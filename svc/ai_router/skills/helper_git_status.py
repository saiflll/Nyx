import subprocess

def helper_git_status() -> dict:
    """
    Memeriksa status repositori Git dari Server_not10ss di HP.
    Gunakan ini untuk mengecek file apa saja yang berubah atau belum disinkronisasi ke GitHub.
    
    Returns:
        dict: Daftar file yang berubah (short status) dan informasi commit terakhir.
    """
    try:
        # Karena ai-router hanya mount folder svc/ai_router, kita gunakan docker mounting 
        # untuk membaca root folder myserver dari host termux.
        # Asumsi root project ada di /data/data/com.termux/files/home/myserver
        
        # Cek status
        cmd_status = [
            "docker", "run", "--rm", "-v", "/data/data/com.termux/files/home/myserver:/repo",
            "alpine/git", "-C", "/repo", "status", "--short"
        ]
        res_status = subprocess.run(cmd_status, capture_output=True, text=True)
        
        # Cek log terakhir
        cmd_log = [
            "docker", "run", "--rm", "-v", "/data/data/com.termux/files/home/myserver:/repo",
            "alpine/git", "-C", "/repo", "log", "-1", "--oneline"
        ]
        res_log = subprocess.run(cmd_log, capture_output=True, text=True)
        
        return {
            "git_status": res_status.stdout.strip() if res_status.stdout else "Bersih (Tidak ada perubahan)",
            "last_commit": res_log.stdout.strip() if res_log.stdout else "Tidak ada commit"
        }
        
    except Exception as e:
        return {"error": f"Gagal mengecek git: {str(e)}"}
