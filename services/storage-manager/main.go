// =============================================================================
// Storage Manager — Multi-Cloud Storage dengan rclone
// =============================================================================

package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"gopkg.in/yaml.v3"
)

// =============================================================================
// STYLE GUIDE: camelCase + singkatan (ambl, smpn, bc, hndlErr, dt, dll)
// =============================================================================

type StorageAccount struct {
	Nama       string `json:"name"`
	Provider   string `json:"provider"`
	Remote     string `json:"remote"`
	Dipakai    int64  `json:"used_bytes"`
	Bebas      int64  `json:"free_bytes"`
	Total      int64  `json:"total_bytes"`
	DipakaiStr string `json:"used_human"`
	BebasStr   string `json:"free_human"`
	TotalStr   string `json:"total_human"`
	Err        string `json:"error,omitempty"`
}

type FileItem struct {
	Nama      string    `json:"name"`
	Path      string    `json:"path"`
	Remote    string    `json:"remote"`
	Ukrn      int64     `json:"size"`
	UkrnStr   string    `json:"size_human"`
	IsFolder  bool      `json:"is_dir"`
	WktModif  time.Time `json:"mod_time"`
	Kategori  string    `json:"category"`
	TipeMime  string    `json:"mime_type"`
}

type KategoriRule struct {
	Pola     string `yaml:"pattern"`
	Kategori string `yaml:"category"`
}

type ConfigKategori struct {
	Aturan []KategoriRule `yaml:"rules"`
}

type RqstUpload struct {
	NamaFl     string `json:"filename"`
	Remote     string `json:"remote"`
	PathTarget string `json:"target_path"`
	AutoKtgri  bool   `json:"auto_category"`
}

// =============================================================================
// GLOBALS
// =============================================================================

var (
	cfgKtgri     ConfigKategori
	dftrRemote   []string
	mu           sync.RWMutex
	cacheAkun    []StorageAccount
	wktCache     time.Time
	batasCache   = 5 * time.Minute
)

// =============================================================================
// MAIN
// =============================================================================

func main() {
	port := amblEnv("STORAGE_MANAGER_PORT", "8090")

	if err := mtKtgri(); err != nil {
		hndlErr("mtKtgri", err)
	}

	muatRemote()

	r := chi.NewRouter()
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(middleware.Timeout(30 * time.Second))
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins: []string{"*"},
		AllowedMethods: []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders: []string{"*"},
	}))

	r.Get("/health", hndlHealth)
	r.Get("/accounts", hndlDftrAkun)
	r.Get("/files", hndlDftrFile)
	r.Get("/search", hndlCariFile)
	r.Post("/upload-url", hndlUploadUrl)
	r.Get("/download-url", hndlDownloadUrl)
	r.Post("/copy", hndlKopiFl)
	r.Post("/move", hndlPindahFl)
	r.Delete("/file", hndlHpsFl)
	r.Post("/mkdir", hndlBtFldr)
	r.Get("/categories", hndlDftrKtgri)
	r.Get("/stats", hndlStats)

	log.Printf("Storage Manager mlu di port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, r))
}

// =============================================================================
// HANDLERS
// =============================================================================

func hndlHealth(w http.ResponseWriter, r *http.Request) {
	tulisJson(w, map[string]string{
		"status":  "ok",
		"service": "storage-manager",
		"remotes": strings.Join(dftrRemote, ","),
	})
}

func hndlDftrAkun(w http.ResponseWriter, r *http.Request) {
	mu.RLock()
	if time.Since(wktCache) < batasCache && len(cacheAkun) > 0 {
		akun := cacheAkun
		mu.RUnlock()
		tulisJson(w, map[string]interface{}{
			"accounts": akun,
			"cached":   true,
		})
		return
	}
	mu.RUnlock()

	akun := amblInfoAkun()

	mu.Lock()
	cacheAkun = akun
	wktCache = time.Now()
	mu.Unlock()

	tulisJson(w, map[string]interface{}{
		"accounts": akun,
		"cached":   false,
	})
}

