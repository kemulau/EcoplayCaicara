import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'tts_defaults.dart';
import 'user_prefs.dart';

class TtsVoiceOption {
  const TtsVoiceOption({
    required this.name,
    required this.locale,
    this.identifier,
    this.raw = const <String, dynamic>{},
  });

  final String name;
  final String locale;
  final String? identifier;
  final Map<String, dynamic> raw;
}

class _TtsQueueEntry {
  const _TtsQueueEntry(this.text, this.category);

  final String text;
  final String category;
}

class TtsService {
  TtsService._();

  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  Future<void>? _initFuture;
  bool _initialized = false;

  bool _enabled = true;
  double _rate = TtsDefaults.rateDefault;
  double _pitch = TtsDefaults.pitchDefault;
  double _volume = TtsDefaults.volumeDefault;
  String? _voiceName;
  String _language = 'pt-BR';
  bool _readTutorials = true;
  bool _readWarnings = true;
  bool _readScores = true;
  bool _readUi = false;
  bool _audioUnlocked = true;
  bool _requiresGesture = false;

  final List<_TtsQueueEntry> _queue = <_TtsQueueEntry>[];
  bool _processingQueue = false;
  bool _isSpeaking = false;
  Completer<void>? _speechCompleter;

  final ValueNotifier<bool> _needsGestureNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _uiNarrationEnabledNotifier = ValueNotifier<bool>(
    false,
  );

  final Map<String, DateTime> _debounceCache = <String, DateTime>{};
  static const Duration _debounceWindow = Duration(milliseconds: 1500);

  List<TtsVoiceOption> _availableVoices = const <TtsVoiceOption>[];
  List<Map<String, dynamic>> _availableVoicesPtBr =
      const <Map<String, dynamic>>[];
  bool _voicesLoaded = false;
  Future<void>? _voicesLoadFuture;
  DateTime? _voicesLoadedAt;

  static const Duration _voicesCacheTtl = Duration(seconds: 10);
  static const Duration _voicesFetchRetryDelay = Duration(milliseconds: 150);
  static const int _voicesFetchMaxAttempts = 20;

  static final RegExp _emojiRegex = RegExp(
    r'[\u{1F000}-\u{1FFFF}\u{200D}\u{FE0F}]',
    unicode: true,
  );

  ValueNotifier<bool> get needsGestureNotifier => _needsGestureNotifier;
  ValueNotifier<bool> get uiNarrationEnabledNotifier =>
      _uiNarrationEnabledNotifier;

  List<TtsVoiceOption> get voicesPtBr => List.unmodifiable(_availableVoices);
  bool get voicesLoaded => _voicesLoaded;
  bool get readTutorials => _readTutorials;
  bool get readWarnings => _readWarnings;
  bool get readScores => _readScores;
  bool get readUi => _readUi;

