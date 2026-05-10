import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'audio_controller.dart';
import 'models.dart';

class PlaybackController extends ChangeNotifier {
  final math.Random _random = math.Random();

  Song? currentSong;
  PlaybackMode playbackMode = PlaybackMode.repeatAll;
  bool isPlaying = false;
  bool isAudioLoading = false;
  String? playbackError;
  List<Song> currentQueue = const [];

  void prepareSong(Song song, {List<Song>? queue}) {
    if (queue != null) {
      currentQueue = _normalizedQueue(queue, song);
    } else if (currentQueue.isEmpty ||
        !currentQueue.any((item) => item.id == song.id)) {
      currentQueue = [song];
    }
    currentSong = song;
    isPlaying = false;
    isAudioLoading = true;
    playbackError = null;
    notifyListeners();
  }

  void finishSongLoad({required bool playing}) {
    isPlaying = playing;
    isAudioLoading = false;
    playbackError = null;
    notifyListeners();
  }

  void failSongLoad({String? message}) {
    isPlaying = false;
    isAudioLoading = false;
    playbackError = message;
    notifyListeners();
  }

  void clearPlaybackError() {
    if (playbackError == null) {
      return;
    }
    playbackError = null;
    notifyListeners();
  }

  void setAudioLoading(bool value) {
    if (isAudioLoading == value) {
      return;
    }
    isAudioLoading = value;
    notifyListeners();
  }

  void setPlaying(bool value) {
    if (isPlaying == value) {
      return;
    }
    isPlaying = value;
    notifyListeners();
  }

  void setCurrentSong(Song? song, {List<Song>? queue}) {
    if (currentSong?.id == song?.id) {
      currentSong = song;
      if (song == null) {
        currentQueue = const [];
      } else if (queue != null) {
        currentQueue = _normalizedQueue(queue, song);
      } else {
        currentQueue = currentQueue
            .map((item) => item.id == song.id ? song : item)
            .toList();
      }
      notifyListeners();
      return;
    }
    currentSong = song;
    if (song == null) {
      currentQueue = const [];
    } else if (queue != null) {
      currentQueue = _normalizedQueue(queue, song);
    } else if (currentQueue.isEmpty ||
        !currentQueue.any((item) => item.id == song.id)) {
      currentQueue = [song];
    }
    notifyListeners();
  }

  void updateCurrentSongIfMatching(Song song) {
    if (currentSong?.id != song.id) {
      return;
    }
    currentSong = song;
    currentQueue = currentQueue
        .map((item) => item.id == song.id ? song : item)
        .toList();
    notifyListeners();
  }

  void cyclePlaybackMode() {
    playbackMode = switch (playbackMode) {
      PlaybackMode.repeatAll => PlaybackMode.repeatOne,
      PlaybackMode.repeatOne => PlaybackMode.shuffle,
      PlaybackMode.shuffle => PlaybackMode.sequential,
      PlaybackMode.sequential => PlaybackMode.repeatAll,
    };
    notifyListeners();
  }

  void setPlaybackMode(PlaybackMode mode) {
    if (playbackMode == mode) {
      return;
    }
    playbackMode = mode;
    notifyListeners();
  }

  void markCompleted() {
    isPlaying = false;
    notifyListeners();
  }

  bool shouldStopAtQueueEnd(List<Song> queue) {
    final current = currentSong;
    return current != null &&
        playbackMode == PlaybackMode.sequential &&
        _isLastSong(queue, current);
  }

  Song? nextSong(List<Song> queue, {required bool wrap}) {
    final current = currentSong;
    if (current == null || queue.isEmpty) {
      return null;
    }
    if (playbackMode == PlaybackMode.repeatOne) {
      return current;
    }
    if (playbackMode == PlaybackMode.shuffle && queue.length > 1) {
      Song next;
      do {
        next = queue[_random.nextInt(queue.length)];
      } while (next.id == current.id);
      return next;
    }
    final index = queue.indexWhere((song) => song.id == current.id);
    if (index < 0) {
      return queue.first;
    }
    final nextIndex = index + 1;
    if (nextIndex < queue.length) {
      return queue[nextIndex];
    }
    return wrap ? queue.first : current;
  }

  List<Song> queueOr(List<Song> fallback) {
    return currentQueue.isEmpty ? fallback : currentQueue;
  }

  void setQueue(List<Song> queue) {
    final current = currentSong;
    if (current == null) {
      currentQueue = _deduplicatedQueue(queue);
    } else {
      currentQueue = _normalizedQueue(queue, current, rotateToCurrent: false);
    }
    notifyListeners();
  }

