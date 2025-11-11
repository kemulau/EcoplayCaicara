import 'package:flutter/material.dart';
import '../../../widgets/pixel_button.dart';
import '../../../widgets/game_frame.dart';
import 'game.dart' deferred as game;
import 'tutorial.dart' deferred as tutorial;
import 'livro_do_mangue.dart' deferred as livro; // <<< NOVO
import '../../../theme/game_styles.dart';
import '../../../widgets/a11y_panel.dart'; // [A11Y]

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
                Text(
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
                    return Text(
                      'Aprenda as regras rapidamente',
                      style: styles?.hint,
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
                  onPressed: () async {
                    await game.loadLibrary();
                    // ignore: use_build_context_synchronously
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => game.TocaGameScreen()),
                    );
                  },
                ),
                const SizedBox(height: 6),
                Builder(
                  builder: (context) {
                    final styles = Theme.of(context).extension<GameStyles>();
                    return Text('Ir direto para o jogo', style: styles?.hint);
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
                    if (!context.mounted) return; // evita usar context após await
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
                    return Text(
                      'Abrir livro com páginas interativas',
                      style: styles?.hint,
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
                    await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) => const A11yPanel(),
                    );
                  },
                ),
                const SizedBox(height: 6),
                Builder(
                  builder: (context) {
                    final styles = Theme.of(context).extension<GameStyles>();
                    return Text(
                      'Ajuste fontes, contraste e cores',
                      style: styles?.hint,
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
