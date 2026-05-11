package repository

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"

	"golang.org/x/crypto/bcrypt"

	"musicflow-backend/internal/model"
)

type Repository struct {
	db *sql.DB
}

var ErrInvalidSongMetadata = errors.New("invalid song metadata")

func New(db *sql.DB) *Repository {
	return &Repository{db: db}
}

func (r *Repository) EnsureSchema(ctx context.Context) error {
	if err := r.ensureColumn(ctx, "songs", "lyrics", "ALTER TABLE songs ADD COLUMN lyrics MEDIUMTEXT NULL AFTER is_favorite"); err != nil {
		return err
	}
	if err := r.ensureColumn(ctx, "songs", "lyrics_offset_ms", "ALTER TABLE songs ADD COLUMN lyrics_offset_ms INT NOT NULL DEFAULT 0 AFTER lyrics"); err != nil {
		return err
	}
	if err := r.ensureColumn(ctx, "songs", "visibility", "ALTER TABLE songs ADD COLUMN visibility VARCHAR(16) NOT NULL DEFAULT 'public' AFTER source"); err != nil {
		return err
	}
	if err := r.ensureColumn(ctx, "songs", "owner_user_id", "ALTER TABLE songs ADD COLUMN owner_user_id BIGINT NOT NULL DEFAULT 0 AFTER visibility"); err != nil {
		return err
	}
	if err := r.ensureColumn(ctx, "playlists", "is_favorite", "ALTER TABLE playlists ADD COLUMN is_favorite BOOLEAN NOT NULL DEFAULT FALSE AFTER owner"); err != nil {
		return err
	}
	if err := r.ensureColumn(ctx, "playlists", "user_id", "ALTER TABLE playlists ADD COLUMN user_id BIGINT NOT NULL DEFAULT 0 AFTER id"); err != nil {
		return err
	}
	if err := r.ensureColumn(ctx, "download_tasks", "user_id", "ALTER TABLE download_tasks ADD COLUMN user_id BIGINT NOT NULL DEFAULT 0 AFTER id"); err != nil {
		return err
	}
	if err := r.ensureColumn(ctx, "download_tasks", "updated_at", "ALTER TABLE download_tasks ADD COLUMN updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER status"); err != nil {
		return err
	}
	if err := r.ensureColumn(ctx, "user_profiles", "username", "ALTER TABLE user_profiles ADD COLUMN username VARCHAR(64) NOT NULL DEFAULT '' AFTER name"); err != nil {
		return err
	}
	if err := r.ensureColumn(ctx, "user_profiles", "is_admin", "ALTER TABLE user_profiles ADD COLUMN is_admin BOOLEAN NOT NULL DEFAULT FALSE AFTER vip"); err != nil {
		return err
	}
	_, err := r.db.ExecContext(ctx, `
		CREATE TABLE IF NOT EXISTS users (
			id BIGINT PRIMARY KEY AUTO_INCREMENT,
			username VARCHAR(64) NOT NULL UNIQUE,
			password_hash CHAR(64) NOT NULL,
			name VARCHAR(64) NOT NULL,
			avatar_url VARCHAR(512) NOT NULL DEFAULT '',
			vip BOOLEAN NOT NULL DEFAULT FALSE,
			is_admin BOOLEAN NOT NULL DEFAULT FALSE,
			storage_limit_mb INT NOT NULL DEFAULT 10240,
			created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
		)`)
	if err != nil {
		return err
	}
	_, err = r.db.ExecContext(ctx, `
		CREATE TABLE IF NOT EXISTS user_favorite_songs (
			user_id BIGINT NOT NULL,
			song_id BIGINT NOT NULL,
			created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
			PRIMARY KEY (user_id, song_id),
			INDEX idx_user_favorite_songs_song (song_id),
			CONSTRAINT fk_user_favorite_songs_song FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE
		)`)
	if err != nil {
		return err
	}
	if err := r.ensureColumn(ctx, "users", "is_admin", "ALTER TABLE users ADD COLUMN is_admin BOOLEAN NOT NULL DEFAULT FALSE AFTER vip"); err != nil {
		return err
	}
	_, err = r.db.ExecContext(ctx, `
		CREATE TABLE IF NOT EXISTS play_history (
			id BIGINT PRIMARY KEY AUTO_INCREMENT,
			user_id BIGINT NOT NULL DEFAULT 0,
			song_id BIGINT NOT NULL,
			played_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
			INDEX idx_play_history_user_time (user_id, played_at),
			INDEX idx_play_history_song (song_id),
			CONSTRAINT fk_play_history_song FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE
		)`)
	if err != nil {
		return err
	}
	_, err = r.db.ExecContext(ctx, `
		CREATE TABLE IF NOT EXISTS song_heat_stats (
			song_id BIGINT PRIMARY KEY,
			play_count INT NOT NULL DEFAULT 0,
			calculated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
			INDEX idx_song_heat_stats_count (play_count),
			CONSTRAINT fk_song_heat_stats_song FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE
		)`)
	if err != nil {
		return err
	}
	if _, err := r.db.ExecContext(ctx, `ALTER TABLE users MODIFY password_hash VARCHAR(128) NOT NULL`); err != nil {
		return err
	}
	if err := r.ensureIndex(ctx, "playlists", "idx_playlists_user_updated", "CREATE INDEX idx_playlists_user_updated ON playlists(user_id, updated_at)"); err != nil {
		return err
	}
	if err := r.ensureIndex(ctx, "download_tasks", "idx_download_tasks_user_status", "CREATE INDEX idx_download_tasks_user_status ON download_tasks(user_id, status)"); err != nil {
		return err
	}
	if err := r.ensureIndex(ctx, "download_tasks", "idx_download_tasks_user_updated", "CREATE INDEX idx_download_tasks_user_updated ON download_tasks(user_id, updated_at, id)"); err != nil {
		return err
	}
	if _, err := r.db.ExecContext(ctx, `
		DELETE d1 FROM download_tasks d1
		INNER JOIN download_tasks d2
			ON d1.user_id = d2.user_id
			AND d1.song_id = d2.song_id
			AND d1.id > d2.id`); err != nil {
		return err
	}
	if err := r.ensureIndex(ctx, "download_tasks", "idx_download_tasks_user_song", "CREATE UNIQUE INDEX idx_download_tasks_user_song ON download_tasks(user_id, song_id)"); err != nil {
		return err
	}
	if err := r.ensureIndex(ctx, "play_history", "idx_play_history_song", "CREATE INDEX idx_play_history_song ON play_history(song_id)"); err != nil {
		return err
	}
	if err := r.ensureIndex(ctx, "songs", "idx_songs_created", "CREATE INDEX idx_songs_created ON songs(created_at)"); err != nil {
		return err
	}
	if err := r.ensureIndex(ctx, "songs", "idx_songs_visibility_owner", "CREATE INDEX idx_songs_visibility_owner ON songs(visibility, owner_user_id)"); err != nil {
		return err
	}
	if err := r.ensureDefaultAccounts(ctx); err != nil {
		return err
	}
	return nil
}

func (r *Repository) ensureColumn(ctx context.Context, table string, column string, statement string) error {
	var count int
	err := r.db.QueryRowContext(ctx, `
		SELECT COUNT(*)
		FROM information_schema.columns
		WHERE table_schema = DATABASE() AND table_name = ? AND column_name = ?`, table, column).Scan(&count)
	if err != nil {
		return err
	}
	if count > 0 {
		return nil
	}
	_, err = r.db.ExecContext(ctx, statement)
	return err
}

