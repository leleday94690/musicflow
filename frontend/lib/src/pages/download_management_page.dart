import 'package:flutter/material.dart';

import '../api_client.dart';
import '../delayed_loading.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/artwork.dart';
import '../widgets/empty_state.dart';

class DownloadManagementPage extends StatefulWidget {
  const DownloadManagementPage({
    super.key,
    required this.isMobile,
    required this.canManageLibrary,
    required this.authToken,
    required this.fallbackTasks,
    required this.onBack,
    required this.onSongTap,
    required this.onSongDelete,
    required this.onDownloadsChanged,
  });

  final bool isMobile;
  final bool canManageLibrary;
  final String? authToken;
  final List<DownloadTask> fallbackTasks;
  final VoidCallback onBack;
  final SongTapCallback onSongTap;
  final Future<void> Function(Song song) onSongDelete;
  final ValueChanged<List<DownloadTask>> onDownloadsChanged;

  @override
  State<DownloadManagementPage> createState() => _DownloadManagementPageState();
}

class _DownloadManagementPageState extends State<DownloadManagementPage> {
  static const int _pageSize = 50;

  List<DownloadTask> _tasks = const [];
  final DelayedLoadingController _refreshLoading = DelayedLoadingController(
    delay: const Duration(milliseconds: 120),
  );
  String _selectedStatus = 'all';
  bool _hasMore = false;
  bool _isLoadingMore = false;
  bool _hasLoaded = false;
  DateTime? _loadingVisibleAt;
  int _nextOffset = 0;
  int _totalCount = 0;
  int _completedCount = 0;
  int _activeCount = 0;
  int _failedCount = 0;
  int _requestSerial = 0;

