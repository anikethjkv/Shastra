import time
import threading
import math
import os
from flask import Flask, render_template, jsonify
from smbus2 import SMBus
from gpiozero import DigitalInputDevice

app = Flask(__name__)

# --- Configuration & Hardware Mapping ---
SMOKE_PIN = 25
MPU_ADDR = 0x68
MPU_SCL_PIN = 3
MPU_SDA_PIN = 2
LTE_UART_PORT = '/dev/ttyAMA0' # GPIO 14/15 usually maps to AMA0 or S0
GPS_USB_PORT = '/dev/ttyACM0'  # Adjust based on your specific USB dongle

# --- Global State (Shared Memory) ---
bike_state = {
    "speed": 0.0,          # km/h
    "distance": 0.0,       # km
    "battery_voltage": 0.0,# Volts
    "smoke_detected": False,
    "gps_status": False,
    "lte_status": False,
    "gyro": {"x": 0, "y": 0, "z": 0},
    "timestamp": 0
}

# --- Hardware Setup ---
# Setup Smoke Sensor (Pull-up/down depends on sensor, assuming active HIGH)
try:
    smoke_sensor = DigitalInputDevice(SMOKE_PIN, pull_up=False) 
except Exception as e:
    print(f"Error init smoke sensor: {e}")
    smoke_sensor = None

# Setup I2C for MPU6050
bus = SMBus(1) # Bus 1 is the default I2C bus on Pi
def read_mpu_word(reg):
    try:
        high = bus.read_byte_data(MPU_ADDR, reg)
        low = bus.read_byte_data(MPU_ADDR, reg+1)
        val = (high << 8) + low
        if (val >= 0x8000): return -((65535 - val) + 1)
        else: return val
    except:
        return 0

# --- Background Task: Data Acquisition & Calculation ---
def hardware_loop():
    global bike_state
    last_time = time.time()
    
    # Initialize MPU6050 (Wake up)
    try:
        bus.write_byte_data(MPU_ADDR, 0x6B, 0)
    except:
        print("MPU6050 not found via I2C")

    while True:
        current_time = time.time()
        dt = current_time - last_time
        
        # 1. SIMULATE CAN DATA (Remove this block when CAN is ready)
        # Simulating speed varying between 0-60 km/h and battery draining
        bike_state["speed"] = (math.sin(current_time * 0.5) + 1) * 30 
        bike_state["battery_voltage"] = 72.0 - (current_time % 100) * 0.1 

        # 2. CALCULATE DISTANCE
        # Distance (km) = Speed (km/h) * Time (h)
        # dt is in seconds, so divide by 3600
        distance_increment = bike_state["speed"] * (dt / 3600.0)
        bike_state["distance"] += distance_increment

        # 3. READ SMOKE SENSOR
        if smoke_sensor:
            bike_state["smoke_detected"] = smoke_sensor.is_active
        
        # 4. READ MPU6050
        # Reading Gyro registers (0x43 to 0x48)
        bike_state["gyro"] = {
            "x": read_mpu_word(0x43),
            "y": read_mpu_word(0x45),
            "z": read_mpu_word(0x47)
        }

        # 5. CHECK PERIPHERALS (GPS/LTE)
        # Simple check if the device path exists
        bike_state["gps_status"] = os.path.exists(GPS_USB_PORT)
        bike_state["lte_status"] = os.path.exists(LTE_UART_PORT)

        last_time = current_time
        time.sleep(0.1) # Update rate 10Hz

# Start background thread
data_thread = threading.Thread(target=hardware_loop)
data_thread.daemon = True
data_thread.start()

# --- Flask Routes ---
@app.route('/')
def index():
    return render_template('index.html')

@app.route('/data')
def get_data():
    return jsonify(bike_state)

if __name__ == '__main__':
    # Run locally for debugging
    app.run(host='0.0.0.0', port=5000, debug=True)