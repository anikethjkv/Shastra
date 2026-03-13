import sqlite3
import zmq

DB_NAME = "Sensor_data.db"

# Setup ZeroMQ Server
context = zmq.Context()
socket = context.socket(zmq.REP) # Reply mode
socket.bind("tcp://*:5555")

def init_db():
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()
    # Table for Overwriting (Latest values)
    cursor.execute("CREATE TABLE IF NOT EXISTS latest_readings (sensor_name TEXT UNIQUE, reading_value REAL)")
    # Table for Appending (Historical data)
    cursor.execute("CREATE TABLE IF NOT EXISTS historical_readings (timestamp DATETIME DEFAULT CURRENT_TIMESTAMP, sensor_name TEXT, reading_value REAL)")
    conn.commit()
    conn.close()

def handle_data(data):
    # data format: {"name": "accel_x", "value": 9.81, "mode": "update"} 
    # mode can be "update" or "append"
    name = data['name']
    val = data['value']
    mode = data.get('mode', 'update')

    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()

    if mode == "update":
        # Overwrite: Insert if new, update if exists
        cursor.execute("""
            INSERT INTO latest_readings (sensor_name, reading_value) VALUES (?, ?)
            ON CONFLICT(sensor_name) DO UPDATE SET reading_value=excluded.reading_value
        """, (name, val))
    
    # Always append to history if requested, or keep it separate
    if mode == "append":
        cursor.execute("INSERT INTO historical_readings (sensor_name, reading_value) VALUES (?, ?)", (name, val))

    conn.commit()
    conn.close()

init_db()
print("SQL Writer is active and listening...")

while True:
    message = socket.recv_json() # Receive data from sensor script
    try:
        handle_data(message)
        socket.send_string("OK") # Signal success
    except Exception as e:
        print(f"Error: {e}")
        socket.send_string(f"Error: {e}")