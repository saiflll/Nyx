# Style Guide Pribadi — @user
# Berlaku untuk SEMUA project dan SEMUA agent/AI yang generate kode
# =============================================================================

## ATURAN UTAMA

### 1. Naming Convention — Singkatan Bahasa Indonesia/Jawa

Gunakan singkatan bermakna dari bahasa Indonesia/Jawa.
Bukan singkatan random — harus bisa ditebak dari konteks.

#### Kamus Singkatan Standar:
```
# Aksi (verba) → singkatan:
baca    → bc       tulis  → tls      ambil  → ambl
simpan  → smpn     hapus  → hps      cek    → ck
mulai   → mli      henti  → hnt      jalan  → jln
kirim   → krm      terima → trm      proses → prs
buat    → bt       atur   → atr      muat   → mt
unggah  → ugg      unduh  → undh     tampil → tmpl

# Jawa (internal/private):
mlaku   → mlu   (berjalan/running)
mlayu   → mly   (berlari/fast)
nyimpen → nsmpn  njupuk → njpk   ngirim → ngrm

# Objek/Noun → singkatan:
data    → dt    hasil   → hsl    error  → err
pesan   → psn   koneksi → knk    config → cfg
waktu   → wkt   ukuran  → ukrn   jumlah → jml
daftar  → dftr  pengguna→ pggn   token  → tkn
kunci   → knci  file    → fl     folder → fldr
server  → srv   client  → cln    request→ rqst   response→ rspn
```

#### Rules:
- Variable lokal  → camelCase bahasa case-sensitive (JS/TS/Go/Rust)
- Variable lokal  → snake_case bahasa non-sensitive (Python, SQL, Bash)
- Constants       → UPPER_SNAKE bahasa Inggris (MAX_RETRY, PORT)
- Class/Type      → PascalCase bahasa Inggris (AiRouter, StorageManager)
- Singkatan HANYA untuk variable lokal & parameter, BUKAN public export/API

---

### 2. Function Style

```typescript
// TOP-LEVEL → regular declaration
function bcFile(path: string): string { ... }

// CALLBACK / INLINE → arrow function
const dftr = items.filter(item => item.aktif)
const hsl  = data.map(dt => prsData(dt))

// Method chaining untuk transformasi
const output = dftr
  .filter(item => item.hsl !== null)
  .map(item => ({ ...item, wkt: Date.now() }))
  .sort((a, b) => b.wkt - a.wkt)
```

---

### 3. Komentar

```typescript
// === SECTION BESAR ===   ← separator

function bcFile(path: string) {  // baca konten file
  // hanya komentar jika logika tidak obvious
  const hsl = readFileSync(path)
  return hsl
}
```

- Tidak perlu JSDoc untuk semua fungsi
- Wajib komentar singkat di head fungsi jika nama masih ambigu
- Wajib di bagian tricky logic/workaround
- Separator `// === NAMA ===` untuk section besar

---

### 4. Error Handling — Async/Await + Centralized

```typescript
// TS/JS — centralized hndlErr
async function amblData(url: string) {
  const [hsl, err] = await to(fetch(url))
  if (err) return hndlErr('amblData', err)
  return hsl
}

function hndlErr(ctx: string, err: Error) {
  logger.error(`[${ctx}] ${err.message}`)
  return null
}
```

```python
# Python — centralized hndl_err
async def ambl_data(url: str):
    try:
        hsl = await fetch(url)
        return hsl
    except Exception as err:
        hndl_err("ambl_data", err)
        return None

def hndl_err(ctx: str, err: Exception):
    logger.error(f"[{ctx}] {err}")
```

- Tidak try/catch tersebar di mana-mana
- Early return jika error, bukan nested if

---

### 5. Indentation

| Bahasa       | Indent | Max Line |
|--------------|--------|----------|
| Python       | 4 spasi| 88 char  |
| TS/JS/Svelte | 2 spasi| 100 char |
| Go           | Tab    | 120 char |
| Rust/C++     | 4 spasi| 100 char |
| Bash         | 4 spasi| 80 char  |
