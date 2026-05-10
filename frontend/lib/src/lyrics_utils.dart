String firstLyricLine(String lyrics) {
  final lines = parseLyricLines(lyrics);
  return lines.isEmpty ? '' : lines.first;
}

String firstMetadataLine(String lyrics) {
  final lines = parseMetadataLines(lyrics);
  return lines.isEmpty ? '' : lines.first;
}

List<String> parseMetadataLines(String lyrics) {
  final normalized = lyrics.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final lines = <String>[];
  for (final rawLine in normalized.split('\n')) {
    final text = rawLine.replaceAll(RegExp(r'\[[^\]]+\]'), '').trim();
    if (text.isNotEmpty && isLyricMetadataLine(text)) {
      lines.add(text);
    }
  }
  return lines;
}

List<String> parseLyricLines(String lyrics) {
  final normalized = lyrics.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final lines = <String>[];
  for (final rawLine in normalized.split('\n')) {
    final text = rawLine.replaceAll(RegExp(r'\[[^\]]+\]'), '').trim();
    if (text.isNotEmpty && !isLyricMetadataLine(text)) {
      lines.add(text);
    }
  }
  return lines;
}

List<TimedLyricLine> parseTimedLyricLines(String lyrics) {
  final normalized = lyrics.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final timeTagPattern = RegExp(r'\[(\d{1,2}):(\d{1,2})(?:[\.:](\d+))?\]');
  final lines = <TimedLyricLine>[];
  for (final rawLine in normalized.split('\n')) {
    final matches = timeTagPattern.allMatches(rawLine).toList();
    final text = rawLine.replaceAll(RegExp(r'\[[^\]]+\]'), '').trim();
    if (text.isEmpty) {
      continue;
    }
    if (matches.isEmpty) {
      continue;
    }
    for (final match in matches) {
      final minutes = int.tryParse(match.group(1) ?? '') ?? 0;
      final seconds = int.tryParse(match.group(2) ?? '') ?? 0;
      final fraction = match.group(3) ?? '0';
      final milliseconds = fraction.length == 1
          ? (int.tryParse(fraction) ?? 0) * 100
          : fraction.length == 2
          ? (int.tryParse(fraction) ?? 0) * 10
          : int.tryParse(fraction.substring(0, 3)) ?? 0;
      lines.add(
        TimedLyricLine(
          time: Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: milliseconds,
          ),
          text: text,
        ),
      );
    }
  }
  lines.sort((a, b) => a.time.compareTo(b.time));
  return lines;
}

int currentLyricIndex(List<TimedLyricLine> lines, Duration position) {
  if (lines.isEmpty) {
    return -1;
  }
  for (var index = lines.length - 1; index >= 0; index--) {
    if (position >= lines[index].time) {
      return index;
    }
  }
  return -1;
}

bool isLyricMetadataLine(String text) {
  final normalized = text.replaceAll('：', ':').trim();
  const prefixes = [
    '作词',
    '作曲',
    '编曲',
    '制作人',
    '监制',
    '出品',
    '录音',
    '混音',
    '母带',
    '吉他',
    '贝斯',
    '鼓',
    '和声',
    'OP',
    'SP',
  ];
  return prefixes.any((prefix) => RegExp('^$prefix\\s*:').hasMatch(normalized));
}

class TimedLyricLine {
  const TimedLyricLine({required this.time, required this.text});

  final Duration time;
  final String text;
}
