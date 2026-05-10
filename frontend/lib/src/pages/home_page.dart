import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio_controller.dart';
import '../delayed_loading.dart';
import '../lyrics_utils.dart';
import '../library_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/artwork.dart';
import '../widgets/empty_state.dart';
import '../widgets/playback_mode_feedback.dart';
import '../widgets/song_tile.dart';
import '../widgets/sliding_tabs.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.isMobile,
    required this.canManageLibrary,
    this.initialSegment = 0,
    required this.currentSong,
    required this.isAudioLoading,
    required this.onSongTap,
    required this.onQueuePlayAll,
    required this.onSongPlayNext,
    required this.onSongAddToPlaylist,
    required this.onSongEdit,
    required this.onFavoriteToggle,
    required this.onSongDownload,
    required this.onSongsAddToPlaylist,
    required this.onSongsDownload,
    required this.onLocalImport,
    required this.onSongDelete,
    required this.onSongsDelete,
    required this.onSectionChanged,
    required this.positionStream,
    required this.playingListenable,
    required this.onTogglePlay,
    required this.onNext,
    required this.onPrevious,
    required this.playbackMode,
    required this.onPlaybackModeChanged,
    required this.hasMoreSongs,
    required this.isLoadingMoreSongs,
    required this.songTotalCount,
    required this.onLoadMoreSongs,
  });

  final bool isMobile;
  final bool canManageLibrary;
  final int initialSegment;
  final Song? currentSong;
  final bool isAudioLoading;
  final SongTapCallback onSongTap;
  final Future<void> Function(List<Song> queue) onQueuePlayAll;
  final ValueChanged<Song> onSongPlayNext;
  final ValueChanged<Song> onSongAddToPlaylist;
  final ValueChanged<Song> onSongEdit;
  final Future<Song> Function(Song song) onFavoriteToggle;
  final Future<void> Function(Song song) onSongDownload;
  final Future<void> Function(List<Song> songs) onSongsAddToPlaylist;
  final Future<void> Function(List<Song> songs) onSongsDownload;
  final Future<int> Function(List<String> paths) onLocalImport;
  final Future<void> Function(Song song) onSongDelete;
  final Future<void> Function(List<Song> songs) onSongsDelete;
  final ValueChanged<MusicSection> onSectionChanged;
  final Stream<Duration> positionStream;
  final ValueListenable<bool> playingListenable;
  final VoidCallback onTogglePlay;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final PlaybackMode playbackMode;
  final VoidCallback onPlaybackModeChanged;
  final bool hasMoreSongs;
  final bool isLoadingMoreSongs;
  final int songTotalCount;
  final Future<void> Function() onLoadMoreSongs;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const int _recentAddedLimit = 20;

  late int selectedSegment = widget.initialSegment;
  final TextEditingController searchController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final Set<int> selectedSongIds = {};
  bool selectionMode = false;
  String searchQuery = '';

  @override
  void dispose() {
    scrollController.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    if (!scrollController.hasClients ||
        selectedSegment != 0 ||
        searchQuery.trim().isNotEmpty ||
        !widget.hasMoreSongs ||
        widget.isLoadingMoreSongs) {
      return;
    }
    final position = scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 420) {
      widget.onLoadMoreSongs();
    }
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSegment != widget.initialSegment) {
      selectedSegment = widget.initialSegment;
      selectedSongIds.clear();
      selectionMode = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleSongs = _visibleSongs;
    final playbackQueue = _playbackQueueForVisibleSongs(visibleSongs);
    final selectedVisibleSongs = _selectedSongs(visibleSongs);
    final allVisibleSelected =
        visibleSongs.isNotEmpty &&
        selectedVisibleSongs.length == visibleSongs.length;
    final tabCounts = _tabCounts;
    final hotSongRanks = _hotSongRanks;
    Future<void> playAllVisible() => widget.onQueuePlayAll(playbackQueue);
    if (widget.isMobile) {
      return ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        children: [
          if (widget.currentSong != null)
            _NowPlayingCard(
              song: widget.currentSong!,
              compact: true,
              isLoading: widget.isAudioLoading,
              positionStream: widget.positionStream,
              playingListenable: widget.playingListenable,
              onFavoriteToggle: widget.onFavoriteToggle,
              onSongTap: widget.onSongTap,
              onTogglePlay: widget.onTogglePlay,
              onNext: widget.onNext,
              onPrevious: widget.onPrevious,
              playbackMode: widget.playbackMode,
              onPlaybackModeChanged: widget.onPlaybackModeChanged,
            ),
          const SizedBox(height: 10),
          SlidingTabs(
            labels: const ['全部', '收藏', '下载'],
            counts: tabCounts.take(3).toList(),
            selectedIndex: selectedSegment.clamp(0, 2),
            onSelected: _selectSegment,
            maxWidth: double.infinity,
            compact: true,
          ),
          const SizedBox(height: 8),
          _MusicSearchField(
            controller: searchController,
            query: searchQuery,
            onChanged: _updateSearchQuery,
            onClear: _clearSearchQuery,
            compact: true,
          ),
          const SizedBox(height: 6),
          _HomeQuickActions(
            compact: true,
            selectionMode: selectionMode,
            showSelection: visibleSongs.isNotEmpty,
            canImport: widget.canManageLibrary,
            onImport: _openLocalImportDialog,
            onSelect: _startSelectionMode,
          ),
          const SizedBox(height: 4),
          if (visibleSongs.isNotEmpty) ...[
            _CollapsibleBatchActions(
              visible: selectionMode,
              bottomSpacing: 8,
              child: _BatchActionBar(
                active: true,
                selectedCount: selectedVisibleSongs.length,
                totalCount: visibleSongs.length,
                allSelected: allVisibleSelected,
                canDelete: widget.canManageLibrary,
                onStart: _startSelectionMode,
                onSelectAll: () => _toggleSelectAllVisible(visibleSongs),
                onClear: _clearSelection,
                onAddToPlaylist: () => _runBatchAction(
                  selectedVisibleSongs,
                  widget.onSongsAddToPlaylist,
                ),
                onDownload: () => _runBatchAction(
                  selectedVisibleSongs,
                  widget.onSongsDownload,
                ),
                onDelete: () =>
                    _runBatchAction(selectedVisibleSongs, widget.onSongsDelete),
              ),
            ),
          ],
          if (visibleSongs.isEmpty)
            EmptyState(
              icon: Icons.storage_rounded,
              message: _emptyMessage,
              margin: const EdgeInsets.symmetric(vertical: 18),
            ),
          ...visibleSongs.map(
            (song) => SongTile(
              key: ValueKey(song.id),
              song: song,
              compact: true,
              showAlbum: false,
              selectionMode: selectionMode,
              selected: selectedSongIds.contains(song.id),
              downloaded: _isDownloaded(song),
              showShadow: !selectionMode,
              hotRank: hotSongRanks[song.id],
              onTap: () => widget.onSongTap(song, queue: playbackQueue),
              onLongPress: () => _startSelection(song),
              onSelectionToggle: () => _toggleSelection(song),
              onPlayAllTap: visibleSongs.length > 1
                  ? () => playAllVisible()
                  : null,
              onPlayNextTap: () => widget.onSongPlayNext(song),
              onAddToPlaylistTap: () => widget.onSongAddToPlaylist(song),
              onEditTap: widget.canManageLibrary
                  ? () => widget.onSongEdit(song)
                  : null,
              onFavoriteTap: () => widget.onFavoriteToggle(song),
              onDownloadTap: () => widget.onSongDownload(song),
              onDeleteTap: widget.canManageLibrary
                  ? () => widget.onSongDelete(song)
                  : null,
            ),
          ),
          if (_shouldShowLoadMore) const _SongLoadMoreIndicator(),
          const SizedBox(height: 12),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasSidePanel = widget.currentSong != null;
        final sidePanelWidth = hasSidePanel
            ? (constraints.maxWidth * .28).clamp(260.0, 360.0).toDouble()
            : 0.0;
        return Row(
          children: [
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 360;
                        final tabs = SlidingTabs(
                          labels: const ['全部歌曲', '收藏', '下载', '最近添加'],
                          counts: tabCounts,
                          selectedIndex: selectedSegment,
                          onSelected: _selectSegment,
                          maxWidth: double.infinity,
                          compact: true,
                        );
                        final searchField = _MusicSearchField(
                          controller: searchController,
                          query: searchQuery,
                          onChanged: _updateSearchQuery,
                          onClear: _clearSearchQuery,
                          compact: true,
                        );
                        if (compact) {
                          final actions = _HomeQuickActions(
                            selectionMode: selectionMode,
                            showSelection: visibleSongs.isNotEmpty,
                            canImport: widget.canManageLibrary,
                            onImport: _openLocalImportDialog,
                            onSelect: _startSelectionMode,
                          );
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              tabs,
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(child: searchField),
                                  const SizedBox(width: 16),
                                  actions,
                                ],
                              ),
                            ],
                          );
                        }
                        final actions = _HomeQuickActions(
                          selectionMode: selectionMode,
                          showSelection: visibleSongs.isNotEmpty,
                          canImport: widget.canManageLibrary,
                          onImport: _openLocalImportDialog,
                          onSelect: _startSelectionMode,
                        );
                        return Column(
                          children: [
                            tabs,
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 350,
                                      ),
                                      child: searchField,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                actions,
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    if (visibleSongs.isNotEmpty) ...[
                      _CollapsibleBatchActions(
                        visible: selectionMode,
                        bottomSpacing: 10,
                        child: _BatchActionBar(
                          active: true,
                          selectedCount: selectedVisibleSongs.length,
                          totalCount: visibleSongs.length,
                          allSelected: allVisibleSelected,
                          canDelete: widget.canManageLibrary,
                          onStart: _startSelectionMode,
                          onSelectAll: () =>
                              _toggleSelectAllVisible(visibleSongs),
                          onClear: _clearSelection,
                          onAddToPlaylist: () => _runBatchAction(
                            selectedVisibleSongs,
                            widget.onSongsAddToPlaylist,
                          ),
                          onDownload: () => _runBatchAction(
                            selectedVisibleSongs,
                            widget.onSongsDownload,
                          ),
                          onDelete: () => _runBatchAction(
                            selectedVisibleSongs,
                            widget.onSongsDelete,
                          ),
                        ),
                      ),
                    ],
                    Expanded(
                      child: CustomScrollView(
                        controller: scrollController,
                        slivers: [
                          if (visibleSongs.isEmpty)
                            SliverToBoxAdapter(
                              child: EmptyState(
                                icon: Icons.storage_rounded,
                                message: _emptyMessage,
                                margin: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                              ),
                            )
                          else
                            SliverList.builder(
                              itemCount: visibleSongs.length,
                              itemBuilder: (context, i) {
                                final song = visibleSongs[i];
                                return SongTile(
                                  key: ValueKey(song.id),
                                  song: song,
                                  index: i + 1,
                                  selectionMode: selectionMode,
                                  selected: selectedSongIds.contains(song.id),
                                  showShadow: !selectionMode,
                                  hotRank: hotSongRanks[song.id],
                                  onTap: () => widget.onSongTap(
                                    song,
                                    queue: playbackQueue,
                                  ),
                                  onLongPress: () => _startSelection(song),
                                  onSelectionToggle: () =>
                                      _toggleSelection(song),
                                  onPlayAllTap: visibleSongs.length > 1
                                      ? () => playAllVisible()
                                      : null,
                                  onPlayNextTap: () =>
                                      widget.onSongPlayNext(song),
                                  onAddToPlaylistTap: () =>
                                      widget.onSongAddToPlaylist(song),
                                  onEditTap: widget.canManageLibrary
                                      ? () => widget.onSongEdit(song)
                                      : null,
                                  downloaded: _isDownloaded(song),
                                  onFavoriteTap: () =>
                                      widget.onFavoriteToggle(song),
                                  onDownloadTap: () =>
                                      widget.onSongDownload(song),
                                  onDeleteTap: widget.canManageLibrary
                                      ? () => widget.onSongDelete(song)
                                      : null,
                                );
                              },
                            ),
                          if (_shouldShowLoadMore)
                            const SliverToBoxAdapter(
                              child: _SongLoadMoreIndicator(),
                            ),
                          const SliverToBoxAdapter(child: SizedBox(height: 16)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(width: 1, color: kLine),
            if (hasSidePanel)
              SizedBox(
                width: sidePanelWidth,
                child: LayoutBuilder(
                  builder: (context, sideConstraints) {
                    final compactSide = sideConstraints.maxHeight < 650;
                    final horizontalPadding = sidePanelWidth >= 320
                        ? 22.0
                        : 18.0;
                    final cardWidth = (sidePanelWidth - horizontalPadding * 2)
                        .clamp(224.0, 292.0)
                        .toDouble();
                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        compactSide ? 16 : 22,
                        horizontalPadding,
                        compactSide ? 12 : 14,
                      ),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.topCenter,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.topCenter,
                              child: SizedBox(
                                width: cardWidth,
                                child: _NowPlayingCard(
                                  song: widget.currentSong!,
                                  isLoading: widget.isAudioLoading,
                                  positionStream: widget.positionStream,
                                  playingListenable: widget.playingListenable,
                                  onFavoriteToggle: widget.onFavoriteToggle,
                                  onSongTap: widget.onSongTap,
                                  onTogglePlay: widget.onTogglePlay,
                                  onNext: widget.onNext,
                                  onPrevious: widget.onPrevious,
                                  playbackMode: widget.playbackMode,
                                  onPlaybackModeChanged:
                                      widget.onPlaybackModeChanged,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: compactSide ? 12 : 18),
                          Expanded(
                            child: _RightSideLyrics(
                              song: widget.currentSong!,
                              positionStream: widget.positionStream,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  void _selectSegment(int index) {
    setState(() => selectedSegment = index);
  }

  void _updateSearchQuery(String value) {
    setState(() => searchQuery = value.trim());
  }

  void _clearSearchQuery() {
    searchController.clear();
    setState(() => searchQuery = '');
  }

  void _startSelectionMode() {
    setState(() {
      selectionMode = true;
    });
  }

  void _startSelection(Song song) {
    setState(() {
      selectionMode = true;
      selectedSongIds.add(song.id);
    });
  }

  void _toggleSelection(Song song) {
    setState(() {
      if (!selectedSongIds.remove(song.id)) {
        selectedSongIds.add(song.id);
      }
    });
  }

  void _toggleSelectAllVisible(List<Song> visibleSongs) {
    setState(() {
      selectionMode = true;
      final visibleIds = visibleSongs.map((song) => song.id).toSet();
      final allSelected =
          visibleIds.isNotEmpty && visibleIds.every(selectedSongIds.contains);
      if (allSelected) {
        selectedSongIds.removeAll(visibleIds);
      } else {
        selectedSongIds.addAll(visibleIds);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      selectedSongIds.clear();
      selectionMode = false;
    });
  }

  List<Song> _selectedSongs(List<Song> visibleSongs) {
    return visibleSongs
        .where((song) => selectedSongIds.contains(song.id))
        .toList();
  }

  Future<void> _runBatchAction(
    List<Song> selectedSongs,
    Future<void> Function(List<Song> songs) action,
  ) async {
    if (selectedSongs.isEmpty) {
      return;
    }
    await action(selectedSongs);
    if (mounted) {
      _clearSelection();
    }
  }

  Future<void> _openLocalImportDialog() async {
    await showDialog<int>(
      context: context,
      builder: (context) => _LocalImportDialog(onImport: widget.onLocalImport),
    );
  }

  List<Song> get _visibleSongs {
    final baseSongs = _segmentSongs;
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return baseSongs;
    }
    return baseSongs.where((song) => _matchesSearch(song, query)).toList();
  }

  List<Song> _playbackQueueForVisibleSongs(List<Song> visibleSongs) {
    if (searchQuery.trim().isEmpty) {
      return visibleSongs;
    }
    return _segmentSongs;
  }

  List<Song> get _segmentSongs {
    if (selectedSegment == 1) {
      return songs.where((song) => song.isFavorite).toList();
    }
    if (selectedSegment == 2) {
      return downloads
          .map((task) => task.song)
          .where((song) => song.id != 0)
          .toList();
    }
    if (selectedSegment == 3) {
      return _recentAddedSongs;
    }
    return songs;
  }

  List<Song> get _recentAddedSongs {
    final recent = List<Song>.of(songs)..sort((a, b) => b.id.compareTo(a.id));
    return recent.take(_recentAddedLimit).toList();
  }

  Map<int, int> get _hotSongRanks {
    final ranked = songs.where((song) => song.playCount > 0).toList()
      ..sort((a, b) {
        final byPlayCount = b.playCount.compareTo(a.playCount);
        if (byPlayCount != 0) {
          return byPlayCount;
        }
        return b.id.compareTo(a.id);
      });
    return {
      for (var i = 0; i < ranked.length && i < 3; i++) ranked[i].id: i + 1,
    };
  }

  List<int?> get _tabCounts => [
    widget.songTotalCount > 0 ? widget.songTotalCount : songs.length,
    songs.where((song) => song.isFavorite).length,
    downloads.where((task) => task.song.id != 0).length,
    _recentAddedSongs.length,
  ];

  bool get _shouldShowLoadMore =>
      selectedSegment == 0 &&
      searchQuery.trim().isEmpty &&
      (widget.hasMoreSongs || widget.isLoadingMoreSongs);

  bool _matchesSearch(Song song, String query) {
    return song.title.toLowerCase().contains(query) ||
        song.artist.toLowerCase().contains(query) ||
        song.album.toLowerCase().contains(query);
  }

  String get _emptyMessage {
    if (searchQuery.isNotEmpty) {
      return '没有找到匹配“$searchQuery”的歌曲';
    }
    if (selectedSegment == 1) {
      return '暂无收藏歌曲';
    }
    if (selectedSegment == 2) {
      return '暂无下载歌曲';
    }
    return '暂无歌曲，请先在 MySQL 中添加真实音乐数据';
  }

  bool _isDownloaded(Song song) {
    return downloads.any((task) => task.song.id == song.id);
  }
}

class _HomeQuickActions extends StatelessWidget {
  const _HomeQuickActions({
    required this.selectionMode,
    required this.showSelection,
    required this.canImport,
    required this.onImport,
    required this.onSelect,
    this.compact = false,
  });

  final bool selectionMode;
  final bool showSelection;
  final bool canImport;
  final VoidCallback onImport;
  final VoidCallback onSelect;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final children = [
      if (canImport)
        _HomeActionButton(
          icon: Icons.folder_open_rounded,
          label: '导入本地',
          onTap: onImport,
          primary: true,
        ),
      if (showSelection)
        _HomeActionButton(
          icon: selectionMode
              ? Icons.check_circle_rounded
              : Icons.checklist_rounded,
          label: selectionMode ? '选择中' : '多选',
          onTap: onSelect,
          selected: selectionMode,
        ),
    ];
    if (compact) {
      return Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: children[i]),
          ],
        ],
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

class _SongLoadMoreIndicator extends StatelessWidget {
  const _SongLoadMoreIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }
}

class _HomeActionButton extends StatefulWidget {
  const _HomeActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool selected;

  @override
  State<_HomeActionButton> createState() => _HomeActionButtonState();
}

class _HomeActionButtonState extends State<_HomeActionButton> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    final foreground = widget.primary
        ? Colors.white
        : widget.selected
        ? kAccentDark
        : kMuted;
    final background = widget.primary
        ? kAccentDark
        : widget.selected
        ? const Color(0xFFE8F8FC)
        : const Color(0xFFF6FAFC);
    final borderColor = widget.primary
        ? kAccentDark
        : widget.selected
        ? kAccent.withValues(alpha: .34)
        : kLine;
    return MouseRegion(
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        scale: hovering ? .985 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 36,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
            boxShadow: widget.primary
                ? [
                    BoxShadow(
                      color: kAccentDark.withValues(alpha: hovering ? .16 : .1),
                      blurRadius: hovering ? 12 : 8,
                      offset: Offset(0, hovering ? 4 : 2),
                    ),
                  ]
                : const [],
          ),
          child: TextButton.icon(
            onPressed: widget.onTap,
            style: TextButton.styleFrom(
              foregroundColor: foreground,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            icon: Icon(widget.icon, size: 16),
            label: Text(
              widget.label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ),
    );
  }
}

class _CollapsibleBatchActions extends StatelessWidget {
  const _CollapsibleBatchActions({
    required this.visible,
    required this.child,
    this.bottomSpacing = 0,
  });

  final bool visible;
  final Widget child;
  final double bottomSpacing;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: ClipRect(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -.12),
                  end: Offset.zero,
                ).animate(curved),
                child: SizeTransition(
                  sizeFactor: curved,
                  axisAlignment: -1,
                  child: child,
                ),
              ),
            );
          },
          child: visible
              ? Padding(
                  key: const ValueKey('batch-actions-expanded'),
                  padding: EdgeInsets.only(bottom: bottomSpacing),
                  child: child,
                )
              : const SizedBox.shrink(key: ValueKey('batch-actions-collapsed')),
        ),
      ),
    );
  }
}

