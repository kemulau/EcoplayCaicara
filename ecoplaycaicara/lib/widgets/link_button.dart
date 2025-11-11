import 'package:flutter/material.dart';
import '../theme/game_styles.dart';

class LinkButton extends StatelessWidget {
  const LinkButton({super.key, required this.label, this.onPressed, this.alignment = Alignment.centerRight});
  final String label;
  final VoidCallback? onPressed;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final styles = Theme.of(context).extension<GameStyles>();
    return Align(
      alignment: alignment,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: styles?.link.color,
          overlayColor: (styles?.link.color ?? Theme.of(context).colorScheme.primary)
              .withOpacity(0.08),
          padding: EdgeInsets.zero,
          minimumSize: const Size(32, 28),
        ),
        child: Text(label, style: styles?.link),
      ),
    );
  }
}
