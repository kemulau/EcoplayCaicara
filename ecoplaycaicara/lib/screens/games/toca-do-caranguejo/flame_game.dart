import 'dart:async' as async;
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:image/image.dart' as img;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flame/flame.dart';
import 'package:flame/text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flame_audio/flame_audio.dart';

import '../../../services/user_prefs.dart';

import 'scroll_intro.dart';

/// =====================================================================
///  MÁSCARA DE CORES DO BACKGROUND (detecção mar/areia + vizinhança)
/// =====================================================================
enum TileKind { water, sand, other }

class _MaskCacheEntry {
  _MaskCacheEntry(this.rgba, this.width, this.height);
  final Uint8List rgba;
  final int width;
  final int height;
}

class SpawnMask {
  final int imgW;
  final int imgH;
  final Uint8List rgba; // raw RGBA
  final Size worldSize;

  static final Map<String, _MaskCacheEntry> _webRgbaCache = {};

  SpawnMask._(this.imgW, this.imgH, this.rgba, this.worldSize);

  static Future<SpawnMask?> fromSprite(
    Sprite bg,
    Size worldSize, {
    required String assetPath,
  }) async {
    try {
      if (kIsWeb) {
        final normalized = assetPath.startsWith('assets/')
            ? assetPath
            : 'assets/$assetPath';

        final cached = _webRgbaCache[normalized];
        if (cached != null) {
          return SpawnMask._(
            cached.width,
            cached.height,
            cached.rgba,
            worldSize,
          );
        }

        final data = await rootBundle.load(normalized);
        final bytes = data.buffer.asUint8List();
        final decoded = img.decodeImage(bytes);
        if (decoded == null) {
          return null;
        }
        img.Image rgbaImage = decoded;
        if (decoded.numChannels != 4 || decoded.format != img.Format.uint8) {
          rgbaImage = decoded.convert(numChannels: 4, format: img.Format.uint8);
        }
        final rgba = Uint8List.fromList(
          rgbaImage.getBytes(order: img.ChannelOrder.rgba),
        );
        _webRgbaCache[normalized] = _MaskCacheEntry(
          rgba,
          rgbaImage.width,
          rgbaImage.height,
        );
        return SpawnMask._(rgbaImage.width, rgbaImage.height, rgba, worldSize);
      }

      final uiImage = bg.image;
      final byteData = await uiImage.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) {
        return null;
      }
      return SpawnMask._(
        uiImage.width,
        uiImage.height,
        byteData.buffer.asUint8List(),
        worldSize,
      );
    } catch (e, stack) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('⚠️ SpawnMask: falha ao ler pixels do background: $e');
        debugPrintStack(stackTrace: stack);
      }
      return null;
    }
  }

  (int xi, int yi) worldToImg(double x, double y) {
    final xi = ((x / worldSize.width) * imgW).clamp(0, imgW - 1).toInt();
    final yi = ((y / worldSize.height) * imgH).clamp(0, imgH - 1).toInt();
    return (xi, yi);
  }

  int _idx(int x, int y) => (y * imgW + x) * 4;

  TileKind _classifyRGB(int r, int g, int b) {
    // Água: azul destacado
    final bool isWater =
        b > 110 && b > g + 12 && b > r + 20 && (b > 0.9 * (r + g) || b > 140);

    // Areia (tolerante)
    final int warm = r - b;
    final bool sandA = r > 120 && g > 90 && b < 150 && r >= g && warm > 22;
    final bool sandB = r > 145 && g > 115 && b < 175 && (r + g) > (b + 140);
    final bool sandC =
        r > 160 && g > 130 && b < 190 && (r - g).abs() <= 40 && warm > 10;

    final bool isSand = sandA || sandB || sandC;

    if (isWater) return TileKind.water;
    if (isSand) return TileKind.sand;
    return TileKind.other;
  }

  TileKind classifyWorld(double x, double y) {
    final (xi, yi) = worldToImg(x, y);
    final p = _idx(xi, yi);
    final r = rgba[p];
    final g = rgba[p + 1];
    final b = rgba[p + 2];
    return _classifyRGB(r, g, b);
  }

  bool isNeighborhoodMostly(
    double x,
    double y, {
    required TileKind want,
    double radiusWorld = 12,
    int samples = 36,
    double minRatio = 0.72,
  }) {
    int ok = 0;
    for (int i = 0; i < samples; i++) {
      final t = (i / samples) * 2 * pi;
      final px = x + cos(t) * radiusWorld;
      final py = y + sin(t) * radiusWorld;
      final k = classifyWorld(px, py);
      if (k == want) ok++;
    }
    return ok / samples >= minRatio;
  }
}

/// =====================================================================
///  HELPERS
/// =====================================================================
class GuaraFlightComponent extends SpriteAnimationComponent {
  GuaraFlightComponent({
    required List<Sprite> frames,
    required Vector2 worldSize,
    required Random random,
  }) : _worldSize = worldSize.clone(),
       _random = random,
       super(priority: -6, anchor: Anchor.center) {
    animation = SpriteAnimation.spriteList(
      [frames[0], frames[1], frames[2], frames[1], frames[0]],
      stepTime: 0.14,
      loop: true,
    );
    _baseFrameSize = frames.first.srcSize.clone();
    _updateSizing();
    _resetPosition(initial: true);
  }

  final Random _random;
  Vector2 _worldSize;
  late Vector2 _baseFrameSize;
  double _speed = 0;
  double _amplitude = 0;
  double _baseY = 0;
  double _phase = 0;
  double _phaseSpeed = 2.0;
  double _margin = 0;
  bool _frozen = false;

  void freeze() {
    _frozen = true;
    playing = false;
  }

  void unfreeze() {
    _frozen = false;
    playing = true;
  }

  void updateWorldSize(Vector2 size) {
    _worldSize = size.clone();
    _updateSizing();
    _resetPosition();
  }

  void _updateSizing() {
    final targetHeight = (_worldSize.y * 0.18).clamp(60.0, 180.0);
    final scale = targetHeight / _baseFrameSize.y;
    size = Vector2(_baseFrameSize.x * scale, _baseFrameSize.y * scale);

    _margin = size.x * 0.6;
    _speed = (_worldSize.x + size.x * 2) / 18.0;
    _amplitude = (_worldSize.y * 0.025).clamp(6.0, 28.0);
    _phaseSpeed = 1.6 + _random.nextDouble() * 0.9;
  }

  void _resetPosition({bool initial = false}) {
    final minY = _worldSize.y * 0.12;
    final maxY = _worldSize.y * 0.22;
    _baseY = ui.lerpDouble(minY, maxY, _random.nextDouble()) ?? minY;
    _phase = _random.nextDouble() * pi * 2;

    final startX = initial
        ? -size.x
        : -_margin * (1.2 + _random.nextDouble() * 0.6);
    position = Vector2(startX, _baseY + sin(_phase) * _amplitude);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_frozen) return;

    position.x += _speed * dt;
    _phase += _phaseSpeed * dt;
    position.y = _baseY + sin(_phase) * _amplitude;

    if (position.x - size.x / 2 > _worldSize.x + _margin) {
      _resetPosition();
    }
  }
}

Rect rectFromComponent(PositionComponent c) {
  final w = c.size.x, h = c.size.y;
  final cx = c.position.x - w * (c.anchor.x - 0.5);
  final cy = c.position.y - h * (c.anchor.y - 0.5);
  return Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);
}

/// =====================================================================
///  RESÍDUOS
/// =====================================================================
class ResiduoComponent extends SpriteComponent {
  ResiduoComponent({
    required this.tipo,
    required this.zona,
    required Sprite sprite,
    required Vector2 start,
    this.onDispose,
  }) : super(
         sprite: sprite,
         position: Vector2(start.x.roundToDouble(), start.y.roundToDouble()),
         anchor: Anchor.center,
         priority: -1,
       ) {
    paint.filterQuality = FilterQuality.none;
  }

  final String tipo;
  final String zona;
  final VoidCallback? onDispose;

  bool reduceMotion = false;
  bool animating = false;
  async.Timer? _animTimer;

  void _setAnimatingFor(Duration d) {
    animating = true;
    _animTimer?.cancel();
    _animTimer = async.Timer(d, () => animating = false);
  }

  void applyReduceMotion(bool value) {
    if (reduceMotion == value) return;
    reduceMotion = value;

    if (reduceMotion) {
      _animTimer?.cancel();
      animating = false;
      for (final effect in children.whereType<Effect>().toList()) {
        effect.removeFromParent();
      }
      opacity = 1;
      scale.setValues(1, 1);
      angle = 0;
    }
  }

  @override
  void onRemove() {
    _animTimer?.cancel();
    onDispose?.call();
    super.onRemove();
  }

  void playVanishAndRemove() {
    if (reduceMotion) {
      if (isMounted) {
        removeFromParent();
      }
      return;
    }

    _setAnimatingFor(const Duration(milliseconds: 280));

    add(
      OpacityEffect.to(
        0,
        EffectController(duration: 0.24, curve: Curves.easeOut),
      ),
    );
    add(
      ScaleEffect.to(
        Vector2(1.12, 1.12),
        EffectController(duration: 0.24, curve: Curves.easeOut),
      ),
    );

    async.Future.delayed(const Duration(milliseconds: 260), () {
      if (isMounted) removeFromParent();
    });
  }
}

class ResiduoAreia extends ResiduoComponent {
  final double ttl;

  ResiduoAreia({
    required String tipo,
    required String zona,
    required Sprite sprite,
    required Vector2 start,
    double? ttlSeconds,
    VoidCallback? onDispose,
  }) : ttl = ttlSeconds ?? (4.2 + Random().nextDouble() * 1.6),
       super(
         tipo: tipo,
         zona: zona,
         sprite: sprite,
         start: start,
         onDispose: onDispose,
       );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    if (reduceMotion) {
      opacity = 1;
      scale.setValues(1, 1);
      // Em reduceMotion removemos sozinho após um tempo para não poluir a tela
      async.Timer(Duration(milliseconds: (ttl * 1000).round()), () {
        if (isMounted) removeFromParent();
      });
      return;
    }

    _setAnimatingFor(const Duration(milliseconds: 260));
    opacity = 0;
    scale.setValues(0.85, 0.85);

    add(
      OpacityEffect.to(
        1,
        EffectController(duration: 0.18, curve: Curves.easeOut),
      ),
    );
    add(
      ScaleEffect.to(
        Vector2.all(1),
        EffectController(duration: 0.22, curve: Curves.easeOutBack),
      ),
    );
  }
}