class _MusicSearchField extends StatelessWidget {
  const _MusicSearchField({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
    this.compact = false,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontSize: compact ? 13 : 14,
      fontWeight: FontWeight.w800,
      height: 1,
    );
    return Container(
      height: compact ? 36 : 44,
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFC),
        borderRadius: BorderRadius.circular(compact ? 14 : 19),
        border: Border.all(color: kLine.withValues(alpha: .72)),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: kMuted, size: compact ? 16 : 22),
          SizedBox(width: compact ? 8 : 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: textStyle,
              decoration: InputDecoration.collapsed(
                hintText: compact ? '搜索音乐' : '搜索歌曲、歌手',
                hintStyle: textStyle?.copyWith(color: kMuted),
              ),
              cursorColor: kAccentDark,
              cursorHeight: compact ? 16 : 18,
            ),
          ),
          if (query.isNotEmpty)
            IconButton(
              tooltip: '清空搜索',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints.tightFor(
                width: compact ? 24 : 28,
                height: compact ? 24 : 28,
              ),
              onPressed: onClear,
              icon: Icon(
                Icons.close_rounded,
                color: kMuted,
                size: compact ? 16 : 20,
              ),
            ),
        ],
      ),
    );
  }
}

class _BatchActionBar extends StatelessWidget {
  const _BatchActionBar({
    required this.active,
    required this.selectedCount,
    required this.totalCount,
    required this.allSelected,
    required this.canDelete,
    required this.onStart,
    required this.onSelectAll,
    required this.onClear,
    required this.onAddToPlaylist,
    required this.onDownload,
    required this.onDelete,
  });

