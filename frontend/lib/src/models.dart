import 'package:flutter/material.dart';

enum MusicSection {
  music,
  playlists,
  search,
  downloads,
  profile,
  player,
  recent,
  downloadManagement,
}

typedef SongTapCallback = void Function(Song song, {List<Song>? queue});

class Song {
  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.seed,
    required this.colors,
    this.isFavorite = false,
    this.source = '',
    this.audioUrl = '',
    this.lyrics = '',
    this.lyricsOffsetMs = 0,
    this.playCount = 0,
  });

  final int id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final String seed;
  final List<Color> colors;
  final bool isFavorite;
  final String source;
  final String audioUrl;
  final String lyrics;
  final int lyricsOffsetMs;
  final int playCount;

  factory Song.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt() ?? 0;
    return Song(
      id: id,
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
      album: json['album'] as String? ?? '',
      duration: Duration(seconds: (json['duration'] as num?)?.toInt() ?? 0),
      seed: 'song-$id',
      colors: artworkColors(id),
      isFavorite: json['isFavorite'] as bool? ?? false,
      source: json['source'] as String? ?? '',
      audioUrl: json['audioUrl'] as String? ?? '',
      lyrics: json['lyrics'] as String? ?? '',
      lyricsOffsetMs: (json['lyricsOffsetMs'] as num?)?.toInt() ?? 0,
      playCount: (json['playCount'] as num?)?.toInt() ?? 0,
    );
  }

  factory Song.empty() {
    return const Song(
      id: 0,
      title: '',
      artist: '',
      album: '',
      duration: Duration.zero,
      seed: 'empty',
      colors: [Color(0xFFE8EDF2), Color(0xFFB8C4D0)],
    );
  }
}

class SongPage {
  const SongPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
    required this.totalCount,
  });

  final List<Song> items;
  final int nextCursor;
  final bool hasMore;
  final int totalCount;

  factory SongPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return SongPage(
      items: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(Song.fromJson)
                .toList()
          : <Song>[],
      nextCursor: (json['nextCursor'] as num?)?.toInt() ?? 0,
      hasMore: json['hasMore'] as bool? ?? false,
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.description,
    required this.owner,
    required this.songs,
    required this.colors,
    required this.icon,
    this.isFavorite = false,
    this.songCount = 0,
    this.totalTime = Duration.zero,
    this.updatedText = '',
  });

  final int id;
  final String name;
  final String description;
  final String owner;
  final List<Song> songs;
  final List<Color> colors;
  final IconData icon;
  final bool isFavorite;
  final int songCount;
  final Duration totalTime;
  final String updatedText;

  factory Playlist.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt() ?? 0;
    final rawSongs = json['songs'];
    final parsedSongs = rawSongs is List
        ? rawSongs.whereType<Map<String, dynamic>>().map(Song.fromJson).toList()
        : <Song>[];
    final songCount =
        (json['songCount'] as num?)?.toInt() ?? parsedSongs.length;
    final updatedAt = DateTime.tryParse(json['updatedAt'] as String? ?? '');

    return Playlist(
      id: id,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      owner: json['owner'] as String? ?? '',
      songs: parsedSongs,
      colors: artworkColors(id + 100),
      icon: Icons.queue_music_rounded,
      isFavorite: json['isFavorite'] as bool? ?? false,
      songCount: songCount,
      totalTime: Duration(seconds: (json['totalTime'] as num?)?.toInt() ?? 0),
      updatedText: updatedAt == null ? '' : formatDate(updatedAt),
    );
  }
}

class DownloadTask {
  const DownloadTask({
    required this.id,
    required this.song,
    required this.quality,
    required this.progress,
    required this.status,
    required this.updatedAt,
  });

