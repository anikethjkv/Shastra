import zmq
import time
import can
import struct
import subprocess

# --- Configuration ---
ZMQ_ADDRESS = "tcp://localhost:5555"
CAN_INTERFACE = "can0"
CAN_BITRATE = "500000"

# BMS CAN IDs for battery data polling
BMS_IDS = [0x100, 0x101, 0x104, 0x105, 0x106]
BMS_POLL_INTERVAL = 2.0  # seconds between BMS polls

def decode_bms_temp(raw_value):
    """Decode BMS NTC temperature: (raw - 2731) / 10.0 in °C."""
    return (raw_value - 2731) / 10.0

# --- Setup ZMQ ---
context = zmq.Context()
socket = context.socket(zmq.REQ)
socket.setsockopt(zmq.SNDTIMEO, 500)   # 500ms send timeout
socket.setsockopt(zmq.RCVTIMEO, 500)   # 500ms recv timeout
socket.setsockopt(zmq.LINGER, 0)
socket.connect(ZMQ_ADDRESS)

def _reconnect_zmq():
    """Re-create the ZMQ socket after an error (REQ/REP requires strict alternation)."""
    global socket
    try:
        socket.close()
    except:
        pass
    socket = context.socket(zmq.REQ)
    socket.setsockopt(zmq.SNDTIMEO, 500)
    socket.setsockopt(zmq.RCVTIMEO, 500)
    socket.setsockopt(zmq.LINGER, 0)
    socket.connect(ZMQ_ADDRESS)

def setup_can():
    try:
        subprocess.run(["sudo", "ip", "link", "set", CAN_INTERFACE, "down"], check=False)
        time.sleep(0.5)
        subprocess.run(["sudo", "ip", "link", "set", CAN_INTERFACE, "up", "type", "can", "bitrate", CAN_BITRATE, "restart-ms", "100"], check=True)
        print(f"{CAN_INTERFACE} initialized at {CAN_BITRATE} bps.")
    except Exception as e:
        print(f"CAN Setup Error: {e}")

def db_query(name, value=None, mode="update", command=None):
    global socket
    try:
        payload = {"name": name, "value": value, "mode": mode}
        if command: payload["command"] = command
        socket.send_json(payload)
        return socket.recv_json() if command else socket.recv_string()
    except Exception as e:
        print(f"[ZMQ ERROR] {name}={value}: {e} — reconnecting")
        _reconnect_zmq()
        return None

def check_remote_start_request(bus):
    reply = db_query("remote_start_cmd", command="get_value")
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
                db_query("bms_total_voltage", round(volt_raw * 0.01, 2))
                db_query("bms_current", round(curr_raw * 0.01, 2))
                db_query("bms_rem_cap", rem_cap_raw * 10)

            elif can_id == 0x101:
                full_cap_raw, cycles, rsoc = struct.unpack('>HhH', data[0:6])
                db_query("bms_full_cap", full_cap_raw * 10)
                db_query("bms_cycles", cycles)
                db_query("bms_soc", rsoc)

            elif can_id == 0x104:
                db_query("bms_strings", data[0])
                db_query("bms_ntc_count", data[1])

            elif can_id == 0x105:
                ntc1, ntc2, ntc3 = struct.unpack('>HHH', data[0:6])
                db_query("bms_ntc1", round(decode_bms_temp(ntc1), 1))
                db_query("bms_ntc2", round(decode_bms_temp(ntc2), 1))
                db_query("bms_ntc3", round(decode_bms_temp(ntc3), 1))

            elif can_id == 0x106:
                if len(data) >= 2:
                    db_query("bms_ntc4", round(decode_bms_temp(struct.unpack('>H', data[0:2])[0]), 1))
                if len(data) >= 4:
                    db_query("bms_ntc5", round(decode_bms_temp(struct.unpack('>H', data[2:4])[0]), 1))

        except Exception:
            continue

