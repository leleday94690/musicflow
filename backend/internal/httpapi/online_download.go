package httpapi

import (
	"bufio"
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"html"
	"io"
	"math"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"

	"musicflow-backend/internal/model"
)

const gequbaoBaseURL = "https://www.gequbao.com"
const gequbaoUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
const jcmallDefaultBaseURL = "https://api.jcmall.site"
const gdStudioBaseURL = "https://music-api.gdstudio.xyz/api.php"
const onlineSearchLimit = 50
const gdStudioSourceSearchLimit = 30

type onlineSearchResult struct {
	ID     string `json:"id"`
	Title  string `json:"title"`
	Artist string `json:"artist"`
	Cover  string `json:"cover"`
}

type remoteSongDTO struct {
	ID        int64  `json:"id"`
	Title     string `json:"title"`
	Artist    string `json:"artist"`
	Album     string `json:"album"`
	Duration  int    `json:"duration"`
	CoverURL  string `json:"coverUrl"`
	StreamURL string `json:"streamUrl"`
	AudioURL  string `json:"audioUrl"`
}

type jcmallResponse[T any] struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
	Data    T      `json:"data"`
}

type gdStudioSearchItem struct {
	ID     string   `json:"id"`
	Name   string   `json:"name"`
	Artist []string `json:"artist"`
	Album  string   `json:"album"`
	PicID  string   `json:"pic_id"`
	URLID  string   `json:"url_id"`
	Source string   `json:"source"`
}

type gdStudioURLPayload struct {
	URL  string `json:"url"`
	BR   int    `json:"br"`
	Size int64  `json:"size"`
}

type gdStudioLyricPayload struct {
	Lyric string `json:"lyric"`
	LRC   string `json:"lrc"`
}

type onlineBatchDownloadRequest struct {
	Songs []onlineBatchSong `json:"songs"`
}

type onlineBatchSong struct {
	ID     string `json:"id"`
	Title  string `json:"title"`
	Artist string `json:"artist"`
}

func (s *Server) handleOnlineSearch(w http.ResponseWriter, r *http.Request) {
	keyword := strings.TrimSpace(r.URL.Query().Get("keyword"))
	if keyword == "" {
		writeError(w, http.StatusBadRequest, "keyword is required")
		return
	}
	results, err := searchGDStudio(r.Context(), keyword)
	if err != nil {
		writeError(w, http.StatusBadGateway, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, results)
}

func (s *Server) handleOnlineDownload(w http.ResponseWriter, r *http.Request) {
	profile, ok := s.requireUser(w, r)
	if !ok {
		return
	}
	onlineID := strings.TrimPrefix(r.URL.Path, "/api/download/song/")
	onlineID = strings.TrimSpace(onlineID)
	if unescaped, err := url.PathUnescape(onlineID); err == nil {
		onlineID = unescaped
	}
	if onlineID == "" {
		writeError(w, http.StatusBadRequest, "online song id is required")
		return
	}
	title := strings.TrimSpace(r.URL.Query().Get("title"))
	artist := strings.TrimSpace(r.URL.Query().Get("artist"))
	if title == "" {
		title = "在线歌曲"
	}

	song, err := s.downloadGDStudioSong(r.Context(), profile, onlineID, title, artist)
	if err != nil {
		writeError(w, http.StatusBadGateway, err.Error())
		return
	}
	writeJSON(w, http.StatusCreated, song)
}

func (s *Server) handleOnlineBatchDownload(w http.ResponseWriter, r *http.Request) {
	profile, ok := s.requireUser(w, r)
	if !ok {
		return
	}
	var request onlineBatchDownloadRequest
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request")
		return
	}
	if len(request.Songs) == 0 {
		writeJSON(w, http.StatusCreated, []model.Song{})
		return
	}
	created := make([]model.Song, 0, len(request.Songs))
	for _, item := range request.Songs {
		id := strings.TrimSpace(item.ID)
		title := strings.TrimSpace(item.Title)
		artist := strings.TrimSpace(item.Artist)
		if id == "" || title == "" {
			continue
		}
		song, err := s.downloadGDStudioSong(r.Context(), profile, id, title, artist)
		if err != nil {
			writeError(w, http.StatusBadGateway, err.Error())
			return
		}
		created = append(created, song)
	}
	writeJSON(w, http.StatusCreated, created)
}

func searchGDStudio(ctx context.Context, keyword string) ([]onlineSearchResult, error) {
	sources := []string{"netease", "kuwo", "kugou", "migu", "tencent"}
	results := make([]onlineSearchResult, 0, onlineSearchLimit)
	seen := map[string]bool{}
	var lastErr error
	for _, source := range sources {
		sourceResults, err := searchGDStudioSource(ctx, keyword, source)
		if err != nil {
			lastErr = err
			continue
		}
		for _, result := range sourceResults {
			if seen[result.ID] {
				continue
			}
			seen[result.ID] = true
			results = append(results, result)
			if len(results) >= onlineSearchLimit {
				return results, nil
			}
		}
	}
	if len(results) > 0 {
		return results, nil
	}
	if lastErr != nil {
		return nil, lastErr
	}
	return results, nil
}