  bool get enabled => _enabled;
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    _refreshUiNarrationFlag();
    _updatePromptState();
  }

  double get rate => _rate;
  set rate(double value) {
    final double clamped = value.clamp(
      TtsDefaults.rateMin,
      TtsDefaults.rateMax,
    );
    if (_rate == clamped) return;
    _rate = clamped;
    unawaited(_tts.setSpeechRate(_rate));
  }

  double get pitch => _pitch;
  set pitch(double value) {
    final double clamped = value.clamp(
      TtsDefaults.pitchMin,
      TtsDefaults.pitchMax,
    );
    if ((_pitch - clamped).abs() < 0.0001) return;
    _pitch = clamped;
    unawaited(_tts.setPitch(TtsDefaults.enginePitchFromSemitones(_pitch)));
  }

  double get volume => _volume;
  set volume(double value) {
    final double clamped = value.clamp(
      TtsDefaults.volumeMin,
      TtsDefaults.volumeMax,
    );
    if ((_volume - clamped).abs() < 0.0001) return;
    _volume = clamped;
    unawaited(_tts.setVolume(_volume));
  }

  String? get voiceName => _voiceName;
  set voiceName(String? value) {
    if (_voiceName == value) return;
    _voiceName = value;
    if (value != null) {
      unawaited(UserPrefs.instance.setTtsVoiceName(value));
    }
    if (_voicesLoaded) {
      final TtsVoiceOption? match =
          _voiceForName(value) ??
          (_availableVoices.isNotEmpty ? _availableVoices.first : null);
      if (match != null) {
        unawaited(_setVoice(match));
      }
    }
  }

  String get language => _language;
  set language(String value) {
    if (_language == value) return;
    _language = value;
    unawaited(_tts.setLanguage(_language));
  }

  Future<void> init() {
    return _initFuture ??= _initInternal();
  }

  Future<void> _initInternal() async {
    await UserPrefs.instance.ensureLoaded();
    _requiresGesture = kIsWeb || defaultTargetPlatform == TargetPlatform.iOS;
    _audioUnlocked = !_requiresGesture || UserPrefs.instance.ttsAudioUnlocked;

    await _configureEngine();
    _registerTtsHandlers();
    _initialized = true;
    updateFromPrefs(UserPrefs.instance);
  }

  Future<void> _configureEngine() async {
    try {
      await _tts.setSharedInstance(true);
    } catch (_) {
      // Algumas plataformas não suportam shared instance.
    }
    await _tts.awaitSpeakCompletion(true);
    _language = 'pt-BR';
    await _tts.setLanguage(_language);
    await _tts.setSpeechRate(_rate);
    await _tts.setPitch(TtsDefaults.enginePitchFromSemitones(_pitch));
    await _tts.setVolume(_volume);
  }

  void _registerTtsHandlers() {
    _tts.setCompletionHandler(_handleTtsCompletion);
    _tts.setCancelHandler(_handleTtsCompletion);
    _tts.setErrorHandler((message) {
      _handleTtsCompletion();
      if (kDebugMode) {
        debugPrint('TTS falhou: ${message ?? 'erro desconhecido'}');
      }
    });
  }

  void updateFromPrefs(UserPrefs prefs) {
    if (!prefs.isLoaded) {
      unawaited(
        prefs.ensureLoaded().then((_) {
          if (identical(prefs, UserPrefs.instance)) {
            updateFromPrefs(prefs);
          }
        }),
      );
      return;
    }

    enabled = prefs.ttsEnabled;
    rate = prefs.ttsRate;
    pitch = prefs.ttsPitch;
    volume = prefs.ttsVolume;
    _voiceName = prefs.ttsVoiceName;
    language = prefs.ttsLang;
    _readTutorials = prefs.ttsReadTutorials;
    _readWarnings = prefs.ttsReadWarnings;
    _readScores = prefs.ttsReadScores;
    _readUi = prefs.ttsReadUi;
    _audioUnlocked = !_requiresGesture || prefs.ttsAudioUnlocked;
    _refreshUiNarrationFlag();

    if (_voicesLoaded) {
      final TtsVoiceOption? current =
          _voiceForName(_voiceName) ??
          (_availableVoices.isNotEmpty ? _availableVoices.first : null);
      if (current != null) {
        unawaited(_setVoice(current));
      }
    }

    _updatePromptState();
  }

  Future<void> ensureUnlockedByUserGesture() async {
    await init();
    if (_audioUnlocked) {
      _updatePromptState();
      if (_queue.isNotEmpty) {
        unawaited(_processQueue());
      }
      return;
    }
    final bool hadQueuedSpeech = _queue.isNotEmpty;
    _audioUnlocked = true;
    await UserPrefs.instance.setTtsAudioUnlocked(true);
    _updatePromptState();
    if (hadQueuedSpeech) {
      unawaited(_processQueue());
    }
  }

  Future<List<Map<String, dynamic>>> loadVoices({bool force = false}) async {
    await ensureVoicesLoaded(force: force);
    return List<Map<String, dynamic>>.from(_availableVoicesPtBr);
  }

  Future<void> ensureVoicesLoaded({bool force = false}) async {
    await init();

    final DateTime now = DateTime.now();
    if (!force &&
        _voicesLoaded &&
        _voicesLoadedAt != null &&
        now.difference(_voicesLoadedAt!) < _voicesCacheTtl) {
      return;
    }

    final future = _voicesLoadFuture;
    if (future != null) {
      await future;
      return;
    }

    final completer = Completer<void>();
    _voicesLoadFuture = completer.future;
    try {
      final List<Map<String, dynamic>> voices = await _fetchVoicesWithBackoff();
      _availableVoicesPtBr = List<Map<String, dynamic>>.from(
        voices,
        growable: false,
      );
      _availableVoices = _availableVoicesPtBr
          .map(
            (map) => TtsVoiceOption(
              name: (map['name'] ?? '').toString(),
              locale: (map['locale'] ?? 'pt-BR').toString(),
              identifier: map['voiceIdentifier']?.toString(),
              raw: map,
            ),
          )
          .toList(growable: false);
      _voicesLoaded = true;
      _voicesLoadedAt = DateTime.now();

      await _applyDefaultVoiceIfNeeded();
    } finally {
      completer.complete();
      _voicesLoadFuture = null;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchVoicesWithBackoff() async {
    List<Map<String, dynamic>> lastResult = const <Map<String, dynamic>>[];
    for (int attempt = 0; attempt < _voicesFetchMaxAttempts; attempt++) {
      try {
        final List<dynamic>? rawList = await _tts.getVoices;
        final List<Map<String, dynamic>> filtered = _filterPtBrVoices(rawList);
        if (filtered.isNotEmpty) {
          return filtered;
        }
        lastResult = filtered;
      } on PlatformException catch (error) {
        if (kDebugMode) {
          final String code = error.message ?? error.code;
          debugPrint('Falha ao obter vozes (tentativa ${attempt + 1}): $code');
        }
      } catch (error) {
        if (kDebugMode) {
          debugPrint('Falha ao obter vozes (tentativa ${attempt + 1}): $error');
        }
      }

      if (attempt < _voicesFetchMaxAttempts - 1) {
        await Future<void>.delayed(_voicesFetchRetryDelay);
      }
    }
    return lastResult;
  }

  List<Map<String, dynamic>> _filterPtBrVoices(List<dynamic>? rawList) {
    if (rawList == null) {
      return const <Map<String, dynamic>>[];
    }
    final List<Map<String, dynamic>> ptBr = <Map<String, dynamic>>[];
    for (final dynamic item in rawList) {
      if (item is Map) {
        final String name = (item['name'] ?? '').toString().trim();
        final String locale = (item['locale'] ?? '').toString();
        final String normalizedLocale = locale
            .replaceAll('_', '-')
            .toLowerCase();
        final String loweredName = name.toLowerCase();
        final bool matchesLocale =
            normalizedLocale == 'pt-br' ||
            normalizedLocale.startsWith('pt-br-');
        final bool matchesName =
            loweredName.contains('portuguese (brazil)') ||
            (loweredName.contains('portuguese') &&
                loweredName.contains('brazil'));
        if (name.isEmpty || (!matchesLocale && !matchesName)) {
          continue;
        }
        final Map<String, dynamic> voiceMap = <String, dynamic>{
          'name': name,
          'locale': locale.isEmpty ? 'pt-BR' : locale,
        };
        final dynamic identifier = item['voiceIdentifier'];
        if (identifier != null && identifier.toString().isNotEmpty) {
          voiceMap['voiceIdentifier'] = identifier.toString();
        }
        ptBr.add(voiceMap);
      }
    }
    ptBr.sort(
      (a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo(
        (b['name'] ?? '').toString().toLowerCase(),
      ),
    );
    return ptBr;
  }

  Future<void> speak(
    String text, {
    bool interrupt = true,
    String category = 'avisos',
  }) async {
    if (interrupt) {
      await speakPriority(text, category: category);
    } else {
      await speakQueue(<String>[text], category: category);
    }
  }

  Future<void> speakQueue(
    List<String> texts, {
    String category = 'avisos',
  }) async {
    await init();
    final String normalizedCategory = _normalizeCategory(category);
    if (!_isCategoryAllowed(normalizedCategory)) {
      return;
    }
    final List<String> sanitized = texts
        .map(_sanitizeText)
        .where((value) => value.isNotEmpty)
        .toList();
    if (sanitized.isEmpty) {
      return;
    }
    final DateTime now = DateTime.now();
    _debounceCache.removeWhere(
      (key, timestamp) => now.difference(timestamp) > _debounceWindow,
    );
    final List<_TtsQueueEntry> newEntries = <_TtsQueueEntry>[];
    for (final text in sanitized) {
      final DateTime? lastTime = _debounceCache[text];
      if (lastTime != null && now.difference(lastTime) < _debounceWindow) {
        continue;
      }
      _debounceCache[text] = now;
      newEntries.add(_TtsQueueEntry(text, normalizedCategory));
    }
    if (newEntries.isEmpty) {
      return;
    }
    _queue.addAll(newEntries);
    unawaited(_processQueue());
  }

  Future<void> speakPriority(String text, {String category = 'avisos'}) async {
    await init();
    final String normalizedCategory = _normalizeCategory(category);
    if (!_isCategoryAllowed(normalizedCategory)) {
      return;
    }
    final String sanitized = _sanitizeText(text);
    if (sanitized.isEmpty) {
      return;
    }
    await stop();
    _queue.clear();
    _queue.add(_TtsQueueEntry(sanitized, normalizedCategory));
    unawaited(_processQueue());
  }

  Future<void> speakSafe(String key, String text, {bool? interrupt}) async {
    final String normalized = _normalizeCategory(key);
    final bool shouldInterrupt = interrupt ?? normalized != 'pontuacao';
    await speak(text, interrupt: shouldInterrupt, category: normalized);
  }

  Future<void> stop() async {
    _queue.clear();
    _processingQueue = false;
    _isSpeaking = false;
    _speechCompleter?.complete();
    _speechCompleter = null;
    if (!_initialized) return;
    try {
      await _tts.stop();
    } catch (_) {
      // Algumas plataformas podem lançar exceções ao interromper.
    }
  }

  void _updatePromptState() {
    final bool needs = _requiresGesture && !_audioUnlocked && _enabled;
    if (_needsGestureNotifier.value != needs) {
      _needsGestureNotifier.value = needs;
    }
  }

  bool _isCategoryAllowed(String category) {
    if (!_enabled) return false;
    switch (category) {
      case 'tutorial':
        return _readTutorials;
      case 'pontuacao':
        return _readScores;
      case 'avisos':
      default:
        return _readWarnings;
    }
  }

  String _normalizeCategory(String input) {
    final String normalized = input.trim().toLowerCase();
    if (normalized.isEmpty) return 'avisos';
    if (normalized == 'tutorial' || normalized.contains('tutorial')) {
      return 'tutorial';
    }
    if (normalized == 'pontuacao' ||
        normalized.contains('pontua') ||
        normalized.contains('score')) {
      return 'pontuacao';
    }
    if (normalized == 'avisos' || normalized.contains('aviso')) {
      return 'avisos';
    }
    return 'avisos';
  }

  String _sanitizeText(String input) {
    if (input.trim().isEmpty) return '';
    String sanitized = input.replaceAll(_emojiRegex, ' ');
    sanitized = sanitized.replaceAll('…', '...');
    sanitized = sanitized.replaceAll(RegExp(r'\.{4,}'), '...');
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ').trim();
    return sanitized;
  }

  String sanitize(String input) {
    return _sanitizeText(input);
  }

  void _refreshUiNarrationFlag() {
    final bool combined = _enabled && _readUi;
    if (_uiNarrationEnabledNotifier.value != combined) {
      _uiNarrationEnabledNotifier.value = combined;
    }
  }

  void _handleTtsCompletion() {
    _isSpeaking = false;
    if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
      _speechCompleter!.complete();
    }
  }

  Future<void> _processQueue() async {
    if (_processingQueue) return;
    _processingQueue = true;
    while (_queue.isNotEmpty) {
      if (!_enabled) {
        _queue.clear();
        break;
      }
      final _TtsQueueEntry entry = _queue.removeAt(0);
      if (!_isCategoryAllowed(entry.category)) {
        continue;
      }
      if (_requiresGesture && !_audioUnlocked) {
        _queue.insert(0, entry);
        _processingQueue = false;
        _updatePromptState();
        return;
      }
      if (entry.text.isEmpty) {
        continue;
      }
      try {
        _isSpeaking = true;
        _speechCompleter = Completer<void>();
        await _tts.speak(entry.text);
        if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
          await _speechCompleter!.future;
        }
      } on PlatformException catch (error) {
        if (kDebugMode) {
          debugPrint('TTS falhou: ${error.message ?? error.code}');
        }
      } catch (error) {
        if (kDebugMode) {
          debugPrint('TTS falhou: $error');
        }
      } finally {
        _speechCompleter = null;
        _isSpeaking = false;
      }
    }
    _processingQueue = false;
  }

  Future<void> _applyDefaultVoiceIfNeeded() async {
    if (_availableVoices.isEmpty) {
      return;
    }
    final TtsVoiceOption? francisca = _findVoiceByNameContains('francisca');
    final bool storedIsThalita = (_voiceName ?? '').toLowerCase().contains(
      'thalita',
    );
    TtsVoiceOption? candidate = _voiceForName(_voiceName);
    if (storedIsThalita && francisca != null) {
      candidate = francisca;
    }
    candidate ??= francisca;
    candidate ??= _findVoiceByNameContains('maria');
    candidate ??= _availableVoices.first;
    if (candidate == null) {
      return;
    }
    if (_voiceName != candidate.name) {
      _voiceName = candidate.name;
      await UserPrefs.instance.setTtsVoiceName(candidate.name);
    }
    await _setVoice(candidate);
  }

  TtsVoiceOption? _voiceForName(String? name) {
    if (name == null || _availableVoices.isEmpty) {
      return null;
    }
    for (final voice in _availableVoices) {
      if (voice.name == name) {
        return voice;
      }
    }
    return null;
  }

  TtsVoiceOption? _findVoiceByNameContains(String fragment) {
    final String needle = fragment.toLowerCase();
    for (final voice in _availableVoices) {
      if (voice.name.toLowerCase().contains(needle)) {
        return voice;
      }
    }
    return null;
  }

  Future<void> _setVoice(TtsVoiceOption voice) async {
    try {
      await _tts.setVoice(<String, String>{
        'name': voice.name,
        'locale': voice.locale,
      });
    } catch (_) {
      if (kDebugMode) {
        debugPrint('Não foi possível definir a voz ${voice.name}.');
      }
    }
  }
}
