#!/bin/bash
# Script untuk push source code ke GitHub
set -e

echo "=========================================="
echo "    UPLOAD DIGITAL BRAIN KE GITHUB"
echo "=========================================="
echo ""

echo "Pastikan kamu sudah membuat repositori kosong di GitHub."
read -p "Masukkan URL Repository (contoh: https://github.com/username/digital-brain.git): " REPO_URL

if [ -z "$REPO_URL" ]; then
    echo "URL kosong. Membatalkan..."
    exit 1
fi

# Cek apakah ini repo git
if [ ! -d ".git" ]; then
    git init
    git branch -M main
fi

# Set remote origin
git remote remove origin 2>/dev/null || true
git remote add origin "$REPO_URL"

echo ""
echo "Melakukan push ke repository..."
# Lakukan push (akan meminta kredensial via Git Credential Manager atau token)
git push -u origin main

echo ""
echo "Selesai! Source code berhasil diupload ke GitHub."
