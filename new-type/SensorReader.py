import zmq
import time
from gpiozero import Button
from mpu6050 import mpu6050
from gps import gps, WATCH_ENABLE, WATCH_NEWSTYLE

# --- Configuration ---
ZMQ_ADDRESS = "tcp://localhost:5555"

context = zmq.Context()
socket = context.socket(zmq.REQ)
socket.connect(ZMQ_ADDRESS)

smoke_sensor = Button(23, pull_up=True)
try:
    mpu = mpu6050(0x68)
except:
    mpu = None

gps_session = gps(mode=WATCH_ENABLE | WATCH_NEWSTYLE)

def send(name, value):
    try:
        payload = {"name": name, "value": round(float(value), 4), "mode": "update"}
        socket.send_json(payload)
        socket.recv_string()
    except:
        pass

print("General Sensor Collector (Smoke/GPS/MPU) is running...")

try:
    while True:
        # 1. Smoke Sensor
        send("smoke_detected", 1.0 if not smoke_sensor.is_pressed else 0.0)

        # 2. MPU6050
        if mpu:
            accel = mpu.get_accel_data()
            send("accel_x", accel['x'])
            send("accel_y", accel['y'])
            send("accel_z", accel['z'])

        # 3. GPS
        if gps_session.waiting(0.01):
            report = gps_session.next()
            send("gps_lock", getattr(report, 'mode', 0))

        # 4. LTE Presence
        send("lte_status", 1.0)

        time.sleep(0.5) # General sensors don't need 100Hz updates

except KeyboardInterrupt:
    print("\nStopping General Collector...")
