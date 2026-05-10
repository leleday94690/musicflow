import 'package:flutter/foundation.dart';

import 'models.dart';

final libraryController = LibraryController();

List<Song> get songs => libraryController.songs;
List<Playlist> get playlists => libraryController.playlists;
List<DownloadTask> get downloads => libraryController.downloads;

class LibraryController extends ChangeNotifier {
  final List<Song> songs = <Song>[];
  final List<Playlist> playlists = <Playlist>[];
  final List<DownloadTask> downloads = <DownloadTask>[];

  void setAll({
    required List<Song> songs,
    required List<Playlist> playlists,
    required List<DownloadTask> downloads,
  }) {
    this.songs
      ..clear()
      ..addAll(songs);
    this.playlists
      ..clear()
      ..addAll(playlists);
    this.downloads
      ..clear()
      ..addAll(downloads);
    notifyListeners();
  }

  void setSongs(List<Song> value) {
    songs
      ..clear()
      ..addAll(value);
    notifyListeners();
  }

  void appendSongs(List<Song> value) {
    var changed = false;
    for (final song in value) {
      if (songs.any((item) => item.id == song.id)) {
        continue;
      }
      songs.add(song);
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  void setPlaylists(List<Playlist> value) {
    playlists
      ..clear()
      ..addAll(value);
    notifyListeners();
  }

  void setDownloads(List<DownloadTask> value) {
    downloads
      ..clear()
      ..addAll(value);
    notifyListeners();
  }

  void addSongIfAbsentToFront(Song song) {
    if (!songs.any((item) => item.id == song.id)) {
      songs.insert(0, song);
      notifyListeners();
    }
  }

  void addPlaylistToFront(Playlist playlist) {
    playlists.insert(0, playlist);
    notifyListeners();
  }

  void upsertPlaylist(Playlist updated) {
    final index = playlists.indexWhere((playlist) => playlist.id == updated.id);
    if (index >= 0) {
      playlists[index] = updated;
    } else {
      playlists.insert(0, updated);
    }
    notifyListeners();
  }

  void removePlaylist(int playlistId) {
    final count = playlists.length;
    playlists.removeWhere((playlist) => playlist.id == playlistId);
    if (playlists.length != count) {
      notifyListeners();
    }
  }

  void replaceSongEverywhere(Song updated) {
    var changed = false;
    final songIndex = songs.indexWhere((song) => song.id == updated.id);
    if (songIndex >= 0) {
      songs[songIndex] = updated;
      changed = true;
    }
    for (var i = 0; i < downloads.length; i++) {
      if (downloads[i].song.id == updated.id) {
        downloads[i] = DownloadTask(
          id: downloads[i].id,
          song: updated,
          quality: downloads[i].quality,
          progress: downloads[i].progress,
          status: downloads[i].status,
          updatedAt: downloads[i].updatedAt,
        );
        changed = true;
      }
    }
    for (var i = 0; i < playlists.length; i++) {
      final playlist = playlists[i];
      if (!playlist.songs.any((song) => song.id == updated.id)) {
        continue;
      }
      final updatedSongs = playlist.songs
          .map((song) => song.id == updated.id ? updated : song)
          .toList();
      playlists[i] = Playlist(
        id: playlist.id,
        name: playlist.name,
        description: playlist.description,
        owner: playlist.owner,
        songs: updatedSongs,
        colors: playlist.colors,
        icon: playlist.icon,
        isFavorite: playlist.isFavorite,
        songCount: playlist.songCount,
        totalTime: playlist.totalTime,
        updatedText: playlist.updatedText,
      );
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  void removeSongEverywhere(int songId) {
    var changed = false;
    final songCount = songs.length;
    songs.removeWhere((song) => song.id == songId);
    changed = songs.length != songCount || changed;
    final downloadCount = downloads.length;
    downloads.removeWhere((task) => task.song.id == songId);
    changed = downloads.length != downloadCount || changed;
    for (var i = 0; i < playlists.length; i++) {
      final playlist = playlists[i];
      final updatedSongs = playlist.songs
          .where((song) => song.id != songId)
          .toList();
      if (updatedSongs.length == playlist.songs.length) {
        continue;
      }
      playlists[i] = Playlist(
        id: playlist.id,
        name: playlist.name,
        description: playlist.description,
        owner: playlist.owner,
        songs: updatedSongs,
        colors: playlist.colors,
        icon: playlist.icon,
        isFavorite: playlist.isFavorite,
        songCount: updatedSongs.length,
        totalTime: updatedSongs.fold<Duration>(
          Duration.zero,
          (total, song) => total + song.duration,
        ),
        updatedText: playlist.updatedText,
      );
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }
}
