import 'dart:async';

import 'package:flutter/material.dart';

import '../lyrics_utils.dart';
import '../audio_controller.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/artwork.dart';
import '../widgets/playback_mode_feedback.dart';

typedef QueueSongAction = void Function(Song song, List<Song> queue);
typedef QueueReorderAction =
    void Function(List<Song> queue, int oldIndex, int newIndex);
typedef LyricsOffsetAction = Future<Song> Function(Song song, int offsetMs);
typedef SongAsyncAction = Future<Song> Function(Song song);

void showPlaybackQueueSheet(
  BuildContext context, {
  required Song currentSong,
  required List<Song> queue,
  required SongTapCallback onSongTap,
  required Future<Song> Function(Song song) onFavoriteToggle,
  required QueueSongAction onQueueRemove,
  required QueueSongAction onQueuePlayNext,
  required QueueReorderAction onQueueReorder,
  required VoidCallback onQueueClear,
}) {
  final playbackQueue = queue.isEmpty ? [currentSong] : queue;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _QueueSheet(
      queue: playbackQueue,
      currentSong: currentSong,
      onSongTap: onSongTap,
      onFavoriteToggle: onFavoriteToggle,
      onQueueRemove: onQueueRemove,
      onQueuePlayNext: onQueuePlayNext,
      onQueueReorder: onQueueReorder,
      onQueueClear: onQueueClear,
    ),
  );
}

TextStyle? _darkTitle(BuildContext context) {
  return Theme.of(
    context,
  ).textTheme.titleMedium?.copyWith(color: kInk, fontWeight: FontWeight.w900);
}

String _songContentKey(Song song) {
  return [
    song.id,
    song.title,
    song.artist,
    song.album,
    song.audioUrl,
    song.lyrics.hashCode,
    song.lyricsOffsetMs,
  ].join('|');
}

bool _hasIntroLyricLine(List<TimedLyricLine> lines) {
  return lines.isNotEmpty && lines.first.time > Duration.zero;
}

List<TimedLyricLine> _lyricDisplayLines(List<TimedLyricLine> lines) {
  if (!_hasIntroLyricLine(lines)) {
    return lines;
  }
  return [const TimedLyricLine(time: Duration.zero, text: '前奏'), ...lines];
}

class PlayerPage extends StatelessWidget {
  const PlayerPage({
    super.key,
    required this.song,
    required this.queue,
    required this.onSongTap,
    required this.onFavoriteToggle,
    this.onSongEdit,
    required this.audioController,
    required this.isLoading,
    required this.onTogglePlay,
    required this.onSeek,
    required this.onNext,
    required this.onPrevious,
    required this.playbackMode,
    required this.onPlaybackModeChanged,
    required this.downloaded,
    required this.onDownload,
    this.onLyricsOffsetChanged,
    this.onLyricsFetch,
    required this.onQueueRemove,
    required this.onQueuePlayNext,
    required this.onQueueReorder,
    required this.onQueueClear,
  });