func searchGDStudioSource(ctx context.Context, keyword string, source string) ([]onlineSearchResult, error) {
	requestURL := gdStudioBaseURL + "?types=search&source=" + url.QueryEscape(source) + "&name=" + url.QueryEscape(keyword) + "&count=" + strconv.Itoa(gdStudioSourceSearchLimit)
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, requestURL, nil)
	if err != nil {
		return nil, err
	}
	request.Header.Set("User-Agent", gequbaoUserAgent)
	request.Header.Set("Accept", "application/json")

	client := &http.Client{Timeout: 20 * time.Second}
	response, err := client.Do(request)
	if err != nil {
		return nil, err
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("在线搜索失败: %d", response.StatusCode)
	}
	body, err := io.ReadAll(response.Body)
	if err != nil {
		return nil, err
	}
	var items []gdStudioSearchItem
	if err := json.Unmarshal(body, &items); err != nil {
		return nil, err
	}
	results := make([]onlineSearchResult, 0, len(items))
	for _, item := range items {
		id := item.URLID
		if id == "" {
			id = item.ID
		}
		if id == "" || item.Name == "" {
			continue
		}
		resultSource := item.Source
		if resultSource == "" {
			resultSource = source
		}
		results = append(results, onlineSearchResult{
			ID:     resultSource + ":" + id,
			Title:  item.Name,
			Artist: strings.Join(item.Artist, " / "),
		})
	}
	return results, nil
}

func (s *Server) downloadGDStudioSong(ctx context.Context, profile model.UserProfile, onlineID string, title string, artist string) (model.Song, error) {
	var existingSong model.Song
	replaceExisting := false
	existing, err := s.repo.FindAccessibleSongByTitleArtist(ctx, profile.ID, title, artist)
	if err == nil {
		existingSong = existing
		source, id := parseGDStudioID(onlineID)
		lyrics := existing.Lyrics
		if strings.TrimSpace(lyrics) == "" {
			lyrics, _ = fetchGDStudioLyrics(ctx, source, id)
		}
		duration := existing.Duration
		if duration <= 0 && existing.AudioURL != "" {
			if info, statErr := os.Stat(existing.AudioURL); statErr == nil {
				duration = audioDurationSeconds(existing.AudioURL, info.Size(), 0)
			}
		}
		if profile.IsAdmin && (duration > 0 || strings.TrimSpace(lyrics) != "") {
			existing, err = s.repo.UpdateSongMetadata(ctx, existing.ID, duration, lyrics)
			if err != nil {
				return model.Song{}, err
			}
		}
		if !profile.IsAdmin || !strings.EqualFold(filepath.Ext(existing.AudioURL), ".flac") {
			return s.markOnlineDownload(ctx, profile.ID, existing)
		}
		replaceExisting = true
	}
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		return model.Song{}, err
	}
	source, id, payload, err := fetchAvailableGDStudioURL(ctx, onlineID, title, artist)
	if err != nil {
		return model.Song{}, err
	}

	musicDir, err := filepath.Abs(filepath.Join("storage", "music"))
	if err != nil {
		return model.Song{}, err
	}
	if err := os.MkdirAll(musicDir, 0o755); err != nil {
		return model.Song{}, err
	}
	filePath := filepath.Join(musicDir, randomHex(16)+audioFileExtension(payload.URL))
	if err := downloadFile(ctx, payload.URL, gdStudioBaseURL, filePath); err != nil {
		return model.Song{}, err
	}
	info, err := os.Stat(filePath)
	if err != nil {
		return model.Song{}, err
	}
	if info.Size() < 10_000 {
		_ = os.Remove(filePath)
		return model.Song{}, fmt.Errorf("下载的文件不是有效音乐文件")
	}
	filePath, info, err = ensurePlayableAudioFile(filePath, info)
	if err != nil {
		return model.Song{}, err
	}

	duration := audioDurationSeconds(filePath, info.Size(), payload.BR)
	lyrics, _ := fetchGDStudioLyrics(ctx, source, id)
	if replaceExisting {
		updated, err := s.repo.UpdateSongAudioMetadata(ctx, existingSong.ID, filePath, source, duration, lyrics)
		if err != nil {
			return model.Song{}, err
		}
		return s.markOnlineDownload(ctx, profile.ID, updated)
	}
	visibility := "public"
	ownerUserID := int64(0)
	if !profile.IsAdmin {
		visibility = "private"
		ownerUserID = profile.ID
	}
	created, err := s.repo.CreateSongScoped(ctx, model.Song{Title: title, Artist: artist, Album: "", Duration: duration, AudioURL: filePath, Source: source, Lyrics: lyrics}, visibility, ownerUserID)
	if err != nil {
		return model.Song{}, err
	}
	return s.markOnlineDownload(ctx, profile.ID, created)
}

