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
# bounce_time=0.1 → gpiozero ignores transitions faster than 100ms, eliminating GPIO noise.
# pull_up=True  → pin is HIGH at rest; sensor pulls LOW when smoke is detected (active-LOW).
smoke_sensor = Button(23, pull_up=True, bounce_time=0.1)
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
        # pull_up=True: pin is HIGH at idle, LOW when smoke sensor actuates.
        # is_pressed=True  → pin LOW → smoke detected → send 1.0
        # is_pressed=False → pin HIGH (idle)           → send 0.0
        send("smoke_detected", 1.0 if smoke_sensor.is_pressed else 0.0)

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
