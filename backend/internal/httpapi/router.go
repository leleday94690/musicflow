package httpapi

import (
	"database/sql"
	"encoding/json"
	"errors"
	"mime"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"musicflow-backend/internal/model"
	"musicflow-backend/internal/repository"
)

type Server struct {
	repo               *repository.Repository
	allowedOrigins     []string
	updateManifestPath string
}

func NewServer(repo *repository.Repository, allowedOrigins []string, updateManifestPath string) *Server {
	return &Server{
		repo:               repo,
		allowedOrigins:     allowedOrigins,
		updateManifestPath: updateManifestPath,
	}
}

func (s *Server) Routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", s.handleHealth)
	mux.HandleFunc("GET /api/songs/page", s.handleSongsPage)
	mux.HandleFunc("GET /api/songs", s.handleSongs)
	mux.HandleFunc("DELETE /api/songs/{id}", s.handleDeleteSong)
	mux.HandleFunc("PATCH /api/songs/{id}", s.handleUpdateSong)
	mux.HandleFunc("PATCH /api/songs/{id}/favorite", s.handleSongFavorite)
	mux.HandleFunc("POST /api/songs/{id}/lyrics/fetch", s.handleFetchSongLyrics)
	mux.HandleFunc("GET /api/songs/", s.handleSongStream)
	mux.HandleFunc("GET /api/search", s.handleSearch)
	mux.HandleFunc("GET /api/playlists", s.handlePlaylists)
	mux.HandleFunc("POST /api/playlists", s.handleCreatePlaylist)
	mux.HandleFunc("PATCH /api/playlists/{id}", s.handleUpdatePlaylist)
	mux.HandleFunc("DELETE /api/playlists/{id}", s.handleDeletePlaylist)
	mux.HandleFunc("PATCH /api/playlists/{id}/favorite", s.handlePlaylistFavorite)
	mux.HandleFunc("POST /api/playlists/{id}/songs", s.handleAddPlaylistSong)
	mux.HandleFunc("PATCH /api/playlists/{id}/songs/order", s.handleReorderPlaylistSongs)
	mux.HandleFunc("DELETE /api/playlists/{id}/songs/{songId}", s.handleRemovePlaylistSong)
	mux.HandleFunc("GET /api/playlists/", s.handlePlaylistDetail)
	mux.HandleFunc("POST /api/auth/login", s.handleLogin)
	mux.HandleFunc("GET /api/profile", s.handleProfile)
	mux.HandleFunc("GET /api/profile/overview", s.handleProfileOverview)
	mux.HandleFunc("GET /api/app-update/latest", s.handleLatestAppUpdate)
	mux.HandleFunc("GET /api/app-update/download/", s.handleAppUpdateDownload)
	mux.HandleFunc("GET /api/play-history", s.handlePlayHistory)
	mux.HandleFunc("POST /api/play-history", s.handleRecordPlay)
	mux.HandleFunc("GET /api/downloads/page", s.handleDownloadsPage)
	mux.HandleFunc("GET /api/downloads", s.handleDownloads)
	mux.HandleFunc("POST /api/downloads", s.handleCreateDownload)
	mux.HandleFunc("DELETE /api/downloads", s.handleClearDownloads)
	mux.HandleFunc("POST /api/import/local", s.handleLocalImport)
	mux.HandleFunc("GET /api/download/search", s.handleOnlineSearch)
	mux.HandleFunc("POST /api/download/batch", s.handleOnlineBatchDownload)
	mux.HandleFunc("POST /api/download/song/", s.handleOnlineDownload)
	return s.cors(mux)
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (s *Server) requireAdmin(w http.ResponseWriter, r *http.Request) bool {
	profile, err := s.authProfile(r)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusUnauthorized, "请先登录管理员账号")
			return false
		}
		writeError(w, http.StatusInternalServerError, "failed to verify permission")
		return false
	}
	if !profile.IsAdmin {
		writeError(w, http.StatusForbidden, "普通用户无权维护系统曲库")
		return false
	}
	return true
}

func (s *Server) optionalUserID(r *http.Request) int64 {
	profile, err := s.authProfile(r)
	if err != nil {
		return 0
	}
	return profile.ID
}

func (s *Server) requireUser(w http.ResponseWriter, r *http.Request) (model.UserProfile, bool) {
	profile, err := s.authProfile(r)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusUnauthorized, "请先登录")
			return model.UserProfile{}, false
		}
		writeError(w, http.StatusInternalServerError, "failed to verify user")
		return model.UserProfile{}, false
	}
	return profile, true
}