func (r *Repository) ensureIndex(ctx context.Context, table string, index string, statement string) error {
	var count int
	err := r.db.QueryRowContext(ctx, `
		SELECT COUNT(*)
		FROM information_schema.statistics
		WHERE table_schema = DATABASE() AND table_name = ? AND index_name = ?`, table, index).Scan(&count)
	if err != nil {
		return err
	}
	if count > 0 {
		return nil
	}
	_, err = r.db.ExecContext(ctx, statement)
	return err
}

func (r *Repository) ensureDefaultAccounts(ctx context.Context) error {
	adminUsername := strings.TrimSpace(os.Getenv("MUSICFLOW_ADMIN_USERNAME"))
	if adminUsername == "" {
		adminUsername = "admin"
	}
	adminName := strings.TrimSpace(os.Getenv("MUSICFLOW_ADMIN_NAME"))
	if adminName == "" {
		adminName = "管理员"
	}
	if adminPassword := os.Getenv("MUSICFLOW_ADMIN_PASSWORD"); adminPassword != "" {
		passwordHash, err := createPasswordHash(adminPassword)
		if err != nil {
			return err
		}
		if _, err := r.db.ExecContext(ctx, `
			INSERT INTO users (username, password_hash, name, avatar_url, vip, is_admin, storage_limit_mb)
			VALUES (?, ?, ?, '', TRUE, TRUE, 10240)
			ON DUPLICATE KEY UPDATE
				password_hash = VALUES(password_hash),
				name = VALUES(name),
				vip = TRUE,
				is_admin = TRUE,
				storage_limit_mb = VALUES(storage_limit_mb)`, adminUsername, passwordHash, adminName); err != nil {
			return err
		}
	}
	if _, err := r.db.ExecContext(ctx, `
		UPDATE users
		SET is_admin = TRUE
		WHERE username = ?`, adminUsername); err != nil {
		return err
	}
	if _, err := r.db.ExecContext(ctx, `
		UPDATE user_profiles
		SET is_admin = TRUE
		WHERE username = ?`, adminUsername); err != nil {
		return err
	}
	if _, err := r.db.ExecContext(ctx, `
		INSERT IGNORE INTO user_favorite_songs (user_id, song_id)
		SELECT u.id, s.id
		FROM users u
		INNER JOIN songs s ON s.is_favorite = TRUE
		WHERE u.username = ?`, adminUsername); err != nil {
		return err
	}
	if _, err := r.db.ExecContext(ctx, `
		UPDATE songs
		SET is_favorite = FALSE
		WHERE is_favorite = TRUE`); err != nil {
		return err
	}
	if _, err := r.db.ExecContext(ctx, `
		UPDATE download_tasks d
		INNER JOIN users u ON u.username = ?
		SET d.user_id = u.id
		WHERE d.user_id = 0`, adminUsername); err != nil {
		return err
	}
	if _, err := r.db.ExecContext(ctx, `
		UPDATE playlists p
		INNER JOIN users u ON u.username = ?
		SET p.user_id = u.id
		WHERE p.user_id = 0`, adminUsername); err != nil {
		return err
	}
	demoPassword := os.Getenv("MUSICFLOW_DEMO_PASSWORD")
	if demoPassword == "" {
		return nil
	}
	passwordHash, err := createPasswordHash(demoPassword)
	if err != nil {
		return err
	}
	_, err = r.db.ExecContext(ctx, `
		INSERT INTO users (username, password_hash, name, avatar_url, vip, is_admin, storage_limit_mb)
		VALUES ('normal', ?, '普通用户', '', FALSE, FALSE, 10240)
		ON DUPLICATE KEY UPDATE
			password_hash = VALUES(password_hash),
			name = VALUES(name),
			vip = FALSE,
			is_admin = FALSE,
			storage_limit_mb = VALUES(storage_limit_mb)`, passwordHash)
	return err
}

