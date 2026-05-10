package httpapi

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"musicflow-backend/internal/model"
)

type localImportRequest struct {
	Path  string   `json:"path"`
	Paths []string `json:"paths"`
}

func (s *Server) handleLocalImport(w http.ResponseWriter, r *http.Request) {
	if !s.requireAdmin(w, r) {
		return
	}
	profile, err := s.authProfile(r)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to verify user")
		return
	}
	var request localImportRequest
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request")
		return
	}
	paths := normalizeLocalImportPaths(request)
	if len(paths) == 0 {
		writeError(w, http.StatusBadRequest, "local path is required")
		return
	}
	songs, err := s.importLocalMusic(r.Context(), profile.ID, paths)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusCreated, songs)
}

func normalizeLocalImportPaths(request localImportRequest) []string {
	seen := map[string]bool{}
	paths := make([]string, 0, len(request.Paths)+1)
	for _, item := range append([]string{request.Path}, request.Paths...) {
		path := strings.TrimSpace(item)
		if path == "" || seen[path] {
			continue
		}
		seen[path] = true
		paths = append(paths, path)
	}
	return paths
}

func (s *Server) importLocalMusic(ctx context.Context, userID int64, paths []string) ([]model.Song, error) {
	files, err := collectLocalImportFiles(paths)
	if err != nil {
		return nil, err
	}
	if len(files.audio) == 0 {
		return nil, fmt.Errorf("没有找到可导入的音频文件")
	}
	imported := make([]model.Song, 0, len(files.audio))
	for _, filePath := range files.audio {
		song, err := s.importLocalAudioFile(ctx, userID, filePath, localLyricsForAudio(filePath, files.lyrics))
		if err != nil {
			return nil, err
		}
		imported = append(imported, song)
	}
	return imported, nil
}

type localImportFiles struct {
	audio  []string
	lyrics map[string]string
}

func collectLocalImportFiles(paths []string) (localImportFiles, error) {
	files := localImportFiles{
		audio:  []string{},
		lyrics: map[string]string{},
	}
	seen := map[string]bool{}
	for _, rawPath := range paths {
		path, err := filepath.Abs(rawPath)
		if err != nil {
			return localImportFiles{}, err
		}
		info, err := os.Stat(path)
		if err != nil {
			return localImportFiles{}, fmt.Errorf("无法访问路径 %s", rawPath)
		}
		if !info.IsDir() {
			if err := collectLocalImportFile(path, &files, seen); err != nil {
				return localImportFiles{}, err
			}
			continue
		}
		if err := filepath.WalkDir(path, func(item string, entry os.DirEntry, err error) error {
			if err != nil {
				return nil
			}
			if entry.IsDir() {
				return nil
			}
			return collectLocalImportFile(item, &files, seen)
		}); err != nil {
			return localImportFiles{}, err
		}
	}
	return files, nil
}

func collectLocalImportFile(path string, files *localImportFiles, seen map[string]bool) error {
	if seen[path] {
		return nil
	}
	if isSupportedLocalAudio(path) {
		seen[path] = true
		files.audio = append(files.audio, path)
		return nil
	}
	if !isSupportedLocalLyrics(path) {
		return nil
	}
	lyrics, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	seen[path] = true
	files.lyrics[localImportMatchKey(path)] = string(lyrics)
	return nil
}

func isSupportedLocalAudio(path string) bool {
	switch strings.ToLower(filepath.Ext(path)) {
	case ".mp3", ".flac", ".m4a", ".aac", ".wav", ".ogg":
		return true
	default:
		return false
	}
}

func isSupportedLocalLyrics(path string) bool {
	return strings.ToLower(filepath.Ext(path)) == ".lrc"
}

func localLyricsForAudio(sourcePath string, lyrics map[string]string) string {
	for _, key := range localImportAudioLyricsKeys(sourcePath) {
		if value := strings.TrimSpace(lyrics[key]); value != "" {
			return value
		}
	}
	return ""
}

func localImportAudioLyricsKeys(path string) []string {
	title, artist, _ := localSongMetadata(path)
	return []string{
		localImportMatchKey(path),
		normalizeLocalImportMatchName(title),
		normalizeLocalImportMatchName(title + "-" + artist),
		normalizeLocalImportMatchName(artist + "-" + title),
	}
}

