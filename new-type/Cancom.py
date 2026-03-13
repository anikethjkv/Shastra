import zmq
import time
import can
import struct
import subprocess

# --- Configuration ---
ZMQ_ADDRESS = "tcp://localhost:5555"
CAN_INTERFACE = "can0"
CAN_BITRATE = "250000"

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

def send(name, value):
    try:
        payload = {"name": name, "value": round(float(value), 4), "mode": "update"}
        socket.send_json(payload)
        socket.recv_string()
    except:
        pass

# ... (get_initial_distance function remains same) ...

setup_can()
try:
    bus = can.interface.Bus(channel=CAN_INTERFACE, interface='socketcan')
except:
    bus = None

print("CAN Collector (Arduino + Motor Controller) Running...")

def parse_can(msg):
    cid = msg.arbitration_id
    data = msg.data
    
    # --- ARDUINO DATA (ID 0x40 / 64 Decimal) ---
    if cid == 0x40:
        # I will fill this logic once you provide the data structure
        # Example: val = struct.unpack('<h', data[0:2])[0]
        print(f"Received Arduino Data: {data.hex()}")
        pass

    # --- MOTOR CONTROLLER DATA (ID 0x42 / 66 Decimal) ---
    elif cid == 0x42:
        # Update this logic based on how the 0x42 packet is structured
        # (Is it a single packet or does it use TPDO offsets?)
        send("mc_raw_data", data[0]) # Placeholder
        pass

    # --- ORIGINAL TPDO MAPPING (Keeping for compatibility) ---
    elif cid in [0x1AA, 0x2AA, 0x3AA, 0x4AA, 0x5AA, 0x6AA]:
        # ... (Existing TPDO parsing logic here) ...
        pass

try:
    while True:
        if bus:
            msg = bus.recv(timeout=0.01)
            if msg:
                parse_can(msg)
except KeyboardInterrupt:
    print("\nStopping...")