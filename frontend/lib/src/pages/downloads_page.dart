import 'package:flutter/material.dart';

import '../library_state.dart';
import '../models.dart';
import '../theme.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({
    super.key,
    required this.isMobile,
    required this.canManageLibrary,
    required this.authToken,
    required this.searchKeyword,
    required this.results,
    required this.downloadedOnlineIds,
    required this.downloadingId,
    required this.errorMessage,
    required this.searching,
    required this.batchActive,
    required this.batchPaused,
    required this.batchCompleted,
    required this.batchTotal,
    required this.batchSuccess,
    required this.onSearchKeywordChanged,
    required this.onSearch,
    required this.onDownload,
    required this.onBatchDownload,
    required this.onBatchPause,
    required this.onClearError,
    required this.onSongTap,
    required this.onSongDownloaded,
    required this.onAuthExpired,
  });

  final bool isMobile;
  final bool canManageLibrary;
  final String? authToken;
  final String searchKeyword;
  final List<Map<String, dynamic>> results;
  final Set<String> downloadedOnlineIds;
  final String? downloadingId;
  final String? errorMessage;
  final bool searching;
  final bool batchActive;
  final bool batchPaused;
  final int batchCompleted;
  final int batchTotal;
  final int batchSuccess;
  final ValueChanged<String> onSearchKeywordChanged;
  final VoidCallback onSearch;
  final ValueChanged<Map<String, dynamic>> onDownload;
  final ValueChanged<List<Map<String, dynamic>>> onBatchDownload;
  final VoidCallback onBatchPause;
  final VoidCallback onClearError;
  final SongTapCallback onSongTap;
  final ValueChanged<Song> onSongDownloaded;
  final VoidCallback onAuthExpired;

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    searchController.text = widget.searchKeyword;
  }

  @override
  void didUpdateWidget(covariant DownloadsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchKeyword != widget.searchKeyword &&
        searchController.text != widget.searchKeyword) {
      searchController.text = widget.searchKeyword;
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final downloadableResults = widget.results
        .where(
          (song) =>
              !_isAlreadyAvailable(song) &&
              !widget.downloadedOnlineIds.contains(song['id']),
        )
        .toList();
    final horizontalPadding = widget.isMobile ? 18.0 : 28.0;
    final showFloatingError =
        widget.errorMessage != null && widget.results.isNotEmpty;
    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            widget.isMobile ? 20 : 28,
            horizontalPadding,
            26,
          ),
          children: [
            _DownloadHeader(downloadedCount: downloads.length),
            const SizedBox(height: 16),
            if (widget.authToken == null)
              const _Panel(
                title: '我的下载',
                subtitle: '登录后可以从系统曲库下载，也可以从网络获取到个人空间',
                child: _EmptySearchState(),
              )
            else ...[
              _SearchPanel(
                controller: searchController,
                busy: widget.searching || widget.batchActive,
                loading: widget.searching,
                onChanged: widget.onSearchKeywordChanged,
                onSubmitted: widget.onSearch,
              ),
              const SizedBox(height: 18),
              _Panel(
                title: widget.results.isEmpty ? '开始搜索' : '搜索结果',
                subtitle: widget.results.isEmpty
                    ? widget.canManageLibrary
                          ? '输入歌名或歌手，从网络获取后保存到系统音乐库'
                          : '输入歌名或歌手，下载到你的个人音乐空间'
                    : widget.canManageLibrary
                    ? '选择单曲入库，或一次性保存全部可用歌曲'
                    : '选择单曲下载，歌曲只会保存到你的个人空间',
                child: Column(
                  children: [
                    if (widget.results.isNotEmpty)
                      _ResultActions(
                        total: widget.results.length,
                        downloadable: downloadableResults.length,
                        busy: widget.batchActive,
                        paused: widget.batchPaused,
                        completed: widget.batchCompleted,
                        batchTotal: widget.batchTotal,
                        success: widget.batchSuccess,
                        onBatchDownload: downloadableResults.isEmpty
                            ? null
                            : () => widget.onBatchDownload(downloadableResults),
                        onBatchPause: widget.onBatchPause,
                      ),
                    if (widget.errorMessage != null && widget.results.isEmpty)
                      _ErrorBanner(message: widget.errorMessage!),
                    if (widget.searching && widget.results.isEmpty)
                      ...List.generate(4, (_) => const _OnlineSongRowSkeleton())
                    else if (widget.results.isEmpty &&
                        widget.errorMessage == null)
                      const _EmptySearchState(),
                    for (final song in widget.results)
                      _OnlineSongRow(
                        song: song,
                        downloaded:
                            widget.downloadedOnlineIds.contains(song['id']) ||
                            (!widget.canManageLibrary &&
                                _isDownloadedSong(song)),
                        existing:
                            widget.canManageLibrary &&
                            _isExistingLibrarySong(song),
                        libraryAvailable:
                            !widget.canManageLibrary &&
                            _isExistingLibrarySong(song),
                        busy: widget.downloadingId == song['id'],
                        loading: widget.downloadingId == song['id'],
                        onDownload: () => widget.onDownload(song),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
        if (showFloatingError)
          Positioned(
            top: widget.isMobile ? 12 : 18,
            left: horizontalPadding,
            right: horizontalPadding,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: _ErrorBanner(
                  message: widget.errorMessage!,
                  floating: true,
                  onClose: widget.onClearError,
                ),
              ),
            ),
          ),
      ],
    );
  }

  bool _isAlreadyAvailable(Map<String, dynamic> song) {
    return widget.canManageLibrary
        ? _isExistingLibrarySong(song)
        : _isDownloadedSong(song);
  }

  bool _isExistingLibrarySong(Map<String, dynamic> song) {
    final title = _normalizeSongText(song['title'] as String? ?? '');
    final artist = _normalizeSongText(song['artist'] as String? ?? '');
    if (title.isEmpty) {
      return false;
    }
    return songs.any((item) {
      final localTitle = _normalizeSongText(item.title);
      final localArtist = _normalizeSongText(item.artist);
      return localTitle == title &&
          (artist.isEmpty ||
              localArtist == artist ||
              localArtist.contains(artist) ||
              artist.contains(localArtist));
    });
  }

  bool _isDownloadedSong(Map<String, dynamic> song) {
    final title = _normalizeSongText(song['title'] as String? ?? '');
    final artist = _normalizeSongText(song['artist'] as String? ?? '');
    if (title.isEmpty) {
      return false;
    }
    return downloads.any((task) {
      final localTitle = _normalizeSongText(task.song.title);
      final localArtist = _normalizeSongText(task.song.artist);
      return localTitle == title &&
          (artist.isEmpty ||
              localArtist == artist ||
              localArtist.contains(artist) ||
              artist.contains(localArtist));
    });
  }
}

