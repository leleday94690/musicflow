import 'dart:async';

import 'package:flutter/material.dart';

import '../api_client.dart';
import '../delayed_loading.dart';
import '../library_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/artwork.dart';
import '../widgets/empty_state.dart';
import '../widgets/song_tile.dart';
import '../widgets/sliding_tabs.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    required this.isMobile,
    required this.canManageLibrary,
    required this.authToken,
    required this.onSongTap,
    required this.onQueuePlayAll,
    required this.onSongPlayNext,
    required this.onSongAddToPlaylist,
    required this.onSongEdit,
    required this.onFavoriteToggle,
    required this.onSongDownload,
  });

  final bool isMobile;
  final bool canManageLibrary;
  final String? authToken;
  final SongTapCallback onSongTap;
  final Future<void> Function(List<Song> queue) onQueuePlayAll;
  final ValueChanged<Song> onSongPlayNext;
  final ValueChanged<Song> onSongAddToPlaylist;
  final ValueChanged<Song> onSongEdit;
  final Future<Song> Function(Song song) onFavoriteToggle;
  final Future<void> Function(Song song) onSongDownload;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  int selectedTab = 0;
  String query = '';
  String resultKeyword = '';
  List<Song> resultSongs = [];
  final DelayedLoadingController searchLoading = DelayedLoadingController(
    delay: const Duration(milliseconds: 320),
  );
  String? errorMessage;
  Timer? _searchDebounce;
  int _searchToken = 0;
  bool _searchPending = false;
  DateTime? _searchLoadingVisibleAt;

  @override
  void initState() {
    super.initState();
    searchLoading.addListener(_handleLoadingChanged);
  }

  @override
  void dispose() {
    searchLoading
      ..removeListener(_handleLoadingChanged)
      ..dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _handleLoadingChanged() {
    if (searchLoading.visible && _searchLoadingVisibleAt == null) {
      _searchLoadingVisibleAt = DateTime.now();
    }
    if (!searchLoading.visible) {
      _searchLoadingVisibleAt = null;
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isMobile) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        children: [
          _SearchBox(width: double.infinity, onSubmitted: _search),
          const SizedBox(height: 8),
          if (!hasQuery)
            _SearchGuide()
          else ...[
            SlidingTabs(
              labels: const ['全部', '歌曲', '歌单', '歌手', '专辑'],
              selectedIndex: selectedTab,
              onSelected: _selectTab,
              maxWidth: double.infinity,
            ),
            const SizedBox(height: 10),
            ..._resultWidgets(compact: true),
          ],
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 26),
            children: [
              _SearchBox(width: 420, onSubmitted: _search),
              const SizedBox(height: 10),
              if (!hasQuery)
                _SearchGuide()
              else ...[
                SlidingTabs(
                  labels: const ['全部', '歌曲', '歌单', '歌手', '专辑'],
                  selectedIndex: selectedTab,
                  onSelected: _selectTab,
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: kLine)),
                  ),
                  child: Column(children: _resultWidgets()),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  bool get hasQuery => query.trim().isNotEmpty;

  Future<void> _search(String value) async {
    final keyword = value.trim();
    _searchDebounce?.cancel();
    final token = ++_searchToken;
    searchLoading.stop();
    _searchLoadingVisibleAt = null;
    setState(() {
      query = keyword;
      errorMessage = null;
      if (keyword.isEmpty) {
        resultKeyword = '';
        resultSongs = [];
      }
      _searchPending = keyword.isNotEmpty;
    });
    if (keyword.isEmpty) {
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 280), () async {
      await _performSearch(keyword, token);
    });
  }

  Future<void> _performSearch(String keyword, int token) async {
    if (!mounted || query != keyword || token != _searchToken) {
      return;
    }
    searchLoading.start();
    try {
      final data = await MusicApiClient(
        token: widget.authToken,
      ).searchSongs(keyword);
      if (!mounted || query != keyword || token != _searchToken) {
        return;
      }
      await _waitForSearchLoadingToSettle(keyword, token);
      if (!mounted || query != keyword || token != _searchToken) {
        return;
      }
      setState(() {
        resultKeyword = keyword;
        resultSongs = data;
        _searchPending = false;
      });
    } catch (error) {
      if (!mounted || query != keyword || token != _searchToken) {
        return;
      }
      await _waitForSearchLoadingToSettle(keyword, token);
      if (!mounted || query != keyword || token != _searchToken) {
        return;
      }
      setState(() {
        errorMessage = error.toString().replaceFirst('Exception: ', '');
        _searchPending = false;
      });
    } finally {
      if (mounted && query == keyword && token == _searchToken) {
        searchLoading.stop();
      }
    }
  }

  Future<void> _waitForSearchLoadingToSettle(String keyword, int token) async {
    if (!searchLoading.visible) {
      return;
    }
    final shownAt = _searchLoadingVisibleAt ?? DateTime.now();
    final remaining =
        const Duration(milliseconds: 260) - DateTime.now().difference(shownAt);
    if (remaining <= Duration.zero) {
      return;
    }
    await Future.delayed(remaining);
    if (!mounted || query != keyword || token != _searchToken) {
      return;
    }
  }

  void _selectTab(int index) {
    setState(() => selectedTab = index);
  }

  List<Widget> _resultWidgets({bool compact = false}) {
    final keyword =
        (_searchPending && resultSongs.isNotEmpty ? resultKeyword : query)
            .trim()
            .toLowerCase();
    if (_searchPending && searchLoading.visible && resultSongs.isEmpty) {
      return const [_SearchLoadingPreview()];
    }
    if (_searchPending && resultSongs.isEmpty) {
      return const [SizedBox(height: 84)];
    }
    if (errorMessage != null) {
      return [
        EmptyState(
          icon: Icons.cloud_off_rounded,
          message: errorMessage!,
          margin: const EdgeInsets.symmetric(vertical: 18),
        ),
      ];
    }
    if (selectedTab == 2) {
      final matchedPlaylists = playlists
          .where(
            (playlist) =>
                playlist.name.toLowerCase().contains(keyword) ||
                playlist.description.toLowerCase().contains(keyword),
          )
          .toList();
      return [
        if (matchedPlaylists.isEmpty)
          const EmptyState(
            icon: Icons.queue_music_rounded,
            message: '暂无歌单搜索结果',
            margin: EdgeInsets.symmetric(vertical: 18),
          ),
        for (final playlist in matchedPlaylists)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: PlaylistCover(
              colors: playlist.colors,
              icon: playlist.icon,
              size: compact ? 48 : 54,
              radius: 10,
            ),
            title: Text(playlist.name),
            subtitle: Text(playlist.description),
          ),
      ];
    }
    final matchedSongs = switch (selectedTab) {
      3 =>
        resultSongs
            .where((song) => song.artist.toLowerCase().contains(keyword))
            .toList(),
      4 =>
        resultSongs
            .where((song) => song.album.toLowerCase().contains(keyword))
            .toList(),
      _ => resultSongs,
    };
    final emptyMessage = switch (selectedTab) {
      3 => '暂无歌手搜索结果',
      4 => '暂无专辑搜索结果',
      _ => '暂无搜索结果',
    };
    if (matchedSongs.isEmpty) {
      return [
        EmptyState(
          icon: Icons.search_off_rounded,
          message: emptyMessage,
          margin: const EdgeInsets.symmetric(vertical: 18),
        ),
      ];
    }
    return [
      Column(
        children: [
          _SearchResultsToolbar(
            compact: compact,
            count: matchedSongs.length,
            onPlayAll: () => widget.onQueuePlayAll(matchedSongs),
          ),
          if (_searchPending && resultSongs.isNotEmpty)
            const _SearchUpdatingHint(),
          for (var i = 0; i < matchedSongs.length; i++)
            SongTile(
              song: matchedSongs[i],
              index: i + 1,
              compact: compact,
              showAlbum: !compact,
              downloaded: downloads.any(
                (task) => task.song.id == matchedSongs[i].id,
              ),
              onTap: () =>
                  widget.onSongTap(matchedSongs[i], queue: matchedSongs),
              onPlayNextTap: () => widget.onSongPlayNext(matchedSongs[i]),
              onAddToPlaylistTap: () =>
                  widget.onSongAddToPlaylist(matchedSongs[i]),
              onEditTap: widget.canManageLibrary
                  ? () => widget.onSongEdit(matchedSongs[i])
                  : null,
              onFavoriteTap: () async {
                final updated = await widget.onFavoriteToggle(matchedSongs[i]);
                if (!context.mounted) {
                  return;
                }
                setState(() {
                  final index = resultSongs.indexWhere(
                    (song) => song.id == updated.id,
                  );
                  if (index >= 0) {
                    resultSongs[index] = updated;
                  }
                });
              },
              onDownloadTap: () => widget.onSongDownload(matchedSongs[i]),
            ),
        ],
      ),
    ];
  }
}