func (s *Server) markOnlineDownload(ctx context.Context, userID int64, song model.Song) (model.Song, error) {
	if err := s.repo.CreateDownload(ctx, userID, song.ID, "320kbps"); err != nil {
		return model.Song{}, err
	}
	return song, nil
}

func (s *Server) downloadSongToLocal(ctx context.Context, song model.Song) (model.Song, error) {
	audioURL := strings.TrimSpace(song.AudioURL)
	if audioURL == "" {
		return model.Song{}, fmt.Errorf("歌曲没有可下载的音频地址")
	}
	if !isRemoteAudioURL(audioURL) {
		return song, nil
	}
	musicDir, err := filepath.Abs(filepath.Join("storage", "music"))
	if err != nil {
		return model.Song{}, err
	}
	if err := os.MkdirAll(musicDir, 0o755); err != nil {
		return model.Song{}, err
	}
	filePath := filepath.Join(musicDir, randomHex(16)+audioFileExtension(audioURL))
	if err := downloadFile(ctx, audioURL, "", filePath); err != nil {
		return model.Song{}, err
	}
	info, err := os.Stat(filePath)
	if err != nil {
		return model.Song{}, err
	}
	if info.Size() < 10_000 {
		_ = os.Remove(filePath)
		return model.Song{}, fmt.Errorf("下载的文件不是有效音乐文件")
	}
	filePath, info, err = ensurePlayableAudioFile(filePath, info)
	if err != nil {
		return model.Song{}, err
	}
	duration := song.Duration
	if duration <= 0 {
		duration = audioDurationSeconds(filePath, info.Size(), 0)
	}
	return s.repo.UpdateSongAudioMetadata(ctx, song.ID, filePath, song.Source, duration, song.Lyrics)
}

func isRemoteAudioURL(audioURL string) bool {
	value := strings.ToLower(strings.TrimSpace(audioURL))
	return strings.HasPrefix(value, "http://") || strings.HasPrefix(value, "https://")
}

func fetchGDStudioURL(ctx context.Context, source string, id string) (gdStudioURLPayload, error) {
	requestURL := gdStudioBaseURL + "?types=url&source=" + url.QueryEscape(source) + "&id=" + url.QueryEscape(id) + "&br=320"
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, requestURL, nil)
	if err != nil {
		return gdStudioURLPayload{}, err
	}
	request.Header.Set("User-Agent", gequbaoUserAgent)
	request.Header.Set("Accept", "application/json")

	client := &http.Client{Timeout: 20 * time.Second}
	response, err := client.Do(request)
	if err != nil {
		return gdStudioURLPayload{}, err
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return gdStudioURLPayload{}, fmt.Errorf("获取音乐地址失败: %d", response.StatusCode)
	}
	body, err := io.ReadAll(response.Body)
	if err != nil {
		return gdStudioURLPayload{}, err
	}
	var payload gdStudioURLPayload
	if err := json.Unmarshal(body, &payload); err != nil {
		return gdStudioURLPayload{}, err
	}
	return payload, nil
}

func fetchAvailableGDStudioURL(ctx context.Context, onlineID string, title string, artist string) (string, string, gdStudioURLPayload, error) {
	var lastErr error
	for _, candidate := range gdStudioDownloadCandidates(ctx, onlineID, title, artist) {
		source, id := parseGDStudioID(candidate)
		payload, err := fetchGDStudioURL(ctx, source, id)
		if err != nil {
			lastErr = err
			continue
		}
		if strings.TrimSpace(payload.URL) != "" {
			return source, id, payload, nil
		}
	}
	if lastErr != nil {
		return "", "", gdStudioURLPayload{}, lastErr
	}
	return "", "", gdStudioURLPayload{}, fmt.Errorf("未获取到可下载的音乐地址，可能当前音源暂不开放下载，请换一个版本或稍后再试")
}

func gdStudioDownloadCandidates(ctx context.Context, onlineID string, title string, artist string) []string {
	candidates := []string{onlineID}
	seen := map[string]bool{onlineID: true}
	queries := []string{
		strings.TrimSpace(title + " " + artist),
		strings.TrimSpace(title),
	}
	for _, query := range queries {
		if query == "" {
			continue
		}
		results, err := searchGDStudio(ctx, query)
		if err != nil {
			continue
		}
		for _, result := range results {
			if result.ID == "" || seen[result.ID] || !matchesGDStudioResult(result, title, artist) {
				continue
			}
			seen[result.ID] = true
			candidates = append(candidates, result.ID)
		}
	}
	return candidates
}

