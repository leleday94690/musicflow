import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'config.dart';
import 'models.dart';

enum PlaybackMode { repeatAll, repeatOne, shuffle, sequential }

class MusicAudioController {
  MusicAudioController({this.baseUrl = AppConfig.apiBaseUrl}) {
    _positionSubscription = _player.onPositionChanged.listen((position) {
      currentPosition = position;
    });
    _durationSubscription = _player.onDurationChanged.listen((duration) {
      currentDuration = duration;
    });
    _stateSubscription = _player.onPlayerStateChanged.listen((state) {
      _setPlaying(state == PlayerState.playing, state);
    });
  }

  static const Duration _playTimeout = Duration(seconds: 12);
  static const Duration _controlTimeout = Duration(seconds: 8);

  final String baseUrl;
  final AudioPlayer _player = AudioPlayer();
  final ValueNotifier<bool> playingNotifier = ValueNotifier<bool>(false);
  late final StreamSubscription<Duration> _positionSubscription;
  late final StreamSubscription<Duration> _durationSubscription;
  late final StreamSubscription<PlayerState> _stateSubscription;
  Song? currentSong;
  Duration currentPosition = Duration.zero;
  Duration currentDuration = Duration.zero;
  PlayerState currentState = PlayerState.stopped;
  bool isPlaying = false;

  Stream<Duration> get positionStream => _player.onPositionChanged;
  Stream<Duration> get durationStream => _player.onDurationChanged;
  Stream<PlayerState> get stateStream => _player.onPlayerStateChanged;
  Stream<void> get completionStream => _player.onPlayerComplete;

  Future<void> play(
    Song song, {
    Duration startPosition = Duration.zero,
    String? authToken,
  }) async {
    currentSong = song;
    currentPosition = startPosition;
    final streamUri = Uri.parse('$baseUrl/api/songs/${song.id}/stream');
    final token = authToken?.trim();
    final url = token == null || token.isEmpty
        ? streamUri.toString()
        : streamUri.replace(queryParameters: {'token': token}).toString();
    try {
      await _player.stop().timeout(_controlTimeout);
      await _player.play(UrlSource(url)).timeout(_playTimeout);
      if (startPosition > Duration.zero) {
        try {
          await _player.seek(startPosition).timeout(_controlTimeout);
          currentPosition = startPosition;
        } catch (_) {}
      }
      _setPlaying(true, PlayerState.playing);
    } catch (_) {
      currentSong = null;
      currentPosition = Duration.zero;
      try {
        await _player.stop().timeout(_controlTimeout);
      } catch (_) {}
      _setPlaying(false, PlayerState.stopped);
      rethrow;
    }
  }

  Future<void> toggle() async {
    if (currentSong == null) {
      return;
    }
    if (isPlaying) {
      await _player.pause().timeout(_controlTimeout);
      _setPlaying(false, PlayerState.paused);
    } else {
      await _player.resume().timeout(_controlTimeout);
      _setPlaying(true, PlayerState.playing);
    }
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position).timeout(_controlTimeout);
    currentPosition = position;
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume.clamp(0.0, 1.0)).timeout(_controlTimeout);
  }

  Future<void> stop() async {
    await _player.stop().timeout(_controlTimeout);
    _setPlaying(false, PlayerState.stopped);
  }

  void markCompleted() {
    _setPlaying(false, PlayerState.completed);
  }

  void _setPlaying(bool value, PlayerState state) {
    currentState = state;
    isPlaying = value;
    if (playingNotifier.value != value) {
      playingNotifier.value = value;
    }
  }

  void dispose() {
    _positionSubscription.cancel();
    _durationSubscription.cancel();
    _stateSubscription.cancel();
    playingNotifier.dispose();
    _player.dispose();
  }
}
