import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

class TypingLoopSfx {
  TypingLoopSfx({this.volume = 0.45});

  final double volume;
  final AudioPlayer _player = AudioPlayer(playerId: 'typing_loop');
  Timer? _segmentTimer;

  /// Desbloqueia a reprodução de áudio no Web (Edge/Chrome),
  /// realizando uma reprodução silenciosa em resposta a um gesto do usuário.
  Future<void> unlock() async {
    _segmentTimer?.cancel();
    await _player.setReleaseMode(ReleaseMode.stop);
    final currentVol = volume;
    // Toca rapidamente em volume 0 para satisfazer a política de auto‑play.
    await _player.setVolume(0);
    await _player.play(AssetSource('audio/tech-ui-typing-30790.mp3'));
    await _player.pause();
    await _player.setVolume(currentVol);
  }

  /// Inicia o áudio e mantém um loop do segmento [segment] começando em 0s.
  Future<void> start({Duration segment = const Duration(seconds: 4)}) async {
    _segmentTimer?.cancel();
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setVolume(volume);
    await _player.play(AssetSource('audio/tech-ui-typing-30790.mp3'));
    // Reposiciona para 0 a cada [segment] para manter o loop do trecho inicial.
    _segmentTimer = Timer.periodic(segment, (_) async {
      await _player.seek(Duration.zero);
      await _player.resume();
    });
  }

  Future<void> stop() async {
    _segmentTimer?.cancel();
    await _player.stop();
  }

  Future<void> dispose() async {
    _segmentTimer?.cancel();
    await _player.dispose();
  }
}

