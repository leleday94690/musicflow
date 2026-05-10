import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'artwork.dart';

class EditSongDialog extends StatefulWidget {
  const EditSongDialog({super.key, required this.song, required this.onUpdate});

  final Song song;
  final Future<Song> Function(
    String title,
    String artist,
    String album,
    String lyrics,
    int lyricsOffsetMs,
  )
  onUpdate;

  @override
  State<EditSongDialog> createState() => _EditSongDialogState();
}

class _EditSongDialogState extends State<EditSongDialog> {
  late final TextEditingController titleController;
  late final TextEditingController artistController;
  late final TextEditingController albumController;
  late final TextEditingController lyricsController;
  late final TextEditingController lyricsOffsetController;
  bool saving = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.song.title);
    artistController = TextEditingController(text: widget.song.artist);
    albumController = TextEditingController(text: widget.song.album);
    lyricsController = TextEditingController(text: widget.song.lyrics);
    lyricsOffsetController = TextEditingController(
      text: widget.song.lyricsOffsetMs.toString(),
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    artistController.dispose();
    albumController.dispose();
    lyricsController.dispose();
    lyricsOffsetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: viewInsets),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            decoration: cardDecoration(radius: 28),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Artwork(song: widget.song, size: 62, radius: 18),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '编辑歌曲信息',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '修正歌名、歌手、专辑与歌词，让音乐库更准确',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _EditSongField(
                    controller: titleController,
                    label: '歌曲名',
                    icon: Icons.music_note_rounded,
                    enabled: !saving,
                  ),
                  const SizedBox(height: 12),
                  _EditSongField(
                    controller: artistController,
                    label: '歌手',
                    icon: Icons.person_rounded,
                    enabled: !saving,
                  ),
                  const SizedBox(height: 12),
                  _EditSongField(
                    controller: albumController,
                    label: '专辑',
                    icon: Icons.album_rounded,
                    enabled: !saving,
                  ),
                  const SizedBox(height: 12),
                  _EditSongField(
                    controller: lyricsController,
                    label: '歌词',
                    icon: Icons.lyrics_rounded,
                    enabled: !saving,
                    minLines: 5,
                    maxLines: 9,
                  ),
                  const SizedBox(height: 12),
                  _EditSongField(
                    controller: lyricsOffsetController,
                    label: '歌词偏移（毫秒，正数提前显示）',
                    icon: Icons.tune_rounded,
                    enabled: !saving,
                    keyboardType: TextInputType.number,
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
                        color: const Color(0xFFE15B5B).withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFE15B5B).withValues(alpha: .18),
                        ),
                      ),
                      child: Text(
                        errorMessage!,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: const Color(0xFFE15B5B),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: saving
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: saving ? null : _save,
                          child: saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('保存信息'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final title = titleController.text.trim();
    final artist = artistController.text.trim();
    final album = albumController.text.trim();
    final lyrics = lyricsController.text.trim();
    final lyricsOffsetMs =
        int.tryParse(lyricsOffsetController.text.trim()) ??
        widget.song.lyricsOffsetMs;
    if (title.isEmpty || artist.isEmpty) {
      setState(() => errorMessage = '歌曲名和歌手不能为空');
      return;
    }
    setState(() {
      saving = true;
      errorMessage = null;
    });
    try {
      final updated = await widget.onUpdate(
        title,
        artist,
        album,
        lyrics,
        lyricsOffsetMs,
      );
      if (mounted) {
        Navigator.of(context).pop(updated);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          saving = false;
          errorMessage =
              '保存失败：${error.toString().replaceFirst('Exception: ', '')}';
        });
      }
    }
  }
}

class _EditSongField extends StatelessWidget {
  const _EditSongField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.enabled,
    this.minLines = 1,
    this.maxLines = 1,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool enabled;
  final int minLines;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: Theme.of(
        context,
      ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 19),
        filled: true,
        fillColor: const Color(0xFFF8FBFD),
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
          borderSide: const BorderSide(color: kAccent, width: 1.4),
        ),
      ),
    );
  }
}
