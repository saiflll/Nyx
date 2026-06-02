def get_system_temperature(unit: str = "celcius") -> dict:
    """
    Mengambil metrik suhu CPU perangkat saat ini. Gunakan tool ini jika user menanyakan suhu server atau HP.
    
    Args:
        unit: Satuan suhu, pilih antara "celcius" atau "fahrenheit". Default: "celcius".
    """
    import random
    
    # Simulasi pembacaan suhu HP (di Termux asli biasanya lewat /sys/class/thermal/)
    base_temp = random.uniform(38.0, 45.0)
    
    if unit == "fahrenheit":
        base_temp = (base_temp * 9/5) + 32
        
    return {
        "status": "normal",
        "temperature": round(base_temp, 1),
        "unit": unit,
        "note": "Pembacaan suhu simulasi hardware"
    }