func localImportMatchKey(path string) string {
	base := strings.TrimSuffix(filepath.Base(path), filepath.Ext(path))
	if before, _, found := strings.Cut(base, "#"); found {
		base = before
	}
	return normalizeLocalImportMatchName(base)
}

func normalizeLocalImportMatchName(value string) string {
	return strings.ToLower(strings.TrimSpace(value))
}

func (s *Server) importLocalAudioFile(ctx context.Context, userID int64, sourcePath string, lyrics string) (model.Song, error) {
	title, artist, album := localSongMetadata(sourcePath)
	if existing, err := s.repo.FindSongByTitleArtist(ctx, title, artist); err == nil {
		targetPath, duration, err := importLocalAudioToStorage(sourcePath)
		if err != nil {
			return model.Song{}, err
		}
		if strings.TrimSpace(lyrics) == "" {
			lyrics = existing.Lyrics
		}
		updated, err := s.repo.UpdateSongAudioMetadata(ctx, existing.ID, targetPath, "local_import", duration, lyrics)
		if err != nil {
			return model.Song{}, err
		}
		if err := s.repo.CreateDownload(ctx, userID, existing.ID, "local"); err != nil {
			return model.Song{}, err
		}
		return updated, nil
	} else if !errors.Is(err, sql.ErrNoRows) {
		return model.Song{}, err
	}

	targetPath, duration, err := importLocalAudioToStorage(sourcePath)
	if err != nil {
		return model.Song{}, err
	}
	created, err := s.repo.CreateSong(ctx, model.Song{
		Title:    title,
		Artist:   artist,
		Album:    album,
		Duration: duration,
		AudioURL: targetPath,
		Source:   "local_import",
		Lyrics:   lyrics,
	})
	if err != nil {
		return model.Song{}, err
	}
	if err := s.repo.CreateDownload(ctx, userID, created.ID, "local"); err != nil {
		return model.Song{}, err
	}
	return created, nil
}

func importLocalAudioToStorage(sourcePath string) (string, int, error) {
	musicDir, err := filepath.Abs(filepath.Join("storage", "music"))
	if err != nil {
		return "", 0, err
	}
	if err := os.MkdirAll(musicDir, 0o755); err != nil {
		return "", 0, err
	}
	targetPath := filepath.Join(musicDir, randomHex(16)+strings.ToLower(filepath.Ext(sourcePath)))
	if err := copyLocalFile(sourcePath, targetPath); err != nil {
		return "", 0, err
	}
	info, err := os.Stat(targetPath)
	if err != nil {
		return "", 0, err
	}
	if info.Size() < 10_000 {
		_ = os.Remove(targetPath)
		return "", 0, fmt.Errorf("%s 不是有效音乐文件", filepath.Base(sourcePath))
	}
	targetPath, info, err = ensurePlayableAudioFile(targetPath, info)
	if err != nil {
		return "", 0, err
	}
	return targetPath, audioDurationSeconds(targetPath, info.Size(), 0), nil
}

func copyLocalFile(sourcePath string, targetPath string) error {
	source, err := os.Open(sourcePath)
	if err != nil {
		return err
	}
	defer source.Close()
	target, err := os.Create(targetPath)
	if err != nil {
		return err
	}
	defer target.Close()
	_, err = io.Copy(target, source)
	return err
}

func localSongMetadata(path string) (string, string, string) {
	base := strings.TrimSuffix(filepath.Base(path), filepath.Ext(path))
	base = strings.TrimSpace(base)
	album := strings.TrimSpace(filepath.Base(filepath.Dir(path)))
	artist := "未知艺术家"
	title := base
	for _, separator := range []string{" - ", " – ", " — ", "_", "-"} {
		parts := strings.SplitN(base, separator, 2)
		if len(parts) != 2 {
			continue
		}
		left := strings.TrimSpace(parts[0])
		right := strings.TrimSpace(parts[1])
		if left != "" && right != "" {
			artist = left
			title = right
			break
		}
	}
	if title == "" {
		title = "本地歌曲"
	}
	if album == "." || album == string(filepath.Separator) {
		album = ""
	}
	return title, artist, album
}
