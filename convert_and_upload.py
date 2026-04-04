import json
import os
import sqlite3

DB_PATH = os.environ.get("SQLITE_DB_PATH", "Sensor_data.db").strip() or "Sensor_data.db"
OUTPUT_PATH = os.environ.get("EXPORT_JSON_PATH", "sensor_data_export.json").strip() or "sensor_data_export.json"

conn = sqlite3.connect(DB_PATH)
cursor = conn.cursor()

cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
tables = cursor.fetchall()

all_data = {}

for table in tables:
    table_name = table[0]
    cursor.execute(f'SELECT * FROM "{table_name}"')
    rows = cursor.fetchall()
    columns = [desc[0] for desc in cursor.description]
    all_data[table_name] = [dict(zip(columns, row)) for row in rows]

conn.close()

with open(OUTPUT_PATH, "w", encoding="utf-8") as file_obj:
    json.dump(all_data, file_obj, indent=2)

print(f"Exported SQLite data from {DB_PATH} to {OUTPUT_PATH}")