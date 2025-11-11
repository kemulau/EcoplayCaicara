import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';

import '../../../widgets/pixel_button.dart';
import '../../../widgets/game_frame.dart';
import '../../../widgets/defeso_end_toast.dart'; // toast do fim do defeso
import '../../../theme/theme_provider.dart';

import 'flame_game.dart';
import 'start.dart';
import 'debug_burrows_overlay.dart';

// [A11Y] painel reutilizável igual ao do cadastro
import '../../../widgets/a11y_panel.dart'; // [A11Y]

class TocaGameScreen extends StatefulWidget {
  const TocaGameScreen({super.key, this.skipStartGate = false});
  final bool skipStartGate;

  @override
  State<TocaGameScreen> createState() => _TocaGameScreenState();
}

class _TocaGameScreenState extends State<TocaGameScreen> {
  late final CrabGame _game;

  @override
  void initState() {
    super.initState();
    _game = CrabGame(
      onGameOver: () {
        if (!mounted) return;
        _game.overlays.add('GameOver');
      },
    );
    unawaited(CrabGame.preloadImages());
    unawaited(CrabGame.preloadAudio());

    // Pausa o jogo inicialmente e mostra o gate de início
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        precacheImage(
          const AssetImage('assets/games/toca-do-caranguejo/background.png'),
          context,
        ),
      );
      unawaited(
        precacheImage(
          const AssetImage(
            'assets/games/toca-do-caranguejo/background-mobile.png',
          ),
          context,
        ),
      );
      if (widget.skipStartGate) {
        _game.startGame();
        _game.resumeEngine();
      } else {
        _game.pauseEngine();
        if (!_game.overlays.isActive('StartGate')) {
          _game.overlays.add('StartGate');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = context.watch<ThemeProvider>().reduceMotion;
    _game.updateReduceMotion(reduceMotion);
    return GameScaffold(
      title: 'Toca do Caranguejo',
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Fundo estático (evita flicker na Web)
              LayoutBuilder(
                builder: (context, _) {
                  final size = MediaQuery.of(context).size;
                  final useMobile =
                      size.width <= 720 || size.height > size.width;
                  final asset = useMobile
                      ? 'assets/games/toca-do-caranguejo/background-mobile.png'
                      : 'assets/games/toca-do-caranguejo/background.png';
                  return Image.asset(asset, fit: BoxFit.cover);
                },
              ),

              // Jogo
              GameWidget(
                game: _game,
                overlayBuilderMap: {
                  'Hud': (context, game) => _HudOverlay(game as CrabGame),
                  'ActionPopup': (context, game) =>
                      _ActionPopupOverlay(game as CrabGame),
                  'GameOver': (context, game) =>
                      _GameOverOverlay(game as CrabGame),
                  'StartGate': (context, game) =>
                      _StartGateOverlay(game as CrabGame),
                  'DebugBurrows': (context, game) =>
                      DebugBurrowsOverlay(game as CrabGame),
                },
                initialActiveOverlays: const ['Hud', 'StartGate'],
              ),

              // 🔔 Toast “Defeso encerrado”
              Positioned.fill(
                child: DefesoEndToast(
                  defesoAtivo: _game.defesoAtivo,
                  fadeIn: Duration(milliseconds: reduceMotion ? 80 : 220),
                  hold: Duration(milliseconds: reduceMotion ? 600 : 1600),
                  fadeOut: Duration(milliseconds: reduceMotion ? 120 : 260),
                  bottomPadding: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HudOverlay extends StatelessWidget {
  const _HudOverlay(this.game);
  final CrabGame game;

  // [A11Y] abre o painel e pausa/resume o engine
  Future<void> _openA11y(BuildContext context) async {
    game.pauseEngine(); // pausa o loop gráfico (timers internos do jogo seguem)
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const A11yPanel(),
    );
    game.resumeEngine();
  }
  // [A11Y] fim

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (details) => game.handleTap(details.localPosition),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 560;
            final isDesktopLike = (constraints.maxWidth >= 800);
            final pad = EdgeInsets.symmetric(
              horizontal: isNarrow ? 8 : 16,
              vertical: isNarrow ? 6 : 12,
            );
            final fontSize = isNarrow ? 13.0 : 16.0;

            final hud = SafeArea(
              child: Padding(
                padding: pad,
                child: isDesktopLike
                    ? Align(
                        alignment: Alignment.topCenter,
                        child: ValueListenableBuilder<bool>(
                          valueListenable: game.defesoAtivo,
                          builder: (context, defesoAtivo, _) {
                            return Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              alignment: WrapAlignment.center,
                              children: [
                                ValueListenableBuilder<int>(
                                  valueListenable: game.score,
                                  builder: (context, score, __) => _infoBox(
                                    '🎯 Pontuação: $score',
                                    fontSize: fontSize,
                                  ),
                                ),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  child: defesoAtivo
                                      ? Padding(
                                          key: const ValueKey(
                                            'defeso-badge-inline',
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                          ),
                                          child: _defesoBadge(
                                            fontSize: fontSize,
                                          ),
                                        )
                                      : const SizedBox.shrink(
                                          key: ValueKey('defeso-badge-hidden'),
                                        ),
                                ),

                                // Tempo
                                ValueListenableBuilder<int>(
                                  valueListenable: game.timeLeft,
                                  builder: (context, time, _) => _infoBox(
                                    '🕒 Tempo: $time s',
                                    fontSize: fontSize,
                                  ),
                                ),

                                // Som on/off
                                ValueListenableBuilder<bool>(
                                  valueListenable: game.sfxEnabled,
                                  builder: (context, enabled, _) =>
                                      _hudIconButton(
                                        icon: enabled
                                            ? Icons.volume_up_rounded
                                            : Icons.volume_off_rounded,
                                        onPressed: () =>
                                            game.sfxEnabled.value = !enabled,
                                      ),
                                ),

                                // [A11Y] Botão de acessibilidade (idêntico ao do cadastro em efeito)
                                _hudIconButton(
                                  icon: Icons.accessibility_new_rounded,
                                  onPressed: () => _openA11y(context),
                                  tooltip: 'Acessibilidade',
                                ),
                                // [A11Y] fim

                                // Recarregar
                                _hudIconButton(
                                  icon: Icons.refresh_rounded,
                                  onPressed: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const TocaGameScreen(),
                                      ),
                                    );
                                  },
                                ),

                                // Debug (somente dev)
                                if (kDebugMode)
                                  _hudIconButton(
                                    icon: Icons.bug_report_rounded,
                                    onPressed: () {
                                      if (game.overlays.isActive(
                                        'DebugBurrows',
                                      )) {
                                        game.overlays.remove('DebugBurrows');
                                      } else {
                                        game.overlays.add('DebugBurrows');
                                      }
                                    },
                                  ),
                              ],
                            );
                          },
                        ),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ⬅️ Coluna: Pontuação + DEFESO logo abaixo
                          Flexible(
                            child: _scoreWithDefeso(game, fontSize: fontSize),
                          ),
                          const SizedBox(width: 8),
                          // ➡️ Demais controles
                          Flexible(
                            child: Align(
                              alignment: Alignment.topRight,
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                alignment: WrapAlignment.end,
                                children: [
                                  ValueListenableBuilder<int>(
                                    valueListenable: game.timeLeft,
                                    builder: (context, time, _) => _infoBox(
                                      '🕒 Tempo: $time s',
                                      fontSize: fontSize,
                                    ),
                                  ),
                                  ValueListenableBuilder<bool>(
                                    valueListenable: game.sfxEnabled,
                                    builder: (context, enabled, _) =>
                                        _hudIconButton(
                                          icon: enabled
                                              ? Icons.volume_up_rounded
                                              : Icons.volume_off_rounded,
                                          onPressed: () =>
                                              game.sfxEnabled.value = !enabled,
                                        ),
                                  ),

                                  // [A11Y] Botão de acessibilidade também no layout compacto
                                  _hudIconButton(
                                    icon: Icons.accessibility_new_rounded,
                                    onPressed: () => _openA11y(context),
                                    tooltip: 'Acessibilidade',
                                  ),

                                  // [A11Y] fim
                                  _hudIconButton(
                                    icon: Icons.refresh_rounded,
                                    onPressed: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const TocaGameScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                  if (kDebugMode)
                                    _hudIconButton(
                                      icon: Icons.bug_report_rounded,
                                      onPressed: () {
                                        if (game.overlays.isActive(
                                          'DebugBurrows',
                                        )) {
                                          game.overlays.remove('DebugBurrows');
                                        } else {
                                          game.overlays.add('DebugBurrows');
                                        }
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            );

            return Stack(
              children: [
                Positioned.fill(child: hud),
                // Popup de ação (mensagens digitando)
                Positioned.fill(
                  child: ValueListenableBuilder<String?>(
                    valueListenable: game.actionMessage,
                    builder: (context, message, _) {
                      if (message == null) return const SizedBox.shrink();
                      return GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: game.dismissActionMessage,
                        child: Center(
                          child: _popupMensagem(
                            message,
                            game.dismissActionMessage,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Constrói o bloco “Pontuação” com o badge DEFESO imediatamente abaixo.
  Widget _scoreWithDefeso(CrabGame game, {double fontSize = 16}) {
    return ValueListenableBuilder<bool>(
      valueListenable: game.defesoAtivo,
      builder: (context, ativo, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ValueListenableBuilder<int>(
              valueListenable: game.score,
              builder: (context, score, __) =>
                  _infoBox('🎯 Pontuação: $score', fontSize: fontSize),
            ),
            if (ativo)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 2),
                child: _defesoBadge(fontSize: fontSize),
              ),
          ],
        );
      },
    );
  }

  Widget _infoBox(String texto, {double fontSize = 16}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.brown),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          texto,
          softWrap: false,
          maxLines: 1,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: Colors.brown,
          ),
        ),
      ),
    );
  }

  Widget _popupMensagem(String texto, VoidCallback onDismiss) {
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        padding: const EdgeInsets.all(18),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.brown, width: 3),
          boxShadow: [
            BoxShadow(
              blurRadius: 6,
              offset: const Offset(4, 4),
              color: Colors.black.withOpacity(0.35),
            ),
          ],
        ),
        child: Text(
          texto,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.brown,
          ),
        ),
      ),
    );
  }

  Widget _hudIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        border: Border.all(color: Colors.brown),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        iconSize: 24,
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.brown),
        tooltip: tooltip,
      ),
    );
  }

  /// Badge DEFESO: retângulo vermelho, levemente menor para harmonizar abaixo da pontuação.
  Widget _defesoBadge({double fontSize = 16}) {
    final fs = (fontSize * 1.25).clamp(15.0, 24.0); // um pouco menor que antes
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFD32F2F).withOpacity(0.98), // vermelho forte
        border: Border.all(color: const Color(0xFFB71C1C), width: 3),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 5,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Text(
        'DEFESO',
        style: TextStyle(
          fontSize: fs,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 1.0,
        ),
      ),
    );

    return AnimatedScale(
      scale: 1.0,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: chip,
      ),
    );
  }
}

