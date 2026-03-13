import zmq
import time
import can
import struct
import subprocess
from gpiozero import Button
from mpu6050 import mpu6050
from gps import gps, WATCH_ENABLE, WATCH_NEWSTYLE

# --- Configuration ---
ZMQ_ADDRESS = "tcp://localhost:5555"
CAN_INTERFACE = "can0"
CAN_BITRATE = "250000"

# --- Automatic CAN Setup ---
def setup_can():
    """Brings up the CAN interface properly by resetting it first."""
    try:
        print(f"Resetting {CAN_INTERFACE}...")
        # Bring it down first so we can change settings
        subprocess.run(["sudo", "ip", "link", "set", CAN_INTERFACE, "down"], check=False)
        
        print(f"Setting bitrate to {CAN_BITRATE}...")
        subprocess.run(["sudo", "ip", "link", "set", CAN_INTERFACE, "up", "type", "can", "bitrate", CAN_BITRATE], check=True)
        print(f"{CAN_INTERFACE} is now UP.")
    except Exception as e:
        print(f"Failed to bring up CAN: {e}")

# Update the Bus initialization to remove the DeprecationWarning:
# Old: bus = can.interface.Bus(channel=CAN_INTERFACE, bustype='socketcan')
# New:
try:
    bus = can.interface.Bus(channel=CAN_INTERFACE, interface='socketcan')
except Exception as e:
    print(f"Library Error: {e}")
    bus = None

# --- Setup ZMQ ---
context = zmq.Context()
socket = context.socket(zmq.REQ)
socket.connect(ZMQ_ADDRESS)

# --- Hardware Initialization ---
smoke_sensor = Button(23, pull_up=True)
try:
    mpu = mpu6050(0x68)
except:
    mpu = None

gps_session = gps(mode=WATCH_ENABLE | WATCH_NEWSTYLE)

# --- Helper Functions ---
def send(name, value):
    try:
        payload = {"name": name, "value": round(float(value), 4), "mode": "update"}
        socket.send_json(payload)
        socket.recv_string()
    except:
        pass

def get_initial_distance():
    """Asks the SQL Writer for the last known odometer value."""
    try:
        socket.send_json({"command": "get_distance"})
        reply = socket.recv_json()
        if reply.get("status") == "OK":
            return float(reply.get("value", 0.0))
    except:
        return 0.0

# --- Start Setup ---
setup_can()
try:
    bus = can.interface.Bus(channel=CAN_INTERFACE, bustype='socketcan')
except:
    bus = None

print("Initializing Odometer...")
total_distance_km = get_initial_distance()
print(f"Starting Odometer at: {total_distance_km:.2f} km")

last_time = time.time()

# --- CAN Parsing Logic ---
def parse_can(msg):
    global total_distance_km, last_time
    cid = msg.arbitration_id
    data = msg.data
    
    if cid == 0x1AA: # TPDO 1
        send("ctrl_status", data[0])
        send("ctrl_temp", data[2])
        send("ctrl_flags", struct.unpack('<H', data[4:6])[0])
        send("ctrl_flags2", struct.unpack('<H', data[6:8])[0])
    elif cid == 0x2AA: # TPDO 2
        send("motor_pwr", struct.unpack('<H', data[0:2])[0])
        speed_kph = (struct.unpack('<H', data[2:4])[0]) / 256.0
        send("vehicle_speed", speed_kph)
        
        # Distance Integration
        now = time.time()
        total_distance_km += speed_kph * ((now - last_time) / 3600.0)
        last_time = now
        send("total_distance", total_distance_km)
        
        send("motor_rpm", struct.unpack('<H', data[4:6])[0])
        send("motor_temp", data[6])
    elif cid == 0x3AA: # TPDO 3
        send("batt_v", struct.unpack('<H', data[0:2])[0] / 32.0)
        send("batt_i", struct.unpack('<H', data[2:4])[0] / 32.0)
        send("batt_soc", data[4])
        send("batt_temp", data[6])
    elif cid == 0x4AA: # TPDO 4
        send("phase_v_a", struct.unpack('<h', data[0:2])[0] / 32.0)
        send("phase_v_b", struct.unpack('<h', data[2:4])[0] / 32.0)
        send("phase_v_c", struct.unpack('<h', data[4:6])[0] / 32.0)
    elif cid == 0x5AA: # TPDO 5
        send("phase_i_a", struct.unpack('<h', data[0:2])[0] / 32.0)
        send("phase_i_b", struct.unpack('<h', data[2:4])[0] / 32.0)
        send("phase_i_c", struct.unpack('<h', data[4:6])[0] / 32.0)
        send("faults", struct.unpack('<H', data[6:8])[0])
    elif cid == 0x6AA: # TPDO 6
        send("faults2", struct.unpack('<h', data[0:2])[0])
        send("faults3", struct.unpack('<h', data[2:4])[0])
        send("warnings", struct.unpack('<h', data[4:6])[0])
        send("warnings2", struct.unpack('<h', data[6:8])[0])

# --- Main Loop ---
try:
    while True:
        send("smoke_detected", 1.0 if not smoke_sensor.is_pressed else 0.0)

        if mpu:
            accel = mpu.get_accel_data()
            send("accel_x", accel['x'])
            send("accel_y", accel['y'])
            send("accel_z", accel['z'])

        if gps_session.waiting(0.01):
            report = gps_session.next()
            send("gps_lock", getattr(report, 'mode', 0))

        send("lte_status", 1.0) # Placeholder for USB connectivity

        if bus:
            msg = bus.recv(timeout=0.05)
            if msg:
                parse_can(msg)

        time.sleep(0.1)

except KeyboardInterrupt:
    print("\nStopping Collector...")
