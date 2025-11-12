import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/backend_client.dart';
import '../../../widgets/game_ranking.dart';
import '../../../widgets/pixel_button.dart';
import 'missao_reciclagem_game.dart';

class MissaoReciclagemGameOverCard extends StatefulWidget {
  const MissaoReciclagemGameOverCard({super.key, required this.game});

  final MissaoReciclagemGame game;

  @override
  State<MissaoReciclagemGameOverCard> createState() =>
      _MissaoReciclagemGameOverCardState();
}

class _MissaoReciclagemGameOverCardState
    extends State<MissaoReciclagemGameOverCard> {
  RankingStatus _rankingStatus = RankingStatus.loading;
  GameRankingResult? _ranking;
  String? _rankingMessage;
  bool _initialSyncDone = false;

  @override
  void initState() {
    super.initState();
    unawaited(_sincronizarRanking());
    unawaited(widget.game.playEndGameAudioIfNeeded());
  }

  Future<void> _sincronizarRanking() async {
    if (_initialSyncDone) return;
    _initialSyncDone = true;
    final backend = BackendClient.instance;
    final session = await backend.getCurrentSession();
    if (!mounted) return;
    if (session == null) {
      setState(() {
        _rankingStatus = RankingStatus.requiresLogin;
        _rankingMessage =
            'Entre com sua conta para registrar a pontuação e ver seu placar pessoal.';
        _ranking = null;
      });
      return;
    }

    final int pontos = widget.game.score.value;
    String? infoMessage;
    try {
      await backend.submitPontuacao('missao-reciclagem', pontos);
    } on BackendException catch (e) {
      if (e.statusCode == 401) {
        await backend.clearSession();
        if (!mounted) return;
        setState(() {
          _rankingStatus = RankingStatus.requiresLogin;
          _rankingMessage =
              'Sua sessão expirou. Faça login novamente para registrar a pontuação.';
          _ranking = null;
        });
        return;
      }
      infoMessage = e.message.isNotEmpty
          ? e.message
          : 'Não foi possível registrar a pontuação desta rodada.';
    } on TimeoutException {
      infoMessage = 'Tempo esgotado ao registrar a pontuação.';
    } catch (_) {
      infoMessage = 'Não foi possível registrar a pontuação desta rodada.';
    }

    try {
      final ranking = await backend.fetchRanking('missao-reciclagem');
      if (!mounted) return;
      setState(() {
        _ranking = ranking;
        _rankingStatus = RankingStatus.ready;
        _rankingMessage = infoMessage;
      });
    } on BackendException catch (e) {
      if (e.statusCode == 401) {
        await backend.clearSession();
        if (!mounted) return;
        setState(() {
          _rankingStatus = RankingStatus.requiresLogin;
          _rankingMessage =
              'Faça login novamente para visualizar seu placar pessoal.';
          _ranking = null;
        });
      } else {
        final message = e.message.isNotEmpty
            ? e.message
            : 'Não foi possível carregar seu placar.';
        if (!mounted) return;
        setState(() {
          _rankingStatus = RankingStatus.error;
          _rankingMessage = message;
          _ranking = null;
        });
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _rankingStatus = RankingStatus.error;
        _rankingMessage =
            'Tempo esgotado ao carregar seu placar. Tente novamente.';
        _ranking = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _rankingStatus = RankingStatus.error;
        _rankingMessage = 'Falha inesperada ao carregar seu placar.';
        _ranking = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final listenable = Listenable.merge([
      widget.game.score,
      widget.game.residuosReciclaveis,
      widget.game.residuosOrganicos,
    ]);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compact = constraints.maxWidth < 520;
        final ThemeData theme = Theme.of(context);
        final bool isDark = theme.brightness == Brightness.dark;
        final EdgeInsets safePadding = EdgeInsets.symmetric(
          horizontal: compact ? 16 : 28,
          vertical: compact ? 18 : 30,
        );
        final double maxCardWidth =
            (constraints.maxWidth - safePadding.horizontal).clamp(280.0, 480.0);
        double? maxCardHeight;
        if (constraints.maxHeight.isFinite) {
          final double room = constraints.maxHeight - safePadding.vertical;
          maxCardHeight = room > 0 ? room : 240.0;
        }
        final Color overlayColor = isDark
            ? Colors.black.withOpacity(compact ? 0.88 : 0.82)
            : Colors.black.withOpacity(compact ? 0.82 : 0.74);
        final Color cardTop = isDark
            ? const Color(0xFF2E1B10)
            : const Color(0xFFF7E2C3);
        final Color cardBottom = isDark
            ? const Color(0xFF1C120A)
            : const Color(0xFFE9C89B);
        final Color borderColor = isDark
            ? const Color(0xFFB37A45)
            : const Color(0xFF79441F);
        final Color shadowColor = isDark
            ? Colors.black.withOpacity(0.72)
            : Colors.black.withOpacity(0.45);
        final Color highlightColor = isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.white.withOpacity(0.08);
        final Color titleColor = isDark
            ? const Color(0xFFEED4B2)
            : const Color(0xFF28160C);
        final Color bodyColor = isDark
            ? const Color(0xFFD9BA8E)
            : const Color(0xFF4B331C);
        final Color scoreColor = isDark
            ? const Color(0xFFFFE4B5)
            : const Color(0xFF3A2516);

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
            Positioned.fill(
              child: SafeArea(
                child: Padding(
                  padding: safePadding,
                  child: LayoutBuilder(
                    builder: (context, viewportConstraints) {
                      final double viewportHeight =
                          viewportConstraints.hasBoundedHeight
                          ? viewportConstraints.maxHeight
                          : 0;
                      return SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.only(bottom: compact ? 12 : 20),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: viewportHeight > 0 ? viewportHeight : 0,
                          ),
                          child: Center(
                            child: AnimatedBuilder(
                              animation: listenable,
                              builder: (context, _) {
                                final int score = widget.game.score.value;
                                final int reciclaveis =
                                    widget.game.residuosReciclaveis.value;
                                final int organicos =
                                    widget.game.residuosOrganicos.value;

                                return ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: maxCardWidth,
                                    maxHeight: maxCardHeight ?? double.infinity,
                                  ),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [cardTop, cardBottom],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        compact ? 20 : 26,
                                      ),
                                      border: Border.all(
                                        color: borderColor,
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: shadowColor,
                                          blurRadius: 22,
                                          offset: const Offset(0, 18),
                                        ),
                                        BoxShadow(
                                          color: highlightColor,
                                          blurRadius: 0,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: LayoutBuilder(
                                      builder: (context, cardBox) {
                                        final double availableHeight =
                                            cardBox.maxHeight.isFinite
                                            ? cardBox.maxHeight
                                            : maxCardHeight ??
                                                  cardBox.biggest.height;
                                        final double baseHeight = compact
                                            ? 480
                                            : 560;
                                        final double scale = availableHeight > 0
                                            ? (availableHeight / baseHeight)
                                                  .clamp(0.78, 1.0)
                                            : 1.0;
                                        final EdgeInsets contentPadding =
                                            EdgeInsets.symmetric(
                                              horizontal:
                                                  (compact ? 18 : 28) * scale,
                                              vertical:
                                                  (compact ? 20 : 28) * scale,
                                            );
                                        final double tinyGap = 6 * scale;
                                        final double regularGap = 14 * scale;
                                        final double statSpacing = 12 * scale;

                                        return Padding(
                                          padding: contentPadding,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.max,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Text(
                                                'Missao concluida!',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize:
                                                      (compact ? 18 : 21) *
                                                      scale,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 0.6,
                                                  height: 1.2,
                                                  color: titleColor,
                                                ),
                                              ),
                                              SizedBox(height: tinyGap),
                                              Text(
                                                'Veja como foi sua coleta e tente bater o recorde.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize:
                                                      (compact ? 13 : 13.5) *
                                                      scale,
                                                  height: 1.25,
                                                  color: bodyColor,
                                                ),
                                              ),
                                              SizedBox(height: regularGap),
                                              Text(
                                                '$score pontos',
                                                style: TextStyle(
                                                  fontSize:
                                                      (compact ? 23 : 28) *
                                                      scale,
                                                  fontWeight: FontWeight.w900,
                                                  color: scoreColor,
                                                ),
                                              ),
                                              SizedBox(height: regularGap),
                                              Wrap(
                                                spacing: statSpacing,
                                                runSpacing: 10 * scale,
                                                alignment: WrapAlignment.center,
                                                children: [
                                                  _statChip(
                                                    context: context,
                                                    label: 'Reciclaveis',
                                                    value: reciclaveis,
                                                    emoji: '♻️',
                                                    scale: scale,
                                                  ),
                                                  _statChip(
                                                    context: context,
                                                    label: 'Organicos',
                                                    value: organicos,
                                                    emoji: '🌱',
                                                    scale: scale,
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: regularGap),
                                              Flexible(
                                                flex: 4,
                                                child: ClipRect(
                                                  child: Align(
                                                    alignment:
                                                        Alignment.topCenter,
                                                    child: GameRankingSection(
                                                      status: _rankingStatus,
                                                      title: 'Ranking pessoal',
                                                      result: _ranking,
                                                      message: _rankingMessage,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(height: regularGap),
                                              Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  PixelButton(
                                                    label: 'JOGAR NOVAMENTE',
                                                    icon: Icons.refresh_rounded,
                                                    width:
                                                        (compact ? 220 : 240) *
                                                        scale,
                                                    height: 48 * scale,
                                                    onPressed: () =>
                                                        _restartRound(
                                                          context,
                                                          showStart: true,
                                                        ),
                                                  ),
                                                  SizedBox(height: 12 * scale),
                                                  PixelButton(
                                                    label: 'VOLTAR AO INICIO',
                                                    icon: Icons.home_outlined,
                                                    width:
                                                        (compact ? 200 : 220) *
                                                        scale,
                                                    height: 48 * scale,
                                                    onPressed: () =>
                                                        _restartRound(
                                                          context,
                                                          goHome: true,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _restartRound(
    BuildContext context, {
    bool showStart = false,
    bool goHome = false,
  }) {
    unawaited(widget.game.playClick());
    widget.game.pauseEngine();
    widget.game.resetGame();
    widget.game.overlays.remove('GameOver');
    if (showStart) {
      if (!widget.game.overlays.isActive('StartGate')) {
        widget.game.overlays.add('StartGate');
      }
      return;
    }
    if (goHome && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Widget _statChip({
    required BuildContext context,
    required String label,
    required int value,
    required String emoji,
    double scale = 1.0,
  }) {
    final double resolvedScale = scale.clamp(0.7, 1.0);
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color background = isDark
        ? const Color(0xFF28170C).withOpacity(0.92)
        : const Color(0xFFFFFBF4);
    final Color border = isDark
        ? const Color(0xFF9D6A33)
        : const Color(0xFFB8854E);
    final Color textPrimary = isDark
        ? const Color(0xFFE9D0AC)
        : const Color(0xFF3A2516);
    final Color textSecondary = isDark
        ? const Color(0xFFC6A782)
        : const Color(0xFF5F4025);
    final Color shadow = isDark
        ? Colors.black.withOpacity(0.55)
        : Colors.black.withOpacity(0.10);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.2),
        boxShadow: [
          BoxShadow(color: shadow, blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 16 * resolvedScale,
          vertical: 12 * resolvedScale,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(emoji, style: TextStyle(fontSize: 20 * resolvedScale)),
            SizedBox(height: 4 * resolvedScale),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 18 * resolvedScale,
                fontWeight: FontWeight.w900,
                color: textPrimary,
              ),
            ),
            SizedBox(height: 2 * resolvedScale),
            Text(
              label,
              style: TextStyle(
                fontSize: 12 * resolvedScale,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
