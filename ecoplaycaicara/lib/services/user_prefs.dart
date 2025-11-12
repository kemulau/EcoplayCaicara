import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tts_defaults.dart';

class UserPrefs {
  UserPrefs._();

  static final UserPrefs instance = UserPrefs._();

  static SharedPreferences? _prefs;

  static const String _keyAudioEnabled = 'toca_audio_enabled';

  static const String _keyTtsEnabled = 'tts.enabled';
  static const String _keyTtsRate = 'tts.rate';
  static const String _keyTtsPitch = 'tts.pitch';
  static const String _keyTtsVolume = 'tts.volume';
  static const String _keyTtsVoiceName = 'tts.voice_name';
  static const String _keyTtsLang = 'tts.lang';
  static const String _keyTtsReadTutorials = 'tts.read_tutorials';
  static const String _keyTtsReadWarnings = 'tts.read_warnings';
  static const String _keyTtsReadScores = 'tts.read_scores';
  static const String _keyTtsAudioUnlocked = 'tts.audio_unlocked';
  static const String _keyTtsPitchSemitones = 'tts.pitch_semitones';
  static const String _keyShowTooltips = 'ui.show_tooltips';
  static const String _keyTtsReadUi = 'tts.read_ui';

  bool _loaded = false;

  bool _ttsEnabled = false;
  double _ttsRate = TtsDefaults.rateDefault;
  double _ttsPitch = TtsDefaults.pitchDefault;
  double _ttsVolume = TtsDefaults.volumeDefault;
  String? _ttsVoiceName;
  String _ttsLang = 'pt-BR';
  bool _ttsReadTutorials = true;
  bool _ttsReadWarnings = true;
  bool _ttsReadScores = true;
  bool _ttsAudioUnlocked = false;
  bool _showTooltips = true;
  bool _ttsReadUi = false;

  final ValueNotifier<bool> ttsEnabledNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> showTooltipsNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> ttsReadUiNotifier = ValueNotifier<bool>(false);

