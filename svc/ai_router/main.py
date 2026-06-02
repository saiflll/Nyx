import os
import time
import asyncio
import uuid
import json
import yaml
import httpx
import docker
import cache
import state_db
from tool_scanner import scanner
from fastapi import FastAPI, Request, HTTPException, Depends
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from typing import List, Dict, Optional, Any

app = FastAPI(title="nyxAgent", version="1.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

security = HTTPBearer()
SERVER_ACCESS_KEY = os.getenv("SERVER_ACCESS_KEY", "dev-key-123")

def amankan_rute(credentials: HTTPAuthorizationCredentials = Depends(security)):
    if credentials.credentials != SERVER_ACCESS_KEY:
        raise HTTPException(status_code=401, detail="API Key Server Salah atau Tidak Diberikan")
    return credentials.credentials

# === MODELS ===
class RqstPesan(BaseModel):
    role: str
    content: Optional[str] = None
    tool_calls: Optional[List[Dict[str, Any]]] = None
    tool_call_id: Optional[str] = None

class RqstJob(BaseModel):
    model: Optional[str] = None
    messages: List[RqstPesan]
    jns_task: Optional[str] = "general"
    max_tokens: Optional[int] = 2048
    temperature: Optional[float] = 0.7
    temperatur: Optional[float] = 0.7
    stream: Optional[bool] = False

    def ambl_task(self) -> str:
        if self.model and self.model in ["coding", "reasoning", "general", "sensitive", "fast"]:
            return self.model
        return self.jns_task

# === STATE MACHINE ===
dt_jobs: Dict[str, dict] = {}
global_semaphore = asyncio.Semaphore(1)

try:
    dkr_cln = docker.from_env()
except:
    dkr_cln = None

DEBUG_MODE = os.getenv("DEBUG_MODE", "1") == "1"

def tls_dbg(msg: str):
    if DEBUG_MODE:
        print(msg)

def bangun_qwen():
    if not dkr_cln: return
    try:
        cont = dkr_cln.containers.get("core-qwen-local-1")
        if cont.status == "paused":
            cont.unpause()
            tls_dbg("[DOCKER] Qwen Local berhasil dibangunkan (Unpause)")
    except Exception as e:
        pass
def hndl_err(ctx: str, err: Exception):
    if DEBUG_MODE:
        print(f"[{ctx}] Error: {err}")

# === PROVIDER MANAGER ===
class AiManager:
    def __init__(self):
        self.prov = []
        self.kunci_akun = {} # Map[provider_name] -> List[API Keys]
        self.idx_akun = {}   # Map[provider_name] -> index akun yg aktif (Round Robin)
        self.usage = {}      # Track token usage

    def mt_cfg(self):
        try:
            with open("providers.yml", "r") as f:
                cfg = yaml.safe_load(f)
                self.prov = cfg.get("providers", [])
            for p in self.prov:
                nama = p["nama"]
                env_k = p.get("env_key")
                raw_keys = os.getenv(env_k, "")
                kunci = [k.strip() for k in raw_keys.split(",") if k.strip()]
                self.kunci_akun[nama] = kunci
                self.idx_akun[nama] = 0
                self.usage[nama] = {"req": 0, "token": 0, "limit_hit": 0}
                tls_dbg(f"[mt_cfg] {nama}: {len(kunci)} akun")
        except Exception as err:
            hndl_err("mt_cfg", err)

    def ambl_prov(self, jns_task: str) -> list:
        if jns_task == "sensitive":
            return [p for p in self.prov if p.get("is_local")]
        hsl = [p for p in self.prov if jns_task in p.get("jns_task", []) and not p.get("is_local")]
        hsl.sort(key=lambda x: x.get("priority", 99))
        if not hsl:
            hsl = [p for p in self.prov if not p.get("is_local")]
            hsl.sort(key=lambda x: x.get("priority", 99))
        return hsl

    def ambl_kunci_aktif(self, nama_prov: str) -> str:
        dftr_kunci = self.kunci_akun.get(nama_prov, [])
        if not dftr_kunci:
            return ""
        idx = self.idx_akun.get(nama_prov, 0)
        kunci = dftr_kunci[idx]
        self.idx_akun[nama_prov] = (idx + 1) % len(dftr_kunci)
        return kunci

    async def krm_rqst(self, prov: dict, req: RqstJob) -> dict:
        url = prov["url"]
        kunci = self.ambl_kunci_aktif(prov["nama"])
        if not kunci and not prov.get("is_local"):
            raise ValueError(f"Tidak ada API Key untuk {prov['nama']}")
            
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {kunci}"
        }
        
        pesan_akhir = []
        for m in req.messages:
            pm = {"role": m.role}
            if m.content is not None: pm["content"] = m.content
            if m.tool_calls is not None: pm["tool_calls"] = m.tool_calls
            if m.tool_call_id is not None: pm["tool_call_id"] = m.tool_call_id
            pesan_akhir.append(pm)
            
        if len(scanner.schemas) > 0:
            pesan_akhir.insert(0, {"role": "system", "content": "TOOL EXECUTOR MODE. Output JSON schema only if calling tool. Otherwise apply style guide:\n" + dt_style_guide})
        elif req.ambl_task() == "coding" and dt_style_guide:
            pesan_akhir.insert(0, {"role": "system", "content": f"Coding assistant. Follow style guide:\n{dt_style_guide}"})

        pyld = {
            "model": prov["model_default"],
            "messages": pesan_akhir,
            "max_tokens": req.max_tokens,
            "temperature": req.temperature if req.temperature is not None else req.temperatur
        }
        if len(scanner.schemas) > 0:
            pyld["tools"] = scanner.schemas
        
        is_force = False
        if len(pesan_akhir) > 0 and pesan_akhir[-1]["role"] == "user":
            konten = pesan_akhir[-1].get("content", "")
            if isinstance(konten, str) and "!refresh" in konten:
                is_force = True
                pesan_akhir[-1]["content"] = konten.replace("!refresh", "").strip()
                pyld["messages"] = pesan_akhir
                tls_dbg("[cache] bypass !refresh")
        if not is_force:
            cached = cache.get_cache(pyld)
            if cached:
                tls_dbg(f"[cache] hit — {prov['model_default']}")
                return cached
        async with global_semaphore:
            async with httpx.AsyncClient() as cln:
                rspn = await cln.post(url, headers=headers, json=pyld, timeout=60.0)
                if rspn.status_code == 429:
                    self.usage[prov["nama"]]["limit_hit"] += 1
                rspn.raise_for_status()
                hsl = rspn.json()
                cache.set_cache(pyld, hsl)
                self.usage[prov["nama"]]["req"] += 1
                if "usage" in hsl:
                    self.usage[prov["nama"]]["token"] += hsl["usage"].get("total_tokens", 0)
                return hsl

