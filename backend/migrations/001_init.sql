CREATE DATABASE IF NOT EXISTS musicflow DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE musicflow;

CREATE TABLE IF NOT EXISTS songs (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    title VARCHAR(128) NOT NULL,
    artist VARCHAR(128) NOT NULL,
    album VARCHAR(128) NOT NULL DEFAULT '',
    duration INT NOT NULL DEFAULT 0,
    cover_url VARCHAR(512) NOT NULL DEFAULT '',
    audio_url VARCHAR(512) NOT NULL DEFAULT '',
    source VARCHAR(64) NOT NULL DEFAULT '',
    visibility VARCHAR(16) NOT NULL DEFAULT 'public',
    owner_user_id BIGINT NOT NULL DEFAULT 0,
    is_favorite BOOLEAN NOT NULL DEFAULT FALSE,
    lyrics MEDIUMTEXT,
    lyrics_offset_ms INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_songs_created (created_at),
    INDEX idx_songs_visibility_owner (visibility, owner_user_id)
);

CREATE TABLE IF NOT EXISTS playlists (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL DEFAULT 0,
    name VARCHAR(128) NOT NULL,
    description VARCHAR(255) NOT NULL DEFAULT '',
    cover_url VARCHAR(512) NOT NULL DEFAULT '',
    owner VARCHAR(64) NOT NULL DEFAULT '',
    is_favorite BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_playlists_user_updated (user_id, updated_at)
);

CREATE TABLE IF NOT EXISTS playlist_songs (
    playlist_id BIGINT NOT NULL,
    song_id BIGINT NOT NULL,
    sort_order INT NOT NULL DEFAULT 0,
    PRIMARY KEY (playlist_id, song_id),
    CONSTRAINT fk_playlist_songs_playlist FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE,
    CONSTRAINT fk_playlist_songs_song FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS user_favorite_songs (
    user_id BIGINT NOT NULL,
    song_id BIGINT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, song_id),
    INDEX idx_user_favorite_songs_song (song_id),
    CONSTRAINT fk_user_favorite_songs_song FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS user_profiles (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(64) NOT NULL,
    username VARCHAR(64) NOT NULL DEFAULT '',
    avatar_url VARCHAR(512) NOT NULL DEFAULT '',
    vip BOOLEAN NOT NULL DEFAULT FALSE,
    is_admin BOOLEAN NOT NULL DEFAULT FALSE,
    favorite_count INT NOT NULL DEFAULT 0,
    playlist_count INT NOT NULL DEFAULT 0,
    recent_count INT NOT NULL DEFAULT 0,
    storage_used_mb INT NOT NULL DEFAULT 0,
    storage_limit_mb INT NOT NULL DEFAULT 10240
);

CREATE TABLE IF NOT EXISTS users (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(64) NOT NULL UNIQUE,
    password_hash VARCHAR(128) NOT NULL,
    name VARCHAR(64) NOT NULL,
    avatar_url VARCHAR(512) NOT NULL DEFAULT '',
    vip BOOLEAN NOT NULL DEFAULT FALSE,
    is_admin BOOLEAN NOT NULL DEFAULT FALSE,
    storage_limit_mb INT NOT NULL DEFAULT 10240,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS play_history (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL DEFAULT 0,
    song_id BIGINT NOT NULL,
    played_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_play_history_user_time (user_id, played_at),
    INDEX idx_play_history_song (song_id),
    CONSTRAINT fk_play_history_song FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS song_heat_stats (
    song_id BIGINT PRIMARY KEY,
    play_count INT NOT NULL DEFAULT 0,
    calculated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_song_heat_stats_count (play_count),
    CONSTRAINT fk_song_heat_stats_song FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS download_tasks (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL DEFAULT 0,
    song_id BIGINT NOT NULL,
    quality VARCHAR(32) NOT NULL DEFAULT '',
    progress INT NOT NULL DEFAULT 0,
    status VARCHAR(32) NOT NULL DEFAULT '',
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE INDEX idx_download_tasks_user_song (user_id, song_id),
    INDEX idx_download_tasks_user_status (user_id, status),
    INDEX idx_download_tasks_user_updated (user_id, updated_at, id),
    CONSTRAINT fk_download_tasks_song FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE
);