func (r *Repository) ListSongs(ctx context.Context, userID int64, limit int) ([]model.Song, error) {
	if limit <= 0 {
		limit = 100
	}
	if limit > 1000 {
		limit = 1000
	}

	rows, err := r.db.QueryContext(ctx, `
		SELECT s.id, s.title, s.artist, s.album, s.duration, s.cover_url, s.audio_url, s.source,
		       CASE WHEN uf.song_id IS NULL THEN FALSE ELSE TRUE END AS is_favorite,
		       COALESCE(s.lyrics, ''), COALESCE(s.lyrics_offset_ms, 0), COALESCE(ph.play_count, 0), s.created_at
		FROM songs s
		LEFT JOIN user_favorite_songs uf ON uf.song_id = s.id AND uf.user_id = ?
		LEFT JOIN song_heat_stats ph ON ph.song_id = s.id
		WHERE (s.visibility = 'public' OR (s.visibility = 'private' AND s.owner_user_id = ?))
		ORDER BY COALESCE(ph.play_count, 0) DESC, s.id ASC
		LIMIT ?`, userID, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return scanSongs(rows)
}

func (r *Repository) ListSongsPage(ctx context.Context, userID int64, limit int, cursor int64) (model.SongPage, error) {
	if limit <= 0 {
		limit = 80
	}
	if limit > 200 {
		limit = 200
	}
	offset := cursor
	if offset < 0 {
		offset = 0
	}
	var totalCount int
	if err := r.db.QueryRowContext(ctx, `
		SELECT COUNT(*)
		FROM songs
		WHERE visibility = 'public' OR (visibility = 'private' AND owner_user_id = ?)`, userID).Scan(&totalCount); err != nil {
		return model.SongPage{}, err
	}
	rows, err := r.db.QueryContext(ctx, `
		SELECT s.id, s.title, s.artist, s.album, s.duration, s.cover_url, s.audio_url, s.source,
		       CASE WHEN uf.song_id IS NULL THEN FALSE ELSE TRUE END AS is_favorite,
		       COALESCE(s.lyrics, ''), COALESCE(s.lyrics_offset_ms, 0), COALESCE(ph.play_count, 0), s.created_at
		FROM songs s
		LEFT JOIN user_favorite_songs uf ON uf.song_id = s.id AND uf.user_id = ?
		LEFT JOIN song_heat_stats ph ON ph.song_id = s.id
		WHERE (s.visibility = 'public' OR (s.visibility = 'private' AND s.owner_user_id = ?))
		ORDER BY COALESCE(ph.play_count, 0) DESC, s.id ASC
		LIMIT ? OFFSET ?`, userID, userID, limit+1, offset)
	if err != nil {
		return model.SongPage{}, err
	}
	defer rows.Close()
	items, err := scanSongs(rows)
	if err != nil {
		return model.SongPage{}, err
	}
	hasMore := len(items) > limit
	if hasMore {
		items = items[:limit]
	}
	nextCursor := int64(0)
	if hasMore {
		nextCursor = offset + int64(limit)
	}
	return model.SongPage{
		Items:      items,
		NextCursor: nextCursor,
		HasMore:    hasMore,
		TotalCount: totalCount,
	}, nil
}

func (r *Repository) SearchSongs(ctx context.Context, userID int64, keyword string) ([]model.Song, error) {
	keyword = strings.TrimSpace(keyword)
	if keyword == "" {
		return []model.Song{}, nil
	}

	like := fmt.Sprintf("%%%s%%", keyword)
	rows, err := r.db.QueryContext(ctx, `
		SELECT s.id, s.title, s.artist, s.album, s.duration, s.cover_url, s.audio_url, s.source,
		       CASE WHEN uf.song_id IS NULL THEN FALSE ELSE TRUE END AS is_favorite,
		       COALESCE(s.lyrics, ''), COALESCE(s.lyrics_offset_ms, 0), COALESCE(ph.play_count, 0), s.created_at
		FROM songs s
		LEFT JOIN user_favorite_songs uf ON uf.song_id = s.id AND uf.user_id = ?
		LEFT JOIN song_heat_stats ph ON ph.song_id = s.id
		WHERE (s.visibility = 'public' OR (s.visibility = 'private' AND s.owner_user_id = ?))
		  AND (s.title LIKE ? OR s.artist LIKE ? OR s.album LIKE ?)
		ORDER BY COALESCE(ph.play_count, 0) DESC, s.id ASC
		LIMIT 50`, userID, userID, like, like, like)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return scanSongs(rows)
}

func (r *Repository) FindSongByTitleArtist(ctx context.Context, title string, artist string) (model.Song, error) {
	title = strings.TrimSpace(title)
	artist = strings.TrimSpace(artist)
	if title == "" {
		return model.Song{}, sql.ErrNoRows
	}
	rows, err := r.db.QueryContext(ctx, `
		SELECT id, title, artist, album, duration, cover_url, audio_url, source, is_favorite, COALESCE(lyrics, ''), COALESCE(lyrics_offset_ms, 0), created_at
		FROM songs
		WHERE LOWER(TRIM(title)) = LOWER(TRIM(?))
		  AND (? = '' OR LOWER(TRIM(artist)) = LOWER(TRIM(?)))
		  AND visibility = 'public'
		ORDER BY id ASC
		LIMIT 1`, title, artist, artist)
	if err != nil {
		return model.Song{}, err
	}
	defer rows.Close()
	songs, err := scanSongs(rows)
	if err != nil {
		return model.Song{}, err
	}
	if len(songs) == 0 {
		return model.Song{}, sql.ErrNoRows
	}
	return songs[0], nil
}

func (r *Repository) FindAccessibleSongByTitleArtist(ctx context.Context, userID int64, title string, artist string) (model.Song, error) {
	title = strings.TrimSpace(title)
	artist = strings.TrimSpace(artist)
	if title == "" {
		return model.Song{}, sql.ErrNoRows
	}
	rows, err := r.db.QueryContext(ctx, `
		SELECT id, title, artist, album, duration, cover_url, audio_url, source, is_favorite, COALESCE(lyrics, ''), COALESCE(lyrics_offset_ms, 0), created_at
		FROM songs
		WHERE LOWER(TRIM(title)) = LOWER(TRIM(?))
		  AND (? = '' OR LOWER(TRIM(artist)) = LOWER(TRIM(?)))
		  AND (visibility = 'public' OR (visibility = 'private' AND owner_user_id = ?))
		ORDER BY CASE WHEN visibility = 'public' THEN 0 ELSE 1 END, id ASC
		LIMIT 1`, title, artist, artist, userID)
	if err != nil {
		return model.Song{}, err
	}
	defer rows.Close()
	songs, err := scanSongs(rows)
	if err != nil {
		return model.Song{}, err
	}
	if len(songs) == 0 {
		return model.Song{}, sql.ErrNoRows
	}
	return songs[0], nil
}

func (r *Repository) Authenticate(ctx context.Context, username string, password string) (model.AuthSession, error) {
	username = strings.TrimSpace(username)
	if username == "" || password == "" {
		return model.AuthSession{}, sql.ErrNoRows
	}
	var profile model.UserProfile
	var passwordHash string
	err := r.db.QueryRowContext(ctx, `
		SELECT id, username, name, avatar_url, vip, is_admin, storage_limit_mb, password_hash
		FROM users
		WHERE username = ?
		LIMIT 1`, username).Scan(
		&profile.ID,
		&profile.Username,
		&profile.Name,
		&profile.AvatarURL,
		&profile.Vip,
		&profile.IsAdmin,
		&profile.StorageLimitMB,
		&passwordHash,
	)
	if err != nil {
		return model.AuthSession{}, err
	}
	valid, upgradedHash, err := verifyPasswordHash(passwordHash, password)
	if err != nil {
		return model.AuthSession{}, err
	}
	if !valid {
		return model.AuthSession{}, sql.ErrNoRows
	}
	if upgradedHash != "" {
		if _, err := r.db.ExecContext(ctx, `UPDATE users SET password_hash = ? WHERE id = ?`, upgradedHash, profile.ID); err != nil {
			return model.AuthSession{}, err
		}
		passwordHash = upgradedHash
	}
	token := signToken(profile.ID, profile.Username, passwordHash)
	return model.AuthSession{Token: token, User: profile}, nil
}

func (r *Repository) ProfileByToken(ctx context.Context, token string) (model.UserProfile, error) {
	parts := strings.Split(token, ".")
	if len(parts) != 2 {
		return model.UserProfile{}, sql.ErrNoRows
	}
	id, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil || id <= 0 {
		return model.UserProfile{}, sql.ErrNoRows
	}
	var profile model.UserProfile
	var passwordHash string
	err = r.db.QueryRowContext(ctx, `
		SELECT id, username, name, avatar_url, vip, is_admin, storage_limit_mb, password_hash
		FROM users
		WHERE id = ?
		LIMIT 1`, id).Scan(
		&profile.ID,
		&profile.Username,
		&profile.Name,
		&profile.AvatarURL,
		&profile.Vip,
		&profile.IsAdmin,
		&profile.StorageLimitMB,
		&passwordHash,
	)
	if err != nil {
		return model.UserProfile{}, err
	}
	if token != signToken(profile.ID, profile.Username, passwordHash) {
		return model.UserProfile{}, sql.ErrNoRows
	}
	return r.hydrateProfileStats(ctx, profile)
}

func (r *Repository) GetSongAudioPath(ctx context.Context, id int64) (string, error) {
	var audioURL string
	err := r.db.QueryRowContext(ctx, `SELECT audio_url FROM songs WHERE id = ?`, id).Scan(&audioURL)
	return audioURL, err
}

func (r *Repository) GetAccessibleSongAudioPath(ctx context.Context, id int64, userID int64) (string, error) {
	var audioURL string
	err := r.db.QueryRowContext(ctx, `
		SELECT audio_url
		FROM songs
		WHERE id = ?
		  AND (visibility = 'public' OR (visibility = 'private' AND owner_user_id = ?))`, id, userID).Scan(&audioURL)
	return audioURL, err
}

func (r *Repository) GetSong(ctx context.Context, id int64) (model.Song, error) {
	if id <= 0 {
		return model.Song{}, sql.ErrNoRows
	}
	rows, err := r.db.QueryContext(ctx, `
		SELECT id, title, artist, album, duration, cover_url, audio_url, source, is_favorite, COALESCE(lyrics, ''), COALESCE(lyrics_offset_ms, 0), created_at
		FROM songs
		WHERE id = ?`, id)
	if err != nil {
		return model.Song{}, err
	}
	defer rows.Close()
	songs, err := scanSongs(rows)
	if err != nil {
		return model.Song{}, err
	}
	if len(songs) == 0 {
		return model.Song{}, sql.ErrNoRows
	}
	return songs[0], nil
}

func (r *Repository) GetAccessibleSong(ctx context.Context, userID int64, id int64) (model.Song, error) {
	if id <= 0 {
		return model.Song{}, sql.ErrNoRows
	}
	rows, err := r.db.QueryContext(ctx, `
		SELECT id, title, artist, album, duration, cover_url, audio_url, source, is_favorite, COALESCE(lyrics, ''), COALESCE(lyrics_offset_ms, 0), created_at
		FROM songs
		WHERE id = ?
		  AND (visibility = 'public' OR (visibility = 'private' AND owner_user_id = ?))`, id, userID)
	if err != nil {
		return model.Song{}, err
	}
	defer rows.Close()
	songs, err := scanSongs(rows)
	if err != nil {
		return model.Song{}, err
	}
	if len(songs) == 0 {
		return model.Song{}, sql.ErrNoRows
	}
	return songs[0], nil
}

func (r *Repository) DeleteSong(ctx context.Context, id int64) (string, error) {
	if id <= 0 {
		return "", sql.ErrNoRows
	}
	audioPath, err := r.GetSongAudioPath(ctx, id)
	if err != nil {
		return "", err
	}
	result, err := r.db.ExecContext(ctx, `DELETE FROM songs WHERE id = ?`, id)
	if err != nil {
		return "", err
	}
	affected, err := result.RowsAffected()
	if err != nil {
		return "", err
	}
	if affected == 0 {
		return "", sql.ErrNoRows
	}
	return audioPath, nil
}

func (r *Repository) UpdateSongFavorite(ctx context.Context, userID int64, id int64, favorite bool) (model.Song, error) {
	if userID <= 0 || id <= 0 {
		return model.Song{}, sql.ErrNoRows
	}
	var exists int
	if err := r.db.QueryRowContext(ctx, `
		SELECT COUNT(*)
		FROM songs
		WHERE id = ? AND (visibility = 'public' OR (visibility = 'private' AND owner_user_id = ?))`, id, userID).Scan(&exists); err != nil {
		return model.Song{}, err
	}
	if exists == 0 {
		return model.Song{}, sql.ErrNoRows
	}
	if favorite {
		_, err := r.db.ExecContext(ctx, `
			INSERT INTO user_favorite_songs (user_id, song_id)
			VALUES (?, ?)
			ON DUPLICATE KEY UPDATE created_at = created_at`, userID, id)
		if err != nil {
			return model.Song{}, err
		}
	} else if _, err := r.db.ExecContext(ctx, `DELETE FROM user_favorite_songs WHERE user_id = ? AND song_id = ?`, userID, id); err != nil {
		return model.Song{}, err
	}
	rows, err := r.db.QueryContext(ctx, `
		SELECT s.id, s.title, s.artist, s.album, s.duration, s.cover_url, s.audio_url, s.source,
		       CASE WHEN uf.song_id IS NULL THEN FALSE ELSE TRUE END AS is_favorite,
		       COALESCE(s.lyrics, ''), COALESCE(s.lyrics_offset_ms, 0), s.created_at
		FROM songs s
		LEFT JOIN user_favorite_songs uf ON uf.song_id = s.id AND uf.user_id = ?
		WHERE s.id = ?`, userID, id)
	if err != nil {
		return model.Song{}, err
	}
	defer rows.Close()
	songs, err := scanSongs(rows)
	if err != nil {
		return model.Song{}, err
	}
	if len(songs) == 0 {
		return model.Song{}, sql.ErrNoRows
	}
	return songs[0], nil
}

func (r *Repository) UpdateSong(ctx context.Context, id int64, title string, artist string, album string, lyrics string, lyricsOffsetMs int) (model.Song, error) {
	title = strings.TrimSpace(title)
	artist = strings.TrimSpace(artist)
	album = strings.TrimSpace(album)
	lyrics = strings.TrimSpace(lyrics)
	if id <= 0 {
		return model.Song{}, sql.ErrNoRows
	}
	if title == "" || artist == "" {
		return model.Song{}, ErrInvalidSongMetadata
	}
	_, err := r.db.ExecContext(ctx, `
		UPDATE songs
		SET title = ?,
		    artist = ?,
		    album = ?,
		    lyrics = ?,
		    lyrics_offset_ms = ?
		WHERE id = ?`, title, artist, album, lyrics, lyricsOffsetMs, id)
	if err != nil {
		return model.Song{}, err
	}
	return r.GetSong(ctx, id)
}

func (r *Repository) CreateSong(ctx context.Context, song model.Song) (model.Song, error) {
	return r.CreateSongScoped(ctx, song, "public", 0)
}

func (r *Repository) CreateSongScoped(ctx context.Context, song model.Song, visibility string, ownerUserID int64) (model.Song, error) {
	visibility = strings.TrimSpace(strings.ToLower(visibility))
	if visibility != "private" {
		visibility = "public"
		ownerUserID = 0
	} else if ownerUserID <= 0 {
		return model.Song{}, sql.ErrNoRows
	}
	result, err := r.db.ExecContext(ctx, `
		INSERT INTO songs (title, artist, album, duration, cover_url, audio_url, source, visibility, owner_user_id, is_favorite, lyrics)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		song.Title,
		song.Artist,
		song.Album,
		song.Duration,
		song.CoverURL,
		song.AudioURL,
		song.Source,
		visibility,
		ownerUserID,
		song.IsFavorite,
		song.Lyrics,
	)
	if err != nil {
		return model.Song{}, err
	}
	id, err := result.LastInsertId()
	if err != nil {
		return model.Song{}, err
	}
	rows, err := r.db.QueryContext(ctx, `
		SELECT id, title, artist, album, duration, cover_url, audio_url, source, is_favorite, COALESCE(lyrics, ''), COALESCE(lyrics_offset_ms, 0), created_at
		FROM songs
		WHERE id = ?`, id)
	if err != nil {
		return model.Song{}, err
	}
	defer rows.Close()
	songs, err := scanSongs(rows)
	if err != nil {
		return model.Song{}, err
	}
	if len(songs) == 0 {
		return model.Song{}, sql.ErrNoRows
	}
	return songs[0], nil
}

func (r *Repository) UpdateSongMetadata(ctx context.Context, id int64, duration int, lyrics string) (model.Song, error) {
	if id <= 0 {
		return model.Song{}, sql.ErrNoRows
	}
	_, err := r.db.ExecContext(ctx, `
		UPDATE songs
		SET duration = CASE WHEN ? > 0 THEN ? ELSE duration END,
		    lyrics = CASE WHEN ? <> '' THEN ? ELSE lyrics END
		WHERE id = ?`, duration, duration, lyrics, lyrics, id)
	if err != nil {
		return model.Song{}, err
	}
	rows, err := r.db.QueryContext(ctx, `
		SELECT id, title, artist, album, duration, cover_url, audio_url, source, is_favorite, COALESCE(lyrics, ''), COALESCE(lyrics_offset_ms, 0), created_at
		FROM songs
		WHERE id = ?`, id)
	if err != nil {
		return model.Song{}, err
	}
	defer rows.Close()
	songs, err := scanSongs(rows)
	if err != nil {
		return model.Song{}, err
	}
	if len(songs) == 0 {
		return model.Song{}, sql.ErrNoRows
	}
	return songs[0], nil
}

func (r *Repository) UpdateSongAudioMetadata(ctx context.Context, id int64, audioURL string, source string, duration int, lyrics string) (model.Song, error) {
	if id <= 0 {
		return model.Song{}, sql.ErrNoRows
	}
	_, err := r.db.ExecContext(ctx, `
		UPDATE songs
		SET audio_url = ?,
		    source = ?,
		    duration = CASE WHEN ? > 0 THEN ? ELSE duration END,
		    lyrics = CASE WHEN ? <> '' THEN ? ELSE lyrics END
		WHERE id = ?`, audioURL, source, duration, duration, lyrics, lyrics, id)
	if err != nil {
		return model.Song{}, err
	}
	rows, err := r.db.QueryContext(ctx, `
		SELECT id, title, artist, album, duration, cover_url, audio_url, source, is_favorite, COALESCE(lyrics, ''), COALESCE(lyrics_offset_ms, 0), created_at
		FROM songs
		WHERE id = ?`, id)
	if err != nil {
		return model.Song{}, err
	}
	defer rows.Close()
	songs, err := scanSongs(rows)
	if err != nil {
		return model.Song{}, err
	}
	if len(songs) == 0 {
		return model.Song{}, sql.ErrNoRows
	}
	return songs[0], nil
}

func (r *Repository) ListPlaylists(ctx context.Context, userID int64) ([]model.Playlist, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT p.id, p.name, p.description, p.cover_url, p.owner, p.is_favorite, COUNT(ps.song_id) AS song_count,
		       COALESCE(SUM(s.duration), 0) AS total_time, p.updated_at
		FROM playlists p
		LEFT JOIN playlist_songs ps ON ps.playlist_id = p.id
		LEFT JOIN songs s ON s.id = ps.song_id
		WHERE p.user_id = ?
		GROUP BY p.id, p.name, p.description, p.cover_url, p.owner, p.is_favorite, p.updated_at
		ORDER BY p.updated_at DESC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	playlists := make([]model.Playlist, 0)
	for rows.Next() {
		var playlist model.Playlist
		if err := rows.Scan(
			&playlist.ID,
			&playlist.Name,
			&playlist.Description,
			&playlist.CoverURL,
			&playlist.Owner,
			&playlist.IsFavorite,
			&playlist.SongCount,
			&playlist.TotalTime,
			&playlist.UpdatedAt,
		); err != nil {
			return nil, err
		}
		playlists = append(playlists, playlist)
	}

	return playlists, rows.Err()
}

func (r *Repository) CreatePlaylist(ctx context.Context, userID int64, name string, description string, owner string) (model.Playlist, error) {
	name = strings.TrimSpace(name)
	description = strings.TrimSpace(description)
	owner = strings.TrimSpace(owner)
	if userID <= 0 || name == "" {
		return model.Playlist{}, sql.ErrNoRows
	}
	result, err := r.db.ExecContext(ctx, `
		INSERT INTO playlists (user_id, name, description, owner)
		VALUES (?, ?, ?, ?)`, userID, name, description, owner)
	if err != nil {
		return model.Playlist{}, err
	}
	id, err := result.LastInsertId()
	if err != nil {
		return model.Playlist{}, err
	}
	return r.GetPlaylist(ctx, userID, id)
}

func (r *Repository) UpdatePlaylist(ctx context.Context, userID int64, id int64, name string, description string) (model.Playlist, error) {
	name = strings.TrimSpace(name)
	description = strings.TrimSpace(description)
	if userID <= 0 || id <= 0 || name == "" {
		return model.Playlist{}, sql.ErrNoRows
	}
	result, err := r.db.ExecContext(ctx, `
		UPDATE playlists
		SET name = ?, description = ?, updated_at = CURRENT_TIMESTAMP
		WHERE id = ? AND user_id = ?`, name, description, id, userID)
	if err != nil {
		return model.Playlist{}, err
	}
	affected, err := result.RowsAffected()
	if err != nil {
		return model.Playlist{}, err
	}
	if affected == 0 {
		return model.Playlist{}, sql.ErrNoRows
	}
	return r.GetPlaylist(ctx, userID, id)
}

func (r *Repository) DeletePlaylist(ctx context.Context, userID int64, id int64) error {
	if userID <= 0 || id <= 0 {
		return sql.ErrNoRows
	}
	result, err := r.db.ExecContext(ctx, `DELETE FROM playlists WHERE id = ? AND user_id = ?`, id, userID)
	if err != nil {
		return err
	}
	affected, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if affected == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (r *Repository) UpdatePlaylistFavorite(ctx context.Context, userID int64, id int64, favorite bool) (model.Playlist, error) {
	if userID <= 0 || id <= 0 {
		return model.Playlist{}, sql.ErrNoRows
	}
	result, err := r.db.ExecContext(ctx, `UPDATE playlists SET is_favorite = ? WHERE id = ? AND user_id = ?`, favorite, id, userID)
	if err != nil {
		return model.Playlist{}, err
	}
	affected, err := result.RowsAffected()
	if err != nil {
		return model.Playlist{}, err
	}
	if affected == 0 {
		return model.Playlist{}, sql.ErrNoRows
	}
	return r.GetPlaylist(ctx, userID, id)
}

func (r *Repository) AddSongToPlaylist(ctx context.Context, userID int64, playlistID int64, songID int64) (model.Playlist, error) {
	if userID <= 0 || playlistID <= 0 || songID <= 0 {
		return model.Playlist{}, sql.ErrNoRows
	}
	var exists int
	if err := r.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM playlists WHERE id = ? AND user_id = ?`, playlistID, userID).Scan(&exists); err != nil {
		return model.Playlist{}, err
	}
	if exists == 0 {
		return model.Playlist{}, sql.ErrNoRows
	}
	if err := r.db.QueryRowContext(ctx, `
		SELECT COUNT(*)
		FROM songs
		WHERE id = ? AND (visibility = 'public' OR (visibility = 'private' AND owner_user_id = ?))`, songID, userID).Scan(&exists); err != nil {
		return model.Playlist{}, err
	}
	if exists == 0 {
		return model.Playlist{}, sql.ErrNoRows
	}
	var nextOrder int
	if err := r.db.QueryRowContext(ctx, `SELECT COALESCE(MAX(sort_order), 0) + 1 FROM playlist_songs WHERE playlist_id = ?`, playlistID).Scan(&nextOrder); err != nil {
		return model.Playlist{}, err
	}
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO playlist_songs (playlist_id, song_id, sort_order)
		VALUES (?, ?, ?)
		ON DUPLICATE KEY UPDATE sort_order = sort_order`, playlistID, songID, nextOrder)
	if err != nil {
		return model.Playlist{}, err
	}
	_, _ = r.db.ExecContext(ctx, `UPDATE playlists SET updated_at = CURRENT_TIMESTAMP WHERE id = ?`, playlistID)
	return r.GetPlaylist(ctx, userID, playlistID)
}

func (r *Repository) RemoveSongFromPlaylist(ctx context.Context, userID int64, playlistID int64, songID int64) (model.Playlist, error) {
	if userID <= 0 || playlistID <= 0 || songID <= 0 {
		return model.Playlist{}, sql.ErrNoRows
	}
	result, err := r.db.ExecContext(ctx, `
		DELETE ps FROM playlist_songs ps
		INNER JOIN playlists p ON p.id = ps.playlist_id
		WHERE ps.playlist_id = ? AND ps.song_id = ? AND p.user_id = ?`, playlistID, songID, userID)
	if err != nil {
		return model.Playlist{}, err
	}
	affected, err := result.RowsAffected()
	if err != nil {
		return model.Playlist{}, err
	}
	if affected == 0 {
		return model.Playlist{}, sql.ErrNoRows
	}
	_, _ = r.db.ExecContext(ctx, `UPDATE playlists SET updated_at = CURRENT_TIMESTAMP WHERE id = ?`, playlistID)
	return r.GetPlaylist(ctx, userID, playlistID)
}

func (r *Repository) ReorderPlaylistSongs(ctx context.Context, userID int64, playlistID int64, songIDs []int64) (model.Playlist, error) {
	if userID <= 0 || playlistID <= 0 {
		return model.Playlist{}, sql.ErrNoRows
	}
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return model.Playlist{}, err
	}
	defer tx.Rollback()

	var exists int
	if err := tx.QueryRowContext(ctx, `SELECT COUNT(*) FROM playlists WHERE id = ? AND user_id = ?`, playlistID, userID).Scan(&exists); err != nil {
		return model.Playlist{}, err
	}
	if exists == 0 {
		return model.Playlist{}, sql.ErrNoRows
	}

	rows, err := tx.QueryContext(ctx, `SELECT song_id FROM playlist_songs WHERE playlist_id = ?`, playlistID)
	if err != nil {
		return model.Playlist{}, err
	}
	currentSongs := make(map[int64]bool)
	for rows.Next() {
		var songID int64
		if err := rows.Scan(&songID); err != nil {
			rows.Close()
			return model.Playlist{}, err
		}
		currentSongs[songID] = true
	}
	if err := rows.Err(); err != nil {
		rows.Close()
		return model.Playlist{}, err
	}
	if err := rows.Close(); err != nil {
		return model.Playlist{}, err
	}
	if len(songIDs) != len(currentSongs) {
		return model.Playlist{}, sql.ErrNoRows
	}

	stmt, err := tx.PrepareContext(ctx, `UPDATE playlist_songs SET sort_order = ? WHERE playlist_id = ? AND song_id = ?`)
	if err != nil {
		return model.Playlist{}, err
	}
	defer stmt.Close()

	seen := make(map[int64]bool, len(songIDs))
	for index, songID := range songIDs {
		if songID <= 0 || !currentSongs[songID] || seen[songID] {
			return model.Playlist{}, sql.ErrNoRows
		}
		seen[songID] = true
		if _, err := stmt.ExecContext(ctx, index+1, playlistID, songID); err != nil {
			return model.Playlist{}, err
		}
	}

	if _, err := tx.ExecContext(ctx, `UPDATE playlists SET updated_at = CURRENT_TIMESTAMP WHERE id = ?`, playlistID); err != nil {
		return model.Playlist{}, err
	}
	if err := tx.Commit(); err != nil {
		return model.Playlist{}, err
	}
	return r.GetPlaylist(ctx, userID, playlistID)
}

func (r *Repository) GetPlaylist(ctx context.Context, userID int64, id int64) (model.Playlist, error) {
	var playlist model.Playlist
	err := r.db.QueryRowContext(ctx, `
		SELECT p.id, p.name, p.description, p.cover_url, p.owner, p.is_favorite, COUNT(ps.song_id) AS song_count,
		       COALESCE(SUM(s.duration), 0) AS total_time, p.updated_at
		FROM playlists p
		LEFT JOIN playlist_songs ps ON ps.playlist_id = p.id
		LEFT JOIN songs s ON s.id = ps.song_id
		WHERE p.id = ? AND p.user_id = ?
		GROUP BY p.id, p.name, p.description, p.cover_url, p.owner, p.is_favorite, p.updated_at`, id, userID).Scan(
		&playlist.ID,
		&playlist.Name,
		&playlist.Description,
		&playlist.CoverURL,
		&playlist.Owner,
		&playlist.IsFavorite,
		&playlist.SongCount,
		&playlist.TotalTime,
		&playlist.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return playlist, err
		}
		return playlist, err
	}

	rows, err := r.db.QueryContext(ctx, `
		SELECT s.id, s.title, s.artist, s.album, s.duration, s.cover_url, s.audio_url, s.source,
		       CASE WHEN uf.song_id IS NULL THEN FALSE ELSE TRUE END AS is_favorite,
		       COALESCE(s.lyrics, ''), COALESCE(s.lyrics_offset_ms, 0), s.created_at
		FROM songs s
		INNER JOIN playlist_songs ps ON ps.song_id = s.id
		LEFT JOIN user_favorite_songs uf ON uf.song_id = s.id AND uf.user_id = ?
		WHERE ps.playlist_id = ?
		ORDER BY ps.sort_order ASC`, userID, id)
	if err != nil {
		return playlist, err
	}
	defer rows.Close()

	songs, err := scanSongs(rows)
	if err != nil {
		return playlist, err
	}
	playlist.Songs = songs

	return playlist, nil
}

func (r *Repository) GetProfile(ctx context.Context) (model.UserProfile, error) {
	var profile model.UserProfile
	err := r.db.QueryRowContext(ctx, `
		SELECT id, name, username, avatar_url, vip, is_admin, storage_limit_mb
		FROM user_profiles
		ORDER BY id ASC
		LIMIT 1`).Scan(
		&profile.ID,
		&profile.Name,
		&profile.Username,
		&profile.AvatarURL,
		&profile.Vip,
		&profile.IsAdmin,
		&profile.StorageLimitMB,
	)
	if err != nil {
		return profile, err
	}
	return r.hydrateProfileStats(ctx, profile)
}

func (r *Repository) ProfileOverview(ctx context.Context, profile model.UserProfile) (model.ProfileOverview, error) {
	user, err := r.hydrateProfileStats(ctx, profile)
	if err != nil {
		return model.ProfileOverview{}, err
	}
	favorites, err := r.ListFavoriteSongs(ctx, profile.ID, 3)
	if err != nil {
		return model.ProfileOverview{}, err
	}
	recent, err := r.ListPlayHistory(ctx, profile.ID, 3)
	if err != nil {
		return model.ProfileOverview{}, err
	}
	downloads, err := r.ListDownloads(ctx, profile.ID)
	if err != nil {
		return model.ProfileOverview{}, err
	}
	if len(downloads) > 3 {
		downloads = downloads[:3]
	}
	return model.ProfileOverview{User: user, Favorites: favorites, Recent: recent, Downloads: downloads}, nil
}

func (r *Repository) ListFavoriteSongs(ctx context.Context, userID int64, limit int) ([]model.Song, error) {
	if limit <= 0 {
		limit = 3
	}
	rows, err := r.db.QueryContext(ctx, `
		SELECT s.id, s.title, s.artist, s.album, s.duration, s.cover_url, s.audio_url, s.source,
		       TRUE AS is_favorite, COALESCE(s.lyrics, ''), COALESCE(s.lyrics_offset_ms, 0), s.created_at
		FROM user_favorite_songs uf
		INNER JOIN songs s ON s.id = uf.song_id
		WHERE uf.user_id = ?
		ORDER BY uf.created_at DESC, s.id ASC
		LIMIT ?`, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanSongs(rows)
}

func (r *Repository) ListRecentSongs(ctx context.Context, userID int64, limit int) ([]model.Song, error) {
	if limit <= 0 {
		limit = 3
	}
	rows, err := r.db.QueryContext(ctx, `
		SELECT s.id, s.title, s.artist, s.album, s.duration, s.cover_url, s.audio_url, s.source,
		       CASE WHEN uf.song_id IS NULL THEN FALSE ELSE TRUE END AS is_favorite,
		       COALESCE(s.lyrics, ''), COALESCE(s.lyrics_offset_ms, 0), s.created_at
		FROM play_history h
		INNER JOIN songs s ON s.id = h.song_id
		LEFT JOIN user_favorite_songs uf ON uf.song_id = s.id AND uf.user_id = ?
		WHERE h.user_id = ?
		ORDER BY h.played_at DESC, h.id DESC
		LIMIT ?`, userID, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanSongs(rows)
}

func (r *Repository) ListPlayHistory(ctx context.Context, userID int64, limit int) ([]model.PlayHistoryItem, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	rows, err := r.db.QueryContext(ctx, `
		SELECT h.id, h.played_at,
		       s.id, s.title, s.artist, s.album, s.duration, s.cover_url, s.audio_url, s.source,
		       CASE WHEN uf.song_id IS NULL THEN FALSE ELSE TRUE END AS is_favorite,
		       COALESCE(s.lyrics, ''), COALESCE(s.lyrics_offset_ms, 0), s.created_at
		FROM play_history h
		INNER JOIN songs s ON s.id = h.song_id
		LEFT JOIN user_favorite_songs uf ON uf.song_id = s.id AND uf.user_id = ?
		WHERE h.user_id = ?
		ORDER BY h.played_at DESC, h.id DESC
		LIMIT ?`, userID, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := make([]model.PlayHistoryItem, 0)
	for rows.Next() {
		var item model.PlayHistoryItem
		if err := rows.Scan(
			&item.ID,
			&item.PlayedAt,
			&item.Song.ID,
			&item.Song.Title,
			&item.Song.Artist,
			&item.Song.Album,
			&item.Song.Duration,
			&item.Song.CoverURL,
			&item.Song.AudioURL,
			&item.Song.Source,
			&item.Song.IsFavorite,
			&item.Song.Lyrics,
			&item.Song.LyricsOffsetMs,
			&item.Song.CreatedAt,
		); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func (r *Repository) RecordPlay(ctx context.Context, userID int64, songID int64) error {
	if userID <= 0 || songID <= 0 {
		return sql.ErrNoRows
	}
	var exists int
	if err := r.db.QueryRowContext(ctx, `
		SELECT COUNT(*)
		FROM songs
		WHERE id = ? AND (visibility = 'public' OR (visibility = 'private' AND owner_user_id = ?))`, songID, userID).Scan(&exists); err != nil {
		return err
	}
	if exists == 0 {
		return sql.ErrNoRows
	}
	_, err := r.db.ExecContext(ctx, `INSERT INTO play_history (user_id, song_id) VALUES (?, ?)`, userID, songID)
	return err
}

func (r *Repository) EnsureSongHeatStats(ctx context.Context) error {
	var count int
	if err := r.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM song_heat_stats`).Scan(&count); err != nil {
		return err
	}
	if count > 0 {
		return nil
	}
	return r.RefreshSongHeatStats(ctx)
}

