import time, threading, math, logging, os, serial, pynmea2
from flask import Flask, render_template, jsonify
from smbus2 import SMBus
from gpiozero import DigitalInputDevice

# --- Terminal Logging Setup ---
logging.basicConfig(level=logging.INFO, format='%(asctime)s - [GPIO LOG] - %(message)s')
app = Flask(__name__)

# --- State & Config ---
SMOKE_PIN = 23 # Physical Pin 16
MPU_ADDR = 0x68
bike_state = {
    "speed": 0.0, "distance": 0.0, "battery_voltage": 72.0, "temperature": 55.0,
    "smoke_detected": False, "gps_status": False, "lte_status": False,
    "lat": 12.9716, "lon": 77.5946, "gyro": {"x": 0, "y": 0, "z": 0}
}

# --- Hardware Initialization ---
try:
    smoke_sensor = DigitalInputDevice(SMOKE_PIN, pull_up=True) # Logic 0 = Fire
    logging.info(f"Smoke sensor on GPIO {SMOKE_PIN} ready.")
except Exception as e:
    logging.error(f"GPIO {SMOKE_PIN} busy or failed: {e}")
    smoke_sensor = None

try:
    bus = SMBus(1)
    bus.write_byte_data(MPU_ADDR, 0x6B, 0)
    logging.info("MPU6050 detected.")
except: bus = None

def hardware_loop():
    global bike_state
    gps_serial = None
    try:
        gps_serial = serial.Serial('/dev/ttyACM0', 9600, timeout=1)
    except: logging.warning("GPS not found on /dev/ttyACM0")

    while True:
        # 1. GPS Processing
        if gps_serial and gps_serial.in_waiting:
            try:
                line = gps_serial.readline().decode('ascii', errors='replace')
                if line.startswith('$GPRMC'):
                    msg = pynmea2.parse(line)
                    if msg.status == 'A':
                        bike_state.update({"lat": msg.latitude, "lon": msg.longitude, "gps_status": True})
                        bike_state["speed"] = float(msg.speedoverground) * 1.852 # Knots to KMH
            except: pass

        # 2. Smoke Logic (Logic 0 = FIRE)
        if smoke_sensor:
            bike_state["smoke_detected"] = (smoke_sensor.value == 0)

        # 3. Dummy Temp for Bar testing
        bike_state["temperature"] = 55 + (math.sin(time.time() * 0.1) * 20)
        time.sleep(0.1)

# Start background thread BEFORE Flask
threading.Thread(target=hardware_loop, daemon=True).start()

@app.route('/')
def index(): return render_template('index.html')

@app.route('/data')
def get_data(): return jsonify(bike_state)

if __name__ == '__main__':
    logging.info("Starting Flask server...")
    app.run(host='127.0.0.1', port=5000, debug=False, use_reloader=False)