func matchesGDStudioResult(result onlineSearchResult, title string, artist string) bool {
	expectedTitle := normalizeGDStudioText(title)
	resultTitle := normalizeGDStudioText(result.Title)
	if expectedTitle != "" && resultTitle != expectedTitle {
		return false
	}
	expectedArtist := normalizeGDStudioText(artist)
	resultArtist := normalizeGDStudioText(result.Artist)
	return expectedArtist == "" || resultArtist == "" || strings.Contains(resultArtist, expectedArtist) || strings.Contains(expectedArtist, resultArtist)
}

func normalizeGDStudioText(value string) string {
	value = strings.ToLower(strings.TrimSpace(value))
	value = regexp.MustCompile(`g\.?\s*e\.?\s*m\.?`).ReplaceAllString(value, "邓紫棋")
	value = regexp.MustCompile(`[\s·\._\-—–()（）《》【】\[\]/]+`).ReplaceAllString(value, "")
	return value
}

func parseGDStudioID(onlineID string) (string, string) {
	parts := strings.SplitN(onlineID, ":", 2)
	if len(parts) == 2 && parts[0] != "" && parts[1] != "" {
		return parts[0], parts[1]
	}
	return "netease", onlineID
}

func audioFileExtension(rawURL string) string {
	parsed, err := url.Parse(rawURL)
	if err != nil {
		return ".mp3"
	}
	extension := strings.ToLower(filepath.Ext(parsed.Path))
	switch extension {
	case ".mp3", ".flac", ".m4a", ".aac", ".wav", ".ogg":
		return extension
	default:
		return ".mp3"
	}
}

func ensurePlayableAudioFile(path string, info os.FileInfo) (string, os.FileInfo, error) {
	if !strings.EqualFold(filepath.Ext(path), ".flac") {
		return path, info, nil
	}
	ffmpegPath, err := exec.LookPath("ffmpeg")
	if err != nil {
		return path, info, nil
	}
	targetPath := strings.TrimSuffix(path, filepath.Ext(path)) + ".mp3"
	command := exec.Command(ffmpegPath, "-nostdin", "-y", "-i", path, "-vn", "-codec:a", "libmp3lame", "-b:a", "320k", targetPath)
	if output, err := command.CombinedOutput(); err != nil {
		_ = os.Remove(targetPath)
		return path, info, fmt.Errorf("FLAC 转码 MP3 失败: %s", strings.TrimSpace(string(output)))
	}
	targetInfo, err := os.Stat(targetPath)
	if err != nil {
		return path, info, err
	}
	if targetInfo.Size() < 10_000 {
		_ = os.Remove(targetPath)
		return path, info, fmt.Errorf("FLAC 转码后的 MP3 文件无效")
	}
	_ = os.Remove(path)
	return targetPath, targetInfo, nil
}

func fetchGDStudioLyrics(ctx context.Context, source string, id string) (string, error) {
	requestURL := gdStudioBaseURL + "?types=lyric&source=" + url.QueryEscape(source) + "&id=" + url.QueryEscape(id)
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, requestURL, nil)
	if err != nil {
		return "", err
	}
	request.Header.Set("User-Agent", gequbaoUserAgent)
	request.Header.Set("Accept", "application/json")
	client := &http.Client{Timeout: 20 * time.Second}
	response, err := client.Do(request)
	if err != nil {
		return "", err
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return "", fmt.Errorf("获取歌词失败: %d", response.StatusCode)
	}
	body, err := io.ReadAll(response.Body)
	if err != nil {
		return "", err
	}
	var payload gdStudioLyricPayload
	if err := json.Unmarshal(body, &payload); err == nil {
		if strings.TrimSpace(payload.LRC) != "" {
			return payload.LRC, nil
		}
		if strings.TrimSpace(payload.Lyric) != "" {
			return payload.Lyric, nil
		}
	}
	var values []gdStudioLyricPayload
	if err := json.Unmarshal(body, &values); err == nil {
		for _, item := range values {
			if strings.TrimSpace(item.LRC) != "" {
				return item.LRC, nil
			}
			if strings.TrimSpace(item.Lyric) != "" {
				return item.Lyric, nil
			}
		}
	}
	return "", nil
}

func fetchLyricsByTitleArtist(ctx context.Context, title string, artist string) (string, error) {
	title = strings.TrimSpace(title)
	artist = strings.TrimSpace(artist)
	if title == "" {
		return "", fmt.Errorf("歌曲名不能为空")
	}
	keyword := strings.TrimSpace(title + " " + artist)
	results, err := searchGDStudio(ctx, keyword)
	if err != nil {
		return "", err
	}
	for _, result := range results {
		if strings.TrimSpace(result.ID) == "" {
			continue
		}
		source, id := parseGDStudioID(result.ID)
		lyrics, err := fetchGDStudioLyrics(ctx, source, id)
		if err != nil {
			continue
		}
		if strings.TrimSpace(lyrics) != "" {
			return lyrics, nil
		}
	}
	return "", nil
}