class _SearchUpdatingHint extends StatelessWidget {
  const _SearchUpdatingHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '正在更新搜索结果…',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: kMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SearchLoadingPreview extends StatelessWidget {
  const _SearchLoadingPreview();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [for (var i = 0; i < 5; i++) const _SearchLoadingRow()],
      ),
    );
  }
}

class _SearchLoadingRow extends StatelessWidget {
  const _SearchLoadingRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAF0F4)),
      ),
      child: Row(
        children: const [
          _SearchSkeletonBlock(width: 26, height: 26, radius: 13),
          SizedBox(width: 14),
          _SearchSkeletonBlock(width: 42, height: 42, radius: 12),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SearchSkeletonBlock(width: 170, height: 14, radius: 7),
                SizedBox(height: 8),
                _SearchSkeletonBlock(width: 96, height: 10, radius: 5),
              ],
            ),
          ),
          _SearchSkeletonBlock(width: 44, height: 18, radius: 9),
        ],
      ),
    );
  }
}

class _SearchSkeletonBlock extends StatelessWidget {
  const _SearchSkeletonBlock({
    required this.width,
    required this.height,
    required this.radius,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFE7F0F4).withValues(alpha: .9),
            const Color(0xFFF8FCFD).withValues(alpha: .96),
            const Color(0xFFEAF2F6).withValues(alpha: .9),
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.width, required this.onSubmitted});

  final double width;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        onChanged: onSubmitted,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: '搜索歌曲、歌手、歌单',
          prefixIcon: const Icon(Icons.search_rounded, color: kMuted, size: 20),
          filled: true,
          fillColor: const Color(0xFFF2F3F4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 11,
          ),
        ),
      ),
    );
  }
}