mngr = AiManager()
dt_style_guide = ""

@app.on_event("startup")
async def startup():
    global dt_style_guide
    mngr.mt_cfg()
    try:
        with open("/app/STYLE_GUIDE.md", "r", encoding="utf-8") as f:
            raw = f.read()
            lines = [l.strip() for l in raw.splitlines() if l.strip()]
            dt_style_guide = " ".join(lines).replace("  ", " ")
        tls_dbg("[startup] Style Guide loaded")
    except Exception as e:
        tls_dbg(f"[startup] Style Guide tidak ada: {e}")

    # Recovery: job yang interrupted saat container mati di-mark FAILED
    recovered = state_db.pulihkan_jobs()
    dt_jobs.update(recovered)
    if recovered:
        tls_dbg(f"[startup] Recovered {len(recovered)} job(s) dari SQLite (marked FAILED)")

    # Cleanup job lama (> 7 hari)
    state_db.brshn_lama()

# === ORCHESTRATOR ===

def _upd_job(job_id: str, **kw):  # update in-memory + persist ke SQLite
    dt_jobs[job_id].update(kw)
    state_db.atr_status(job_id, dt_jobs[job_id]["status"], **{k: v for k, v in kw.items() if k != "status"})

async def prs_job(job_id: str, rqst: RqstJob):
    _upd_job(job_id, status="ROUTING")

    task_real = rqst.ambl_task()
    dftr_prov = mngr.ambl_prov(task_real)
    if not dftr_prov:
        _upd_job(job_id, status="FAILED", error="Tidak ada provider tersedia")
        return
        
    for p in dftr_prov:
        if p.get("is_local"):
            bangun_qwen()
            
        dt_jobs[job_id]["history_prov"].append(p["nama"])
        _upd_job(job_id, status=f"THINKING ({p['nama']})", history_prov=dt_jobs[job_id]["history_prov"])
        try:
            hsl = None
            for step in range(3): # Max 3 tool iterations
                hsl = await mngr.krm_rqst(p, rqst)
                msg_out = hsl.get("choices", [{}])[0].get("message", {})
                tool_calls = msg_out.get("tool_calls")
                
                if tool_calls:
                    _upd_job(job_id, status=f"EXECUTING_TOOL ({p['nama']})")
                    for tc in tool_calls:
                        func_name = tc["function"]["name"]
                        try:
                            args = json.loads(tc["function"]["arguments"])
                            tool_res = scanner.execute_tool(func_name, args)
                        except Exception as e:
                            tool_res = {"error": "Format argumen tidak valid JSON. Perbaiki."}
                            
                        # Update history
                        rqst.messages.append(RqstPesan(role="assistant", content=msg_out.get("content"), tool_calls=tool_calls))
                        rqst.messages.append(RqstPesan(role="tool", content=json.dumps(tool_res), tool_call_id=tc.get("id")))
                    continue # Loop ke LLM lagi
                else:
                    break # Selesai
            
            routing = {
                "provider": p["nama"],
                "model": p["model_default"],
                "multi_account_idx": mngr.idx_akun.get(p["nama"], 0)
            }
            _upd_job(job_id, status="DONE", hasil=hsl, routing=routing)
            return
            
        except httpx.HTTPStatusError as e:
            if e.response.status_code == 429:
                hndl_err("prs_job", Exception(f"Limit API {p['nama']}, mencoba provider lain..."))
                continue
            else:
                hndl_err("prs_job", Exception(f"Error {p['nama']}: {e}"))
                continue
        except Exception as e:
            hndl_err("prs_job", e)
            continue
            
    _upd_job(job_id, status="FAILED", error="Semua provider gagal atau limit habis")