func audioDurationSeconds(path string, fileSize int64, bitrateKbps int) int {
	if duration := flacDurationSeconds(path); duration > 0 {
		return duration
	}
	if duration := mp3DurationSeconds(path); duration > 0 {
		return duration
	}
	if strings.EqualFold(filepath.Ext(path), ".flac") {
		return 0
	}
	if bitrateKbps > 0 && fileSize > 0 {
		return int(math.Round(float64(fileSize*8) / float64(bitrateKbps*1000)))
	}
	return 0
}

func flacDurationSeconds(path string) int {
	file, err := os.Open(path)
	if err != nil {
		return 0
	}
	defer file.Close()
	header := make([]byte, 42)
	if _, err := io.ReadFull(file, header); err != nil {
		return 0
	}
	if string(header[:4]) != "fLaC" {
		return 0
	}
	if header[4]&0x7F != 0 {
		return 0
	}
	if int(header[5])<<16|int(header[6])<<8|int(header[7]) != 34 {
		return 0
	}
	streamInfo := header[8:42]
	sampleRate := int(streamInfo[10])<<12 | int(streamInfo[11])<<4 | int(streamInfo[12]>>4)
	totalSamples := uint64(streamInfo[13]&0x0F)<<32 | uint64(streamInfo[14])<<24 | uint64(streamInfo[15])<<16 | uint64(streamInfo[16])<<8 | uint64(streamInfo[17])
	if sampleRate <= 0 || totalSamples == 0 {
		return 0
	}
	return int(math.Round(float64(totalSamples) / float64(sampleRate)))
}

func mp3DurationSeconds(path string) int {
	file, err := os.Open(path)
	if err != nil {
		return 0
	}
	defer file.Close()
	reader := bufio.NewReader(file)
	if err := skipID3v2(reader); err != nil {
		return 0
	}
	header := make([]byte, 4)
	for i := 0; i < 8192; i++ {
		if _, err := io.ReadFull(reader, header[:1]); err != nil {
			return 0
		}
		if header[0] != 0xFF {
			continue
		}
		if _, err := io.ReadFull(reader, header[1:]); err != nil {
			return 0
		}
		if header[1]&0xE0 != 0xE0 {
			continue
		}
		bitrate := mp3BitrateKbps(header)
		if bitrate <= 0 {
			continue
		}
		info, err := file.Stat()
		if err != nil {
			return 0
		}
		return int(math.Round(float64(info.Size()*8) / float64(bitrate*1000)))
	}
	return 0
}

func skipID3v2(reader *bufio.Reader) error {
	header, err := reader.Peek(10)
	if err != nil {
		return nil
	}
	if string(header[:3]) != "ID3" {
		return nil
	}
	size := int(header[6]&0x7F)<<21 | int(header[7]&0x7F)<<14 | int(header[8]&0x7F)<<7 | int(header[9]&0x7F)
	_, err = reader.Discard(10 + size)
	return err
}

func mp3BitrateKbps(header []byte) int {
	versionID := (header[1] >> 3) & 0x03
	layer := (header[1] >> 1) & 0x03
	bitrateIndex := (header[2] >> 4) & 0x0F
	if bitrateIndex == 0 || bitrateIndex == 15 || layer == 0 || versionID == 1 {
		return 0
	}
	mpeg1Layer3 := []int{0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320}
	mpeg2Layer3 := []int{0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160}
	if layer == 1 {
		if versionID == 3 {
			return mpeg1Layer3[bitrateIndex]
		}
		return mpeg2Layer3[bitrateIndex]
	}
	return 0
}

func searchGequbao(ctx context.Context, keyword string) ([]onlineSearchResult, error) {
	searchURL := gequbaoBaseURL + "/s/" + url.PathEscape(keyword)
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, searchURL, nil)
	if err != nil {
		return nil, err
	}
	request.Header.Set("User-Agent", gequbaoUserAgent)
	request.Header.Set("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
	request.Header.Set("Referer", gequbaoBaseURL+"/")
	setGequbaoCookie(request)

	client := &http.Client{Timeout: 15 * time.Second}
	response, err := client.Do(request)
	if err != nil {
		return nil, err
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("search failed: %d", response.StatusCode)
	}
	body, err := io.ReadAll(response.Body)
	if err != nil {
		return nil, err
	}
	if strings.Contains(string(body), "cf-mitigated") || strings.Contains(string(body), "Just a moment...") {
		return nil, fmt.Errorf("歌曲宝触发 Cloudflare 验证，请配置 GEQUBAO_COOKIE 后重启后端")
	}
	return parseGequbaoResults(string(body), keyword), nil
}

