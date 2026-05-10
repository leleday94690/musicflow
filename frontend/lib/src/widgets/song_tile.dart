import 'dart:ui';

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'artwork.dart';

enum _SongTileAction {
  playAll,
  playNext,
  addToPlaylist,
  edit,
  favorite,
  download,
  delete,
}

OverlayEntry? _openSongActionMenuEntry;

void _dismissOpenSongActionMenu() {
  _openSongActionMenuEntry?.remove();
  _openSongActionMenuEntry = null;
}

class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.song,
    this.index,
    this.compact = false,
    this.showAlbum = true,
    this.selected = false,
    this.selectionMode = false,
    this.downloaded = false,
    this.showShadow = true,
    this.hotRank,
    this.onTap,
    this.onLongPress,
    this.onSelectionToggle,
    this.onPlayAllTap,
    this.onPlayNextTap,
    this.onAddToPlaylistTap,
    this.onEditTap,
    this.onFavoriteTap,
    this.onDownloadTap,
    this.onDeleteTap,
  });

  final Song song;
  final int? index;
  final bool compact;
  final bool showAlbum;
  final bool selected;
  final bool selectionMode;
  final bool downloaded;
  final bool showShadow;
  final int? hotRank;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSelectionToggle;
  final VoidCallback? onPlayAllTap;
  final VoidCallback? onPlayNextTap;
  final VoidCallback? onAddToPlaylistTap;
  final VoidCallback? onEditTap;
  final VoidCallback? onFavoriteTap;
  final VoidCallback? onDownloadTap;
  final VoidCallback? onDeleteTap;

  bool get _hasActions =>
      onPlayAllTap != null ||
      onPlayNextTap != null ||
      onAddToPlaylistTap != null ||
      onEditTap != null ||
      onFavoriteTap != null ||
      onDownloadTap != null ||
      onDeleteTap != null;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tight = compact || constraints.maxWidth < 460;
        final emphasized = selected || index == 1;
        final isHot = hotRank != null;
        final tileColor = selectionMode
            ? const Color(0xFFFBFCFD)
            : selected
            ? kAccent.withValues(alpha: 0.1)
            : index == 1
            ? const Color(0xFFF4FBFD)
            : const Color(0xFFFBFCFD);
        final tileBorderColor = selectionMode
            ? selected
                  ? kAccent.withValues(alpha: 0.2)
                  : const Color(0xFFEAF0F4)
            : selected
            ? kAccent.withValues(alpha: 0.28)
            : index == 1
            ? const Color(0xFFD8F1F7)
            : const Color(0xFFEAF0F4);
        final tileShadow = showShadow && !selectionMode
            ? [
                BoxShadow(
                  color: selected
                      ? kAccent.withValues(alpha: 0.1)
                      : const Color(0xFF0B1D2A).withValues(alpha: 0.035),
                  blurRadius: selected ? 22 : 18,
                  offset: Offset(0, selected ? 10 : 8),
                ),
              ]
            : const <BoxShadow>[];
        final titleColor = selectionMode
            ? kInk
            : selected
            ? kAccentDark
            : kInk;
        final tile = Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(tight ? 16 : 18),
          child: InkWell(
            borderRadius: BorderRadius.circular(tight ? 16 : 18),
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashColor: kAccent.withValues(alpha: 0.08),
            onTap: () {
              _dismissOpenSongActionMenu();
              if (selectionMode) {
                onSelectionToggle?.call();
                return;
              }
              onTap?.call();
            },
            onLongPress: onLongPress,
            child: AnimatedContainer(
              duration: selectionMode
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              margin: EdgeInsets.symmetric(vertical: tight ? 4 : 5),
              padding: EdgeInsets.symmetric(
                horizontal: tight ? 11 : 13,
                vertical: tight ? 8 : 9,
              ),
              decoration: BoxDecoration(
                color: tileColor,
                borderRadius: BorderRadius.circular(tight ? 14 : 16),
                border: Border.all(color: tileBorderColor),
                boxShadow: tileShadow,
              ),
              child: Row(
                children: [
                  if (selectionMode) ...[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      width: tight ? 24 : 26,
                      height: tight ? 24 : 26,
                      decoration: BoxDecoration(
                        color: selected ? kAccent : Colors.white,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: selected
                              ? kAccent
                              : kMuted.withValues(alpha: .34),
                          width: 1.4,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: kAccent.withValues(alpha: .18),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                ),
                              ]
                            : const [],
                      ),
                      child: selected
                          ? Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: tight ? 17 : 18,
                            )
                          : null,
                    ),
                    SizedBox(width: tight ? 9 : 10),
                  ],
                  if (index != null)
                    Container(
                      width: tight ? 24 : 28,
                      height: tight ? 24 : 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: index! <= 3
                            ? kAccent.withValues(alpha: 0.12)
                            : const Color(0xFFF4F7F9),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${index!}',
                        style: TextStyle(
                          color: index! <= 3 ? kAccentDark : kMuted,
                          fontSize: tight ? 12 : 13,
                          fontWeight: FontWeight.w700,
                          height: 1,
                          letterSpacing: 0.2,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  if (index != null) SizedBox(width: tight ? 10 : 12),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Artwork(song: song, size: tight ? 40 : 46, radius: 13),
                      Container(
                        width: tight ? 21 : 23,
                        height: tight ? 21 : 23,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.86),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: kAccent,
                          size: tight ? 15 : 17,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: tight ? 11 : 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: titleColor,
                                  fontSize: tight ? 14 : 15,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                            if (isHot) ...[
                              const SizedBox(width: 8),
                              _HotBadge(
                                rank: hotRank!,
                                playCount: song.playCount,
                                compact: tight,
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: tight ? 3 : 4),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: selected
                                      ? kAccentDark.withValues(alpha: .82)
                                      : kMuted,
                                  fontSize: tight ? 12 : 12.5,
                                  fontWeight: FontWeight.w500,
                                  height: 1.25,
                                  letterSpacing: 0.15,
                                ),
                              ),
                            ),
                            if (!tight &&
                                showAlbum &&
                                song.album.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: kMuted.withValues(alpha: 0.4),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  song.album,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: kMuted.withValues(alpha: .85),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: tight ? 8 : 10),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: tight ? 9 : 11,
                      vertical: tight ? 5 : 6,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? kAccent.withValues(alpha: .12)
                          : const Color(0xFFF1F5F8),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      formatDuration(song.duration),
                      style: TextStyle(
                        fontSize: tight ? 11 : 12,
                        fontWeight: FontWeight.w600,
                        height: 1,
                        letterSpacing: 0.2,
                        color: selected
                            ? kAccentDark
                            : kMuted.withValues(alpha: .92),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  SizedBox(width: tight ? 6 : 8),
                  if (!selectionMode)
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      hoverColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      splashColor: kAccent.withValues(alpha: 0.08),
                      onTap: onFavoriteTap,
                      child: Container(
                        width: tight ? 30 : 32,
                        height: tight ? 30 : 32,
                        decoration: BoxDecoration(
                          color: song.isFavorite
                              ? kAccent.withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.72),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: kLine.withValues(alpha: .55),
                          ),
                        ),
                        child: Icon(
                          song.isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: song.isFavorite ? kAccent : kMuted,
                          size: tight ? 17 : 19,
                        ),
                      ),
                    ),
                  if (!selectionMode && !tight) ...[
                    const SizedBox(width: 8),
                    _hasActions
                        ? InkWell(
                            borderRadius: BorderRadius.circular(16),
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            splashColor: kAccent.withValues(alpha: 0.08),
                            onTapDown: (details) => _showActionMenu(
                              context,
                              details.globalPosition,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(5),
                              child: Icon(
                                Icons.more_horiz_rounded,
                                color: emphasized ? kAccent : kMuted,
                                size: 22,
                              ),
                            ),
                          )
                        : Icon(
                            emphasized
                                ? Icons.equalizer_rounded
                                : Icons.more_horiz_rounded,
                            color: emphasized ? kAccent : kMuted,
                            size: 22,
                          ),
                  ],
                ],
              ),
            ),
          ),
        );
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onSecondaryTapDown: _hasActions && !selectionMode
              ? (details) => _showActionMenu(context, details.globalPosition)
              : null,
          child: tile,
        );
      },
    );
  }

  void _showActionMenu(BuildContext context, Offset position) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }
    _dismissOpenSongActionMenu();
    late final OverlayEntry menuEntry;
    menuEntry = OverlayEntry(
      builder: (context) => _SongActionMenuHost(
        position: position,
        entries: [
          if (onPlayAllTap != null)
            const _SongActionMenuEntry(
              action: _SongTileAction.playAll,
              icon: Icons.playlist_play_rounded,
              label: '播放全部',
              color: kAccentDark,
            ),
          if (onPlayNextTap != null)
            const _SongActionMenuEntry(
              action: _SongTileAction.playNext,
              icon: Icons.low_priority_rounded,
              label: '下一首播放',
              color: kAccentDark,
            ),
          if (onAddToPlaylistTap != null)
            const _SongActionMenuEntry(
              action: _SongTileAction.addToPlaylist,
              icon: Icons.playlist_add_rounded,
              label: '添加到歌单',
              color: kAccentDark,
            ),
          if (onEditTap != null)
            const _SongActionMenuEntry(
              action: _SongTileAction.edit,
              icon: Icons.edit_outlined,
              label: '编辑信息',
              color: kInk,
            ),
          if (onFavoriteTap != null)
            _SongActionMenuEntry(
              action: _SongTileAction.favorite,
              icon: song.isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              label: song.isFavorite ? '取消收藏' : '收藏歌曲',
              color: kAccent,
            ),
          if (onDownloadTap != null)
            _SongActionMenuEntry(
              action: _SongTileAction.download,
              icon: downloaded
                  ? Icons.download_done_rounded
                  : Icons.download_rounded,
              label: downloaded ? '已下载到本地' : '下载到本地',
              color: downloaded ? kMuted : kAccentDark,
              enabled: !downloaded,
            ),
          if (onDeleteTap != null)
            const _SongActionMenuEntry(
              action: _SongTileAction.delete,
              icon: Icons.delete_outline_rounded,
              label: '删除歌曲',
              color: Color(0xFFE15B5B),
            ),
        ],
        onSelected: (action) {
          if (_openSongActionMenuEntry == menuEntry) {
            _openSongActionMenuEntry = null;
          }
          menuEntry.remove();
          _handleAction(action);
        },
      ),
    );
    _openSongActionMenuEntry = menuEntry;
    overlay.insert(menuEntry);
  }

  void _handleAction(_SongTileAction action) {
    if (action == _SongTileAction.playAll) {
      onPlayAllTap?.call();
    }
    if (action == _SongTileAction.playNext) {
      onPlayNextTap?.call();
    }
    if (action == _SongTileAction.addToPlaylist) {
      onAddToPlaylistTap?.call();
    }
    if (action == _SongTileAction.edit) {
      onEditTap?.call();
    }
    if (action == _SongTileAction.favorite) {
      onFavoriteTap?.call();
    }
    if (action == _SongTileAction.download) {
      onDownloadTap?.call();
    }
    if (action == _SongTileAction.delete) {
      onDeleteTap?.call();
    }
  }
}

