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
        # Build a lookup dict for quick access
        readings = {}
        for row in latest:
            readings[row[0]] = row[1]
            print(f"{row[0]:<20} | {row[1]:<10.2f}")

        # 2. BMS Battery Data (dedicated section)
        bms_keys = [
            "bms_total_voltage", "bms_current", "bms_rem_cap",
            "bms_full_cap", "bms_cycles", "bms_soc",
            "bms_strings", "bms_ntc_count",
            "bms_ntc1", "bms_ntc2", "bms_ntc3", "bms_ntc4", "bms_ntc5"
        ]
        bms_units = {
            "bms_total_voltage": "V", "bms_current": "A",
            "bms_rem_cap": "mAh", "bms_full_cap": "mAh",
            "bms_cycles": "cycles", "bms_soc": "%",
            "bms_strings": "S", "bms_ntc_count": "probes",
            "bms_ntc1": "°C", "bms_ntc2": "°C", "bms_ntc3": "°C",
            "bms_ntc4": "°C", "bms_ntc5": "°C"
        }
        has_bms = any(k in readings for k in bms_keys)
        if has_bms:
            print("\n=== BMS BATTERY DATA ===")
            print(f"{'Parameter':<22} | {'Value':<10} | {'Unit'}")
            print("-" * 45)
            for key in bms_keys:
                if key in readings:
                    label = key.replace("bms_", "").replace("_", " ").title()
                    unit = bms_units.get(key, "")
                    print(f"{label:<22} | {readings[key]:<10.2f} | {unit}")

        print("\n")

        # 3. Fetch Last 5 Historical Readings
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