import 'package:flutter/material.dart';

import '../theme.dart';

class PlaybackModeFeedback extends StatelessWidget {
  const PlaybackModeFeedback({
    super.key,
    required this.visible,
    required this.label,
    required this.child,
  });

  final bool visible;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        child,
        Positioned(
          bottom: 46,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              child: AnimatedSlide(
                offset: visible ? Offset.zero : const Offset(0, .12),
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: kInk.withValues(alpha: .88),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .08),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .06),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
