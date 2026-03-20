import sqlite3
import zmq

DB_NAME = "Sensor_data.db"

# Setup ZeroMQ Server
context = zmq.Context()
socket = context.socket(zmq.REP) # Reply mode
socket.bind("tcp://*:5555")

def init_db():
    conn = sqlite3.connect(DB_NAME)
    conn.execute("PRAGMA journal_mode=WAL")  # Allow concurrent reads from api_server
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

import json

def handle_command(data):
    """Handle command-based requests (get_value, get_distance) from Cancom.py."""
    command = data.get("command")
    name = data.get("name", "")
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()

    if command == "get_value":
        cursor.execute("SELECT reading_value FROM latest_readings WHERE sensor_name = ?", (name,))
        row = cursor.fetchone()
        conn.close()
        if row:
            return json.dumps({"status": "OK", "value": row[0]})
        return json.dumps({"status": "OK", "value": 0})

    elif command == "get_distance":
        cursor.execute("SELECT reading_value FROM latest_readings WHERE sensor_name = 'total_distance'")
        row = cursor.fetchone()
        conn.close()
        if row:
            return json.dumps({"status": "OK", "value": row[0]})
        return json.dumps({"status": "OK", "value": 0.0})

    conn.close()
    return json.dumps({"status": "ERROR", "message": "Unknown command"})

init_db()
print("SQL Writer is active and listening...")

while True:
    message = socket.recv_json()  # Receive data from sensor script
    try:
        if "command" in message:
            # Command request — reply with JSON
            result = handle_command(message)
            socket.send_string(result)
        else:
            # Regular data update — reply with plain string
            handle_data(message)
            socket.send_string("OK")
    except Exception as e:
        print(f"Error: {e}")
        socket.send_string(f"Error: {e}")