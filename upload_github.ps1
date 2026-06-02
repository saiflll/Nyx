Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "    UPLOAD DIGITAL BRAIN KE GITHUB (WINDOWS)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Pastikan kamu sudah membuat repositori kosong di GitHub." -ForegroundColor Yellow
$repoUrl = Read-Host "Masukkan URL Repository (contoh: https://github.com/username/digital-brain.git)"

if ([string]::IsNullOrWhiteSpace($repoUrl)) {
    Write-Host "URL kosong. Membatalkan..." -ForegroundColor Red
    exit
}

# Pindah ke direktori utama (karena script ini di root folder myserver)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location -Path $scriptDir

# Cek apakah ini repo git
if (!(Test-Path ".git")) {
    git init
    git branch -M main
}

# Hapus remote lama jika ada, lalu tambahkan yang baru
git remote remove origin 2>$null
git remote add origin $repoUrl

Write-Host "`nMelakukan push ke repository..." -ForegroundColor Cyan
# Lakukan push (akan otomatis memanggil Git Credential Manager milik Windows)
git push -u origin main

Write-Host "`nSelesai! Source code berhasil diupload ke GitHub." -ForegroundColor Green
