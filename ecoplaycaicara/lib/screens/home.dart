import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/game_frame.dart';
import '../widgets/narrable.dart';
import '../theme/color_matrices.dart';
import '../theme/theme_provider.dart';
import 'games/toca-do-caranguejo/start.dart';

const ColorFilter _grayscaleFilter =
    ColorFilter.matrix(kRelativeLuminanceGrayscaleMatrix);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const List<Map<String, dynamic>> cards = [
    {
      'image': 'assets/cards/toca-do-caranguejo.jpg',
      'title': 'Toca do Caranguejo',
      'available': true,
    },
    {
      'image': 'assets/cards/missao-reciclar.jpg',
      'title': 'Missão Reciclagem',
      'available': true,
    },
    {
      'image': 'assets/cards/mare-responsa.jpg',
      'title': 'Maré Responsa',
      'available': false,
    },
    {
      'image': 'assets/cards/trilha-da-fauna.jpg',
      'title': 'Trilha da Fauna',
      'available': false,
    },
  ];

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _didPrecache = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _precacheCards());
  }

  Future<void> _precacheCards() async {
    if (!mounted || _didPrecache) return;
    _didPrecache = true;
    final futures = <Future<void>>[];
    for (final card in HomeScreen.cards) {
      final image = card['image'] as String;
      futures.add(precacheImage(AssetImage(image), context));
    }
    futures.add(precacheImage(
      const AssetImage('assets/cards/moldura.png'),
      context,
    ));
    await Future.wait(futures);
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: 'Ecoplay Caiçara',
      fill: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          const spacing = 24.0;
          const vSpacing = 24.0;
          const aspect = 16 / 9; // largura/altura
          // Base responsiva: 1 coluna no mobile; 2 colunas fixas acima de 600px.
          final bool isMobile = maxW < 600;
          // Mantém 2x2 fixo quando houver espaço de desktop (>= ~1100px internos do painel),
          // alinhado com o congelamento do painel em 1200px.
          final bool forceTwoByTwo = !isMobile && maxW >= 1100;

          // Largura visando 2 colunas
          final double baseW = isMobile ? maxW * 0.92 : (maxW - spacing) / 2.0;

          // Ajuste considerando a altura disponível (para caber 2 linhas)
          double widthByHeight = baseW;
          if (!isMobile &&
              constraints.hasBoundedHeight &&
              constraints.maxHeight.isFinite) {
            // Aqui o child está dentro de GamePanel, que já deflaciona 16px
            // de padding vertical. Só precisamos abater o padding interno do
            // SingleChildScrollView (16px verticais) para estimar o espaço útil.
            // Adicionamos uma pequena margem (8px) de folga para evitar corte por arredondamento.
            final usableH = (constraints.maxHeight - 16 - 8).clamp(
              100.0,
              double.infinity,
            );
            final perTileH = (usableH - vSpacing) / 2.0;
            widthByHeight = perTileH * aspect;
          }

          // Evitar 3 colunas: largura mínima para impedir 3 cards por linha
          final minWidthTwoCols = ((maxW - 2 * spacing) / 3.0) + 1;
          double cardWidth = isMobile
              ? baseW
              : (widthByHeight < baseW ? widthByHeight : baseW);
          // Em modo desktop, fixe o layout em 2x2 calculando o tamanho para caber 2 linhas
          // e 2 colunas sem rolagem, sempre que houver espaço suficiente.
          if (forceTwoByTwo) {
            // Garante que não extrapola o espaço disponível por largura.
            final double maxByWidth = (maxW - spacing) / 2.0;
            // E nem por altura (2 linhas + espaçamento e paddings já considerados acima).
            final double maxByHeight = widthByHeight;
            cardWidth = [
              cardWidth,
              maxByWidth,
              maxByHeight,
            ].reduce((a, b) => a < b ? a : b);
          }
          if (!isMobile)
            cardWidth = cardWidth < minWidthTwoCols
                ? minWidthTwoCols
                : cardWidth;
          final double cardHeight = cardWidth / aspect; // mantém 16:9

          // Calcula se o conteúdo extrapola a altura disponível
          final int columns = isMobile ? 1 : 2;
          final int rows = (HomeScreen.cards.length / columns).ceil();
          final double estimatedContentHeight =
              rows * (cardHeight) +
              (rows - 1) * vSpacing +
              16; // + padding interno do scroll

          final bool needsScroll =
              constraints.hasBoundedHeight &&
              constraints.maxHeight.isFinite &&
              estimatedContentHeight > constraints.maxHeight;

          return SingleChildScrollView(
            physics: isMobile
                ? const BouncingScrollPhysics()
                : (needsScroll
                      ? const ClampingScrollPhysics()
                      : const NeverScrollableScrollPhysics()),
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
            child: Wrap(
              spacing: spacing,
              runSpacing: vSpacing,
              alignment: WrapAlignment.center,
              children: HomeScreen.cards.map((card) {
                return GameCard(
                  imagePath: card['image'] as String,
                  title: card['title'] as String,
                  molduraPath: 'assets/cards/moldura.png',
                  isAvailable: card['available'] as bool,
                  width: cardWidth,
                  height: cardHeight,
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

class GameCard extends StatefulWidget {
  final String imagePath;
  final String molduraPath;
  final String title;
  final bool isAvailable;
  final double width;
  final double height;

  const GameCard({
    super.key,
    required this.imagePath,
    required this.title,
    required this.molduraPath,
    required this.isAvailable,
    required this.width,
    required this.height,
  });

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard>
    with SingleTickerProviderStateMixin {
  double _scale = 1.0;

  void _onHover(bool hovering) {
    if (!widget.isAvailable) return;
    final reduceMotion = context.read<ThemeProvider>().reduceMotion;
    if (reduceMotion) return;
    setState(() {
      _scale = hovering ? 1.05 : 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = context.watch<ThemeProvider>().reduceMotion;
    final scale = (reduceMotion || !widget.isAvailable) ? 1.0 : _scale;
    final animDuration = Duration(milliseconds: reduceMotion ? 80 : 200);
    final double devicePixelRatio =
        MediaQuery.of(context).devicePixelRatio.clamp(1.0, 3.0);
    final int cacheWidth =
        (widget.width * devicePixelRatio).clamp(64, 2048).round();
    final int cacheHeight =
        (widget.height * devicePixelRatio).clamp(64, 2048).round();

    Widget buildCardImage({bool grayscale = false}) {
      final image = Image.asset(
        widget.imagePath,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
      );
      if (!grayscale) return image;
      return ColorFiltered(
        colorFilter: _grayscaleFilter,
        child: image,
      );
    }
    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: GestureDetector(
        onTap: () {
          if (!widget.isAvailable) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Narrable.text(
                  'Em breve: ${widget.title}',
                  readOnFocus: false,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                duration: const Duration(seconds: 2),
              ),
            );
            return;
          }
          if (widget.title == 'Toca do Caranguejo') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TocaStartScreen()),
            );
          } else if (widget.title == 'Missão Reciclagem') {
            Navigator.pushNamed(context, '/missao-reciclagem');
          }
        },
        child: Narrable(
          text: widget.title,
          tooltip: widget.title,
          child: AnimatedScale(
            scale: scale,
            duration: animDuration,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: widget.width,
                  height: widget.height,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: widget.isAvailable
                              ? buildCardImage()
                              : buildCardImage(grayscale: true),
                        ),
                        if (!widget.isAvailable)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withOpacity(0.25),
                            ),
                          ),
                        Positioned.fill(
                          child: Image.asset(
                            widget.molduraPath,
                            fit: BoxFit.fill,
                            cacheWidth: cacheWidth,
                            cacheHeight: cacheHeight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
