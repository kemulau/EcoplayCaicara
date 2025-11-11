import 'package:flutter/material.dart';

class GameChrome extends ThemeExtension<GameChrome> {
  const GameChrome({
    // Button
    required this.buttonRadius,
    required this.buttonBorder,
    required this.buttonShadow,
    required this.buttonGradientTop,
    required this.buttonGradientBottom,
    // Panel
    required this.panelRadius,
    required this.panelBorder,
    required this.panelShadow,
    required this.panelBackground,
  });

  // PixelButton
  final double buttonRadius;
  final Color buttonBorder;
  final List<BoxShadow> buttonShadow;
  final Color buttonGradientTop;
  final Color buttonGradientBottom;

  // GamePanel
  final double panelRadius;
  final Color panelBorder;
  final List<BoxShadow> panelShadow;
  final Color panelBackground;

  static GameChrome fromScheme(ColorScheme scheme) {
    return GameChrome(
      buttonRadius: 12,
      buttonBorder: _shade(scheme.primary, .40),
      buttonShadow: [
        BoxShadow(
          offset: const Offset(0, 8),
          blurRadius: 18,
          color: Colors.black.withOpacity(0.35),
        )
      ],
      buttonGradientTop: _tint(scheme.primary, .18),
      buttonGradientBottom: _shade(scheme.primary, .20),
      panelRadius: 18,
      panelBorder: scheme.onSurface.withOpacity(.25),
      panelShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.35),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
      panelBackground: (scheme.brightness == Brightness.dark
              ? scheme.surface
              : scheme.background)
          .withOpacity(.86),
    );
  }

  @override
  GameChrome copyWith({
    double? buttonRadius,
    Color? buttonBorder,
    List<BoxShadow>? buttonShadow,
    Color? buttonGradientTop,
    Color? buttonGradientBottom,
    double? panelRadius,
    Color? panelBorder,
    List<BoxShadow>? panelShadow,
    Color? panelBackground,
  }) {
    return GameChrome(
      buttonRadius: buttonRadius ?? this.buttonRadius,
      buttonBorder: buttonBorder ?? this.buttonBorder,
      buttonShadow: buttonShadow ?? this.buttonShadow,
      buttonGradientTop: buttonGradientTop ?? this.buttonGradientTop,
      buttonGradientBottom: buttonGradientBottom ?? this.buttonGradientBottom,
      panelRadius: panelRadius ?? this.panelRadius,
      panelBorder: panelBorder ?? this.panelBorder,
      panelShadow: panelShadow ?? this.panelShadow,
      panelBackground: panelBackground ?? this.panelBackground,
    );
  }

  @override
  ThemeExtension<GameChrome> lerp(ThemeExtension<GameChrome>? other, double t) {
    if (other is! GameChrome) return this;
    return GameChrome(
      buttonRadius: lerpDouble(buttonRadius, other.buttonRadius, t),
      buttonBorder: Color.lerp(buttonBorder, other.buttonBorder, t)!,
      buttonShadow: other.buttonShadow, // simplificação
      buttonGradientTop: Color.lerp(buttonGradientTop, other.buttonGradientTop, t)!,
      buttonGradientBottom:
          Color.lerp(buttonGradientBottom, other.buttonGradientBottom, t)!,
      panelRadius: lerpDouble(panelRadius, other.panelRadius, t),
      panelBorder: Color.lerp(panelBorder, other.panelBorder, t)!,
      panelShadow: other.panelShadow,
      panelBackground: Color.lerp(panelBackground, other.panelBackground, t)!,
    );
  }
}

double lerpDouble(double a, double b, double t) => a + (b - a) * t;

Color _tint(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  final light = (hsl.lightness + amount).clamp(0.0, 1.0);
  return hsl.withLightness(light.toDouble()).toColor();
}

Color _shade(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  final light = (hsl.lightness - amount).clamp(0.0, 1.0);
  return hsl.withLightness(light.toDouble()).toColor();
}

