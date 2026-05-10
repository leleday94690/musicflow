import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'config.dart';
import 'models.dart';

class ApiException implements Exception {
  const ApiException(this.message, {required this.statusCode});

  final String message;
  final int statusCode;

  bool get isUnauthorized => statusCode == HttpStatus.unauthorized;
  bool get isNetworkError => statusCode == 0;

  @override
  String toString() => message;
}

class MusicApiClient {
  MusicApiClient({this.baseUrl = AppConfig.apiBaseUrl, this.token});

  static const Duration _connectionTimeout = Duration(seconds: 12);
  static const Duration _requestTimeout = Duration(seconds: 35);
  static const Duration _downloadTimeout = Duration(minutes: 3);

  final String baseUrl;
  final String? token;

  Future<AuthSession> login(String username, String password) async {
    final data = await _postMap('/api/auth/login', {
      'username': username,
      'password': password,
    });
    return AuthSession.fromJson(data);
  }

  Future<ProfileOverview> fetchProfileOverview() async {
    final data = await _getMap('/api/profile/overview');
    return ProfileOverview.fromJson(data);
  }

  Future<void> recordPlay(int songId) async {
    await _postMap('/api/play-history', {'songId': songId});
  }

  Future<List<PlayHistoryItem>> fetchPlayHistory({int limit = 50}) async {
    final data = await _getList('/api/play-history?limit=$limit');
    return data
        .whereType<Map<String, dynamic>>()
        .map(PlayHistoryItem.fromJson)
        .toList();
  }

  Future<List<Song>> fetchSongs() async {
    final data = await _getList('/api/songs?limit=1000');
    return data.whereType<Map<String, dynamic>>().map(Song.fromJson).toList();
  }

  Future<SongPage> fetchSongsPage({int limit = 80, int cursor = 0}) async {
    final data = await _getMap('/api/songs/page?limit=$limit&cursor=$cursor');
    return SongPage.fromJson(data);
  }

  Future<List<Song>> searchSongs(String keyword) async {
    final data = await _getList(
      '/api/search?q=${Uri.encodeQueryComponent(keyword)}',
    );
    return data.whereType<Map<String, dynamic>>().map(Song.fromJson).toList();
  }

  Future<Song> updateSongFavorite(int songId, bool favorite) async {
    final data = await _patchMap('/api/songs/$songId/favorite', {
      'favorite': favorite,
    });
    return Song.fromJson(data);
  }

  Future<Song> updateSong(
    int songId,
    String title,
    String artist,
    String album,
    String lyrics,
    int lyricsOffsetMs,
  ) async {
    final data = await _patchMap('/api/songs/$songId', {
      'title': title,
      'artist': artist,
      'album': album,
      'lyrics': lyrics,
      'lyricsOffsetMs': lyricsOffsetMs,
    });
    return Song.fromJson(data);
  }

  Future<Song> fetchSongLyrics(int songId) async {
    final data = await _postMap('/api/songs/$songId/lyrics/fetch', {});
    return Song.fromJson(data);
  }

  Future<void> deleteSong(int songId) async {
    await _deleteMap('/api/songs/$songId');
  }

  Future<List<Playlist>> fetchPlaylists() async {
    final data = await _getList('/api/playlists');
    return data
        .whereType<Map<String, dynamic>>()
        .map(Playlist.fromJson)
        .toList();
  }

  Future<Playlist> fetchPlaylist(int id) async {
    final data = await _getMap('/api/playlists/$id');
    return Playlist.fromJson(data);
  }

  Future<Playlist> createPlaylist(String name, String description) async {
    final data = await _postMap('/api/playlists', {
      'name': name,
      'description': description,
    });
    return Playlist.fromJson(data);
  }

  Future<Playlist> updatePlaylist(
    int playlistId,
    String name,
    String description,
  ) async {
    final data = await _patchMap('/api/playlists/$playlistId', {
      'name': name,
      'description': description,
    });
    return Playlist.fromJson(data);
  }

  Future<void> deletePlaylist(int playlistId) async {
    await _deleteMap('/api/playlists/$playlistId');
  }

  Future<Playlist> updatePlaylistFavorite(int playlistId, bool favorite) async {
    final data = await _patchMap('/api/playlists/$playlistId/favorite', {
      'favorite': favorite,
    });
    return Playlist.fromJson(data);
  }

  Future<Playlist> addSongToPlaylist(int playlistId, int songId) async {
    final data = await _postMap('/api/playlists/$playlistId/songs', {
      'songId': songId,
    });
    return Playlist.fromJson(data);
  }

  Future<Playlist> removeSongFromPlaylist(int playlistId, int songId) async {
    final data = await _deleteMap('/api/playlists/$playlistId/songs/$songId');
    return Playlist.fromJson(data);
  }

  Future<Playlist> reorderPlaylistSongs(
    int playlistId,
    List<int> songIds,
  ) async {
    final data = await _patchMap('/api/playlists/$playlistId/songs/order', {
      'songIds': songIds,
    });
    return Playlist.fromJson(data);
  }

  Future<List<DownloadTask>> fetchDownloads() async {
    final data = await _getList('/api/downloads');
    return data
        .whereType<Map<String, dynamic>>()
        .map(DownloadTask.fromJson)
        .toList();
  }

  Future<DownloadTaskPage> fetchDownloadsPage({
    int limit = 50,
    int offset = 0,
    String status = 'all',
  }) async {
    final query = Uri(
      path: '/api/downloads/page',
      queryParameters: {
        'limit': '$limit',
        'offset': '$offset',
        'status': status,
      },
    ).toString();
    final data = await _getMap(query);
    return DownloadTaskPage.fromJson(data);
  }