func (s *Server) handleSongs(w http.ResponseWriter, r *http.Request) {
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	songs, err := s.repo.ListSongs(r.Context(), s.optionalUserID(r), limit)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to list songs")
		return
	}
	writeJSON(w, http.StatusOK, songs)
}

func (s *Server) handleSongsPage(w http.ResponseWriter, r *http.Request) {
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	cursor, _ := strconv.ParseInt(r.URL.Query().Get("cursor"), 10, 64)
	page, err := s.repo.ListSongsPage(r.Context(), s.optionalUserID(r), limit, cursor)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to list songs")
		return
	}
	writeJSON(w, http.StatusOK, page)
}

func (s *Server) handleDeleteSong(w http.ResponseWriter, r *http.Request) {
	if !s.requireAdmin(w, r) {
		return
	}
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || id <= 0 {
		writeError(w, http.StatusBadRequest, "invalid song id")
		return
	}
	audioPath, err := s.repo.DeleteSong(r.Context(), id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "song not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "failed to delete song")
		return
	}
	if audioPath != "" && !strings.HasPrefix(strings.ToLower(audioPath), "http://") && !strings.HasPrefix(strings.ToLower(audioPath), "https://") {
		if err := os.Remove(audioPath); err != nil && !errors.Is(err, os.ErrNotExist) {
			writeJSON(w, http.StatusOK, map[string]any{"deleted": true, "fileDeleted": false})
			return
		}
	}
	writeJSON(w, http.StatusOK, map[string]any{"deleted": true, "fileDeleted": audioPath != ""})
}

type updateSongRequest struct {
	Title          string `json:"title"`
	Artist         string `json:"artist"`
	Album          string `json:"album"`
	Lyrics         string `json:"lyrics"`
	LyricsOffsetMs int    `json:"lyricsOffsetMs"`
}

func (s *Server) handleUpdateSong(w http.ResponseWriter, r *http.Request) {
	if !s.requireAdmin(w, r) {
		return
	}
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || id <= 0 {
		writeError(w, http.StatusBadRequest, "invalid song id")
		return
	}
	var request updateSongRequest
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request")
		return
	}
	song, err := s.repo.UpdateSong(r.Context(), id, request.Title, request.Artist, request.Album, request.Lyrics, request.LyricsOffsetMs)
	if err != nil {
		if errors.Is(err, repository.ErrInvalidSongMetadata) {
			writeError(w, http.StatusBadRequest, "song title and artist are required")
			return
		}
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "song not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "failed to update song")
		return
	}
	writeJSON(w, http.StatusOK, song)
}

func (s *Server) handleFetchSongLyrics(w http.ResponseWriter, r *http.Request) {
	if !s.requireAdmin(w, r) {
		return
	}
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || id <= 0 {
		writeError(w, http.StatusBadRequest, "invalid song id")
		return
	}
	song, err := s.repo.GetSong(r.Context(), id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "song not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "failed to load song")
		return
	}
	lyrics, err := fetchLyricsByTitleArtist(r.Context(), song.Title, song.Artist)
	if err != nil {
		writeError(w, http.StatusBadGateway, err.Error())
		return
	}
	if strings.TrimSpace(lyrics) == "" {
		writeError(w, http.StatusNotFound, "没有找到匹配歌词")
		return
	}
	updated, err := s.repo.UpdateSong(r.Context(), song.ID, song.Title, song.Artist, song.Album, lyrics, song.LyricsOffsetMs)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to update lyrics")
		return
	}
	writeJSON(w, http.StatusOK, updated)
}

func (s *Server) handleSongStream(w http.ResponseWriter, r *http.Request) {
	path := strings.TrimPrefix(r.URL.Path, "/api/songs/")
	if !strings.HasSuffix(path, "/stream") {
		writeError(w, http.StatusNotFound, "song endpoint not found")
		return
	}

	idText := strings.TrimSuffix(path, "/stream")
	id, err := strconv.ParseInt(idText, 10, 64)
	if err != nil || id <= 0 {
		writeError(w, http.StatusBadRequest, "invalid song id")
		return
	}

	audioPath, err := s.repo.GetAccessibleSongAudioPath(r.Context(), id, s.optionalUserID(r))
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "song not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "failed to get song audio")
		return
	}
	if audioPath == "" {
		writeError(w, http.StatusNotFound, "song audio not found")
		return
	}
	info, err := os.Stat(audioPath)
	if err != nil {
		writeError(w, http.StatusNotFound, "song audio file not found")
		return
	}
	file, err := os.Open(audioPath)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to open song audio")
		return
	}
	defer file.Close()

	extension := strings.ToLower(filepath.Ext(audioPath))
	if extension == ".flac" {
		w.Header().Set("Content-Type", "audio/flac")
	} else if contentType := mime.TypeByExtension(extension); contentType != "" {
		w.Header().Set("Content-Type", contentType)
	} else {
		w.Header().Set("Content-Type", "audio/mpeg")
	}
	http.ServeContent(w, r, filepath.Base(audioPath), info.ModTime(), file)
}

