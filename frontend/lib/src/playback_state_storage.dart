import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'audio_controller.dart';

class SavedPlaybackState {
  const SavedPlaybackState({
    required this.songId,
    required this.queueIds,
    required this.playbackMode,
    required this.position,
  });

  final int? songId;
  final List<int> queueIds;
  final PlaybackMode playbackMode;
  final Duration position;

  Map<String, dynamic> toJson() {
    return {
      'songId': songId,
      'queueIds': queueIds,
      'playbackMode': playbackMode.name,
      'positionMs': position.inMilliseconds,
    };
  }

  factory SavedPlaybackState.fromJson(Map<String, dynamic> json) {
    final modeName = json['playbackMode'] as String? ?? '';
    return SavedPlaybackState(
      songId: (json['songId'] as num?)?.toInt(),
      queueIds: (json['queueIds'] as List? ?? const [])
          .whereType<num>()
          .map((id) => id.toInt())
          .where((id) => id > 0)
          .toList(),
      playbackMode: PlaybackMode.values.firstWhere(
        (mode) => mode.name == modeName,
        orElse: () => PlaybackMode.repeatAll,
      ),
      position: Duration(
        milliseconds: ((json['positionMs'] as num?)?.toInt() ?? 0).clamp(
          0,
          24 * 60 * 60 * 1000,
        ),
      ),
    );
  }
}

class PlaybackStateStorage {
  const PlaybackStateStorage._();

  static const _stateKey = 'musicflow.playback.state';

  static Future<SavedPlaybackState?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_stateKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) {
        return null;
      }
      return SavedPlaybackState.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(SavedPlaybackState state) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_stateKey, jsonEncode(state.toJson()));
  }

  static Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_stateKey);
  }
}
