import 'dart:async';

import 'package:flutter/material.dart';

import '../services/tts_service.dart';
import '../services/user_prefs.dart';

/// Wraps a widget with tooltip, semantics, and optional TTS narration support.
class Narrable extends StatelessWidget {
  const Narrable({
    super.key,
    required this.child,
    required this.text,
    this.tooltip,
    this.category = 'ui',
    this.readOnFocus = true,
  });

  factory Narrable.text(
    String text, {
    Key? key,
    String? tooltip,
    String category = 'ui',
    bool readOnFocus = true,
    TextStyle? style,
    TextAlign? textAlign,
    TextDirection? textDirection,
    Locale? locale,
    bool? softWrap,
    TextOverflow? overflow,
    double? textScaleFactor,
    int? maxLines,
    String? semanticsLabel,
    TextWidthBasis? textWidthBasis,
    TextHeightBehavior? textHeightBehavior,
    StrutStyle? strutStyle,
  }) {
    return Narrable(
      key: key,
      text: text,
      tooltip: tooltip,
      category: category,
      readOnFocus: readOnFocus,
      child: Text(
        text,
        style: style,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaleFactor: textScaleFactor,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        strutStyle: strutStyle,
      ),
    );
  }

  final Widget child;
  final String text;
  final String? tooltip;
  final String category;
  final bool readOnFocus;

  @override
  Widget build(BuildContext context) {
    final prefs = UserPrefs.instance;
    unawaited(prefs.ensureLoaded());

    return ValueListenableBuilder<bool>(
      valueListenable: prefs.showTooltipsNotifier,
      builder: (context, showTooltips, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: TtsService.instance.uiNarrationEnabledNotifier,
          builder: (context, canNarrateUi, __) {
            Widget wrapped = Focus(
              onFocusChange: (focused) {
                if (focused && readOnFocus) {
                  _speakIfEnabled(canNarrateUi);
                }
              },
              child: MouseRegion(
                onEnter: (_) => _speakIfEnabled(canNarrateUi),
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onLongPress: () => _speakIfEnabled(canNarrateUi),
                  child: Semantics(label: text, child: child),
                ),
              ),
            );

            if (showTooltips) {
              final String tooltipMessage =
                  (tooltip == null || tooltip!.trim().isEmpty)
                  ? text
                  : tooltip!;
              wrapped = Tooltip(message: tooltipMessage, child: wrapped);
            }

            return wrapped;
          },
        );
      },
    );
  }

  void _speakIfEnabled(bool canNarrate) {
    if (!canNarrate) {
      return;
    }
    unawaited(TtsService.instance.ensureUnlockedByUserGesture());
    final String sanitized = TtsService.instance.sanitize(text);
    if (sanitized.isEmpty) {
      return;
    }
    TtsService.instance.speakQueue(<String>[sanitized], category: category);
  }
}
