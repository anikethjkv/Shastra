import zmq
import time
import can
import struct
import subprocess

# --- Configuration ---
ZMQ_ADDRESS = "tcp://localhost:5555"
CAN_INTERFACE = "can0"
CAN_BITRATE = "500000"

# --- Setup ZMQ ---
context = zmq.Context()
socket = context.socket(zmq.REQ)
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
    try:
        payload = {"name": name, "value": value, "mode": mode}
        if command: payload["command"] = command
        socket.send_json(payload)
        return socket.recv_json() if command else socket.recv_string()
    except:
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
        db_query("batt_soc", data[4])
        db_query("batt_temp", data[6])

    # --- TPDO 4: Phase Voltages ---
    elif cid == 0x4AA:
        db_query("phase_v_a", struct.unpack('<h', data[0:2])[0] / 32.0)
        db_query("phase_v_b", struct.unpack('<h', data[2:4])[0] / 32.0)
        db_query("phase_v_c", struct.unpack('<h', data[4:6])[0] / 32.0)

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
except KeyboardInterrupt:
    print("\nStopping...")
