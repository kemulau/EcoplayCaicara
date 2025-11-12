import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/theme_provider.dart';
import '../../../widgets/game_frame.dart';
import '../../../widgets/pixel_button.dart';
import '../../../theme/game_chrome.dart';

import 'game_over_card.dart';
import 'missao_reciclagem_game.dart';
import 'missao_reciclagem_hud.dart';

class MissaoReciclagemGameScreen extends StatefulWidget {
  const MissaoReciclagemGameScreen({super.key});

  @override
  State<MissaoReciclagemGameScreen> createState() =>
      _MissaoReciclagemGameScreenState();
}

class _MissaoReciclagemGameScreenState
    extends State<MissaoReciclagemGameScreen> {
  late final MissaoReciclagemGame _game;
  bool _didPrecache = false;

  @override
  void initState() {
    super.initState();
    _game = MissaoReciclagemGame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _game.resetGame();
      _game.pauseEngine();
      if (!_game.overlays.isActive('StartGate')) {
        _game.overlays.add('StartGate');
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecache) return;
    _didPrecache = true;
    unawaited(
      precacheImage(
        const AssetImage(
          'assets/games/missao-reciclagem/background-reciclagem.png',
        ),
        context,
      ),
    );
    unawaited(
      precacheImage(
        const AssetImage(
          'assets/games/missao-reciclagem/background-missao-mobile.png',
        ),
        context,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = context.watch<ThemeProvider>().reduceMotion;
    _game.updateReduceMotion(reduceMotion);

    final baseTheme = Theme.of(context);
    final chrome = baseTheme.extension<GameChrome>();
    final customChrome = chrome?.copyWith(
      panelBackground: Colors.white.withOpacity(0.08),
      panelBorder: Colors.white.withOpacity(0.12),
      panelBorderWidth: 5,
      panelShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.28),
          blurRadius: 22,
          offset: const Offset(0, 16),
        ),
      ],
    );
    final extensions = baseTheme.extensions.values.toList(growable: true);
    if (customChrome != null) {
      extensions.removeWhere((ext) => ext is GameChrome);
      extensions.add(customChrome);
    }

    final widgetTree = GameScaffold(
      title: 'Missão Reciclagem',
      backgroundAsset:
          'assets/games/missao-reciclagem/background-reciclagem.png',
      mobileBackgroundAsset:
          'assets/games/missao-reciclagem/background-missao-mobile.png',
      panelPadding: EdgeInsets.zero,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(constraints.maxWidth, constraints.maxHeight);
                  final useMobile =
                      size.width <= 720 || size.height > size.width;
                  final asset = useMobile
                      ? 'assets/games/missao-reciclagem/background-missao-mobile.png'
                      : 'assets/games/missao-reciclagem/background-reciclagem.png';
                  return Image.asset(asset, fit: BoxFit.cover);
                },
              ),
              GameWidget(
                game: _game,
                overlayBuilderMap: {
                  'Hud': (context, game) => MissaoReciclagemHud(
                        game: game as MissaoReciclagemGame,
                      ),
                  'GameOver': (context, game) =>
                      MissaoReciclagemGameOverCard(
                        game: game as MissaoReciclagemGame,
                      ),
                  'StartGate': (context, game) =>
                      _StartGateOverlay(game as MissaoReciclagemGame),
                },
                initialActiveOverlays: const ['Hud', 'StartGate'],
              ),
            ],
          ),
        ),
      ),
    );

    if (customChrome != null) {
      return Theme(
        data: baseTheme.copyWith(extensions: extensions),
        child: widgetTree,
      );
    }

    return widgetTree;
  }
}

class _StartGateOverlay extends StatefulWidget {
  const _StartGateOverlay(this.game);

  final MissaoReciclagemGame game;

  @override
  State<_StartGateOverlay> createState() => _StartGateOverlayState();
}

class _StartGateOverlayState extends State<_StartGateOverlay> {
  bool _starting = false;
  String? _error;

  Future<void> _handleStart() async {
    if (_starting) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      try {
        await widget.game.ensureAudioUnlocked().timeout(
              const Duration(seconds: 4),
              onTimeout: () async {},
            );
      } catch (_) {}
      try {
        await widget.game.playClick().timeout(
              const Duration(milliseconds: 800),
              onTimeout: () async {},
            );
      } catch (_) {}
      widget.game.resetGame();
      widget.game.startRound();
      widget.game.resumeEngine();
      widget.game.overlays.remove('StartGate');
    } catch (e) {
      setState(() {
        _error = 'Falha ao iniciar. Tente novamente.';
      });
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double maxWidth = MediaQuery.of(context).size.width;
    final double buttonWidth = (maxWidth * 0.75).clamp(220.0, 360.0);

    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color cardBackground = isDark
        ? const Color(0xFF21140C).withOpacity(0.96)
        : Colors.white.withOpacity(0.98);
    final Color borderColor = isDark ? const Color(0xFF9F6630) : Colors.brown;
    final Color titleColor = isDark ? const Color(0xFFEAD0AE) : Colors.brown;
    final Color bodyColor = isDark ? const Color(0xFFCBA57F) : Colors.black87;
    final Color shadowColor =
        isDark ? Colors.black.withOpacity(0.65) : Colors.black.withOpacity(0.5);

    return Container(
      color: Colors.transparent,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 4),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                offset: const Offset(4, 4),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pronto para reciclar?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Clique em Iniciar para começar a separar os resíduos.\nNo navegador, isso garante que áudio e animações sejam habilitados corretamente.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: bodyColor),
              ),
              const SizedBox(height: 20),
              PixelButton(
                label: '▶ Iniciar',
                width: buttonWidth,
                onPressed: _handleStart,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