class ResiduoBoiando extends ResiduoComponent {
  final double ttl;

  ResiduoBoiando({
    required String tipo,
    required String zona,
    required Sprite sprite,
    required Vector2 start,
    double? ttlSeconds,
    VoidCallback? onDispose,
  }) : ttl = ttlSeconds ?? (3.6 + Random().nextDouble() * 2.2),
       super(
         tipo: tipo,
         zona: zona,
         sprite: sprite,
         start: start,
         onDispose: onDispose,
       );

  // Controle de vida
  DateTime? _spawnedAt;
  async.Timer? _lifeTimer;

  // Random consistente por instância
  final Random _rand = Random();
  double? _dxSign;
  double? _rotSign;

  // -- utilidades ---------------------------------------------------------

  void _scheduleEnd(double seconds) {
    _lifeTimer?.cancel();
    _lifeTimer = async.Timer(
      Duration(milliseconds: (seconds * 1000).round()),
      () {
        if (!isMounted) return;
        // Em reduceMotion, playVanishAndRemove remove direto; no normal faz fade
        playVanishAndRemove();
      },
    );
  }

  double _remainingSeconds() {
    if (_spawnedAt == null) return ttl;
    final elapsed =
        DateTime.now().difference(_spawnedAt!).inMilliseconds / 1000.0;
    final rem = ttl - elapsed;
    return rem.isFinite ? rem.clamp(0.1, ttl) : ttl;
  }

  void _killMotionEffects() {
    for (final e in children.whereType<Effect>().toList()) {
      if (e is MoveEffect || e is RotateEffect || e is SequenceEffect) {
        e.removeFromParent();
      }
    }
  }

  void _startNormalMotion({double? forSeconds}) {
    final dur = (forSeconds ?? ttl).clamp(0.1, ttl);
    _dxSign ??= _rand.nextBool() ? 1.0 : -1.0;
    _rotSign ??= _rand.nextBool() ? 1.0 : -1.0;

    final dx = (20 + _rand.nextInt(40)).toDouble() * _dxSign!;

    // Deriva horizontal durante o tempo restante
    add(
      MoveEffect.by(
        Vector2(dx, 0),
        EffectController(duration: dur, curve: Curves.linear),
      ),
    );

    // Boia verticalmente
    add(
      MoveEffect.by(
        Vector2(0, -3),
        EffectController(
          duration: 0.9,
          alternate: true,
          infinite: true,
          curve: Curves.easeInOut,
        ),
      ),
    );

    // Pequena rotação alternada
    add(
      RotateEffect.by(
        0.06 * _rotSign!,
        EffectController(
          duration: 1.8,
          alternate: true,
          infinite: true,
          curve: Curves.easeInOut,
        ),
      ),
    );
  }

  void _applyReducedStatic() {
    // Nada de movimento: só fica visível e aguarda o TTL
    opacity = 1;
    scale.setValues(1, 1);
  }

  // -- ciclo de vida ------------------------------------------------------

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _spawnedAt = DateTime.now();

    // estado inicial
    opacity = 1;
    scale.setValues(1, 1);

    if (reduceMotion) {
      // Acessibilidade: só aparece e some no TTL
      _applyReducedStatic();
      _scheduleEnd(ttl);
      return;
    }

    // Modo normal
    opacity = 0;
    _setAnimatingFor(const Duration(milliseconds: 260));

    add(
      OpacityEffect.to(
        1,
        EffectController(duration: 0.20, curve: Curves.easeOut),
      ),
    );

    _startNormalMotion(forSeconds: ttl);
    _scheduleEnd(ttl);
  }

  @override
  void onRemove() {
    _lifeTimer?.cancel();
    _lifeTimer = null;
    super.onRemove();
  }

  // Alternância da preferência de redução de movimento em tempo real
  @override
  void applyReduceMotion(bool value) {
    final was = reduceMotion;
    super.applyReduceMotion(value); // limpa efeitos e normaliza visuais

    if (!isMounted || was == value) return;

    // Sempre remova quaisquer movimentos em curso
    _killMotionEffects();

    final rem = _remainingSeconds();
    if (rem <= 0.11) return; // deixa o timer remover em instantes

    if (value) {
      // Entrou em redução: fica estático; timer já está agendado
      _applyReducedStatic();
      // Timer já cobre o tempo restante; não precisa reagendar
    } else {
      // Saiu da redução: retoma movimentos pelo tempo restante
      _startNormalMotion(forSeconds: rem);
      // Timer de vida continua o mesmo
    }
  }
}

/// =====================================================================
///  GAME
/// =====================================================================
class CrabGame extends FlameGame {
  CrabGame({required this.onGameOver, this.fontFamily = 'PressStart2P'}) {
    _resetSessionState();
  }

  // HUD
  final ValueNotifier<int> score = ValueNotifier<int>(0);
  final ValueNotifier<int> timeLeft = ValueNotifier<int>(60);
  final ValueNotifier<bool> sfxEnabled = ValueNotifier<bool>(true);
  final ValueNotifier<String?> actionMessage = ValueNotifier<String?>(null);
  final ValueNotifier<bool> defesoAtivo = ValueNotifier<bool>(false);
  final ValueNotifier<int> defesoSeconds = ValueNotifier<int>(0);
  final ValueNotifier<int> crabsCaptured = ValueNotifier<int>(0);
  final ValueNotifier<int> residuesCollected = ValueNotifier<int>(0);
  final ValueNotifier<Map<String, int>> residueCounts =
      ValueNotifier<Map<String, int>>(<String, int>{});

  final String fontFamily;
  final VoidCallback onGameOver;

  static const List<String> _sfxAssets = <String>[
    'audio/residuos-effect.wav',
    'audio/point-effect.wav',
    'audio/negative-point.mp3',
    'audio/+fimdejogo.mp3',
    'audio/-fimdejogo.mp3',
    'audio/page-flip-47177.mp3',
  ];

  static const List<String> _imageAssets = <String>[
    'games/toca-do-caranguejo/background.png',
    'games/toca-do-caranguejo/background-mobile.png',
    'games/toca-do-caranguejo/acertou.png',
    'games/toca-do-caranguejo/caranguejo.png',
    'games/toca-do-caranguejo/residuo-caixa.png',
    'games/toca-do-caranguejo/lata.png',
    'games/toca-do-caranguejo/pet-sob-areia.png',
    'games/toca-do-caranguejo/cordas.png',
    'games/toca-do-caranguejo/residuo-isopor-boiando.png',
    'games/toca-do-caranguejo/residuo-madeira-musgo.png',
    'games/toca-do-caranguejo/pergaminho-fechado-1.png',
    'games/toca-do-caranguejo/pergaminho-entreaberto-2.png',
    'games/toca-do-caranguejo/pergaminho-aberto-3.png',
    'games/toca-do-caranguejo/sacola-submersa.png',
    'games/toca-do-caranguejo/residuo-fralda-submersa.png',
    'games/toca-do-caranguejo/caixa-leite-cartonada.png',
    // Guará (carregaremos com fallback se o nome real tiver .png.png)
    'games/toca-do-caranguejo/guara-aberto-1.png',
    'games/toca-do-caranguejo/guara-entreaberto-2.png',
    'games/toca-do-caranguejo/guara-fechado-3.png',
  ];

  static const String _unlockAsset = 'audio/point-effect.wav';

  static async.Future<void>? _imagePreload;
  static async.Future<void>? _audioPreload;

  bool _audioUnlocked = !kIsWeb;
  async.Future<void>? _pendingAudioUnlock;
  async.Future<void>? _audioPreloadFuture;

  void _resetSessionState() {
    score.value = 0;
    timeLeft.value = 60;
    crabsCaptured.value = 0;
    residuesCollected.value = 0;
    residueCounts.value = <String, int>{};
  }

  // Componentes
  SpriteComponent? _background;
  Sprite? _okIcon;
  CrabComponent? _crab;
  CrabComponent? _crab2;
  PositionComponent? _world;
  GuaraFlightComponent? _guara;
  final List<ResiduoComponent> _residuos = <ResiduoComponent>[];

  // Spawner de resíduos
  async.Timer? _residuoTimer;
  int _residuoMax = 5;

  // Controle de duplicidade
  final Set<String> _activeResidTypes = <String>{};

  // Tocas
  final List<Offset> _burrows = <Offset>[];
  final Random _rand = Random();
  double _roiY0World = 0;
  double _roiY1World = 0;
  double _burrowMinYWorld = 0;
  final Set<int> _reservedBurrows = <int>{};

  // Máscara
  SpawnMask? _mask;
  List<Offset> get burrows => List.unmodifiable(_burrows);
  double get burrowMinYWorld => _burrowMinYWorld;
  double get roiY0World => _roiY0World;
  double get roiY1World => _roiY1World;

  Rect get crabRect {
    final c = _crab;
    if (c == null) return Rect.zero;
    return Rect.fromLTWH(
      c.position.x - c.size.x * c.anchor.x,
      c.position.y - c.size.y * c.anchor.y,
      c.size.x,
      c.size.y,
    );
  }

  void updateReduceMotion(bool value) {
    if (_reduceMotion == value) return;
    _reduceMotion = value;

    if (_reduceMotion) {
      _guara?.freeze();
    } else {
      _guara?.unfreeze();
    }

    if (_crab != null) {
      _crab!.applyReduceMotion(value);
      if (!value) _ensureMoving(_crab!);
    }
    if (_crab2 != null) {
      _crab2!.applyReduceMotion(value);
      if (!value) _ensureMoving(_crab2!);
    }
    for (final residue in _residuos) {
      residue.applyReduceMotion(value);
    }
  }

  // Timers/estado
  async.Timer? _countdownTimer;
  async.Timer? _messageTimer;
  async.Timer? _defesoCheckTimer;
  async.Timer? _defesoEndTimer;
  async.Timer? _defesoSecondsTimer;
  DateTime? _defesoEndsAt;

  bool _started = false;
  bool _reduceMotion = false;

  // pausa lógica
  bool _paused = false;
  bool get _acceptClicks => _started && timeLeft.value > 0 && !_paused;
  bool get _acceptSpawns => _started && timeLeft.value > 0 && !_paused;

  int _spawnCount = 0;
  bool _nextIsSmall = false;

  final Map<CrabComponent, int> _loopCounter = {};
  final Map<CrabComponent, int> _loopTarget = {};
  DateTime _defesoCooldownUntil = DateTime.fromMillisecondsSinceEpoch(0);
  bool _defesoUsed = false;

  @override
  Color backgroundColor() => Colors.transparent;