func parseGequbaoResults(pageHTML string, keyword string) []onlineSearchResult {
	patterns := []*regexp.Regexp{
		regexp.MustCompile(`(?i)<a\s+[^>]*href="/music/(\d+)"[^>]*title="([^"]+)"[^>]*>`),
		regexp.MustCompile(`(?i)<a\s+[^>]*title="([^"]+)"[^>]*href="/music/(\d+)"[^>]*>`),
	}
	results := make([]onlineSearchResult, 0)
	seen := map[string]bool{}
	for index, pattern := range patterns {
		matches := pattern.FindAllStringSubmatch(pageHTML, 100)
		for _, match := range matches {
			id := match[1]
			titleText := match[2]
			if index == 1 {
				id = match[2]
				titleText = match[1]
			}
			title, artist := parseOnlineTitle(titleText)
			if id == "" || title == "" || seen[id] {
				continue
			}
			seen[id] = true
			results = append(results, onlineSearchResult{ID: id, Title: title, Artist: artist})
		}
		if len(results) > 0 {
			return filterOnlineResults(results, keyword)
		}
	}

	linkPattern := regexp.MustCompile(`(?i)<a\s+[^>]*href="/music/(\d+)"[^>]*>([\s\S]*?)</a>`)
	matches := linkPattern.FindAllStringSubmatch(pageHTML, 100)
	for _, match := range matches {
		id := match[1]
		text := regexp.MustCompile(`<[^>]+>`).ReplaceAllString(match[2], " ")
		title, artist := parseOnlineTitle(text)
		if id == "" || title == "" || seen[id] {
			continue
		}
		seen[id] = true
		results = append(results, onlineSearchResult{ID: id, Title: title, Artist: artist})
	}
	return filterOnlineResults(results, keyword)
}

func parseOnlineTitle(raw string) (string, string) {
	value := strings.TrimSpace(html.UnescapeString(raw))
	value = regexp.MustCompile(`\s+`).ReplaceAllString(value, " ")
	if strings.Contains(value, " - ") {
		parts := strings.SplitN(value, " - ", 2)
		return strings.TrimSpace(parts[0]), strings.TrimSpace(parts[1])
	}
	if strings.Contains(value, "-") && !strings.HasPrefix(value, "-") {
		parts := strings.SplitN(value, "-", 2)
		return strings.TrimSpace(parts[0]), strings.TrimSpace(parts[1])
	}
	bookPattern := regexp.MustCompile(`(.*)《(.+)》`)
	if match := bookPattern.FindStringSubmatch(value); len(match) == 3 {
		return strings.TrimSpace(match[2]), strings.TrimSpace(match[1])
	}
	return value, ""
}

func filterOnlineResults(results []onlineSearchResult, keyword string) []onlineSearchResult {
	if len(results) == 0 {
		return results
	}
	keyword = strings.ToLower(strings.TrimSpace(keyword))
	filtered := make([]onlineSearchResult, 0, len(results))
	for _, result := range results {
		combined := strings.ToLower(result.Title + " " + result.Artist)
		if strings.Contains(combined, keyword) || keyword == "" {
			filtered = append(filtered, result)
		}
	}
	if len(filtered) == 0 {
		if len(results) > onlineSearchLimit {
			return results[:onlineSearchLimit]
		}
		return results
	}
	if len(filtered) > onlineSearchLimit {
		return filtered[:onlineSearchLimit]
	}
	return filtered
}

func searchJCMall(ctx context.Context, keyword string, auth string) ([]onlineSearchResult, error) {
	endpoint := strings.TrimRight(os.Getenv("JCMALL_API_BASE_URL"), "/")
	if endpoint == "" {
		endpoint = jcmallDefaultBaseURL
	}
	requestURL := endpoint + "/api/download/search?keyword=" + url.QueryEscape(keyword)
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, requestURL, nil)
	if err != nil {
		return nil, err
	}
	request.Header.Set("Authorization", auth)
	request.Header.Set("Accept", "application/json")

	client := &http.Client{Timeout: 30 * time.Second}
	response, err := client.Do(request)
	if err != nil {
		return nil, err
	}
	defer response.Body.Close()
	body, err := io.ReadAll(response.Body)
	if err != nil {
		return nil, err
	}
	if response.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("参考项目远端搜索失败: %d", response.StatusCode)
	}
	var payload jcmallResponse[[]onlineSearchResult]
	if err := json.Unmarshal(body, &payload); err != nil {
		return nil, err
	}
	if !payload.Success {
		if payload.Message == "" {
			payload.Message = "参考项目远端搜索失败"
		}
		return nil, errors.New(payload.Message)
	}
	return payload.Data, nil
}

