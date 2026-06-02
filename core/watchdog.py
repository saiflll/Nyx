import time
import docker
import os

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
            tls_dbg(f"[watchdog] {container_name} paused (idle)")
    except Exception as e:
        tls_dbg(f"[watchdog] pause gagal: {e}")

if __name__ == "__main__":
    tls_dbg("[watchdog] aktif")
    deploy_trigger = os.path.join(os.path.dirname(__file__), "logs", "deploy.trigger")

    while True:
        if os.path.exists(deploy_trigger):
            tls_dbg("[webhook] sinyal deploy diterima")
            try:
                os.remove(deploy_trigger)
                os.system("cd .. && git pull origin main")
                tls_dbg("[webhook] git pull selesai, restart nyxAgent...")
                os.system("docker compose restart ai-router")
            except Exception as e:
                tls_dbg(f"[webhook] gagal: {e}")
        time.sleep(5)