  // ======= LOAD =======
  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final storedAudioEnabled = await UserPrefs.getAudioEnabled();
    if (sfxEnabled.value != storedAudioEnabled) {
      sfxEnabled.value = storedAudioEnabled;
    }
    sfxEnabled.addListener(_onSfxPreferenceChanged);

    images.prefix = 'assets/';

    if (kIsWeb) {
      await preloadImages();
      _audioPreloadFuture = preloadAudio();
    } else {
      final preload = preloadAssets();
      _audioPreloadFuture = preload;
      await preload;
    }

    _world = PositionComponent(priority: 0)..size = size;
    add(_world!);

    final bool useMobileBg = size.x <= 720 || size.y > size.x;
    final bgPath = useMobileBg
        ? 'games/toca-do-caranguejo/background-mobile.png'
        : 'games/toca-do-caranguejo/background.png';

    final sprites = await Future.wait<Sprite>([
      Sprite.load(bgPath, images: images),
      Sprite.load('games/toca-do-caranguejo/acertou.png', images: images),
      Sprite.load('games/toca-do-caranguejo/caranguejo.png', images: images),
    ]);

    final backgroundSprite = sprites[0];
    _background = SpriteComponent(sprite: backgroundSprite, size: size)
      ..priority = -10
      ..position = Vector2.zero();
    add(_background!);

    _mask = await SpawnMask.fromSprite(
      backgroundSprite,
      Size(size.x, size.y),
      assetPath: 'assets/$bgPath',
    );

    _okIcon = sprites[1];

    Future<Sprite> _loadGuaraWithFallback(String p) async {
      // tenta .png, se falhar tenta .png.png (ou vice-versa)
      try {
        return await Sprite.load(p, images: images);
      } catch (_) {
        if (p.endsWith('.png.png')) {
          final alt = p.substring(0, p.length - 4);
          return Sprite.load(alt, images: images);
        } else {
          final alt = '$p.png';
          return Sprite.load(alt, images: images);
        }
      }
    }

    final guaraSprites = await Future.wait<Sprite>([
      _loadGuaraWithFallback('games/toca-do-caranguejo/guara-aberto-1.png'),
      _loadGuaraWithFallback(
        'games/toca-do-caranguejo/guara-entreaberto-2.png',
      ),
      _loadGuaraWithFallback('games/toca-do-caranguejo/guara-fechado-3.png'),
    ]);

    _generateBurrows();

    _guara = GuaraFlightComponent(
      frames: guaraSprites,
      worldSize: Vector2(size.x, size.y),
      random: _rand,
    );
    _world!.add(_guara!);

    final crabSprite = sprites[2];
    _crab = CrabComponent(sprite: crabSprite)..anchor = Anchor.center;
    _crab!.applyReduceMotion(_reduceMotion);
    _crab2 = CrabComponent(sprite: crabSprite)..anchor = Anchor.center;
    _crab2!.applyReduceMotion(_reduceMotion);

    _world!.addAll([_crab!, _crab2!]);

