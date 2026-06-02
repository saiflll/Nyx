import os

def baca_sistem_daya() -> dict:
    """
    Membaca tegangan (Voltage) dan arus (Ampere) yang masuk ke IC Power/Baterai kernel Android.
    Gunakan ini untuk mengecek apakah daya dari buck converter stabil atau drop saat chipset beban berat.
    
    Returns:
        dict: Informasi tegangan (V), arus (A), dan status kesehatan daya.
    """
    # Path kernel standar Android untuk baterai
    volt_path = "/sys/class/power_supply/battery/voltage_now"
    curr_path = "/sys/class/power_supply/battery/current_now"
    
    hasil = {
        "voltage_v": 0.0,
        "current_a": 0.0,
        "status": "Tidak terbaca"
    }
    
    try:
        if os.path.exists(volt_path):
            with open(volt_path, "r") as f:
                # Voltage_now biasanya dalam microvolts
                v_micro = int(f.read().strip())
                hasil["voltage_v"] = round(v_micro / 1_000_000, 2)
                
        if os.path.exists(curr_path):
            with open(curr_path, "r") as f:
                # Current_now biasanya dalam microamps
                c_micro = int(f.read().strip())
                hasil["current_a"] = round(c_micro / 1_000_000, 2)
                
        # Analisis Cepat
        if hasil["voltage_v"] > 0:
            if hasil["voltage_v"] < 3.7:
                hasil["status"] = "DROP (Tegangan kurang dari 3.7V, bahaya mati mendadak)"
            elif hasil["voltage_v"] > 4.4:
                hasil["status"] = "OVERVOLTAGE (Bahaya IC Power jebol)"
            else:
                hasil["status"] = "STABIL (Buck Converter aman)"
                
    except Exception as e:
        hasil["error"] = str(e)
        
    return hasil