  @override
  void initState() {
    super.initState();
    _refreshLoading.addListener(_handleLoadingChanged);
    if (widget.authToken == null) {
      _tasks = _sortLatestFirst(widget.fallbackTasks);
      _syncCountsFromTasks(_tasks);
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
  void didUpdateWidget(covariant DownloadManagementPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authToken != widget.authToken) {
      _tasks = const [];
      _hasLoaded = false;
      _resetPageState();
      if (widget.authToken == null) {
        _tasks = _sortLatestFirst(widget.fallbackTasks);
        _syncCountsFromTasks(_tasks);
        _hasLoaded = true;
      } else {
        _refresh();
      }
      return;
    }
    if (oldWidget.fallbackTasks != widget.fallbackTasks &&
        widget.authToken == null &&
        _tasks.isEmpty) {
      _tasks = _sortLatestFirst(widget.fallbackTasks);
      _syncCountsFromTasks(_tasks);
      _hasLoaded = true;
    }
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_refreshLoading.active || _isLoadingMore) {
      return;
    }
    final requestSerial = ++_requestSerial;
    if (!silent) {
      _refreshLoading.start();
    }
    try {
      final page = await MusicApiClient(
        token: widget.authToken,
      ).fetchDownloadsPage(limit: _pageSize, status: _selectedStatus);
      if (!mounted) {
        return;
      }
      if (requestSerial != _requestSerial) {
        return;
      }
      if (!silent) {
        await _waitForLoadingToSettle(requestSerial);
      }
      setState(() {
        _applyPage(page, append: false);
        _hasLoaded = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      if (!_hasLoaded && _tasks.isEmpty) {
        final fallback = _sortLatestFirst(widget.fallbackTasks);
        setState(() {
          _tasks = fallback;
          _syncCountsFromTasks(fallback);
          _hasLoaded = true;
        });
      }
    } finally {
      if (!silent) {
        _refreshLoading.stop();
      }
    }
  }

  Future<void> _waitForLoadingToSettle(int requestSerial) async {
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
    if (!mounted || requestSerial != _requestSerial) {
      return;
    }
  }

  Future<void> _loadMore() async {
    if (_refreshLoading.active || _isLoadingMore || !_hasMore) {
      return;
    }
    final requestSerial = ++_requestSerial;
    setState(() => _isLoadingMore = true);
    try {
      final page = await MusicApiClient(token: widget.authToken)
          .fetchDownloadsPage(
            limit: _pageSize,
            offset: _nextOffset,
            status: _selectedStatus,
          );
      if (!mounted || requestSerial != _requestSerial) {
        return;
      }
      setState(() {
        _applyPage(page, append: true);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
    } finally {
      if (mounted && requestSerial == _requestSerial) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleTasks = _visibleTasks;
    final queue = visibleTasks.map((task) => task.song).toList();
    final showSkeleton =
        !_hasLoaded && _tasks.isEmpty && _refreshLoading.visible;
    final showPendingSpace =
        !_hasLoaded &&
        _tasks.isEmpty &&
        _refreshLoading.active &&
        !showSkeleton;
    final padding = EdgeInsets.fromLTRB(
      widget.isMobile ? 18 : 28,
      widget.isMobile ? 14 : 20,
      widget.isMobile ? 18 : 28,
      24,
    );
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 520) {
          _loadMore();
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: padding,
              sliver: SliverList.list(
                children: [
                  _DownloadHeader(
                    isMobile: widget.isMobile,
                    count: _totalCount,
                    completedCount: _completedCount,
                    busy: _refreshLoading.active || _isLoadingMore,
                    loading: _refreshLoading.visible,
                    pending: showPendingSpace,
                    onBack: widget.onBack,
                    onRefresh: _refresh,
                    onClearCompleted: _completedCount == 0
                        ? null
                        : _clearCompleted,
                  ),
                  const SizedBox(height: 12),
                  _DownloadStats(
                    total: _totalCount,
                    completed: _completedCount,
                    active: _activeCount,
                    failed: _failedCount,
                    isMobile: widget.isMobile,
                  ),
                  const SizedBox(height: 12),
                  _DownloadStatusFilter(
                    selectedStatus: _selectedStatus,
                    counts: {
                      'all': _totalCount,
                      'completed': _completedCount,
                      'downloading': _activeCount,
                      'failed': _failedCount,
                    },
                    onSelected: _selectStatus,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            if (showSkeleton)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(padding.left, 0, padding.right, 0),
                sliver: const SliverToBoxAdapter(
                  child: _DownloadSkeletonList(),
                ),
              )
            else if (showPendingSpace)
              const SliverToBoxAdapter(child: SizedBox(height: 220))
            else if (_tasks.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.download_done_rounded,
                  message: '暂无下载任务',
                  margin: EdgeInsets.symmetric(vertical: 32),
                ),
              )
            else if (visibleTasks.isEmpty)
              SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.filter_alt_off_rounded,
                  message: '当前筛选下暂无下载任务',
                  margin: const EdgeInsets.symmetric(vertical: 32),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(padding.left, 0, padding.right, 0),
                sliver: SliverList.builder(
                  itemCount: visibleTasks.length,
                  itemBuilder: (context, index) {
                    final task = visibleTasks[index];
                    return _DownloadTaskRow(
                      task: task,
                      index: index + 1,
                      isFirst: index == 0,
                      isLast: index == visibleTasks.length - 1,
                      canManageLibrary: widget.canManageLibrary,
                      onTap: () => widget.onSongTap(task.song, queue: queue),
                      onDelete: () => _deleteSong(task.song),
                    );
                  },
                ),
              ),
            SliverToBoxAdapter(
              child: _DownloadListFooter(
                isLoadingMore: _isLoadingMore,
                hasMore: _hasMore,
                hasItems: visibleTasks.isNotEmpty,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSong(Song song) async {
    await widget.onSongDelete(song);
    await _refresh(silent: true);
  }

  List<DownloadTask> get _visibleTasks {
    return _tasks;
  }

  void _selectStatus(String status) {
    if (_selectedStatus == status || _refreshLoading.active || _isLoadingMore) {
      return;
    }
    setState(() {
      _selectedStatus = status;
      _tasks = const [];
      _hasLoaded = false;
      _resetPageState();
    });
    _refresh();
  }

  Future<void> _clearCompleted() async {
    if (_refreshLoading.active) {
      return;
    }
    _refreshLoading.start();
    try {
      final loaded = await MusicApiClient(
        token: widget.authToken,
      ).clearDownloads(status: 'completed');
      if (!mounted) {
        return;
      }
      final sorted = _sortLatestFirst(loaded);
      _syncCountsFromTasks(sorted);
      setState(() {
        _tasks = sorted.take(_pageSize).toList();
        _nextOffset = _tasks.length;
        _hasMore = sorted.length > _pageSize;
        if (_selectedStatus == 'completed') {
          _selectedStatus = 'all';
        }
      });
      widget.onDownloadsChanged(sorted);
      _refreshLoading.stop();
      await _refresh(silent: true);
    } finally {
      if (_refreshLoading.active) {
        _refreshLoading.stop();
      }
    }
  }

  void _applyPage(DownloadTaskPage page, {required bool append}) {
    final merged = append
        ? <DownloadTask>[..._tasks, ...page.items]
        : List<DownloadTask>.of(page.items);
    _tasks = _dedupeTasks(_sortLatestFirst(merged));
    _hasMore = page.hasMore;
    _nextOffset = page.nextOffset;
    _totalCount = page.allCount == 0 ? page.totalCount : page.allCount;
    _completedCount = page.completedCount;
    _activeCount = page.activeCount;
    _failedCount = page.failedCount;
  }

  void _syncCountsFromTasks(List<DownloadTask> tasks) {
    _totalCount = tasks.length;
    _completedCount = tasks
        .where((task) => _normalizedDownloadStatus(task) == 'completed')
        .length;
    _activeCount = tasks.where((task) {
      final status = _normalizedDownloadStatus(task);
      return status == 'downloading' || status == 'pending';
    }).length;
    _failedCount = tasks
        .where((task) => _normalizedDownloadStatus(task) == 'failed')
        .length;
  }

  void _resetPageState() {
    _hasMore = false;
    _isLoadingMore = false;
    _nextOffset = 0;
    _totalCount = 0;
    _completedCount = 0;
    _activeCount = 0;
    _failedCount = 0;
  }

  List<DownloadTask> _dedupeTasks(List<DownloadTask> tasks) {
    final seen = <int>{};
    return [
      for (final task in tasks)
        if (seen.add(task.id)) task,
    ];
  }

  List<DownloadTask> _sortLatestFirst(List<DownloadTask> tasks) {
    return List<DownloadTask>.of(tasks)..sort((a, b) {
      final timeCompare = b.updatedAt.compareTo(a.updatedAt);
      if (timeCompare != 0) {
        return timeCompare;
      }
      return b.id.compareTo(a.id);
    });
  }
}

class _DownloadHeader extends StatelessWidget {
  const _DownloadHeader({
    required this.isMobile,
    required this.count,
    required this.completedCount,
    required this.busy,
    required this.loading,
    required this.pending,
    required this.onBack,
    required this.onRefresh,
    required this.onClearCompleted,
  });

  final bool isMobile;
  final int count;
  final int completedCount;
  final bool busy;
  final bool loading;
  final bool pending;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback? onClearCompleted;

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
              Icons.download_done_rounded,
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
                  '下载管理',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  pending
                      ? '正在读取下载任务'
                      : loading
                      ? '同步中'
                      : '$count 个下载任务',
                  style: Theme.of(context).textTheme.labelMedium,
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
          if (!isMobile)
            OutlinedButton.icon(
              onPressed: busy ? null : onClearCompleted,
              style: OutlinedButton.styleFrom(
                foregroundColor: kAccentDark,
                disabledForegroundColor: kMuted.withValues(alpha: .55),
                side: BorderSide(
                  color: completedCount == 0
                      ? kLine
                      : kAccent.withValues(alpha: .22),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.cleaning_services_rounded, size: 17),
              label: Text('清理已完成 $completedCount'),
            )
          else
            IconButton(
              tooltip: '清理已完成',
              onPressed: busy ? null : onClearCompleted,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.cleaning_services_rounded, color: kMuted),
            ),
        ],
      ),
    );
  }
}

class _DownloadStats extends StatelessWidget {
  const _DownloadStats({
    required this.total,
    required this.completed,
    required this.active,
    required this.failed,
    required this.isMobile,
  });

  final int total;
  final int completed;
  final int active;
  final int failed;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final stats = [
      _DownloadStatData(
        icon: Icons.task_alt_rounded,
        label: '全部任务',
        value: '$total',
        color: kInk,
      ),
      _DownloadStatData(
        icon: Icons.download_done_rounded,
        label: '已完成',
        value: '$completed',
        color: kAccentDark,
      ),
      _DownloadStatData(
        icon: Icons.downloading_rounded,
        label: '进行中',
        value: '$active',
        color: const Color(0xFF4477AA),
      ),
      _DownloadStatData(
        icon: Icons.error_outline_rounded,
        label: '失败',
        value: '$failed',
        color: const Color(0xFFE15B5B),
      ),
    ];
    if (isMobile) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.35,
        children: stats.map((stat) => _DownloadStatCard(stat: stat)).toList(),
      );
    }
    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: _DownloadStatCard(stat: stats[i])),
        ],
      ],
    );
  }
}