    await _placeCrabInto(_crab!, randomizeSize: true, forceSmall: false);
    await _placeCrabInto(_crab2!, randomizeSize: true, forceSmall: true);
  }

  // ======= START =======
  void startGame() {
    if (_started) return;

    _resetSessionState();

    _defesoUsed = defesoAtivo.value;
    _paused = false;
    _started = true;

    if (_reduceMotion) {
      _guara?.freeze();
    } else {
      _guara?.unfreeze();
    }

    if (defesoAtivo.value) {
      _showDefesoIntro();
    }

    final c1 = _crab;
    if (c1 != null) {
      if (c1.opacity < 0.99) c1.opacity = 1.0;
      _startWalkLoop(c1);
    }
    final c2 = _crab2;
    if (c2 != null) {
      if (c2.opacity < 0.99) c2.opacity = 1.0;
      _startWalkLoop(c2);
    }

    _countdownTimer = async.Timer.periodic(const Duration(seconds: 1), (_) {
      if (_paused) return;

      timeLeft.value = timeLeft.value - 1;
      if (timeLeft.value <= 0) {
        _countdownTimer?.cancel();
        _stopResiduoSpawnerAndClear();
        _stopAllAnimations();
        onGameOver();

        async.Future.delayed(
          const Duration(milliseconds: 120),
          _playEndGameSfx,
        );
      }
    });

    _startDefesoScheduler();
    _startResiduoSpawner();
  }

  /// ======= A11Y: pause/resume =======
  @override
  void pauseEngine() {
    super.pauseEngine();
    _pauseGameplay();
  }

  @override
  void resumeEngine() {
    _resumeGameplay();
    super.resumeEngine();
  }

  /// ======= Preloads =======
  static Future<void> preloadAssets() {
    final images = preloadImages();
    final audio = preloadAudio();
    return Future.wait([images, audio]).then((_) {});
  }

  static Future<void> preloadImages() {
    final existing = _imagePreload;
    if (existing != null) {
      return existing;
    }
    final future = _doPreloadImages();
    _imagePreload = future.catchError((Object error, StackTrace stack) {
      if (kDebugMode) {
        print('⚠️ Preload de imagens falhou: $error');
      }
      _imagePreload = null;
    });
    return _imagePreload!;
  }

  static Future<void> preloadAudio() {
    final existing = _audioPreload;
    if (existing != null) {
      return existing;
    }
    final future = _doPreloadAudio();
    _audioPreload = future.catchError((Object error, StackTrace stack) {
      if (kDebugMode) {
        print('⚠️ Preload de áudio falhou: $error');
      }
      _audioPreload = null;
    });
    return _audioPreload!;
  }

  static Future<void> _doPreloadImages() async {
    final previousPrefix = Flame.images.prefix;
    Flame.images.prefix = 'assets/';
    try {
      // carrega uma a uma, com fallback .png <-> .png.png quando necessário
      for (final p in _imageAssets) {
        try {
          await Flame.images.load(p);
        } catch (_) {
          if (p.endsWith('.png.png')) {
            final alt = p.substring(0, p.length - 4);
            try {
              await Flame.images.load(alt);
            } catch (__) {
              if (kDebugMode) {
                print('⚠️ não foi possível pré-carregar "$p" nem "$alt"');
              }
            }
          } else if (p.endsWith('.png')) {
            final alt = '$p.png';
            try {
              await Flame.images.load(alt);
            } catch (__) {
              if (kDebugMode) {
                print('⚠️ não foi possível pré-carregar "$p" nem "$alt"');
              }
            }
          } else {
            if (kDebugMode) {
              print('⚠️ não foi possível pré-carregar "$p"');
            }
          }
        }
      }
    } finally {
      if (previousPrefix == 'assets/' || previousPrefix.isEmpty) {
        Flame.images.prefix = 'assets/';
      } else {
        Flame.images.prefix = previousPrefix;
      }
    }
  }

  static Future<void> _doPreloadAudio() async {
    FlameAudio.updatePrefix('assets/');
    await FlameAudio.audioCache.loadAll(_sfxAssets);
  }

  async.Future<void> _waitForAudioPreload() {
    _audioPreloadFuture ??= preloadAudio();
    return _audioPreloadFuture!;
  }

  void _onSfxPreferenceChanged() {
    async.unawaited(UserPrefs.setAudioEnabled(sfxEnabled.value));
  }

  Future<void> ensureAudioUnlocked() async {
    if (_audioUnlocked) return;

    if (!kIsWeb) {
      _audioUnlocked = true;
      return;
    }

    if (_pendingAudioUnlock != null) {
      await _pendingAudioUnlock;
      return;
    }

    final unlockFuture = _unlockAudioInternal();
    _pendingAudioUnlock = unlockFuture;
    try {
      await unlockFuture;
    } finally {
      _pendingAudioUnlock = null;
    }
  }

  Future<void> _unlockAudioInternal() async {
    await _waitForAudioPreload();
    AudioPlayer? player;
    try {
      player = await FlameAudio.play(_unlockAsset, volume: 0);
      _audioUnlocked = true;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Falha ao desbloquear áudio no web: $e');
      }
    } finally {
      if (player != null) {
        try {
          await player.stop();
        } catch (_) {}
        await player.dispose();
      }
    }
  }

  // ======= ÁUDIO =======
  Future<void> _sfx(String asset, {double volume = 1.0}) async {
    if (!sfxEnabled.value) return;
    try {
      await ensureAudioUnlocked();
      await FlameAudio.play(asset, volume: volume);
    } catch (e) {
      if (kDebugMode) print('⚠️ Áudio falhou: $asset — $e');
    }
  }

  void _playEndGameSfx() {
    if (score.value > 0) {
      _sfx('audio/+fimdejogo.mp3');
    } else {
      _sfx('audio/-fimdejogo.mp3');
    }
  }

  void _pauseGameplay() {
    _paused = true;
  }

  void _resumeGameplay() {
    _paused = false;
  }

  // ======= RESÍDUO: SPAWNER =======
  void _startResiduoSpawner() {
    _residuoTimer?.cancel();

    Future<void> safeSpawn() async {
      _residuos.removeWhere((r) => !r.isMounted);
      _activeResidTypes.retainWhere(
        (t) => _residuos.any((r) => r.isMounted && r.tipo == t),
      );

      if (_residuos.where((r) => r.isMounted).length >= _residuoMax) return;

      final bool zonaMar = _rand.nextDouble() < 0.60; // 60% mar
      final tiposMar = ['sacola', 'isopor', 'madeira', 'fralda'];
      final tiposAreia = ['papelao', 'lata', 'pet', 'cordas', 'caixa_leite'];
      final pool = zonaMar ? tiposMar : tiposAreia;

      final available = pool
          .where((t) => !_activeResidTypes.contains(t))
          .toList();
      if (available.isEmpty) return;

      final tipo = available[_rand.nextInt(available.length)];
      await spawnResiduo(tipo, zonaMar ? 'mar' : 'areia');
    }

    void scheduleNext() {
      final delayMs = 1600 + _rand.nextInt(1400); // 1.6–3.0s
      _residuoTimer = async.Timer(Duration(milliseconds: delayMs), () async {
        if (!_started || timeLeft.value <= 0) return;
        if (_paused) {
          scheduleNext();
          return;
        }
        try {
          await safeSpawn();
        } catch (e, st) {
          if (kDebugMode) print('⚠️ Erro ao spawnar resíduo: $e\n$st');
        }
        scheduleNext();
      });
    }

    scheduleNext();
  }

  void _stopResiduoSpawnerAndClear() {
    _residuoTimer?.cancel();
    for (final r in List<ResiduoComponent>.from(_residuos)) {
      if (r.isMounted) r.playVanishAndRemove();
    }
    _residuos.clear();
    _activeResidTypes.clear();
  }

  void _stopAllAnimations() {
    _paused = true;
    _started = false;
    for (final crab in <CrabComponent?>[_crab, _crab2]) {
      crab?.stopAllMotion();
    }
    _guara?.freeze();
  }

  // ======= BURROWS / LAYOUT =======
  void _generateBurrows() {
    _burrows.clear();

    final h = size.y;
    final w = size.x;

    _roiY0World = h * 0.70;
    _roiY1World = h * 0.89;

    final rows = [
      ui.lerpDouble(_roiY0World, _roiY1World, 0.40)!,
      ui.lerpDouble(_roiY0World, _roiY1World, 0.65)!,
      ui.lerpDouble(_roiY0World, _roiY1World, 0.88)!,
    ];
    final counts = [6, 5, 6];

    for (int r = 0; r < rows.length; r++) {
      final c = counts[r];
      final margin = w * 0.07;
      final usable = w - margin * 2;
      for (int i = 0; i < c; i++) {
        final x = margin + usable * (i + 0.5) / c;
        _burrows.add(Offset(x, rows[r]));
      }
    }

    if (_burrows.isNotEmpty) {
      _burrowMinYWorld = _burrows
          .map((o) => o.dy)
          .reduce((a, b) => a < b ? a : b);
    }
  }

  @override
  void onGameResize(Vector2 newSize) {
    super.onGameResize(newSize);

    final wroot = _world;
    if (wroot != null && wroot.isMounted) {
      wroot.size = newSize;
    }

    if (_background != null && _background!.isMounted) {
      _background!
        ..size = newSize
        ..position = Vector2.zero();
    }

    _guara?.updateWorldSize(newSize);

    _mask = _mask == null
        ? null
        : SpawnMask._(
            _mask!.imgW,
            _mask!.imgH,
            _mask!.rgba,
            Size(newSize.x, newSize.y),
          );

    _generateBurrows();

    final c1 = _crab;
    if (c1 != null) _resizeCrab(c1);
    final c2 = _crab2;
    if (c2 != null) _resizeCrab(c2);
  }

  // ======= DEFESO =======
  void _startDefesoScheduler() {
    _defesoCheckTimer?.cancel();
    if (_defesoUsed || defesoAtivo.value) {
      return;
    }
    _defesoCheckTimer = async.Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_started) return;
      if (_defesoUsed) return;
      if (timeLeft.value <= 16) return;
      if (defesoAtivo.value) return;
      if (DateTime.now().isBefore(_defesoCooldownUntil)) return;

      const double chance = 0.18;
      if (_rand.nextDouble() < chance) {
        _beginDefesoFor(const Duration(seconds: 15));
      }
    });
  }

  void _beginDefesoFor(Duration duration) {
    if (_defesoUsed && !defesoAtivo.value) {
      return;
    }

    _defesoUsed = true;
    _defesoCheckTimer?.cancel();

    setDefeso(true, showIntro: false);
    _showDefesoIntro();

    _defesoEndsAt = DateTime.now().add(duration);
    defesoSeconds.value = duration.inSeconds;

    _defesoSecondsTimer?.cancel();
    _defesoSecondsTimer = async.Timer.periodic(const Duration(seconds: 1), (_) {
      if (_defesoEndsAt == null) return;
      final left = _defesoEndsAt!.difference(DateTime.now()).inSeconds;
      defesoSeconds.value = left > 0 ? left : 0;
    });

    _defesoEndTimer?.cancel();
    _defesoEndTimer = async.Timer(duration, () async {
      _pauseGameplay();

      if (_reduceMotion) {
        showAction('Período de defeso encerrado!');
        _resumeGameplay();
        setDefeso(false, showIntro: false);
        _defesoCooldownUntil = DateTime.now().add(const Duration(seconds: 8));
        _defesoEndsAt = null;
        _defesoSecondsTimer?.cancel();
        defesoSeconds.value = 0;
        return;
      }

      final outro = ScrollIntro(
        position: Vector2(size.x / 2, size.y / 2),
        extraTextDelayMs: 0,
        displayMs: 900,
        dismissOnTap: true,
        animated: !_reduceMotion,
      );
      add(outro);

      // 🎵 som de pergaminho
      _sfx('audio/page-flip-47177.mp3', volume: 0.8);
      await outro.play();
      _sfx('audio/page-flip-47177.mp3', volume: 0.8);

      _resumeGameplay();
      setDefeso(false, showIntro: false);
      _defesoCooldownUntil = DateTime.now().add(const Duration(seconds: 8));
      _defesoEndsAt = null;
      _defesoSecondsTimer?.cancel();
      defesoSeconds.value = 0;
    });
  }

  void setDefeso(bool value, {bool showIntro = true}) {
    defesoAtivo.value = value;

    if (value) {
      _defesoUsed = true;
      _defesoCheckTimer?.cancel();
      if (showIntro) {
        _showDefesoIntro();
      }
    } else {
      _defesoEndsAt = null;
      _defesoSecondsTimer?.cancel();
      defesoSeconds.value = 0;
    }
  }

  Future<void> _showDefesoIntro() async {
    if (children.any((c) => c is ScrollIntro)) {
      return;
    }
    if (_reduceMotion) {
      showAction('Período de defeso ativo!');
      return;
    }

    _pauseGameplay();

    final scroll = ScrollIntro(
      position: Vector2(size.x / 2, size.y / 2),
      extraTextDelayMs: 400,
      displayMs: 1200,
      dismissOnTap: true,
      animated: !_reduceMotion,
    );
    add(scroll);

    // 🎵 som de “page flip”
    _sfx('audio/page-flip-47177.mp3', volume: 0.8);
    await scroll.play();
    _sfx('audio/page-flip-47177.mp3', volume: 0.8);

    _resumeGameplay();
  }

  // ======= SOBREPOSIÇÃO / COLISÃO =======
  bool _intersectsAnyAnimating(Rect candidate) {
    if (_crab != null && _crab!.animating) {
      if (rectFromComponent(_crab!).overlaps(candidate)) return true;
    }
    if (_crab2 != null && _crab2!.animating) {
      if (rectFromComponent(_crab2!).overlaps(candidate)) return true;
    }
    for (final r in _residuos) {
      if (!r.isMounted) continue;
      if (r.animating && rectFromComponent(r).overlaps(candidate)) return true;
    }
    return false;
  }

  bool _overlapsAnyResidue(Rect candidate, {double pad = 2}) {
    for (final r in _residuos) {
      if (!r.isMounted) continue;
      final rect = rectFromComponent(r).inflate(pad);
      if (rect.overlaps(candidate)) return true;
    }
    return false;
  }

  Future<bool> _waitAreaFree(
    Rect candidate, {
    int polls = 16,
    Duration interval = const Duration(milliseconds: 80),
  }) async {
    for (int i = 0; i < polls; i++) {
      if (!_intersectsAnyAnimating(candidate)) return true;
      await async.Future.delayed(interval);
    }
    return !_intersectsAnyAnimating(candidate);
  }

  // ======= CRABS =======
  Future<void> _placeCrabInto(
    CrabComponent crab, {
    required bool randomizeSize,
    bool? forceSmall,
    Offset? posOverride,
  }) async {
    if (_burrows.isEmpty) return;

    bool small;
    if (forceSmall != null) {
      small = forceSmall;
    } else {
      if (_spawnCount < 2) {
        small = false;
      } else {
        small = _nextIsSmall;
      }
      _nextIsSmall = !_nextIsSmall;
    }
    _spawnCount += 1;

    const double designW = 1280.0;
    const double stepDesignX = 128.0;
    final stepX = (size.x / designW) * stepDesignX;

    final bool isPortrait = size.y > size.x;
    final bool isNarrow = size.x <= 720;
    final double mobileMult = isPortrait ? 1.9 : (isNarrow ? 1.25 : 1.0);

    double width = stepX * (small ? 0.50 : 0.82) * mobileMult;
    final double maxWBig = (size.y * 0.100).clamp(32.0, 104.0).toDouble();
    final double maxWSmall = (size.y * 0.075).clamp(24.0, 84.0).toDouble();
    final double maxW = small ? maxWSmall : maxWBig;
    if (width > maxW) width = maxW;
    final height = width;

    Offset pos = posOverride ?? _burrows[_rand.nextInt(_burrows.length)];
    final halfH = height / 2;
    final safeY = pos.dy < (_burrowMinYWorld + halfH)
        ? (_burrowMinYWorld + halfH)
        : pos.dy;
    pos = Offset(pos.dx, safeY);

    final candRect = Rect.fromCenter(center: pos, width: width, height: height);
    final ok = await _waitAreaFree(candRect.inflate(2));
    if (!ok) {
      for (final p in _burrows..shuffle(_rand)) {
        final y = p.dy < (_burrowMinYWorld + halfH)
            ? (_burrowMinYWorld + halfH)
            : p.dy;
        final r = Rect.fromCenter(
          center: Offset(p.dx, y),
          width: width,
          height: height,
        );
        if (!_intersectsAnyAnimating(r.inflate(2))) {
          pos = Offset(p.dx, y);
          break;
        }
      }
    }

    crab
      ..size = Vector2(width, height)
      ..position = Vector2(pos.dx, pos.dy)
      ..isSmall = small;

    crab.applyReduceMotion(_reduceMotion);

    final roiSpan = (_roiY1World > _roiY0World)
        ? (_roiY1World - _roiY0World)
        : (size.y * 0.2);
    final depth = ((pos.dy - _roiY0World) / (roiSpan == 0 ? 1 : roiSpan)).clamp(
      0.0,
      1.0,
    );

    double dirSign;
    if (pos.dx < size.x * 0.35) {
      dirSign = 1.0;
    } else if (pos.dx > size.x * 0.65) {
      dirSign = -1.0;
    } else {
      dirSign = _rand.nextBool() ? 1.0 : -1.0;
    }

    final jitter = _rand.nextDouble();

    crab.playSpawnMotion(
      stepX: stepX,
      dirSign: dirSign,
      depth: depth,
      jitter: jitter,
    );

    crab.playSpawnAppearance(
      microDelay: _reduceMotion ? 0.01 : (0.02 + 0.03 * jitter),
    );
  }

  int _claimBurrowIndexAvoiding({
    required List<Offset> avoid,
    double minDistFraction = 0.18,
  }) {
    if (_burrows.isEmpty) return 0;

    final List<int> candidates = List<int>.generate(_burrows.length, (i) => i)
      ..shuffle(_rand);
    final double minDist = size.x * minDistFraction;

    bool okIndex(int idx) {
      if (_reservedBurrows.contains(idx)) return false;
      final c = _burrows[idx];
      for (final a in avoid) {
        if ((c - a).distance <= minDist) return false;
      }
      return true;
    }

    for (final i in candidates) {
      if (okIndex(i)) {
        _reservedBurrows.add(i);
        return i;
      }
    }

    for (final i in candidates) {
      if (!_reservedBurrows.contains(i)) {
        _reservedBurrows.add(i);
        return i;
      }
    }

    _reservedBurrows.add(0);
    return 0;
  }

  void _resizeCrab(CrabComponent crab) {
    const double designW = 1280.0;
    const double stepDesignX = 128.0;
    final stepX = (size.x / designW) * stepDesignX;

    final bool isPortrait = size.y > size.x;
    final bool isNarrow = size.x <= 720;
    final double mobileMult = isPortrait ? 1.9 : (isNarrow ? 1.25 : 1.0);

    double width = stepX * (crab.isSmall ? 0.50 : 0.82) * mobileMult;
    final double maxWBig = (size.y * 0.100).clamp(32.0, 104.0).toDouble();
    final double maxWSmall = (size.y * 0.075).clamp(24.0, 84.0).toDouble();
    final double maxW = crab.isSmall ? maxWSmall : maxWBig;
    if (width > maxW) width = maxW;
    final height = width;

    crab.size = Vector2(width, height);

    final roiSpan = (_roiY1World > _roiY0World)
        ? (_roiY1World - _roiY0World)
        : (size.y * 0.2);
    final yMin = (_roiY0World > 0) ? (_roiY0World + height / 2) : height / 2;
    final yMax = (_roiY1World > 0)
        ? (_roiY1World - height / 2)
        : (yMin + roiSpan - height);
    final clampedY = crab.position.y.clamp(yMin, yMax);
    final clampedX = crab.position.x.clamp(width / 2, size.x - width / 2);
    crab.position = Vector2(clampedX.toDouble(), clampedY.toDouble());
  }

  // ======= INPUT =======
  void handleTap(Offset position) {
    async.unawaited(ensureAudioUnlocked());
    if (!_acceptClicks) return;

    for (final r in List<ResiduoComponent>.from(_residuos)) {
      if (!r.isMounted || r.animating) continue;

      final rect = Rect.fromLTWH(
        r.position.x - r.size.x * r.anchor.x,
        r.position.y - r.size.y * r.anchor.y,
        r.size.x,
        r.size.y,
      );
      if (rect.contains(position)) {
        _coletarResiduo(r);
        return;
      }
    }

    if (_crab2 != null && !_crab2!.animating) {
      final r2 = Rect.fromLTWH(
        _crab2!.position.x - _crab2!.size.x * _crab2!.anchor.x,
        _crab2!.position.y - _crab2!.size.y * _crab2!.anchor.y,
        _crab2!.size.x,
        _crab2!.size.y,
      );
      if (r2.contains(position)) {
        _onCrabTapped(_crab2!);
        return;
      }
    }

    final c = _crab;
    if (c != null && !c.animating) {
      final r1 = crabRect;
      if (r1.contains(position)) {
        _onCrabTapped(c);
      }
    }
  }

  // ======= RESÍDUOS: ASSETS & TUNING =======
  String? _assetForResiduo(String tipo, String zona) {
    const base = 'games/toca-do-caranguejo/';

    const mapAreia = <String, String>{
      'papelao': 'residuo-caixa.png',
      'lata': 'lata.png',
      'pet': 'pet-sob-areia.png',
      'cordas': 'cordas.png',
      'caixa_leite': 'caixa-leite-cartonada.png',
    };

    const mapMar = <String, String>{
      'isopor': 'residuo-isopor-boiando.png',
      'madeira': 'residuo-madeira-musgo.png',
      'sacola': 'sacola-submersa.png',
      'fralda': 'residuo-fralda-submersa.png',
    };

    final p = zona == 'mar' ? mapMar[tipo] : mapAreia[tipo];
    return p == null ? null : base + p;
  }

  List<String> _altCandidates(String tipo, String zona) {
    const base = 'games/toca-do-caranguejo/';
    final List<String> c = [];
    if (zona == 'areia') {
      if (tipo == 'papelao') {
        c.addAll(['residuo-caixa.png', 'caixa.png', 'papelao.png']);
      }
      if (tipo == 'lata') {
        c.addAll(['lata.png', 'residuo-lata.png', 'lata-areia.png']);
      }
      if (tipo == 'pet') {
        c.addAll(['pet-sob-areia.png', 'pet.png', 'garrafa-pet.png']);
      }
      if (tipo == 'cordas') {
        c.addAll(['cordas.png', 'residuo-cordas.png']);
      }
      if (tipo == 'caixa_leite') {
        c.addAll([
          'caixa-leite-cartonada.png',
          'caixa-leite.png',
          'residuo-caixa.png',
        ]);
      }
    } else {
      if (tipo == 'sacola') {
        c.addAll(['sacola-submersa.png', 'sacola.png', 'sacola-boiando.png']);
      }
      if (tipo == 'isopor') {
        c.addAll(['residuo-isopor-boiando.png', 'isopor.png']);
      }
      if (tipo == 'madeira') {
        c.addAll(['residuo-madeira-musgo.png', 'madeira.png', 'tronco.png']);
      }
      if (tipo == 'fralda') {
        c.addAll(['residuo-fralda-submersa.png', 'fralda.png']);
      }
    }
    return c.map((f) => base + f).toList();
  }

  Future<Sprite?> _tryLoadSprite(String path) async {
    try {
      return await Sprite.load(path, images: images);
    } catch (_) {
      return null;
    }
  }

  Future<Sprite?> _loadResiduoSprite(String tipo, String zona) async {
    final primary = _assetForResiduo(tipo, zona);
    if (primary != null) {
      final s = await _tryLoadSprite(primary);
      if (s != null) return s;
    }
    for (final alt in _altCandidates(tipo, zona)) {
      final s = await _tryLoadSprite(alt);
      if (s != null) return s;
    }
    if (kDebugMode) print('❌ Nenhum asset encontrado para $tipo/$zona');
    return null;
  }

  String _normalizeZona(String tipo, String zona) {
    if (zona == 'mar' && (tipo == 'papelao' || tipo == 'caixa_leite')) {
      return 'areia';
    }
    return zona;
  }

  // rótulo para mostrar junto do +20
  String _labelResiduo(String tipo) {
    switch (tipo) {
      case 'papelao':
        return 'Papelão\nPAPEL';
      case 'lata':
        return 'Lata\nMETAL';
      case 'pet':
        return 'Garrafa PET\nPLÁSTICO';
      case 'cordas':
        return 'Cordas\nFIBRA';
      case 'sacola':
        return 'Sacola\nPLÁSTICO';
      case 'isopor':
        return 'Isopor\nPLÁSTICO';
      case 'madeira':
        return 'Madeira\nORGÂNICO';
      case 'fralda':
        return 'Fralda\nPLÁSTICO/CELULOSE';
      case 'caixa_leite':
        return 'Caixa de leite\nPAPEL/ALUMÍNIO';
      default:
        return tipo;
    }
  }

  String _residueNameShort(String tipo) {
    final label = _labelResiduo(tipo);
    final int br = label.indexOf('\n');
    return br >= 0 ? label.substring(0, br) : label;
  }

  // ========= tamanhos proporcionais ao caranguejo =========
  double _refCrabWidth() {
    final w1 = _crab?.size.x ?? 0;
    final w2 = _crab2?.size.x ?? 0;
    double ref = max(w1, w2);
    if (ref <= 0) ref = size.y * 0.09; // fallback
    return ref;
  }

  ({double ratio, double jitter, double minMul, double maxMul})
  _residueTuningByCrab(String tipo, String zona) {
    switch (zona) {
      case 'areia':
        switch (tipo) {
          case 'lata':
            return (ratio: 0.45, jitter: 0.06, minMul: 0.36, maxMul: 0.70);
          case 'pet':
            return (ratio: 0.68, jitter: 0.08, minMul: 0.50, maxMul: 0.95);
          case 'papelao':
            return (ratio: 0.80, jitter: 0.08, minMul: 0.60, maxMul: 1.05);
          case 'cordas':
            return (ratio: 0.72, jitter: 0.08, minMul: 0.52, maxMul: 0.98);
          case 'caixa_leite':
            return (ratio: 0.82, jitter: 0.07, minMul: 0.60, maxMul: 1.05);
          default:
            return (ratio: 0.70, jitter: 0.08, minMul: 0.50, maxMul: 1.00);
        }
      case 'mar':
        switch (tipo) {
          case 'sacola':
            return (ratio: 0.70, jitter: 0.08, minMul: 0.50, maxMul: 0.98);
          case 'isopor':
            return (ratio: 0.82, jitter: 0.08, minMul: 0.60, maxMul: 1.08);
          case 'madeira':
            return (ratio: 0.78, jitter: 0.08, minMul: 0.58, maxMul: 1.02);
          case 'fralda':
            return (ratio: 0.60, jitter: 0.08, minMul: 0.45, maxMul: 0.88);
          default:
            return (ratio: 0.72, jitter: 0.08, minMul: 0.50, maxMul: 1.00);
        }
      default:
        return (ratio: 0.70, jitter: 0.08, minMul: 0.50, maxMul: 1.00);
    }
  }

  double _computeResidueHeightFromCrab(String tipo, String zona) {
    final ref = _refCrabWidth();
    final t = _residueTuningByCrab(tipo, zona);

    double h = ref * t.ratio;
    final double jitter = (1 + ((_rand.nextDouble() * 2) - 1) * t.jitter);
    h *= jitter;

    final bool portrait = size.y > size.x;
    final double cap = size.y * (portrait ? 0.20 : 0.16);

    final double minH = ref * t.minMul;
    final double maxH = min(ref * t.maxMul, cap);

    return h.clamp(minH, maxH).toDouble();
  }

  // --------- Checagens “de pegada” ----------
  ({int sand, int water, int other, int total}) _gridCountsFootprint(
    double x,
    double y,
    double w,
    double h,
    SpawnMask mask, {
    int gx = 5,
    int gy = 3,
    double shrinkFrac = 0.22,
  }) {
    final halfW = w * 0.5 * (1.0 - shrinkFrac);
    final halfH = h * 0.5 * (1.0 - shrinkFrac);

    int sand = 0, water = 0, other = 0;
    int total = 0;

    for (int iy = 0; iy < gy; iy++) {
      final ty = gy == 1 ? 0.5 : iy / (gy - 1);
      final py = ui.lerpDouble(y - halfH, y + halfH, ty)!;

      for (int ix = 0; ix < gx; ix++) {
        final tx = gx == 1 ? 0.5 : ix / (gx - 1);
        final px = ui.lerpDouble(x - halfW, x + halfW, tx)!;

        final k = mask.classifyWorld(px, py);
        if (k == TileKind.sand) {
          sand++;
        } else if (k == TileKind.water) {
          water++;
        } else {
          other++;
        }
        total++;
      }
    }
    return (sand: sand, water: water, other: other, total: total);
  }

  bool _isStronglySandAt(
    double x,
    double y,
    double w,
    double h,
    SpawnMask mask,
  ) {
    final g = _gridCountsFootprint(x, y, w, h, mask, shrinkFrac: 0.24);
    final ratio = g.sand / g.total;
    if (!(ratio >= 0.74 && g.water <= 1)) return false;

    final r = max(12.0, h * 0.6);
    if (!mask.isNeighborhoodMostly(
      x,
      y,
      want: TileKind.sand,
      radiusWorld: r,
      samples: 36,
      minRatio: 0.70,
    ))
      return false;

    for (int i = 1; i <= 3; i++) {
      final yy = y - h * 0.20 * i;
      if (mask.classifyWorld(x, yy) == TileKind.water) return false;
    }
    return true;
  }

  bool _isMediumSandAt(double x, double y, double w, double h, SpawnMask mask) {
    if (mask.classifyWorld(x, y) == TileKind.water) return false;

    final g = _gridCountsFootprint(x, y, w, h, mask, shrinkFrac: 0.26);
    final ratio = g.sand / g.total;
    if (!(ratio >= 0.58 && g.water <= 1)) return false;

    final r = max(10.0, h * 0.48);
    if (!mask.isNeighborhoodMostly(
      x,
      y,
      want: TileKind.sand,
      radiusWorld: r,
      samples: 32,
      minRatio: 0.60,
    ))
      return false;

    for (int i = 1; i <= 2; i++) {
      final yy = y + h * 0.18 * i;
      if (mask.classifyWorld(x, yy) == TileKind.water) return false;
    }
    return true;
  }

  bool _isStronglyWaterAt(
    double x,
    double y,
    double w,
    double h,
    SpawnMask mask,
  ) {
    final g = _gridCountsFootprint(x, y, w, h, mask, shrinkFrac: 0.20);
    final ratio = g.water / g.total;
    if (!(ratio >= 0.75 && g.sand == 0)) return false;

    final r = max(14.0, h * 0.7);
    if (!mask.isNeighborhoodMostly(
      x,
      y,
      want: TileKind.water,
      radiusWorld: r,
      samples: 42,
      minRatio: 0.78,
    ))
      return false;

    for (int i = 1; i <= 3; i++) {
      final yy = y + h * 0.20 * i;
      if (mask.classifyWorld(x, yy) == TileKind.sand) return false;
    }
    return true;
  }

  /// Polígono das raízes do mangue — área proibida
  List<Offset> _rootsPolygonWorld() {
    final w = size.x, h = size.y;
    return [
      Offset(0.00 * w, 0.30 * h),
      Offset(0.28 * w, 0.30 * h),
      Offset(0.38 * w, 0.64 * h),
      Offset(0.22 * w, 0.86 * h),
      Offset(0.00 * w, 0.86 * h),
    ];
  }

  bool _pointInPolygon(Offset p, List<Offset> poly) {
    bool c = false;
    for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final yi = poly[i].dy, yj = poly[j].dy;
      final xi = poly[i].dx, xj = poly[j].dx;
      final intersect =
          ((yi > p.dy) != (yj > p.dy)) &&
          (p.dx <
              (xj - xi) * (p.dy - yi) / ((yj - yi) == 0 ? 1e-6 : (yj - yi)) +
                  xi);
      if (intersect) c = !c;
    }
    return c;
  }

  ({double xMin, double xMax, double yMin, double yMax}) _spawnRegionGuess(
    String zona,
  ) {
    final bool portrait = size.y > size.x;

    if (zona == 'mar') {
      final xMin = size.x * (portrait ? 0.52 : 0.36);
      final xMax = size.x * 0.98;
      final yMin = size.y * (portrait ? 0.56 : 0.54);
      final yMax = size.y * (portrait ? 0.68 : 0.66);
      return (xMin: xMin, xMax: xMax, yMin: yMin, yMax: yMax);
    } else {
      final roiTop = _roiY0World;
      final roiBottom = _roiY1World > _roiY0World
          ? _roiY1World
          : (_roiY0World + size.y * 0.18);
      final span = (roiBottom - roiTop).clamp(1.0, size.y);

      final xMin = size.x * (portrait ? 0.30 : 0.18);
      final xMax = size.x * (portrait ? 0.92 : 0.78);
      final yMin = (roiTop + span * (portrait ? 0.08 : 0.10));
      final yMax = (roiBottom - span * (portrait ? 0.10 : 0.12));
      final y0 = min(yMin, yMax);
      final y1 = max(yMin, yMax);
      return (xMin: xMin, xMax: xMax, yMin: y0, yMax: y1);
    }
  }

  bool _tooCloseToBurrows(Offset p, double radiusWorld) {
    for (final b in _burrows) {
      if ((b - p).distance <= radiusWorld) return true;
    }
    return false;
  }

  Offset? _pickSafeSpawn(String zona, double targetW, double targetH) {
    final mask = _mask;
    final region = _spawnRegionGuess(zona);
    final rootsPoly = _rootsPolygonWorld();

    final double baseAvoid = size.x * 0.05;
    final double avoidNearBurrows = zona == 'areia'
        ? max(baseAvoid * 0.7, targetH * 0.60)
        : max(baseAvoid, targetH * 1.00);

    bool rejectCommon(Offset p) {
      if (_pointInPolygon(p, rootsPoly)) return true;
      if (_tooCloseToBurrows(p, avoidNearBurrows)) return true;
      final cand = Rect.fromCenter(center: p, width: targetW, height: targetH);
      if (_intersectsAnyAnimating(cand.inflate(2))) return true;
      if (_overlapsAnyResidue(cand.inflate(2))) return true;
      return false;
    }

    if (mask != null) {
      final triesStrong = zona == 'areia' ? 160 : 100;
      for (int i = 0; i < triesStrong; i++) {
        final x = ui.lerpDouble(region.xMin, region.xMax, _rand.nextDouble())!;
        final y = ui.lerpDouble(region.yMin, region.yMax, _rand.nextDouble())!;
        final p = Offset(x, y);
        if (rejectCommon(p)) continue;

        final ok = (zona == 'mar')
            ? _isStronglyWaterAt(x, y, targetW, targetH, mask)
            : _isStronglySandAt(x, y, targetW, targetH, mask);
        if (ok) return p;
      }

      if (zona == 'areia') {
        for (int i = 0; i < 200; i++) {
          final x = ui.lerpDouble(
            region.xMin,
            region.xMax,
            _rand.nextDouble(),
          )!;
          final y = ui.lerpDouble(
            region.yMin,
            region.yMax,
            _rand.nextDouble(),
          )!;
          final p = Offset(x, y);
          if (rejectCommon(p)) continue;
          if (_isMediumSandAt(x, y, targetW, targetH, mask)) return p;
        }
      }

      if (zona == 'areia') {
        for (int i = 0; i < 220; i++) {
          final x = ui.lerpDouble(
            region.xMin,
            region.xMax,
            _rand.nextDouble(),
          )!;
          final y = ui.lerpDouble(
            region.yMin,
            region.yMax,
            _rand.nextDouble(),
          )!;
          final p = Offset(x, y);
          if (rejectCommon(p)) continue;
          if (mask.classifyWorld(x, y) != TileKind.water) return p;
        }
      }
    } else {
      if (zona == 'areia') {
        for (int i = 0; i < 160; i++) {
          final x = ui.lerpDouble(
            region.xMin,
            region.xMax,
            _rand.nextDouble(),
          )!;
          final y = ui.lerpDouble(
            max(region.yMin, _roiY0World * 1.00),
            region.yMax,
            _rand.nextDouble(),
          )!;
          final p = Offset(x, y);
          if (rejectCommon(p)) continue;
          return p;
        }
      } else {
        for (int i = 0; i < 120; i++) {
          final x = ui.lerpDouble(
            region.xMin,
            region.xMax,
            _rand.nextDouble(),
          )!;
          final y = ui.lerpDouble(
            region.yMin,
            region.yMax,
            _rand.nextDouble(),
          )!;
          final p = Offset(x, y);
          if (rejectCommon(p)) continue;
          return p;
        }
      }
    }

    if (zona == 'areia') {
      final double relaxedAvoid = max(baseAvoid * 0.5, targetH * 0.40);
      for (int i = 0; i < 240; i++) {
        final x = ui.lerpDouble(region.xMin, region.xMax, _rand.nextDouble())!;
        final y = ui.lerpDouble(region.yMin, region.yMax, _rand.nextDouble())!;
        final p = Offset(x, y);
        if (_pointInPolygon(p, rootsPoly)) continue;
        if (_tooCloseToBurrows(p, relaxedAvoid)) continue;

        final cand = Rect.fromCenter(
          center: p,
          width: targetW,
          height: targetH,
        );
        if (_intersectsAnyAnimating(cand.inflate(2))) continue;
        if (_overlapsAnyResidue(cand.inflate(2))) continue;
        if (mask != null && mask.classifyWorld(x, y) == TileKind.water)
          continue;
        return p;
      }
    }

    return null;
  }

  // ======= SPAWN RESÍDUO =======
  Future<void> spawnResiduo(String tipo, String zona) async {
    if (!_acceptSpawns) return;
    if (_activeResidTypes.contains(tipo)) return;

    final nz = _normalizeZona(tipo, zona);
    final spr = await _loadResiduoSprite(tipo, nz);
    if (spr == null) return;

    final double targetH = _computeResidueHeightFromCrab(tipo, nz);
    final aspect = spr.srcSize.x / spr.srcSize.y;
    final double targetW = targetH * aspect;

    final pos = _pickSafeSpawn(nz, targetW, targetH);
    if (pos == null) return;

    final candRect = Rect.fromCenter(
      center: pos,
      width: targetW,
      height: targetH,
    );
    final ok = await _waitAreaFree(candRect.inflate(2));
    if (!ok) return;
    if (_overlapsAnyResidue(candRect.inflate(2))) return;

    _activeResidTypes.add(tipo);

    late ResiduoComponent comp;
    if (nz == 'mar') {
      comp = ResiduoBoiando(
        tipo: tipo,
        zona: nz,
        sprite: spr,
        start: Vector2(pos.dx, pos.dy),
        onDispose: () {
          _activeResidTypes.remove(tipo);
          _residuos.remove(comp);
        },
      );
    } else {
      comp = ResiduoAreia(
        tipo: tipo,
        zona: nz,
        sprite: spr,
        start: Vector2(pos.dx, pos.dy),
        onDispose: () {
          _activeResidTypes.remove(tipo);
          _residuos.remove(comp);
        },
      );
    }

    comp.size = Vector2(targetW, targetH);

    // ✅ novo: garante que o resíduo já respeite o modo atual (redução ou normal)
    comp.applyReduceMotion(_reduceMotion);

    _residuos.add(comp);
    if (_world != null) {
      _world!.add(comp);
    } else {
      add(comp);
    }
  }

  // ======= COLETA =======
  void _coletarResiduo(ResiduoComponent r) {
    if (r.animating) return;

    residuesCollected.value = residuesCollected.value + 1;
    final simpleName = _residueNameShort(r.tipo);
    final map = Map<String, int>.from(residueCounts.value);
    map[simpleName] = (map[simpleName] ?? 0) + 1;
    residueCounts.value = map;

    score.value = score.value + 20;
    _sfx('audio/residuos-effect.wav');

    _spawnScoreText(
      20,
      Offset(r.position.x, r.position.y),
      label: _labelResiduo(r.tipo),
    );

    r.playVanishAndRemove();
  }

  void _ensureMoving(CrabComponent c) {
    if (!isMounted || timeLeft.value <= 0 || !_started) return;

    final hasMove = c.children.any(
      (child) => child is MoveEffect || child is SequenceEffect,
    );

    if (!hasMove) {
      _startWalkLoop(c);
    }
  }

  /// Garante que o efeito flutuante (texto/ícone) fique dentro do canvas.
  Vector2 _clampFloatingStart(
    Vector2 desired,
    TextPaint textPaint,
    String displayText,
    double distance, {
    required bool withIcon,
  }) {
    final style = textPaint.style;
    final double fontSize = style.fontSize ?? 16.0;

    final tp = TextPainter(
      text: TextSpan(text: displayText, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    final double textW = tp.width;
    final double textH = tp.height;

    final double iconW = withIcon ? fontSize * 1.8 : 0.0;
    final double spacing = withIcon ? 8.0 : 0.0;
    final double totalW = textW + iconW + spacing;
    final double totalH = max(textH, withIcon ? (fontSize * 1.8) : textH);

    const double margin = 6.0;
    final double halfW = totalW / 2.0;
    final double halfH = totalH / 2.0;

    final double minX = margin + halfW;
    final double maxX = size.x - margin - halfW;

    double x = desired.x.clamp(minX, maxX).toDouble();

    final double topMinStart = margin + halfH + distance;
    final double bottomMaxStart = size.y - margin - halfH;
    double y = desired.y.clamp(topMinStart, bottomMaxStart).toDouble();

    return Vector2(x, y);
  }

  void _spawnScoreText(int delta, Offset worldPos, {String? label}) {
    final baseScore = delta >= 0 ? '+$delta' : '$delta';
    final displayText = (label != null && delta >= 0)
        ? '$label\n$baseScore'
        : baseScore;
    final color = delta >= 0 ? Colors.white : Colors.redAccent;

    final double base = (size.y * 0.026).clamp(12.0, 20.0).toDouble();
    final tp = TextPaint(
      style: TextStyle(
        fontSize: base,
        fontWeight: FontWeight.w900,
        fontFamily: fontFamily,
        color: color,
        shadows: const [
          Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(1, 1)),
        ],
      ),
    );

    final double distance = size.y * 0.06;
    final bool hasIcon = _okIcon != null && delta >= 0;

    Vector2 start = Vector2(worldPos.dx, worldPos.dy);
    start = _clampFloatingStart(
      start,
      tp,
      displayText,
      distance,
      withIcon: hasIcon,
    );

    if (hasIcon) {
      final comp = FloatingScoreWithIcon(
        text: displayText,
        textPaint: tp,
        icon: _okIcon!,
        start: start,
        distance: distance,
        duration: 0.9,
      );
      if (_world != null) {
        _world!.add(comp);
      } else {
        add(comp);
      }
    } else {
      final comp = FloatingScore(
        text: displayText,
        textPaint: tp,
        start: start,
        distance: distance,
        duration: 0.9,
      );
      if (_world != null) {
        _world!.add(comp);
      } else {
        add(comp);
      }
    }
  }

  void _shakeNegativeFeedback() {
    if (_reduceMotion) return;
    final wroot = _world;
    if (wroot == null) return;

    final toRemove = wroot.children
        .where((c) => c is MoveEffect || c is SequenceEffect)
        .toList(growable: false);
    for (final e in toRemove) {
      e.removeFromParent();
    }

    final double mag = (size.x * 0.012).clamp(4.0, 12.0).toDouble();

    final seq = SequenceEffect([
      MoveEffect.by(
        Vector2(mag, 0),
        EffectController(duration: 0.04, curve: Curves.easeOut),
      ),
      MoveEffect.by(
        Vector2(-mag * 2, 0),
        EffectController(duration: 0.08, curve: Curves.easeInOut),
      ),
      MoveEffect.by(
        Vector2(mag, 0),
        EffectController(duration: 0.04, curve: Curves.easeOut),
      ),
      MoveEffect.by(Vector2(0, 0), EffectController(duration: 0.02)),
    ]);

    wroot.add(seq);
  }

  void dismissActionMessage() {
    _messageTimer?.cancel();
    _messageTimer = null;
    actionMessage.value = null;
  }

  void showAction(
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _messageTimer?.cancel();
    actionMessage.value = message;

    if (duration > Duration.zero) {
      _messageTimer = async.Timer(duration, () {
        actionMessage.value = null;
        _messageTimer = null;
      });
    } else {
      _messageTimer = null;
    }
  }

  @override
  void onRemove() {
    _stopAllAnimations();
    _countdownTimer?.cancel();
    _messageTimer?.cancel();
    _defesoCheckTimer?.cancel();
    _defesoEndTimer?.cancel();
    _defesoSecondsTimer?.cancel();
    _residuoTimer?.cancel();

    score.dispose();
    timeLeft.dispose();
    sfxEnabled.removeListener(_onSfxPreferenceChanged);
    sfxEnabled.dispose();
    actionMessage.dispose();
    defesoSeconds.dispose();

    super.onRemove();
  }

  // ======= MOVIMENTO DOS CARANGUEJOS =======
  void _startWalkLoop(CrabComponent crab, {double? lastDir}) {
    if (!isMounted || timeLeft.value <= 0) return;

    const double designW = 1280.0;
    const double stepDesignX = 128.0;
    final stepX = (size.x / designW) * stepDesignX;

    double dirSign = lastDir ?? (crab.position.x < size.x * 0.5 ? 1.0 : -1.0);
    if (crab.position.x < size.x * 0.12) dirSign = 1.0;
    if (crab.position.x > size.x * 0.88) dirSign = -1.0;
    if (_rand.nextDouble() < 0.04) dirSign *= -1.0;

    final roiSpan = (_roiY1World > _roiY0World)
        ? (_roiY1World - _roiY0World)
        : (size.y * 0.2);
    final depth =
        ((crab.position.y - _roiY0World) / (roiSpan == 0 ? 1 : roiSpan)).clamp(
          0.0,
          1.0,
        );

    final jitter = _rand.nextDouble();

    final double topBand = _roiY0World + roiSpan * 0.06;
    final double bottomBand = _roiY1World - roiSpan * 0.06;
    final double y = crab.position.y;

    double vDrift;
    if (y <= topBand) {
      vDrift = 0.8;
    } else if (y < topBand + roiSpan * 0.10) {
      vDrift = 0.4;
    } else if (y >= bottomBand) {
      vDrift = -0.8;
    } else if (y > bottomBand - roiSpan * 0.10) {
      vDrift = -0.4;
    } else {
      vDrift = (_rand.nextDouble() * 0.24) - 0.12;
    }

    final bool lowMotion = _reduceMotion;
    crab.applyReduceMotion(lowMotion);

    final double ampMult = crab.isSmall
        ? (lowMotion ? 1.0 : 2.2)
        : (lowMotion ? 1.2 : 2.6);
    final double speedMult = crab.isSmall
        ? (lowMotion ? 0.7 : 1.1)
        : (lowMotion ? 0.65 : 0.95);

    crab.playSpawnMotion(
      stepX: stepX,
      dirSign: dirSign,
      depth: depth,
      jitter: jitter,
      ampMult: ampMult,
      vDrift: vDrift,
      speedMult: speedMult,
      onComplete: () {
        if (!isMounted || timeLeft.value <= 0 || !_started) return;

        final count = (_loopCounter[crab] ?? 0) + 1;
        _loopCounter[crab] = count;

        final target = _loopTarget[crab] ?? (5 + _rand.nextInt(3));
        _loopTarget[crab] = target;

        if (count >= target) {
          _loopCounter[crab] = 0;
          _loopTarget[crab] = 5 + _rand.nextInt(3);

          final avoids = <Offset>[];
          if (_crab != null) {
            avoids.add(Offset(_crab!.position.x, _crab!.position.y));
          }
          if (_crab2 != null) {
            avoids.add(Offset(_crab2!.position.x, _crab2!.position.y));
          }

          final idx = _claimBurrowIndexAvoiding(
            avoid: avoids,
            minDistFraction: 0.20,
          );

          crab.playVanish(
            duration: lowMotion ? 0.10 : 0.18,
            onComplete: () async {
              final pos = _burrows[idx];
              _reservedBurrows.remove(idx);

              await _placeCrabInto(
                crab,
                randomizeSize: true,
                posOverride: pos,
                forceSmall: identical(crab, _crab2),
              );

              async.Future.delayed(
                Duration(
                  milliseconds: lowMotion ? 140 : 12 + _rand.nextInt(12),
                ),
                () {
                  _startWalkLoop(crab, lastDir: dirSign);
                },
              );
            },
          );
        } else {
          async.Future.delayed(
            Duration(milliseconds: lowMotion ? 140 : 12 + _rand.nextInt(12)),
            () {
              _startWalkLoop(crab, lastDir: dirSign);
            },
          );
        }
      },
    );
  }

  void _onCrabTapped(CrabComponent c) {
    if (!_acceptClicks) return;
    if (c.animating) return;

    if (defesoAtivo.value) {
      score.value = score.value - 20;
      showAction('Período de defeso: não capture caranguejos!');
      _spawnScoreText(-20, Offset(c.position.x, c.position.y));
      _shakeNegativeFeedback();
      _sfx('audio/negative-point.mp3');
      if (!_reduceMotion) HapticFeedback.heavyImpact();
      if (!_reduceMotion) HapticFeedback.vibrate();
      _ensureMoving(c);
      return;
    }

    if (c.isSmall) {
      score.value = score.value - 20;
      showAction('Este caranguejo é pequeno, deixe crescer!');
      _spawnScoreText(-20, Offset(c.position.x, c.position.y));
      _shakeNegativeFeedback();
      _sfx('audio/negative-point.mp3');
      if (!_reduceMotion) HapticFeedback.heavyImpact();
      if (!_reduceMotion) HapticFeedback.vibrate();
      _ensureMoving(c);
      return;
    }

    score.value = score.value + 15;
    crabsCaptured.value = crabsCaptured.value + 1;
    _spawnScoreText(15, Offset(c.position.x, c.position.y));
    _sfx('audio/point-effect.wav');

    final avoids = <Offset>[];
    if (_crab != null) avoids.add(Offset(_crab!.position.x, _crab!.position.y));
    if (_crab2 != null) {
      avoids.add(Offset(_crab2!.position.x, _crab2!.position.y));
    }

    final idx = _claimBurrowIndexAvoiding(avoid: avoids, minDistFraction: 0.20);

    c.playVanish(
      onComplete: () async {
        final pos = _burrows[idx];
        _reservedBurrows.remove(idx);

        await _placeCrabInto(
          c,
          randomizeSize: true,
          posOverride: pos,
          forceSmall: identical(c, _crab2),
        );
        _startWalkLoop(c);
      },
    );

    async.Future.delayed(const Duration(milliseconds: 260), () {
      _ensureMoving(c);
    });
  }
}

