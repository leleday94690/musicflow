import 'package:flutter/material.dart';

import '../api_client.dart';
import '../delayed_loading.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/artwork.dart';
import '../widgets/empty_state.dart';

class RecentPlaysPage extends StatefulWidget {
  const RecentPlaysPage({
    super.key,
    required this.isMobile,
    required this.token,
    required this.fallbackItems,
    required this.onBack,
    required this.onSongTap,
    required this.onFavoriteToggle,
  });

  final bool isMobile;
  final String? token;
  final List<PlayHistoryItem> fallbackItems;
  final VoidCallback onBack;
  final SongTapCallback onSongTap;
  final Future<Song> Function(Song song) onFavoriteToggle;

  @override
  State<RecentPlaysPage> createState() => _RecentPlaysPageState();
}

class _RecentPlaysPageState extends State<RecentPlaysPage> {
  late List<PlayHistoryItem> _items;
  final DelayedLoadingController _refreshLoading = DelayedLoadingController();

  @override
  void initState() {
    super.initState();
    _refreshLoading.addListener(_handleLoadingChanged);
    _items = _fallbackItems;
    _refresh(silent: true);
  }

  @override
  void dispose() {
    _refreshLoading
      ..removeListener(_handleLoadingChanged)
      ..dispose();
    super.dispose();
  }

  void _handleLoadingChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant RecentPlaysPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token ||
        oldWidget.fallbackItems != widget.fallbackItems) {
      if (_items.isEmpty || _items.any((item) => item.id < 0)) {
        _items = _fallbackItems;
      }
      _refresh(silent: true);
    }
  }

  Future<List<PlayHistoryItem>> _loadHistory() async {
    final token = widget.token;
    if (token == null) {
      return _fallbackItems;
    }
    try {
      final history = await MusicApiClient(
        token: token,
      ).fetchPlayHistory(limit: 80);
      return history.isEmpty ? _fallbackItems : history;
    } catch (_) {
      return _fallbackItems;
    }
  }

  List<PlayHistoryItem> get _fallbackItems {
    return widget.fallbackItems;
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_refreshLoading.active) {
      return;
    }
    if (!silent) {
      _refreshLoading.start();
    }
    try {
      final next = await _loadHistory();
      if (!mounted) {
        return;
      }
      setState(() {
        _items = next;
      });
    } finally {
      if (!silent) {
        _refreshLoading.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.fromLTRB(
      widget.isMobile ? 18 : 28,
      widget.isMobile ? 14 : 20,
      widget.isMobile ? 18 : 28,
      24,
    );
    final fallback = _items.any((item) => item.id < 0);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: padding,
        children: [
          _Header(
            isMobile: widget.isMobile,
            count: _items.length,
            busy: _refreshLoading.active,
            loading: _refreshLoading.visible,
            fallback: fallback,
            onBack: widget.onBack,
            onRefresh: _refresh,
          ),
          const SizedBox(height: 12),
          if (_items.isEmpty)
            const EmptyState(
              icon: Icons.history_rounded,
              message: '暂无最近播放记录',
              margin: EdgeInsets.symmetric(vertical: 32),
            )
          else
            _HistoryList(
              items: _items,
              onSongTap: widget.onSongTap,
              onFavoriteToggle: widget.onFavoriteToggle,
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.isMobile,
    required this.count,
    required this.busy,
    required this.loading,
    required this.fallback,
    required this.onBack,
    required this.onRefresh,
  });

  final bool isMobile;
  final int count;
  final bool busy;
  final bool loading;
  final bool fallback;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 10 : 12,
        vertical: isMobile ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDEFF4)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.arrow_back_rounded, color: kInk),
          ),
          const SizedBox(width: 4),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: kAccent.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.history_rounded,
              color: kAccentDark,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '最近播放',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  loading
                      ? '同步中'
                      : fallback
                      ? '显示最近概览'
                      : '$count 条播放记录',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: kMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: busy ? null : onRefresh,
            visualDensity: VisualDensity.compact,
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, color: kMuted),
          ),
        ],
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.items,
    required this.onSongTap,
    required this.onFavoriteToggle,
  });

  final List<PlayHistoryItem> items;
  final SongTapCallback onSongTap;
  final Future<Song> Function(Song song) onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final queue = items.map((item) => item.song).toList();
    return Container(
      decoration: cardDecoration(radius: 18),
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++)
            _HistoryRow(
              item: items[index],
              index: index + 1,
              showDivider: index < items.length - 1,
              onTap: () => onSongTap(items[index].song, queue: queue),
              onFavoriteTap: () => onFavoriteToggle(items[index].song),
            ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.item,
    required this.index,
    required this.showDivider,
    required this.onTap,
    required this.onFavoriteTap,
  });

  final PlayHistoryItem item;
  final int index;
  final bool showDivider;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    final song = item.song;
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(bottom: BorderSide(color: kLine))
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text(
                '$index',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            Artwork(song: song, size: 42, radius: 9),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${song.artist} · ${formatDuration(song.duration)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              item.playedAt.millisecondsSinceEpoch == 0
                  ? '最近听过'
                  : formatRelativeTime(item.playedAt),
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onFavoriteTap,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                song.isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: song.isFavorite ? kAccent : kMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
