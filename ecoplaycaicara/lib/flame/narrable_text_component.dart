import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../services/tts_service.dart';
import '../services/user_prefs.dart';

/// TextComponent com suporte a tooltip simples e narração via TTS.
class NarrableTextComponent extends TextComponent
    with HoverCallbacks, TapCallbacks {
  NarrableTextComponent({
    required super.text,
    super.textRenderer,
    super.position,
    super.size,
    super.scale,
    super.anchor,
    super.angle,
    super.priority,
    this.tooltip,
    this.spokenText,
    this.category = 'ui',
    this.readOnShow = true,
    Vector2? tooltipOffset,
    this.tooltipDuration = 1.8,
    TextPaint? tooltipTextPaint,
  }) : tooltipOffset = tooltipOffset ?? Vector2(0, -24),
       _tooltipPaint = tooltipTextPaint;

  final String? tooltip;
  final String? spokenText;
  final String category;
  final bool readOnShow;
  final Vector2 tooltipOffset;
  final double tooltipDuration;
  final TextPaint? _tooltipPaint;

  double _tooltipTimer = 0;
  bool _tooltipVisible = false;
  String get _tooltipMessage => tooltip ?? text;
  String get _spokenMessage => spokenText ?? _tooltipMessage;

  TextPaint? _resolvedTooltipPaint;

  @override
  void onMount() {
    super.onMount();
    unawaited(_handleInteraction(triggerNarration: readOnShow));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_tooltipVisible) {
      _tooltipTimer -= dt;
      if (_tooltipTimer <= 0) {
        _tooltipVisible = false;
        _tooltipTimer = 0;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!_tooltipVisible) {
      return;
    }
    final String message = _tooltipMessage;
    if (message.trim().isEmpty) {
      return;
    }
    final paint = _resolvedTooltipPaint ??= _resolveTooltipPaint();
    final Vector2 offset = tooltipOffset;
    paint.render(canvas, message, Vector2(offset.x, offset.y));
  }

  @override
  void onHoverEnter() {
    _handleInteraction();
    super.onHoverEnter();
  }

  @override
  void onHoverExit() {
    _tooltipVisible = false;
    super.onHoverExit();
  }

  @override
  void onTapDown(TapDownEvent event) {
    _handleInteraction();
    super.onTapDown(event);
  }

  Future<void> _handleInteraction({bool triggerNarration = true}) async {
    final prefs = UserPrefs.instance;
    await prefs.ensureLoaded();

    if (prefs.showTooltips) {
      _activateTooltip();
    }
    if (!triggerNarration) {
      return;
    }
    if (!prefs.ttsReadUi || !prefs.ttsEnabled) {
      return;
    }
    await TtsService.instance.ensureUnlockedByUserGesture();
    final String sanitized = TtsService.instance
        .sanitize(_spokenMessage)
        .trim();
    if (sanitized.isEmpty) {
      return;
    }
    unawaited(
      TtsService.instance.speakQueue(<String>[sanitized], category: category),
    );
  }

  void _activateTooltip() {
    if (_tooltipMessage.trim().isEmpty) {
      return;
    }
    _tooltipVisible = true;
    _tooltipTimer = tooltipDuration;
  }

  TextPaint _resolveTooltipPaint() {
    if (_tooltipPaint != null) {
      return _tooltipPaint!;
    }
    final TextStyle baseStyle = (() {
      final renderer = textRenderer;
      if (renderer is TextPaint) {
        return renderer.style;
      }
      return const TextStyle(fontSize: 12);
    })().copyWith(color: Colors.white, fontWeight: FontWeight.w600);
    return TextPaint(style: baseStyle);
  }
}