func (r *Repository) RefreshSongHeatStats(ctx context.Context) error {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if _, err := tx.ExecContext(ctx, `DELETE FROM song_heat_stats`); err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO song_heat_stats (song_id, play_count, calculated_at)
		SELECT song_id, COUNT(*) AS play_count, CURRENT_TIMESTAMP
		FROM play_history
		GROUP BY song_id`); err != nil {
		return err
	}
	return tx.Commit()
}

func (r *Repository) ListDownloads(ctx context.Context, userID int64) ([]model.DownloadTask, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT d.id, d.quality, d.progress, d.status, d.updated_at,
		       s.id, s.title, s.artist, s.album, s.duration, s.cover_url, s.audio_url, s.source,
		       CASE WHEN uf.song_id IS NULL THEN FALSE ELSE TRUE END AS is_favorite,
		       COALESCE(s.lyrics, ''), COALESCE(s.lyrics_offset_ms, 0), s.created_at
		FROM download_tasks d
		INNER JOIN songs s ON s.id = d.song_id
		LEFT JOIN user_favorite_songs uf ON uf.song_id = s.id AND uf.user_id = ?
		WHERE d.user_id = ?
		ORDER BY d.updated_at DESC, d.id DESC`, userID, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return scanDownloadTasks(rows)
}