class _ActionPopupOverlay extends StatelessWidget {
  const _ActionPopupOverlay(this.game);
  final CrabGame game;
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay(this.game);
  final CrabGame game;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compactWidth = constraints.maxWidth < 520;
        final bool narrowWidth = constraints.maxWidth < 360;
        final bool shortHeight = constraints.maxHeight < 620;

        final double maxCardWidth = math.min(420.0, constraints.maxWidth - 24);
        final double buttonWidth =
            (narrowWidth
                    ? constraints.maxWidth - 40
                    : maxCardWidth * (compactWidth ? 0.72 : 0.58))
                .clamp(180.0, 320.0);

        final listenable = Listenable.merge([
          game.score,
          game.crabsCaptured,
          game.residuesCollected,
          game.residueCounts,
        ]);

        final EdgeInsets safePad = EdgeInsets.symmetric(
          horizontal: compactWidth ? 14 : 24,
          vertical: shortHeight ? 18 : 28,
        );

        final double sectionSpacing = shortHeight ? 14 : 18;
        final double chipSpacing = shortHeight ? 6 : 9;
        final double statSpacing = shortHeight ? 8 : 12;

        final Color overlayColor = Colors.black.withOpacity(
          compactWidth ? 0.82 : 0.74,
        );

        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  color: overlayColor,
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: SafeArea(
                child: Padding(
                  padding: safePad,
                  child: Center(
                    child: AnimatedBuilder(
                      animation: listenable,
                      builder: (context, _) {
                        final score = game.score.value;
                        final crabs = game.crabsCaptured.value;
                        final residues = game.residuesCollected.value;
                        final residueStats =
                            game.residueCounts.value.entries
                                .map(
                                  (entry) => MapEntry(entry.key, entry.value),
                                )
                                .toList()
                              ..sort((a, b) => a.key.compareTo(b.key));
                        final bool hasResidues = residueStats.isNotEmpty;

                        final theme = Theme.of(context);
                        final titleStyle =
                            theme.textTheme.headlineSmall?.copyWith(
                              color: const Color(0xFF28160C),
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ) ??
                            const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFEAD6B5),
                            );

                        final bodyStyle =
                            theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF4B331C),
                              height: 1.32,
                            ) ??
                            const TextStyle(
                              fontSize: 14,
                              height: 1.32,
                              color: Color(0xFF4B331C),
                            );

                        // ---------- CARD ----------
                        final Widget card = ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: maxCardWidth.clamp(280.0, 520.0),
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF7E2C3), Color(0xFFE9C89B)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius:
                                  BorderRadius.circular(compactWidth ? 20 : 26),
                              border: Border.all(
                                color: const Color(0xFF79441F),
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.45),
                                  blurRadius: 24,
                                  offset: const Offset(0, 18),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: compactWidth ? 18 : 26,
                                vertical: shortHeight ? 18 : (compactWidth ? 24 : 30),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    '🏁 Fim de jogo!',
                                    textAlign: TextAlign.center,
                                    style: titleStyle,
                                  ),
                                  SizedBox(height: shortHeight ? 4 : 6),
                                  Text(
                                    'Confira o que você conseguiu nesta rodada.',
                                    textAlign: TextAlign.center,
                                    style: bodyStyle.copyWith(
                                      color: const Color(0xFF5C3D20),
                                    ),
                                  ),
                                  SizedBox(height: sectionSpacing),
                                  _scoreHighlight(
                                    theme,
                                    score,
                                    compact: compactWidth,
                                    short: shortHeight,
                                  ),
                                  SizedBox(height: sectionSpacing),
                                  Wrap(
                                    spacing: statSpacing,
                                    runSpacing: statSpacing,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      _statBadge('🦀', 'Caranguejos', crabs),
                                      _statBadge('♻️', 'Resíduos', residues),
                                    ],
                                  ),
                                  SizedBox(height: sectionSpacing),
                                  Text(
                                    residues == 0
                                        ? 'Nenhum resíduo foi recolhido desta vez. Observe o mangue e tente novamente!'
                                        : residues == 1
                                            ? 'Você recolheu 1 resíduo:'
                                            : 'Você recolheu $residues resíduos ao todo:',
                                    textAlign: TextAlign.center,
                                    style: bodyStyle,
                                  ),
                                  SizedBox(height: shortHeight ? 8 : 12),
                                  if (hasResidues)
                                    Center(
                                      child: Wrap(
                                        spacing: chipSpacing,
                                        runSpacing: chipSpacing,
                                        alignment: WrapAlignment.center,
                                        children: [
                                          for (final entry in residueStats)
                                            _residueChip(
                                              entry.key,
                                              entry.value,
                                            ),
                                        ],
                                      ),
                                    )
                                  else
                                    _emptyResidueTip(bodyStyle),
                                  SizedBox(height: sectionSpacing + 4),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 10,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      PixelButton(
                                        label: 'Jogar novamente',
                                        width: buttonWidth,
                                        height: shortHeight ? 48 : 52,
                                        icon: Icons.refresh,
                                        onPressed: () {
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const TocaGameScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                      PixelButton(
                                        label: 'Voltar ao início',
                                        width: buttonWidth,
                                        height: shortHeight ? 48 : 52,
                                        icon: Icons.home_outlined,
                                        onPressed: () {
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const TocaStartScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: sectionSpacing),
                                  Text(
                                    'Compartilhe o que aprendeu e siga cuidando do manguezal!',
                                    textAlign: TextAlign.center,
                                    style: bodyStyle.copyWith(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );

                        // ---------- ENVOLTÓRIO RESPONSIVO ----------
                        // Garante que o card SEMPRE cabe: se faltar espaço, reduz a escala.
                        return ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth,
                            maxHeight: constraints.maxHeight,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.center,
                            child: card,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static Widget _scoreHighlight(
    ThemeData theme,
    int score, {
    required bool compact,
    required bool short,
  }) {
    final TextStyle numberStyle =
        theme.textTheme.headlineMedium?.copyWith(
          color: const Color(0xFF28160C),
          fontWeight: FontWeight.w900,
          letterSpacing: 1.1,
          fontSize: compact ? 34 : 36,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ) ??
        const TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w900,
          color: Color(0xFF28160C),
        );

    return Column(
      children: [
        Text(
          'Pontuação total',
          style: theme.textTheme.titleMedium?.copyWith(
                color: const Color(0xFF5C3D20),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.35,
              ) ??
              const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF5C3D20),
              ),
        ),
        SizedBox(height: short ? 6 : 8),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFDFA35F), Color(0xFFB87839)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(compact ? 16 : 20),
            border: Border.all(color: const Color(0xFF6C3C1E), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 22 : 28,
              vertical: short ? 12 : 14,
            ),
            // ✅ mostra o score
            child: Text('$score', textAlign: TextAlign.center, style: numberStyle),
          ),
        ),
      ],
    );
  }

  static Widget _statBadge(String emoji, String label, int value) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFB8854E), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(
              value.toString(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF3A2516),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5F4025),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _residueChip(String label, int count) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFB77B3E), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3F2A18),
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 4),
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFEED9B6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '×',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6F5132),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF5A3B1F),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _emptyResidueTip(TextStyle baseStyle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCEAA7A), width: 1.1),
      ),
      child: Text(
        'Fique de olho em latas, cordas e sacolas para limpar o mangue e ganhar mais pontos!',
        textAlign: TextAlign.center,
        style: baseStyle.copyWith(fontSize: 12.5),
      ),
    );
  }
}

class _StartGateOverlay extends StatelessWidget {
  const _StartGateOverlay(this.game);
  final CrabGame game;

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.of(context).size.width;
    final btnW = (maxW * 0.75).clamp(220.0, 360.0);
    return Container(
      color: Colors.transparent,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.98),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.brown, width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                offset: const Offset(4, 4),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Pronto para iniciar?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.brown,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Clique em Iniciar para começar o jogo.\nNo navegador, isso evita travamentos de animação e habilita interações corretamente.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 20),
              PixelButton(
                label: '▶ Iniciar',
                width: btnW,
                onPressed: () async {
                  await game.ensureAudioUnlocked();
                  game.overlays.remove('StartGate');
                  game.startGame();
                  game.resumeEngine();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
