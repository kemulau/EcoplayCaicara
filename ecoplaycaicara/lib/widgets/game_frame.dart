// lib/widgets/game_frame.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'accessibility/panel.dart'; // [A11Y]
import 'narrable.dart';
import '../theme/game_chrome.dart';
import 'hud/title_capsule.dart';

class _OpenA11yIntent extends Intent {
  const _OpenA11yIntent();
}

class _DismissA11yIntent extends Intent {
  const _DismissA11yIntent();
}

class GameScaffold extends StatelessWidget {
  const GameScaffold({
    super.key,
    required this.title,
    required this.child,
    this.fill = true,
    this.backgroundAsset,
    this.mobileBackgroundAsset,
    this.mobileBreakpoint = 600,
    this.panelPadding,
    this.showA11yButton = false, // [A11Y]
    this.onOpenA11y, // [A11Y]
  });

  final String title;
  final Widget child;
  final bool fill;
  // Permite personalizar o fundo e um fundo específico para telas pequenas.
  final String? backgroundAsset;
  final String? mobileBackgroundAsset;
  final double mobileBreakpoint;
  // Permite personalizar o padding interno do painel branco.
  final EdgeInsets? panelPadding;

  // [A11Y] controla botão no cabeçalho e callback para abrir painel
  final bool showA11yButton; // [A11Y]
  final void Function(BuildContext context)? onOpenA11y; // [A11Y]

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    // Max content width used for desktop/big screens (keeps look consistent beyond baseline).
    const double desktopPanelMaxWidth = 1200.0;
    // Max panel height when not filling on large screens (keeps look consistent vertically too).
    const double desktopPanelMaxHeight = 760.0;
    // Fundo padrão do app
    const String defaultBackground = 'assets/images/background-toca.png';
    // Escolhe o fundo considerando breakpoint para mobile
    final String chosenBackground =
        (screenWidth <= mobileBreakpoint && mobileBackgroundAsset != null)
        ? mobileBackgroundAsset!
        : (backgroundAsset ?? defaultBackground);

    // Ajuste de decode para imagem de fundo proporcional à largura da tela
    final int bgCacheWidth = (screenWidth * media.devicePixelRatio).round();

    // [A11Y] função padrão para abrir painel (se o caller não fornecer)
    Future<void> _openA11y(BuildContext ctx) async {
      await showA11yPanelBottomSheet(ctx);
    }

    final openPanel = onOpenA11y ?? _openA11y;

    final scaffold = Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              chosenBackground,
              fit: BoxFit.cover,
              cacheWidth: bgCacheWidth,
              filterQuality: FilterQuality.low,
            ),
          ),
          Center(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                // Congela a largura do conteúdo quando há espaço para 1200px.
                final bool hasRoomForDesktop =
                    constraints.maxWidth >= desktopPanelMaxWidth;
                final double maxW = hasRoomForDesktop
                    ? desktopPanelMaxWidth
                    : (constraints.maxWidth < desktopPanelMaxWidth
                          ? constraints.maxWidth
                          : desktopPanelMaxWidth);
                // Limita a altura do painel para evitar overflow em telas baixas.
                final double maxPanelHeight = (constraints.maxHeight - 40)
                    .clamp(
                      260.0,
                      hasRoomForDesktop
                          ? desktopPanelMaxHeight
                          : double.infinity,
                    )
                    .toDouble();

                Widget panel = GamePanel(child: child, padding: panelPadding);

                if (!fill) {
                  panel = ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxPanelHeight),
                    child: panel,
                  );
                }

                return ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SafeArea(
                      child: Column(
                        mainAxisSize: fill
                            ? MainAxisSize.max
                            : MainAxisSize.min,
                        children: [
                          _HeaderBar(
                            title: title,
                            showA11yButton: showA11yButton, // [A11Y]
                            onOpenA11y: onOpenA11y ?? _openA11y, // [A11Y]
                          ),
                          const SizedBox(height: 8),
                          fill
                              ? Expanded(child: panel)
                              : Flexible(child: panel),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.slash, shift: true):
            const _OpenA11yIntent(),
        const SingleActivator(LogicalKeyboardKey.escape):
            const _DismissA11yIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _OpenA11yIntent: CallbackAction<_OpenA11yIntent>(
            onInvoke: (_) {
              openPanel(context);
              return null;
            },
          ),
          _DismissA11yIntent: CallbackAction<_DismissA11yIntent>(
            onInvoke: (_) {
              Navigator.of(context).maybePop();
              return null;
            },
          ),
        },
        child: Focus(autofocus: true, child: scaffold),
      ),
    );
  }
}

