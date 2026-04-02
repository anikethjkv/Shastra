import time
from gpiozero import Button
from mpu6050 import mpu6050
from gps import gps, WATCH_ENABLE, WATCH_NEWSTYLE

import os
import sqlite3

# --- Configuration ---
DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Sensor_data.db")

db_conn = sqlite3.connect(DB_PATH, check_same_thread=False)
db_conn.execute("PRAGMA journal_mode=WAL")
db_conn.execute("CREATE TABLE IF NOT EXISTS latest_readings (sensor_name TEXT UNIQUE, reading_value REAL)")
db_conn.commit()

# --- Sensors ---
smoke_sensor = Button(23, pull_up=True)
try:
    mpu = mpu6050(0x68)
except:
    mpu = None

try:
    gps_session = gps(mode=WATCH_ENABLE | WATCH_NEWSTYLE)
except:
    gps_session = None

def send(name, value):
    try:
        db_conn.execute(
            "INSERT INTO latest_readings (sensor_name, reading_value) VALUES (?, ?) "
            "ON CONFLICT(sensor_name) DO UPDATE SET reading_value=excluded.reading_value",
            (name, round(float(value), 4))
        )
    except:
        pass

print("General Sensor Collector (Smoke/GPS/MPU) is running...")

try:
    while True:
        # 1. Smoke Sensor
        send("smoke_detected", 1.0 if smoke_sensor.is_pressed else 0.0)  # LOW = smoke (pull_up=True, LOW = active)

        # 2. MPU6050
        if mpu:
            accel = mpu.get_accel_data()
            send("accel_x", accel['x'])
            send("accel_y", accel['y'])
            send("accel_z", accel['z'])

        # 3. GPS
        if gps_session and gps_session.waiting(0.01):
            report = gps_session.next()
            send("gps_lock", getattr(report, 'mode', 0))

        # 4. LTE Presence
        send("lte_status", 1.0)
        
        db_conn.commit()
        time.sleep(0.5) # General sensors don't need 100Hz updates

except KeyboardInterrupt:
    print("\nStopping General Collector...")