func (s *Server) handleSearch(w http.ResponseWriter, r *http.Request) {
	songs, err := s.repo.SearchSongs(r.Context(), s.optionalUserID(r), r.URL.Query().Get("q"))
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to search songs")
		return
	}
	writeJSON(w, http.StatusOK, songs)
}

type favoriteRequest struct {
	Favorite bool `json:"favorite"`
}

func (s *Server) handleSongFavorite(w http.ResponseWriter, r *http.Request) {
	profile, err := s.authProfile(r)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusUnauthorized, "请先登录")
			return
		}
		writeError(w, http.StatusInternalServerError, "failed to verify user")
		return
	}
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || id <= 0 {
		writeError(w, http.StatusBadRequest, "invalid song id")
		return
	}
	var request favoriteRequest
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request")
		return
	}
	song, err := s.repo.UpdateSongFavorite(r.Context(), profile.ID, id, request.Favorite)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "song not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "failed to update favorite")
		return
	}
	writeJSON(w, http.StatusOK, song)
}

func (s *Server) handlePlaylists(w http.ResponseWriter, r *http.Request) {
	profile, ok := s.requireUser(w, r)
	if !ok {
		return
	}
	playlists, err := s.repo.ListPlaylists(r.Context(), profile.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to list playlists")
		return
	}
	writeJSON(w, http.StatusOK, playlists)
}

type createPlaylistRequest struct {
	Name        string `json:"name"`
	Description string `json:"description"`
}

func (s *Server) handleCreatePlaylist(w http.ResponseWriter, r *http.Request) {
	profile, ok := s.requireUser(w, r)
	if !ok {
		return
	}
	var request createPlaylistRequest
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request")
		return
	}
	owner := profile.Name
	if owner == "" {
		owner = profile.Username
	}
	playlist, err := s.repo.CreatePlaylist(r.Context(), profile.ID, request.Name, request.Description, owner)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusBadRequest, "playlist name is required")
			return
		}
		writeError(w, http.StatusInternalServerError, "failed to create playlist")
		return
	}
	writeJSON(w, http.StatusCreated, playlist)
}

func (s *Server) handleUpdatePlaylist(w http.ResponseWriter, r *http.Request) {
	profile, ok := s.requireUser(w, r)
	if !ok {
		return
	}
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || id <= 0 {
		writeError(w, http.StatusBadRequest, "invalid playlist id")
		return
	}
	var request createPlaylistRequest
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request")
		return
	}
	playlist, err := s.repo.UpdatePlaylist(r.Context(), profile.ID, id, request.Name, request.Description)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusBadRequest, "playlist name is required")
			return
		}
		writeError(w, http.StatusInternalServerError, "failed to update playlist")
		return
	}
	writeJSON(w, http.StatusOK, playlist)
}

func (s *Server) handleDeletePlaylist(w http.ResponseWriter, r *http.Request) {
	profile, ok := s.requireUser(w, r)
	if !ok {
		return
	}
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || id <= 0 {
		writeError(w, http.StatusBadRequest, "invalid playlist id")
		return
	}
	if err := s.repo.DeletePlaylist(r.Context(), profile.ID, id); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "playlist not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "failed to delete playlist")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"deleted": true})
}

func (s *Server) handlePlaylistFavorite(w http.ResponseWriter, r *http.Request) {
	profile, ok := s.requireUser(w, r)
	if !ok {
		return
	}
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || id <= 0 {
		writeError(w, http.StatusBadRequest, "invalid playlist id")
		return
	}
	var request favoriteRequest
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request")
		return
	}
	playlist, err := s.repo.UpdatePlaylistFavorite(r.Context(), profile.ID, id, request.Favorite)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "playlist not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "failed to update playlist favorite")
		return
	}
	writeJSON(w, http.StatusOK, playlist)
}

