import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../widgets/accessibility/panel.dart';
import '../../../widgets/narrable.dart';
import '../../../widgets/pixel_button.dart';
import 'missao_reciclagem_game.dart';

// =========================================================
// Helpers shared between HUD variants
// =========================================================
Future<void> _openA11yPanel(
  BuildContext context,
  MissaoReciclagemGame game,
) async {
  game.pauseEngine();
  await showA11yPanelBottomSheet(context);
  game.resumeEngine();
}

void _performRestart(MissaoReciclagemGame game) {
  unawaited(game.playClick());
  game.pauseEngine();
  game.resetGame();
  game.overlays.remove('GameOver');
  if (!game.overlays.isActive('StartGate')) {
    game.overlays.add('StartGate');
  }
}

Future<void> _confirmRestart(
  BuildContext context,
  MissaoReciclagemGame game,
) async {
  final bool wasPaused = game.isPaused;
  if (!wasPaused) {
    game.pauseEngine();
  }

  final bool? confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final double dialogMaxWidth = math.min(
        MediaQuery.of(dialogContext).size.width * 0.85,
        420,
      );
      final theme = Theme.of(dialogContext);
      final bool isDark = theme.brightness == Brightness.dark;
      final Color surface = isDark
          ? const Color(0xFF21140C).withOpacity(0.96)
          : Colors.white.withOpacity(0.98);
      final Color borderColor =
          isDark ? const Color(0xFF9F6630) : const Color(0xFF7A4B1D);
      final Color titleColor =
          isDark ? const Color(0xFFEAD0AE) : const Color(0xFF3A2516);
      final Color bodyColor =
          isDark ? const Color(0xFFCBA57F) : const Color(0xFF5F4025);
      final Color shadowColor = isDark
          ? Colors.black.withOpacity(0.65)
          : Colors.black.withOpacity(0.45);

      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: dialogMaxWidth),
          child: Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 3),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 18,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Reiniciar rodada?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tem certeza de que deseja reiniciar agora? '
                    'Você perderá o progresso desta rodada.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.36,
                      color: bodyColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  PixelButton(
                    label: 'REINICIAR',
                    icon: Icons.refresh_rounded,
                    width: 200,
                    height: 48,
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: bodyColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  if (confirmed == true) {
    _performRestart(game);
  } else if (!wasPaused) {
    game.resumeEngine();
  }
}

List<Widget> _buildScoreChips(
  MissaoReciclagemGame game,
  double fontSize, {
  double? maxWidth,
  double? fixedWidth,
  EdgeInsets? padding,
}) {
  return [
    ValueListenableBuilder<int>(
      valueListenable: game.score,
      builder: (_, score, __) => _HudInfoChip(
        text: '🎯 Pontuação: $score',
        fontSize: fontSize,
        maxWidth: maxWidth,
        fixedWidth: fixedWidth,
        padding: padding,
      ),
    ),
    ValueListenableBuilder<int>(
      valueListenable: game.timeLeft,
      builder: (_, tempo, __) => _HudInfoChip(
        text: '🕒 Tempo: ${tempo}s',
        fontSize: fontSize,
        maxWidth: maxWidth,
        fixedWidth: fixedWidth,
        padding: padding,
      ),
    ),
  ];
}

Widget _scoreColumn(
  MissaoReciclagemGame game, {
  double fontSize = 16,
  double? maxWidth,
  double? fixedWidth,
  EdgeInsets? padding,
}) {
  final column = Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ValueListenableBuilder<int>(
        valueListenable: game.score,
        builder: (_, score, __) => _HudInfoChip(
          text: '🎯 Pontuação: $score',
          fontSize: fontSize,
          fixedWidth: fixedWidth,
          padding:
              padding ?? const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          maxWidth: maxWidth,
        ),
      ),
      const SizedBox(height: 6),
      ValueListenableBuilder<int>(
        valueListenable: game.timeLeft,
        builder: (_, tempo, __) => _HudInfoChip(
          text: '🕒 Tempo: ${tempo}s',
          fontSize: fontSize,
          fixedWidth: fixedWidth,
          padding:
              padding ?? const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          maxWidth: maxWidth,
        ),
      ),
    ],
  );

  if (maxWidth == null) {
    return column;
  }
  return ConstrainedBox(
    constraints: BoxConstraints(maxWidth: maxWidth),
    child: column,
  );
}

