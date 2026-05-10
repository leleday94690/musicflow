import 'package:flutter/material.dart';

import '../theme.dart';

class SlidingTabs extends StatelessWidget {
  const SlidingTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.counts,
    this.maxWidth = 520,
    this.compact = false,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<int?>? counts;
  final double maxWidth;
  final bool compact;

  int? _countAt(int index) {
    final list = counts;
    if (list == null || index < 0 || index >= list.length) {
      return null;
    }
    return list[index];
  }

  String _formatCount(int value) {
    if (value >= 10000) {
      final v = (value / 1000).round() / 10;
      return '${v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1)}w';
    }
    if (value >= 1000) {
      final v = (value / 100).round() / 10;
      return '${v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1)}k';
    }
    return '$value';
  }

  @override
  Widget build(BuildContext context) {
    final safeIndex = selectedIndex.clamp(0, labels.length - 1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < maxWidth
            ? constraints.maxWidth
            : maxWidth;
        return SizedBox(
          width: width,
          height: compact ? 38 : 48,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF2F7FA),
              borderRadius: BorderRadius.circular(compact ? 14 : 16),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedAlign(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment(
                    -1 + (2 * safeIndex / (labels.length - 1)),
                    0,
                  ),
                  child: FractionallySizedBox(
                    widthFactor: 1 / labels.length,
                    heightFactor: 1,
                    child: Padding(
                      padding: EdgeInsets.all(compact ? 3 : 4),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: kAccent,
                          borderRadius: BorderRadius.circular(
                            compact ? 11 : 13,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: kAccent.withValues(alpha: 0.24),
                              blurRadius: compact ? 10 : 16,
                              offset: Offset(0, compact ? 4 : 8),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < labels.length; i++)
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(
                            compact ? 14 : 16,
                          ),
                          onTap: () => onSelected(i),
                          child: _SlidingTabContent(
                            label: labels[i],
                            count: _countAt(i),
                            countLabel: _countAt(i) == null
                                ? null
                                : _formatCount(_countAt(i)!),
                            selected: i == safeIndex,
                            compact: compact,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SlidingTabContent extends StatelessWidget {
  const _SlidingTabContent({
    required this.label,
    required this.count,
    required this.countLabel,
    required this.selected,
    required this.compact,
  });

  final String label;
  final int? count;
  final String? countLabel;
  final bool selected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final showBadge =
        selected && count != null && count! > 0 && countLabel != null;
    final labelColor = selected ? Colors.white : kMuted;
    final labelStyle = Theme.of(context).textTheme.labelMedium!.copyWith(
      color: labelColor,
      fontSize: compact ? 12.5 : null,
      fontWeight: FontWeight.w800,
      height: 1,
    );
    final textWidget = AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 180),
      style: labelStyle,
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        Center(child: textWidget),
        if (showBadge)
          Positioned(
            top: compact ? -2 : -3,
            right: compact ? 2 : 4,
            child: _SlidingTabBadge(label: countLabel!, compact: compact),
          ),
      ],
    );
  }
}

class _SlidingTabBadge extends StatelessWidget {
  const _SlidingTabBadge({required this.label, required this.compact});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: .85, end: 1).animate(animation),
          alignment: Alignment.topRight,
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey(label),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 5 : 6,
          vertical: compact ? 1.5 : 2,
        ),
        constraints: BoxConstraints(
          minWidth: compact ? 16 : 18,
          minHeight: compact ? 14 : 16,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: kAccent, width: 1),
          boxShadow: [
            BoxShadow(
              color: kAccentDark.withValues(alpha: .18),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: TextStyle(
            color: kAccentDark,
            fontSize: compact ? 9.5 : 10.5,
            fontWeight: FontWeight.w800,
            height: 1,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