class _DownloadStatData {
  const _DownloadStatData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
}

class _DownloadStatCard extends StatelessWidget {
  const _DownloadStatCard({required this.stat});

  final _DownloadStatData stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kLine),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: stat.color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(stat.icon, color: stat.color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  stat.value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  stat.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadStatusFilter extends StatelessWidget {
  const _DownloadStatusFilter({
    required this.selectedStatus,
    required this.counts,
    required this.onSelected,
  });

  final String selectedStatus;
  final Map<String, int> counts;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    const statuses = ['all', 'completed', 'downloading', 'failed'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final status in statuses) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: selectedStatus == status,
                label: Text(
                  '${_downloadStatusLabel(status)} ${counts[status] ?? 0}',
                ),
                onSelected: (_) => onSelected(status),
                selectedColor: kAccent.withValues(alpha: .16),
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: selectedStatus == status
                      ? kAccent.withValues(alpha: .3)
                      : kLine,
                ),
                labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selectedStatus == status ? kAccentDark : kMuted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DownloadTaskRow extends StatelessWidget {
  const _DownloadTaskRow({
    required this.task,
    required this.index,
    required this.isFirst,
    required this.isLast,
    required this.canManageLibrary,
    required this.onTap,
    required this.onDelete,
  });

  final DownloadTask task;
  final int index;
  final bool isFirst;
  final bool isLast;
  final bool canManageLibrary;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final song = task.song;
    final status = _normalizedDownloadStatus(task);
    final percent = (task.progress * 100).round().clamp(0, 100);
    final progress = task.progress.clamp(0.0, 1.0).toDouble();
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: isFirst ? const Radius.circular(18) : Radius.zero,
            bottom: isLast ? const Radius.circular(18) : Radius.zero,
          ),
          border: Border(
            top: isFirst ? const BorderSide(color: kLine) : BorderSide.none,
            left: const BorderSide(color: kLine),
            right: const BorderSide(color: kLine),
            bottom: const BorderSide(color: kLine),
          ),
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: const Color(0xFF273746),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$percent%',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: const Color(0xFF93A1AE),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${song.artist} · ${task.quality.isEmpty ? '标准音质' : task.quality} · ${_downloadStatusLabel(status)} · ${formatDuration(song.duration)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF8B98A5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 5,
                      value: progress,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF68CFE1),
                      ),
                      backgroundColor: const Color(0xFFEAF7FA),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (canManageLibrary)
              IconButton(
                tooltip: '删除下载歌曲',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                color: const Color(0xFFE15B5B),
                visualDensity: VisualDensity.compact,
              ),
            IconButton(
              tooltip: '播放',
              onPressed: onTap,
              icon: const Icon(Icons.play_circle_fill_rounded),
              color: const Color(0xFF45BCD6),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadSkeletonList extends StatefulWidget {
  const _DownloadSkeletonList();

  @override
  State<_DownloadSkeletonList> createState() => _DownloadSkeletonListState();
}

class _DownloadSkeletonListState extends State<_DownloadSkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 920),
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
        return Column(
          children: [
            for (var index = 0; index < 8; index++)
              _DownloadSkeletonRow(
                color: color,
                isFirst: index == 0,
                isLast: index == 7,
              ),
          ],
        );
      },
    );
  }
}