String _normalizeSongText(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'g\.?e\.?m\.?', caseSensitive: false), '邓紫棋')
      .replaceAll(RegExp(r'[\s·\._\-—–()（）《》【】\[\]]+'), '')
      .trim();
}

class _DownloadHeader extends StatelessWidget {
  const _DownloadHeader({required this.downloadedCount});

  final int downloadedCount;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF8FC),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          '$downloadedCount 首已下载到本地',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: kAccentDark,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.controller,
    required this.busy,
    required this.loading,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool busy;
  final bool loading;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kLine),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .045),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF8FC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.search_rounded, color: kAccentDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: (_) => onSubmitted(),
              style: Theme.of(context).textTheme.titleMedium,
              decoration: const InputDecoration(
                hintText: '搜索歌名、歌手或专辑',
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 44,
            child: FilledButton.icon(
              onPressed: busy ? null : onSubmitted,
              style: FilledButton.styleFrom(
                backgroundColor: kAccentDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.travel_explore_rounded),
              label: Text(loading ? '搜索中' : '搜索'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultActions extends StatelessWidget {
  const _ResultActions({
    required this.total,
    required this.downloadable,
    required this.busy,
    required this.paused,
    required this.completed,
    required this.batchTotal,
    required this.success,
    required this.onBatchDownload,
    required this.onBatchPause,
  });

  final int total;
  final int downloadable;
  final bool busy;
  final bool paused;
  final int completed;
  final int batchTotal;
  final int success;
  final VoidCallback? onBatchDownload;
  final VoidCallback onBatchPause;

  @override
  Widget build(BuildContext context) {
    final progress = batchTotal == 0
        ? 0
        : busy && completed < batchTotal
        ? completed + 1
        : completed;
    final progressValue = batchTotal <= 0
        ? 0.0
        : (progress / batchTotal).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _ResultPill(icon: Icons.library_music_rounded, text: '$total 首结果'),
          _ResultPill(
            icon: Icons.cloud_done_rounded,
            text: '$downloadable 首可获取',
          ),
          _BatchProgressButton(
            busy: busy,
            paused: paused,
            progress: progress,
            total: batchTotal,
            value: progressValue,
            canResume: success > 0 && completed > 0 && completed < batchTotal,
            onPressed: busy ? onBatchPause : onBatchDownload,
          ),
        ],
      ),
    );
  }
}

class _BatchProgressButton extends StatelessWidget {
  const _BatchProgressButton({
    required this.busy,
    required this.paused,
    required this.progress,
    required this.total,
    required this.value,
    required this.canResume,
    required this.onPressed,
  });

