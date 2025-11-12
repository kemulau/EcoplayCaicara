import 'package:flutter/material.dart';

import '../../../theme/game_styles.dart';
import '../../../widgets/accessibility/panel.dart';
import '../../../widgets/game_frame.dart';
import '../../../widgets/narrable.dart';
import '../../../widgets/pixel_button.dart';
import '../../../widgets/game_loading_screen.dart';

import 'game.dart';
import 'missao_reciclagem_game.dart';
import 'tutorial.dart' deferred as tutorial;

class MissaoReciclagemStartScreen extends StatelessWidget {
  const MissaoReciclagemStartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: 'Missão Reciclagem',
      backgroundAsset:
          'assets/games/missao-reciclagem/background-reciclagem.png',
      mobileBackgroundAsset:
          'assets/games/missao-reciclagem/background-missao-mobile.png',
      fill: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double maxW = constraints.maxWidth;
          final double buttonWidth = (maxW * 0.72).clamp(220.0, 320.0);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Narrable.text(
                  'Escolha uma opção',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                PixelButton(
                  label: 'TUTORIAL',
                  icon: Icons.menu_book_rounded,
                  iconRight: true,
                  width: buttonWidth,
                  height: 52,
                  onPressed: () async {
                    await tutorial.loadLibrary();
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            tutorial.MissaoReciclagemTutorialScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
                Builder(
                  builder: (context) {
                    final styles = Theme.of(context).extension<GameStyles>();
                    return Narrable.text(
                      'Conheça as regras antes de jogar',
                      style: styles?.hint,
                      readOnFocus: false,
                    );
                  },
                ),
                const SizedBox(height: 14),
                PixelButton(
                  label: 'JOGAR',
                  icon: Icons.play_arrow_rounded,
                  iconRight: true,
                  width: buttonWidth,
                  height: 52,
                  onPressed: () async {
                    await _precacheReciclagemBackgrounds(context);
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GameLoadingScreen(
                          title: 'Missão Reciclagem',
                          backgroundAsset:
                              'assets/games/missao-reciclagem/background-reciclagem.png',
                          mobileBackgroundAsset:
                              'assets/games/missao-reciclagem/background-missao-mobile.png',
                          onLoad: () async {
                            try {
                              await MissaoReciclagemGame.preloadAssets()
                                  .timeout(
                                const Duration(seconds: 8),
                                onTimeout: () async {},
                              );
                            } catch (_) {}
                          },
                          onReady: (_) => const MissaoReciclagemGameScreen(),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
                Builder(
                  builder: (context) {
                    final styles = Theme.of(context).extension<GameStyles>();
                    return Narrable.text(
                      'Separar o lixo nunca foi tão divertido!',
                      style: styles?.hint,
                      readOnFocus: false,
                    );
                  },
                ),
                const SizedBox(height: 16),
                PixelButton(
                  label: 'ACESSIBILIDADE',
                  icon: Icons.accessibility_new_rounded,
                  iconRight: true,
                  width: buttonWidth,
                  height: 52,
                  onPressed: () async {
                    await showA11yPanelBottomSheet(context);
                  },
                ),
                const SizedBox(height: 6),
                Builder(
                  builder: (context) {
                    final styles = Theme.of(context).extension<GameStyles>();
                    return Narrable.text(
                      'Ajuste contraste e narração antes de jogar',
                      style: styles?.hint,
                      readOnFocus: false,
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

Future<void> _precacheReciclagemBackgrounds(BuildContext context) async {
  await Future.wait<void>([
    precacheImage(
      const AssetImage(
        'assets/games/missao-reciclagem/background-reciclagem.png',
      ),
      context,
    ),
    precacheImage(
      const AssetImage(
        'assets/games/missao-reciclagem/background-missao-mobile.png',
      ),
      context,
    ),
  ]);
}