type playlistSongRequest struct {
	SongID int64 `json:"songId"`
}

type playlistSongOrderRequest struct {
	SongIDs []int64 `json:"songIds"`
}

func (s *Server) handleAddPlaylistSong(w http.ResponseWriter, r *http.Request) {
	profile, ok := s.requireUser(w, r)
	if !ok {
		return
	}
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || id <= 0 {
		writeError(w, http.StatusBadRequest, "invalid playlist id")
		return
	}
	var request playlistSongRequest
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request")
		return
	}
	playlist, err := s.repo.AddSongToPlaylist(r.Context(), profile.ID, id, request.SongID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "playlist or song not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "failed to add playlist song")
		return
	}
	writeJSON(w, http.StatusCreated, playlist)
}

func (s *Server) handleReorderPlaylistSongs(w http.ResponseWriter, r *http.Request) {
	profile, ok := s.requireUser(w, r)
	if !ok {
		return
	}
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || id <= 0 {
		writeError(w, http.StatusBadRequest, "invalid playlist id")
		return
	}
	var request playlistSongOrderRequest
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request")
		return
	}
	playlist, err := s.repo.ReorderPlaylistSongs(r.Context(), profile.ID, id, request.SongIDs)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusBadRequest, "playlist song order mismatch")
			return
		}
		writeError(w, http.StatusInternalServerError, "failed to reorder playlist songs")
		return
	}
	writeJSON(w, http.StatusOK, playlist)
}

func (s *Server) handleRemovePlaylistSong(w http.ResponseWriter, r *http.Request) {
	profile, ok := s.requireUser(w, r)
	if !ok {
		return
	}
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || id <= 0 {
		writeError(w, http.StatusBadRequest, "invalid playlist id")
		return
	}
	songID, err := strconv.ParseInt(r.PathValue("songId"), 10, 64)
	if err != nil || songID <= 0 {
		writeError(w, http.StatusBadRequest, "invalid song id")
		return
	}
	playlist, err := s.repo.RemoveSongFromPlaylist(r.Context(), profile.ID, id, songID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "playlist song not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "failed to remove playlist song")
		return
	}
	writeJSON(w, http.StatusOK, playlist)
}

func (s *Server) handlePlaylistDetail(w http.ResponseWriter, r *http.Request) {
	profile, ok := s.requireUser(w, r)
	if !ok {
		return
	}
	idText := strings.TrimPrefix(r.URL.Path, "/api/playlists/")
	id, err := strconv.ParseInt(idText, 10, 64)
	if err != nil || id <= 0 {
		writeError(w, http.StatusBadRequest, "invalid playlist id")
		return
	}

	playlist, err := s.repo.GetPlaylist(r.Context(), profile.ID, id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "playlist not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "failed to get playlist")
		return
	}
	writeJSON(w, http.StatusOK, playlist)
}

type loginRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

func (s *Server) handleLogin(w http.ResponseWriter, r *http.Request) {
	var request loginRequest
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request")
		return
	}
	session, err := s.repo.Authenticate(r.Context(), request.Username, request.Password)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusUnauthorized, "用户名或密码错误")
			return
		}
		writeError(w, http.StatusInternalServerError, "failed to login")
		return
	}
	writeJSON(w, http.StatusOK, session)
}

func (s *Server) handleProfile(w http.ResponseWriter, r *http.Request) {
	profile, err := s.authProfile(r)
	if err != nil && errors.Is(err, sql.ErrNoRows) {
		profile, err = s.repo.GetProfile(r.Context())
	}
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "profile not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "failed to get profile")
		return
	}
	writeJSON(w, http.StatusOK, profile)
}

func (s *Server) handleProfileOverview(w http.ResponseWriter, r *http.Request) {
	profile, err := s.authProfile(r)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusUnauthorized, "请先登录")
			return
		}
		writeError(w, http.StatusInternalServerError, "failed to get profile")
		return
	}
	overview, err := s.repo.ProfileOverview(r.Context(), profile)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to get profile overview")
		return
	}
	writeJSON(w, http.StatusOK, overview)
}

type recordPlayRequest struct {
	SongID int64 `json:"songId"`
}

func (s *Server) handlePlayHistory(w http.ResponseWriter, r *http.Request) {
	profile, err := s.authProfile(r)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusUnauthorized, "请先登录")
			return
		}
		writeError(w, http.StatusInternalServerError, "failed to get play history")
		return
	}
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	history, err := s.repo.ListPlayHistory(r.Context(), profile.ID, limit)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to get play history")
		return
	}
	writeJSON(w, http.StatusOK, history)
}

