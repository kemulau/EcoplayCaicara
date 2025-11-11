import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// ScrollBehavior que permite rolagem por toque, mouse, trackpad e stylus
/// em todas as plataformas, sem glow de overscroll.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.unknown,
      };

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Remove glow padrão para ficar consistente com UI de jogo
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // Clamping evita bounce exagerado em web/desktop
    final base = super.getScrollPhysics(context);
    return const ClampingScrollPhysics().applyTo(base);
  }
}