  void removeFromQueue(Song song, List<Song> visibleQueue) {
    final current = currentSong;
    if (current != null && song.id == current.id) {
      return;
    }
    final nextQueue = _deduplicatedQueue(
      visibleQueue.where((item) => item.id != song.id).toList(),
    );
    setQueue(nextQueue);
  }

  void clearQueue() {
    final current = currentSong;
    currentQueue = current == null ? const [] : [current];
    notifyListeners();
  }

  void moveQueueItem(List<Song> visibleQueue, int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= visibleQueue.length) {
      return;
    }
    var targetIndex = newIndex;
    if (oldIndex < targetIndex) {
      targetIndex -= 1;
    }
    if (targetIndex < 0) {
      targetIndex = 0;
    }
    if (targetIndex >= visibleQueue.length) {
      targetIndex = visibleQueue.length - 1;
    }
    final nextQueue = List<Song>.of(visibleQueue);
    final item = nextQueue.removeAt(oldIndex);
    nextQueue.insert(targetIndex, item);
    setQueue(nextQueue);
  }

  void moveSongNext(Song song, List<Song> visibleQueue) {
    final current = currentSong;
    if (current == null || song.id == current.id) {
      return;
    }
    final nextQueue = _deduplicatedQueue(visibleQueue);
    final songIndex = nextQueue.indexWhere((item) => item.id == song.id);
    final currentIndex = nextQueue.indexWhere((item) => item.id == current.id);
    if (songIndex < 0 || currentIndex < 0) {
      return;
    }
    final item = nextQueue.removeAt(songIndex);
    final refreshedCurrentIndex = nextQueue.indexWhere(
      (item) => item.id == current.id,
    );
    nextQueue.insert(refreshedCurrentIndex + 1, item);
    setQueue(nextQueue);
  }

  bool queueSongNext(Song song) {
    final current = currentSong;
    if (current == null || song.id == current.id) {
      return false;
    }
    final nextQueue = _deduplicatedQueue(
      currentQueue.isEmpty ? [current] : currentQueue,
    );
    if (!nextQueue.any((item) => item.id == current.id)) {
      nextQueue.insert(0, current);
    }
    nextQueue.removeWhere((item) => item.id == song.id);
    final currentIndex = nextQueue.indexWhere((item) => item.id == current.id);
    nextQueue.insert(currentIndex + 1, song);
    currentQueue = nextQueue;
    notifyListeners();
    return true;
  }

  Song? previousSong(List<Song> queue) {
    final current = currentSong;
    if (current == null || queue.isEmpty) {
      return null;
    }
    final index = queue.indexWhere((song) => song.id == current.id);
    final previousIndex = index <= 0 ? queue.length - 1 : index - 1;
    return queue[previousIndex];
  }

  Song? fallbackSong(
    List<Song> queue,
    Set<int> failedSongIds, {
    required bool wrap,
  }) {
    if (queue.isEmpty || failedSongIds.length >= queue.length) {
      return null;
    }
    if (playbackMode == PlaybackMode.shuffle) {
      final candidates = queue
          .where((song) => !failedSongIds.contains(song.id))
          .toList();
      if (candidates.isEmpty) {
        return null;
      }
      return candidates[_random.nextInt(candidates.length)];
    }
    final current = currentSong;
    final startIndex = current == null
        ? -1
        : queue.indexWhere((song) => song.id == current.id);
    for (var offset = 1; offset <= queue.length; offset++) {
      final rawIndex = startIndex + offset;
      if (rawIndex >= queue.length && !wrap) {
        return null;
      }
      final index = rawIndex % queue.length;
      final candidate = queue[index];
      if (!failedSongIds.contains(candidate.id)) {
        return candidate;
      }
    }
    return null;
  }

  bool _isLastSong(List<Song> queue, Song current) {
    final index = queue.indexWhere((song) => song.id == current.id);
    return index >= queue.length - 1;
  }

  List<Song> _normalizedQueue(
    List<Song> queue,
    Song current, {
    bool rotateToCurrent = true,
  }) {
    final normalized = _deduplicatedQueue(queue);
    if (normalized.isEmpty) {
      return [current];
    }
    final currentIndex = normalized.indexWhere((song) => song.id == current.id);
    if (currentIndex < 0) {
      return [current, ...normalized];
    }
    if (!rotateToCurrent || currentIndex == 0) {
      return normalized;
    }
    return [...normalized.skip(currentIndex), ...normalized.take(currentIndex)];
  }

  List<Song> _deduplicatedQueue(List<Song> queue) {
    final seen = <int>{};
    final result = <Song>[];
    for (final song in queue) {
      if (song.id == 0 || !seen.add(song.id)) {
        continue;
      }
      result.add(song);
    }
    return result;
  }
}
