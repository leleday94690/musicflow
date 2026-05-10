import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

class Artwork extends StatelessWidget {
  const Artwork({
    super.key,
    required this.song,
    this.size = 48,
    this.radius = 12,
  });

  final Song song;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final accent = song.colors.isEmpty ? kAccent : song.colors.last;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kAccent.withValues(alpha: .12), Colors.white],
        ),
        border: Border.all(color: kAccent.withValues(alpha: .10)),
        boxShadow: [
          BoxShadow(
            color: kInk.withValues(alpha: .045),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -size * .24,
            top: -size * .2,
            child: Container(
              width: size * .74,
              height: size * .74,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: size * .18,
            bottom: size * .18,
            right: size * .18,
            child: Container(
              height: math.max(2, size * .055),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .28),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Center(
            child: Container(
              width: size * .52,
              height: size * .52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .72),
                border: Border.all(color: Colors.white.withValues(alpha: .80)),
              ),
              child: Icon(
                Icons.music_note_rounded,
                color: kAccentDark,
                size: size * .30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PlaylistCover extends StatelessWidget {
  const PlaylistCover({
    super.key,
    required this.colors,
    required this.icon,
    this.size = 96,
    this.radius = 18,
  });

  final List<Color> colors;
  final IconData icon;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (size.isFinite) {
      return SizedBox(width: size, height: size, child: _buildContent(size));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final effective = [
          constraints.maxWidth,
          constraints.maxHeight,
        ].where((value) => value.isFinite).fold<double>(96, math.min);
        return _buildContent(effective);
      },
    );
  }

  Widget _buildContent(double effective) {
    final base = colors.isEmpty
        ? const [Color(0xFF6EC9FF), Color(0xFF1E5BFF)]
        : colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: base,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.7, -0.8),
                radius: 1.1,
                colors: [
                  Colors.white.withValues(alpha: .28),
                  Colors.white.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          Positioned(
            right: -effective * .25,
            bottom: -effective * .25,
            child: Container(
              width: effective * .6,
              height: effective * .6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .08),
              ),
            ),
          ),
          Center(
            child: Container(
              width: effective * .5,
              height: effective * .5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: .45),
                  width: 1.2,
                ),
              ),
              child: Icon(icon, color: Colors.white, size: effective * .28),
            ),
          ),
        ],
      ),
    );
  }
}