@app.post("/v1/jobs")
async def bt_job(rqst: RqstJob, key: str = Depends(amankan_rute)):
    id_job = str(uuid.uuid4())
    dt_jobs[id_job] = {
        "status": "PENDING",
        "waktu_buat": time.time(),
        "history_prov": [],
        "hasil": None,
        "routing": None,
        "error": None
    }
    state_db.smpn_job(id_job, dt_jobs[id_job])
    asyncio.create_task(prs_job(id_job, rqst))
    return {"job_id": id_job, "status": "PENDING"}

@app.get("/v1/jobs/{job_id}")
async def ck_job(job_id: str):
    if job_id in dt_jobs:
        return dt_jobs[job_id]
    # Fallback: job ada di SQLite tapi sudah keluar dari in-memory (restart lama)
    dt = state_db.ambl_job(job_id)
    if dt:
        return dt
    raise HTTPException(status_code=404, detail="Job tidak ditemukan")

@app.post("/api/ai/v1/chat/completions")
async def chat_legacy(rqst: RqstJob, key: str = Depends(amankan_rute)):
    id_job = str(uuid.uuid4())
    dt_jobs[id_job] = {
        "status": "PENDING",
        "waktu_buat": time.time(),
        "history_prov": [],
        "hasil": None,
        "routing": None,
        "error": None
    }
    state_db.smpn_job(id_job, dt_jobs[id_job])
    await prs_job(id_job, rqst)
    if dt_jobs[id_job]["status"] == "DONE":
        hsl = dt_jobs[id_job]["hasil"]
        hsl["_routing"] = dt_jobs[id_job]["routing"]
        return hsl
    else:
        return JSONResponse(status_code=500, content={"error": dt_jobs[id_job].get("error", "Failed")})

@app.get("/api/ai/usage")
async def ck_usage():
    return {"usage": mngr.usage}

@app.get("/api/skills")
async def ambl_skills():
    return {"skills": [s["function"] for s in scanner.schemas]}

@app.post("/v1/deploy-webhook")
async def deploy_webhook(key: str = Depends(amankan_rute)):
    with open("/app/logs/deploy.trigger", "w") as f:
        f.write(str(time.time()))
    return {"status": "Deploy trigger sent to host watchdog"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
