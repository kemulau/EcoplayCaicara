import 'dart:math' as math;

/// Valores padrão e limites dos controles de narração.
class TtsDefaults {
  const TtsDefaults._();

  static const double rateMin = 0.85;
  static const double rateMax = 1.15;
  static const double rateDefault = 1.0;

  static const double pitchMin = -3.0;
  static const double pitchMax = 3.0;
  static const double pitchDefault = 0.0;

  static const double volumeMin = 0.6;
  static const double volumeMax = 1.0;
  static const double volumeDefault = 0.85;

  /// Converte semitons para o valor esperado pelo motor TTS (fator multiplicador).
  static double enginePitchFromSemitones(double semitones) {
    return math.pow(2, semitones / 12.0).toDouble();
  }

  /// Converte do valor do motor TTS (fator multiplicador) para semitons.
  static double semitonesFromEnginePitch(double pitch) {
    if (pitch <= 0) return 0;
    return 12.0 * (math.log(pitch) / math.ln2);
  }
}
