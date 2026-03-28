import os
import sqlite3
import firebase_admin
from firebase_admin import credentials, db

DB_PATH = os.environ.get("SQLITE_DB_PATH", "Sensor_data.db").strip() or "Sensor_data.db"
SERVICE_ACCOUNT_PATH = os.environ.get("FIREBASE_SERVICE_ACCOUNT", "").strip()
DATABASE_URL = os.environ.get("FIREBASE_DATABASE_URL", "").strip()
FIREBASE_NODE = os.environ.get("FIREBASE_NODE", "sensor_data").strip() or "sensor_data"

if not SERVICE_ACCOUNT_PATH or not DATABASE_URL:
    raise RuntimeError(
        "Missing Firebase configuration. Set FIREBASE_SERVICE_ACCOUNT and FIREBASE_DATABASE_URL environment variables."
    )

conn = sqlite3.connect(DB_PATH)
try:
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
finally:
    conn.close()

print("DB converted")

cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
try:
    app = firebase_admin.get_app()
except ValueError:
    app = firebase_admin.initialize_app(cred, {"databaseURL": DATABASE_URL})

ref = db.reference(FIREBASE_NODE, app=app)
ref.set(all_data)

print("Uploaded to Firebase")