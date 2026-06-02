from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import httpx
from bs4 import BeautifulSoup
import urllib.parse
import os
import re

app = FastAPI(title="OSINT Scraper", version="1.0")

# =============================================================================
# Style Guide: snake_case + singkatan (ambl, ck, prs, dll)
# =============================================================================

class RqstCari(BaseModel):
    query: str
    target: str = "umum" # umum, sosmed, email, buku

async def ambl_html(url: str) -> str:
    # Pakai proxy jika ada (hindari block)
    px = os.getenv("HTTP_PROXY")
    
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    }
    
    try:
        async with httpx.AsyncClient(proxy=px, follow_redirects=True) as cln:
            rspn = await cln.get(url, headers=headers, timeout=15.0)
            rspn.raise_for_status()
            return rspn.text
    except Exception as err:
        hndl_err("ambl_html", err)
        return ""

def hndl_err(ctx: str, err: Exception):
    print(f"[{ctx}] Error: {err}")

def prs_email(html: str) -> list[str]:
    # Regex sederhana untuk email
    email_pattern = r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'
    hsl = re.findall(email_pattern, html)
    return list(set(hsl))

def prs_sosmed(html: str) -> list[str]:
    sosmed_domains = ["twitter.com", "instagram.com", "facebook.com", "linkedin.com", "t.me"]
    soup = BeautifulSoup(html, "html.parser")
    links = []
    for a in soup.find_all('a', href=True):
        href = a['href']
        if any(d in href for d in sosmed_domains):
            links.append(href)
    return list(set(links))

@app.post("/cari")
async def cari_data(req: RqstCari):
    """
    Endpoint untuk mencari data via duckduckgo html (tanpa headless browser).
    Cocok untuk cari buku, nomer telp, jejak digital.
    """
    q_encode = urllib.parse.quote_plus(req.query)
    url_cari = f"https://html.duckduckgo.com/html/?q={q_encode}"
    
    html = await ambl_html(url_cari)
    if not html:
        raise HTTPException(status_code=500, detail="Gagal ambl data dr mesin pencari")
        
    soup = BeautifulSoup(html, "html.parser")
    hsl_cari = []
    
    # Prs hasil pencarian DDG
    for res in soup.find_all('div', class_='result'):
        title_el = res.find('a', class_='result__url')
        snippet_el = res.find('a', class_='result__snippet')
        
        if title_el and snippet_el:
            link = title_el.get('href', '')
            title = title_el.text.strip()
            snippet = snippet_el.text.strip()
            hsl_cari.append({
                "judul": title,
                "url": link,
                "kutipan": snippet
            })
            
    # Ekstraksi tambahan sesuai target
    dt_tambahan = {}
    if req.target == "email":
        dt_tambahan["emails"] = prs_email(html)
    elif req.target == "sosmed":
        dt_tambahan["sosmed"] = prs_sosmed(html)
        
    return {
        "status": "sukses",
        "query": req.query,
        "target": req.target,
        "jml_hasil": len(hsl_cari),
        "hasil": hsl_cari,
        "tambahan": dt_tambahan
    }

if __name__ == "__main__":
    import uvicorn
    # mlu (running)
    uvicorn.run(app, host="0.0.0.0", port=8085)
