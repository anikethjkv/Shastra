import can
import os
import time
import struct
import subprocess
import sqlite3

# --- CONFIGURATION ---
CAN_INTERFACE = 'can0'
CAN_BITRATE = 500000
DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Can_data.db")

# BMS CAN IDs for battery data polling
BMS_IDS = [0x100, 0x101, 0x104, 0x105, 0x106]
BMS_POLL_INTERVAL = 2.0
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

def decode_le(data_chunk, signed=True):
    """Decodes little endian data from CAN packet."""
    return int.from_bytes(data_chunk, byteorder='little', signed=signed)

def decode_bms_temp(raw_value):
    """Decode BMS NTC temperature: (raw - 2731) / 10.0 in °C."""
    return (raw_value - 2731) / 10.0

# --- Setup Direct SQLite ---
db_conn = sqlite3.connect(DB_PATH, check_same_thread=False)
db_conn.execute("PRAGMA journal_mode=WAL")
db_conn.execute("PRAGMA synchronous=NORMAL")
db_conn.execute("CREATE TABLE IF NOT EXISTS latest_readings (sensor_name TEXT UNIQUE, reading_value REAL)")
db_conn.commit()

sensor_cache = {}

def db_write(name, value):
    """Buffer sensor value in memory."""
    sensor_cache[name] = float(value)

def db_flush():
    """Batch write only the newest values to SQLite, drastically reducing disk IO."""
    if not sensor_cache:
        return
    try:
        # Prepare batch payload
        records = [(k, v) for k, v in sensor_cache.items()]
        sensor_cache.clear()
        
        db_conn.executemany(
            "INSERT INTO latest_readings (sensor_name, reading_value) VALUES (?, ?) "
            "ON CONFLICT(sensor_name) DO UPDATE SET reading_value=excluded.reading_value",
            records
        )
        db_conn.commit()
    except Exception as e:
        print(f"[DB COMMIT ERROR]: {e}")


# --- CAN Setup ---
def setup_can():
    try:
        result = subprocess.run(['ip', 'link', 'show', CAN_INTERFACE], capture_output=True, text=True)
        if "UP" not in result.stdout:
            subprocess.run(['sudo', 'ip', 'link', 'set', CAN_INTERFACE, 'down'], check=False)
            subprocess.run(['sudo', 'ip', 'link', 'set', CAN_INTERFACE, 'type', 'can', 'bitrate', str(CAN_BITRATE)], check=True)
            subprocess.run(['sudo', 'ip', 'link', 'set', CAN_INTERFACE, 'up'], check=True)
        print(f"{CAN_INTERFACE} initialized at {CAN_BITRATE} bps.")
        return True
    except Exception as e:
        print(f"CAN Setup Error: {e}")
        return False

def check_remote_start(bus):
    """Read remote_start_cmd from SQLite and send to CAN."""
    try:
        row = db_conn.execute("SELECT reading_value FROM latest_readings WHERE sensor_name='remote_start_cmd'").fetchone()
        cmd = int(float(row[0])) if row else 0
        if cmd:
            bus.send(can.Message(arbitration_id=0x41, data=[cmd], is_extended_id=False))
    except:
        pass

# BMS validity limits — values outside these ranges are garbled frames, silently dropped.
MAX_SOC      = 100    # SOC is a percentage: 0–100. Anything above = erroneous.
MAX_NTC_TEMP = 100.0  # NTC sensors cannot physically read above 100°C on this pack.
MIN_NTC_TEMP = -40.0  # Sub -40°C is equally unphysical for a Li-ion pack.

def _write_ntc(key, raw):
    """Decode BMS NTC raw and write only if within physical bounds."""
    temp = round(decode_bms_temp(raw), 1)
    if MIN_NTC_TEMP <= temp <= MAX_NTC_TEMP:
        db_write(key, temp)

def poll_bms(bus):
    """Poll BMS CAN IDs and write responses to SQLite."""
    for can_id in BMS_IDS:
        try:
            bus.send(can.Message(arbitration_id=can_id, data=[0x5A], is_extended_id=False))
            resp = bus.recv(timeout=0.1)
            if not resp or resp.arbitration_id != can_id or len(resp.data) < 4:
                continue
            d = resp.data

            if can_id == 0x100:
                v_raw, i_raw, cap_raw = struct.unpack('>HhH', d[0:6])
                db_write("bms_total_voltage", round(v_raw * 0.01, 2))
                db_write("bms_current",       round(i_raw * 0.01, 2))
                db_write("bms_rem_cap",        cap_raw * 10)
            elif can_id == 0x101:
                fc_raw, cyc, rsoc = struct.unpack('>HhH', d[0:6])
                db_write("bms_full_cap", fc_raw * 10)
                db_write("bms_cycles",   cyc)
                # SOC guard: discard if outside 0–100% (erroneous reads like 1386% ignored)
                if 0 <= rsoc <= MAX_SOC:
                    db_write("bms_soc", rsoc)
            elif can_id == 0x104:
                db_write("bms_strings",   d[0])
                db_write("bms_ntc_count", d[1])
            elif can_id == 0x105:
                n1, n2, n3 = struct.unpack('>HHH', d[0:6])
                # NTC guard: discard individual sensors if outside -40°C to 100°C
                _write_ntc("bms_ntc1", n1)
                _write_ntc("bms_ntc2", n2)
                _write_ntc("bms_ntc3", n3)
            elif can_id == 0x106:
                if len(d) >= 2:
                    _write_ntc("bms_ntc4", struct.unpack('>H', d[0:2])[0])
                if len(d) >= 4:
                    _write_ntc("bms_ntc5", struct.unpack('>H', d[2:4])[0])
        except:
            continue
    db_flush()

