import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

class SideNavigation extends StatelessWidget {
  const SideNavigation({
    super.key,
    required this.current,
    required this.onChanged,
    this.canManageLibrary = false,
  });

  final MusicSection current;
  final ValueChanged<MusicSection> onChanged;
  final bool canManageLibrary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 178,
      decoration: const BoxDecoration(
        color: kSurface,
        border: Border(right: BorderSide(color: kLine)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 20, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.graphic_eq_rounded, color: kAccent, size: 30),
              const SizedBox(width: 10),
              Text('MusicFlow', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 28),
          _NavItem(
            icon: Icons.music_note_rounded,
            label: '音乐',
            section: MusicSection.music,
            current: current,
            onChanged: onChanged,
          ),
          _NavItem(
            icon: Icons.queue_music_rounded,
            label: '歌单',
            section: MusicSection.playlists,
            current: current,
            onChanged: onChanged,
          ),
          _NavItem(
            icon: Icons.search_rounded,
            label: '搜索',
            section: MusicSection.search,
            current: current,
            onChanged: onChanged,
          ),
          _NavItem(
            icon: Icons.cloud_download_rounded,
            label: canManageLibrary ? '曲库入库' : '我的下载',
            section: MusicSection.downloads,
            current: current,
            onChanged: onChanged,
          ),
          _NavItem(
            icon: Icons.person_outline_rounded,
            label: '我的',
            section: MusicSection.profile,
            current: current,
            onChanged: onChanged,
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.section,
    required this.current,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final MusicSection section;
  final MusicSection current;
  final ValueChanged<MusicSection> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = current == section;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: () => onChanged(section),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? kAccent.withValues(alpha: .1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: selected ? kAccentDark : kInk),
              const SizedBox(width: 12),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? kAccentDark : kInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MobileTabs extends StatelessWidget {
  const MobileTabs({
    super.key,
    required this.current,
    required this.onChanged,
    this.canManageLibrary = false,
  });

  final MusicSection current;
  final ValueChanged<MusicSection> onChanged;
  final bool canManageLibrary;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: kSurface,
        border: Border(top: BorderSide(color: kLine)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _MobileTab(
            icon: Icons.music_note_rounded,
            label: '音乐',
            section: MusicSection.music,
            current: current,
            onChanged: onChanged,
          ),
          _MobileTab(
            icon: Icons.queue_music_rounded,
            label: '歌单',
            section: MusicSection.playlists,
            current: current,
            onChanged: onChanged,
          ),
          _MobileTab(
            icon: Icons.search_rounded,
            label: '搜索',
            section: MusicSection.search,
            current: current,
            onChanged: onChanged,
          ),
          _MobileTab(
            icon: Icons.cloud_download_rounded,
            label: canManageLibrary ? '入库' : '下载',
            section: MusicSection.downloads,
            current: current,
            onChanged: onChanged,
          ),
          _MobileTab(
            icon: Icons.person_outline_rounded,
            label: '我的',
            section: MusicSection.profile,
            current: current,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _MobileTab extends StatelessWidget {
  const _MobileTab({
    required this.icon,
    required this.label,
    required this.section,
    required this.current,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final MusicSection section;
  final MusicSection current;
  final ValueChanged<MusicSection> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = current == section;
    return InkWell(
      onTap: () => onChanged(section),
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? kAccent : kMuted, size: 23),
            const SizedBox(height: 3),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? kAccent : kMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
