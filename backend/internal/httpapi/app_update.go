package httpapi

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"os"
	"path"
	"path/filepath"
	"strconv"
	"strings"
)

type appUpdateManifest struct {
	Updates []appUpdateEntry `json:"updates"`
}

type appUpdateEntry struct {
	Platform     string `json:"platform"`
	Channel      string `json:"channel"`
	Version      string `json:"version"`
	BuildNumber  int    `json:"buildNumber"`
	ReleaseNotes string `json:"releaseNotes"`
	DownloadURL  string `json:"downloadUrl"`
	FileName     string `json:"fileName"`
	FileSize     int64  `json:"fileSize"`
	SHA256       string `json:"sha256"`
	Mandatory    bool   `json:"mandatory"`
}

type appUpdateResponse struct {
	Available      bool   `json:"available"`
	CurrentVersion string `json:"currentVersion"`
	CurrentBuild   int    `json:"currentBuild"`
	Platform       string `json:"platform"`
	Channel        string `json:"channel"`
	Version        string `json:"version,omitempty"`
	BuildNumber    int    `json:"buildNumber,omitempty"`
	ReleaseNotes   string `json:"releaseNotes,omitempty"`
	DownloadURL    string `json:"downloadUrl,omitempty"`
	FileName       string `json:"fileName,omitempty"`
	FileSize       int64  `json:"fileSize,omitempty"`
	SHA256         string `json:"sha256,omitempty"`
	Mandatory      bool   `json:"mandatory,omitempty"`
}

func (s *Server) handleLatestAppUpdate(w http.ResponseWriter, r *http.Request) {
	platform := normalizeUpdatePlatform(r.URL.Query().Get("platform"))
	channel := strings.TrimSpace(strings.ToLower(r.URL.Query().Get("channel")))
	if channel == "" {
		channel = "stable"
	}
	currentVersion := strings.TrimSpace(r.URL.Query().Get("version"))
	currentBuild, _ := strconv.Atoi(r.URL.Query().Get("buildNumber"))

	if platform == "" {
		writeError(w, http.StatusBadRequest, "platform is required")
		return
	}
	if currentVersion == "" {
		currentVersion = "0.0.0"
	}

	response := appUpdateResponse{
		Available:      false,
		CurrentVersion: currentVersion,
		CurrentBuild:   currentBuild,
		Platform:       platform,
		Channel:        channel,
	}

	manifest, err := s.loadAppUpdateManifest()
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			writeJSON(w, http.StatusOK, response)
			return
		}
		writeError(w, http.StatusInternalServerError, "failed to load update manifest")
		return
	}

	var latest *appUpdateEntry
	for i := range manifest.Updates {
		entry := manifest.Updates[i]
		if normalizeUpdatePlatform(entry.Platform) != platform {
			continue
		}
		entryChannel := strings.TrimSpace(strings.ToLower(entry.Channel))
		if entryChannel == "" {
			entryChannel = "stable"
		}
		if entryChannel != channel {
			continue
		}
		if latest == nil || compareAppVersion(entry.Version, entry.BuildNumber, latest.Version, latest.BuildNumber) > 0 {
			latest = &entry
		}
	}

	if latest == nil || compareAppVersion(latest.Version, latest.BuildNumber, currentVersion, currentBuild) <= 0 {
		writeJSON(w, http.StatusOK, response)
		return
	}

	response.Available = true
	response.Version = normalizeVersionText(latest.Version)
	response.BuildNumber = latest.BuildNumber
	response.ReleaseNotes = latest.ReleaseNotes
	response.DownloadURL = resolveUpdateDownloadURL(r, *latest)
	response.FileName = latest.FileName
	response.FileSize = latest.FileSize
	response.SHA256 = strings.TrimSpace(strings.ToLower(latest.SHA256))
	response.Mandatory = latest.Mandatory
	writeJSON(w, http.StatusOK, response)
}

func (s *Server) handleAppUpdateDownload(w http.ResponseWriter, r *http.Request) {
	fileName := path.Base(strings.TrimPrefix(r.URL.Path, "/api/app-update/download/"))
	if fileName == "." || fileName == "/" || strings.TrimSpace(fileName) == "" {
		writeError(w, http.StatusBadRequest, "invalid update file")
		return
	}
	filePath := filepath.Join(filepath.Dir(s.updateManifestPath), "files", fileName)
	file, err := os.Open(filePath)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			writeError(w, http.StatusNotFound, "update file not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "failed to open update file")
		return
	}
	defer file.Close()

	w.Header().Set("Content-Type", "application/octet-stream")
	w.Header().Set("Content-Disposition", `attachment; filename="`+fileName+`"`)
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(http.StatusOK)

	buffer := make([]byte, 256*1024)
	_, _ = io.CopyBuffer(w, file, buffer)
}

func (s *Server) loadAppUpdateManifest() (appUpdateManifest, error) {
	file, err := os.Open(s.updateManifestPath)
	if err != nil {
		return appUpdateManifest{}, err
	}
	defer file.Close()

	var manifest appUpdateManifest
	if err := json.NewDecoder(file).Decode(&manifest); err != nil {
		return appUpdateManifest{}, err
	}
	return manifest, nil
}

func normalizeUpdatePlatform(value string) string {
	value = strings.TrimSpace(strings.ToLower(value))
	switch value {
	case "mac", "darwin", "macos", "osx":
		return "macos"
	case "win", "windows":
		return "windows"
	default:
		return value
	}
}

func resolveUpdateDownloadURL(r *http.Request, entry appUpdateEntry) string {
	downloadURL := strings.TrimSpace(entry.DownloadURL)
	if strings.HasPrefix(downloadURL, "http://") || strings.HasPrefix(downloadURL, "https://") {
		return downloadURL
	}
	if downloadURL == "" && strings.TrimSpace(entry.FileName) != "" {
		downloadURL = "/releases/" + path.Base(entry.FileName)
	}
	if downloadURL == "" {
		return ""
	}
	if !strings.HasPrefix(downloadURL, "/") {
		downloadURL = "/" + downloadURL
	}
	scheme := r.Header.Get("X-Forwarded-Proto")
	if scheme == "" {
		if r.TLS != nil {
			scheme = "https"
		} else {
			scheme = "http"
		}
	}
	host := r.Header.Get("X-Forwarded-Host")
	if host == "" {
		host = r.Host
	}
	return scheme + "://" + host + downloadURL
}

func compareAppVersion(aVersion string, aBuild int, bVersion string, bBuild int) int {
	aParts := versionParts(aVersion)
	bParts := versionParts(bVersion)
	for i := 0; i < 3; i++ {
		if aParts[i] > bParts[i] {
			return 1
		}
		if aParts[i] < bParts[i] {
			return -1
		}
	}
	if aBuild > bBuild {
		return 1
	}
	if aBuild < bBuild {
		return -1
	}
	return 0
}

func versionParts(version string) [3]int {
	version = normalizeVersionText(version)
	if cut := strings.IndexAny(version, "+-"); cut >= 0 {
		version = version[:cut]
	}
	parts := strings.Split(version, ".")
	var result [3]int
	for i := 0; i < len(parts) && i < 3; i++ {
		result[i], _ = strconv.Atoi(parts[i])
	}
	return result
}

func normalizeVersionText(version string) string {
	return strings.TrimPrefix(strings.TrimSpace(strings.ToLower(version)), "v")
}
