import sqlite3
import time
import os

DB_NAME = "Sensor_data.db"

def clear_terminal():
    # Clears the terminal screen for a clean "Live" feel
    os.system('cls' if os.name == 'nt' else 'clear')

def read_database():
    try:
        conn = sqlite3.connect(DB_NAME)
        cursor = conn.cursor()

        # 1. Fetch Latest Readings
        print("=== LATEST SENSOR READINGS (Live Dashboard) ===")
        print(f"{'Sensor Name':<20} | {'Value':<10}")
        print("-" * 35)
        cursor.execute("SELECT sensor_name, reading_value FROM latest_readings")
        latest = cursor.fetchall()
        for row in latest:
            print(f"{row[0]:<20} | {row[1]:<10.2f}")

        print("\n")

        # 2. Fetch Last 5 Historical Readings
        print("=== HISTORICAL DATA (Last 5 Logs) ===")
        print(f"{'Timestamp':<20} | {'Sensor':<10} | {'Value':<10}")
        print("-" * 45)
        cursor.execute("SELECT timestamp, sensor_name, reading_value FROM historical_readings ORDER BY timestamp DESC LIMIT 5")
        history = cursor.fetchall()
        for row in history:
            print(f"{row[0]:<20} | {row[1]:<10} | {row[2]:<10.2f}")

        conn.close()
    except sqlite3.OperationalError:
        print("Database not found or tables not created yet. Waiting for data...")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    print("Starting DB Viewer... Press Ctrl+C to exit.")
    time.sleep(1)
    try:
        while True:
            clear_terminal()
            read_database()
            time.sleep(1) # Refresh rate: 1 second
    except KeyboardInterrupt:
        print("\nViewer stopped.")