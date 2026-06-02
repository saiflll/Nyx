import sqlite3
import hashlib
import json
import time
import os

CACHE_DB = "/app/logs/router_cache.db"

os.makedirs(os.path.dirname(CACHE_DB), exist_ok=True)

def _get_conn():
    conn = sqlite3.connect(CACHE_DB)
    conn.execute('''CREATE TABLE IF NOT EXISTS api_cache
                 (hash_key TEXT PRIMARY KEY,
                  response TEXT,
                  timestamp REAL)''')
    return conn

def _hash_payload(pyld: dict) -> str:
    clean_pyld = {k: v for k, v in pyld.items() if k not in ['temperature']}
    s = json.dumps(clean_pyld, sort_keys=True)
    return hashlib.md5(s.encode('utf-8')).hexdigest()

def get_cache(pyld: dict, max_age_seconds: int = 86400):
    h = _hash_payload(pyld)
    with _get_conn() as conn:
        c = conn.cursor()
        c.execute("SELECT response, timestamp FROM api_cache WHERE hash_key=?", (h,))
        row = c.fetchone()
        if row:
            resp, ts = row
            if time.time() - ts <= max_age_seconds:
                return json.loads(resp)
            else:
                c.execute("DELETE FROM api_cache WHERE hash_key=?", (h,))
    return None

def set_cache(pyld: dict, response: dict):
    h = _hash_payload(pyld)
    with _get_conn() as conn:
        conn.execute("INSERT OR REPLACE INTO api_cache (hash_key, response, timestamp) VALUES (?, ?, ?)",
                     (h, json.dumps(response), time.time()))