func (s *Server) downloadJCMallSong(ctx context.Context, userID int64, onlineID string, title string, artist string, auth string) (model.Song, error) {
	endpoint := strings.TrimRight(os.Getenv("JCMALL_API_BASE_URL"), "/")
	if endpoint == "" {
		endpoint = jcmallDefaultBaseURL
	}
	requestURL := endpoint + "/api/download/song/" + url.PathEscape(onlineID) + "?title=" + url.QueryEscape(title)
	if artist != "" {
		requestURL += "&artist=" + url.QueryEscape(artist)
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, requestURL, nil)
	if err != nil {
		return model.Song{}, err
	}
	request.Header.Set("Authorization", auth)
	request.Header.Set("Accept", "application/json")

	client := &http.Client{Timeout: 120 * time.Second}
	response, err := client.Do(request)
	if err != nil {
		return model.Song{}, err
	}
	defer response.Body.Close()
	body, err := io.ReadAll(response.Body)
	if err != nil {
		return model.Song{}, err
	}
	if response.StatusCode != http.StatusOK && response.StatusCode != http.StatusCreated {
		return model.Song{}, fmt.Errorf("参考项目远端下载失败: %d", response.StatusCode)
	}
	var payload jcmallResponse[remoteSongDTO]
	if err := json.Unmarshal(body, &payload); err != nil {
		return model.Song{}, err
	}
	if !payload.Success {
		if payload.Message == "" {
			payload.Message = "参考项目远端下载失败"
		}
		return model.Song{}, errors.New(payload.Message)
	}
	sourceURL := payload.Data.StreamURL
	if sourceURL == "" {
		sourceURL = payload.Data.AudioURL
	}
	return s.saveRemoteSong(ctx, userID, payload.Data, sourceURL)
}

func (s *Server) saveRemoteSong(ctx context.Context, userID int64, remote remoteSongDTO, sourceURL string) (model.Song, error) {
	if sourceURL == "" {
		return model.Song{}, fmt.Errorf("远端未返回播放地址")
	}
	musicDir, err := filepath.Abs(filepath.Join("storage", "music"))
	if err != nil {
		return model.Song{}, err
	}
	if err := os.MkdirAll(musicDir, 0o755); err != nil {
		return model.Song{}, err
	}
	filePath := filepath.Join(musicDir, randomHex(16)+".mp3")
	if err := downloadFile(ctx, sourceURL, jcmallDefaultBaseURL, filePath); err != nil {
		return model.Song{}, err
	}
	info, err := os.Stat(filePath)
	if err != nil {
		return model.Song{}, err
	}
	filePath, info, err = ensurePlayableAudioFile(filePath, info)
	if err != nil {
		return model.Song{}, err
	}
	duration := remote.Duration
	if duration <= 0 {
		duration = audioDurationSeconds(filePath, info.Size(), 0)
	}
	created, err := s.repo.CreateSong(ctx, model.Song{
		Title:    remote.Title,
		Artist:   remote.Artist,
		Album:    remote.Album,
		Duration: duration,
		CoverURL: remote.CoverURL,
		AudioURL: filePath,
		Source:   "参考项目",
	})
	if err != nil {
		return model.Song{}, err
	}
	return s.markOnlineDownload(ctx, userID, created)
}

func (s *Server) downloadGequbaoSong(ctx context.Context, userID int64, onlineID string, title string, artist string) (model.Song, error) {
	downloadURL, err := getGequbaoDownloadURL(ctx, onlineID)
	if err != nil {
		return model.Song{}, err
	}
	if downloadURL == "" {
		return model.Song{}, fmt.Errorf("无法获取下载链接")
	}

	musicDir, err := filepath.Abs(filepath.Join("storage", "music"))
	if err != nil {
		return model.Song{}, err
	}
	if err := os.MkdirAll(musicDir, 0o755); err != nil {
		return model.Song{}, err
	}
	fileName := randomHex(16) + ".mp3"
	filePath := filepath.Join(musicDir, fileName)
	if err := downloadFile(ctx, downloadURL, gequbaoBaseURL+"/music/"+onlineID, filePath); err != nil {
		return model.Song{}, err
	}
	info, err := os.Stat(filePath)
	if err != nil {
		return model.Song{}, err
	}
	if info.Size() < 10_000 {
		_ = os.Remove(filePath)
		return model.Song{}, fmt.Errorf("下载的文件不是有效音乐文件")
	}
	filePath, info, err = ensurePlayableAudioFile(filePath, info)
	if err != nil {
		return model.Song{}, err
	}

	duration := audioDurationSeconds(filePath, info.Size(), 0)
	created, err := s.repo.CreateSong(ctx, model.Song{Title: title, Artist: artist, Album: "", Duration: duration, AudioURL: filePath, Source: "歌曲宝"})
	if err != nil {
		return model.Song{}, err
	}
	return s.markOnlineDownload(ctx, userID, created)
}