  static Future<SharedPreferences> _instance() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  bool get isLoaded => _loaded;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await _instance();
    _ttsEnabled = prefs.getBool(_keyTtsEnabled) ?? _ttsEnabled;
    _ttsRate = (prefs.getDouble(_keyTtsRate) ?? _ttsRate)
        .clamp(TtsDefaults.rateMin, TtsDefaults.rateMax)
        .toDouble();
    final bool pitchStoredAsSemitones =
        prefs.getBool(_keyTtsPitchSemitones) ?? false;
    final double? storedPitchValue = prefs.getDouble(_keyTtsPitch);
    double rawPitch = storedPitchValue ?? _ttsPitch;
    if (!pitchStoredAsSemitones) {
      if (storedPitchValue != null) {
        rawPitch = TtsDefaults.semitonesFromEnginePitch(
          storedPitchValue.clamp(0.01, double.maxFinite),
        );
        await prefs.setDouble(_keyTtsPitch, rawPitch);
      }
      await prefs.setBool(_keyTtsPitchSemitones, true);
    }
    _ttsPitch = rawPitch
        .clamp(TtsDefaults.pitchMin, TtsDefaults.pitchMax)
        .toDouble();
    _ttsVolume = (prefs.getDouble(_keyTtsVolume) ?? _ttsVolume)
        .clamp(TtsDefaults.volumeMin, TtsDefaults.volumeMax)
        .toDouble();
    _ttsVoiceName = prefs.getString(_keyTtsVoiceName);
    _ttsLang = prefs.getString(_keyTtsLang) ?? _ttsLang;
    _ttsReadTutorials =
        prefs.getBool(_keyTtsReadTutorials) ?? _ttsReadTutorials;
    _ttsReadWarnings = prefs.getBool(_keyTtsReadWarnings) ?? _ttsReadWarnings;
    _ttsReadScores = prefs.getBool(_keyTtsReadScores) ?? _ttsReadScores;
    _ttsAudioUnlocked =
        prefs.getBool(_keyTtsAudioUnlocked) ?? _ttsAudioUnlocked;
    _showTooltips = prefs.getBool(_keyShowTooltips) ?? _showTooltips;
    _ttsReadUi = prefs.getBool(_keyTtsReadUi) ?? _ttsReadUi;
    if (ttsEnabledNotifier.value != _ttsEnabled) {
      ttsEnabledNotifier.value = _ttsEnabled;
    }
    if (showTooltipsNotifier.value != _showTooltips) {
      showTooltipsNotifier.value = _showTooltips;
    }
    if (ttsReadUiNotifier.value != _ttsReadUi) {
      ttsReadUiNotifier.value = _ttsReadUi;
    }
    _loaded = true;
  }

  bool get ttsEnabled => _ttsEnabled;
  double get ttsRate => _ttsRate;
  double get ttsPitch => _ttsPitch;
  double get ttsVolume => _ttsVolume;
  String? get ttsVoiceName => _ttsVoiceName;
  String get ttsLang => _ttsLang;
  bool get ttsReadTutorials => _ttsReadTutorials;
  bool get ttsReadWarnings => _ttsReadWarnings;
  bool get ttsReadScores => _ttsReadScores;
  bool get ttsAudioUnlocked => _ttsAudioUnlocked;
  bool get showTooltips => _showTooltips;
  bool get ttsReadUi => _ttsReadUi;

  Future<void> setTtsEnabled(bool value) async {
    await ensureLoaded();
    _ttsEnabled = value;
    final prefs = await _instance();
    await prefs.setBool(_keyTtsEnabled, value);
    if (ttsEnabledNotifier.value != value) {
      ttsEnabledNotifier.value = value;
    }
  }

  Future<void> setTtsRate(double value) async {
    await ensureLoaded();
    final double clamped = value
        .clamp(TtsDefaults.rateMin, TtsDefaults.rateMax)
        .toDouble();
    _ttsRate = clamped;
    final prefs = await _instance();
    await prefs.setDouble(_keyTtsRate, clamped);
  }

  Future<void> setTtsPitch(double value) async {
    await ensureLoaded();
    final double clamped = value
        .clamp(TtsDefaults.pitchMin, TtsDefaults.pitchMax)
        .toDouble();
    _ttsPitch = clamped;
    final prefs = await _instance();
    await prefs.setDouble(_keyTtsPitch, clamped);
    await prefs.setBool(_keyTtsPitchSemitones, true);
  }

  Future<void> setTtsVolume(double value) async {
    await ensureLoaded();
    final double clamped = value
        .clamp(TtsDefaults.volumeMin, TtsDefaults.volumeMax)
        .toDouble();
    _ttsVolume = clamped;
    final prefs = await _instance();
    await prefs.setDouble(_keyTtsVolume, clamped);
  }

  Future<void> setTtsVoiceName(String? value) async {
    await ensureLoaded();
    final prefs = await _instance();
    final String? sanitized = (value == null || value.trim().isEmpty)
        ? null
        : value.trim();
    _ttsVoiceName = sanitized;
    if (sanitized == null) {
      await prefs.remove(_keyTtsVoiceName);
    } else {
      await prefs.setString(_keyTtsVoiceName, sanitized);
    }
  }

  Future<void> setTtsLang(String value) async {
    await ensureLoaded();
    _ttsLang = value.trim().isEmpty ? 'pt-BR' : value.trim();
    final prefs = await _instance();
    await prefs.setString(_keyTtsLang, _ttsLang);
  }

  Future<void> setTtsReadTutorials(bool value) async {
    await ensureLoaded();
    _ttsReadTutorials = value;
    final prefs = await _instance();
    await prefs.setBool(_keyTtsReadTutorials, value);
  }

  Future<void> setTtsReadWarnings(bool value) async {
    await ensureLoaded();
    _ttsReadWarnings = value;
    final prefs = await _instance();
    await prefs.setBool(_keyTtsReadWarnings, value);
  }

  Future<void> setTtsReadScores(bool value) async {
    await ensureLoaded();
    _ttsReadScores = value;
    final prefs = await _instance();
    await prefs.setBool(_keyTtsReadScores, value);
  }

  Future<void> setTtsAudioUnlocked(bool value) async {
    await ensureLoaded();
    _ttsAudioUnlocked = value;
    final prefs = await _instance();
    await prefs.setBool(_keyTtsAudioUnlocked, value);
  }

  Future<void> setShowTooltips(bool value) async {
    await ensureLoaded();
    _showTooltips = value;
    final prefs = await _instance();
    await prefs.setBool(_keyShowTooltips, value);
    if (showTooltipsNotifier.value != value) {
      showTooltipsNotifier.value = value;
    }
  }

  Future<void> setTtsReadUi(bool value) async {
    await ensureLoaded();
    _ttsReadUi = value;
    final prefs = await _instance();
    await prefs.setBool(_keyTtsReadUi, value);
    if (ttsReadUiNotifier.value != value) {
      ttsReadUiNotifier.value = value;
    }
  }

  static Future<bool> getAudioEnabled({bool defaultValue = true}) async {
    final prefs = await _instance();
    return prefs.getBool(_keyAudioEnabled) ?? defaultValue;
  }

  static Future<void> setAudioEnabled(bool value) async {
    final prefs = await _instance();
    await prefs.setBool(_keyAudioEnabled, value);
  }
}
