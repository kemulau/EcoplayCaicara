import 'package:flutter/material.dart';

import '../narrable.dart';

class StatPill extends StatelessWidget {
  const StatPill({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.semanticLabel,
    this.height = 52,
    this.minWidth = 160,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? semanticLabel;
  final double height;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final String narrableText = semanticLabel ?? '$label $value';

    return Narrable(
      text: narrableText,
      tooltip: narrableText,
      child: Container(
        constraints: BoxConstraints(minWidth: minWidth, minHeight: height),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(
            color: scheme.onSurface.withOpacity(0.08),
            width: 1.6,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              height: height - 20,
              width: height - 20,
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular((height - 20) / 2),
              ),
              child: Icon(
                icon,
                size: (height - 26).clamp(18, 26),
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$label:',
                    style: textTheme.labelLarge?.copyWith(
                      color: scheme.onSurface.withOpacity(0.72),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  Text(
                    value,
                    style: textTheme.titleMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