  final bool busy;
  final bool paused;
  final int progress;
  final int total;
  final double value;
  final bool canResume;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final background = paused ? const Color(0xFF8AA6B4) : kAccentDark;
    final label = busy
        ? paused
              ? '暂停中 $progress/$total'
              : '暂停 $progress/$total'
        : canResume
        ? '继续获取 $progress/$total'
        : '批量获取';
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          constraints: const BoxConstraints(minHeight: 40),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    value: paused ? value : null,
                    strokeWidth: 2.4,
                    backgroundColor: Colors.white.withValues(alpha: .28),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.playlist_add_check_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultPill extends StatelessWidget {
  const _ResultPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7FA),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: kAccentDark),
          const SizedBox(width: 5),
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: kInk,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    this.floating = false,
    this.onClose,
  });

  final String message;
  final bool floating;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFE15B5B);
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: floating ? 0 : 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Color.lerp(Colors.white, color, .08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .18)),
        boxShadow: floating
            ? [
                BoxShadow(
                  color: color.withValues(alpha: .12),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: color,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: floating ? 2 : null,
              overflow: floating ? TextOverflow.ellipsis : null,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: kInk,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
          if (onClose != null) ...[
            const SizedBox(width: 8),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onClose,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, color: kMuted, size: 18),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 34),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFD),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kLine),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF8FC),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.manage_search_rounded,
              color: kAccentDark,
              size: 34,
            ),
          ),
          const SizedBox(height: 14),
          Text('搜索结果会显示在这里', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            '输入歌名或歌手后，选择想要的歌曲获取到音乐库',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _OnlineSongRowSkeleton extends StatefulWidget {
  const _OnlineSongRowSkeleton();

  @override
  State<_OnlineSongRowSkeleton> createState() => _OnlineSongRowSkeletonState();
}

class _OnlineSongRowSkeletonState extends State<_OnlineSongRowSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFFBFCFD),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kLine),
        ),
        child: Row(
          children: [
            _SkeletonBox(
              controller: _controller,
              width: 42,
              height: 42,
              radius: 14,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SkeletonBox(
                    controller: _controller,
                    width: 168,
                    height: 13,
                    radius: 6,
                  ),
                  const SizedBox(height: 8),
                  _SkeletonBox(
                    controller: _controller,
                    width: 112,
                    height: 11,
                    radius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _SkeletonBox(
              controller: _controller,
              width: 72,
              height: 36,
              radius: 12,
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.controller,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  final AnimationController controller;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: reduceMotion
            ? const ColoredBox(color: Color(0xFFEFF3F6))
            : AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  // Shimmer band is 2 widget-widths wide and travels from
                  // fully off-left (t=0, begin=-3,end=-1) to fully off-right
                  // (t=1, begin=+1,end=+3), so the loop boundary is invisible.
                  final t = controller.value;
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-3.0 + 4 * t, 0),
                        end: Alignment(-1.0 + 4 * t, 0),
                        colors: const [
                          Color(0xFFEFF3F6),
                          Color(0xFFF7FAFC),
                          Color(0xFFEFF3F6),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _OnlineSongRow extends StatelessWidget {
  const _OnlineSongRow({
    required this.song,
    required this.downloaded,
    required this.existing,
    required this.libraryAvailable,
    required this.busy,
    required this.loading,
    required this.onDownload,
  });

  final Map<String, dynamic> song;
  final bool downloaded;
  final bool existing;
  final bool libraryAvailable;
  final bool busy;
  final bool loading;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final title = song['title'] as String? ?? '';
    final artist = song['artist'] as String? ?? '';
    final actionIcon = downloaded
        ? Icons.check_rounded
        : libraryAvailable
        ? Icons.playlist_add_rounded
        : Icons.download_rounded;
    final actionLabel = downloaded
        ? '已下载'
        : libraryAvailable
        ? '加入'
        : '下载';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFFBFCFD),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kLine),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFEAF8FC), Color(0xFFCFEFF7)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.music_note_rounded,
                color: kAccentDark,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? '未知歌曲' : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          artist.isEmpty ? '未知歌手' : artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF8FC),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '网络资源',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: kAccentDark,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (existing)
              _DownloadStateBadge(
                label: '已在库',
                icon: Icons.check_circle_rounded,
                active: false,
              )
            else
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: downloaded || busy ? null : onDownload,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: downloaded ? const Color(0xFFEAF3F6) : kAccentDark,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: loading
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                actionIcon,
                                color: downloaded ? kMuted : Colors.white,
                                size: 17,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                actionLabel,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: downloaded ? kMuted : Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DownloadStateBadge extends StatelessWidget {
  const _DownloadStateBadge({
    required this.label,
    required this.icon,
    required this.active,
  });

  final String label;
  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: active ? kAccentDark : const Color(0xFFEAF3F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: active ? Colors.white : kMuted),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: active ? Colors.white : kMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
