import 'package:flutter/material.dart';

class GameStyles extends ThemeExtension<GameStyles> {
  const GameStyles({
    required this.tutorialBody,
    required this.hint,
    required this.link,
  });

  final TextStyle tutorialBody;
  final TextStyle hint;
  final TextStyle link;

  @override
  GameStyles copyWith({TextStyle? tutorialBody, TextStyle? hint, TextStyle? link}) {
    return GameStyles(
      tutorialBody: tutorialBody ?? this.tutorialBody,
      hint: hint ?? this.hint,
      link: link ?? this.link,
    );
  }

  @override
  GameStyles lerp(ThemeExtension<GameStyles>? other, double t) {
    if (other is! GameStyles) return this;
    return GameStyles(
      tutorialBody: TextStyle.lerp(tutorialBody, other.tutorialBody, t)!,
      hint: TextStyle.lerp(hint, other.hint, t)!,
      link: TextStyle.lerp(link, other.link, t)!,
    );
  }

  static GameStyles fromScheme(ColorScheme scheme, {String? fontFamily}) {
    return GameStyles(
      tutorialBody: TextStyle(
        fontSize: 14,
        color: scheme.onSurface,
        height: 1.3,
        fontFamily: fontFamily,
      ),
      hint: TextStyle(
        fontSize: 10,
        color: scheme.onSurface.withOpacity(0.75),
        fontFamily: fontFamily,
      ),
      link: TextStyle(
        fontSize: 12,
        color: scheme.primary,
        decoration: TextDecoration.underline,
        fontFamily: fontFamily,
      ),
    );
  }
}