class GamePanel extends StatelessWidget {
  const GamePanel({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chrome = Theme.of(context).extension<GameChrome>();

    return Container(
      decoration: BoxDecoration(
        color:
            (chrome?.panelBackground ??
                    (Theme.of(context).brightness == Brightness.dark
                        ? scheme.surface
                        : scheme.background))
                .withOpacity(0.86),
        borderRadius: BorderRadius.circular(chrome?.panelRadius ?? 18),
        border: Border.all(
          color: chrome?.panelBorder ?? scheme.onSurface.withOpacity(0.25),
          width: chrome?.panelBorderWidth ?? 2,
        ),
        boxShadow:
            chrome?.panelShadow ??
            [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
      ),
      child: Padding(
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: child,
      ),
    );
  }
}

class GameSectionTitle extends StatelessWidget {
  const GameSectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Narrable(
      text: text,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: scheme.primary.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.title,
    this.showA11yButton = false, // [A11Y]
    this.onOpenA11y, // [A11Y]
  });

  final String title;
  final bool showA11yButton; // [A11Y]
  final void Function(BuildContext context)? onOpenA11y; // [A11Y]

  @override
  Widget build(BuildContext context) {
    final chrome = Theme.of(context).extension<GameChrome>();
    final scheme = Theme.of(context).colorScheme;
    final navigator = Navigator.of(context);
    const double controlSlotWidth = 48;
    Widget leadingSlot = SizedBox(width: controlSlotWidth);
    if (navigator.canPop()) {
      leadingSlot = SizedBox(
        width: controlSlotWidth,
        height: 48,
        child: Narrable(
          text: 'Voltar',
          tooltip: 'Voltar',
          child: Material(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(32),
            child: InkWell(
              borderRadius: BorderRadius.circular(32),
              onTap: () => navigator.maybePop(),
              child: Center(
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: scheme.onPrimary,
                  size: 18,
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget? trailing;
    if (showA11yButton) {
      trailing = Narrable(
        text: 'Abrir painel de acessibilidade',
        tooltip: 'Acessibilidade',
        child: IconButton(
          tooltip: 'Acessibilidade',
          onPressed: () => onOpenA11y?.call(context),
          icon: const Icon(Icons.accessibility_new_rounded),
          color: scheme.onPrimary,
          splashRadius: 20,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableHeaderWidth =
            (constraints.maxWidth - (controlSlotWidth * 2)).clamp(
              0.0,
              constraints.maxWidth,
            );
        final double maxHeader = availableHeaderWidth <= 160
            ? availableHeaderWidth
            : availableHeaderWidth.clamp(160.0, 420.0);
        final double naturalMinWidth = (chrome?.panelRadius ?? 16) * 10;
        final double resolvedMinWidth = maxHeader <= 220
            ? maxHeader
            : naturalMinWidth.clamp(220.0, maxHeader);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            leadingSlot,
            Expanded(
              child: Center(
                child: TitleCapsule(
                  text: title,
                  maxWidth: maxHeader <= 0 ? 160 : maxHeader,
                  minWidth: resolvedMinWidth > 0 ? resolvedMinWidth : 120,
                  trailing: trailing,
                ),
              ),
            ),
            SizedBox(width: controlSlotWidth),
          ],
        );
      },
    );
  }
}