  final Song song;
  final List<Song> queue;
  final SongTapCallback onSongTap;
  final Future<Song> Function(Song song) onFavoriteToggle;
  final ValueChanged<Song>? onSongEdit;
  final MusicAudioController audioController;
  final bool isLoading;
  final VoidCallback onTogglePlay;
  final Future<void> Function(Duration position) onSeek;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final PlaybackMode playbackMode;
  final VoidCallback onPlaybackModeChanged;
  final bool downloaded;
  final Future<void> Function(Song song) onDownload;
  final LyricsOffsetAction? onLyricsOffsetChanged;
  final SongAsyncAction? onLyricsFetch;
  final QueueSongAction onQueueRemove;
  final QueueSongAction onQueuePlayNext;
  final QueueReorderAction onQueueReorder;
  final VoidCallback onQueueClear;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 720;
    final metadataLine = firstMetadataLine(song.lyrics);
    if (isMobile) {
      return Scaffold(
        backgroundColor: kScaffold,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                  const Spacer(),
                  Text('正在播放', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 18),
              Center(child: Artwork(song: song, size: 320, radius: 18)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          song.artist,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => onFavoriteToggle(song),
                    icon: Icon(
                      song.isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: kAccent,
                    ),
                  ),
                  const SizedBox(width: 18),
                  IconButton(
                    onPressed: () => _showSongInfo(context),
                    icon: const Icon(Icons.more_horiz_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _Lyrics(song: song, centered: true),
              const SizedBox(height: 20),
              _Progress(
                song: song,
                audioController: audioController,
                onSeek: onSeek,
              ),
              const SizedBox(height: 18),
              _Controls(
                big: true,
                audioController: audioController,
                isLoading: isLoading,
                onTogglePlay: onTogglePlay,
                onNext: onNext,
                onPrevious: onPrevious,
                playbackMode: playbackMode,
                onPlaybackModeChanged: onPlaybackModeChanged,
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Action(
                    icon: _modeIcon(playbackMode),
                    label: _modeLabel(playbackMode),
                    active: playbackMode != PlaybackMode.sequential,
                    onTap: onPlaybackModeChanged,
                  ),
                  _Action(
                    icon: downloaded
                        ? Icons.download_done_rounded
                        : Icons.download_rounded,
                    label: downloaded ? '已下载' : '下载',
                    active: downloaded,
                    onTap: downloaded ? null : () => _downloadSong(context),
                  ),
                  _Action(
                    icon: Icons.queue_music_rounded,
                    label: '播放列表',
                    onTap: () => _openQueue(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: song.colors.last,
      body: Stack(
        children: [
          Positioned.fill(child: _PlayerBackdrop(song: song)),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compactHeight = constraints.maxHeight < 760;
                final tinyHeight = constraints.maxHeight < 650;
                final artworkSize = tinyHeight
                    ? 170.0
                    : compactHeight
                    ? 220.0
                    : 250.0;
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    34,
                    tinyHeight ? 12 : 18,
                    34,
                    tinyHeight ? 18 : 28,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _GlassIconButton(
                            icon: Icons.arrow_back_rounded,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                          const Spacer(),
                          Text('正在播放', style: _darkTitle(context)),
                          const Spacer(),
                          _GlassIconButton(
                            icon: Icons.more_horiz_rounded,
                            onTap: () => _showSongInfo(context),
                          ),
                        ],
                      ),
                      SizedBox(height: tinyHeight ? 8 : 18),
                      Expanded(
                        flex: tinyHeight ? 6 : 7,
                        child: Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: _NowPlayingPanel(
                                song: song,
                                metadataLine: metadataLine,
                                artworkSize: artworkSize,
                                compact: compactHeight,
                                tiny: tinyHeight,
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 6,
                              child: _ImmersiveLyrics(
                                key: ValueKey(
                                  'lyrics-${_songContentKey(song)}',
                                ),
                                song: song,
                                positionStream: audioController.positionStream,
                                initialPosition:
                                    audioController.currentPosition,
                                canManageLyrics:
                                    onLyricsOffsetChanged != null &&
                                    onLyricsFetch != null,
                                onLyricsOffsetChanged: onLyricsOffsetChanged,
                                onLyricsFetch: onLyricsFetch,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: tinyHeight ? 10 : 16),
                      Flexible(
                        flex: tinyHeight ? 3 : 2,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 980,
                              maxHeight: 150,
                            ),
                            child: _DesktopControlPanel(
                              song: song,
                              audioController: audioController,
                              tinyHeight: tinyHeight,
                              downloaded: downloaded,
                              isLoading: isLoading,
                              playbackMode: playbackMode,
                              onSeek: onSeek,
                              onFavoriteToggle: onFavoriteToggle,
                              onDownload: () => _downloadSong(context),
                              onTogglePlay: onTogglePlay,
                              onNext: onNext,
                              onPrevious: onPrevious,
                              onPlaybackModeChanged: onPlaybackModeChanged,
                              onOpenQueue: () => _openQueue(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showSongInfo(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 720;
    if (!isMobile) {
      showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: cardDecoration(radius: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Artwork(song: song, size: 56, radius: 14),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _SongInfoLine(
                    label: '专辑',
                    value: song.album.isEmpty ? '未知专辑' : song.album,
                  ),
                  _SongInfoLine(
                    label: '时长',
                    value: formatDuration(song.duration),
                  ),
                  _SongInfoLine(label: '音质', value: '高品质 MP3'),
                  const SizedBox(height: 18),
                  if (onSongEdit != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onSongEdit?.call(song);
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('编辑信息'),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('知道了'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(song.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              '歌手：${song.artist}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '专辑：${song.album.isEmpty ? '未知专辑' : song.album}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '时长：${formatDuration(song.duration)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onSongEdit != null) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onSongEdit?.call(song);
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('编辑信息'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openQueue(BuildContext context) {
    showPlaybackQueueSheet(
      context,
      currentSong: song,
      queue: queue,
      onSongTap: onSongTap,
      onFavoriteToggle: onFavoriteToggle,
      onQueueRemove: onQueueRemove,
      onQueuePlayNext: onQueuePlayNext,
      onQueueReorder: onQueueReorder,
      onQueueClear: onQueueClear,
    );
  }

  Future<void> _downloadSong(BuildContext context) async {
    try {
      await onDownload(song);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${song.title} 已下载到本地')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }
}

class _DesktopControlPanel extends StatelessWidget {
  const _DesktopControlPanel({
    required this.song,
    required this.audioController,
    required this.tinyHeight,
    required this.downloaded,
    required this.isLoading,
    required this.playbackMode,
    required this.onSeek,
    required this.onFavoriteToggle,
    required this.onDownload,
    required this.onTogglePlay,
    required this.onNext,
    required this.onPrevious,
    required this.onPlaybackModeChanged,
    required this.onOpenQueue,
  });

  final Song song;
  final MusicAudioController audioController;
  final bool tinyHeight;
  final bool downloaded;
  final bool isLoading;
  final PlaybackMode playbackMode;
  final Future<void> Function(Duration position) onSeek;
  final Future<Song> Function(Song song) onFavoriteToggle;
  final VoidCallback onDownload;
  final VoidCallback onTogglePlay;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onPlaybackModeChanged;
  final VoidCallback onOpenQueue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(18, tinyHeight ? 8 : 12, 18, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .76),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: .78)),
        boxShadow: [
          BoxShadow(
            color: kInk.withValues(alpha: .07),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        children: [
          _Progress(
            song: song,
            audioController: audioController,
            onSeek: onSeek,
          ),
          SizedBox(height: tinyHeight ? 8 : 12),
          SizedBox(
            height: 68,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 132,
                    child: Row(
                      children: [
                        _GlassIconButton(
                          icon: song.isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          onTap: () => onFavoriteToggle(song),
                        ),
                        const SizedBox(width: 12),
                        _GlassIconButton(
                          icon: downloaded
                              ? Icons.download_done_rounded
                              : Icons.download_rounded,
                          onTap: downloaded ? null : onDownload,
                        ),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: _Controls(
                    big: true,
                    audioController: audioController,
                    isLoading: isLoading,
                    onTogglePlay: onTogglePlay,
                    onNext: onNext,
                    onPrevious: onPrevious,
                    playbackMode: playbackMode,
                    onPlaybackModeChanged: onPlaybackModeChanged,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 132,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _GlassIconButton(
                        icon: Icons.queue_music_rounded,
                        onTap: onOpenQueue,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Lyrics extends StatelessWidget {
  const _Lyrics({required this.song, this.centered = false});

  final Song song;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final lines = parseLyricLines(song.lyrics);
    final visibleLines = lines.isEmpty ? const ['暂无歌词信息'] : lines;
    if (centered) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < visibleLines.take(6).length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                visibleLines[i],
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: lines.isNotEmpty && i == 0 ? kAccentDark : kMuted,
                  fontWeight: lines.isNotEmpty && i == 0
                      ? FontWeight.w800
                      : FontWeight.w400,
                ),
              ),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('歌词', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 18),
        Expanded(
          child: ListView.builder(
            itemCount: visibleLines.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  visibleLines[index],
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: lines.isNotEmpty && index == 0
                        ? kAccentDark
                        : kMuted,
                    fontWeight: lines.isNotEmpty && index == 0
                        ? FontWeight.w800
                        : FontWeight.w400,
                    height: 1.45,
                  ),
                ),
              );
            },
          ),
        ),
        if (lines.isEmpty)
          Text(
            '请确认后端已启动，并刷新歌曲列表',
            style: Theme.of(context).textTheme.labelMedium,
          ),
      ],
    );
  }
}

class _QueueSheet extends StatefulWidget {
  const _QueueSheet({
    required this.queue,
    required this.currentSong,
    required this.onSongTap,
    required this.onFavoriteToggle,
    required this.onQueueRemove,
    required this.onQueuePlayNext,
    required this.onQueueReorder,
    required this.onQueueClear,
  });

  final List<Song> queue;
  final Song currentSong;
  final SongTapCallback onSongTap;
  final Future<Song> Function(Song song) onFavoriteToggle;
  final QueueSongAction onQueueRemove;
  final QueueSongAction onQueuePlayNext;
  final QueueReorderAction onQueueReorder;
  final VoidCallback onQueueClear;

  @override
  State<_QueueSheet> createState() => _QueueSheetState();
}

class _QueueSheetState extends State<_QueueSheet> {
  final GlobalKey _currentSongKey = GlobalKey();
  late List<Song> queue = List<Song>.of(widget.queue);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentSong());
  }

  void _scrollToCurrentSong() {
    final context = _currentSongKey.currentContext;
    if (context == null) {
      return;
    }
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: .35,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
              child: Row(
                children: [
                  Text('当前队列', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: queue.length <= 1 ? null : _clearQueue,
                    icon: const Icon(Icons.clear_all_rounded, size: 18),
                    label: const Text('清空'),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${queue.length} 首',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
                proxyDecorator: (child, index, animation) => Material(
                  color: Colors.transparent,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 1, end: 1.02).animate(
                      CurvedAnimation(parent: animation, curve: Curves.easeOut),
                    ),
                    child: child,
                  ),
                ),
                itemCount: queue.length,
                onReorder: _reorderQueue,
                itemBuilder: (context, index) {
                  final queueSong = queue[index];
                  final selected = queueSong.id == widget.currentSong.id;
                  return KeyedSubtree(
                    key: selected
                        ? _currentSongKey
                        : ValueKey('queue-$index-${queueSong.id}'),
                    child: _QueueSongRow(
                      song: queueSong,
                      index: index + 1,
                      selected: selected,
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onSongTap(queueSong, queue: queue);
                      },
                      onFavoriteTap: () => widget.onFavoriteToggle(queueSong),
                      onPlayNext: selected
                          ? null
                          : () => _moveSongNext(queueSong),
                      onRemove: selected ? null : () => _removeSong(queueSong),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearQueue() {
    setState(() => queue = [widget.currentSong]);
    widget.onQueueClear();
  }

  void _removeSong(Song song) {
    final nextQueue = queue.where((item) => item.id != song.id).toList();
    setState(() => queue = nextQueue);
    widget.onQueueRemove(song, queue);
  }

  void _moveSongNext(Song song) {
    final nextQueue = List<Song>.of(queue);
    final songIndex = nextQueue.indexWhere((item) => item.id == song.id);
    final currentIndex = nextQueue.indexWhere(
      (item) => item.id == widget.currentSong.id,
    );
    if (songIndex < 0 || currentIndex < 0) {
      return;
    }
    final item = nextQueue.removeAt(songIndex);
    final refreshedCurrentIndex = nextQueue.indexWhere(
      (item) => item.id == widget.currentSong.id,
    );
    nextQueue.insert(refreshedCurrentIndex + 1, item);
    setState(() => queue = nextQueue);
    widget.onQueuePlayNext(song, queue);
  }

  void _reorderQueue(int oldIndex, int newIndex) {
    final previousQueue = List<Song>.of(queue);
    var targetIndex = newIndex;
    if (oldIndex < targetIndex) {
      targetIndex -= 1;
    }
    if (targetIndex < 0) {
      targetIndex = 0;
    }
    if (targetIndex >= queue.length) {
      targetIndex = queue.length - 1;
    }
    final nextQueue = List<Song>.of(queue);
    final item = nextQueue.removeAt(oldIndex);
    nextQueue.insert(targetIndex, item);
    setState(() => queue = nextQueue);
    widget.onQueueReorder(previousQueue, oldIndex, newIndex);
  }
}

enum _QueueRowAction { favorite, playNext, remove }

class _QueueSongRow extends StatelessWidget {
  const _QueueSongRow({
    required this.song,
    required this.index,
    required this.selected,
    required this.onTap,
    required this.onFavoriteTap,
    required this.onPlayNext,
    required this.onRemove,
  });

  final Song song;
  final int index;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;
  final VoidCallback? onPlayNext;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? kAccent.withValues(alpha: .11)
                  : const Color(0xFFFBFCFD),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? kAccent.withValues(alpha: .30)
                    : const Color(0xFFEAF0F4),
              ),
              boxShadow: [
                BoxShadow(
                  color: (selected ? kAccent : kInk).withValues(alpha: .055),
                  blurRadius: selected ? 22 : 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 26,
                  child: selected
                      ? Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: kAccent.withValues(alpha: .14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.equalizer_rounded,
                            color: kAccent,
                            size: 17,
                          ),
                        )
                      : Text(
                          '$index',
                          textAlign: TextAlign.center,
                          style: textTheme.labelMedium?.copyWith(
                            color: kMuted,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Artwork(song: song, size: 46, radius: 13),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          color: selected ? kAccentDark : kInk,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelMedium?.copyWith(
                          color: selected ? kAccentDark : kMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatDuration(song.duration),
                  style: textTheme.labelMedium?.copyWith(
                    color: selected ? kAccentDark : kMuted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  tooltip: song.isFavorite ? '取消收藏' : '收藏',
                  onPressed: onFavoriteTap,
                  icon: Icon(
                    song.isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: song.isFavorite ? kAccent : kMuted,
                  ),
                ),
                PopupMenuButton<_QueueRowAction>(
                  tooltip: '队列操作',
                  color: Colors.white,
                  elevation: 14,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  onSelected: (action) {
                    if (action == _QueueRowAction.favorite) {
                      onFavoriteTap();
                    } else if (action == _QueueRowAction.playNext) {
                      onPlayNext?.call();
                    } else if (action == _QueueRowAction.remove) {
                      onRemove?.call();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: _QueueRowAction.favorite,
                      child: Text(song.isFavorite ? '取消收藏' : '收藏歌曲'),
                    ),
                    PopupMenuItem(
                      enabled: onPlayNext != null,
                      value: _QueueRowAction.playNext,
                      child: const Text('下一首播放'),
                    ),
                    PopupMenuItem(
                      enabled: onRemove != null,
                      value: _QueueRowAction.remove,
                      child: const Text('从队列移除'),
                    ),
                  ],
                  icon: const Icon(Icons.more_horiz_rounded, color: kMuted),
                ),
                ReorderableDragStartListener(
                  index: index - 1,
                  child: const _QueueDragHandle(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QueueDragHandle extends StatelessWidget {
  const _QueueDragHandle();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '拖动排序',
      child: Container(
        width: 30,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFEAF3F7).withValues(alpha: .72),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                _QueueGripDot(),
                SizedBox(width: 4),
                _QueueGripDot(),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                _QueueGripDot(),
                SizedBox(width: 4),
                _QueueGripDot(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueGripDot extends StatelessWidget {
  const _QueueGripDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        color: kMuted.withValues(alpha: .62),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SongInfoLine extends StatelessWidget {
  const _SongInfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerBackdrop extends StatelessWidget {
  const _PlayerBackdrop({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final first = song.colors.isEmpty ? kAccent : song.colors.first;
    final last = song.colors.isEmpty ? kAccentDark : song.colors.last;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(first, Colors.white, .78)!,
            Color.lerp(last, Colors.white, .84)!,
            const Color(0xFFF6FBFD),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -120,
            top: -120,
            child: _BlurCircle(color: Colors.white.withValues(alpha: .52)),
          ),
          Positioned(
            right: -150,
            bottom: -150,
            child: _BlurCircle(color: first.withValues(alpha: .16), size: 360),
          ),
          Positioned(
            right: 180,
            top: -190,
            child: _BlurCircle(color: last.withValues(alpha: .10), size: 300),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlurCircle extends StatelessWidget {
  const _BlurCircle({required this.color, this.size = 320});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _NowPlayingPanel extends StatelessWidget {
  const _NowPlayingPanel({
    required this.song,
    required this.metadataLine,
    required this.artworkSize,
    required this.compact,
    required this.tiny,
  });

  final Song song;
  final String metadataLine;
  final double artworkSize;
  final bool compact;
  final bool tiny;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 22 : 28,
        vertical: tiny ? 18 : 26,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: Colors.white.withValues(alpha: .48)),
        boxShadow: [
          BoxShadow(
            color: kInk.withValues(alpha: .055),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: .74),
                      Colors.white.withValues(alpha: .28),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .62),
                  ),
                ),
                child: Artwork(song: song, size: artworkSize, radius: 28),
              ),
              SizedBox(height: tiny ? 12 : 20),
              Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: textTheme.headlineLarge?.copyWith(
                  color: kInk,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  color: kMuted,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (!tiny) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    const _InfoPill(text: '高品质 MP3'),
                    if (song.album.isNotEmpty && !compact)
                      _InfoPill(text: song.album),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  metadataLine.isEmpty ? '暂无歌曲创作信息' : metadataLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(color: kMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: .52)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, color: onTap == null ? kMuted : kInk, size: 22),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: kAccent.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: kAccent.withValues(alpha: .12)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: kAccentDark,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ImmersiveLyrics extends StatefulWidget {
  const _ImmersiveLyrics({
    super.key,
    required this.song,
    required this.positionStream,
    required this.initialPosition,
    required this.canManageLyrics,
    this.onLyricsOffsetChanged,
    this.onLyricsFetch,
  });

  final Song song;
  final Stream<Duration> positionStream;
  final Duration initialPosition;
  final bool canManageLyrics;
  final LyricsOffsetAction? onLyricsOffsetChanged;
  final SongAsyncAction? onLyricsFetch;

  @override
  State<_ImmersiveLyrics> createState() => _ImmersiveLyricsState();
}

class _ImmersiveLyricsState extends State<_ImmersiveLyrics> {
  static const double _lyricRowExtent = 56;

  final _controller = ScrollController();
  int _lastIndex = -2;
  int _scrollRequest = 0;
  bool _savingOffset = false;
  bool _fetchingLyrics = false;
  String? _lyricsMessage;

  double _lyricVerticalPadding(double viewportHeight) {
    return (viewportHeight * .22).clamp(56.0, 120.0);
  }

  @override
  void didUpdateWidget(covariant _ImmersiveLyrics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_songContentKey(oldWidget.song) != _songContentKey(widget.song)) {
      _lastIndex = -2;
      if (_controller.hasClients) {
        _controller.jumpTo(0);
      }
    }
  }

  void _scrollToLyric(int index, {int retry = 0}) {
    final request = ++_scrollRequest;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || request != _scrollRequest) {
        return;
      }
      if (!_controller.hasClients) {
        if (retry < 3) {
          _scrollToLyric(index, retry: retry + 1);
        }
        return;
      }
      final position = _controller.position;
      if (!position.hasContentDimensions) {
        if (retry < 3) {
          _scrollToLyric(index, retry: retry + 1);
        }
        return;
      }
      final viewport = position.viewportDimension;
      final topPadding = _lyricVerticalPadding(viewport);
      final activeCenter =
          topPadding + index * _lyricRowExtent + _lyricRowExtent / 2;
      final target = (activeCenter - viewport * .38).clamp(
        0.0,
        position.maxScrollExtent,
      );
      if (retry == 0) {
        unawaited(
          _controller.animateTo(
            target,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          ),
        );
        return;
      }
      _controller.jumpTo(target);
    });
  }

  Future<void> _changeOffset(int deltaMs) async {
    final onLyricsOffsetChanged = widget.onLyricsOffsetChanged;
    if (!widget.canManageLyrics ||
        onLyricsOffsetChanged == null ||
        _savingOffset ||
        _fetchingLyrics) {
      return;
    }
    final nextOffset = widget.song.lyricsOffsetMs + deltaMs;
    setState(() {
      _savingOffset = true;
      _lyricsMessage = null;
    });
    try {
      await onLyricsOffsetChanged(widget.song, nextOffset);
      if (mounted) {
        setState(() => _lyricsMessage = '偏移已保存');
      }
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              _lyricsMessage = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _savingOffset = false);
      }
    }
  }

  Future<void> _resetOffset() async {
    if (widget.song.lyricsOffsetMs == 0) {
      return;
    }
    await _changeOffset(-widget.song.lyricsOffsetMs);
  }

  Future<void> _fetchLyrics() async {
    final onLyricsFetch = widget.onLyricsFetch;
    if (!widget.canManageLyrics ||
        onLyricsFetch == null ||
        _savingOffset ||
        _fetchingLyrics) {
      return;
    }
    setState(() {
      _fetchingLyrics = true;
      _lyricsMessage = null;
    });
    try {
      await onLyricsFetch(widget.song);
      if (mounted) {
        setState(() => _lyricsMessage = '歌词已补全');
      }
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              _lyricsMessage = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _fetchingLyrics = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rawTimedLines = parseTimedLyricLines(widget.song.lyrics);
    final hasIntroLine = _hasIntroLyricLine(rawTimedLines);
    final timedLines = _lyricDisplayLines(rawTimedLines);
    final fallbackLines = parseLyricLines(widget.song.lyrics);
    final hasTimedLyrics = timedLines.isNotEmpty;
    final offsetDuration = Duration(milliseconds: widget.song.lyricsOffsetMs);
    final adjustedInitialPosition = widget.initialPosition + offsetDuration;
    final busy = _savingOffset || _fetchingLyrics;
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .56),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: .58)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text('歌词', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (widget.song.lyricsOffsetMs != 0) ...[
                _InfoPill(
                  text: _formatLyricsOffset(widget.song.lyricsOffsetMs),
                ),
                const SizedBox(width: 8),
              ],
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: kAccent.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  hasTimedLyrics ? '实时滚动' : '静态预览',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: kAccentDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (widget.canManageLyrics) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _LyricToolButton(
                  icon: Icons.fast_rewind_rounded,
                  label: '提前',
                  onTap: busy ? null : () => _changeOffset(500),
                ),
                const SizedBox(width: 8),
                _LyricToolButton(
                  icon: Icons.restart_alt_rounded,
                  label: '重置',
                  onTap: busy ? null : _resetOffset,
                ),
                const SizedBox(width: 8),
                _LyricToolButton(
                  icon: Icons.fast_forward_rounded,
                  label: '延后',
                  onTap: busy ? null : () => _changeOffset(-500),
                ),
                const Spacer(),
                _LyricToolButton(
                  icon: Icons.cloud_sync_rounded,
                  label: _fetchingLyrics ? '补全中' : '补全歌词',
                  onTap: busy ? null : _fetchLyrics,
                  emphasized: true,
                ),
              ],
            ),
          ],
          if (_lyricsMessage != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _lyricsMessage!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: kMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: timedLines.isEmpty
                ? _StaticLyricPreview(lines: fallbackLines)
                : StreamBuilder<Duration>(
                    stream: widget.positionStream,
                    builder: (context, snapshot) {
                      final adjustedPosition =
                          (snapshot.data ?? adjustedInitialPosition) +
                          (snapshot.hasData ? offsetDuration : Duration.zero);
                      var current = currentLyricIndex(
                        timedLines,
                        adjustedPosition,
                      );
                      if (current < 0) {
                        current = 0;
                      }
                      if (current != _lastIndex) {
                        _lastIndex = current;
                        _scrollToLyric(current);
                      }
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          return ListView.builder(
                            controller: _controller,
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.symmetric(
                              vertical: _lyricVerticalPadding(
                                constraints.maxHeight,
                              ),
                            ),
                            itemExtent: _lyricRowExtent,
                            itemCount: timedLines.length,
                            itemBuilder: (context, index) {
                              final lyricIndex = index;
                              final active = lyricIndex == current;
                              final distance = (lyricIndex - current).abs();
                              final intro = hasIntroLine && lyricIndex == 0;
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutCubic,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium!
                                      .copyWith(
                                        color: active
                                            ? kAccentDark
                                            : kInk.withValues(
                                                alpha: distance <= 2
                                                    ? .62
                                                    : .34,
                                              ),
                                        fontSize: active ? 25 : 19,
                                        fontWeight: active
                                            ? FontWeight.w900
                                            : FontWeight.w600,
                                        height: 1.35,
                                      ),
                                  child: intro
                                      ? _IntroLyricBeat(active: active)
                                      : Text(
                                          timedLines[lyricIndex].text,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _IntroLyricBeat extends StatefulWidget {
  const _IntroLyricBeat({required this.active});

  final bool active;

  @override
  State<_IntroLyricBeat> createState() => _IntroLyricBeatState();
}

class _IntroLyricBeatState extends State<_IntroLyricBeat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.active) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _IntroLyricBeat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) {
      return;
    }
    if (widget.active) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final color = widget.active ? kAccentDark : kInk.withValues(alpha: .34);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('前奏'),
        const SizedBox(width: 14),
        if (!reduceMotion)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (index) {
                  final phase = widget.active
                      ? (_controller.value + index * .16) % 1.0
                      : 0.0;
                  final wave = widget.active
                      ? (1 - (phase - .5).abs() * 2).clamp(0.0, 1.0).toDouble()
                      : 0.0;
                  return Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(right: 7),
                    decoration: BoxDecoration(
                      color: color.withValues(
                        alpha: widget.active ? .34 + .5 * wave : .34,
                      ),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              );
            },
          )
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              return Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.only(right: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .38),
                  shape: BoxShape.circle,
                ),
              );
            }),
          ),
      ],
    );
  }
}

class _StaticLyricPreview extends StatelessWidget {
  const _StaticLyricPreview({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final visibleLines = lines.isEmpty
        ? const ['暂无歌词信息', '下载歌曲后如果包含歌词，会在这里展示']
        : lines;
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        vertical: MediaQuery.sizeOf(context).height * .12,
      ),
      itemCount: visibleLines.length,
      itemBuilder: (context, index) {
        final active = lines.isNotEmpty && index == 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Text(
            visibleLines[index],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: active ? kAccentDark : kInk.withValues(alpha: .48),
              fontSize: active ? 24 : 18,
              fontWeight: active ? FontWeight.w900 : FontWeight.w600,
              height: 1.35,
            ),
          ),
        );
      },
    );
  }
}

String _formatLyricsOffset(int offsetMs) {
  if (offsetMs == 0) {
    return '0.0s';
  }
  final seconds = (offsetMs.abs() / 1000).toStringAsFixed(1);
  return offsetMs > 0 ? '提前 ${seconds}s' : '延后 ${seconds}s';
}

class _LyricToolButton extends StatelessWidget {
  const _LyricToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final foreground = emphasized ? Colors.white : kAccentDark;
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: enabled ? foreground : kMuted,
        backgroundColor: emphasized
            ? kAccentDark.withValues(alpha: enabled ? 1 : .28)
            : kAccent.withValues(alpha: enabled ? .09 : .04),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        minimumSize: const Size(0, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      icon: Icon(icon, size: 17),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({
    required this.song,
    required this.audioController,
    required this.onSeek,
  });

  final Song song;
  final MusicAudioController audioController;
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
                    ? song.duration
                    : audioController.currentDuration);
            final maxMilliseconds = duration.inMilliseconds <= 0
                ? 1.0
                : duration.inMilliseconds.toDouble();
            final value = position.inMilliseconds
                .clamp(0, maxMilliseconds.toInt())
                .toDouble();
            return Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5,
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
                Row(
                  children: [
                    Text(
                      formatDuration(position),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const Spacer(),
                    Text(
                      formatDuration(duration),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    this.big = false,
    required this.audioController,
    required this.isLoading,
    required this.onTogglePlay,
    required this.onNext,
    required this.onPrevious,
    required this.playbackMode,
    required this.onPlaybackModeChanged,
  });

  final bool big;
  final MusicAudioController audioController;
  final bool isLoading;
  final VoidCallback onTogglePlay;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final PlaybackMode playbackMode;
  final VoidCallback onPlaybackModeChanged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: audioController.playingNotifier,
      builder: (context, isPlaying, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ModeIconButton(
              mode: playbackMode,
              onPressed: onPlaybackModeChanged,
            ),
            const SizedBox(width: 22),
            IconButton(
              onPressed: onPrevious,
              icon: const Icon(Icons.skip_previous_rounded, size: 34),
            ),
            const SizedBox(width: 18),
            InkWell(
              borderRadius: BorderRadius.circular(big ? 31 : 24),
              onTap: isLoading ? null : onTogglePlay,
              child: CircleAvatar(
                radius: big ? 31 : 24,
                backgroundColor: kAccent,
                child: isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: big ? 38 : 28,
                      ),
              ),
            ),
            const SizedBox(width: 18),
            IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.skip_next_rounded, size: 34),
            ),
          ],
        );
      },
    );
  }
}

class _ModeIconButton extends StatefulWidget {
  const _ModeIconButton({required this.mode, required this.onPressed});

  final PlaybackMode mode;
  final VoidCallback onPressed;

  @override
  State<_ModeIconButton> createState() => _ModeIconButtonState();
}

class _ModeIconButtonState extends State<_ModeIconButton> {
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
          icon: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: active
                  ? kAccent.withValues(alpha: .12)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _modeIcon(widget.mode),
              color: active ? kAccent : kMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: active ? kAccent.withValues(alpha: .12) : Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: active
                  ? kAccent
                  : onTap == null
                  ? kMuted
                  : kInk,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: active
                  ? kAccentDark
                  : onTap == null
                  ? kMuted
                  : kInk,
              fontWeight: active ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ],
      ),
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
