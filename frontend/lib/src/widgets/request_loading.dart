import 'package:flutter/material.dart';

import '../theme.dart';

class RequestLoadingBanner extends StatelessWidget {
  const RequestLoadingBanner({super.key, this.message = '正在处理请求…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        offset: Offset.zero,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .96),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFDDEFF4)),
              boxShadow: [
                BoxShadow(
                  color: kAccent.withValues(alpha: .16),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  message,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: kInk,
                    fontWeight: FontWeight.w800,
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

class InlineRequestLoading extends StatelessWidget {
  const InlineRequestLoading({super.key, this.message = '加载中…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Center(child: RequestLoadingBanner(message: message)),
    );
  }
}