  final int id;
  final Song song;
  final String quality;
  final double progress;
  final String status;
  final DateTime updatedAt;

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    final rawSong = json['song'];
    return DownloadTask(
      id: (json['id'] as num?)?.toInt() ?? 0,
      song: rawSong is Map<String, dynamic>
          ? Song.fromJson(rawSong)
          : Song.empty(),
      quality: json['quality'] as String? ?? '',
      progress: ((json['progress'] as num?)?.toDouble() ?? 0) / 100,
      status: json['status'] as String? ?? '',
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class DownloadTaskPage {
  const DownloadTaskPage({
    required this.items,
    required this.nextOffset,
    required this.hasMore,
    required this.totalCount,
    required this.allCount,
    required this.completedCount,
    required this.activeCount,
    required this.failedCount,
  });

  final List<DownloadTask> items;
  final int nextOffset;
  final bool hasMore;
  final int totalCount;
  final int allCount;
  final int completedCount;
  final int activeCount;
  final int failedCount;

  factory DownloadTaskPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return DownloadTaskPage(
      items: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(DownloadTask.fromJson)
                .toList()
          : <DownloadTask>[],
      nextOffset: (json['nextOffset'] as num?)?.toInt() ?? 0,
      hasMore: json['hasMore'] as bool? ?? false,
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      allCount: (json['allCount'] as num?)?.toInt() ?? 0,
      completedCount: (json['completedCount'] as num?)?.toInt() ?? 0,
      activeCount: (json['activeCount'] as num?)?.toInt() ?? 0,
      failedCount: (json['failedCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class PlayHistoryItem {
  const PlayHistoryItem({
    required this.id,
    required this.song,
    required this.playedAt,
  });

  final int id;
  final Song song;
  final DateTime playedAt;

  factory PlayHistoryItem.fromJson(Map<String, dynamic> json) {
    final rawSong = json['song'];
    final song = rawSong is Map<String, dynamic>
        ? Song.fromJson(rawSong)
        : Song.fromJson(json);
    return PlayHistoryItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      song: song,
      playedAt:
          DateTime.tryParse(json['playedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.username,
    required this.avatarUrl,
    required this.vip,
    required this.isAdmin,
    required this.favoriteCount,
    required this.playlistCount,
    required this.recentCount,
    required this.storageUsedMb,
    required this.storageLimitMb,
  });

  final int id;
  final String name;
  final String username;
  final String avatarUrl;
  final bool vip;
  final bool isAdmin;
  final int favoriteCount;
  final int playlistCount;
  final int recentCount;
  final int storageUsedMb;
  final int storageLimitMb;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      username: json['username'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      vip: json['vip'] as bool? ?? false,
      isAdmin: json['isAdmin'] as bool? ?? false,
      favoriteCount: (json['favoriteCount'] as num?)?.toInt() ?? 0,
      playlistCount: (json['playlistCount'] as num?)?.toInt() ?? 0,
      recentCount: (json['recentCount'] as num?)?.toInt() ?? 0,
      storageUsedMb: (json['storageUsedMb'] as num?)?.toInt() ?? 0,
      storageLimitMb: (json['storageLimitMb'] as num?)?.toInt() ?? 0,
    );
  }
}

class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final UserProfile user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    return AuthSession(
      token: json['token'] as String? ?? '',
      user: rawUser is Map<String, dynamic>
          ? UserProfile.fromJson(rawUser)
          : UserProfile.fromJson(const {}),
    );
  }
}

class ProfileOverview {
  const ProfileOverview({
    required this.user,
    required this.favorites,
    required this.recent,
    required this.downloads,
  });

  final UserProfile user;
  final List<Song> favorites;
  final List<PlayHistoryItem> recent;
  final List<DownloadTask> downloads;

  factory ProfileOverview.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    final rawFavorites = json['favorites'];
    final rawRecent = json['recent'];
    final rawDownloads = json['downloads'];
    return ProfileOverview(
      user: rawUser is Map<String, dynamic>
          ? UserProfile.fromJson(rawUser)
          : UserProfile.fromJson(const {}),
      favorites: rawFavorites is List
          ? rawFavorites
                .whereType<Map<String, dynamic>>()
                .map(Song.fromJson)
                .toList()
          : <Song>[],
      recent: rawRecent is List
          ? rawRecent
                .whereType<Map<String, dynamic>>()
                .map(PlayHistoryItem.fromJson)
                .toList()
          : <PlayHistoryItem>[],
      downloads: rawDownloads is List
          ? rawDownloads
                .whereType<Map<String, dynamic>>()
                .map(DownloadTask.fromJson)
                .toList()
          : <DownloadTask>[],
    );
  }
}

List<Color> artworkColors(int id) {
  const palettes = [
    [Color(0xFF6EC9FF), Color(0xFF1E5BFF)],
    [Color(0xFFFFA687), Color(0xFFFF5874)],
    [Color(0xFFB993FF), Color(0xFF6B6BFF)],
    [Color(0xFF63E6BE), Color(0xFF0EA371)],
    [Color(0xFFFFD36E), Color(0xFFFF7E3C)],
    [Color(0xFFFFB3CB), Color(0xFFE84393)],
    [Color(0xFF7DE2FC), Color(0xFF4093E4)],
    [Color(0xFFC2E9FB), Color(0xFF667EEA)],
  ];
  return palettes[id.abs() % palettes.length];
}

String formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String formatDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final days = today.difference(target).inDays;
  if (days <= 0) {
    return '今天';
  }
  if (days == 1) {
    return '昨天';
  }
  if (days < 7) {
    return '$days 天前';
  }
  return '${date.month}月${date.day}日';
}

String formatRelativeTime(DateTime date) {
  if (date.millisecondsSinceEpoch == 0) {
    return '';
  }
  final now = DateTime.now();
  final diff = now.difference(date.toLocal());
  if (diff.inMinutes < 1) {
    return '刚刚播放';
  }
  if (diff.inHours < 1) {
    return '${diff.inMinutes} 分钟前';
  }
  if (diff.inDays < 1) {
    return '${diff.inHours} 小时前';
  }
  if (diff.inDays == 1) {
    return '昨天';
  }
  if (diff.inDays < 7) {
    return '${diff.inDays} 天前';
  }
  return '${date.month}月${date.day}日';
}