# --- Odometer ---
total_distance_km = 0.0
last_time = time.time()

# --- CAN Message Parser (using user's proven decode_le logic) ---
def parse_can(msg):
    global total_distance_km, last_time
    cid = msg.arbitration_id
    d = msg.data

    # --- ARDUINO SWITCHES (ID 0x40) ---
    if cid in SWITCH_IDS and len(d) >= 1:
        s = d[0]
        hi_beam_raw = 1.0 if (s & (1 << 4)) else 0.0   # bit 5 in 1-based indexing
        headlight_raw = 1.0 if (s & (1 << 5)) else 0.0 # bit 6 in 1-based indexing
        db_write("sw_left",    1.0 if (s & (1 << 0)) else 0.0)
        db_write("sw_right",   1.0 if (s & (1 << 1)) else 0.0)
        db_write("sw_horn",    1.0 if (s & (1 << 2)) else 0.0)
        db_write("sw_brake",   1.0 if (s & (1 << 3)) else 0.0)
        db_write("sw_hi_beam", hi_beam_raw)
        db_write("sw_head", headlight_raw)
        db_write("sw_low_beam", 1.0 if (headlight_raw >= 1.0 and hi_beam_raw < 1.0) else 0.0)

    # --- TPDO 1: Controller Data ---
    elif cid == 0x1AA and len(d) >= 8:
        db_write("ctrl_status", d[0])
        db_write("ctrl_temp", decode_le(d[2:4]))
        db_write("ctrl_flags", decode_le(d[4:6], signed=False))
        db_write("ctrl_flags2", decode_le(d[6:8], signed=False))

    # --- TPDO 2: Motor Data ---
    elif cid == 0x2AA and len(d) >= 8:
        pwr   = decode_le(d[0:2], signed=False)                   # Power: unsigned W
        speed = decode_le(d[2:4], signed=False) / SCALES["speed"] # Speed: unsigned raw/256 = km/h
        rpm   = decode_le(d[4:6], signed=True)                    # RPM: signed (negative = reverse)
        mtemp = decode_le(d[6:8], signed=True)                    # Motor temp: signed °C

        db_write("motor_pwr",     pwr)
        db_write("vehicle_speed", round(speed, 2))
        db_write("motor_rpm",     rpm)
        # Motor temp guard: ignore glitch values above 49°C or below -20°C.
        # TPDO2 occasionally produces out-of-range readings; DB retains last valid value.
        if -20 <= mtemp <= 49:
            db_write("motor_temp", mtemp)

        # Odometer
        now = time.time()
        total_distance_km += speed * ((now - last_time) / 3600.0)
        last_time = now
        db_write("total_distance", total_distance_km)

    # --- TPDO 3 (0x3AA): ignored ---
    # Battery data comes exclusively from BMS polling (0x100/0x101).
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
            db_write("phase_v_a", va)
            db_write("phase_v_b", vb)
            db_write("phase_v_c", vc)

    # --- TPDO 5: Phase Currents & Faults ---
    # Map1=PhaseAI, Map2=PhaseBi, Map3=PhaseCI — signed ÷32 (negative = regen).
    # Map4=faults — unsigned bitmask.
    elif cid == 0x5AA and len(d) >= 8:
        db_write("phase_i_a", decode_le(d[0:2], signed=True) / SCALES["current"])
        db_write("phase_i_b", decode_le(d[2:4], signed=True) / SCALES["current"])
        db_write("phase_i_c", decode_le(d[4:6], signed=True) / SCALES["current"])
        db_write("faults",    decode_le(d[6:8], signed=False))

    # --- TPDO 6: Faults (cont.) & Warnings ---
    elif cid == 0x6AA and len(d) >= 8:
        db_write("faults2",   decode_le(d[0:2], signed=False))
        db_write("faults3",   decode_le(d[2:4], signed=False))
        db_write("warnings",  decode_le(d[4:6], signed=False))
        db_write("warnings2", decode_le(d[6:8], signed=False))

    else:
        # Ignore BMS IDs which we poll actively
        if cid not in BMS_IDS:
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

# Odometer sync from SQLite
try:
    row = db_conn.execute("SELECT reading_value FROM latest_readings WHERE sensor_name='total_distance'").fetchone()
    total_distance_km = float(row[0]) if row else 0.0
except:
    total_distance_km = 0.0

last_time = time.time()
last_flush = time.time()
last_remote = time.time()
last_bms = time.time()
msg_count = 0

print("Shastra CAN Collector running (direct SQLite writes)...")

try:
    while True:
        msg = bus.recv(timeout=0.01)
        if msg:
            parse_can(msg)
            msg_count += 1

        now = time.time()

        # Flush SQLite every 50ms
        if now - last_flush > 0.05:
            db_flush()
            last_flush = now

        # Remote start check every 500ms
        if now - last_remote > 0.5:
            check_remote_start(bus)
            last_remote = now

        # BMS poll every 2s
        if now - last_bms > BMS_POLL_INTERVAL:
            poll_bms(bus)
            last_bms = now

except KeyboardInterrupt:
    print(f"\nStopping... ({msg_count} CAN messages processed)")
except (can.CanOperationError, OSError) as e:
    print(f"\nCAN Error: {e}")
finally:
    db_flush()
    db_conn.close()
    if bus:
        bus.shutdown()