class _DownloadSkeletonRow extends StatelessWidget {
  const _DownloadSkeletonRow({
    required this.color,
    required this.isFirst,
    required this.isLast,
  });

  final Color color;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(18) : Radius.zero,
          bottom: isLast ? const Radius.circular(18) : Radius.zero,
        ),
        border: Border(
          top: isFirst ? const BorderSide(color: kLine) : BorderSide.none,
          left: const BorderSide(color: kLine),
          right: const BorderSide(color: kLine),
          bottom: const BorderSide(color: kLine),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          _DownloadSkeletonBlock(
            width: 16,
            height: 10,
            radius: 5,
            color: color,
          ),
          const SizedBox(width: 10),
          _DownloadSkeletonBlock(
            width: 42,
            height: 42,
            radius: 9,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FractionallySizedBox(
                        widthFactor: .42,
                        alignment: Alignment.centerLeft,
                        child: _DownloadSkeletonBlock(
                          height: 12,
                          radius: 6,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _DownloadSkeletonBlock(
                      width: 34,
                      height: 10,
                      radius: 5,
                      color: color,
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                FractionallySizedBox(
                  widthFactor: .36,
                  child: _DownloadSkeletonBlock(
                    height: 10,
                    radius: 5,
                    color: color,
                  ),
                ),
                const SizedBox(height: 9),
                _DownloadSkeletonBlock(height: 5, radius: 99, color: color),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _DownloadSkeletonBlock(
            width: 30,
            height: 30,
            radius: 15,
            color: color,
          ),
          const SizedBox(width: 8),
          _DownloadSkeletonBlock(
            width: 30,
            height: 30,
            radius: 15,
            color: color,
          ),
        ],
      ),
    );
  }
}

class _DownloadSkeletonBlock extends StatelessWidget {
  const _DownloadSkeletonBlock({
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

class _DownloadListFooter extends StatelessWidget {
  const _DownloadListFooter({
    required this.isLoadingMore,
    required this.hasMore,
    required this.hasItems,
  });

  final bool isLoadingMore;
  final bool hasMore;
  final bool hasItems;

  @override
  Widget build(BuildContext context) {
    if (!hasItems) {
      return const SizedBox(height: 28);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: isLoadingMore
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                hasMore ? '继续下滑加载更多' : '已加载全部',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: kMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

String _normalizedDownloadStatus(DownloadTask task) {
  final status = task.status.trim().toLowerCase();
  if (status.isEmpty && task.progress >= 1) {
    return 'completed';
  }
  if (status == 'complete' || status == 'done') {
    return 'completed';
  }
  if (status == 'queued') {
    return 'pending';
  }
  return status.isEmpty ? 'pending' : status;
}

String _downloadStatusLabel(String status) {
  return switch (status) {
    'all' => '全部',
    'completed' => '已完成',
    'downloading' => '进行中',
    'pending' => '等待中',
    'failed' => '失败',
    _ => status,
  };
}
