import can
import os
import time
import struct
import subprocess
import sqlite3

# --- CONFIGURATION ---
CAN_INTERFACE = 'can0'
CAN_BITRATE = 500000
DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Sensor_data.db")

# BMS CAN IDs for battery data polling
BMS_IDS = [0x100, 0x101, 0x104, 0x105, 0x106]
BMS_POLL_INTERVAL = 0.5
SWITCH_IDS = {0x40, 0x43}
COLLECTOR_RECV_TIMEOUT = 0.005
DB_FLUSH_INTERVAL = 0.02
REMOTE_CHECK_INTERVAL = 0.2
STALE_TIMEOUT_SEC = 0.4
BMS_STALE_TIMEOUT_SEC = 1.2

# Multipliers from documentation
SCALES = {
    "voltage": 32.0,
    "current": 32.0,
    "speed": 256.0,
}

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
last_seen = {
    "switch": 0.0,
    "tpdo1": 0.0,
    "tpdo2": 0.0,
    "tpdo3": 0.0,
    "tpdo4": 0.0,
    "tpdo5": 0.0,
    "tpdo6": 0.0,
    "bms": 0.0,
}

SWITCH_KEYS = ["sw_left", "sw_right", "sw_horn", "sw_brake", "sw_head", "sw_hi_beam", "sw_low_beam"]
TPDO1_KEYS = ["ctrl_status", "ctrl_temp", "ctrl_flags", "ctrl_flags2"]
TPDO2_KEYS = ["motor_pwr", "vehicle_speed", "motor_rpm", "motor_temp"]
TPDO3_KEYS = ["batt_v", "batt_i", "batt_soc", "batt_temp"]
TPDO4_KEYS = ["phase_v_a", "phase_v_b", "phase_v_c", "motor_temp"]
TPDO5_KEYS = ["phase_i_a", "phase_i_b", "phase_i_c", "faults"]
TPDO6_KEYS = ["faults2", "faults3", "warnings", "warnings2"]
BMS_KEYS = [
    "bms_total_voltage", "bms_current", "bms_rem_cap", "bms_full_cap", "bms_cycles", "bms_soc",
    "bms_strings", "bms_ntc_count", "bms_ntc1", "bms_ntc2", "bms_ntc3", "bms_ntc4", "bms_ntc5",
]

def db_write(name, value):
    """Buffer sensor value in memory."""
    sensor_cache[name] = float(value)


def mark_seen(group, now=None):
    last_seen[group] = now if now is not None else time.time()


def zero_group(keys):
    for key in keys:
        db_write(key, 0.0)


def reset_stale_signals(now):
    stale_groups = [
        ("switch", SWITCH_KEYS, STALE_TIMEOUT_SEC),
        ("tpdo1", TPDO1_KEYS, STALE_TIMEOUT_SEC),
        ("tpdo2", TPDO2_KEYS, STALE_TIMEOUT_SEC),
        ("tpdo3", TPDO3_KEYS, STALE_TIMEOUT_SEC),
        ("tpdo4", TPDO4_KEYS, STALE_TIMEOUT_SEC),
        ("tpdo5", TPDO5_KEYS, STALE_TIMEOUT_SEC),
        ("tpdo6", TPDO6_KEYS, STALE_TIMEOUT_SEC),
        ("bms", BMS_KEYS, BMS_STALE_TIMEOUT_SEC),
    ]

    for group, keys, timeout in stale_groups:
        seen_ts = last_seen.get(group, 0.0)
        if seen_ts > 0 and (now - seen_ts) > timeout:
            zero_group(keys)
            last_seen[group] = now


