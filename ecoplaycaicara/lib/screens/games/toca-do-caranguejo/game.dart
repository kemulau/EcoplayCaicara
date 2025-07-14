import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../widgets/pixel_button.dart';
import 'start.dart';

/// Percentuais das posições das tocas em relação
/// à largura e altura da tela base (1536x1024).
const _tocasPercentuais = <Offset>[
  Offset(0.091, 0.742),
  Offset(0.176, 0.713),
  Offset(0.260, 0.693),
  Offset(0.345, 0.684),
  Offset(0.430, 0.693),
  Offset(0.514, 0.713),
  Offset(0.599, 0.732),
  Offset(0.684, 0.752),
  Offset(0.130, 0.840),
  Offset(0.221, 0.820),
  Offset(0.312, 0.811),
  Offset(0.404, 0.811),
  Offset(0.495, 0.820),
  Offset(0.586, 0.840),
  Offset(0.677, 0.859),
];

/// Gera as coordenadas das tocas de acordo com o
/// tamanho da tela.
List<Offset> gerarTocas(Size size) {
  return _tocasPercentuais
      .map((p) => Offset(p.dx * size.width, p.dy * size.height))
      .toList();
}

class TocaGameScreen extends StatefulWidget {
  const TocaGameScreen({super.key});

  @override
  State<TocaGameScreen> createState() => _TocaGameScreenState();
}

class _TocaGameScreenState extends State<TocaGameScreen> {
  int pontuacao = 0;
  int tempoRestante = 60;
  bool mostrarPopup = false;
  int popupIndex = 0;
  Offset caranguejoPosition = Offset.zero;
  bool caranguejoPequeno = false;
  bool mostrarAcaoPopup = false;
  String mensagemAcao = '';

  List<Offset> tocas = [];

  final List<String> mensagens = [
    '🦀 Os caranguejos ajudam a manter o solo do mangue saudável!',
    '🌱 O manguezal é o berçário de muitas espécies marinhas!',
    '🚯 Não jogue lixo no mangue. Preserve a natureza!'
  ];

  Timer? cronometro;
  Timer? popupTimer;
  Timer? moverCaranguejoTimer;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      tocas = gerarTocas(size);

      setState(() {
        caranguejoPosition = tocas[Random().nextInt(tocas.length)];
        caranguejoPequeno = Random().nextBool();
      });

      cronometro = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          tempoRestante--;
          if (tempoRestante <= 0) {
            cronometro?.cancel();
            moverCaranguejoTimer?.cancel();
            popupTimer?.cancel();
          }
        });
      });

      popupTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (tempoRestante > 0) {
          setState(() {
            mostrarPopup = true;
            popupIndex = (popupIndex + 1) % mensagens.length;
          });
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted) setState(() => mostrarPopup = false);
          });
        }
      });

      moverCaranguejoTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (tempoRestante > 0) {
          setState(() {
            caranguejoPosition = tocas[Random().nextInt(tocas.length)];
            caranguejoPequeno = Random().nextBool();
          });
        }
      });
    });
  }

  void _clicouNoCaranguejo() {
    setState(() {
      if (caranguejoPequeno) {
        pontuacao -= 20;
        mensagemAcao = '⚠️ Capturar caranguejo jovem prejudica o ciclo do mangue!';
      } else {
        pontuacao += 15;
        mensagemAcao = '✅ Proteger o ciclo reprodutivo mantém o mangue vivo!';
      }
      mostrarAcaoPopup = true;
      caranguejoPosition = tocas[Random().nextInt(tocas.length)];
      caranguejoPequeno = Random().nextBool();
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => mostrarAcaoPopup = false);
    });
  }

  @override
  void dispose() {
    cronometro?.cancel();
    popupTimer?.cancel();
    moverCaranguejoTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          SizedBox(
            width: size.width,
            height: size.height,
            child: Image.asset(
              'lib/assets/games/toca-do-caranguejo/background.png',
              fit: BoxFit.cover,
            ),
          ),

          Positioned(top: 20, left: 20, child: _infoBox('🎯 Pontuação: $pontuacao')),
          Positioned(top: 20, right: 20, child: _infoBox('🕒 Tempo: $tempoRestante s')),

          // Botões de som e configuração
          Positioned(
            top: 80,
            right: 20,
            child: Column(
              children: [
                _iconButton(Icons.volume_up),
                const SizedBox(height: 8),
                _iconButton(Icons.settings),
              ],
            ),
          ),

          if (tempoRestante > 0)
            Positioned(
              left: caranguejoPosition.dx,
              top: caranguejoPosition.dy,
              child: GestureDetector(
                onTap: _clicouNoCaranguejo,
                child: Image.asset(
                  'lib/assets/games/toca-do-caranguejo/caranguejo.png',
                  width: caranguejoPequeno ? 50 : 80,
                ),
              ),
            ),

          if (mostrarPopup && tempoRestante > 0)
            Center(
              child: _popupMensagem(mensagens[popupIndex]),
            ),

          if (mostrarAcaoPopup && tempoRestante > 0)
            Center(
              child: _popupMensagem(mensagemAcao),
            ),

          if (tempoRestante <= 0)
            Center(
              child: _fimDeJogoDialog(),
            ),
        ],
      ),
    );
  }

  Widget _infoBox(String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.brown),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.brown,
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        border: Border.all(color: Colors.brown),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        iconSize: 24,
        icon: Icon(icon, color: Colors.brown),
        onPressed: () {},
      ),
    );
  }

  Widget _popupMensagem(String texto) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.brown, width: 3),
        boxShadow: [
          BoxShadow(
            blurRadius: 6,
            offset: const Offset(4, 4),
            color: Colors.black.withOpacity(0.4),
          ),
        ],
      ),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.brown,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _fimDeJogoDialog() {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.brown, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            offset: const Offset(4, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '🏁 Fim de Jogo!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.brown,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '🎯 Sua pontuação: $pontuacao',
            style: const TextStyle(fontSize: 18, color: Colors.black87),
          ),
          const SizedBox(height: 24),
          PixelButton(
            label: '🔁 Jogar Novamente',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const TocaGameScreen()),
              );
            },
          ),
          const SizedBox(height: 16),
          PixelButton(
            label: '🏠 Voltar ao Início',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const TocaStartScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