/// =====================================================================
///  UI AUXILIAR
/// =====================================================================
class CrabComponent extends SpriteComponent {
  CrabComponent({required super.sprite}) : super(priority: 10);

  bool reduceMotion = false;
  bool isSmall = false;
  bool animating = false;
  async.Timer? _animTimer;

  void _setAnimatingFor(Duration d) {
    animating = true;
    _animTimer?.cancel();
    _animTimer = async.Timer(d, () => animating = false);
  }

  void applyReduceMotion(bool value) {
    if (reduceMotion == value) return;
    reduceMotion = value;

    if (reduceMotion) {
      _animTimer?.cancel();
      animating = false;
      for (final effect in children.whereType<Effect>().toList()) {
        effect.removeFromParent();
      }
      opacity = 1;
      scale.setValues(1, 1);
      angle = 0;
    }
  }

  void stopAllMotion() {
    _animTimer?.cancel();
    animating = false;
    for (final effect in children.whereType<Effect>().toList()) {
      effect.removeFromParent();
    }
  }

  @override
  void onRemove() {
    _animTimer?.cancel();
    super.onRemove();
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
  }

  void playSpawnMotion({
    required double stepX,
    required double dirSign,
    required double depth,
    required double jitter,
    double ampMult = 1.0,
    double speedMult = 1.0,
    double vDrift = 0.0,
    VoidCallback? onComplete,
  }) {
    final toRemove = children
        .where((c) => c is MoveEffect || c is SequenceEffect)
        .toList(growable: false);
    for (final e in toRemove) {
      e.removeFromParent();
    }

    final double motionScale = reduceMotion ? 0.25 : 1.0;
    final double timeScale = reduceMotion ? 0.55 : 1.0;

    final double amp = (0.10 + 0.14 * depth) * ampMult * motionScale;
    final double ax = stepX * amp * (0.9 + 0.2 * jitter) * dirSign;
    double ay = stepX * (amp * 0.12) * (0.9 + 0.2 * (1 - jitter));
    ay += stepX * 0.35 * vDrift * motionScale;

    double d1 = 0.12 + 0.06 * (1 - depth) * (0.5 + 0.5 * jitter);
    double d2 = 0.11 + 0.05 * depth * (0.5 + 0.5 * (1 - jitter));
    double d3 = 0.11 + 0.05 * (0.5 + 0.5 * jitter);
    double d4 = 0.10 + 0.04 * (0.5 + 0.5 * (1 - jitter));

    d1 *= timeScale;
    d2 *= timeScale;
    d3 *= timeScale;
    d4 *= timeScale;

    final int steps = reduceMotion ? 6 : 14;

    final Vector2 diag = Vector2(ax, ay);
    final Vector2 stepVec = Vector2(diag.x / steps, diag.y / steps);

    final double len = diag.length;
    Vector2 perp = len < 0.0001
        ? Vector2(0, 0)
        : Vector2(-diag.y / len, diag.x / len);

    final double wiggleMag =
        stepX * (0.009 + 0.013 * depth) * (0.7 + 0.3 * jitter) * motionScale;
    final Vector2 dirUnit = len < 0.0001
        ? Vector2.zero()
        : Vector2(diag.x / len, diag.y / len);

    final double diagJitterMag =
        (stepX * 0.004 + stepX * 0.008 * depth * (0.7 + 0.3 * jitter)) *
        motionScale;

    final double phase0 = jitter * pi * 2.0;
    final double cycles = reduceMotion ? 0.5 : (1.2 + 0.3 * jitter);

    final moveEffects = <Effect>[];
    final double totalDur =
        (d1 + d2 + d3 + d4) / (speedMult <= 0 ? 1.0 : speedMult);
    final double segDur = totalDur / steps;

    for (int i = 0; i < steps; i++) {
      final double t = (i + 1) / steps;
      final double wave = sin(phase0 + t * pi * 2.0 * cycles);
      final double wave90 = cos(phase0 + t * pi * 2.0 * cycles);

      final Vector2 w = perp * (wiggleMag * wave);
      final Vector2 dj = dirUnit * (diagJitterMag * 0.45 * wave90);
      final Vector2 seg = stepVec + w + dj;

      moveEffects.add(
        MoveEffect.by(
          seg,
          EffectController(
            duration: segDur,
            curve: reduceMotion ? Curves.easeOut : Curves.easeInOut,
          ),
        ),
      );
    }

    final seq = SequenceEffect(moveEffects)
      ..onComplete = () {
        onComplete?.call();
      };
    add(seq);
  }

