import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../delayed_loading.dart';
import '../library_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/artwork.dart';
import '../widgets/empty_state.dart';
import '../widgets/song_tile.dart';
import '../widgets/sliding_tabs.dart';

typedef PlaylistUpdateCallback =
    Future<Playlist> Function(
      Playlist playlist,
      String name,
      String description,
    );
typedef PlaylistSongsReorderCallback =
    Future<Playlist> Function(Playlist playlist, List<Song> orderedSongs);

class PlaylistsPage extends StatefulWidget {
  const PlaylistsPage({
    super.key,
    required this.isMobile,
    required this.canManageLibrary,
    required this.onSongTap,
    required this.onSongPlayNext,
    required this.onSongAddToPlaylist,
    required this.onSongEdit,
    required this.onSectionChanged,
    required this.onCreatePlaylist,
    required this.onUpdatePlaylist,
    required this.onDeletePlaylist,
    required this.onFetchPlaylist,
    required this.onPlaylistFavoriteToggle,
    required this.onAddSongToPlaylist,
    required this.onRemoveSongFromPlaylist,
    required this.onReorderPlaylistSongs,
    required this.onSongDownload,
  });

  final bool isMobile;
  final bool canManageLibrary;
  final SongTapCallback onSongTap;
  final ValueChanged<Song> onSongPlayNext;
  final ValueChanged<Song> onSongAddToPlaylist;
  final ValueChanged<Song> onSongEdit;
  final ValueChanged<MusicSection> onSectionChanged;
  final Future<Playlist> Function(String name, String description)
  onCreatePlaylist;
  final PlaylistUpdateCallback onUpdatePlaylist;
  final Future<bool> Function(Playlist playlist) onDeletePlaylist;
  final Future<Playlist> Function(Playlist playlist) onFetchPlaylist;
  final Future<Playlist> Function(Playlist playlist) onPlaylistFavoriteToggle;
  final Future<Playlist> Function(Playlist playlist, Song song)
  onAddSongToPlaylist;
  final Future<Playlist> Function(Playlist playlist, Song song)
  onRemoveSongFromPlaylist;
  final PlaylistSongsReorderCallback onReorderPlaylistSongs;
  final Future<void> Function(Song song) onSongDownload;

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage> {
  int selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final visiblePlaylists = _visiblePlaylists;
    if (widget.isMobile) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: () => widget.onSectionChanged(MusicSection.search),
              icon: const Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 16),
          _Tabs(selectedIndex: selectedTab, onSelected: _selectTab),
          const SizedBox(height: 12),
          _CreatePlaylistRow(onTap: _createPlaylist),
          if (visiblePlaylists.isEmpty)
            EmptyState(icon: Icons.queue_music_rounded, message: _emptyMessage),
          for (final playlist in visiblePlaylists)
            _PlaylistRow(
              playlist: playlist,
              onTap: () => _openDetail(context, playlist),
              onEdit: () => _editPlaylist(playlist),
              onDelete: () => _deletePlaylist(playlist),
            ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(28, 24, 24, 26),
            children: [
              _Tabs(selectedIndex: selectedTab, onSelected: _selectTab),
              const SizedBox(height: 18),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: visiblePlaylists.length + 1,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 360,
                  mainAxisExtent: 112,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _CreatePlaylistCard(onTap: _createPlaylist);
                  }
                  final playlist = visiblePlaylists[index - 1];
                  return _PlaylistCard(
                    playlist: playlist,
                    onTap: () => _openDetail(context, playlist),
                    onPlay: () => _playPlaylist(playlist),
                    onEdit: () => _editPlaylist(playlist),
                    onDelete: () => _deletePlaylist(playlist),
                  );
                },
              ),
              if (visiblePlaylists.isEmpty)
                EmptyState(
                  icon: Icons.queue_music_rounded,
                  message: _emptyMessage,
                  margin: const EdgeInsets.symmetric(vertical: 30),
                ),
            ],
          ),
        ),
        Container(width: 1, color: kLine),
        SizedBox(width: 252, child: _StatsPanel()),
      ],
    );
  }

  void _selectTab(int index) {
    setState(() => selectedTab = index);
  }

  Future<void> _createPlaylist() async {
    final created = await showDialog<Playlist>(
      context: context,
      builder: (context) =>
          _CreatePlaylistDialog(onCreate: widget.onCreatePlaylist),
    );
    if (created == null || !mounted) {
      return;
    }
    setState(() {});
  }

  List<Playlist> get _visiblePlaylists {
    if (selectedTab == 2) {
      return playlists.where((playlist) => playlist.isFavorite).toList();
    }
    return playlists;
  }

  String get _emptyMessage {
    if (selectedTab == 1) {
      return '暂无创建的歌单';
    }
    if (selectedTab == 2) {
      return '暂无收藏的歌单';
    }
    return '暂无歌单';
  }

  Future<void> _openDetail(BuildContext context, Playlist playlist) async {
    final loaded = await widget.onFetchPlaylist(playlist);
    if (!context.mounted) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlaylistDetailPage(
          playlist: loaded,
          onSongTap: widget.onSongTap,
          onSongPlayNext: widget.onSongPlayNext,
          onSongAddToPlaylist: widget.onSongAddToPlaylist,
          onSongEdit: widget.onSongEdit,
          canManageLibrary: widget.canManageLibrary,
          onPlaylistFavoriteToggle: widget.onPlaylistFavoriteToggle,
          onAddSongToPlaylist: widget.onAddSongToPlaylist,
          onRemoveSongFromPlaylist: widget.onRemoveSongFromPlaylist,
          onReorderPlaylistSongs: widget.onReorderPlaylistSongs,
          onUpdatePlaylist: widget.onUpdatePlaylist,
          onDeletePlaylist: widget.onDeletePlaylist,
          onSongDownload: widget.onSongDownload,
        ),
      ),
    );
  }

  void _playPlaylist(Playlist playlist) {
    if (playlist.songs.isEmpty) {
      return;
    }
    widget.onSongTap(playlist.songs.first, queue: playlist.songs);
  }

  Future<void> _editPlaylist(Playlist playlist) async {
    final updated = await showDialog<Playlist>(
      context: context,
      builder: (context) => _EditPlaylistDialog(
        playlist: playlist,
        onUpdate: (name, description) =>
            widget.onUpdatePlaylist(playlist, name, description),
      ),
    );
    if (updated == null || !mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _deletePlaylist(Playlist playlist) async {
    await widget.onDeletePlaylist(playlist);
    if (mounted) {
      setState(() {});
    }
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const labels = ['全部歌单', '我创建的', '我收藏的'];
    return SlidingTabs(
      labels: labels,
      selectedIndex: selectedIndex,
      onSelected: onSelected,
      maxWidth: 420,
    );
  }
}

class _CreatePlaylistDialog extends StatefulWidget {
  const _CreatePlaylistDialog({required this.onCreate});

  final Future<Playlist> Function(String name, String description) onCreate;

  @override
  State<_CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<_CreatePlaylistDialog> {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final DelayedLoadingController loading = DelayedLoadingController();
  String? errorMessage;

  @override
  void dispose() {
    loading.dispose();
    nameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    loading.addListener(_handleLoadingChanged);
  }

  void _handleLoadingChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: cardDecoration(radius: 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF8FC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.queue_music_rounded,
                      color: kAccentDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '新建歌单',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '整理喜欢的歌曲，创建你的专属歌单',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _DialogField(
                controller: nameController,
                label: '歌单名称',
                hintText: '例如：通勤路上',
                autofocus: true,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              _DialogField(
                controller: descriptionController,
                label: '描述',
                hintText: '可以简单写下这张歌单的氛围',
                maxLines: 2,
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFD8D8)),
                  ),
                  child: Text(
                    errorMessage!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: loading.active
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kInk,
                        side: const BorderSide(color: kLine),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: loading.active ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: kAccentDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: loading.visible
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('创建'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final name = nameController.text.trim();
    final description = descriptionController.text.trim();
    if (name.isEmpty) {
      setState(() => errorMessage = '请输入歌单名称');
      return;
    }
    loading.start();
    setState(() => errorMessage = null);
    try {
      final playlist = await widget.onCreate(name, description);
      if (mounted) {
        Navigator.of(context).pop(playlist);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      loading.stop();
    }
  }
}

class _EditPlaylistDialog extends StatefulWidget {
  const _EditPlaylistDialog({required this.playlist, required this.onUpdate});

  final Playlist playlist;
  final Future<Playlist> Function(String name, String description) onUpdate;

  @override
  State<_EditPlaylistDialog> createState() => _EditPlaylistDialogState();
}

class _EditPlaylistDialogState extends State<_EditPlaylistDialog> {
  late final TextEditingController nameController;
  late final TextEditingController descriptionController;
  final DelayedLoadingController loading = DelayedLoadingController();
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.playlist.name);
    descriptionController = TextEditingController(
      text: widget.playlist.description,
    );
    loading.addListener(_handleLoadingChanged);
  }

  @override
  void dispose() {
    loading
      ..removeListener(_handleLoadingChanged)
      ..dispose();
    nameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  void _handleLoadingChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.playlist.colors.isEmpty
        ? kAccent
        : widget.playlist.colors.last;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: cardDecoration(radius: 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PlaylistCover(
                    colors: widget.playlist.colors,
                    icon: widget.playlist.icon,
                    size: 46,
                    radius: 15,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '编辑歌单信息',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '调整名称和描述，让它更容易识别',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _DialogField(
                controller: nameController,
                label: '歌单名称',
                hintText: '例如：深夜循环',
                autofocus: true,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              _DialogField(
                controller: descriptionController,
                label: '描述',
                hintText: '写下这张歌单的氛围',
                maxLines: 2,
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFD8D8)),
                  ),
                  child: Text(
                    errorMessage!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: loading.active
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kInk,
                        side: const BorderSide(color: kLine),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: loading.active ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: loading.visible
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('保存'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final name = nameController.text.trim();
    final description = descriptionController.text.trim();
    if (name.isEmpty) {
      setState(() => errorMessage = '请输入歌单名称');
      return;
    }
    loading.start();
    setState(() => errorMessage = null);
    try {
      final playlist = await widget.onUpdate(name, description);
      if (mounted) {
        Navigator.of(context).pop(playlist);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      loading.stop();
    }
  }
}

class _DialogField extends StatelessWidget {
  const _DialogField({
    required this.controller,
    required this.label,
    required this.hintText,
    this.autofocus = false,
    this.textInputAction,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: kInk,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          autofocus: autofocus,
          textInputAction: textInputAction,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: const Color(0xFFF7FAFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: kLine),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: kLine),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: kAccentDark, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}

class _CreatePlaylistCard extends StatefulWidget {
  const _CreatePlaylistCard({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_CreatePlaylistCard> createState() => _CreatePlaylistCardState();
}

class _CreatePlaylistCardState extends State<_CreatePlaylistCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hovered ? -3 : 0, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: kAccent.withValues(alpha: _hovered ? .18 : .10),
              blurRadius: _hovered ? 28 : 20,
              offset: const Offset(0, 14),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: .025),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashColor: kAccent.withValues(alpha: .08),
            onTap: widget.onTap,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 280;
                final veryNarrow = constraints.maxWidth < 230;
                final coverSize = constraints.maxWidth < 260
                    ? math.max(54.0, constraints.maxWidth * .25)
                    : 74.0;
                final gap = narrow ? 10.0 : 16.0;
                return Padding(
                  padding: EdgeInsets.all(narrow ? 10 : 12),
                  child: Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: coverSize,
                            height: coverSize,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  kAccent.withValues(alpha: .16),
                                  const Color(0xFFFFFFFF),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                narrow ? 15 : 18,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: kAccent.withValues(alpha: .12),
                                  blurRadius: narrow ? 12 : 18,
                                  offset: Offset(0, narrow ? 6 : 10),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.playlist_add_rounded,
                              color: kAccent.withValues(alpha: .78),
                              size: narrow ? 28 : 34,
                            ),
                          ),
                          Positioned(
                            right: narrow ? -5 : -7,
                            bottom: narrow ? -5 : -7,
                            child: AnimatedScale(
                              scale: _hovered ? 1.08 : 1,
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOut,
                              child: Material(
                                color: kAccent,
                                shape: const CircleBorder(),
                                elevation: 5,
                                shadowColor: kAccent.withValues(alpha: .35),
                                child: SizedBox.square(
                                  dimension: narrow ? 28 : 32,
                                  child: Icon(
                                    Icons.add_rounded,
                                    color: Colors.white,
                                    size: narrow ? 18 : 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(width: gap),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '新建歌单',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: kInk,
                                fontSize: narrow ? 15 : 16,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              '从一首歌开始收藏',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: kMuted,
                                fontSize: narrow ? 11 : 12,
                                fontWeight: FontWeight.w500,
                                height: 1.2,
                              ),
                            ),
                            if (!veryNarrow) ...[
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value: _hovered ? .82 : .56,
                                  minHeight: 4,
                                  backgroundColor: const Color(0xFFEFF4F7),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    kAccent.withValues(alpha: .72),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (!narrow) ...[
                        const SizedBox(width: 10),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: kMuted.withValues(alpha: .7),
                          size: 22,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CreatePlaylistRow extends StatelessWidget {
  const _CreatePlaylistRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: kAccent.withValues(alpha: .045),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          hoverColor: kAccent.withValues(alpha: .04),
          highlightColor: Colors.transparent,
          splashColor: kAccent.withValues(alpha: .08),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: kAccent.withValues(alpha: .2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: kAccent,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '创建歌单',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: kInk,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '把喜欢的音乐整理起来',
                        style: Theme.of(
                          context,
                        ).textTheme.labelMedium?.copyWith(color: kMuted),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: kAccent.withValues(alpha: .72),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistCard extends StatefulWidget {
  const _PlaylistCard({
    required this.playlist,
    required this.onTap,
    required this.onPlay,
    required this.onEdit,
    required this.onDelete,
  });

  final Playlist playlist;
  final VoidCallback onTap;
  final VoidCallback onPlay;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_PlaylistCard> createState() => _PlaylistCardState();
}

class _PlaylistCardState extends State<_PlaylistCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final playlist = widget.playlist;
    final accent = playlist.colors.isEmpty ? kAccent : playlist.colors.last;
    final subtitle = playlist.updatedText.isEmpty
        ? '${playlist.songCount} 首歌曲'
        : '${playlist.songCount} 首 · ${playlist.updatedText}';
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hovered ? -3 : 0, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: _hovered ? .28 : .16),
              blurRadius: _hovered ? 32 : 22,
              offset: const Offset(0, 14),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: .03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: widget.onTap,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 280;
                final veryNarrow = constraints.maxWidth < 230;
                final coverSize = constraints.maxWidth < 260
                    ? math.max(54.0, constraints.maxWidth * .25)
                    : 74.0;
                final playSize = narrow ? 28.0 : 32.0;
                final gap = narrow ? 10.0 : 16.0;
                return Padding(
                  padding: EdgeInsets.all(narrow ? 10 : 12),
                  child: Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: coverSize,
                            height: coverSize,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                narrow ? 15 : 18,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: .24),
                                  blurRadius: narrow ? 12 : 18,
                                  offset: Offset(0, narrow ? 6 : 10),
                                ),
                              ],
                            ),
                            child: PlaylistCover(
                              colors: playlist.colors,
                              icon: playlist.icon,
                              size: coverSize,
                              radius: narrow ? 15 : 18,
                            ),
                          ),
                          Positioned(
                            right: narrow ? -5 : -7,
                            bottom: narrow ? -5 : -7,
                            child: AnimatedScale(
                              scale: _hovered ? 1.08 : 1,
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOut,
                              child: Material(
                                color: Colors.white,
                                shape: const CircleBorder(),
                                elevation: 5,
                                shadowColor: accent.withValues(alpha: .35),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: widget.onPlay,
                                  child: SizedBox.square(
                                    dimension: playSize,
                                    child: Icon(
                                      Icons.play_arrow_rounded,
                                      color: accent,
                                      size: playSize * .62,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (playlist.isFavorite)
                            const Positioned(
                              top: 6,
                              right: 6,
                              child: _CoverBadge(
                                icon: Icons.favorite_rounded,
                                label: '',
                              ),
                            ),
                        ],
                      ),
                      SizedBox(width: gap),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              playlist.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: kInk,
                                fontSize: narrow ? 15 : 16,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: kMuted,
                                fontSize: narrow ? 11 : 12,
                                fontWeight: FontWeight.w500,
                                height: 1.2,
                              ),
                            ),
                            if (!veryNarrow) ...[
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value: playlist.songCount == 0 ? 0 : .72,
                                  minHeight: 4,
                                  backgroundColor: const Color(0xFFEFF4F7),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    accent,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (!narrow) ...[
                        const SizedBox(width: 10),
                        _PlaylistMoreMenu(
                          onEdit: widget.onEdit,
                          onDelete: widget.onDelete,
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: kMuted.withValues(alpha: .7),
                          size: 22,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverBadge extends StatelessWidget {
  const _CoverBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: EdgeInsets.symmetric(horizontal: label.isEmpty ? 6 : 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .32),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlaylistMoreMenu extends StatefulWidget {
  const _PlaylistMoreMenu({required this.onEdit, required this.onDelete});

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_PlaylistMoreMenu> createState() => _PlaylistMoreMenuState();
}

class _PlaylistMoreMenuState extends State<_PlaylistMoreMenu> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
      ),
      child: PopupMenuButton<_PlaylistMenuAction>(
        tooltip: '更多操作',
        padding: EdgeInsets.zero,
        color: Colors.white,
        elevation: 12,
        shadowColor: kInk.withValues(alpha: .12),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        offset: const Offset(0, 10),
        onSelected: (action) {
          switch (action) {
            case _PlaylistMenuAction.edit:
              widget.onEdit();
            case _PlaylistMenuAction.delete:
              widget.onDelete();
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: _PlaylistMenuAction.edit,
            child: _PlaylistMenuItem(icon: Icons.edit_outlined, label: '编辑信息'),
          ),
          PopupMenuItem(
            value: _PlaylistMenuAction.delete,
            child: _PlaylistMenuItem(
              icon: Icons.delete_outline_rounded,
              label: '删除歌单',
              destructive: true,
            ),
          ),
        ],
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hovered
                  ? kAccent.withValues(alpha: .08)
                  : const Color(0xFFF7FAFC),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: _hovered
                    ? kAccent.withValues(alpha: .16)
                    : kLine.withValues(alpha: .85),
              ),
            ),
            child: Icon(
              Icons.more_horiz_rounded,
              color: _hovered ? kAccent : kMuted.withValues(alpha: .82),
            ),
          ),
        ),
      ),
    );
  }
}

enum _PlaylistMenuAction { edit, delete }

class _PlaylistMenuItem extends StatelessWidget {
  const _PlaylistMenuItem({
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? const Color(0xFFE15B5B) : kInk;
    return Row(
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 10),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _PlaylistRow extends StatelessWidget {
  const _PlaylistRow({
    required this.playlist,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Playlist playlist;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final accent = playlist.colors.isEmpty ? kAccent : playlist.colors.last;
    final subtitle = playlist.updatedText.isEmpty
        ? '${playlist.songCount} 首歌曲'
        : '${playlist.songCount} 首 · ${playlist.updatedText}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: kLine),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: .08),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                PlaylistCover(
                  colors: playlist.colors,
                  icon: playlist.icon,
                  size: 60,
                  radius: 14,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              playlist.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: kInk,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                          ),
                          if (playlist.isFavorite)
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(
                                Icons.favorite_rounded,
                                size: 14,
                                color: Color(0xFFE84393),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: kMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _PlaylistMoreMenu(onEdit: onEdit, onDelete: onDelete),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: .12),
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: accent,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final playlistCount = playlists.length;
    final songCount = playlists.fold<int>(
      0,
      (total, playlist) => total + playlist.songCount,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      children: [
        Text('歌单统计', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 14),
        _StatCard(
          icon: Icons.library_music_rounded,
          value: '$playlistCount',
          label: '歌单总数',
        ),
        const SizedBox(height: 12),
        _StatCard(
          icon: Icons.music_note_rounded,
          value: '$songCount',
          label: '收录歌曲',
        ),
        const SizedBox(height: 12),
        _StatCard(
          icon: Icons.favorite_rounded,
          value: '${playlists.where((playlist) => playlist.isFavorite).length}',
          label: '收藏歌单',
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Text('最近编辑', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            const Icon(Icons.history_rounded, color: kMuted, size: 18),
          ],
        ),
        const SizedBox(height: 14),
        if (playlists.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: cardDecoration(radius: 18),
            child: Text('暂无歌单', style: Theme.of(context).textTheme.bodyMedium),
          ),
        for (final playlist in playlists.take(5))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: .05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  PlaylistCover(
                    colors: playlist.colors,
                    icon: playlist.icon,
                    size: 38,
                    radius: 10,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playlist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        Text(
                          '${playlist.songCount} 首 · ${playlist.updatedText}',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kLine),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: kAccent.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: kAccent, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: Theme.of(context).textTheme.titleMedium),
                Text(label, style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PlaylistDetailPage extends StatefulWidget {
  const PlaylistDetailPage({
    super.key,
    required this.playlist,
    required this.onSongTap,
    required this.onSongPlayNext,
    required this.onSongAddToPlaylist,
    required this.onSongEdit,
    required this.canManageLibrary,
    required this.onPlaylistFavoriteToggle,
    required this.onAddSongToPlaylist,
    required this.onRemoveSongFromPlaylist,
    required this.onReorderPlaylistSongs,
    required this.onUpdatePlaylist,
    required this.onDeletePlaylist,
    required this.onSongDownload,
  });

  final Playlist playlist;
  final SongTapCallback onSongTap;
  final ValueChanged<Song> onSongPlayNext;
  final ValueChanged<Song> onSongAddToPlaylist;
  final ValueChanged<Song> onSongEdit;
  final bool canManageLibrary;
  final Future<Playlist> Function(Playlist playlist) onPlaylistFavoriteToggle;
  final Future<Playlist> Function(Playlist playlist, Song song)
  onAddSongToPlaylist;
  final Future<Playlist> Function(Playlist playlist, Song song)
  onRemoveSongFromPlaylist;
  final PlaylistSongsReorderCallback onReorderPlaylistSongs;
  final PlaylistUpdateCallback onUpdatePlaylist;
  final Future<bool> Function(Playlist playlist) onDeletePlaylist;
  final Future<void> Function(Song song) onSongDownload;

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  late Playlist playlist = widget.playlist;
  final DelayedLoadingController loading = DelayedLoadingController();
  int? _draggingSongId;

  @override
  void initState() {
    super.initState();
    loading.addListener(_handleLoadingChanged);
  }

  @override
  void dispose() {
    loading
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
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 720;
    return Scaffold(
      backgroundColor: kScaffold,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 16 : 24,
            isMobile ? 10 : 16,
            isMobile ? 16 : 24,
            24,
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PlaylistCover(
                  colors: playlist.colors,
                  icon: playlist.icon,
                  size: isMobile ? 72 : 132,
                  radius: 16,
                ),
                SizedBox(width: isMobile ? 12 : 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: isMobile
                            ? Theme.of(context).textTheme.titleMedium
                            : Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${playlist.owner} · 更新于 ${playlist.updatedText.isEmpty ? '未知' : playlist.updatedText}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '${playlist.songCount} 首歌曲 · ${formatDuration(playlist.totalTime)}',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ActionButton(
                            icon: Icons.play_arrow_rounded,
                            label: '播放全部',
                            filled: true,
                            onTap: _playAll,
                          ),
                          _ActionButton(
                            icon: playlist.isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            label: loading.visible
                                ? '处理中'
                                : playlist.isFavorite
                                ? '已收藏'
                                : '收藏',
                            busy: loading.active,
                            loading: loading.visible,
                            onTap: _toggleFavorite,
                          ),
                          _ActionButton(
                            icon: Icons.add_rounded,
                            label: '添加歌曲',
                            busy: loading.active,
                            onTap: _addSong,
                          ),
                          _PlaylistMoreMenu(
                            onEdit: _editPlaylist,
                            onDelete: _deletePlaylist,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (playlist.songs.isEmpty)
              Container(
                decoration: cardDecoration(radius: 18),
                child: const EmptyState(
                  icon: Icons.music_note_rounded,
                  message: '这个歌单还没有歌曲',
                  margin: EdgeInsets.symmetric(vertical: 26),
                ),
              )
            else
              Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: kAccent.withValues(alpha: .055),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: kAccent.withValues(alpha: .1)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.drag_indicator_rounded,
                          color: kAccent.withValues(alpha: .78),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '拖动歌曲右侧手柄调整播放顺序，松开后自动保存',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: kMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    buildDefaultDragHandles: false,
                    onReorderStart: (index) {
                      setState(
                        () => _draggingSongId = playlist.songs[index].id,
                      );
                    },
                    onReorderEnd: (_) {
                      if (mounted) {
                        setState(() => _draggingSongId = null);
                      }
                    },
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, child) {
                          final t = Curves.easeOutCubic.transform(
                            animation.value,
                          );
                          return Transform.scale(
                            scale: 1 + t * .008,
                            child: Material(
                              type: MaterialType.transparency,
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                              clipBehavior: Clip.antiAlias,
                              child: child,
                            ),
                          );
                        },
                        child: child,
                      );
                    },
                    itemCount: playlist.songs.length,
                    onReorder: _reorderSongs,
                    itemBuilder: (context, i) {
                      final song = playlist.songs[i];
                      final isDragging = _draggingSongId == song.id;
                      return Padding(
                        key: ValueKey(
                          'playlist-${playlist.id}-song-${song.id}',
                        ),
                        padding: EdgeInsets.only(
                          bottom: i == playlist.songs.length - 1 ? 0 : 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: SongTile(
                                song: song,
                                index: i + 1,
                                compact: true,
                                downloaded: downloads.any(
                                  (task) => task.song.id == song.id,
                                ),
                                showShadow: !isDragging,
                                onTap: () => widget.onSongTap(
                                  song,
                                  queue: playlist.songs,
                                ),
                                onPlayNextTap: () =>
                                    widget.onSongPlayNext(song),
                                onAddToPlaylistTap: () =>
                                    widget.onSongAddToPlaylist(song),
                                onEditTap: widget.canManageLibrary
                                    ? () => widget.onSongEdit(song)
                                    : null,
                                onDownloadTap: () =>
                                    widget.onSongDownload(song),
                              ),
                            ),
                            IconButton(
                              tooltip: '从歌单移除',
                              style: IconButton.styleFrom(
                                hoverColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                              ),
                              onPressed: loading.active
                                  ? null
                                  : () => _removeSong(song),
                              icon: const Icon(
                                Icons.remove_circle_outline_rounded,
                                color: kMuted,
                              ),
                            ),
                            ReorderableDragStartListener(
                              index: i,
                              enabled: !loading.active,
                              child: Container(
                                width: 38,
                                height: 38,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: kAccent.withValues(alpha: .06),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: Icon(
                                  Icons.drag_indicator_rounded,
                                  color: kMuted.withValues(alpha: .8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _playAll() {
    if (playlist.songs.isEmpty) {
      return;
    }
    widget.onSongTap(playlist.songs.first, queue: playlist.songs);
  }

  Future<void> _toggleFavorite() async {
    if (loading.active) {
      return;
    }
    loading.start();
    try {
      final updated = await widget.onPlaylistFavoriteToggle(playlist);
      if (mounted) {
        setState(() => playlist = updated);
      }
    } finally {
      loading.stop();
    }
  }

  Future<void> _addSong() async {
    final selected = await showDialog<Song>(
      context: context,
      builder: (context) => _AddSongDialog(
        availableSongs: songs
            .where((song) => !playlist.songs.any((item) => item.id == song.id))
            .toList(),
      ),
    );
    if (selected == null || !mounted) {
      return;
    }
    if (loading.active) {
      return;
    }
    loading.start();
    try {
      final updated = await widget.onAddSongToPlaylist(playlist, selected);
      if (mounted) {
        setState(() => playlist = updated);
      }
    } finally {
      loading.stop();
    }
  }

  Future<void> _removeSong(Song song) async {
    if (loading.active) {
      return;
    }
    loading.start();
    try {
      final updated = await widget.onRemoveSongFromPlaylist(playlist, song);
      if (mounted) {
        setState(() => playlist = updated);
      }
    } finally {
      loading.stop();
    }
  }

  Future<void> _reorderSongs(int oldIndex, int newIndex) async {
    if (loading.active || oldIndex == newIndex) {
      return;
    }
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    if (oldIndex < 0 ||
        oldIndex >= playlist.songs.length ||
        newIndex < 0 ||
        newIndex >= playlist.songs.length) {
      return;
    }
    final previous = playlist;
    final orderedSongs = List<Song>.of(playlist.songs);
    final moved = orderedSongs.removeAt(oldIndex);
    orderedSongs.insert(newIndex, moved);
    setState(() {
      playlist = _copyPlaylistWithSongs(playlist, orderedSongs);
    });
    loading.start();
    try {
      final updated = await widget.onReorderPlaylistSongs(
        playlist,
        orderedSongs,
      );
      if (mounted) {
        setState(() => playlist = updated);
      }
    } catch (error) {
      if (mounted) {
        setState(() => playlist = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '排序保存失败：${error.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      loading.stop();
    }
  }

  Playlist _copyPlaylistWithSongs(Playlist source, List<Song> orderedSongs) {
    return Playlist(
      id: source.id,
      name: source.name,
      description: source.description,
      owner: source.owner,
      songs: orderedSongs,
      colors: source.colors,
      icon: source.icon,
      isFavorite: source.isFavorite,
      songCount: orderedSongs.length,
      totalTime: orderedSongs.fold<Duration>(
        Duration.zero,
        (total, song) => total + song.duration,
      ),
      updatedText: source.updatedText,
    );
  }

  Future<void> _editPlaylist() async {
    if (loading.active) {
      return;
    }
    final updated = await showDialog<Playlist>(
      context: context,
      builder: (context) => _EditPlaylistDialog(
        playlist: playlist,
        onUpdate: (name, description) =>
            widget.onUpdatePlaylist(playlist, name, description),
      ),
    );
    if (updated == null || !mounted) {
      return;
    }
    setState(() => playlist = updated);
  }

  Future<void> _deletePlaylist() async {
    if (loading.active) {
      return;
    }
    final deleted = await widget.onDeletePlaylist(playlist);
    if (deleted && mounted) {
      Navigator.of(context).pop();
    }
  }
}

class _AddSongDialog extends StatelessWidget {
  const _AddSongDialog({required this.availableSongs});

  final List<Song> availableSongs;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加歌曲'),
      content: SizedBox(
        width: 420,
        height: 420,
        child: availableSongs.isEmpty
            ? const EmptyState(
                icon: Icons.music_note_rounded,
                message: '没有可添加的歌曲',
                margin: EdgeInsets.symmetric(vertical: 30),
              )
            : ListView.builder(
                itemCount: availableSongs.length,
                itemBuilder: (context, index) {
                  final song = availableSongs[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Artwork(song: song, size: 42, radius: 10),
                    title: Text(song.title),
                    subtitle: Text(song.artist),
                    trailing: const Icon(Icons.add_rounded, color: kAccent),
                    onTap: () => Navigator.of(context).pop(song),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.busy = false,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;
  final bool busy;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    const color = kInk;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: busy ? null : onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: filled ? kAccent : Colors.white.withValues(alpha: .16),
          border: Border.all(color: filled ? kAccent : kLine),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: filled ? Colors.white : color,
                ),
              )
            else
              Icon(icon, size: 18, color: filled ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: filled ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