List<Widget> _buildControls(
  BuildContext context,
  MissaoReciclagemGame game,
  double buttonSize, {
  bool verticalStack = false,
  double verticalSpacing = 4,
  double? fixedWidth,
}) {
  final volumeButton = ValueListenableBuilder<bool>(
    valueListenable: game.sfxEnabled,
    builder: (_, enabled, __) => _HudIconButton(
      icon: enabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
      tooltip: enabled ? 'Desativar efeitos sonoros' : 'Ativar efeitos sonoros',
      semanticLabel: enabled ? 'Som ligado' : 'Som desligado',
      onPressed: game.toggleSfx,
      size: buttonSize,
      fixedWidth: fixedWidth,
    ),
  );

  final a11yButton = _HudIconButton(
    icon: Icons.accessibility_new_rounded,
    tooltip: 'Painel de acessibilidade',
    semanticLabel: 'Abrir painel de acessibilidade',
    onPressed: () => _openA11yPanel(context, game),
    size: buttonSize,
    fixedWidth: fixedWidth,
  );

  final restartButton = _HudIconButton(
    icon: Icons.refresh_rounded,
    tooltip: 'Reiniciar rodada',
    semanticLabel: 'Reiniciar jogo',
    onPressed: () => _confirmRestart(context, game),
    size: buttonSize,
    fixedWidth: fixedWidth,
  );

  if (verticalStack) {
    Widget column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        volumeButton,
        SizedBox(height: verticalSpacing),
        a11yButton,
        SizedBox(height: verticalSpacing),
        restartButton,
      ],
    );
    if (fixedWidth != null) {
      column = SizedBox(width: fixedWidth, child: column);
    }
    return [column];
  }

  return [
    volumeButton,
    a11yButton,
    restartButton,
  ];
}

// =========================================================
// Virtual Key helpers for on-screen arrows
// =========================================================
void _sendArrowKey(MissaoReciclagemGame game, LogicalKeyboardKey logical) {
  final PhysicalKeyboardKey physical =
      (logical == LogicalKeyboardKey.arrowLeft)
          ? PhysicalKeyboardKey.arrowLeft
          : PhysicalKeyboardKey.arrowRight;

  // Use um timestamp válido (pode ser zero para eventos sintetizados)
  final Duration now =
      Duration(milliseconds: DateTime.now().millisecondsSinceEpoch);

  final down = KeyDownEvent(
    logicalKey: logical,
    physicalKey: physical,
    timeStamp: now,
    synthesized: true,
  );
  game.onKeyEvent(down, {logical});

  scheduleMicrotask(() {
    final up = KeyUpEvent(
      logicalKey: logical,
      physicalKey: physical,
      timeStamp: now + const Duration(milliseconds: 1),
      synthesized: true,
    );
    game.onKeyEvent(up, const <LogicalKeyboardKey>{});
  });
}

// =========================================================
// HUD Responsivo (única implementação)
// =========================================================
class MissaoReciclagemHud extends StatelessWidget {
  const MissaoReciclagemHud({super.key, required this.game});

  final MissaoReciclagemGame game;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            game.updateViewportProfile(constraints.maxWidth);
            final bool isWide = constraints.maxWidth >= 820;
            final bool compact = constraints.maxWidth < 620;
            final bool ultraCompact = constraints.maxWidth < 480;
            final bool mobileLike = constraints.maxWidth < 760;
            final bool crabStyleMobile = !isWide && mobileLike;

            final EdgeInsets pad = EdgeInsets.symmetric(
              horizontal: ultraCompact ? 10 : (compact ? 14 : 22),
              vertical: ultraCompact ? 8 : (compact ? 10 : 16),
            );
            final double spacing =
                crabStyleMobile ? 8 : (ultraCompact ? 6 : 12);
            final double fontSize = crabStyleMobile
                ? (constraints.maxWidth < 560 ? 13.0 : 14.2)
                : (isWide ? 19.0 : (ultraCompact ? 18.5 : 20.0));
            final double buttonSize =
                crabStyleMobile ? 42 : (ultraCompact ? 40 : (compact ? 46 : 52));
            final EdgeInsets chipPadding = isWide
                ? const EdgeInsets.symmetric(horizontal: 22, vertical: 12)
                : (crabStyleMobile
                    ? const EdgeInsets.symmetric(horizontal: 14, vertical: 8)
                    : (ultraCompact
                        ? const EdgeInsets.symmetric(horizontal: 18, vertical: 9)
                        : const EdgeInsets.symmetric(horizontal: 22, vertical: 12)));

            final double innerWidth =
                math.max(0, constraints.maxWidth - pad.horizontal);
            final double? scoreMaxWidth;
            if (isWide || compact) {
              scoreMaxWidth = null;
            } else {
              final double cap = mobileLike ? 420 : 360;
              final double factor = mobileLike ? 0.82 : 0.7;
              scoreMaxWidth = math.min(innerWidth * factor, cap);
            }
            double? mobileChipWidth;
            if (crabStyleMobile) {
              final double base = innerWidth > 0 ? innerWidth * 0.42 : 160;
              mobileChipWidth = base.clamp(140, 220);
            }

            final scoreChips = _buildScoreChips(
              game,
              fontSize,
              maxWidth: (!isWide && !crabStyleMobile) ? scoreMaxWidth : null,
              fixedWidth: crabStyleMobile ? null : mobileChipWidth,
              padding: chipPadding,
            );
            final controls = _buildControls(
              context,
              game,
              buttonSize,
              verticalStack: false,
              verticalSpacing: spacing,
              fixedWidth: null,
            );
            final Widget scoreColumn = _scoreColumn(
              game,
              fontSize: fontSize,
              maxWidth: crabStyleMobile ? null : scoreMaxWidth,
              fixedWidth: crabStyleMobile ? mobileChipWidth : null,
              padding: chipPadding,
            );

