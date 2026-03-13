import zmq
import time
import random

# Setup ZMQ Client
context = zmq.Context()
socket = context.socket(zmq.REQ)
socket.connect("tcp://localhost:5555")

def send_to_writer(name, value, mode="update"):
    """Sends fake sensor data to the SQL Writer script."""
    payload = {"name": name, "value": value, "mode": mode}
    try:
        socket.send_json(payload)
        response = socket.recv_string()
        return response
    except Exception as e:
        return f"Connection Error: {e}"

print("Starting Mock Sensor Test... Press Ctrl+C to stop.")

try:
    while True:
        # 1. Simulate Smoke (Randomly 0 or 1)
        smoke_status = float(random.choice([0, 1]))
        send_to_writer("smoke_detected", smoke_status, mode="update")

        # 2. Simulate Accel (Random floats)
        ax = random.uniform(-1.0, 1.0)
        ay = random.uniform(-1.0, 1.0)
        az = random.uniform(9.0, 10.0) # Gravity-ish
        send_to_writer("accel_x", ax, mode="append")
        send_to_writer("accel_y", ay, mode="append")
        send_to_writer("accel_z", az, mode="append")

        # 3. Simulate Temp (Fluctuating around 25C)
        temp = 25.0 + random.uniform(-0.5, 0.5)
        send_to_writer("temp_c", temp, mode="update")

        # 4. Simulate GPS (Lock modes 0-3)
        gps_mode = float(random.randint(0, 3))
        send_to_writer("gps_lock_status", gps_mode, mode="update")

        print(f"Sent Mock Data: Smoke={smoke_status}, Temp={temp:.2f}, GPS={gps_mode}")
        
        # Wait 2 seconds between bursts
        time.sleep(2)

except KeyboardInterrupt:
    print("\nMock testing stopped.")