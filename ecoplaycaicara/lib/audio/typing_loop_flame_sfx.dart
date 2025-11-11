import 'dart:async';
import 'package:flame_audio/flame_audio.dart';

/// Helper específico para FlameAudio BGM que reproduz
/// um pequeno trecho em loop (simulação de "typing").
///
/// Observações de compatibilidade com Flame:
/// - Garante que o prefixo global do cache fique em 'assets/' antes de inicializar.
/// - Inicializa o BGM apenas uma vez e faz preload do arquivo.
/// - Usa `FlameAudio.bgm` (recomendado para loops longos),
///   controlando o reinício por Timer do segmento desejado.
class TypingLoopFlameSfx {
  TypingLoopFlameSfx({this.volume = 0.25});

  // Mantém caminho relativo à pasta de assets para compatibilidade web/mobile.
  static const String _assetPath = 'audio/tech-ui-typing-30790.mp3';

  final double volume;
  Timer? _timer;
  bool _initialized = false;
  // Garante que o prefixo global esteja em 'assets/' para resolver assets web/mobile.

  Future<void> unlock() async {
    if (_initialized) return;
    FlameAudio.updatePrefix('assets/');
    FlameAudio.bgm.initialize();
    await FlameAudio.audioCache.load(_assetPath); // preload para reduzir latência
    _initialized = true;
  }

  Future<void> start({Duration segment = const Duration(seconds: 4)}) async {
    await unlock();
    await FlameAudio.bgm.stop();
    await FlameAudio.bgm.play(_assetPath, volume: volume);

    _timer?.cancel();
    _timer = Timer.periodic(segment, (_) async {
      await FlameAudio.bgm.stop();
      await FlameAudio.bgm.play(_assetPath, volume: volume);
    });
  }

  Future<void> stop() async {
    _timer?.cancel();
    await FlameAudio.bgm.stop();
  }

  Future<void> dispose() async {
    _timer?.cancel();
    await FlameAudio.bgm.stop();
  }
}
