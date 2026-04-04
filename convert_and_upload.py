import json
import os
import sqlite3

DB_PATHS = {
    "sensor": os.environ.get("SENSOR_DB_PATH", "Sensor_data.db").strip() or "Sensor_data.db",
    "can": os.environ.get("CAN_DB_PATH", "Can_data.db").strip() or "Can_data.db",
}
OUTPUT_PATH = os.environ.get("EXPORT_JSON_PATH", "sensor_data_export.json").strip() or "sensor_data_export.json"

all_data = {}
for source_name, db_path in DB_PATHS.items():
    source_tables = {}
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
        tables = cursor.fetchall()

        for table in tables:
            table_name = table[0]
            cursor.execute(f'SELECT * FROM "{table_name}"')
            rows = cursor.fetchall()
            columns = [desc[0] for desc in cursor.description]
            source_tables[table_name] = [dict(zip(columns, row)) for row in rows]
    except sqlite3.Error:
        source_tables = {}
    finally:
        try:
            conn.close()
        except Exception:
            pass

    all_data[source_name] = {
        "db_path": db_path,
        "tables": source_tables,
    }

with open(OUTPUT_PATH, "w", encoding="utf-8") as file_obj:
    json.dump(all_data, file_obj, indent=2)

print(f"Exported Sensor + CAN SQLite data to {OUTPUT_PATH}")