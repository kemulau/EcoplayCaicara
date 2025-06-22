import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  final List<Map<String, String>> cards = const [
    {
      'image': 'lib/assets/cards/mare-responsa.jpg',
      'title': 'Maré Responsa',
    },
    {
      'image': 'lib/assets/cards/missao-reciclar.jpg',
      'title': 'Missão Reciclagem',
    },
    {
      'image': 'lib/assets/cards/toca-do-caranguejo.jpg',
      'title': 'Toca do Caranguejo',
    },
    {
      'image': 'lib/assets/cards/trilha-da-fauna.jpg',
      'title': 'Trilha da Fauna',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1000;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E1),
      body: SafeArea(
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isLargeScreen = constraints.maxWidth >= 1000;
              final cardWidth = isMobile
                  ? screenWidth * 0.9
                  : isTablet
                  ? screenWidth * 0.42
                  : screenWidth * 0.33; // 2 colunas com 24px de espaçamento entre e margens

              final cardHeight = cardWidth * 0.5625;

              return SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                child: Column(
                  children: [
                    Text(
                      'Ecoplay Caiçara',
                      style: GoogleFonts.pressStart2p(
                        fontSize: isMobile ? 16 : 22,
                        color: const Color(0xFF8B4B35),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 24,
                      runSpacing: 24,
                      alignment: WrapAlignment.center,
                      children: cards.map((card) {
                        return GameCard(
                          imagePath: card['image']!,
                          molduraPath: 'lib/assets/cards/moldura.png',
                          width: cardWidth,
                          height: cardHeight,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class GameCard extends StatefulWidget {
  final String imagePath;
  final String molduraPath;
  final double width;
  final double height;

  const GameCard({
    super.key,
    required this.imagePath,
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
    setState(() {
      _scale = hovering ? 1.05 : 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Abrindo: ${widget.imagePath.split('/').last.replaceAll('.jpg', '')}',
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 200),
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