func getGequbaoDownloadURL(ctx context.Context, onlineID string) (string, error) {
	pageURL := gequbaoBaseURL + "/music/" + onlineID
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, pageURL, nil)
	if err != nil {
		return "", err
	}
	request.Header.Set("User-Agent", gequbaoUserAgent)
	request.Header.Set("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
	request.Header.Set("Referer", gequbaoBaseURL+"/")
	setGequbaoCookie(request)

	client := &http.Client{Timeout: 20 * time.Second}
	response, err := client.Do(request)
	if err != nil {
		return "", err
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return "", fmt.Errorf("获取歌曲页面失败: %d", response.StatusCode)
	}
	body, err := io.ReadAll(response.Body)
	if err != nil {
		return "", err
	}
	page := string(body)
	if strings.Contains(page, "cf-mitigated") || strings.Contains(page, "Just a moment...") {
		return "", fmt.Errorf("歌曲宝触发 Cloudflare 验证，请配置 GEQUBAO_COOKIE 后重启后端")
	}

	playIDPattern := regexp.MustCompile(`play_id[\\u0022"]+:\s*[\\u0022"]+([A-Za-z0-9+/=]+)[\\u0022"]`)
	if match := playIDPattern.FindStringSubmatch(page); len(match) == 2 {
		form := url.Values{}
		form.Set("id", match[1])
		apiRequest, err := http.NewRequestWithContext(ctx, http.MethodPost, gequbaoBaseURL+"/api/play-url", strings.NewReader(form.Encode()))
		if err != nil {
			return "", err
		}
		apiRequest.Header.Set("User-Agent", gequbaoUserAgent)
		apiRequest.Header.Set("Accept", "application/json")
		apiRequest.Header.Set("Content-Type", "application/x-www-form-urlencoded")
		apiRequest.Header.Set("Referer", pageURL)
		setGequbaoCookie(apiRequest)
		apiResponse, err := client.Do(apiRequest)
		if err != nil {
			return "", err
		}
		defer apiResponse.Body.Close()
		apiBody, err := io.ReadAll(apiResponse.Body)
		if err != nil {
			return "", err
		}
		var payload struct {
			Code int `json:"code"`
			Data struct {
				URL string `json:"url"`
			} `json:"data"`
		}
		if err := json.Unmarshal(apiBody, &payload); err == nil && payload.Code == 1 && payload.Data.URL != "" {
			return payload.Data.URL, nil
		}
	}

	patterns := []*regexp.Regexp{
		regexp.MustCompile(`"url"\s*:\s*"([^"]+\.mp3[^"]*)"`),
		regexp.MustCompile(`href="([^"]+\.mp3[^"]*)"`),
		regexp.MustCompile(`src="([^"]+\.mp3[^"]*)"`),
		regexp.MustCompile(`data-url="([^"]+)"`),
		regexp.MustCompile(`'url'\s*:\s*'([^']+)'`),
	}
	for _, pattern := range patterns {
		if match := pattern.FindStringSubmatch(page); len(match) == 2 {
			candidate := strings.ReplaceAll(match[1], `\/`, "/")
			if strings.HasPrefix(candidate, "http") {
				return candidate, nil
			}
		}
	}
	return "", nil
}

func downloadFile(ctx context.Context, sourceURL string, referer string, targetPath string) error {
	referers := []string{referer, "https://www.kuwo.cn/", gequbaoBaseURL + "/", ""}
	client := &http.Client{Timeout: 90 * time.Second}
	var lastStatus int
	for _, item := range referers {
		request, err := http.NewRequestWithContext(ctx, http.MethodGet, sourceURL, nil)
		if err != nil {
			return err
		}
		request.Header.Set("User-Agent", gequbaoUserAgent)
		request.Header.Set("Accept", "*/*")
		request.Header.Set("Accept-Encoding", "identity")
		if item != "" {
			request.Header.Set("Referer", item)
		}
		setGequbaoCookie(request)
		response, err := client.Do(request)
		if err != nil {
			continue
		}
		lastStatus = response.StatusCode
		if response.StatusCode == http.StatusOK {
			defer response.Body.Close()
			file, err := os.Create(targetPath)
			if err != nil {
				return err
			}
			defer file.Close()
			_, err = io.Copy(file, response.Body)
			return err
		}
		_ = response.Body.Close()
	}
	return fmt.Errorf("下载失败，状态码: %d", lastStatus)
}

func randomHex(length int) string {
	buffer := make([]byte, length)
	if _, err := rand.Read(buffer); err != nil {
		return fmt.Sprintf("%d", time.Now().UnixNano())
	}
	return hex.EncodeToString(buffer)
}

func setGequbaoCookie(request *http.Request) {
	cookie := strings.TrimSpace(os.Getenv("GEQUBAO_COOKIE"))
	if cookie != "" {
		request.Header.Set("Cookie", cookie)
	}
}

func jcmallAuthHeader(request *http.Request) string {
	auth := strings.TrimSpace(request.Header.Get("Authorization"))
	if auth != "" {
		return auth
	}
	token := strings.TrimSpace(os.Getenv("JCMALL_API_TOKEN"))
	if token == "" {
		return ""
	}
	if strings.HasPrefix(strings.ToLower(token), "bearer ") {
		return token
	}
	return "Bearer " + token
}
