import 'package:flutter/material.dart';

import '../theme.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.margin,
  });

  final IconData icon;
  final String message;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(22),
      decoration: cardDecoration(radius: 16),
      child: Row(
        children: [
          Icon(icon, color: kAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