  void playSpawnAppearance({required double microDelay}) {
    final toRemove = children
        .where((c) => c is OpacityEffect || c is ScaleEffect)
        .toList(growable: false);
    for (final e in toRemove) {
      e.removeFromParent();
    }

    _setAnimatingFor(Duration(milliseconds: 300 + (microDelay * 1000).round()));

    opacity = 0.0;
    scale.setValues(0.92, 0.92);

    add(
      OpacityEffect.to(
        1.0,
        EffectController(
          duration: 0.22,
          startDelay: microDelay,
          curve: Curves.easeOutCubic,
        ),
      ),
    );
    add(
      ScaleEffect.to(
        Vector2(1, 1),
        EffectController(
          duration: 0.26,
          startDelay: microDelay * 0.9,
          curve: Curves.easeOutCubic,
        ),
      ),
    );
  }

  void playVanish({double duration = 0.18, VoidCallback? onComplete}) {
    _setAnimatingFor(Duration(milliseconds: (duration * 1000).round() + 60));

    final toRemove = children.whereType<Effect>().toList(growable: false);
    for (final e in toRemove) {
      e.removeFromParent();
    }

    add(
      OpacityEffect.to(
          0.0,
          EffectController(duration: duration, curve: Curves.easeInOut),
        )
        ..onComplete = () {
          onComplete?.call();
        },
    );

    add(
      ScaleEffect.to(
        Vector2(0.86, 0.86),
        EffectController(duration: duration, curve: Curves.easeInOut),
      ),
    );
  }
}