func (s *Server) handleRecordPlay(w http.ResponseWriter, r *http.Request) {
	var request recordPlayRequest
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request")
		return
	}
	profile, err := s.authProfile(r)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeJSON(w, http.StatusOK, map[string]bool{"recorded": false})
			return
		}
		writeError(w, http.StatusInternalServerError, "failed to record play")
		return
	}
	if err := s.repo.RecordPlay(r.Context(), profile.ID, request.SongID); err != nil {
		writeError(w, http.StatusInternalServerError, "failed to record play")
		return
	}
	writeJSON(w, http.StatusCreated, map[string]bool{"recorded": true})
}

func (s *Server) authProfile(r *http.Request) (model.UserProfile, error) {
	header := strings.TrimSpace(r.Header.Get("Authorization"))
	token := strings.TrimSpace(strings.TrimPrefix(header, "Bearer "))
	if token == "" || token == header {
		token = strings.TrimSpace(r.URL.Query().Get("token"))
		if token == "" {
			return model.UserProfile{}, sql.ErrNoRows
		}
	}
	return s.repo.ProfileByToken(r.Context(), token)
}

func (s *Server) handleDownloads(w http.ResponseWriter, r *http.Request) {
	profile, err := s.authProfile(r)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeJSON(w, http.StatusOK, []model.DownloadTask{})
			return
		}
		writeError(w, http.StatusInternalServerError, "failed to verify user")
		return
	}
	tasks, err := s.repo.ListDownloads(r.Context(), profile.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to list downloads")
		return
	}
	writeJSON(w, http.StatusOK, tasks)
}

func (s *Server) handleDownloadsPage(w http.ResponseWriter, r *http.Request) {
	profile, err := s.authProfile(r)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeJSON(w, http.StatusOK, model.DownloadTaskPage{})
			return
		}
		writeError(w, http.StatusInternalServerError, "failed to verify user")
		return
	}
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))
	status := r.URL.Query().Get("status")
	page, err := s.repo.ListDownloadsPage(r.Context(), profile.ID, status, limit, offset)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to list downloads")
		return
	}
	writeJSON(w, http.StatusOK, page)
}

type createDownloadRequest struct {
	SongID  int64  `json:"songId"`
	Quality string `json:"quality"`
}

func (s *Server) handleCreateDownload(w http.ResponseWriter, r *http.Request) {
	profile, err := s.authProfile(r)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusUnauthorized, "请先登录")
			return
		}
		writeError(w, http.StatusInternalServerError, "failed to verify user")
		return
	}
	var request createDownloadRequest
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request")
		return
	}
	if request.SongID <= 0 {
		writeError(w, http.StatusBadRequest, "invalid song id")
		return
	}
	song, err := s.repo.GetAccessibleSong(r.Context(), profile.ID, request.SongID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "song not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "failed to get song")
		return
	}
	if _, err := s.downloadSongToLocal(r.Context(), song); err != nil {
		writeError(w, http.StatusInternalServerError, "failed to download song")
		return
	}
	if err := s.repo.CreateDownload(r.Context(), profile.ID, request.SongID, request.Quality); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "song not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "failed to create download")
		return
	}
	tasks, err := s.repo.ListDownloads(r.Context(), profile.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to list downloads")
		return
	}
	writeJSON(w, http.StatusCreated, tasks)
}

func (s *Server) handleClearDownloads(w http.ResponseWriter, r *http.Request) {
	profile, err := s.authProfile(r)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusUnauthorized, "请先登录")
			return
		}
		writeError(w, http.StatusInternalServerError, "failed to verify user")
		return
	}
	status := r.URL.Query().Get("status")
	if err := s.repo.ClearDownloads(r.Context(), profile.ID, status); err != nil {
		writeError(w, http.StatusInternalServerError, "failed to clear downloads")
		return
	}
	tasks, err := s.repo.ListDownloads(r.Context(), profile.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to list downloads")
		return
	}
	writeJSON(w, http.StatusOK, tasks)
}

func (s *Server) cors(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if origin := s.allowedOrigin(r.Header.Get("Origin")); origin != "" {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Vary", "Origin")
		}
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func (s *Server) allowedOrigin(origin string) string {
	origin = strings.TrimSpace(origin)
	if origin == "" {
		return ""
	}
	for _, allowed := range s.allowedOrigins {
		if allowed == "*" || allowed == origin {
			return allowed
		}
	}
	return ""
}