class _HotBadge extends StatelessWidget {
  const _HotBadge({
    required this.rank,
    required this.playCount,
    required this.compact,
  });

  final int rank;
  final int playCount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final topThree = rank <= 3;
    final foreground = topThree ? const Color(0xFFB54708) : kAccentDark;
    final label = 'TOP$rank · $playCount';
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: topThree
              ? const [Color(0xFFFFF1D6), Color(0xFFFFE0B2)]
              : const [Color(0xFFE8F8FC), Color(0xFFDDF4FA)],
        ),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: topThree
              ? const Color(0xFFFFB74D).withValues(alpha: .55)
              : kAccent.withValues(alpha: .24),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: compact ? 12 : 13,
            color: foreground,
          ),
          SizedBox(width: compact ? 2 : 3),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: compact ? 9.5 : 10.5,
              fontWeight: FontWeight.w800,
              height: 1,
              letterSpacing: .2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _SongActionMenuEntry {
  const _SongActionMenuEntry({
    required this.action,
    required this.icon,
    required this.label,
    required this.color,
    this.enabled = true,
  });

  final _SongTileAction action;
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
}

class _SongActionMenuHost extends StatefulWidget {
  const _SongActionMenuHost({
    required this.position,
    required this.entries,
    required this.onSelected,
  });

