import zmq
import time
import can
import struct
import subprocess
import sqlite3
import os

# --- Configuration ---
ZMQ_ADDRESS = "tcp://localhost:5555"
CAN_INTERFACE = "can0"
CAN_BITRATE = "500000"
DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Sensor_data.db")

# BMS CAN IDs for battery data polling
BMS_IDS = [0x100, 0x101, 0x104, 0x105, 0x106]
BMS_POLL_INTERVAL = 2.0  # seconds between BMS polls

def decode_bms_temp(raw_value):
    """Decode BMS NTC temperature: (raw - 2731) / 10.0 in °C."""
    return (raw_value - 2731) / 10.0

# --- Setup Direct SQLite (for fast CAN writes) ---
db_conn = sqlite3.connect(DB_PATH, check_same_thread=False)
db_conn.execute("PRAGMA journal_mode=WAL")  # Allow concurrent reads from api.py
db_conn.execute("PRAGMA synchronous=NORMAL")  # Faster writes, still safe
db_conn.execute("CREATE TABLE IF NOT EXISTS latest_readings (sensor_name TEXT UNIQUE, reading_value REAL)")
db_conn.commit()

def db_write(name, value):
    """Write sensor value directly to SQLite — no ZMQ overhead."""
    try:
        db_conn.execute(
            "INSERT INTO latest_readings (sensor_name, reading_value) VALUES (?, ?) "
            "ON CONFLICT(sensor_name) DO UPDATE SET reading_value=excluded.reading_value",
            (name, float(value))
        )
    except Exception as e:
        print(f"[DB WRITE ERROR] {name}={value}: {e}")

def db_flush():
    """Commit batched writes to disk."""
    try:
        db_conn.commit()
    except Exception as e:
        print(f"[DB COMMIT ERROR]: {e}")

# --- Setup ZMQ (only for commands that need a reply) ---
context = zmq.Context()
zmq_socket = context.socket(zmq.REQ)
zmq_socket.setsockopt(zmq.SNDTIMEO, 1000)
zmq_socket.setsockopt(zmq.RCVTIMEO, 1000)
zmq_socket.setsockopt(zmq.LINGER, 0)
zmq_socket.connect(ZMQ_ADDRESS)

def _reconnect_zmq():
    global zmq_socket
    try:
        zmq_socket.close()
    except:
        pass
    zmq_socket = context.socket(zmq.REQ)
    zmq_socket.setsockopt(zmq.SNDTIMEO, 1000)
    zmq_socket.setsockopt(zmq.RCVTIMEO, 1000)
    zmq_socket.setsockopt(zmq.LINGER, 0)
    zmq_socket.connect(ZMQ_ADDRESS)

def db_command(name, command):
    """Send a command via ZMQ (only for get_value/get_distance that need a reply)."""
    global zmq_socket
    try:
        zmq_socket.send_json({"name": name, "command": command})
        return zmq_socket.recv_json()
    except Exception as e:
        print(f"[ZMQ CMD ERROR] {name}/{command}: {e} — reconnecting")
        _reconnect_zmq()
        return None

# --- CAN Setup ---
def setup_can():
    try:
        subprocess.run(["sudo", "ip", "link", "set", CAN_INTERFACE, "down"], check=False)
        time.sleep(0.5)
        subprocess.run(["sudo", "ip", "link", "set", CAN_INTERFACE, "up", "type", "can", "bitrate", CAN_BITRATE, "restart-ms", "100"], check=True)
        print(f"{CAN_INTERFACE} initialized at {CAN_BITRATE} bps.")
    except Exception as e:
        print(f"CAN Setup Error: {e}")

def check_remote_start_request(bus):
    reply = db_command("remote_start_cmd", "get_value")
    if reply and reply.get("status") == "OK":
        cmd_state = int(float(reply.get("value", 0)))
        msg = can.Message(arbitration_id=0x41, data=[cmd_state], is_extended_id=False)
        try:
            bus.send(msg)
        except:
            pass

def poll_bms(bus):
    """Send 0x5A request frames to BMS CAN IDs and decode responses."""
    for can_id in BMS_IDS:
        try:
            req = can.Message(arbitration_id=can_id, data=[0x5A], is_extended_id=False)
            bus.send(req)
            response = bus.recv(timeout=0.1)
            if not response or response.arbitration_id != can_id or len(response.data) < 4:
                continue
            data = response.data

            if can_id == 0x100:
                volt_raw, curr_raw, rem_cap_raw = struct.unpack('>HhH', data[0:6])
                db_write("bms_total_voltage", round(volt_raw * 0.01, 2))
                db_write("bms_current", round(curr_raw * 0.01, 2))
                db_write("bms_rem_cap", rem_cap_raw * 10)

            elif can_id == 0x101:
                full_cap_raw, cycles, rsoc = struct.unpack('>HhH', data[0:6])
                db_write("bms_full_cap", full_cap_raw * 10)
                db_write("bms_cycles", cycles)
                db_write("bms_soc", rsoc)

            elif can_id == 0x104:
                db_write("bms_strings", data[0])
                db_write("bms_ntc_count", data[1])

            elif can_id == 0x105:
                ntc1, ntc2, ntc3 = struct.unpack('>HHH', data[0:6])
                db_write("bms_ntc1", round(decode_bms_temp(ntc1), 1))
                db_write("bms_ntc2", round(decode_bms_temp(ntc2), 1))
                db_write("bms_ntc3", round(decode_bms_temp(ntc3), 1))

            elif can_id == 0x106:
                if len(data) >= 2:
                    db_write("bms_ntc4", round(decode_bms_temp(struct.unpack('>H', data[0:2])[0]), 1))
                if len(data) >= 4:
                    db_write("bms_ntc5", round(decode_bms_temp(struct.unpack('>H', data[2:4])[0]), 1))

        except Exception:
            continue
    db_flush()

