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
                          'Clique nos caranguejos para capturá-los 🎯, '
                          'mas preste atenção ao tamanho e ao período reprodutivo! 🦀\n\n'
                          '❌ Capturar caranguejos em defeso ou muito pequenos gera -20 pontos '
                          'e mostra uma explicação sobre a importância da preservação.\n\n'
                          '✅ Se você respeitar o defeso ou evitar os jovens, recebe +15 pontos e um aviso:\n'
                          '“Proteger o ciclo reprodutivo mantém o mangue vivo!” 🌱\n\n'
                          '🧹 Ao clicar em objetos de lixo, como latas e sacolas, '
                          'você ajuda a limpar o mangue e ganha +20 pontos!\n\n'
                          '📚 Leia as curiosidades e jogue por 60 segundos ⏱️!',
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
