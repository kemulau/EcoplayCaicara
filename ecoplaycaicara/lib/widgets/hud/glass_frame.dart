import 'package:flutter/material.dart';

/// Semi-transparent frosted glass frame used to wrap the gameplay viewport.
class GlassFrame extends StatelessWidget {
  const GlassFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(width: 4, color: Colors.white.withOpacity(0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 2),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
