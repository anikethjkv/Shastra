#!/usr/bin/env python3
"""Utilities to convert SQLite data and upload it to Firebase RTDB."""

import sqlite3
from typing import Dict, List, Any


def convert_sqlite_to_jsonable(db_path: str) -> Dict[str, List[Dict[str, Any]]]:
    conn = sqlite3.connect(db_path)
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
        tables = [row[0] for row in cursor.fetchall()]

        all_data: Dict[str, List[Dict[str, Any]]] = {}
        for table_name in tables:
            cursor.execute(f'SELECT * FROM "{table_name}"')
            rows = cursor.fetchall()
            columns = [desc[0] for desc in cursor.description] if cursor.description else []
            all_data[table_name] = [dict(zip(columns, row)) for row in rows]

        return all_data
    finally:
        conn.close()


def upload_json_to_firebase(payload: Dict[str, Any], service_account_path: str, database_url: str, node: str = "sensor_data") -> None:
    import firebase_admin
    from firebase_admin import credentials, db

    try:
        app = firebase_admin.get_app()
    except ValueError:
        cred = credentials.Certificate(service_account_path)
        app = firebase_admin.initialize_app(cred, {"databaseURL": database_url})

    ref = db.reference(node, app=app)
    ref.set(payload)


def sync_sqlite_to_firebase(db_path: str, service_account_path: str, database_url: str, node: str = "sensor_data") -> Dict[str, Any]:
    payload = convert_sqlite_to_jsonable(db_path)
    upload_json_to_firebase(payload, service_account_path, database_url, node=node)
    return {
        "tables": len(payload),
        "node": node,
    }