class FloatingScore extends TextComponent {
  FloatingScore({
    required String text,
    required TextPaint textPaint,
    required Vector2 start,
    required double distance,
    required double duration,
    this.reduceMotion = false,
  }) : _baseStyle = textPaint.style,
       _distance = distance,
       _duration = duration,
       _start = start.clone(),
       super(text: text, textRenderer: textPaint) {
    position = start.clone();
    anchor = Anchor.center;
    priority = 1000;
  }

  final TextStyle _baseStyle;
  final double _distance;
  final double _duration;
  final Vector2 _start;
  final bool reduceMotion;

  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;

    final p = (_t / _duration).clamp(0.0, 1.0);
    position.setValues(_start.x, _start.y - _distance * p);

    final baseColor = _baseStyle.color ?? Colors.white;
    final next = _baseStyle.copyWith(color: baseColor.withOpacity(1.0 - p));
    textRenderer = TextPaint(style: next);

    if (p >= 1.0) removeFromParent();
  }
}

class FloatingScoreWithIcon extends PositionComponent {
  FloatingScoreWithIcon({
    required String text,
    required TextPaint textPaint,
    required Sprite icon,
    required Vector2 start,
    required double distance,
    required double duration,
    this.reduceMotion = false,
  }) : _text = TextComponent(text: text, textRenderer: textPaint),
       _icon = SpriteComponent(sprite: icon),
       _distance = distance,
       _duration = duration,
       _start = start.clone(),
       super(priority: 1000) {
    position = start.clone();
    anchor = Anchor.center;
  }

  final TextComponent _text;
  final SpriteComponent _icon;
  final double _distance;
  final double _duration;
  final Vector2 _start;
  final bool reduceMotion;

  double _t = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final double h = (_text.textRenderer as TextPaint).style.fontSize ?? 16;
    final double iconH = h * 1.8;

    _icon.size = Vector2(iconH, iconH);
    _icon.anchor = Anchor.centerRight;
    _icon.paint.filterQuality = FilterQuality.none;

    _text.anchor = Anchor.centerLeft;

    _icon.position = Vector2(-4, 0);
    _text.position = Vector2(4, 0);

    add(_icon);
    add(_text);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;

    final p = (_t / _duration).clamp(0.0, 1.0);
    position.setValues(_start.x, _start.y - _distance * p);

    final textStyle = (_text.textRenderer as TextPaint).style;
    final baseColor = textStyle.color ?? Colors.white;
    _text.textRenderer = TextPaint(
      style: textStyle.copyWith(color: baseColor.withOpacity(1.0 - p)),
    );

    _icon.opacity = 1.0 - p;

    if (p >= 1.0) removeFromParent();
  }
}