def parse_can(msg):
    global total_distance_km, last_time
    cid = msg.arbitration_id
    data = msg.data

    # --- ARDUINO SWITCHES (ID 0x40) ---
    if cid == 0x40:
        s = data[0]
        db_query("sw_left",    1.0 if (s & (1 << 0)) else 0.0)
        db_query("sw_right",   1.0 if (s & (1 << 1)) else 0.0)
        db_query("sw_horn",    1.0 if (s & (1 << 2)) else 0.0)
        db_query("sw_brake",   1.0 if (s & (1 << 3)) else 0.0)
        db_query("sw_head",    1.0 if (s & (1 << 4)) else 0.0)
        db_query("sw_hi_beam", 1.0 if (s & (1 << 5)) else 0.0)

    # --- TPDO 1: Controller Data ---
    elif cid == 0x1AA:
        db_query("ctrl_status", data[0])
        db_query("ctrl_temp", data[2])
        db_query("ctrl_flags", struct.unpack('<H', data[4:6])[0])
        db_query("ctrl_flags2", struct.unpack('<H', data[6:8])[0])

    # --- TPDO 2: Motor Data ---
    elif cid == 0x2AA:
        db_query("motor_pwr", struct.unpack('<H', data[0:2])[0])
        speed_kph = struct.unpack('<H', data[2:4])[0] / 256.0
        db_query("vehicle_speed", speed_kph)

        # Odometer Integration
        now = time.time()
        total_distance_km += speed_kph * ((now - last_time) / 3600.0)
        last_time = now
        db_query("total_distance", total_distance_km)

        db_query("motor_rpm", struct.unpack('<H', data[4:6])[0])
        db_query("motor_temp", data[6])

    # --- TPDO 3: Battery Data ---
    elif cid == 0x3AA:
        db_query("batt_v", struct.unpack('<H', data[0:2])[0] / 32.0)
        db_query("batt_i", struct.unpack('<H', data[2:4])[0] / 32.0)
        db_query("batt_soc", struct.unpack('<H', data[4:6])[0])
        db_query("batt_temp", struct.unpack('<H', data[6:8])[0])

    # --- TPDO 4: Phase Voltages + Motor Temp ---
    elif cid == 0x4AA:
        db_query("phase_v_a", struct.unpack('<h', data[0:2])[0] / 32.0)
        db_query("phase_v_b", struct.unpack('<h', data[2:4])[0] / 32.0)
        db_query("phase_v_c", struct.unpack('<h', data[4:6])[0] / 32.0)
        db_query("motor_temp2", struct.unpack('<h', data[6:8])[0])

    # --- TPDO 5: Phase Currents & Faults ---
    elif cid == 0x5AA:
        db_query("phase_i_a", struct.unpack('<h', data[0:2])[0] / 32.0)
        db_query("phase_i_b", struct.unpack('<h', data[2:4])[0] / 32.0)
        db_query("phase_i_c", struct.unpack('<h', data[4:6])[0] / 32.0)
        db_query("faults", struct.unpack('<H', data[6:8])[0])

    # --- TPDO 6: Secondary Faults & Warnings ---
    elif cid == 0x6AA:
        db_query("faults2", struct.unpack('<h', data[0:2])[0])
        db_query("faults3", struct.unpack('<h', data[2:4])[0])
        db_query("warnings", struct.unpack('<h', data[4:6])[0])
        db_query("warnings2", struct.unpack('<h', data[6:8])[0])

# --- Main Setup & Loop ---
setup_can()
try:
    bus = can.interface.Bus(channel=CAN_INTERFACE, interface='socketcan')
except:
    bus = None

# Odometer Sync
initial_odo = db_query("total_distance", command="get_distance")
total_distance_km = float(initial_odo.get("value", 0.0)) if initial_odo else 0.0

last_time = time.time()
last_db_check = time.time()
last_bms_poll = time.time()

try:
    print("Full Telemetry CAN Collector Running...")
    while True:
        if bus:
            msg = bus.recv(timeout=0.01)
            if msg:
                parse_can(msg)

            # Check for Remote Start command every 500ms
            if time.time() - last_db_check > 0.5:
                check_remote_start_request(bus)
                last_db_check = time.time()

            # Poll BMS battery data every ~2 seconds
            if time.time() - last_bms_poll > BMS_POLL_INTERVAL:
                poll_bms(bus)
                last_bms_poll = time.time()
except KeyboardInterrupt:
    print("\nStopping...")