  Future<List<DownloadTask>> createDownload(
    int songId, {
    String quality = '320kbps',
  }) async {
    final data = await _postList('/api/downloads', {
      'songId': songId,
      'quality': quality,
    });
    return data
        .whereType<Map<String, dynamic>>()
        .map(DownloadTask.fromJson)
        .toList();
  }

  Future<List<DownloadTask>> clearDownloads({
    String status = 'completed',
  }) async {
    final trimmedStatus = status.trim();
    final query = trimmedStatus.isEmpty
        ? ''
        : '?status=${Uri.encodeQueryComponent(trimmedStatus)}';
    final data = await _deleteList('/api/downloads$query');
    return data
        .whereType<Map<String, dynamic>>()
        .map(DownloadTask.fromJson)
        .toList();
  }

  Future<List<Song>> importLocalMusic(List<String> paths) async {
    final data = await _postList('/api/import/local', {
      'paths': paths,
    }, timeout: _downloadTimeout);
    return data.whereType<Map<String, dynamic>>().map(Song.fromJson).toList();
  }

  Future<List<Map<String, dynamic>>> searchOnlineMusic(String keyword) async {
    final data = await _getList(
      '/api/download/search?keyword=${Uri.encodeQueryComponent(keyword)}',
    );
    return data.whereType<Map<String, dynamic>>().toList();
  }

  Future<Song> downloadOnlineMusic(
    String onlineSongId,
    String title,
    String artist,
  ) async {
    final params =
        'title=${Uri.encodeQueryComponent(title)}&artist=${Uri.encodeQueryComponent(artist)}';
    final data = await _postMap(
      '/api/download/song/${Uri.encodeComponent(onlineSongId)}?$params',
      {},
      timeout: _downloadTimeout,
    );
    return Song.fromJson(data);
  }

  Future<List<Song>> downloadOnlineMusicBatch(
    List<Map<String, dynamic>> onlineSongs,
  ) async {
    final data = await _postList('/api/download/batch', {
      'songs': onlineSongs,
    }, timeout: _downloadTimeout);
    return data.whereType<Map<String, dynamic>>().map(Song.fromJson).toList();
  }

  Future<List<dynamic>> _getList(String path) async {
    final data = await _requestJson(path, method: 'GET');
    return data is List ? data : <dynamic>[];
  }

  Future<List<dynamic>> _postList(
    String path,
    Map<String, dynamic> payload, {
    Duration timeout = _requestTimeout,
  }) async {
    final data = await _requestJson(
      path,
      method: 'POST',
      payload: payload,
      expectedStatuses: const {HttpStatus.ok, HttpStatus.created},
      timeout: timeout,
    );
    return data is List ? data : <dynamic>[];
  }

  Future<Map<String, dynamic>> _postMap(
    String path,
    Map<String, dynamic> payload, {
    Duration timeout = _requestTimeout,
  }) async {
    final data = await _requestJson(
      path,
      method: 'POST',
      payload: payload,
      expectedStatuses: const {HttpStatus.ok, HttpStatus.created},
      timeout: timeout,
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> _patchMap(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final data = await _requestJson(path, method: 'PATCH', payload: payload);
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> _deleteMap(String path) async {
    final data = await _requestJson(path, method: 'DELETE');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<List<dynamic>> _deleteList(String path) async {
    final data = await _requestJson(path, method: 'DELETE');
    return data is List ? data : <dynamic>[];
  }

  Future<Map<String, dynamic>> _getMap(String path) async {
    final data = await _requestJson(path, method: 'GET');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<dynamic> _requestJson(
    String path, {
    required String method,
    Map<String, dynamic>? payload,
    Set<int> expectedStatuses = const {HttpStatus.ok},
    Duration timeout = _requestTimeout,
  }) async {
    final client = HttpClient()..connectionTimeout = _connectionTimeout;
    try {
      final uri = Uri.parse('$baseUrl$path');
      final request = switch (method) {
        'GET' => await client.getUrl(uri),
        'POST' => await client.postUrl(uri),
        'PATCH' => await client.patchUrl(uri),
        'DELETE' => await client.deleteUrl(uri),
        _ => throw ApiException(
          'unsupported request method: $method',
          statusCode: 0,
        ),
      };
      _applyAuthHeader(request);
      if (payload != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(payload));
      }
      final response = await request.close().timeout(timeout);
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);
      if (!expectedStatuses.contains(response.statusCode)) {
        throw _apiException(response.statusCode, body);
      }
      if (body.trim().isEmpty) {
        return null;
      }
      try {
        return jsonDecode(body);
      } on FormatException {
        throw ApiException('服务返回了无法解析的数据', statusCode: response.statusCode);
      }
    } on TimeoutException {
      throw const ApiException('请求超时，请稍后重试', statusCode: 0);
    } on SocketException {
      throw const ApiException('无法连接到后端服务，请确认服务已启动', statusCode: 0);
    } on HandshakeException {
      throw const ApiException('安全连接失败，请检查服务地址', statusCode: 0);
    } finally {
      client.close(force: true);
    }
  }

  void _applyAuthHeader(HttpClientRequest request) {
    final value = token;
    if (value != null && value.isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $value');
    }
  }

  ApiException _apiException(int statusCode, String body) {
    return ApiException(
      _errorMessage(statusCode, body),
      statusCode: statusCode,
    );
  }

  String _errorMessage(int statusCode, String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic> && data['error'] is String) {
        return data['error'] as String;
      }
    } catch (_) {}
    return 'request failed: $statusCode';
  }
}