func hndlDftrFile(w http.ResponseWriter, r *http.Request) {
	remote := r.URL.Query().Get("remote")
	path := r.URL.Query().Get("path")
	if path == "" {
		path = "/"
	}

	var dftrFl []FileItem
	var err error

	if remote == "" || remote == "all" {
		for _, rem := range dftrRemote {
			fl, e := amblFile(rem, path)
			if e != nil {
				hndlErr("amblFile "+rem, e)
				continue
			}
			dftrFl = append(dftrFl, fl...)
		}
	} else {
		dftrFl, err = amblFile(remote, path)
		if err != nil {
			tulisErr(w, http.StatusInternalServerError, err.Error())
			return
		}
	}

	for i := range dftrFl {
		if dftrFl[i].Kategori == "" {
			dftrFl[i].Kategori = ckKategori(dftrFl[i].Nama)
		}
	}

	sort.Slice(dftrFl, func(i, j int) bool {
		if dftrFl[i].IsFolder != dftrFl[j].IsFolder {
			return dftrFl[i].IsFolder
		}
		return dftrFl[i].Nama < dftrFl[j].Nama
	})

	tulisJson(w, map[string]interface{}{
		"files":  dftrFl,
		"path":   path,
		"remote": remote,
		"total":  len(dftrFl),
	})
}

func hndlCariFile(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query().Get("q")
	remote := r.URL.Query().Get("remote")

	if q == "" {
		tulisErr(w, http.StatusBadRequest, "query 'q' diperlukan")
		return
	}

	var rmCari []string
	if remote != "" && remote != "all" {
		rmCari = []string{remote}
	} else {
		rmCari = dftrRemote
	}

	var hsl []FileItem
	for _, rem := range rmCari {
		args := []string{"lsjson", "--recursive", "--include", fmt.Sprintf("*%s*", q), fmt.Sprintf("%s:/", rem)}
		out, err := jlnRclone(args...)
		if err != nil {
			continue
		}

		var items []map[string]interface{}
		if err := json.Unmarshal([]byte(out), &items); err != nil {
			continue
		}

		for _, item := range items {
			f := prsItemRclone(item, rem)
			f.Kategori = ckKategori(f.Nama)
			hsl = append(hsl, f)
		}
	}

	tulisJson(w, map[string]interface{}{
		"results": hsl,
		"query":   q,
		"total":   len(hsl),
	})
}

