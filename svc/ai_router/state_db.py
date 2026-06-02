import sqlite3
import json
import time
import os

JOBS_DB = "/app/logs/jobs.db"
if not os.path.exists("/app/logs"):
    JOBS_DB = "logs/jobs.db"
    os.makedirs("logs", exist_ok=True)

def _conn() -> sqlite3.Connection:
    conn = sqlite3.connect(JOBS_DB)
    conn.row_factory = sqlite3.Row
    conn.execute('''CREATE TABLE IF NOT EXISTS jobs (
        job_id      TEXT PRIMARY KEY,
        status      TEXT NOT NULL,
        waktu_buat  REAL NOT NULL,
        history_prov TEXT NOT NULL DEFAULT '[]',
        hasil       TEXT,
        routing     TEXT,
        error       TEXT,
        updated_at  REAL NOT NULL
    )''')
    return conn

def _srl(v) -> str | None:  # serialize ke JSON string, None-safe
    return json.dumps(v) if v is not None else None

def _dsl(v) -> dict | list | None:  # deserialize dari JSON string, None-safe
    return json.loads(v) if v is not None else None

# === WRITE ===

def smpn_job(job_id: str, dt: dict):
    with _conn() as conn:
        conn.execute('''INSERT OR REPLACE INTO jobs
            (job_id, status, waktu_buat, history_prov, hasil, routing, error, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)''', (
            job_id,
            dt.get("status", "PENDING"),
            dt.get("waktu_buat", time.time()),
            _srl(dt.get("history_prov", [])),
            _srl(dt.get("hasil")),
            _srl(dt.get("routing")),
            dt.get("error"),
            time.time()
        ))

def atr_status(job_id: str, status: str, **extra):
    fields = ["status=?", "updated_at=?"]
    values = [status, time.time()]
    for k, v in extra.items():
        fields.append(f"{k}=?")
        values.append(_srl(v) if isinstance(v, (dict, list)) else v)
    values.append(job_id)
    with _conn() as conn:
        conn.execute(f"UPDATE jobs SET {', '.join(fields)} WHERE job_id=?", values)

# === READ ===

def ambl_job(job_id: str) -> dict | None:
    with _conn() as conn:
        row = conn.execute("SELECT * FROM jobs WHERE job_id=?", (job_id,)).fetchone()
    if not row:
        return None
    return {
        "status":       row["status"],
        "waktu_buat":   row["waktu_buat"],
        "history_prov": _dsl(row["history_prov"]) or [],
        "hasil":        _dsl(row["hasil"]),
        "routing":      _dsl(row["routing"]),
        "error":        row["error"]
    }

# === STARTUP RECOVERY ===

def pulihkan_jobs() -> dict:
    """
    Dipanggil saat startup. Job yang masih PENDING/ROUTING/THINKING
    artinya container mati di tengah jalan — tandai sebagai FAILED.
    Kembalikan dict untuk dipopulasikan ke dt_jobs in-memory.
    """
    interrupted = ("PENDING", "ROUTING", "THINKING", "EXECUTING_TOOL")
    hsl = {}
    with _conn() as conn:
        rows = conn.execute(
            f"SELECT * FROM jobs WHERE status IN ({','.join('?'*len(interrupted))})",
            interrupted
        ).fetchall()
        for row in rows:
            job_id = row["job_id"]
            hsl[job_id] = {
                "status":       "FAILED",
                "waktu_buat":   row["waktu_buat"],
                "history_prov": _dsl(row["history_prov"]) or [],
                "hasil":        None,
                "routing":      None,
                "error":        "Interrupted — container restarted"
            }
            conn.execute(
                "UPDATE jobs SET status='FAILED', error=?, updated_at=? WHERE job_id=?",
                ("Interrupted — container restarted", time.time(), job_id)
            )
    return hsl

# === CLEANUP ===

def brshn_lama(max_age_seconds: int = 86400 * 7):
    cutoff = time.time() - max_age_seconds
    with _conn() as conn:
        conn.execute("DELETE FROM jobs WHERE waktu_buat < ?", (cutoff,))