func (r *Repository) ListDownloadsPage(ctx context.Context, userID int64, status string, limit int, offset int) (model.DownloadTaskPage, error) {
	if userID <= 0 {
		return model.DownloadTaskPage{}, sql.ErrNoRows
	}
	if limit <= 0 {
		limit = 50
	}
	if limit > 100 {
		limit = 100
	}
	if offset < 0 {
		offset = 0
	}
	status = normalizeDownloadStatusFilter(status)
	page := model.DownloadTaskPage{}
	if err := r.db.QueryRowContext(ctx, `
		SELECT
			COUNT(*),
			COALESCE(SUM(CASE WHEN LOWER(status) = 'completed' THEN 1 ELSE 0 END), 0),
			COALESCE(SUM(CASE WHEN LOWER(status) IN ('downloading', 'pending', 'queued') THEN 1 ELSE 0 END), 0),
			COALESCE(SUM(CASE WHEN LOWER(status) = 'failed' THEN 1 ELSE 0 END), 0)
		FROM download_tasks
		WHERE user_id = ?`, userID).Scan(
		&page.AllCount,
		&page.CompletedCount,
		&page.ActiveCount,
		&page.FailedCount,
	); err != nil {
		return model.DownloadTaskPage{}, err
	}

	whereClause := "d.user_id = ?"
	args := []any{userID}
	switch status {
	case "completed":
		whereClause += " AND LOWER(d.status) = 'completed'"
	case "downloading":
		whereClause += " AND LOWER(d.status) IN ('downloading', 'pending', 'queued')"
	case "failed":
		whereClause += " AND LOWER(d.status) = 'failed'"
	}
	if err := r.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM download_tasks d WHERE "+whereClause, args...).Scan(&page.TotalCount); err != nil {
		return model.DownloadTaskPage{}, err
	}
	query := `
		SELECT d.id, d.quality, d.progress, d.status, d.updated_at,
		       s.id, s.title, s.artist, s.album, s.duration, s.cover_url, s.audio_url, s.source,
		       CASE WHEN uf.song_id IS NULL THEN FALSE ELSE TRUE END AS is_favorite,
		       COALESCE(s.lyrics, ''), COALESCE(s.lyrics_offset_ms, 0), s.created_at
		FROM download_tasks d
		INNER JOIN songs s ON s.id = d.song_id
		LEFT JOIN user_favorite_songs uf ON uf.song_id = s.id AND uf.user_id = ?
		WHERE ` + whereClause + `
		ORDER BY d.updated_at DESC, d.id DESC
		LIMIT ? OFFSET ?`
	queryArgs := []any{userID}
	queryArgs = append(queryArgs, args...)
	queryArgs = append(queryArgs, limit+1, offset)
	rows, err := r.db.QueryContext(ctx, query, queryArgs...)
	if err != nil {
		return model.DownloadTaskPage{}, err
	}
	defer rows.Close()

	items, err := scanDownloadTasks(rows)
	if err != nil {
		return model.DownloadTaskPage{}, err
	}
	page.HasMore = len(items) > limit
	if page.HasMore {
		items = items[:limit]
	}
	page.Items = items
	page.NextOffset = offset + len(items)
	return page, nil
}

