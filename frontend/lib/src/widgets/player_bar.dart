import 'dart:async';

import 'package:flutter/material.dart';

import '../audio_controller.dart';
import '../models.dart';
import '../theme.dart';
import 'artwork.dart';
import 'playback_mode_feedback.dart';

class PlayerBar extends StatelessWidget {
  const PlayerBar({
    super.key,
    required this.song,
    required this.isMobile,
    required this.onOpenPlayer,
    required this.onOpenQueue,
    required this.onTogglePlay,
    required this.audioController,
    required this.isLoading,
    required this.onSeek,
    required this.onNext,
    required this.onPrevious,
    required this.playbackMode,
    required this.onPlaybackModeChanged,
  });

  final Song? song;
  final bool isMobile;
  final VoidCallback onOpenPlayer;
  final VoidCallback onOpenQueue;
  final VoidCallback onTogglePlay;
  final MusicAudioController audioController;
  final bool isLoading;
  final Future<void> Function(Duration position) onSeek;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final PlaybackMode playbackMode;
  final VoidCallback onPlaybackModeChanged;

  @override
  Widget build(BuildContext context) {
    final current = song;
    if (current == null) {
      return const SizedBox.shrink();
    }
    if (isMobile) {
      return InkWell(
        onTap: onOpenPlayer,
        child: Container(
          decoration: const BoxDecoration(
            color: kSurface,
            border: Border(top: BorderSide(color: kLine)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 60,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Artwork(song: current, size: 42, radius: 9),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              current.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            Text(
                              current.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ],
                        ),
                      ),
                      isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                ),
                              ),
                            )
                          : IconButton(
                              onPressed: onTogglePlay,
                              icon: ValueListenableBuilder<bool>(
                                valueListenable:
                                    audioController.playingNotifier,
                                builder: (context, isPlaying, _) {
                                  return Icon(
                                    isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: kInk,
                                  );
                                },
                              ),
                            ),
                      _PlaybackModeButton(
                        mode: playbackMode,
                        onPressed: onPlaybackModeChanged,
                      ),
                      IconButton(
                        onPressed: onOpenQueue,
                        icon: const Icon(
                          Icons.playlist_play_rounded,
                          color: kInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _MobileProgressBar(
                audioController: audioController,
                fallbackDuration: current.duration,
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final tight = constraints.maxWidth < 1080;
        return Container(
          height: 78,
          padding: EdgeInsets.symmetric(horizontal: tight ? 16 : 22),
          decoration: const BoxDecoration(
            color: kSurface,
            border: Border(top: BorderSide(color: kLine)),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: onOpenPlayer,
                child: Row(
                  children: [
                    Artwork(song: current, size: 48, radius: 10),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: tight ? 130 : 160,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            current.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          Text(
                            current.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      current.isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: current.isFavorite ? kAccent : kMuted,
                      size: 20,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _PlaybackModeButton(
                mode: playbackMode,
                onPressed: onPlaybackModeChanged,
              ),
              _RoundIcon(Icons.skip_previous_rounded, onPressed: onPrevious),
              InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: isLoading ? null : onTogglePlay,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: kAccent,
                    shape: BoxShape.circle,
                  ),
                  child: isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(13),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.6,
                            color: Colors.white,
                          ),
                        )
                      : ValueListenableBuilder<bool>(
                          valueListenable: audioController.playingNotifier,
                          builder: (context, isPlaying, _) {
                            return Icon(
                              isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 30,
                            );
                          },
                        ),
                ),
              ),
              _RoundIcon(Icons.skip_next_rounded, onPressed: onNext),
              SizedBox(width: tight ? 12 : 18),
              Expanded(
                flex: 5,
                child: _DesktopProgressBar(
                  audioController: audioController,
                  fallbackDuration: current.duration,
                  onSeek: onSeek,
                ),
              ),
              SizedBox(width: tight ? 12 : 20),
              const Icon(Icons.volume_up_rounded, color: kMuted, size: 20),
              const SizedBox(width: 6),
              _VolumeSlider(
                audioController: audioController,
                width: tight ? 100 : 130,
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: onOpenQueue,
                icon: const Icon(
                  Icons.queue_music_rounded,
                  color: kMuted,
                  size: 22,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DesktopProgressBar extends StatelessWidget {
  const _DesktopProgressBar({
    required this.audioController,
    required this.fallbackDuration,
    required this.onSeek,
  });

  final MusicAudioController audioController;
  final Duration fallbackDuration;
  final Future<void> Function(Duration position) onSeek;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: audioController.positionStream,
      builder: (context, positionSnapshot) {
        return StreamBuilder<Duration>(
          stream: audioController.durationStream,
          builder: (context, durationSnapshot) {
            final position =
                positionSnapshot.data ?? audioController.currentPosition;
            final duration =
                durationSnapshot.data ??
                (audioController.currentDuration == Duration.zero
                    ? fallbackDuration
                    : audioController.currentDuration);
            final maxMilliseconds = duration.inMilliseconds <= 0
                ? 1.0
                : duration.inMilliseconds.toDouble();
            final value = position.inMilliseconds
                .clamp(0, maxMilliseconds.toInt())
                .toDouble();
            return LayoutBuilder(
              builder: (context, constraints) {
                final showTimeLabels = constraints.maxWidth >= 170;
                return Row(
                  children: [
                    if (showTimeLabels) ...[
                      SizedBox(
                        width: 44,
                        child: Text(
                          formatDuration(position),
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          activeTrackColor: kAccent,
                          inactiveTrackColor: kAccent.withValues(alpha: .15),
                          thumbColor: kAccent,
                          overlayColor: kAccent.withValues(alpha: .12),
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 14,
                          ),
                        ),
                        child: Slider(
                          value: value,
                          max: maxMilliseconds,
                          onChanged: (next) =>
                              onSeek(Duration(milliseconds: next.round())),
                          onChangeEnd: (next) =>
                              onSeek(Duration(milliseconds: next.round())),
                        ),
                      ),
                    ),
                    if (showTimeLabels) ...[
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 44,
                        child: Text(
                          formatDuration(duration),
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _MobileProgressBar extends StatelessWidget {
  const _MobileProgressBar({
    required this.audioController,
    required this.fallbackDuration,
  });

  final MusicAudioController audioController;
  final Duration fallbackDuration;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: audioController.positionStream,
      builder: (context, positionSnapshot) {
        return StreamBuilder<Duration>(
          stream: audioController.durationStream,
          builder: (context, durationSnapshot) {
            final position =
                positionSnapshot.data ?? audioController.currentPosition;
            final duration =
                durationSnapshot.data ??
                (audioController.currentDuration == Duration.zero
                    ? fallbackDuration
                    : audioController.currentDuration);
            final total = duration.inMilliseconds <= 0
                ? 1
                : duration.inMilliseconds;
            final value = (position.inMilliseconds / total).clamp(0.0, 1.0);
            return SizedBox(
              height: 2,
              child: LinearProgressIndicator(
                value: value,
                backgroundColor: kAccent.withValues(alpha: .12),
                valueColor: const AlwaysStoppedAnimation<Color>(kAccent),
              ),
            );
          },
        );
      },
    );
  }
}

class _VolumeSlider extends StatefulWidget {
  const _VolumeSlider({required this.audioController, this.width = 130});

  final MusicAudioController audioController;
  final double width;

  @override
  State<_VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<_VolumeSlider> {
  double volume = .72;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 4,
          activeTrackColor: kAccent,
          inactiveTrackColor: kAccent.withValues(alpha: .15),
          thumbColor: kAccent,
          overlayColor: kAccent.withValues(alpha: .12),
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        ),
        child: Slider(
          value: volume,
          onChanged: (next) {
            setState(() => volume = next);
            widget.audioController.setVolume(next);
          },
        ),
      ),
    );
  }
}

class _PlaybackModeButton extends StatefulWidget {
  const _PlaybackModeButton({required this.mode, required this.onPressed});

  final PlaybackMode mode;
  final VoidCallback onPressed;

  @override
  State<_PlaybackModeButton> createState() => _PlaybackModeButtonState();
}

class _PlaybackModeButtonState extends State<_PlaybackModeButton> {
  Timer? _feedbackTimer;
  bool _feedbackVisible = false;

  void _handlePressed() {
    widget.onPressed();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _feedbackTimer?.cancel();
        setState(() {
          _feedbackVisible = true;
        });
        _feedbackTimer = Timer(const Duration(milliseconds: 1200), () {
          if (mounted) {
            setState(() {
              _feedbackVisible = false;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.mode != PlaybackMode.sequential;
    return PlaybackModeFeedback(
      visible: _feedbackVisible,
      label: _modeLabel(widget.mode),
      child: Tooltip(
        message: _modeLabel(widget.mode),
        child: IconButton(
          onPressed: _handlePressed,
          splashRadius: 22,
          icon: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: active
                  ? kAccent.withValues(alpha: .12)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _modeIcon(widget.mode),
              color: active ? kAccent : kMuted,
              size: 21,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon(this.icon, {required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: onPressed == null ? kMuted : kInk),
      splashRadius: 22,
    );
  }
}

IconData _modeIcon(PlaybackMode mode) {
  return switch (mode) {
    PlaybackMode.repeatAll => Icons.repeat_rounded,
    PlaybackMode.repeatOne => Icons.repeat_one_rounded,
    PlaybackMode.shuffle => Icons.shuffle_rounded,
    PlaybackMode.sequential => Icons.trending_flat_rounded,
  };
}

String _modeLabel(PlaybackMode mode) {
  return switch (mode) {
    PlaybackMode.repeatAll => '列表循环',
    PlaybackMode.repeatOne => '单曲循环',
    PlaybackMode.shuffle => '随机播放',
    PlaybackMode.sequential => '顺序播放',
  };
}
