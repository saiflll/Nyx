import subprocess

def manajer_proses_kontainer(action: str = "list", container_name: str = "") -> dict:
    """
    Mengelola dan memonitor proses kontainer Docker/Podman di server.
    Gunakan tool ini untuk mengecek apakah suatu service (seperti qwen-local atau osint-scraper) sedang berjalan, mati, atau ter-pause.
    
    Args:
        action (str): Aksi yang mau dilakukan. Pilihan: 'list' (lihat semua), 'logs' (lihat log), 'restart' (restart kontainer). Default 'list'.
        container_name (str): Nama kontainer spesifik jika action='logs' atau 'restart'. Kosongkan jika 'list'.
        
    Returns:
        dict: Hasil eksekusi docker command.
    """
    try:
        if action == "list":
            cmd = ["docker", "ps", "-a", "--format", "{{.Names}}: {{.Status}}"]
            res = subprocess.run(cmd, capture_output=True, text=True, check=True)
            lines = res.stdout.strip().split('\n')
            return {"containers": lines if lines[0] else []}
            
        elif action == "logs" and container_name:
            cmd = ["docker", "logs", "--tail", "20", container_name]
            res = subprocess.run(cmd, capture_output=True, text=True, check=True)
            return {"logs": res.stdout.strip()[-1000:]} # Ambil 1000 karakter terakhir
            
        elif action == "restart" and container_name:
            cmd = ["docker", "restart", container_name]
            res = subprocess.run(cmd, capture_output=True, text=True, check=True)
            return {"status": f"Kontainer {container_name} berhasil direstart."}
            
        else:
            return {"error": "Parameter tidak valid. Gunakan action='list' atau action='logs'/'restart' beserta container_name."}
            
    except subprocess.CalledProcessError as e:
        return {"error": f"Gagal mengeksekusi docker: {e.stderr}"}
    except Exception as e:
        return {"error": str(e)}
