import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/game_frame.dart';
import '../theme/theme_provider.dart';
import 'games/toca-do-caranguejo/start.dart';
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  final List<Map<String, String>> cards = const [
    {
      'image': 'assets/cards/mare-responsa.jpg',
      'title': 'Maré Responsa',
    },
    {
      'image': 'assets/cards/missao-reciclar.jpg',
      'title': 'Missão Reciclagem',
    },
    {
      'image': 'assets/cards/toca-do-caranguejo.jpg',
      'title': 'Toca do Caranguejo',
    },
    {
      'image': 'assets/cards/trilha-da-fauna.jpg',
      'title': 'Trilha da Fauna',
    },
  ];

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
          if (!isMobile && constraints.hasBoundedHeight && constraints.maxHeight.isFinite) {
            // Aqui o child está dentro de GamePanel, que já deflaciona 16px
            // de padding vertical. Só precisamos abater o padding interno do
            // SingleChildScrollView (16px verticais) para estimar o espaço útil.
            // Adicionamos uma pequena margem (8px) de folga para evitar corte por arredondamento.
            final usableH = (constraints.maxHeight - 16 - 8)
                .clamp(100.0, double.infinity);
            final perTileH = (usableH - vSpacing) / 2.0;
            widthByHeight = perTileH * aspect;
          }

          // Evitar 3 colunas: largura mínima para impedir 3 cards por linha
          final minWidthTwoCols = ((maxW - 2 * spacing) / 3.0) + 1;
          double cardWidth = isMobile ? baseW : (widthByHeight < baseW ? widthByHeight : baseW);
          // Em modo desktop, fixe o layout em 2x2 calculando o tamanho para caber 2 linhas
          // e 2 colunas sem rolagem, sempre que houver espaço suficiente.
          if (forceTwoByTwo) {
            // Garante que não extrapola o espaço disponível por largura.
            final double maxByWidth = (maxW - spacing) / 2.0;
            // E nem por altura (2 linhas + espaçamento e paddings já considerados acima).
            final double maxByHeight = widthByHeight;
            cardWidth = [cardWidth, maxByWidth, maxByHeight].reduce((a, b) => a < b ? a : b);
          }
          if (!isMobile) cardWidth = cardWidth < minWidthTwoCols ? minWidthTwoCols : cardWidth;
          final double cardHeight = cardWidth / aspect; // mantém 16:9

          // Calcula se o conteúdo extrapola a altura disponível
          final int columns = isMobile ? 1 : 2;
          final int rows = (cards.length / columns).ceil();
          final double estimatedContentHeight =
              rows * (cardHeight) + (rows - 1) * vSpacing + 16; // + padding interno do scroll

          final bool needsScroll =
              constraints.hasBoundedHeight && constraints.maxHeight.isFinite &&
              estimatedContentHeight > constraints.maxHeight;

          return SingleChildScrollView(
            physics: isMobile
                ? const BouncingScrollPhysics()
                : (needsScroll ? const ClampingScrollPhysics() : const NeverScrollableScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Wrap(
              spacing: spacing,
              runSpacing: vSpacing,
              alignment: WrapAlignment.center,
              children: cards.map((card) {
                return GameCard(
                  imagePath: card['image']!,
                  title: card['title']!,
                  molduraPath: 'assets/cards/moldura.png',
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
  final double width;
  final double height;

  const GameCard({
    super.key,
    required this.imagePath,
    required this.title,
    required this.molduraPath,
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
    final reduceMotion = context.read<ThemeProvider>().reduceMotion;
    if (reduceMotion) return;
    setState(() {
      _scale = hovering ? 1.05 : 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = context.watch<ThemeProvider>().reduceMotion;
    final scale = reduceMotion ? 1.0 : _scale;
    final animDuration = Duration(milliseconds: reduceMotion ? 80 : 200);
    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: GestureDetector(
        onTap: () {
          if (widget.title == 'Toca do Caranguejo') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TocaStartScreen()),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Em breve: ${widget.title}',
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
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
                        child: Image.asset(
                          widget.imagePath,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned.fill(
                        child: Image.asset(
                          widget.molduraPath,
                          fit: BoxFit.fill,
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
    );
  }
}
