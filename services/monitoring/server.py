"""
Monitoring API Server — expose metrics via HTTP (SSE + REST)
STYLE GUIDE: snake_case + singkatan (bc, jln, mlu, dll)
"""
import asyncio
import json
from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import StreamingResponse
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="Monitoring API")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

FL_DT = Path("/data/metrics.json")
RIWAYAT = []
MAX_RWYT = 360  # 1 jam

async def bc_dt() -> dict:
    if FL_DT.exists():
        try:
            return json.loads(FL_DT.read_text())
        except Exception:
            pass
    return {}

@app.on_event("startup")
async def mlu_srv():
    """Start collector shell script"""
    asyncio.create_task(jln_kolektor())
    asyncio.create_task(smpn_rwyt())

async def jln_kolektor():
    proc = await asyncio.create_subprocess_exec(
        "/app/collector.sh",
        stdout=asyncio.subprocess.DEVNULL,
        stderr=asyncio.subprocess.DEVNULL,
    )
    await proc.wait()

async def smpn_rwyt():
    while True:
        m = await bc_dt()
        if m:
            RIWAYAT.append(m)
            if len(RIWAYAT) > MAX_RWYT:
                RIWAYAT.pop(0)
        await asyncio.sleep(10)

@app.get("/health")
async def ck_health():
    return {"status": "ok", "service": "monitoring"}

@app.get("/metrics")
async def ambl_dt():
    return await bc_dt()

@app.get("/history")
async def ambl_rwyt(limit: int = 60):
    return {"history": RIWAYAT[-limit:], "total": len(RIWAYAT)}

@app.get("/stream")
async def strm_dt():
    """Server-Sent Events untuk real-time update"""
    async def gen_ev():
        wkt_akhir = 0
        while True:
            m = await bc_dt()
            if m and m.get("timestamp", 0) != wkt_akhir:
                wkt_akhir = m.get("timestamp", 0)
                yield f"data: {json.dumps(m)}\n\n"
            await asyncio.sleep(5)

    return StreamingResponse(
        gen_ev(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8099)
