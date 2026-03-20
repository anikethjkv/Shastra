import sqlite3
import time
from gpiozero import Button
from mpu6050 import mpu6050
from gps import gps, WATCH_ENABLE, WATCH_NEWSTYLE

# --- Configuration ---
DB_NAME = "Sensor_data.db"
# Smoke Sensor on GPIO 23. pull_up=False because your notes say "LOW as +ve Sense"
smoke_sensor = Button(23, pull_up=False) 
# MPU6050 at default address 0x68
mpu = mpu6050(0x68)

# --- GPSD Setup ---
# This requires the gpsd service to be running: sudo systemctl start gpsd
gps_session = gps(mode=WATCH_ENABLE | WATCH_NEWSTYLE)

# Run this once to create the starting points for the script
conn = sqlite3.connect("Sensor_data.db")
cursor = conn.cursor()
cursor.execute("CREATE TABLE IF NOT EXISTS bike_data (sensor_name TEXT UNIQUE, reading_value REAL)")

# Insert the initial placeholders
sensors = ["smoke_detected", "accel_x", "accel_y", "accel_z", "temp_c", "gps_lock_status"]
for s in sensors:
    cursor.execute("INSERT OR IGNORE INTO bike_data (sensor_name, reading_value) VALUES (?, 0.0)", (s,))

conn.commit()
conn.close()

def log_to_db(sensor_name, reading_value):
    """Updates an existing sensor entry in the SQLite database."""
    try:
        conn = sqlite3.connect(DB_NAME)
        cursor = conn.cursor()
        # This command finds the row with the matching name and updates the value
        cursor.execute(
            "UPDATE bike_data SET reading_value = ? WHERE sensor_name = ?",
            (reading_value, sensor_name)
        )
        print(f"Loop Enter Sensor value to DB: {sensor_name}")
        conn.commit()
        conn.close()
    except Exception as e:
        print(f"Database error: {e}")
        
def get_gps_status():
    """Checks GPSD for lock status without hanging."""
    # This waits for a maximum of 0.1 seconds for data
    if gps_session.waiting(0.1): 
        report = gps_session.next()
        if hasattr(report, 'mode'):
            return report.mode
    return 0 # Return 0 (no lock) if no data is ready
    
print("Starting Bike Data Logger... Press Ctrl+C to stop.")

try:
    while True:
        # 1. Smoke Sensor (Digital)
        # If 'is_pressed' is true (Logic HIGH from your converter), smoke is detected.
        smoke_status = 1.0 if smoke_sensor.is_pressed else 0.0
        log_to_db("smoke_detected", smoke_status)

        # 2. MPU6050 (I2C)
        accel_data = mpu.get_accel_data()
        gyro_data = mpu.get_gyro_data()
        temp = mpu.get_temp()

        log_to_db("accel_x", accel_data['x'])
        log_to_db("accel_y", accel_data['y'])
        log_to_db("accel_z", accel_data['z'])
        log_to_db("temp_c", temp)

        # 3. GPS Status (via GPSD)
        gps_mode = get_gps_status()
        log_to_db("gps_lock_status", float(gps_mode))

        print(f"Logged: Smoke={smoke_status}, AccelX={accel_data['x']:.2f}, GPS_Mode={gps_mode}")
        
        # Adjust frequency as needed
        time.sleep(1)

except KeyboardInterrupt:
    print("\nLogging stopped by user.")
