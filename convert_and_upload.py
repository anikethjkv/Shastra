import sqlite3
import json
import firebase_admin
from firebase_admin import credentials, db

conn = sqlite3.connect("Sensor_data.db")
cursor = conn.cursor()

cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
tables = cursor.fetchall()

all_data = {}

for table in tables:
    table_name = table[0]

    cursor.execute(f"SELECT * FROM {table_name}")
    rows = cursor.fetchall()

    columns = [desc[0] for desc in cursor.description]

    table_data = []
    for row in rows:
        table_data.append(dict(zip(columns, row)))

    all_data[table_name] = table_data

print("DB converted")

cred = credentials.Certificate("serviceAccountKey.json")

firebase_admin.initialize_app(cred, {
    'databaseURL': 'https://shastra-app-90301-default-rtdb.asia-southeast1.firebasedatabase.app'
})

ref = db.reference("sensor_data")
ref.set(all_data)

print("Uploaded to Firebase")