class _SearchResultsToolbar extends StatelessWidget {
  const _SearchResultsToolbar({
    required this.compact,
    required this.count,
    required this.onPlayAll,
  });

  final bool compact;
  final int count;
  final VoidCallback onPlayAll;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        Container(
          width: compact ? 34 : 38,
          height: compact ? 34 : 38,
          decoration: BoxDecoration(
            color: kAccent.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: kAccent.withValues(alpha: .16)),
          ),
          child: const Icon(Icons.queue_music_rounded, color: kAccentDark),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '找到 $count 首歌曲',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: kInk,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 12),
        TextButton.icon(
          onPressed: onPlayAll,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: kAccentDark,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 16,
              vertical: compact ? 9 : 10,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          icon: const Icon(Icons.play_arrow_rounded, size: 18),
          label: const Text(
            '播放全部',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
    return Padding(
      padding: EdgeInsets.only(
        top: compact ? 2 : 10,
        bottom: compact ? 10 : 12,
      ),
      child: compact
          ? content
          : Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kLine),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0B1D2A).withValues(alpha: .035),
                    blurRadius: 14,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: content,
            ),
    );
  }
}

class _SearchGuide extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kLine),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B1D2A).withValues(alpha: .025),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.manage_search_rounded, color: kAccent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '输入关键词搜索歌曲、歌手或歌单',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: kMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
