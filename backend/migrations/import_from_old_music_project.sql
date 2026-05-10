START TRANSACTION;

INSERT IGNORE INTO musicflow.songs (id, title, artist, album, duration, cover_url, audio_url, source, is_favorite, created_at)
SELECT
  id,
  COALESCE(NULLIF(title, ''), '未知歌曲'),
  COALESCE(NULLIF(artist, ''), '未知歌手'),
  COALESCE(album, ''),
  COALESCE(duration, 0),
  CASE WHEN cover_path IS NULL OR cover_path = '' THEN '' ELSE CONCAT('/Users/liao/Desktop/音乐项目/music-server/storage/covers/', cover_path) END,
  CASE WHEN file_path LIKE '/%' THEN file_path ELSE CONCAT('/Users/liao/Desktop/音乐项目/music-server/storage/music/', file_path) END,
  '音乐项目',
  favorite <> 0,
  COALESCE(created_at, CURRENT_TIMESTAMP)
FROM music_db.songs;

INSERT IGNORE INTO musicflow.playlists (id, name, description, cover_url, owner, updated_at)
SELECT
  id,
  COALESCE(NULLIF(name, ''), '旧项目歌单'),
  COALESCE(description, ''),
  CASE WHEN cover_path IS NULL OR cover_path = '' THEN '' ELSE CONCAT('/Users/liao/Desktop/音乐项目/music-server/storage/covers/', cover_path) END,
  'liao',
  COALESCE(updated_at, CURRENT_TIMESTAMP)
FROM music_db.playlists;

INSERT IGNORE INTO musicflow.playlist_songs (playlist_id, song_id, sort_order)
SELECT playlist_id, song_id, COALESCE(order_index, 0)
FROM music_db.playlist_songs
WHERE playlist_id IN (SELECT id FROM musicflow.playlists)
  AND song_id IN (SELECT id FROM musicflow.songs);

INSERT IGNORE INTO musicflow.download_tasks (song_id, quality, progress, status)
SELECT id, '320kbps', 100, 'completed'
FROM musicflow.songs
ORDER BY id
LIMIT 5;

COMMIT;
