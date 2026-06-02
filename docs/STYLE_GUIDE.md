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
- Separator `// --- NAMA SECTION --- ` untuk section besar
- Sparator untuk komentar fungsi penting dan sub section yang perlu di komentari pakai `// nama subtion ` saja , contoh : `// handle function`

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

### 6. Aturan Pengubahan
Gunakan metode dan route yang sudah ada diutamakan kecuali aku meminta diubah atau ditambahkan. Atau bisa sarankan metode lain jika dianggap lebih efesien dan cocok.
Jangan asal mengubah api dan merubah endpoint yang sudah ada tanpa memberitahuku. Kecuali ada perubahan yang sudah di ACC olehku.
Jangan asal mengubah layout tampilan kecuali meminta tersetujuanku( jika project sudah ada uinya ) jika belum bia full autu build dengan integrasi backend dan frontend otomatis.

### 7. Aturan Komunikasi
Saat menjelaskan task selalu gunakan Bahasa Indonesia.

### 8. Aturan Update
Saat mengubah/ menambah atau menguranggi suatu fitur atau route , biasakan cek ada keterkaitan service lain atau tidak, jika tidak langsung saja jika ada seperti ke ui maka sesuaikan dulu sebelum bilang done.

### 9. Aturan Penamaan Folder
Aku lebih suka penamaan yang singkat dan jelas, menggunakan bahasa Indonesia. Contoh : folder ui jangan ditulis user-interface tapi tulis ui saja, kumpulan services jangan ditulis sebagai full-service atau group-services tapi tulis svc, contoh lain kumpulan script untuk testing atau develop , jangan dimasukan dalam folder bernama develop cukup dev , begitu juga untuk dokumentasi cukup docs saja . untuk main program aku lebih suka nama foldernya core saja.

### 10. Aturan Penamaan File
Jika menamai file yang isinya code python aku lebih suka menggunakan snake_case, contoh file-saya.py atau file_saya.py.  jika menamai file yang isinya code typescript aku lebih suka menggunakan camelCase, contoh fileSaya.ts atau file-saya.ts . jika menamai file yang isinya code go aku lebih suka menggunakan snake_case, contoh file_saya.go . dan namanya itu jelas contoh jika isi filenya untuk mengelola user maka bisa diberi nama user.py , user.ts atau user.go  atau jika isi filenya untuk mengelola database maka bisa diberi nama db.py, db.ts atau db.go. dan contoh lain jika komplek dan banyak pemangilan ,aku lebih suka standart semua formatnya , contoh file di folder tool maka didalamnya nama filenya tool_user.py atau toolUser begitu . aku lebih suka mengunakan bahasa indonesia untuk menamai file, folder atau variable tetapi jika variabel bahasa indonesianya terlalu panjang atau susah diucapkan atau susah dihafalkan dan disingkat seperti menjalankan atau memegang atau mengelola proses aku lebih suka menggunakan bahasa inggris untuk menamai variable, folder atau file ya walaupun ku singkat seperti mng(management) ctlg(controlling) dst.

### 11. Susunan strukture file
Untuk backend aku lebih suka terpisah- pisah antara bagian core atau inti , bagian service atau fitur , bagaian ui , bagian dokumen , bagian dev tool , bagian config , dst 
begitu juga di front endnya 
bagain layout,
bagain header , 
bagain isi , 
bagain navigasi , 
bagain styling , 
bagain yang hit ke api" be dan 
bagain scripting dan static file 

### 12. Model Debug
 Aku suka membuat sistem itu bisa di on offkan mode debugnya melalui satu perintah bisa dari .env bisa dari main sistemnya , cukup ubah 1 jadi 0 atau on jadi off untuk mematikan semua console log , debug , dkk agar lebih silent saat sudah fix dideploy. tapi saat awal build sbelum aku ubah sendiri jadi 0 default ny 1