  final bool active;
  final int selectedCount;
  final int totalCount;
  final bool allSelected;
  final bool canDelete;
  final VoidCallback onStart;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final VoidCallback onAddToPlaylist;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final enabled = selectedCount > 0;
    final textTheme = Theme.of(context).textTheme;
    if (!active) {
      return Align(
        alignment: Alignment.centerRight,
        child: _BatchButton(
          icon: Icons.checklist_rounded,
          label: '多选',
          onTap: onStart,
          quiet: true,
        ),
      );
    }
    final actionButtons = [
      _BatchButton(
        icon: allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
        label: allSelected ? '全不选' : '全选',
        onTap: onSelectAll,
      ),
      if (enabled) ...[
        _BatchButton(
          icon: Icons.playlist_add_rounded,
          label: '加歌单',
          onTap: onAddToPlaylist,
        ),
        _BatchButton(
          icon: Icons.download_rounded,
          label: '下载',
          onTap: onDownload,
        ),
        if (canDelete)
          _BatchButton(
            icon: Icons.delete_outline_rounded,
            label: '删除',
            destructive: true,
            onTap: onDelete,
          ),
      ],
      _BatchButton(
        icon: Icons.close_rounded,
        label: '退出',
        quiet: true,
        onTap: onClear,
      ),
    ];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: 46,
      padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kAccent.withValues(alpha: .18)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B1D2A).withValues(alpha: .045),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: selectedCount == 0 ? const Color(0xFFF3FAFC) : kAccent,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: kAccent.withValues(alpha: .18)),
            ),
            child: Icon(
              selectedCount == 0
                  ? Icons.checklist_rounded
                  : Icons.check_rounded,
              color: selectedCount == 0 ? kAccentDark : Colors.white,
              size: 17,
            ),
          ),
          const SizedBox(width: 9),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '已选 ',
                  style: textTheme.labelMedium?.copyWith(
                    color: kMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: '$selectedCount',
                  style: textTheme.titleSmall?.copyWith(
                    color: selectedCount == 0 ? kMuted : kAccentDark,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextSpan(
                  text: ' / $totalCount',
                  style: textTheme.labelMedium?.copyWith(
                    color: kMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            maxLines: 1,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                children: [
                  for (var i = 0; i < actionButtons.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    actionButtons[i],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BatchButton extends StatelessWidget {
  const _BatchButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.quiet = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? const Color(0xFFE15B5B)
        : quiet
        ? kMuted
        : kAccentDark;
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: color,
        disabledForegroundColor: kMuted.withValues(alpha: .55),
        backgroundColor: quiet
            ? Colors.transparent
            : color.withValues(alpha: destructive ? .08 : .07),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        minimumSize: const Size(0, 30),
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      icon: Icon(icon, size: 15),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class _LocalImportDialog extends StatefulWidget {
  const _LocalImportDialog({required this.onImport});

  final Future<int> Function(List<String> paths) onImport;

  @override
  State<_LocalImportDialog> createState() => _LocalImportDialogState();
}

class _LocalImportDialogState extends State<_LocalImportDialog> {
  final List<String> selectedPaths = [];
  final DelayedLoadingController importLoading = DelayedLoadingController();
  bool picking = false;
  String? errorMessage;

  bool get importing => importLoading.active;

  @override
  void initState() {
    super.initState();
    importLoading.addListener(_handleImportLoadingChanged);
  }

  @override
  void dispose() {
    importLoading
      ..removeListener(_handleImportLoadingChanged)
      ..dispose();
    super.dispose();
  }

  void _handleImportLoadingChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('导入本地音乐'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '选择本机音乐和歌词文件，或选择一个音乐文件夹批量导入。支持 mp3、flac、m4a、aac、wav、ogg、lrc。',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: kMuted, height: 1.45),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _ImportPickerButton(
                    icon: Icons.audio_file_rounded,
                    title: '选择文件',
                    subtitle: '可多选音频和歌词',
                    enabled: !picking && !importing,
                    onTap: _pickFiles,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ImportPickerButton(
                    icon: Icons.folder_rounded,
                    title: '选择文件夹',
                    subtitle: '递归扫描整个目录',
                    enabled: !picking && !importing,
                    onTap: _pickDirectory,
                  ),
                ),
              ],
            ),
            if (picking) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '正在打开系统选择器…',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: kMuted),
                  ),
                ],
              ),
            ],
            if (selectedPaths.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    '待导入 ${selectedPaths.length} 项',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: kInk,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: importing ? null : _clearSelectedPaths,
                    child: const Text('清空'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: (selectedPaths.length * 48.0)
                    .clamp(48.0, 168.0)
                    .toDouble(),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F8F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kLine),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: selectedPaths.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: kLine),
                    itemBuilder: (context, index) {
                      final path = selectedPaths[index];
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          _iconForPath(path),
                          color: kAccentDark,
                          size: 20,
                        ),
                        title: Text(
                          _displayName(path),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        trailing: IconButton(
                          tooltip: '移除',
                          onPressed: importing
                              ? null
                              : () => _removeSelectedPath(path),
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            if (errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                errorMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFE15B5B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: importing ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: importing || picking || selectedPaths.isEmpty
              ? null
              : _submitSelectedPaths,
          icon: importLoading.visible
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.library_add_check_rounded),
          label: Text(importLoading.visible ? '导入中' : '确认导入'),
        ),
      ],
    );
  }

  Future<void> _pickFiles() async {
    _startPicking();
    try {
      final paths = Platform.isMacOS
          ? await _pickMacFiles()
          : await _pickPluginFiles();
      _addSelectedPaths(paths);
    } catch (error) {
      _showPickerError(error);
    } finally {
      _finishPicking();
    }
  }

  Future<void> _pickDirectory() async {
    _startPicking();
    try {
      final directory = Platform.isMacOS
          ? await _pickMacDirectory()
          : await getDirectoryPath();
      _addSelectedPaths(directory == null ? const [] : [directory]);
    } catch (error) {
      _showPickerError(error);
    } finally {
      _finishPicking();
    }
  }

  Future<List<String>> _pickPluginFiles() async {
    const audioGroup = XTypeGroup(
      label: 'Audio',
      extensions: ['mp3', 'flac', 'm4a', 'aac', 'wav', 'ogg', 'lrc'],
    );
    final files = await openFiles(acceptedTypeGroups: const [audioGroup]);
    return files.map((file) => file.path).whereType<String>().toList();
  }

  Future<List<String>> _pickMacFiles() async {
    final result = await Process.run('osascript', [
      '-e',
      'set selectedFiles to choose file of type {"mp3", "flac", "m4a", "aac", "wav", "ogg", "lrc"} with multiple selections allowed',
      '-e',
      'set output to ""',
      '-e',
      'repeat with selectedFile in selectedFiles',
      '-e',
      'set output to output & POSIX path of selectedFile & linefeed',
      '-e',
      'end repeat',
      '-e',
      'return output',
    ]);
    return _parseAppleScriptPaths(result);
  }

  Future<String?> _pickMacDirectory() async {
    final result = await Process.run('osascript', [
      '-e',
      'POSIX path of (choose folder)',
    ]);
    final paths = _parseAppleScriptPaths(result);
    return paths.isEmpty ? null : paths.first;
  }

  List<String> _parseAppleScriptPaths(ProcessResult result) {
    if (result.exitCode != 0) {
      return const [];
    }
    return result.stdout
        .toString()
        .split('\n')
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty)
        .toList();
  }

  void _addSelectedPaths(List<String> paths) {
    final nextPaths = paths
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty)
        .where((path) => !selectedPaths.contains(path))
        .toList();
    if (nextPaths.isEmpty) {
      return;
    }
    setState(() {
      selectedPaths.addAll(nextPaths);
      errorMessage = null;
    });
  }

  void _removeSelectedPath(String path) {
    setState(() {
      selectedPaths.remove(path);
    });
  }

  void _clearSelectedPaths() {
    setState(selectedPaths.clear);
  }

  IconData _iconForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.lrc')) {
      return Icons.subtitles_rounded;
    }
    if (_extension(path).isEmpty) {
      return Icons.folder_rounded;
    }
    return Icons.audio_file_rounded;
  }

  String _displayName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/').where((part) => part.isNotEmpty);
    return parts.isEmpty ? path : parts.last;
  }

  String _extension(String path) {
    final name = _displayName(path);
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == name.length - 1) {
      return '';
    }
    return name.substring(dotIndex + 1);
  }

  void _startPicking() {
    setState(() {
      picking = true;
      errorMessage = null;
    });
  }

  void _finishPicking() {
    if (!mounted) {
      return;
    }
    setState(() {
      picking = false;
    });
  }

  void _showPickerError(Object error) {
    if (!mounted) {
      return;
    }
    final detail = error is PlatformException
        ? error.message ?? error.code
        : error.toString();
    setState(() {
      errorMessage =
          '系统选择器打开失败：$detail。请完全退出应用后执行 flutter clean，再重新运行 make dev。';
    });
  }

  Future<void> _submit(List<String> paths) async {
    if (paths.isEmpty) {
      setState(() => errorMessage = '未选择任何文件或文件夹');
      return;
    }
    importLoading.start();
    setState(() => errorMessage = null);
    try {
      final count = await widget.onImport(paths);
      if (mounted) {
        Navigator.of(context).pop(count);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      importLoading.stop();
    }
  }

  Future<void> _submitSelectedPaths() => _submit(selectedPaths);
}