def initialize_default_values():
    zero_group(SWITCH_KEYS)
    zero_group(TPDO1_KEYS)
    zero_group(TPDO2_KEYS)
    zero_group(TPDO3_KEYS)
    zero_group(TPDO4_KEYS)
    zero_group(TPDO5_KEYS)
    zero_group(TPDO6_KEYS)
    zero_group(BMS_KEYS)
    db_flush()

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
                db_write("bms_current", round(i_raw * 0.01, 2))
                db_write("bms_rem_cap", cap_raw * 10)
            elif can_id == 0x101:
                fc_raw, cyc, rsoc = struct.unpack('>HhH', d[0:6])
                db_write("bms_full_cap", fc_raw * 10)
                db_write("bms_cycles", cyc)
                db_write("bms_soc", rsoc)
            elif can_id == 0x104:
                db_write("bms_strings", d[0])
                db_write("bms_ntc_count", d[1])
            elif can_id == 0x105:
                n1, n2, n3 = struct.unpack('>HHH', d[0:6])
                db_write("bms_ntc1", round(decode_bms_temp(n1), 1))
                db_write("bms_ntc2", round(decode_bms_temp(n2), 1))
                db_write("bms_ntc3", round(decode_bms_temp(n3), 1))
            elif can_id == 0x106:
                if len(d) >= 2:
                    db_write("bms_ntc4", round(decode_bms_temp(struct.unpack('>H', d[0:2])[0]), 1))
                if len(d) >= 4:
                    db_write("bms_ntc5", round(decode_bms_temp(struct.unpack('>H', d[2:4])[0]), 1))
            mark_seen("bms")
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
        mark_seen("switch")
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
        mark_seen("tpdo1")
        db_write("ctrl_status", d[0])
        db_write("ctrl_temp", decode_le(d[2:4]))
        db_write("ctrl_flags", decode_le(d[4:6], signed=False))
        db_write("ctrl_flags2", decode_le(d[6:8], signed=False))

    # --- TPDO 2: Motor Data ---
    elif cid == 0x2AA and len(d) >= 8:
        mark_seen("tpdo2")
        pwr   = decode_le(d[0:2])
        speed = decode_le(d[2:4]) / SCALES["speed"]
        rpm   = decode_le(d[4:6])
        mtemp = decode_le(d[6:8])

        print(f"[DEBUG 0x2AA] RAW: {d.hex()} | RPM: {rpm} | SPEED: {speed}")

        db_write("motor_pwr", pwr)
        db_write("vehicle_speed", round(speed, 2))
        db_write("motor_rpm", rpm)
        db_write("motor_temp", mtemp)

        # Odometer
        now = time.time()
        total_distance_km += speed * ((now - last_time) / 3600.0)
        last_time = now
        db_write("total_distance", total_distance_km)

    # --- TPDO 3: Battery Data ---
    elif cid == 0x3AA and len(d) >= 8:
        mark_seen("tpdo3")
        db_write("batt_v", decode_le(d[0:2]) / SCALES["voltage"])
        db_write("batt_i", decode_le(d[2:4]) / SCALES["current"])
        db_write("batt_soc", decode_le(d[4:6], signed=False))
        db_write("batt_temp", decode_le(d[6:8]))

    # --- TPDO 4: Phase Voltages ---
    elif cid == 0x4AA and len(d) >= 8:
        mark_seen("tpdo4")
        db_write("phase_v_a", decode_le(d[0:2]) / SCALES["voltage"])
        db_write("phase_v_b", decode_le(d[2:4]) / SCALES["voltage"])
        db_write("phase_v_c", decode_le(d[4:6]) / SCALES["voltage"])
        db_write("motor_temp", decode_le(d[6:8]))

    # --- TPDO 5: Phase Currents & Faults ---
    elif cid == 0x5AA and len(d) >= 8:
        mark_seen("tpdo5")
        db_write("phase_i_a", decode_le(d[0:2]) / SCALES["current"])
        db_write("phase_i_b", decode_le(d[2:4]) / SCALES["current"])
        db_write("phase_i_c", decode_le(d[4:6]) / SCALES["current"])
        db_write("faults", decode_le(d[6:8], signed=False))

    # --- TPDO 6: Faults (cont.) & Warnings ---
    elif cid == 0x6AA and len(d) >= 8:
        mark_seen("tpdo6")
        db_write("faults2", decode_le(d[0:2], signed=False))
        db_write("faults3", decode_le(d[2:4], signed=False))
        db_write("warnings", decode_le(d[4:6], signed=False))
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
initialize_default_values()
last_flush = time.time()
last_remote = time.time()
last_bms = time.time()
msg_count = 0

print("Shastra CAN Collector running (direct SQLite writes)...")

try:
    while True:
        msg = bus.recv(timeout=COLLECTOR_RECV_TIMEOUT)
        if msg:
            parse_can(msg)
            msg_count += 1

        now = time.time()
        reset_stale_signals(now)

        # Flush SQLite every 20ms
        if now - last_flush > DB_FLUSH_INTERVAL:
            db_flush()
            last_flush = now

        # Remote start check every 200ms
        if now - last_remote > REMOTE_CHECK_INTERVAL:
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
