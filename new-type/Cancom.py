import can
import time
import json
import socket
import subprocess

# --- CONFIGURATION ---
CAN_INTERFACE = 'can0'
CAN_BITRATE = 500000
UDP_TARGET_HOST = '127.0.0.1'
UDP_TARGET_PORT = 8765
PUBLISH_INTERVAL_S = 0.02

SWITCH_IDS = {0x40, 0x43}

# Multipliers from documentation
SCALES = {
    "voltage": 32.0,
    "current": 32.0,
    "speed": 256.0,
}

# Maximum physically valid phase voltage.
# 45V is the hard ceiling — anything at or above is a garbled ADC frame, discard entirely.
MAX_PHASE_V = 45.0
MAX_SPEED_KMPH = 80.0
MAX_RPM = 5100

def decode_le(data_chunk, signed=True):
    """Decodes little endian data from CAN packet."""
    return int.from_bytes(data_chunk, byteorder='little', signed=signed)

latest_data = {}
dirty_data = False

def write_value(name, value):
    """Update in-memory telemetry value with numeric coercion guard."""
    global dirty_data
    try:
        latest_data[name] = float(value)
        dirty_data = True
    except Exception:
        pass

def publish_latest(sock, target):
    """Publish latest telemetry snapshot to API bridge over localhost UDP."""
    payload = json.dumps(latest_data, separators=(',', ':'))
    sock.sendto(payload.encode('utf-8'), target)


# --- CAN Setup ---
def setup_can():
    try:
        result = subprocess.run(['ip', 'link', 'show', CAN_INTERFACE], capture_output=True, text=True)
        if "UP" not in result.stdout:
            subprocess.run(['ip', 'link', 'set', CAN_INTERFACE, 'down'], check=False)
            subprocess.run(['ip', 'link', 'set', CAN_INTERFACE, 'type', 'can', 'bitrate', str(CAN_BITRATE)], check=True)
            subprocess.run(['ip', 'link', 'set', CAN_INTERFACE, 'up'], check=True)
        print(f"{CAN_INTERFACE} initialized at {CAN_BITRATE} bps.")
        return True
    except Exception as e:
        print(f"CAN Setup Error: {e}")
        return False

# --- Odometer ---
total_distance_km = 0.0
last_time = time.time()
last_unknown_log = 0.0