class _ImportPickerButton extends StatelessWidget {
  const _ImportPickerButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: enabled ? onTap : null,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F8F9),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: enabled ? kAccentDark : kMuted, size: 28),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: kMuted, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _NowPlayingCard extends StatefulWidget {
  const _NowPlayingCard({
    required this.song,
    required this.isLoading,
    required this.positionStream,
    required this.playingListenable,
    required this.onFavoriteToggle,
    required this.onSongTap,
    required this.onTogglePlay,
    required this.onNext,
    required this.onPrevious,
    required this.playbackMode,
    required this.onPlaybackModeChanged,
    this.compact = false,
  });

  final Song song;
  final bool isLoading;
  final Stream<Duration> positionStream;
  final ValueListenable<bool> playingListenable;
  final Future<Song> Function(Song song) onFavoriteToggle;
  final SongTapCallback onSongTap;
  final VoidCallback onTogglePlay;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final PlaybackMode playbackMode;
  final VoidCallback onPlaybackModeChanged;
  final bool compact;

  @override
  State<_NowPlayingCard> createState() => _NowPlayingCardState();
}

class _NowPlayingCardState extends State<_NowPlayingCard> {
  @override
  Widget build(BuildContext context) {
    final song = widget.song;
    final compact = widget.compact;
    if (compact) {
      return InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => widget.onSongTap(song),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: cardDecoration(radius: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Artwork(song: song, size: 78, radius: 12),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('继续播放', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 3),
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
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: .32,
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: widget.isLoading ? null : widget.onTogglePlay,
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: widget.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : ValueListenableBuilder<bool>(
                          valueListenable: widget.playingListenable,
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
              ),
            ],
          ),
        ),
      );
    }

    final coverColor = song.colors.isEmpty ? kAccent : song.colors.last;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(coverColor, Colors.white, .85)!,
            const Color(0xFFF7FAFC),
          ],
        ),
        border: Border.all(color: kLine),
        boxShadow: [
          BoxShadow(
            color: coverColor.withValues(alpha: .12),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: kAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '正在播放',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: .5,
                ),
              ),
              const Spacer(),
              _MiniIconButton(
                icon: song.isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: kAccent,
                onTap: () => widget.onFavoriteToggle(song),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: coverColor.withValues(alpha: .35),
                    blurRadius: 22,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Artwork(song: song, size: 110, radius: 18),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            song.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 14),
          StreamBuilder<Duration>(
            stream: widget.positionStream,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              final total = song.duration.inMilliseconds <= 0
                  ? const Duration(seconds: 1)
                  : song.duration;
              final progress = (position.inMilliseconds / total.inMilliseconds)
                  .clamp(0.0, 1.0);
              return Column(
                children: [
                  SizedBox(
                    height: 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: kAccent.withValues(alpha: .15),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          kAccent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        formatDuration(position),
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const Spacer(),
                      Text(
                        formatDuration(song.duration),
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          _CompactControls(
            playingListenable: widget.playingListenable,
            isLoading: widget.isLoading,
            onPlay: widget.onTogglePlay,
            onPrevious: widget.onPrevious,
            onNext: widget.onNext,
            playbackMode: widget.playbackMode,
            onPlaybackModeChanged: widget.onPlaybackModeChanged,
          ),
        ],
      ),
    );
  }
}