# --- Odometer ---
total_distance_km = 0.0
last_time = time.time()

# --- CAN Message Parser ---
def parse_can(msg):
    global total_distance_km, last_time
    cid = msg.arbitration_id
    data = msg.data

    # --- ARDUINO SWITCHES (ID 0x40) ---
    if cid == 0x40:
        s = data[0]
        db_write("sw_left",    1.0 if (s & (1 << 0)) else 0.0)
        db_write("sw_right",   1.0 if (s & (1 << 1)) else 0.0)
        db_write("sw_horn",    1.0 if (s & (1 << 2)) else 0.0)
        db_write("sw_brake",   1.0 if (s & (1 << 3)) else 0.0)
        db_write("sw_head",    1.0 if (s & (1 << 4)) else 0.0)
        db_write("sw_hi_beam", 1.0 if (s & (1 << 5)) else 0.0)

    # --- TPDO 1: Controller Data ---
    elif cid == 0x1AA:
        db_write("ctrl_status", data[0])
        db_write("ctrl_temp", data[2])
        db_write("ctrl_flags", struct.unpack('<H', data[4:6])[0])
        db_write("ctrl_flags2", struct.unpack('<H', data[6:8])[0])

    # --- TPDO 2: Motor Data ---
    elif cid == 0x2AA:
        db_write("motor_pwr", struct.unpack('<H', data[0:2])[0])
        speed_kph = struct.unpack('<H', data[2:4])[0] / 256.0
        db_write("vehicle_speed", speed_kph)

        # Odometer Integration
        now = time.time()
        total_distance_km += speed_kph * ((now - last_time) / 3600.0)
        last_time = now
        db_write("total_distance", total_distance_km)

        db_write("motor_rpm", struct.unpack('<H', data[4:6])[0])
        db_write("motor_temp", data[6])

    # --- TPDO 3: Battery Data ---
    elif cid == 0x3AA:
        db_write("batt_v", struct.unpack('<H', data[0:2])[0] / 32.0)
        db_write("batt_i", struct.unpack('<H', data[2:4])[0] / 32.0)
        db_write("batt_soc", struct.unpack('<H', data[4:6])[0])
        db_write("batt_temp", struct.unpack('<H', data[6:8])[0])

    # --- TPDO 4: Phase Voltages + Motor Temp ---
    elif cid == 0x4AA:
        db_write("phase_v_a", struct.unpack('<h', data[0:2])[0] / 32.0)
        db_write("phase_v_b", struct.unpack('<h', data[2:4])[0] / 32.0)
        db_write("phase_v_c", struct.unpack('<h', data[4:6])[0] / 32.0)
        db_write("motor_temp2", struct.unpack('<h', data[6:8])[0])

    # --- TPDO 5: Phase Currents & Faults ---
    elif cid == 0x5AA:
        db_write("phase_i_a", struct.unpack('<h', data[0:2])[0] / 32.0)
        db_write("phase_i_b", struct.unpack('<h', data[2:4])[0] / 32.0)
        db_write("phase_i_c", struct.unpack('<h', data[4:6])[0] / 32.0)
        db_write("faults", struct.unpack('<H', data[6:8])[0])

    # --- TPDO 6: Secondary Faults & Warnings ---
    elif cid == 0x6AA:
        db_write("faults2", struct.unpack('<h', data[0:2])[0])
        db_write("faults3", struct.unpack('<h', data[2:4])[0])
        db_write("warnings", struct.unpack('<h', data[4:6])[0])
        db_write("warnings2", struct.unpack('<h', data[6:8])[0])

# --- Main Setup & Loop ---
setup_can()
try:
    bus = can.interface.Bus(channel=CAN_INTERFACE, interface='socketcan')
except:
    bus = None

# Odometer Sync — read directly from SQLite
try:
    row = db_conn.execute("SELECT reading_value FROM latest_readings WHERE sensor_name='total_distance'").fetchone()
    total_distance_km = float(row[0]) if row else 0.0
except:
    total_distance_km = 0.0

last_time = time.time()
last_db_flush = time.time()
last_db_check = time.time()
last_bms_poll = time.time()
msg_count = 0

try:
    print("Full Telemetry CAN Collector Running (direct SQLite writes)...")
    while True:
        if bus:
            msg = bus.recv(timeout=0.01)
            if msg:
                parse_can(msg)
                msg_count += 1

            # Flush writes to disk every 200ms (batches ~20-50 writes)
            now = time.time()
            if now - last_db_flush > 0.2:
                db_flush()
                last_db_flush = now

            # Check for Remote Start command every 500ms (uses ZMQ)
            if now - last_db_check > 0.5:
                check_remote_start_request(bus)
                last_db_check = now

            # Poll BMS battery data every ~2 seconds
            if now - last_bms_poll > BMS_POLL_INTERVAL:
                poll_bms(bus)
                last_bms_poll = now

except KeyboardInterrupt:
    print(f"\nStopping... ({msg_count} messages processed)")
    db_flush()
    db_conn.close()
