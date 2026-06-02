import os
import asyncio
import httpx

# =============================================================================
# Alert Bot — Telegram Notifier
# Mengirim notifikasi saat RAM/CPU kritis atau service mati
# =============================================================================

TKN_BOT = os.getenv("TELEGRAM_BOT_TOKEN")
ID_CHAT = os.getenv("TELEGRAM_CHAT_ID")

async def krm_psn(pesan: str) -> bool:
    if not TKN_BOT or not ID_CHAT:
        print("TKN_BOT atau ID_CHAT tidak ada, skip krm_psn")
        return False

    url = f"https://api.telegram.org/bot{TKN_BOT}/sendMessage"
    payload = {
        "chat_id": ID_CHAT,
        "text": pesan,
        "parse_mode": "Markdown"
    }

    try:
        async with httpx.AsyncClient() as cln:
            rspn = await cln.post(url, json=payload, timeout=10.0)
            if rspn.status_code == 200:
                print(f"Sukses ngrm pesan: {pesan}")
                return True
            else:
                print(f"Gagal ngrm pesan: {rspn.text}")
                return False
    except Exception as err:
        hndl_err("krm_psn", err)
        return False

def hndl_err(ctx: str, err: Exception):
    print(f"[{ctx}] {err}")

async def ck_health():
    # Contoh fungsi untuk cek health nginx, ini bisa diperluas
    try:
        async with httpx.AsyncClient() as cln:
            rspn = await cln.get("http://nginx/health", timeout=5.0)
            return rspn.status_code == 200
    except:
        return False

async def mlu_bot():
    print("Bot mlu (running)...")
    await krm_psn("✅ *Server AI Note 10S Online*\nBot alert telah aktif.")
    
    while True:
        # Loop cek rutin tiap 5 menit
        await asyncio.sleep(300)
        
        # Cek Nginx health sbg indikator server hidup
        hsl_health = await ck_health()
        if not hsl_health:
            await krm_psn("🔴 *PERINGATAN*: Nginx tidak merespon! Cek service.")
            
if __name__ == "__main__":
    asyncio.run(mlu_bot())