            Wrap controlsWrap(WrapAlignment alignment) {
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: alignment,
                children: controls,
              );
            }

            Widget content;
            if (isWide) {
              content = Align(
                alignment: Alignment.topCenter,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.center,
                  children: [...scoreChips, ...controls],
                ),
              );
            } else if (crabStyleMobile) {
              content = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.start,
                      children: scoreChips,
                    ),
                  ),
                  SizedBox(width: spacing),
                  Wrap(
                    spacing: spacing,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.end,
                    children: controls,
                  ),
                ],
              );
            } else if (compact) {
              content = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: scoreColumn,
                  ),
                  SizedBox(height: spacing),
                  Align(
                    alignment: Alignment.topLeft,
                    child: controlsWrap(WrapAlignment.start),
                  ),
                ],
              );
            } else {
              content = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    flex: mobileLike ? 5 : 3,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: scoreColumn,
                    ),
                  ),
                  SizedBox(width: spacing),
                  Flexible(
                    flex: 4,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: controlsWrap(WrapAlignment.end),
                    ),
                  ),
                ],
              );
            }

            // ====== SETAS LATERAIS (meio da tela) ======
            final double edgeButtonSize =
                crabStyleMobile ? 54 : (ultraCompact ? 50 : 56);

            Widget leftArrow = Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _HudIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                tooltip: 'Mover para a esquerda (←)',
                semanticLabel: 'Mover para a esquerda',
                onPressed: () =>
                    _sendArrowKey(game, LogicalKeyboardKey.arrowLeft),
                size: edgeButtonSize,
              ),
            );

            Widget rightArrow = Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _HudIconButton(
                icon: Icons.arrow_forward_ios_rounded,
                tooltip: 'Mover para a direita (→)',
                semanticLabel: 'Mover para a direita',
                onPressed: () =>
                    _sendArrowKey(game, LogicalKeyboardKey.arrowRight),
                size: edgeButtonSize,
              ),
            );
            // ===========================================

            return Stack(
              children: [
                Padding(
                  padding: pad,
                  child: Align(alignment: Alignment.topCenter, child: content),
                ),
                Align(alignment: Alignment.centerLeft, child: leftArrow),
                Align(alignment: Alignment.centerRight, child: rightArrow),
              ],
            );
          },
        ),
      ),
    );
  }
}

// =========================================================
// Shared UI elements
// =========================================================
class _HudInfoChip extends StatelessWidget {
  const _HudInfoChip({
    required this.text,
    required this.fontSize,
    this.padding,
    this.maxWidth,
    this.fixedWidth,
  });

  final String text;
  final double fontSize;
  final EdgeInsets? padding;
  final double? maxWidth;
  final double? fixedWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color background =
        isDark ? const Color(0xFF20140C).withOpacity(0.88) : Colors.white.withOpacity(0.9);
    final Color border = isDark ? const Color(0xFF8B5723) : Colors.brown;
    final Color textColor = isDark ? const Color(0xFFECD2AE) : Colors.brown;

    final chip = Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          softWrap: false,
          maxLines: 1,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ),
    );

    Widget base = chip;
    if (fixedWidth != null) {
      base = SizedBox(
        width: fixedWidth,
        child: chip,
      );
    } else if (maxWidth != null) {
      base = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth!),
        child: chip,
      );
    }

    return Narrable(
      text: text,
      tooltip: text,
      child: base,
    );
  }
}

class _HudIconButton extends StatelessWidget {
  const _HudIconButton({
    required this.icon,
    required this.tooltip,
    required this.semanticLabel,
    required this.onPressed,
    required this.size,
    this.fixedWidth,
  });

  final IconData icon;
  final String tooltip;
  final String semanticLabel;
  final VoidCallback onPressed;
  final double size;
  final double? fixedWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color background =
        isDark ? const Color(0xFF20140C).withOpacity(0.88) : Colors.white.withOpacity(0.9);
    final Color border = isDark ? const Color(0xFF8B5723) : Colors.brown;
    final Color iconColor = isDark ? const Color(0xFFECD2AE) : Colors.brown;

    Widget button = Narrable(
      text: semanticLabel,
      tooltip: tooltip,
      readOnFocus: false,
      child: Container(
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: IconButton(
          icon: Icon(icon, color: iconColor),
          tooltip: tooltip,
          onPressed: onPressed,
          constraints: BoxConstraints.tightFor(width: size, height: size),
          padding: EdgeInsets.zero,
          splashRadius: size * 0.6,
        ),
      ),
    );

    if (fixedWidth != null) {
      button = SizedBox(width: fixedWidth, child: button);
    }
    return button;
  }
}