func hndlUploadUrl(w http.ResponseWriter, r *http.Request) {
	var rq RqstUpload
	if err := json.NewDecoder(r.Body).Decode(&rq); err != nil {
		tulisErr(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	if rq.AutoKtgri && rq.PathTarget == "" {
		kat := ckKategori(rq.NamaFl)
		rq.PathTarget = "/" + kat + "/" + rq.NamaFl
	} else if rq.PathTarget == "" {
		rq.PathTarget = "/" + rq.NamaFl
	}

	tulisJson(w, map[string]interface{}{
		"method":      "webdav",
		"upload_url":  fmt.Sprintf("http://localhost:8091/upload/%s%s", rq.Remote, rq.PathTarget),
		"target_path": rq.PathTarget,
		"remote":      rq.Remote,
	})
}

// hndlDownloadUrl — DIRECT CLOUD HIT
// Menggunakan rclone link untuk men-generate public/presigned URL dari cloud provider.
// Traffic download akan langsung dari Google Drive/MEGA ke perangkat user, BUKAN melewati HP.
func hndlDownloadUrl(w http.ResponseWriter, r *http.Request) {
	path := r.URL.Query().Get("path") // format: "gdrive:/path/to/file.mp4"
	if path == "" {
		tulisErr(w, http.StatusBadRequest, "path diperlukan")
		return
	}

	out, err := jlnRclone("link", path)
	if err != nil {
		tulisErr(w, http.StatusInternalServerError, fmt.Sprintf("Gagal generate direct link: %s\n%s", err, out))
		return
	}

	link := strings.TrimSpace(out)
	tulisJson(w, map[string]string{
		"status": "ok",
		"direct_url": link,
		"note": "Traffic download langsung dari cloud, tidak membebani Note 10s",
	})
}

func hndlKopiFl(w http.ResponseWriter, r *http.Request) {
	var b map[string]string
	json.NewDecoder(r.Body).Decode(&b)

	src, dst := b["src"], b["dst"]
	if src == "" || dst == "" {
		tulisErr(w, http.StatusBadRequest, "src dan dst diperlukan")
		return
	}

	out, err := jlnRclone("copyto", src, dst)
	if err != nil {
		tulisErr(w, http.StatusInternalServerError, fmt.Sprintf("Kopi gagal: %s\n%s", err, out))
		return
	}
	tulisJson(w, map[string]string{"status": "ok", "message": fmt.Sprintf("Copied %s → %s", src, dst)})
}

func hndlPindahFl(w http.ResponseWriter, r *http.Request) {
	var b map[string]string
	json.NewDecoder(r.Body).Decode(&b)

	out, err := jlnRclone("moveto", b["src"], b["dst"])
	if err != nil {
		tulisErr(w, http.StatusInternalServerError, fmt.Sprintf("Pindah gagal: %s\n%s", err, out))
		return
	}
	tulisJson(w, map[string]string{"status": "ok"})
}

func hndlHpsFl(w http.ResponseWriter, r *http.Request) {
	path := r.URL.Query().Get("path")
	if path == "" {
		tulisErr(w, http.StatusBadRequest, "path diperlukan")
		return
	}

	out, err := jlnRclone("deletefile", path)
	if err != nil {
		tulisErr(w, http.StatusInternalServerError, fmt.Sprintf("Hps gagal: %s\n%s", err, out))
		return
	}
	tulisJson(w, map[string]string{"status": "ok"})
}

func hndlBtFldr(w http.ResponseWriter, r *http.Request) {
	var b map[string]string
	json.NewDecoder(r.Body).Decode(&b)

	out, err := jlnRclone("mkdir", b["path"])
	if err != nil {
		tulisErr(w, http.StatusInternalServerError, fmt.Sprintf("Mkdir gagal: %s\n%s", err, out))
		return
	}
	tulisJson(w, map[string]string{"status": "ok"})
}

func hndlDftrKtgri(w http.ResponseWriter, r *http.Request) {
	tulisJson(w, cfgKtgri.Aturan)
}

func hndlStats(w http.ResponseWriter, r *http.Request) {
	akun := amblInfoAkun()
	var tFree, tUsed, tTotal int64
	for _, a := range akun {
		tFree += a.Bebas
		tUsed += a.Dipakai
		tTotal += a.Total
	}

	tulisJson(w, map[string]interface{}{
		"accounts":       akun,
		"total_free":     tFree,
		"total_used":     tUsed,
		"total_capacity": tTotal,
		"free_human":     fmtUkrn(tFree),
		"used_human":     fmtUkrn(tUsed),
		"capacity_human": fmtUkrn(tTotal),
	})
}

// =============================================================================
// HELPERS
// =============================================================================

func hndlErr(ctx string, err error) {
	log.Printf("[%s] Error: %v", ctx, err)
}

func jlnRclone(args ...string) (string, error) {
	cmd := exec.Command("rclone", args...)
	out, err := cmd.CombinedOutput()
	return string(out), err
}

func muatRemote() {
	out, err := jlnRclone("listremotes")
	if err != nil {
		hndlErr("muatRemote", err)
		return
	}

	var r []string
	for _, baris := range strings.Split(strings.TrimSpace(out), "\n") {
		nama := strings.TrimSuffix(strings.TrimSpace(baris), ":")
		if nama != "" {
			r = append(r, nama)
		}
	}

	mu.Lock()
	dftrRemote = r
	mu.Unlock()
}

func amblInfoAkun() []StorageAccount {
	mu.RLock()
	rmAktif := dftrRemote
	mu.RUnlock()

	var wg sync.WaitGroup
	hsl := make([]StorageAccount, len(rmAktif))

	for i, rem := range rmAktif {
		wg.Add(1)
		go func(idx int, remote string) {
			defer wg.Done()
			akn := StorageAccount{Nama: remote, Remote: remote + ":"}

			out, err := jlnRclone("about", remote+":", "--json")
			if err != nil {
				akn.Err = err.Error()
				hsl[idx] = akn
				return
			}

			var info map[string]interface{}
			if err := json.Unmarshal([]byte(out), &info); err == nil {
				if t, ok := info["total"].(float64); ok {
					akn.Total = int64(t)
					akn.TotalStr = fmtUkrn(akn.Total)
				}
				if u, ok := info["used"].(float64); ok {
					akn.Dipakai = int64(u)
					akn.DipakaiStr = fmtUkrn(akn.Dipakai)
				}
				if f, ok := info["free"].(float64); ok {
					akn.Bebas = int64(f)
					akn.BebasStr = fmtUkrn(akn.Bebas)
				}
			}
			akn.Provider = ckProvider(remote)
			hsl[idx] = akn
		}(i, rem)
	}
	wg.Wait()
	return hsl
}

func amblFile(remote, path string) ([]FileItem, error) {
	pathLengkap := fmt.Sprintf("%s:%s", remote, path)
	out, err := jlnRclone("lsjson", pathLengkap)
	if err != nil {
		return nil, err
	}

	var items []map[string]interface{}
	if err := json.Unmarshal([]byte(out), &items); err != nil {
		return nil, err
	}

	var fl []FileItem
	for _, item := range items {
		fl = append(fl, prsItemRclone(item, remote))
	}
	return fl, nil
}

func prsItemRclone(item map[string]interface{}, remote string) FileItem {
	nama, _ := item["Name"].(string)
	path, _ := item["Path"].(string)
	ukrn, _ := item["Size"].(float64)
	isDir, _ := item["IsDir"].(bool)
	wktStr, _ := item["ModTime"].(string)
	wktModif, _ := time.Parse(time.RFC3339, wktStr)

	return FileItem{
		Nama:     nama,
		Path:     path,
		Remote:   remote,
		Ukrn:     int64(ukrn),
		UkrnStr:  fmtUkrn(int64(ukrn)),
		IsFolder: isDir,
		WktModif: wktModif,
		TipeMime: ckMime(filepath.Ext(nama)),
	}
}

func ckKategori(namaFl string) string {
	lw := strings.ToLower(namaFl)

	for _, rule := range cfgKtgri.Aturan {
		polaArr := strings.Split(rule.Pola, "|")
		for _, p := range polaArr {
			p = strings.TrimSpace(p)
			if p == "*" || (strings.HasPrefix(p, "*.") && strings.HasSuffix(lw, strings.TrimPrefix(p, "*"))) {
				return rule.Kategori
			}
			if strings.Contains(lw, strings.Trim(p, "*")) {
				return rule.Kategori
			}
		}
	}
	return "others"
}

func ckProvider(remote string) string {
	lw := strings.ToLower(remote)
	switch {
	case strings.Contains(lw, "gdrive") || strings.Contains(lw, "google"): return "Google Drive"
	case strings.Contains(lw, "mega"): return "MEGA"
	case strings.Contains(lw, "dropbox"): return "Dropbox"
	case strings.Contains(lw, "terabox"): return "Terabox"
	default: return "Unknown"
	}
}

func fmtUkrn(b int64) string {
	const unit = 1024
	if b < unit {
		return fmt.Sprintf("%d B", b)
	}
	div, exp := int64(unit), 0
	for n := b / unit; n >= unit; n /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.1f %cB", float64(b)/float64(div), "KMGTPE"[exp])
}

func ckMime(ext string) string {
	m := map[string]string{".pdf": "application/pdf", ".jpg": "image/jpeg", ".png": "image/png", ".mp4": "video/mp4"}
	if t, ok := m[ext]; ok {
		return t
	}
	return "application/octet-stream"
}

func mtKtgri() error {
	dt, err := os.ReadFile("/app/categories.yml")
	if err != nil {
		return err
	}
	return yaml.Unmarshal(dt, &cfgKtgri)
}

func amblEnv(key, flb string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return flb
}

func tulisJson(w http.ResponseWriter, dt interface{}) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(dt)
}

func tulisErr(w http.ResponseWriter, code int, msg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(map[string]string{"error": msg})
}

func init() { _ = strconv.Itoa }