class _RightSideLyrics extends StatelessWidget {
  const _RightSideLyrics({required this.song, required this.positionStream});

  final Song song;
  final Stream<Duration> positionStream;

  @override
  Widget build(BuildContext context) {
    final timedLines = parseTimedLyricLines(song.lyrics);
    final plainLines = parseLyricLines(song.lyrics);
    final fallbackLines = plainLines.isEmpty
        ? const ['暂无歌词信息', '播放含歌词的歌曲后', '这里会同步展示']
        : plainLines;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '歌词',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: kInk,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: timedLines.isEmpty
                    ? _StaticRightLyrics(lines: fallbackLines)
                    : StreamBuilder<Duration>(
                        stream: positionStream,
                        builder: (context, snapshot) {
                          final position = snapshot.data ?? Duration.zero;
                          var activeIndex = currentLyricIndex(
                            timedLines,
                            position,
                          );
                          if (activeIndex < 0) {
                            activeIndex = 0;
                          }
                          return _AnimatedRightLyricList(
                            key: ValueKey('lyrics-${song.id}'),
                            lines: timedLines,
                            activeIndex: activeIndex,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnimatedRightLyricList extends StatefulWidget {
  const _AnimatedRightLyricList({
    super.key,
    required this.lines,
    required this.activeIndex,
  });

  final List<TimedLyricLine> lines;
  final int activeIndex;

  @override
  State<_AnimatedRightLyricList> createState() =>
      _AnimatedRightLyricListState();
}

class _AnimatedRightLyricListState extends State<_AnimatedRightLyricList> {
  static const double _lineExtent = 28;

  final _controller = ScrollController();
  int _lastActiveIndex = -1;
  double _verticalPadding = 0;
  double _viewportHeight = 0;

  @override
  void initState() {
    super.initState();
    _lastActiveIndex = widget.activeIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
  }

  @override
  void didUpdateWidget(covariant _AnimatedRightLyricList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lines != widget.lines) {
      _lastActiveIndex = -1;
      if (_controller.hasClients) {
        _controller.jumpTo(0);
      }
    }
    if (_lastActiveIndex != widget.activeIndex) {
      _lastActiveIndex = widget.activeIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scrollToActive() {
    if (!mounted || !_controller.hasClients) {
      return;
    }
    final position = _controller.position;
    if (!position.hasContentDimensions) {
      return;
    }
    final activeCenter =
        _verticalPadding + widget.activeIndex * _lineExtent + _lineExtent / 2;
    final target = (activeCenter - _viewportHeight * .24).clamp(
      0.0,
      position.maxScrollExtent,
    );
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final lines = widget.lines;
        final activeIndex = widget.activeIndex;
        final fillViewport =
            lines.length > 1 &&
            constraints.maxHeight.isFinite &&
            lines.length * _lineExtent <= constraints.maxHeight;
        if (!fillViewport) {
          _viewportHeight = constraints.maxHeight;
          final verticalPadding = (constraints.maxHeight * .1).clamp(8.0, 28.0);
          _verticalPadding = verticalPadding;
          return ClipRect(
            child: ListView.builder(
              controller: _controller,
              padding: EdgeInsets.symmetric(vertical: verticalPadding),
              itemExtent: _lineExtent,
              itemCount: lines.length,
              itemBuilder: (context, index) {
                return _RightLyricLine(
                  key: ValueKey(
                    'line-${lines[index].time.inMilliseconds}-$index',
                  ),
                  text: lines[index].text,
                  active: index == activeIndex,
                );
              },
            ),
          );
        }
        return ClipRect(
          child: SizedBox.expand(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var index = 0; index < lines.length; index++)
                      _RightLyricLine(
                        key: ValueKey(
                          'line-${lines[index].time.inMilliseconds}-$index',
                        ),
                        text: lines[index].text,
                        active: index == activeIndex,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RightLyricLine extends StatelessWidget {
  const _RightLyricLine({super.key, required this.text, required this.active});

  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium!;
    return SizedBox(
      height: _AnimatedRightLyricListState._lineExtent,
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(left: active ? 0 : 2),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            style: style.copyWith(
              color: active ? kAccentDark : kMuted,
              fontWeight: active ? FontWeight.w900 : FontWeight.w600,
              height: 1.08,
            ),
            child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      ),
    );
  }
}

class _StaticRightLyrics extends StatelessWidget {
  const _StaticRightLyrics({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const lineExtent = _AnimatedRightLyricListState._lineExtent;
        final fillViewport =
            lines.length > 1 &&
            constraints.maxHeight.isFinite &&
            lines.length * lineExtent <= constraints.maxHeight;
        if (!fillViewport) {
          return ClipRect(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemExtent: lineExtent,
              itemCount: lines.length,
              itemBuilder: (context, index) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    lines[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: kMuted,
                      height: 1.08,
                    ),
                  ),
                );
              },
            ),
          );
        }
        return ClipRect(
          child: SizedBox.expand(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in lines)
                      SizedBox(
                        height: lineExtent,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            line,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: kMuted, height: 1.08),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({required this.icon, required this.onTap, this.color});

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kLine),
        ),
        child: Icon(icon, size: 16, color: color ?? kInk),
      ),
    );
  }
}

class _CompactControls extends StatelessWidget {
  const _CompactControls({
    required this.playingListenable,
    required this.isLoading,
    required this.onPlay,
    required this.onPrevious,
    required this.onNext,
    required this.playbackMode,
    required this.onPlaybackModeChanged,
  });

  final ValueListenable<bool> playingListenable;
  final bool isLoading;
  final VoidCallback onPlay;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final PlaybackMode playbackMode;
  final VoidCallback onPlaybackModeChanged;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeSmallIconButton(
            mode: playbackMode,
            onPressed: onPlaybackModeChanged,
          ),
          const SizedBox(width: 5),
          _SmallIconButton(
            icon: Icons.skip_previous_rounded,
            onTap: onPrevious,
          ),
          const SizedBox(width: 10),
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: isLoading ? null : onPlay,
            child: CircleAvatar(
              radius: 15,
              backgroundColor: kAccent,
              child: isLoading
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : ValueListenableBuilder<bool>(
                      valueListenable: playingListenable,
                      builder: (context, isPlaying, _) {
                        return Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 20,
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(width: 6),
          _SmallIconButton(icon: Icons.skip_next_rounded, onTap: onNext),
        ],
      ),
    );
  }
}

class _SmallIconButton extends StatelessWidget {
  const _SmallIconButton({required this.icon, this.onTap, this.color});

  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: SizedBox(
        width: 24,
        height: 26,
        child: Icon(
          icon,
          size: 18,
          color: color ?? (onTap == null ? kMuted : kInk),
        ),
      ),
    );
  }
}

class _ModeSmallIconButton extends StatefulWidget {
  const _ModeSmallIconButton({required this.mode, required this.onPressed});

  final PlaybackMode mode;
  final VoidCallback onPressed;

  @override
  State<_ModeSmallIconButton> createState() => _ModeSmallIconButtonState();
}

class _ModeSmallIconButtonState extends State<_ModeSmallIconButton> {
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
      child: _SmallIconButton(
        icon: _modeIcon(widget.mode),
        color: active ? kAccent : kMuted,
        onTap: _handlePressed,
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
