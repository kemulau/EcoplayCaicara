import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Animação de digitação para textos curtos (balões/popup).
/// - Exibe 1 caractere por vez com intervalo configurável.
/// - Emite um pequeno "click" do sistema a cada N caracteres (fallback cross‑platform).
/// - Oferece botão "Pular" para revelar instantaneamente.
class TypingText extends StatefulWidget {
  const TypingText({
    super.key,
    required this.text,
    this.charDelay = const Duration(milliseconds: 24),
    this.clickEvery = 3,
    this.onFinished,
    this.style,
    this.enableSound = true,
    this.onClick,
    this.onStart,
    this.controller,
    this.showSkipButton = true,
    this.onSkip,
  });

  final String text;
  final Duration charDelay;
  final int clickEvery; // quantos chars por click de som
  final VoidCallback? onFinished;
  final TextStyle? style;
  final bool enableSound;
  final VoidCallback? onClick;
  final VoidCallback? onStart;
  final TypingTextController? controller;
  final bool showSkipButton;
  final VoidCallback? onSkip;

  @override
  State<TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<TypingText> {
  String _shown = '';
  int _index = 0;
  Timer? _timer;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(_skip);
    _start();
  }

  void _start() {
    _timer?.cancel();
    if (widget.onStart != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onStart!.call();
      });
    }
    _timer = Timer.periodic(widget.charDelay, (t) {
      if (!mounted) return;
      if (_index >= widget.text.runes.length) {
        t.cancel();
        _finished = true;
        widget.onFinished?.call();
        return;
      }
      final runes = widget.text.runes.toList();
      setState(() {
        _shown = String.fromCharCodes(runes.sublist(0, _index + 1));
        _index++;
      });
      if (widget.enableSound && _index % widget.clickEvery == 0) {
        if (widget.onClick != null) {
          widget.onClick!();
        } else {
          SystemSound.play(SystemSoundType.click);
        }
      }
    });
  }

  void _skip() {
    _timer?.cancel();
    setState(() {
      _shown = widget.text;
      _index = widget.text.length;
      _finished = true;
    });
    widget.onFinished?.call();
  }

  @override
  void didUpdateWidget(TypingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      widget.controller?._attach(_skip);
    }
    if (oldWidget.text != widget.text) {
      _index = 0;
      _shown = '';
      _finished = false;
      _start();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _shown,
          style: widget.style ?? Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        if (widget.showSkipButton)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                if (widget.onSkip != null) {
                  widget.onSkip!();
                } else {
                  _skip();
                }
              },
              child: Text(
                'Pular',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      decoration: TextDecoration.underline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
          ),
      ],
    );
  }
}

class TypingTextController {
  VoidCallback? _skipImpl;
  void _attach(VoidCallback f) => _skipImpl = f;
  void skip() => _skipImpl?.call();
}

