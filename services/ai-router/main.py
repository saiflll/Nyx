import os
import time
import asyncio
import uuid
import json
import yaml
import httpx
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Dict, Optional

app = FastAPI(title="Digital Brain AI Router", version="2.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

# =============================================================================
# STYLE GUIDE: snake_case + singkatan (ambl, smpn, bc, hndl_err)
# =============================================================================

# --- STRUCT / MODELS ---
class RqstPesan(BaseModel):
    role: str
    content: str

class RqstJob(BaseModel):
    model: Optional[str] = None   # Tangkap input 'model' dari standar OpenAI (VSCode)
    messages: List[RqstPesan]
    jns_task: Optional[str] = "general"
    max_tokens: Optional[int] = 2048
    temperature: Optional[float] = 0.7   # Standar OpenAI pakai temperature (inggris)
    temperatur: Optional[float] = 0.7    # Fallback Indo
    stream: Optional[bool] = False

    def ambl_task(self) -> str:
        # Jika client (seperti VSCode) mengirim "model": "coding", ubah itu jadi jns_task
        if self.model and self.model in ["coding", "reasoning", "general", "sensitive", "fast"]:
            return self.model
        return self.jns_task

# --- STATE MACHINE (In-Memory) ---
dt_jobs: Dict[str, dict] = {}

def hndl_err(ctx: str, err: Exception):
    print(f"[{ctx}] Error: {err}")

# --- KELOLA PROVIDER & MULTI-ACCOUNT ---
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
                
                # Support multi-account, pisahkan koma
                kunci = [k.strip() for k in raw_keys.split(",") if k.strip()]
                self.kunci_akun[nama] = kunci
                self.idx_akun[nama] = 0
                self.usage[nama] = {"req": 0, "token": 0, "limit_hit": 0}
                
                print(f"[mt_cfg] Load {nama}: {len(kunci)} akun")
        except Exception as err:
            hndl_err("mt_cfg", err)

    def ambl_prov(self, jns_task: str) -> list:
        # Jika sensitif, PAKSA ke Qwen Lokal saja
        if jns_task == "sensitive":
            return [p for p in self.prov if p.get("is_local")]
            
        # Filter berdasarkan task dan urutkan priority
        hsl = [p for p in self.prov if jns_task in p.get("jns_task", []) and not p.get("is_local")]
        hsl.sort(key=lambda x: x.get("priority", 99))
        
        # Jika tidak ada yg cocok, fallback ke semua eksternal
        if not hsl:
            hsl = [p for p in self.prov if not p.get("is_local")]
            hsl.sort(key=lambda x: x.get("priority", 99))
        return hsl

    def ambl_kunci_aktif(self, nama_prov: str) -> str:
        dftr_kunci = self.kunci_akun.get(nama_prov, [])
        if not dftr_kunci:
            return ""
            
        # Round-Robin multi account
        idx = self.idx_akun.get(nama_prov, 0)
        kunci = dftr_kunci[idx]
        
        # Putar index ke akun berikutnya untuk request selanjutnya
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
        
        pesan_akhir = [{"role": m.role, "content": m.content} for m in req.messages]
        
        # Injeksi Style Guide jika task berkaitan dengan coding
        if req.ambl_task() == "coding" and dt_style_guide:
            pesan_akhir.insert(0, {"role": "system", "content": f"Kamu adalah AI asisten coding. WAJIB ikuti style guide berikut:\n{dt_style_guide}"})

        pyld = {
            "model": prov["model_default"],
            "messages": pesan_akhir,
            "max_tokens": req.max_tokens,
            "temperature": req.temperature if req.temperature is not None else req.temperatur
        }
        
        async with httpx.AsyncClient() as cln:
            rspn = await cln.post(url, headers=headers, json=pyld, timeout=60.0)
            if rspn.status_code == 429: # Rate limit hit!
                self.usage[prov["nama"]]["limit_hit"] += 1
            rspn.raise_for_status()
            hsl = rspn.json()
            
            # Catat usage
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
            # Kompresi untuk hemat token: hapus baris kosong dan multiple spaces
            lines = [l.strip() for l in raw.splitlines() if l.strip()]
            dt_style_guide = " ".join(lines).replace("  ", " ")
        print("[startup] Style Guide berhasil dimuat & dikompres (Hemat Token!)")
    except Exception as e:
        print(f"[startup] Gagal muat Style Guide (abaikan jika tidak ada): {e}")

# =============================================================================
# STATE MACHINE / ORCHESTRATOR
# =============================================================================

async def prs_job(job_id: str, rqst: RqstJob):
    dt_jobs[job_id]["status"] = "ROUTING"
    
    task_real = rqst.ambl_task()
    dftr_prov = mngr.ambl_prov(task_real)
    if not dftr_prov:
        dt_jobs[job_id]["status"] = "FAILED"
        dt_jobs[job_id]["error"] = "Tidak ada provider tersedia"
        return
        
    for p in dftr_prov:
        dt_jobs[job_id]["status"] = f"THINKING ({p['nama']})"
        dt_jobs[job_id]["history_prov"].append(p["nama"])
        try:
            hsl = await mngr.krm_rqst(p, rqst)
            
            # Validation (bisa ditambah logic State Machine di sini, ex: if salah format -> RETRY)
            
            dt_jobs[job_id]["status"] = "DONE"
            dt_jobs[job_id]["hasil"] = hsl
            dt_jobs[job_id]["routing"] = {
                "provider": p["nama"],
                "model": p["model_default"],
                "multi_account_idx": mngr.idx_akun.get(p["nama"], 0)
            }
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
            
    dt_jobs[job_id]["status"] = "FAILED"
    dt_jobs[job_id]["error"] = "Semua provider gagal atau limit habis"


@app.post("/v1/jobs")
async def bt_job(rqst: RqstJob):
    # Buat Job ID unik
    id_job = str(uuid.uuid4())
    dt_jobs[id_job] = {
        "status": "PENDING",
        "waktu_buat": time.time(),
        "history_prov": [],
        "hasil": None,
        "error": None
    }
    
    # Jalankan background task
    asyncio.create_task(prs_job(id_job, rqst))
    
    return {"job_id": id_job, "status": "PENDING"}

@app.get("/v1/jobs/{job_id}")
async def ck_job(job_id: str):
    if job_id not in dt_jobs:
        raise HTTPException(status_code=404, detail="Job tidak ditemukan")
    return dt_jobs[job_id]

# Endpoint Legacy / Synchronous (tetap ada untuk backward compatibility SvelteKit UI saat ini)
@app.post("/api/ai/v1/chat/completions")
async def chat_legacy(rqst: RqstJob):
    id_job = str(uuid.uuid4())
    dt_jobs[id_job] = {"status": "PENDING", "history_prov": []}
    
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

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
