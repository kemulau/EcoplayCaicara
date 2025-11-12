import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'game_frame.dart';
import 'narrable.dart';

/// Tela de carregamento genérica com barra de progresso simulada.
class GameLoadingScreen extends StatefulWidget {
  const GameLoadingScreen({
    super.key,
    required this.title,
    required this.onReady,
    required this.onLoad,
    required this.backgroundAsset,
    this.mobileBackgroundAsset,
    this.minDuration = const Duration(milliseconds: 1400),
    this.maxLoadDuration = const Duration(seconds: 10),
  });

  final String title;
  final WidgetBuilder onReady;
  final Future<void> Function() onLoad;
  final Duration minDuration;
  final Duration maxLoadDuration;
  final String backgroundAsset;
  final String? mobileBackgroundAsset;

  @override
  State<GameLoadingScreen> createState() => _GameLoadingScreenState();
}

class _GameLoadingScreenState extends State<GameLoadingScreen> {
  static final Random _rand = Random();

  double _progress = 0.08;
  Timer? _progressTimer;
  bool _loadCompleted = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _kickOffLoad();
    _startProgressLoop();
  }

  void _kickOffLoad() {
    Future.wait<void>([
      _runLoadWithTimeout(),
      Future<void>.delayed(widget.minDuration),
    ]).then(
      (_) => _markLoadCompleted(),
      onError: (Object error, StackTrace stack) {
        if (kDebugMode) {
          debugPrint('GameLoadingScreen: falha durante carregamento: $error');
          debugPrintStack(stackTrace: stack);
        }
        _markLoadCompleted();
      },
    );
  }

  Future<void> _runLoadWithTimeout() async {
    try {
      await widget.onLoad().timeout(
            widget.maxLoadDuration,
            onTimeout: () async {},
          );
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint('GameLoadingScreen: erro no onLoad: $error');
        debugPrintStack(stackTrace: stack);
      }
    }
  }

  void _markLoadCompleted() {
    if (!mounted) return;
    setState(() => _loadCompleted = true);
  }

  void _startProgressLoop() {
    _progressTimer =
        Timer.periodic(const Duration(milliseconds: 110), (timer) {
      final double target = _loadCompleted ? 1.0 : 0.92;
      if (!mounted) return;

      final double remaining = (target - _progress).clamp(0.0, 1.0);
      double step;
      if (remaining <= 0.002) {
        step = remaining;
      } else {
        final double jitter =
            _loadCompleted ? _rand.nextDouble() * 0.05 : _rand.nextDouble() * 0.02;
        step = (_loadCompleted ? 0.08 : 0.03) + jitter;
        step = step.clamp(0.005, remaining);
      }

      final double nextProgress = (_progress + step).clamp(0.0, target);
      setState(() => _progress = nextProgress);

      if (_loadCompleted && nextProgress >= 0.999) {
        timer.cancel();
        Future<void>.delayed(const Duration(milliseconds: 260), _finish);
      }
    });
  }

  void _finish() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: widget.onReady),
    );
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percent = (_progress * 100).clamp(0, 100).toStringAsFixed(0);
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return GameScaffold(
      title: widget.title,
      fill: false,
      backgroundAsset: widget.backgroundAsset,
      mobileBackgroundAsset: widget.mobileBackgroundAsset,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.35), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Narrable.text(
                'Preparando o território...',
                style: textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 14,
                  backgroundColor: Colors.white.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.secondary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Narrable.text(
                    _loadCompleted ? 'Tudo pronto!' : 'Carregando recursos...',
                    readOnFocus: false,
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  Narrable.text(
                    '$percent%',
                    readOnFocus: false,
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
