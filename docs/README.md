# Digital Brain v2

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
