import json
import yaml
import os

# =============================================================================
# Generator Dokumentasi & Diagram (Digital Brain v2)
# =============================================================================

def hndl_err(ctx, err):
    print(f"[{ctx}] Error: {err}")

def bt_readme():
    try:
        konten = """# Digital Brain v2

Sistem server AI otonom dan monitoring berbasis Android (Termux/Proot).

## Fitur Utama

1. **AI Router & Orchestrator**: Multi-akun API key, load balancing, failover, dan in-memory state machine.
2. **Qwen Lokal**: Model AI offline untuk pemrosesan file sensitif.
3. **OSINT Scraper**: API ringan untuk pencarian data tanpa headless browser.
4. **Storage Manager**: Multi-cloud proxy (GDrive, MEGA, dll) menggunakan rclone.
5. **Monitoring & Alert**: Isolasi CPU (cpuset), integrasi Telegram bot, dan metrik sistem.
6. **Web Dashboard**: SvelteKit UI untuk manajemen layanan.

## Instalasi

1. Clone repositori ke perangkat.
2. Eksekusi skrip setup dasar:
   ```bash
   bash setup.sh
   ```
3. Salin dan konfigurasi environment variables:
   ```bash
   cp core/.env.template core/.env
   # Edit core/.env dengan kredensial API dan Telegram
   ```
4. Jalankan core setup (download model & inisialisasi):
   ```bash
   bash core/setup-core.sh
   ```

## Konfigurasi Lanjutan

- **Multi-Akun AI**: Tambahkan beberapa API key di `.env` dengan pemisah koma (contoh: `GEMINI_API_KEYS=key1,key2`). Router akan membagi beban secara otomatis.
- **CPU Isolation**: Edit `core/docker-compose.yml` pada bagian `cpuset` untuk menyesuaikan dengan topologi prosesor perangkat.
- **Telegram Bot**: Memerlukan `TELEGRAM_BOT_TOKEN` dan `TELEGRAM_CHAT_ID` valid di `.env`.

## Arsitektur

Lihat `flow.html` untuk diagram alur sistem yang interaktif.
"""
        with open("docs/README.md", "w", encoding="utf-8") as f:
            f.write(konten)
        print("Berhasil bt_readme")
    except Exception as e:
        hndl_err("bt_readme", e)

def bt_flow():
    try:
        konten = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Digital Brain v2 Flow</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; background: #0d1117; color: #c9d1d9; margin: 0; padding: 2rem; }
        .container { max-width: 1200px; margin: 0 auto; }
        h1 { border-bottom: 1px solid #30363d; padding-bottom: 0.5rem; }
        .mermaid { margin-top: 2rem; background: #161b22; padding: 2rem; border-radius: 6px; border: 1px solid #30363d; }
    </style>
    <script type="module">
        import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs';
        mermaid.initialize({ startOnLoad: true, theme: 'dark' });
    </script>
</head>
<body>
    <div class="container">
        <h1>Arsitektur Digital Brain v2</h1>
        <p>Diagram di bawah merepresentasikan interaksi antar service, manajemen status job, dan isolasi CPU.</p>
        
        <div class="mermaid">
        graph TD
            Client[Web Dashboard / User]
            
            subgraph Proxy_Layer[Proxy Layer - Core 2-3]
                Nginx[Nginx Reverse Proxy]
            end
            
            subgraph AI_Orchestrator[AI Orchestrator - Core 4-7]
                Router[AI Router: State Machine]
                Qwen[Qwen Local 1.5B]
                ExternalAI[External APIs: Groq, Gemini...]
            end
            
            subgraph Core_Services[Core Services - Core 2-3]
                Storage[Storage Manager]
                Web[SvelteKit Interface]
            end
            
            subgraph Background_Workers[Background Workers - Core 0-1]
                Monitor[Monitoring Service]
                Alert[Telegram Alert Bot]
                OSINT[OSINT Scraper]
                VectorDB[ChromaDB]
            end
            
            Client -->|Request| Nginx
            
            Nginx -->|/api/ai/*| Router
            Nginx -->|/api/storage/*| Storage
            Nginx -->|/| Web
            
            Router -->|Kueri Konteks| VectorDB
            Router -->|Data Eksternal| OSINT
            Router -->|Sensitif| Qwen
            Router -->|Umum / Fallback| ExternalAI
            
            Monitor -->|Peringatan Limit| Alert
            Alert -->|Telegram API| UserTelegram((User))
        </div>

        <div class="mermaid">
        stateDiagram-v2
            [*] --> PENDING: Job Dibuat
            PENDING --> ROUTING: Evaluasi Task Type
            ROUTING --> THINKING: Pilih Provider Aktif
            
            THINKING --> DONE: Sukses
            THINKING --> RETRY: Validasi Format Gagal
            RETRY --> THINKING: Coba Provider Sama / Lain
            
            THINKING --> FAILED_PROVIDER: Limit/Timeout
            FAILED_PROVIDER --> ROUTING: Failover ke Provider Lain
            
            ROUTING --> FAILED_ALL: Semua Provider Habis
            FAILED_ALL --> [*]
            DONE --> [*]
        </div>
    </div>
</body>
</html>
"""
        with open("docs/flow.html", "w", encoding="utf-8") as f:
            f.write(konten)
        print("Berhasil bt_flow")
    except Exception as e:
        hndl_err("bt_flow", e)

if __name__ == "__main__":
    bt_readme()
    bt_flow()