# --- CAN Message Parser (using user's proven decode_le logic) ---
def parse_can(msg):
    global total_distance_km, last_time, last_unknown_log
    cid = msg.arbitration_id
    d = msg.data

    # --- ARDUINO SWITCHES (ID 0x40/0x43) ---
    if cid in SWITCH_IDS:
        if len(d) < 1:
            return
        s = d[0]
        hi_beam_raw = 1.0 if (s & (1 << 4)) else 0.0   # bit 5 in 1-based indexing
        headlight_raw = 1.0 if (s & (1 << 5)) else 0.0 # bit 6 in 1-based indexing
        write_value("sw_left",    1.0 if (s & (1 << 0)) else 0.0)
        write_value("sw_right",   1.0 if (s & (1 << 1)) else 0.0)
        # Horn bit is intentionally ignored for dashboard UI; keep value pinned low.
        write_value("sw_horn",    0.0)
        write_value("sw_brake",   1.0 if (s & (1 << 3)) else 0.0)
        write_value("sw_hi_beam", hi_beam_raw)
        write_value("sw_head", headlight_raw)
        write_value("sw_low_beam", 1.0 if (headlight_raw >= 1.0 and hi_beam_raw < 1.0) else 0.0)

    # --- TPDO 1: Controller Data ---
    elif cid == 0x1AA and len(d) >= 8:
        write_value("ctrl_status", d[0])
        write_value("ctrl_temp", decode_le(d[2:4]))
        write_value("ctrl_flags", decode_le(d[4:6], signed=False))
        write_value("ctrl_flags2", decode_le(d[6:8], signed=False))

    # --- TPDO 2: Motor Data ---
    elif cid == 0x2AA and len(d) >= 8:
        pwr   = decode_le(d[0:2], signed=False)                   # Power: unsigned W
        speed_raw = decode_le(d[2:4], signed=False) / SCALES["speed"] # Speed: unsigned raw/256 = km/h
        rpm_raw   = decode_le(d[4:6], signed=True)                    # RPM: signed (negative = reverse)
        mtemp = decode_le(d[6:8], signed=True)                    # Motor temp: signed °C

        speed = min(speed_raw, MAX_SPEED_KMPH)
        rpm = max(-MAX_RPM, min(rpm_raw, MAX_RPM))

        write_value("motor_pwr",     pwr)
        write_value("vehicle_speed", round(speed, 2))
        write_value("motor_rpm",     rpm)
        # Motor temp guard: ignore glitch values above 49°C or below -20°C.
        # TPDO2 occasionally produces out-of-range readings; DB retains last valid value.
        if -20 <= mtemp <= 49:
            write_value("motor_temp", mtemp)

        # Odometer
        now = time.time()
        total_distance_km += speed * ((now - last_time) / 3600.0)
        last_time = now
        write_value("total_distance", total_distance_km)

    # --- TPDO 3 (0x3AA): ignored ---
    # Battery data is intentionally not handled in this collector.
    # elif cid == 0x3AA: pass

    # --- TPDO 4: Phase Voltages ---
    # Map1=PhaseA, Map2=PhaseB, Map3=PhaseC — unsigned ÷32.
    # 45V hard ceiling: frames with any phase ≥45V are ADC-torn garbage, discarded entirely.
    # motor_temp intentionally NOT read here — TPDO2 (0x2AA) is the sole motor_temp source.
    elif cid == 0x4AA and len(d) >= 6:
        va = decode_le(d[0:2], signed=False) / SCALES["voltage"]
        vb = decode_le(d[2:4], signed=False) / SCALES["voltage"]
        vc = decode_le(d[4:6], signed=False) / SCALES["voltage"]
        if va < MAX_PHASE_V and vb < MAX_PHASE_V and vc < MAX_PHASE_V:
            write_value("phase_v_a", va)
            write_value("phase_v_b", vb)
            write_value("phase_v_c", vc)

    # --- TPDO 5: Phase Currents & Faults ---
    # Map1=PhaseAI, Map2=PhaseBi, Map3=PhaseCI — signed ÷32 (negative = regen).
    # Map4=faults — unsigned bitmask.
    elif cid == 0x5AA and len(d) >= 8:
        write_value("phase_i_a", decode_le(d[0:2], signed=True) / SCALES["current"])
        write_value("phase_i_b", decode_le(d[2:4], signed=True) / SCALES["current"])
        write_value("phase_i_c", decode_le(d[4:6], signed=True) / SCALES["current"])
        write_value("faults",    decode_le(d[6:8], signed=False))

    # --- TPDO 6: Faults (cont.) & Warnings ---
    elif cid == 0x6AA and len(d) >= 8:
        write_value("faults2",   decode_le(d[0:2], signed=False))
        write_value("faults3",   decode_le(d[2:4], signed=False))
        write_value("warnings",  decode_le(d[4:6], signed=False))
        write_value("warnings2", decode_le(d[6:8], signed=False))

    else:
        # Throttle unknown logs to avoid loop stalls.
        if (time.time() - last_unknown_log) > 0.5:
            last_unknown_log = time.time()
            print(f"[UNKNOWN] ID: {hex(cid)} | LEN: {len(d)} | DATA: {d.hex()}")

# --- Main ---
if not setup_can():
    print("[!] CAN interface failed. Exiting.")
    exit(1)

bus = None
try:
    bus = can.interface.Bus(channel=CAN_INTERFACE, interface='socketcan')
except Exception as e:
    print(f"CAN Bus Error: {e}")
    exit(1)

udp_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
udp_target = (UDP_TARGET_HOST, UDP_TARGET_PORT)

last_time = time.time()
last_publish = time.time()
msg_count = 0

print("Shastra CAN Collector running (direct UDP stream)...")

try:
    while True:
        msg = bus.recv(timeout=0.002)
        if msg:
            parse_can(msg)
            msg_count += 1

        now = time.time()
        if dirty_data and (now - last_publish) >= PUBLISH_INTERVAL_S:
            try:
                publish_latest(udp_sock, udp_target)
                globals()['dirty_data'] = False
            except Exception as e:
                print(f"[STREAM ERROR]: {e}")
            last_publish = now

except KeyboardInterrupt:
    print(f"\nStopping... ({msg_count} CAN messages processed)")
except (can.CanOperationError, OSError) as e:
    print(f"\nCAN Error: {e}")
finally:
    try:
        if latest_data:
            publish_latest(udp_sock, udp_target)
    except Exception:
        pass
    udp_sock.close()
    if bus:
        bus.shutdown()
