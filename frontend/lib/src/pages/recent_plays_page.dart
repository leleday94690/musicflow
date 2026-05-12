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
  List<PlayHistoryItem> _items = const [];
  final DelayedLoadingController _refreshLoading = DelayedLoadingController(
    delay: const Duration(milliseconds: 120),
  );
  DateTime? _loadingVisibleAt;
  var _hasLoaded = false;
  var _refreshToken = 0;

  @override
  void initState() {
    super.initState();
    _refreshLoading.addListener(_handleLoadingChanged);
    if (widget.token == null) {
      _items = _fallbackItems;
      _hasLoaded = true;
    } else {
      _refresh();
    }
  }

  @override
  void dispose() {
    _refreshLoading
      ..removeListener(_handleLoadingChanged)
      ..dispose();
    super.dispose();
  }

  void _handleLoadingChanged() {
    if (_refreshLoading.visible && _loadingVisibleAt == null) {
      _loadingVisibleAt = DateTime.now();
    }
    if (!_refreshLoading.visible) {
      _loadingVisibleAt = null;
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant RecentPlaysPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token ||
        oldWidget.fallbackItems != widget.fallbackItems) {
      if (widget.token == null) {
        _items = _fallbackItems;
        _hasLoaded = true;
      } else if (oldWidget.token != widget.token) {
        _items = const [];
        _hasLoaded = false;
      }
      _refresh();
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
      return history;
    } catch (_) {
      return _fallbackItems;
    }
  }

  List<PlayHistoryItem> get _fallbackItems {
    return widget.fallbackItems;
  }

  Future<void> _refresh() async {
    if (_refreshLoading.active) {
      return;
    }
    final token = ++_refreshToken;
    _refreshLoading.start();
    try {
      final next = await _loadHistory();
      await _waitForLoadingToSettle(token);
      if (!mounted) {
        return;
      }
      setState(() {
        _items = next;
        _hasLoaded = true;
      });
    } finally {
      if (mounted && token == _refreshToken) {
        _refreshLoading.stop();
      }
    }
  }

  Future<void> _waitForLoadingToSettle(int token) async {
    if (!_refreshLoading.visible) {
      return;
    }
    final shownAt = _loadingVisibleAt ?? DateTime.now();
    final remaining =
        const Duration(milliseconds: 180) - DateTime.now().difference(shownAt);
    if (remaining <= Duration.zero) {
      return;
    }
    await Future.delayed(remaining);
    if (!mounted || token != _refreshToken) {
      return;
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
    final showSkeleton =
        !_hasLoaded && _items.isEmpty && _refreshLoading.visible;
    final showPendingSpace =
        !_hasLoaded &&
        _items.isEmpty &&
        _refreshLoading.active &&
        !showSkeleton;
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
            fallback: fallback && _hasLoaded,
            pending: showPendingSpace,
            onBack: widget.onBack,
            onRefresh: _refresh,
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  axisAlignment: -1,
                  child: child,
                ),
              );
            },
            child: showSkeleton
                ? const _HistorySkeletonList(key: ValueKey('skeleton'))
                : showPendingSpace
                ? const SizedBox(key: ValueKey('pending'), height: 220)
                : _items.isEmpty
                ? const EmptyState(
                    key: ValueKey('empty'),
                    icon: Icons.history_rounded,
                    message: '暂无最近播放记录',
                    margin: EdgeInsets.symmetric(vertical: 32),
                  )
                : _HistoryList(
                    key: ValueKey('history'),
                    items: _items,
                    onSongTap: widget.onSongTap,
                    onFavoriteToggle: widget.onFavoriteToggle,
                  ),
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
    required this.pending,
    required this.onBack,
    required this.onRefresh,
  });

  final bool isMobile;
  final int count;
  final bool busy;
  final bool loading;
  final bool fallback;
  final bool pending;
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
                  pending
                      ? '正在读取播放记录'
                      : loading
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
    super.key,
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

class _HistorySkeletonList extends StatefulWidget {
  const _HistorySkeletonList({super.key});

  @override
  State<_HistorySkeletonList> createState() => _HistorySkeletonListState();
}

class _HistorySkeletonListState extends State<_HistorySkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 920),
      lowerBound: 0,
      upperBound: 1,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final color = Color.lerp(
          const Color(0xFFEAF0F4),
          const Color(0xFFF7FAFC),
          Curves.easeInOut.transform(_controller.value),
        )!;
        return Container(
          decoration: cardDecoration(radius: 18),
          child: Column(
            children: [
              for (var index = 0; index < 8; index++)
                _HistorySkeletonRow(color: color, showDivider: index < 7),
            ],
          ),
        );
      },
    );
  }
}

class _HistorySkeletonRow extends StatelessWidget {
  const _HistorySkeletonRow({required this.color, required this.showDivider});

  final Color color;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: kLine))
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          _SkeletonBlock(width: 16, height: 10, radius: 5, color: color),
          const SizedBox(width: 10),
          _SkeletonBlock(width: 42, height: 42, radius: 9, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: .38,
                  child: _SkeletonBlock(height: 12, radius: 6, color: color),
                ),
                const SizedBox(height: 8),
                FractionallySizedBox(
                  widthFactor: .28,
                  child: _SkeletonBlock(height: 10, radius: 5, color: color),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _SkeletonBlock(width: 52, height: 10, radius: 5, color: color),
          const SizedBox(width: 14),
          _SkeletonBlock(width: 24, height: 24, radius: 12, color: color),
        ],
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    this.width,
    required this.height,
    required this.radius,
    required this.color,
  });

  final double? width;
  final double height;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
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