func scanDownloadTasks(rows *sql.Rows) ([]model.DownloadTask, error) {
	tasks := make([]model.DownloadTask, 0)
	for rows.Next() {
		var task model.DownloadTask
		if err := rows.Scan(
			&task.ID,
			&task.Quality,
			&task.Progress,
			&task.Status,
			&task.UpdatedAt,
			&task.Song.ID,
			&task.Song.Title,
			&task.Song.Artist,
			&task.Song.Album,
			&task.Song.Duration,
			&task.Song.CoverURL,
			&task.Song.AudioURL,
			&task.Song.Source,
			&task.Song.IsFavorite,
			&task.Song.Lyrics,
			&task.Song.LyricsOffsetMs,
			&task.Song.CreatedAt,
		); err != nil {
			return nil, err
		}
		tasks = append(tasks, task)
	}
	return tasks, rows.Err()
}

func normalizeDownloadStatusFilter(status string) string {
	status = strings.TrimSpace(strings.ToLower(status))
	if status == "active" || status == "pending" || status == "queued" {
		return "downloading"
	}
	if status == "completed" || status == "downloading" || status == "failed" {
		return status
	}
	return "all"
}

func (r *Repository) CreateDownload(ctx context.Context, userID int64, songID int64, quality string) error {
	if userID <= 0 || songID <= 0 {
		return sql.ErrNoRows
	}
	var exists int
	if err := r.db.QueryRowContext(ctx, `
		SELECT COUNT(*)
		FROM songs
		WHERE id = ? AND (visibility = 'public' OR (visibility = 'private' AND owner_user_id = ?))`, songID, userID).Scan(&exists); err != nil {
		return err
	}
	if exists == 0 {
		return sql.ErrNoRows
	}
	if quality == "" {
		quality = "320kbps"
	}
	result, err := r.db.ExecContext(ctx, `
		UPDATE download_tasks
		SET quality = ?, progress = 100, status = 'completed', updated_at = CURRENT_TIMESTAMP
		WHERE user_id = ? AND song_id = ?`, quality, userID, songID)
	if err != nil {
		return err
	}
	affected, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if affected > 0 {
		return nil
	}
	_, err = r.db.ExecContext(ctx, `
		INSERT INTO download_tasks (user_id, song_id, quality, progress, status)
		VALUES (?, ?, ?, 100, 'completed')`, userID, songID, quality)
	return err
}

