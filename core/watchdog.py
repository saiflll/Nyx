import time
import docker
import os

# Watchdog untuk membekukan kontainer Qwen jika tidak ada request sensitive.
# Dalam environment production, ini bisa membaca Nginx logs.
# Untuk simulasi, kita memantau waktu sejak terakhir kali Qwen dipanggil via router.
# Namun karena kita butuh trigger "unpause" secara instan saat request datang,
# unpause akan dihandle langsung oleh ai-router. Watchdog hanya bertugas melakukan pause.

DEBUG_MODE = os.getenv("DEBUG_MODE", "1") == "1"

def tls_dbg(msg: str):
    if DEBUG_MODE:
        print(msg)

try:
    client = docker.from_env()
except:
    client = None
    tls_dbg("Docker socket tidak tersedia. Fitur freezing dinonaktifkan.")

def freeze_container(container_name="qwen-local"):
    if not client: return
    try:
        container = client.containers.get(container_name)
        if container.status == "running":
            container.pause()
            tls_dbg(f"[Watchdog] Kontainer {container_name} dibekukan (Pause) karena idle.")
    except Exception as e:
        tls_dbg(f"Gagal pause kontainer: {e}")

if __name__ == "__main__":
    tls_dbg("Watchdog aktif. Memantau kontainer idle & Webhook Deploy...")
    
    deploy_trigger = os.path.join(os.path.dirname(__file__), "logs", "deploy.trigger")
    
    while True:
        # Cek Git Webhook
        if os.path.exists(deploy_trigger):
            tls_dbg("\n[WEBHOOK] Menerima sinyal deploy baru!")
            try:
                os.remove(deploy_trigger)
                # Pindah ke root repo dan pull
                os.system("cd .. && git pull origin main")
                tls_dbg("[WEBHOOK] Git pull selesai. Merestart kontainer AI Router...")
                os.system("docker compose restart ai-router")
            except Exception as e:
                tls_dbg(f"Gagal memproses deploy webhook: {e}")
        
        # Cek Idle Container
        # Simplifikasi: Cek idle time dari file flag atau API (disini kita asumsikan selalu cek tiap 5 menit)
        time.sleep(5)
        # TODO: Implementasi deteksi aktivitas asli untuk freeze_container()

