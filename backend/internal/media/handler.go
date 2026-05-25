package media

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/hapa-world/hapa/pkg/config"
	pkgmiddleware "github.com/hapa-world/hapa/pkg/middleware"
)

const (
	maxUploadSize = 500 << 20 // 500 MB — videos can be large
	uploadsDir    = "/app/uploads"
)

var allowedMIME = map[string]string{
	"image/jpeg":      ".jpg",
	"image/png":       ".png",
	"image/webp":      ".webp",
	"image/gif":       ".gif",
	"video/mp4":       ".mp4",
	"video/quicktime": ".mov",
	"video/x-msvideo": ".avi",
	"video/webm":      ".webm",
	"video/x-matroska": ".mkv",
	"video/3gpp":      ".3gp",
	"video/3gpp2":     ".3g2",
}

// extToMIME is used as fallback when DetectContentType returns application/octet-stream.
// Mobile devices (especially Android) often produce files whose magic bytes
// aren't recognised by Go's MIME sniffer.
var extToMIME = map[string]string{
	".mp4":  "video/mp4",
	".mov":  "video/quicktime",
	".avi":  "video/x-msvideo",
	".webm": "video/webm",
	".mkv":  "video/x-matroska",
	".3gp":  "video/3gpp",
	".3g2":  "video/3gpp2",
	".jpg":  "image/jpeg",
	".jpeg": "image/jpeg",
	".png":  "image/png",
	".gif":  "image/gif",
	".webp": "image/webp",
}

func Handler(cfg *config.Config) http.HandlerFunc {
	if err := os.MkdirAll(uploadsDir, 0755); err != nil {
		panic(fmt.Sprintf("cannot create uploads dir: %v", err))
	}

	return func(w http.ResponseWriter, r *http.Request) {
		userID := pkgmiddleware.UserIDFromCtx(r.Context())
		if userID == "" {
			http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
			return
		}

		r.Body = http.MaxBytesReader(w, r.Body, maxUploadSize)
		if err := r.ParseMultipartForm(10 << 20); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "file too large (max 500MB)"})
			return
		}

		file, header, err := r.FormFile("file")
		if err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "file field required"})
			return
		}
		defer file.Close()

		// Detect MIME type from first 512 bytes
		buf := make([]byte, 512)
		n, _ := file.Read(buf)
		mime := http.DetectContentType(buf[:n])
		// Normalise: DetectContentType returns e.g. "image/jpeg; charset=..." for some
		mime = strings.Split(mime, ";")[0]

		// Go's DetectContentType returns application/octet-stream for many mobile
		// video formats (3GP, some MP4s). Fall back to extension-based detection.
		if mime == "application/octet-stream" || mime == "application/zip" {
			fileExt := strings.ToLower(filepath.Ext(header.Filename))
			if m, ok := extToMIME[fileExt]; ok {
				mime = m
			}
		}

		ext, ok := allowedMIME[mime]
		if !ok {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "unsupported file type: " + mime})
			return
		}

		// Seek back so we save the full file
		if seeker, ok := file.(io.Seeker); ok {
			seeker.Seek(0, io.SeekStart)
		}

		b := make([]byte, 16)
		rand.Read(b)
		filename := hex.EncodeToString(b) + ext
		dst, err := os.Create(filepath.Join(uploadsDir, filename))
		if err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "could not save file"})
			return
		}
		defer dst.Close()

		if _, err := io.Copy(dst, file); err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "upload failed"})
			return
		}

		// Derive public URL from the request host so it works on any network
		scheme := "http"
		if r.TLS != nil {
			scheme = "https"
		}
		host := r.Host
		url := fmt.Sprintf("%s://%s/uploads/%s", scheme, host, filename)

		_ = header // filename available if needed
		writeJSON(w, http.StatusCreated, map[string]any{
			"url":      url,
			"filename": filename,
			"mime":     mime,
		})
	}
}

// StaticHandler serves files from the uploads directory
func StaticHandler() http.Handler {
	return http.StripPrefix("/uploads/", http.FileServer(http.Dir(uploadsDir)))
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}
