import subprocess

def bersihkan_zram_cache() -> dict:
    """
    Membersihkan cache memori (PageCache, dentry, dan inode) secara paksa di level Kernel/Bare-metal.
    Sangat berguna untuk membebaskan sisa RAM (termasuk zRAM) setelah beban berat (scraping/LLM).
    
    Returns:
        dict: Status pembersihan RAM.
    """
    try:
        # Trik: Karena kita punya docker.sock, kita bisa menembak host kernel cache via privileged container
        # tanpa harus menginstall KSU di dalam container ini.
        cmd = [
            "docker", "run", "--rm", "--privileged", "alpine",
            "sh", "-c", "echo 3 > /proc/sys/vm/drop_caches"
        ]
        
        subprocess.run(cmd, capture_output=True, text=True, check=True)
        return {"status": "SUKSES: echo 3 > /proc/sys/vm/drop_caches berhasil dieksekusi di Kernel HP. RAM bersih."}
        
    except subprocess.CalledProcessError as e:
        return {"error": f"Gagal eksekusi drop_caches via docker privileged: {e.stderr}"}
    except Exception as e:
        return {"error": str(e)}