  final Offset position;
  final List<_SongActionMenuEntry> entries;
  final ValueChanged<_SongTileAction> onSelected;

  @override
  State<_SongActionMenuHost> createState() => _SongActionMenuHostState();
}

class _SongActionMenuHostState extends State<_SongActionMenuHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 118),
      reverseDuration: const Duration(milliseconds: 72),
    )..forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SongActionMenuOverlay(
      position: widget.position,
      entries: widget.entries,
      animation: controller,
      onSelected: widget.onSelected,
    );
  }
}

class _SongActionMenuOverlay extends StatelessWidget {
  const _SongActionMenuOverlay({
    required this.position,
    required this.entries,
    required this.animation,
    required this.onSelected,
  });

  static const double _width = 208;
  static const double _itemHeight = 42;
  static const double _padding = 8;
  static const double _screenMargin = 12;

  final Offset position;
  final List<_SongActionMenuEntry> entries;
  final Animation<double> animation;
  final ValueChanged<_SongTileAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final menuHeight = entries.length * _itemHeight + _padding * 2;
    final minLeft = media.viewPadding.left + _screenMargin;
    final maxLeft =
        size.width - media.viewPadding.right - _screenMargin - _width;
    final boundedMaxLeft = maxLeft < minLeft ? minLeft : maxLeft;
    final minTop = media.viewPadding.top + _screenMargin;
    final maxTop =
        size.height - media.viewPadding.bottom - _screenMargin - menuHeight;
    final boundedMaxTop = maxTop < minTop ? minTop : maxTop;
    final left = position.dx.clamp(minLeft, boundedMaxLeft);
    final preferredTop = position.dy + 2;
    final top = preferredTop > boundedMaxTop
        ? (position.dy - menuHeight - 2).clamp(minTop, boundedMaxTop)
        : preferredTop.clamp(minTop, boundedMaxTop);
    final alignment = Alignment(
      ((position.dx - left) / _width * 2 - 1).clamp(-1.0, 1.0).toDouble(),
      ((position.dy - top) / menuHeight * 2 - 1).clamp(-1.0, 1.0).toDouble(),
    );
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );
    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, .72, curve: Curves.easeOutCubic),
      reverseCurve: Curves.easeInCubic,
    );

    return Positioned(
      left: left.toDouble(),
      top: top.toDouble(),
      width: _width,
      child: TapRegion(
        onTapOutside: (_) => _dismissOpenSongActionMenu(),
        child: Material(
          color: Colors.transparent,
          child: FadeTransition(
            opacity: fade,
            child: AnimatedBuilder(
              animation: curved,
              builder: (context, child) {
                final value = curved.value;
                return Transform.translate(
                  offset: Offset(0, 7 * (1 - animation.value)),
                  child: Transform.scale(
                    scale: .91 + value * .09,
                    alignment: alignment,
                    child: child,
                  ),
                );
              },
              child: _SongActionMenuCard(
                entries: entries,
                onSelected: onSelected,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SongActionMenuCard extends StatelessWidget {
  const _SongActionMenuCard({required this.entries, required this.onSelected});

  final List<_SongActionMenuEntry> entries;
  final ValueChanged<_SongTileAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: .78)),
        boxShadow: [
          BoxShadow(
            color: kAccentDark.withValues(alpha: .10),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: .10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in entries)
                  _SongActionMenuButton(entry: entry, onSelected: onSelected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SongActionMenuButton extends StatefulWidget {
  const _SongActionMenuButton({required this.entry, required this.onSelected});

  final _SongActionMenuEntry entry;
  final ValueChanged<_SongTileAction> onSelected;

  @override
  State<_SongActionMenuButton> createState() => _SongActionMenuButtonState();
}

class _SongActionMenuButtonState extends State<_SongActionMenuButton> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final destructive = entry.color == const Color(0xFFE15B5B);
    final disabled = !entry.enabled;
    final accent = disabled ? kMuted : entry.color;
    final labelColor = disabled || destructive ? accent : kInk;
    final active = hovering && !disabled;
    return Semantics(
      button: true,
      enabled: !disabled,
      label: entry.label,
      child: MouseRegion(
        cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
        onEnter: (_) => setState(() => hovering = true),
        onExit: (_) => setState(() => hovering = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: disabled ? null : () => widget.onSelected(entry.action),
          child: AnimatedScale(
            scale: active ? 1.018 : 1,
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 105),
              curve: Curves.easeOutCubic,
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: active
                    ? accent.withValues(alpha: destructive ? .10 : .085)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: active
                      ? accent.withValues(alpha: destructive ? .16 : .13)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  AnimatedScale(
                    scale: active ? 1.08 : 1,
                    duration: const Duration(milliseconds: 105),
                    curve: Curves.easeOutBack,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 105),
                      curve: Curves.easeOutCubic,
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: accent.withValues(
                          alpha: active
                              ? destructive
                                    ? .17
                                    : .15
                              : disabled
                              ? .08
                              : .11,
                        ),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(entry.icon, color: accent, size: 17),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: labelColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: active ? 1 : 0,
                    duration: const Duration(milliseconds: 90),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: accent,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
