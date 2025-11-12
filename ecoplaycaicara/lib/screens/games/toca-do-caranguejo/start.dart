import 'package:flutter/material.dart';
import '../../../widgets/pixel_button.dart';
import '../../../widgets/game_frame.dart';
import 'game.dart' deferred as game;
import 'tutorial.dart' deferred as tutorial;
import 'livro_do_mangue.dart' deferred as livro; // <<< NOVO
import '../../../theme/game_styles.dart';
import '../../../widgets/accessibility/panel.dart'; // [A11Y]
import '../../../widgets/game_loading_screen.dart';
import '../../../widgets/narrable.dart';

class TocaStartScreen extends StatelessWidget {
  const TocaStartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: 'Toca do Caranguejo',
      backgroundAsset: 'assets/games/toca-do-caranguejo/background.png',
      mobileBackgroundAsset:
          'assets/games/toca-do-caranguejo/background-mobile.png',
      fill: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          final btnWidth = (maxW * 0.72).clamp(200.0, 320.0);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Narrable.text(
                  'Escolha uma opção',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),

                // ---------------------- TUTORIAL ----------------------
                PixelButton(
                  label: 'TUTORIAL',
                  icon: Icons.menu_book_rounded,
                  iconRight: true,
                  width: btnWidth,
                  height: 52,
                  onPressed: () async {
                    await tutorial.loadLibrary();
                    // ignore: use_build_context_synchronously
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => tutorial.TocaTutorialScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
                Builder(
                  builder: (context) {
                    final styles = Theme.of(context).extension<GameStyles>();
                    return Narrable.text(
                      'Aprenda as regras rapidamente',
                      style: styles?.hint,
                      readOnFocus: false,
                    );
                  },
                ),

                // ------------------------- JOGAR -----------------------
                const SizedBox(height: 12),
                PixelButton(
                  label: 'JOGAR',
                  icon: Icons.play_arrow_rounded,
                  iconRight: true,
                  width: btnWidth,
                  height: 52,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GameLoadingScreen(
                          title: 'Toca do Caranguejo',
                          backgroundAsset:
                              'assets/games/toca-do-caranguejo/background.png',
                          mobileBackgroundAsset:
                              'assets/games/toca-do-caranguejo/background-mobile.png',
                          onLoad: () async {
                            await game.loadLibrary();
                            try {
                              await game
                                  .preloadTocaDoCaranguejoGame()
                                  .timeout(
                                    const Duration(seconds: 8),
                                    onTimeout: () async {},
                                  );
                            } catch (_) {}
                          },
                          onReady: (_) => game.TocaGameScreen(),
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
                      'Ir direto para o jogo',
                      style: styles?.hint,
                      readOnFocus: false,
                    );
                  },
                ),

                // ------------------ LIVRO DO MANGUE -------------------
                const SizedBox(height: 12),
                PixelButton(
                  label: 'LIVRO DO MANGUE',
                  icon: Icons.auto_stories_rounded,
                  iconRight: true,
                  width: btnWidth,
                  height: 52,
                  onPressed: () async {
                    await livro.loadLibrary();
                    if (!context.mounted)
                      return; // evita usar context após await
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => livro.LivroDoMangueScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
                Builder(
                  builder: (context) {
                    final styles = Theme.of(context).extension<GameStyles>();
                    return Narrable.text(
                      'Abrir livro com páginas interativas',
                      style: styles?.hint,
                      readOnFocus: false,
                    );
                  },
                ),

                // --------------------- ACESSIBILIDADE ------------------
                const SizedBox(height: 12),
                PixelButton(
                  label: 'ACESSIBILIDADE',
                  icon: Icons.accessibility_new_rounded,
                  iconRight: true,
                  width: btnWidth,
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
                      'Ajuste fontes, contraste e cores',
                      style: styles?.hint,
                      readOnFocus: false,
                    );
                  },
                ),
                // [A11Y] fim
              ],
            ),
          );
        },
      ),
    );
  }
}
