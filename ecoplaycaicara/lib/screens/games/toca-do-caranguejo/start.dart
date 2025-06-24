import 'package:flutter/material.dart';
import '../../../widgets/pixel_button.dart';
import 'game.dart';

class TocaStartScreen extends StatelessWidget {
  const TocaStartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const textoEscuro = Color(0xFF3B2C1A); // Marrom escuro para melhor leitura

    return Scaffold(
      body: Stack(
        children: [
          // Imagem de fundo com leve esmaecimento
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.white.withOpacity(0.2),
                BlendMode.lighten,
              ),
              child: Image.asset(
                'lib/assets/games/toca-do-caranguejo/background.png',
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Conteúdo principal
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '🐚 Toca do Caranguejo 🦀',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: textoEscuro,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      border: Border.all(color: textoEscuro),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      children: [
                        Text(
                          '🦀 Como Jogar',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textoEscuro,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Clique no caranguejo para ganhar pontos 🎯.\n'
                          'Ele aparece aleatoriamente em uma das tocas.\n\n'
                          'Leia as curiosidades e jogue por 60 segundos ⏱️!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: textoEscuro,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  PixelButton(
                    label: 'COMEÇAR JOGO',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TocaGameScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
