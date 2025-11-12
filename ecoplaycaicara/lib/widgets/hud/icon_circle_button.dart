import 'package:flutter/material.dart';

import '../narrable.dart';

class IconCircleButton extends StatelessWidget {
  const IconCircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.semanticLabel,
    this.size = 44,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final String? semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final double iconSize = (size * 0.48).clamp(18, 26);

    return Narrable(
      text: semanticLabel ?? tooltip ?? '',
      tooltip: tooltip,
      readOnFocus: false,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: Ink(
          height: size,
          width: size,
          decoration: BoxDecoration(
            color: scheme.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: scheme.onSurface.withOpacity(0.12),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.14),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Icon(icon, size: iconSize, color: scheme.onSurface),
          ),
        ),
      ),
    );
  }
}
