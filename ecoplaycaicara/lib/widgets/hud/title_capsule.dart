import 'package:flutter/material.dart';

import '../../theme/game_chrome.dart';
import '../narrable.dart';

/// Gradient capsule used at the top of the game panels.
///
/// Extracted from the original Toca do Caranguejo implementation so it can be
/// reused by other games (e.g. Missão Reciclagem) with pixel parity.
class TitleCapsule extends StatelessWidget {
  const TitleCapsule({
    super.key,
    required this.text,
    this.maxWidth = 420,
    this.minWidth = 220,
    this.trailing,
  });

  final String text;
  final double maxWidth;
  final double minWidth;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chrome = Theme.of(context).extension<GameChrome>();
    final width = MediaQuery.sizeOf(context).width;

    String displayText = text;
    if (width < 520 && text.contains(' ')) {
      final parts = text.split(' ');
      if (parts.length > 1) {
        displayText =
            '${parts.sublist(0, parts.length - 1).join(' ')}\n${parts.last}';
      }
    }

    final bool wrapped = displayText.contains('\n');

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth, minWidth: minWidth),
      child: Stack(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 18,
              vertical: wrapped ? 12 : 10,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(chrome?.panelRadius ?? 16),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  (chrome?.buttonGradientTop ??
                      scheme.primary.withOpacity(0.92)),
                  (chrome?.buttonGradientBottom ??
                      scheme.primary.withOpacity(0.82)),
                ],
              ),
              boxShadow:
                  chrome?.panelShadow ??
                  [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.08),
                      blurRadius: 0,
                      offset: const Offset(0, 1),
                    ),
                  ],
            ),
            child: Center(
              child: Narrable(
                text: text,
                tooltip: text,
                child: Text(
                  displayText,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: scheme.onPrimary,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          if (trailing != null)
            Positioned(
              right: 6,
              top: wrapped ? 6 : 4,
              child: SizedBox(height: 32, width: 32, child: trailing!),
            ),
        ],
      ),
    );
  }
}
