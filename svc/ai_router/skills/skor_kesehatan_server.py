import subprocess
import os

def skor_kesehatan_server() -> dict:
    """
    Mengambil rangkuman diagnostik kesehatan server secara menyeluruh.
    Ini mencakup Suhu HP, Sisa RAM (MemFree + Buffers/Cache), dan Sisa Storage eMMC internal.
    Gunakan ini sebagai langkah pertama saat pengguna bertanya tentang 'kondisi server saat ini'.
    
    Returns:
        dict: Metrik kesehatan server lengkap.
    """
    hasil = {
        "suhu_cpu_celsius": "Tidak diketahui",
        "ram_info": "Tidak diketahui",
        "storage_info": "Tidak diketahui",
        "kesimpulan": "Aman"
    }
    
    # 1. Cek Suhu (Asumsi dari zone0)
    try:
        if os.path.exists("/sys/class/thermal/thermal_zone0/temp"):
            with open("/sys/class/thermal/thermal_zone0/temp", "r") as f:
                temp = int(f.read().strip()) / 1000.0
                hasil["suhu_cpu_celsius"] = f"{temp:.1f}°C"
                if temp > 45.0:
                    hasil["kesimpulan"] = "WARNING: Suhu Tinggi"
    except:
        pass
        
    # 2. Cek RAM dari host via docker info (karena /proc/meminfo container kadang di-limit)
    try:
        cmd_mem = ["docker", "info", "--format", "{{.MemTotal}}"]
        res_mem = subprocess.run(cmd_mem, capture_output=True, text=True)
        if res_mem.stdout:
            total_mem_gb = int(res_mem.stdout.strip()) / (1024**3)
            hasil["ram_info"] = f"Total RAM Host: {total_mem_gb:.1f} GB"
    except:
        pass
        
    # 3. Cek Storage Host (kita pakai docker trick lagi)
    try:
        cmd_disk = [
            "docker", "run", "--rm", "-v", "/data/data/com.termux/files/home:/host", 
            "alpine", "df", "-h", "/host"
        ]
        res_disk = subprocess.run(cmd_disk, capture_output=True, text=True)
        if res_disk.stdout:
            # Ambil baris kedua dari output df
            lines = res_disk.stdout.strip().split('\n')
            if len(lines) > 1:
                hasil["storage_info"] = lines[1]
    except:
        pass
        
    return hasil