func (r *Repository) ClearDownloads(ctx context.Context, userID int64, status string) error {
	if userID <= 0 {
		return sql.ErrNoRows
	}
	status = strings.TrimSpace(strings.ToLower(status))
	if status == "" || status == "completed" {
		_, err := r.db.ExecContext(ctx, `DELETE FROM download_tasks WHERE user_id = ? AND status = 'completed'`, userID)
		return err
	}
	if status == "all" {
		_, err := r.db.ExecContext(ctx, `DELETE FROM download_tasks WHERE user_id = ?`, userID)
		return err
	}
	_, err := r.db.ExecContext(ctx, `DELETE FROM download_tasks WHERE user_id = ? AND status = ?`, userID, status)
	return err
}

func (r *Repository) hydrateProfileStats(ctx context.Context, profile model.UserProfile) (model.UserProfile, error) {
	if err := r.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM user_favorite_songs WHERE user_id = ?`, profile.ID).Scan(&profile.FavoriteCount); err != nil {
		return profile, err
	}
	if err := r.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM playlists WHERE user_id = ?`, profile.ID).Scan(&profile.PlaylistCount); err != nil {
		return profile, err
	}
	if err := r.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM play_history WHERE user_id = ?`, profile.ID).Scan(&profile.RecentCount); err != nil {
		return profile, err
	}
	used, err := r.storageUsedMB(ctx)
	if err != nil {
		return profile, err
	}
	profile.StorageUsedMB = used
	return profile, nil
}

func (r *Repository) storageUsedMB(ctx context.Context) (int, error) {
	rows, err := r.db.QueryContext(ctx, `SELECT audio_url FROM songs WHERE audio_url <> ''`)
	if err != nil {
		return 0, err
	}
	defer rows.Close()
	var total int64
	for rows.Next() {
		var audioURL string
		if err := rows.Scan(&audioURL); err != nil {
			return 0, err
		}
		info, err := os.Stat(audioURL)
		if err == nil && !info.IsDir() {
			total += info.Size()
		}
	}
	if err := rows.Err(); err != nil {
		return 0, err
	}
	return int(total / 1024 / 1024), nil
}

func legacyPasswordHash(password string) string {
	sum := sha256.Sum256([]byte(password))
	return hex.EncodeToString(sum[:])
}

func createPasswordHash(password string) (string, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return "", err
	}
	return string(hash), nil
}

func verifyPasswordHash(storedHash string, password string) (bool, string, error) {
	storedHash = strings.TrimSpace(storedHash)
	if storedHash == "" {
		return false, "", nil
	}
	if strings.HasPrefix(storedHash, "$2a$") ||
		strings.HasPrefix(storedHash, "$2b$") ||
		strings.HasPrefix(storedHash, "$2y$") {
		return bcrypt.CompareHashAndPassword([]byte(storedHash), []byte(password)) == nil, "", nil
	}
	if storedHash != legacyPasswordHash(password) {
		return false, "", nil
	}
	upgradedHash, err := createPasswordHash(password)
	if err != nil {
		return false, "", err
	}
	return true, upgradedHash, nil
}

func signToken(id int64, username string, passwordHash string) string {
	secret := os.Getenv("MUSICFLOW_TOKEN_SECRET")
	if secret == "" {
		secret = "musicflow-local-secret"
	}
	sum := sha256.Sum256([]byte(fmt.Sprintf("%d:%s:%s:%s", id, username, passwordHash, secret)))
	return fmt.Sprintf("%d.%s", id, hex.EncodeToString(sum[:]))
}

func scanSongs(rows *sql.Rows) ([]model.Song, error) {
	columns, err := rows.Columns()
	if err != nil {
		return nil, err
	}
	songs := make([]model.Song, 0)
	for rows.Next() {
		var song model.Song
		if len(columns) == 13 {
			if err := rows.Scan(
				&song.ID,
				&song.Title,
				&song.Artist,
				&song.Album,
				&song.Duration,
				&song.CoverURL,
				&song.AudioURL,
				&song.Source,
				&song.IsFavorite,
				&song.Lyrics,
				&song.LyricsOffsetMs,
				&song.PlayCount,
				&song.CreatedAt,
			); err != nil {
				return nil, err
			}
		} else {
			if err := rows.Scan(
				&song.ID,
				&song.Title,
				&song.Artist,
				&song.Album,
				&song.Duration,
				&song.CoverURL,
				&song.AudioURL,
				&song.Source,
				&song.IsFavorite,
				&song.Lyrics,
				&song.LyricsOffsetMs,
				&song.CreatedAt,
			); err != nil {
				return nil, err
			}
		}
		songs = append(songs, song)
	}
	return songs, rows.Err()
}
