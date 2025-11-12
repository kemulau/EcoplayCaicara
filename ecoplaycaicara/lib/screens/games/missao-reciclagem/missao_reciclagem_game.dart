import 'dart:async' as async;
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame/text.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../flame/narrable_text_component.dart';
import '../../../services/user_prefs.dart';
import 'bin_component.dart';
import 'item_component.dart';

enum ItemFailureReason { missed, wrongBin }

class MissaoReciclagemGame extends FlameGame
    with
        HasCollisionDetection,
        HasKeyboardHandlerComponents,
        MultiTouchTapDetector,
        MultiTouchDragDetector {
  MissaoReciclagemGame();

  static const int roundDurationSeconds = 60;

  double get groundLineY => _groundLineY;

  // ======= Estado/HUD =======
  final ValueNotifier<int> score = ValueNotifier<int>(0);
  final ValueNotifier<int> timeLeft = ValueNotifier<int>(roundDurationSeconds);
  final ValueNotifier<int> residuosOrganicos = ValueNotifier<int>(0);
  final ValueNotifier<int> residuosReciclaveis = ValueNotifier<int>(0);
  final ValueNotifier<bool> sfxEnabled = ValueNotifier<bool>(true);

  bool _reduceMotion = false;
  bool _paused = false;
  bool _roundActive = false;

  static const int _maxConcurrentItems = 1;
  final Random _rand = Random();
  async.Timer? _spawnTimer;
  async.Timer? _countdownTimer;

  Sprite? _successIcon;
  bool _audioUnlocked = !kIsWeb;
  Future<void>? _pendingAudioUnlock;
  async.Future<void>? _audioPreloadFuture;
  bool _endGameAudioPlayed = false;

  // ======= Mundo/elementos =======
  final List<ItemComponent> _activeItems = <ItemComponent>[];
  final List<BinComponent> _bins = <BinComponent>[];

  PositionComponent? _world;
  SpriteComponent? _backgroundComponent;
  Sprite? _desktopBackgroundSprite;
  Sprite? _mobileBackgroundSprite;

  Component get _root => _world ?? this;

  double _spawnLeft = 0;
  double _spawnRight = 0;
  double _groundLineY = 0;
  double _spawnStartY = 0;
  ItemType? _lastSpawnedType;
  static const double _nearBinMarginFactor = 0.32;
  static const double _nearBinMarginMin = 18.0;
  static const double _touchDeadZoneFraction = 0.02;
  static const double _touchBlendFactor = 0.52;

  Vector2 _lastCanvasSize = Vector2.zero();
  double _lastViewportLogicalWidth = 0;
  bool _mobileViewportOverride = false;
  ItemControlProfile _activeControlProfile = _desktopControlProfile;
  final Map<int, double> _activeTouchDirections = <int, double>{};
  double _currentTouchAxis = 0;
  double _lastAppliedTouchAxis = 0;

  // === Keyboard support (setas / A-D) ===
  double _keyboardAxis = 0;                // -1 (esq) .. 0 .. +1 (dir)
  bool _keyLeftHeld = false;
  bool _keyRightHeld = false;

  // ======= Assets dos itens/lixeiras =======
  static const Map<ItemType, List<String>> _itemAssets = <ItemType, List<String>>{
    ItemType.papel: <String>['games/missao-reciclagem/papelao.png'],
    ItemType.metal: <String>['games/missao-reciclagem/Latinha (2).png'],
    ItemType.vidro: <String>['games/missao-reciclagem/garrafa-vidro.png'],
    ItemType.plastico: <String>['games/missao-reciclagem/garrafa-pet.png'],
    ItemType.organico: <String>['games/missao-reciclagem/casca-banana.png'],
  };

  static const Map<BinType, String> _binSprites = <BinType, String>{
    BinType.papel: 'games/missao-reciclagem/papel.png',
    BinType.plastico: 'games/missao-reciclagem/plastico.png',
    BinType.metal: 'games/missao-reciclagem/metal.png',
    BinType.vidro: 'games/missao-reciclagem/vidro.png',
    BinType.organico: 'games/missao-reciclagem/organico.png',
  };
  static const ItemControlProfile _mobileControlProfile = ItemControlProfile(
    maxSpeed: 320,
    targetBlend: 8,
    snapDistance: 5,
  );
  static const ItemControlProfile _desktopControlProfile = ItemControlProfile(
    maxSpeed: 420,
    targetBlend: 11,
    snapDistance: 3,
  );
  static const String _sfxClick = 'audio/click.mp3';
  static const String _sfxResiduo = 'audio/residuos-effect.wav';
  static const String _sfxPoint = 'audio/point-effect.wav';
  static const String _sfxNegative = 'audio/negative-point.mp3';
  static const String _sfxEndPositive = 'audio/+fimdejogo.mp3';
  static const String _sfxEndNegative = 'audio/-fimdejogo.mp3';
  static const String _unlockAsset = _sfxPoint;
  static const List<String> _sfxAssets = <String>[
    _sfxClick,
    _sfxResiduo,
    _sfxPoint,
    _sfxNegative,
    _sfxEndPositive,
    _sfxEndNegative,
  ];

  static const List<String> _imageAssets = <String>[
    'games/missao-reciclagem/background-reciclagem.png',
    'games/missao-reciclagem/background-missao-mobile.png',
    'images/acertou.png',
    'games/missao-reciclagem/papel.png',
    'games/missao-reciclagem/plastico.png',
    'games/missao-reciclagem/metal.png',
    'games/missao-reciclagem/vidro.png',
    'games/missao-reciclagem/organico.png',
    'games/missao-reciclagem/papelao.png',
    'games/missao-reciclagem/Latinha (2).png',
    'games/missao-reciclagem/garrafa-vidro.png',
    'games/missao-reciclagem/garrafa-pet.png',
    'games/missao-reciclagem/casca-banana.png',
  ];

  static async.Future<void>? _imagePreload;
  static async.Future<void>? _audioPreload;

  @override
  Color backgroundColor() => Colors.transparent;

  Vector2 get _effectiveCanvasSize =>
      (_lastCanvasSize.x > 0 && _lastCanvasSize.y > 0) ? _lastCanvasSize : size;

  static Future<void> preloadAssets() {
    final images = preloadImages();
    final audio = preloadAudio();
    return Future.wait<void>([images, audio]).then((_) {});
  }

  static Future<void> preloadImages() {
    final existing = _imagePreload;
    if (existing != null) return existing;
    final future = _doPreloadImages();
    _imagePreload = future.catchError((Object error, StackTrace stack) {
      if (kDebugMode) {
        debugPrint('⚠️ Falha ao pré-carregar imagens do Missão Reciclagem: $error');
        debugPrintStack(stackTrace: stack);
      }
      _imagePreload = null;
    });
    return _imagePreload!;
  }

  static Future<void> preloadAudio() {
    final existing = _audioPreload;
    if (existing != null) return existing;
    final future = _doPreloadAudio();
    _audioPreload = future.catchError((Object error, StackTrace stack) {
      if (kDebugMode) {
        debugPrint('⚠️ Falha ao pré-carregar áudio do Missão Reciclagem: $error');
        debugPrintStack(stackTrace: stack);
      }
      _audioPreload = null;
    });
    return _audioPreload!;
  }

  static Future<void> _doPreloadImages() async {
    final String previousPrefix = Flame.images.prefix;
    Flame.images.prefix = 'assets/';
    try {
      for (final asset in _imageAssets) {
        try {
          await Flame.images.load(asset);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ Falha ao pré-carregar imagem "$asset": $e');
          }
        }
      }
    } finally {
      if (previousPrefix.isEmpty || previousPrefix == 'assets/') {
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

  bool get _isMobileView {
    if (_mobileViewportOverride) return true;
    final Vector2 canvas = _effectiveCanvasSize;
    if (canvas.x <= 0 || canvas.y <= 0) return false;
    return canvas.x <= 720 || canvas.y > canvas.x;
  }

  ItemControlProfile get _resolvedControlProfile =>
      _isMobileView ? _mobileControlProfile : _desktopControlProfile;

  void _refreshControlProfile({bool force = false}) {
    final ItemControlProfile next = _resolvedControlProfile;
    if (!force && identical(next, _activeControlProfile)) {
      return;
    }
    _activeControlProfile = next;
    for (final ItemComponent item in _activeItems) {
      item.applyControlProfile(next);
    }
    _applyTouchAxisToLead();
  }

  void _applyTouchAxisToLead() {
    if (_activeItems.isEmpty) return;
    _lastAppliedTouchAxis =
        _blendTouchAxis(_lastAppliedTouchAxis, _currentTouchAxis);
    _activeItems.last.setTouchAxis(_lastAppliedTouchAxis);
  }

  void _registerTouchDirection(int pointerId, Vector2 globalPosition) {
    if (_activeItems.isEmpty) return;
    async.unawaited(ensureAudioUnlocked());
    final double direction = _touchAxisForPosition(globalPosition);
    _activeTouchDirections[pointerId] = direction;
    _recomputeTouchAxis();
  }

  void _updateTouchDirection(int pointerId, Vector2 globalPosition) {
    if (_activeItems.isEmpty) return;
    final double direction = _touchAxisForPosition(globalPosition);
    final double? previous = _activeTouchDirections[pointerId];
    if (previous != null && (previous - direction).abs() < 0.01) {
      return;
    }
    _activeTouchDirections[pointerId] = direction;
    _recomputeTouchAxis();
  }

  void _unregisterTouchDirection(int pointerId) {
    final bool removed = _activeTouchDirections.remove(pointerId) != null;
    if (removed) {
      _recomputeTouchAxis();
    }
  }

  void _recomputeTouchAxis() {
    // média entre toques ativos e eixo do teclado
    int count = _activeTouchDirections.length;
    double total = 0;
    if (count > 0) {
      total = _activeTouchDirections.values.reduce((a, b) => a + b);
    }
    if (_keyboardAxis != 0) {
      total += _keyboardAxis;
      count += 1;
    }

    double axis;
    if (count == 0) {
      axis = 0;
    } else {
      axis = (total / count).clamp(-1, 1).toDouble();
    }
    if (axis.abs() < _touchDeadZoneFraction) {
      axis = 0;
    }
    _currentTouchAxis = axis;
    _applyTouchAxisToLead();
  }

  double _touchAxisForPosition(Vector2 globalPosition) {
    final double width = size.x;
    if (width <= 0) return 0;
    final double worldX = globalPosition.x;
    final double center = width / 2;
    final double delta = worldX - center;
    final double normalized = (delta / center).clamp(-1, 1).toDouble();
    if (normalized.abs() < _touchDeadZoneFraction) return 0;
    return normalized;
  }

  double _blendTouchAxis(double previous, double target) {
    return previous + (target - previous) * _touchBlendFactor;
  }

  // =========================================================
  // Lifecycle
  // =========================================================
  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final bool storedAudioEnabled =
        await UserPrefs.getAudioEnabled(defaultValue: true);
    if (storedAudioEnabled != sfxEnabled.value) {
      sfxEnabled.value = storedAudioEnabled;
    }
    sfxEnabled.addListener(_onSfxPreferenceChanged);

    images.prefix = 'assets/';
    FlameAudio.updatePrefix('assets/');

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

    await _loadBackground();
    _ensureBackgroundAdded();

    await _loadBins();
    _layoutWorld(force: true);
    _refreshControlProfile(force: true);

    try {
      _successIcon = await Sprite.load('images/acertou.png', images: images);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Falha ao pré-carregar images/acertou.png: $e');
      }
    }
  }

  @override
  void onGameResize(Vector2 canvasSize) {
    super.onGameResize(canvasSize);
    _lastCanvasSize = canvasSize.clone();
    _world?.size = size.clone();
    _refreshBackgroundSprite();
    _layoutWorld(force: true);
    _refreshControlProfile();
  }

  @override
  void update(double dt) {
    super.update(dt);
  }

  Future<Sprite?> _safeLoadSprite(String path) async {
    try {
      return await Sprite.load(path, images: images);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Falha ao carregar $path: $e');
      }
      return null;
    }
  }

  Future<void> _loadBackground() async {
    final sprites = await Future.wait<Sprite?>([
      _safeLoadSprite('games/missao-reciclagem/background-reciclagem.png'),
      _safeLoadSprite('games/missao-reciclagem/background-missao-mobile.png'),
    ]);
    _desktopBackgroundSprite = sprites[0];
    _mobileBackgroundSprite = sprites[1];
  }

  Sprite? _currentBackgroundSprite() {
    if (_isMobileView && _mobileBackgroundSprite != null) {
      return _mobileBackgroundSprite;
    }
    return _desktopBackgroundSprite ?? _mobileBackgroundSprite;
  }

  void _ensureBackgroundAdded() {
    final sprite = _currentBackgroundSprite();
    _backgroundComponent ??= SpriteComponent(priority: -10)
      ..anchor = Anchor.topLeft;
    if (sprite != null) {
      _backgroundComponent!.sprite = sprite;
    }
    _backgroundComponent!
      ..size = size.clone()
      ..position = Vector2.zero();
    if (!(_backgroundComponent!.isMounted)) {
      _root.add(_backgroundComponent!);
    }
  }

  void _refreshBackgroundSprite() {
    final sprite = _currentBackgroundSprite();
    final component = _backgroundComponent;
    if (component == null) {
      _ensureBackgroundAdded();
      return;
    }
    if (sprite != null) {
      component.sprite = sprite;
    }
    component
      ..size = size.clone()
      ..position = Vector2.zero();
  }

  Future<void> _loadBins() async {
    const order = <BinType>[
      BinType.papel,
      BinType.plastico,
      BinType.metal,
      BinType.vidro,
      BinType.organico,
    ];

    _bins.clear();
    for (final type in order) {
      final String asset = _binSprites[type]!;
      final Sprite sprite = await Sprite.load(asset, images: images);
      final bin = BinComponent(
        type: type,
        sprite: sprite,
        position: Vector2.zero(),
        size: Vector2.zero(),
      );
      bin.priority = 10; // garante camada acima do background e abaixo dos itens
      _bins.add(bin);
      _root.add(bin);
    }
  }

  void _layoutWorld({bool force = false}) {
    if (size.x <= 0 || size.y <= 0) return;

    final bg = _backgroundComponent;
    if (bg != null) {
      bg
        ..size = Vector2(size.x, size.y)
        ..position = Vector2.zero();
    }

    _layoutBins();

    for (final item in _activeItems) {
      item
        ..updateGroundLine(_groundLineY)
        ..updateBounds(_spawnLeft, _spawnRight);
    }
  }

  void _layoutBins() {
    if (_bins.isEmpty || size.x <= 0 || size.y <= 0) return;

    final double w = size.x;
    final double h = size.y;
    final bool portrait = h > w;
    final bool mobile = _isMobileView;

    final double marginH = w * (portrait ? 0.056 : 0.046);
    final double safeInset = w * (portrait ? 0.032 : 0.026);
    final double layoutLeft = marginH + safeInset;
    final double layoutRight = w - marginH - safeInset;
    final double layoutWidth = max(0.0, layoutRight - layoutLeft);
    final double bottomPadding = h * (portrait ? 0.090 : 0.066);
    final double baseGap = w *
        (portrait
            ? (mobile ? 0.0085 : 0.0105)
            : (mobile ? 0.0065 : 0.0085));

    final int count = _bins.length;
    final double usable = max(0.0, layoutWidth);

    double desiredSize = (usable - baseGap * (count - 1)) / count;
    if (mobile) {
      final double scaleBoost = portrait ? 1.48 : 1.28;
      desiredSize *= scaleBoost;
    }
    final double maxBin = h *
        (portrait
            ? (mobile ? 0.36 : 0.25)
            : (mobile ? 0.27 : 0.18));
    final double minBin = h *
        (portrait
            ? (mobile ? 0.11 : 0.096)
            : (mobile ? 0.10 : 0.088));

    double binSize = desiredSize.clamp(minBin, maxBin);

    double totalWidth = binSize * count + baseGap * (count - 1);
    final double maxRowWidth = max(0.0, usable);
    if (totalWidth > maxRowWidth && maxRowWidth > 0) {
      final double scale = maxRowWidth / totalWidth;
      binSize *= scale;
      totalWidth = binSize * count + baseGap * (count - 1);
    }

    final double start = layoutLeft + max(0.0, (layoutWidth - totalWidth) / 2.0);
    final double yBottom = h - 4.0 - bottomPadding * 0.0;

    double leftEdge = double.infinity;
    double rightEdge = -double.infinity;

    for (int i = 0; i < count; i++) {
      final double cx = start + binSize / 2 + i * (binSize + baseGap);
      final bin = _bins[i];
      bin
        ..size = Vector2.all(binSize)
        ..anchor = Anchor.bottomCenter
        ..position = Vector2(cx, yBottom);

      leftEdge = min(leftEdge, cx - binSize / 2);
      rightEdge = max(rightEdge, cx + binSize / 2);
    }

    final double spawnMargin = binSize * 0.25;
    _spawnLeft = max(layoutLeft, leftEdge - spawnMargin * 0.4);
    _spawnRight = min(layoutRight, rightEdge + spawnMargin * 0.4);
    if (_spawnRight <= _spawnLeft) {
      final double center = w / 2;
      final double fallbackRange = binSize * 0.6;
      _spawnLeft = center - fallbackRange;
      _spawnRight = center + fallbackRange;
    }

    final double groundOffset = binSize * (mobile ? 0.18 : 0.14);
    _groundLineY = yBottom - binSize - groundOffset;

    final double topSafe = h * (portrait ? 0.14 : 0.10);
    final double desiredSpawn = topSafe + binSize * (mobile ? 0.42 : 0.32);
    final double maxSpawn = _groundLineY - binSize * 0.55;
    final double minSpawn = topSafe;
    _spawnStartY = max(minSpawn, min(desiredSpawn, maxSpawn));
  }

  // =========================================================
  // Preferências/Acessibilidade
  // =========================================================
  void toggleSfx() {
    sfxEnabled.value = !sfxEnabled.value;
  }

  void _onSfxPreferenceChanged() {
    async.unawaited(UserPrefs.setAudioEnabled(sfxEnabled.value));
  }

  void updateReduceMotion(bool value) {
    if (_reduceMotion == value) return;
    _reduceMotion = value;
    for (final ItemComponent item in _activeItems) {
      item.updateReduceMotion(value);
    }
  }

  void updateViewportProfile(double logicalWidth) {
    if (logicalWidth <= 0) return;
    _lastViewportLogicalWidth = logicalWidth;
    final bool shouldForceMobile = logicalWidth <= 760;
    if (_mobileViewportOverride == shouldForceMobile) {
      return;
    }
    _mobileViewportOverride = shouldForceMobile;
    _layoutWorld(force: true);
    _refreshControlProfile(force: true);
  }

  Future<void> playClick() => _playClick();

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
    final future = _unlockAudioInternal();
    _pendingAudioUnlock = future;
    try {
      await future;
    } finally {
      if (identical(_pendingAudioUnlock, future)) {
        _pendingAudioUnlock = null;
      }
    }
  }

  // =========================================================
  // Spawns / Round
  // =========================================================
  void _scheduleNextSpawn({bool immediate = false}) {
    _spawnTimer?.cancel();

    if (!_roundActive || timeLeft.value <= 0) {
      _spawnTimer = null;
      return;
    }
    if (_activeItems.isNotEmpty) {
      _spawnTimer = null;
      return;
    }

    final int delayMs = immediate ? 0 : 2400 + _rand.nextInt(800);
    _spawnTimer = async.Timer(Duration(milliseconds: delayMs), () async {
      if (!_roundActive || _paused || timeLeft.value <= 0) {
        _scheduleNextSpawn();
        return;
      }
      if (_activeItems.isNotEmpty) {
        _scheduleNextSpawn();
        return;
      }
      try {
        await spawnItem();
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('⚠️ Falha ao spawnar resíduo: $e');
          debugPrintStack(stackTrace: st);
        }
        _scheduleNextSpawn(immediate: true);
      }
    });
  }

  ItemType _pickNextItemType() {
    final List<ItemType> options = ItemType.values.toList();
    if (_lastSpawnedType != null && options.length > 1) {
      options.remove(_lastSpawnedType);
    }
    final ItemType choice = options[_rand.nextInt(options.length)];
    _lastSpawnedType = choice;
    return choice;
  }

  Future<void> spawnItem() async {
    if (_activeItems.length >= _maxConcurrentItems) return;
    final ItemType type = _pickNextItemType();
    final List<String> pool = _itemAssets[type]!;
    final String asset = pool[_rand.nextInt(pool.length)];
    final Sprite sprite = await Sprite.load(asset, images: images);

    final double leftClamp = _spawnLeft;
    final double rightClamp = _spawnRight;
    final double startX = (leftClamp + rightClamp) / 2;
    final double fallSpeed = 90 + _rand.nextDouble() * 30;

    final item = ItemComponent(
      type: type,
      sprite: sprite,
      start: Vector2(startX, _spawnStartY),
      fallSpeed: fallSpeed,
      leftClamp: leftClamp,
      rightClamp: rightClamp,
      groundLineY: groundLineY,
      controlProfile: _activeControlProfile,
    )..updateReduceMotion(_reduceMotion);

    final Vector2 frameSize = sprite.srcSize;
    if (frameSize.x > 0 && frameSize.y > 0) {
      const double targetMaxSide = 72.0;
      final double maxSourceSide =
          frameSize.x > frameSize.y ? frameSize.x : frameSize.y;
      final double scale = targetMaxSide / maxSourceSide;
      final Vector2 baseSize =
          Vector2(frameSize.x * scale, frameSize.y * scale);
      item.size = baseSize;
    }

    if (type == ItemType.metal) {
      final Vector2 original = item.size.clone();
      item.size = Vector2(original.x * 0.65, original.y * 0.65);
    } else if (type == ItemType.plastico && _isMobileView) {
      final Vector2 original = item.size.clone();
      item.size = Vector2(original.x * 0.78, original.y * 0.78);
    }

    _root.add(item..priority = 20); // itens acima das lixeiras
    _activeItems.add(item);
    _applyTouchAxisToLead();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = async.Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isMounted || _paused) return;
      final int next = max(0, timeLeft.value - 1);
      if (next != timeLeft.value) {
        timeLeft.value = next;
      }
      if (timeLeft.value == 0) {
        timer.cancel();
        stopRound();
        async.unawaited(_playEndGameSfx());
        pauseEngine();
        if (!overlays.isActive('GameOver')) {
          overlays.add('GameOver');
        }
      }
    });
  }

  void startRound() {
    if (_roundActive) return;
    _roundActive = true;
    _scheduleNextSpawn();
    _startCountdown();
  }

  void stopRound() {
    _spawnTimer?.cancel();
    _countdownTimer?.cancel();
    _spawnTimer = null;
    _countdownTimer = null;
    _roundActive = false;

    // limpa qualquer “toque preso” e teclas
    _activeTouchDirections.clear();
    _currentTouchAxis = 0;
    _lastAppliedTouchAxis = 0;
    _keyLeftHeld = false;
    _keyRightHeld = false;
    _keyboardAxis = 0;
  }

  void resetGame() {
    stopRound();
    for (final item in List<ItemComponent>.from(_activeItems)) {
      item.removeFromParent();
    }
    _activeItems.clear();
    score.value = 0;
    timeLeft.value = roundDurationSeconds;
    residuosOrganicos.value = 0;
    residuosReciclaveis.value = 0;
    _lastSpawnedType = null;
    _endGameAudioPlayed = false;
  }

  bool isWithinCatchMargin(ItemComponent item) {
    if (_bins.isEmpty) return false;
    for (final BinComponent bin in _bins) {
      if (!bin.matches(item.type)) continue;
      final double tolerance = _binCatchTolerance(bin);
      final double distanceX = (item.position.x - bin.position.x).abs();
      return distanceX <= tolerance;
    }
    return false;
  }

  double _binCatchTolerance(BinComponent bin) {
    final double halfWidth = bin.size.x / 2;
    final double margin = max(_nearBinMarginMin, bin.size.x * _nearBinMarginFactor);
    return halfWidth + margin;
  }

  // =========================================================
  // Input (toque e teclado)
  // =========================================================
  @override
  void onTapDown(int pointerId, TapDownInfo info) {
    if (!_roundActive && timeLeft.value > 0) startRound(); // inicia no primeiro toque
    _registerTouchDirection(pointerId, info.eventPosition.global);
    _directActiveItem(info.eventPosition.global);
  }

  @override
  void onTapUp(int pointerId, TapUpInfo info) {
    _unregisterTouchDirection(pointerId);
  }

  @override
  void onTapCancel(int pointerId) {
    _unregisterTouchDirection(pointerId);
  }

  @override
  void onDragStart(int pointerId, DragStartInfo info) {
    _registerTouchDirection(pointerId, info.eventPosition.global);
  }

  @override
  void onDragUpdate(int pointerId, DragUpdateInfo info) {
    _updateTouchDirection(pointerId, info.eventPosition.global);
    _directActiveItem(info.eventPosition.global);
  }

  @override
  void onDragEnd(int pointerId, DragEndInfo info) {
    _unregisterTouchDirection(pointerId);
  }

  @override
  void onDragCancel(int pointerId) {
    _unregisterTouchDirection(pointerId);
  }

  // === SETAS DO TECLADO ===
  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    // Interessa apenas setas (ou A/D)
    final LogicalKeyboardKey key = event.logicalKey;
    final bool isArrowKey = key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyA ||
        key == LogicalKeyboardKey.keyD;

    if (!isArrowKey) return KeyEventResult.ignored;

    // Atualiza estado de "tecla segurada"
    _keyLeftHeld = keysPressed.contains(LogicalKeyboardKey.arrowLeft) ||
        keysPressed.contains(LogicalKeyboardKey.keyA);
    _keyRightHeld = keysPressed.contains(LogicalKeyboardKey.arrowRight) ||
        keysPressed.contains(LogicalKeyboardKey.keyD);

    // Converte estado para eixo do teclado
    double axis = 0;
    if (_keyLeftHeld && !_keyRightHeld) {
      axis = -1;
    } else if (_keyRightHeld && !_keyLeftHeld) {
      axis = 1;
    }
    _keyboardAxis = axis;
    _recomputeTouchAxis();

    // “Nudge” no KeyDown para clique curto do HUD produzir movimento visível
    if (event is KeyDownEvent) {
      _nudgeFromKey(key);
    }

    return KeyEventResult.handled;
  }

  // Empurra o item um passo curto quando há um KeyDown único (clique curto)
  void _nudgeFromKey(LogicalKeyboardKey key) {
    if (_activeItems.isEmpty) return;
    final ItemComponent lead = _activeItems.last;

    final bool left = key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA;
    final bool right = key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyD;
    if (!left && !right) return;

    final double sign = left ? -1.0 : 1.0;
    // passo proporcional à largura útil
    final double range = (_spawnRight - _spawnLeft).abs();
    final double step = max(8.0, range * 0.06); // 6% da faixa
    final double targetX = lead.position.x + step * sign;
    lead.setTargetX(targetX);
  }

  double globalToWorldX(Vector2 globalPosition) => globalPosition.x;

  void _directActiveItem(Vector2 globalPosition) {
    if (_activeItems.isEmpty) return;
    final double targetX = globalToWorldX(globalPosition);
    final ItemComponent lead = _activeItems.last;
    lead.setTargetX(targetX);
  }

  // =========================================================
  // Pausa / Pontuação / Feedback
  // =========================================================
  @override
  void pauseEngine() {
    _paused = true;
    super.pauseEngine();
  }

  @override
  void resumeEngine() {
    _paused = false;
    super.resumeEngine();
  }

  bool get isPaused => _paused;

  void notifyWrongBinDrop(BinComponent bin) {
    if (_reduceMotion) return;
    _shakeBin(bin);
  }

  void _shakeBin(BinComponent bin) {
    final Iterable<Component> shaking =
        bin.children.where((child) => child is MoveEffect || child is SequenceEffect);
    for (final Component effect in shaking.toList(growable: false)) {
      effect.removeFromParent();
    }

    final double magnitude = (bin.size.x * 0.085).clamp(4.0, 18.0);
    final SequenceEffect seq = SequenceEffect(<Effect>[
      MoveEffect.by(
        Vector2(magnitude, 0),
        EffectController(duration: 0.045, curve: Curves.easeOut),
      ),
      MoveEffect.by(
        Vector2(-magnitude * 2, 0),
        EffectController(duration: 0.09, curve: Curves.easeInOut),
      ),
      MoveEffect.by(
        Vector2(magnitude, 0),
        EffectController(duration: 0.045, curve: Curves.easeOut),
      ),
    ])..removeOnFinish = true;

    bin.add(seq);
  }

  Future<void> resolveItem({
    required ItemComponent item,
    required bool correct,
    ItemFailureReason? failureReason,
  }) async {
    final Vector2 spawnPosition = item.position.clone();
    final ItemType type = item.type;
    final String itemLabel = _itemLabel(type);
    if (correct) {
      score.value = score.value + 10;
      if (type == ItemType.organico) {
        residuosOrganicos.value = residuosOrganicos.value + 1;
      } else {
        residuosReciclaveis.value = residuosReciclaveis.value + 1;
      }
      _spawnScoreDelta(
        10,
        spawnPosition,
        label: itemLabel,
        spokenText: 'Acerto com $itemLabel! Você ganhou dez pontos.',
      );
      async.unawaited(_playResiduoEffect());
      await playPositivePointAudio();
    } else {
      const int penalty = 5;
      score.value = score.value - penalty;
      final int pointsLost = penalty;
      final String pontosLabel = pointsLost == 1 ? 'ponto' : 'pontos';
      final String spokenText = failureReason == ItemFailureReason.wrongBin
          ? '$itemLabel na lixeira errada. Você perdeu $pointsLost $pontosLabel.'
          : '$itemLabel caiu no chão e você perdeu $pointsLost $pontosLabel.';
      _spawnScoreDelta(
        -pointsLost,
        spawnPosition,
        label: itemLabel,
        spokenText: spokenText,
      );
      await playNegativePointAudio();
      if (!_reduceMotion) {
        try {
          await HapticFeedback.heavyImpact();
          await HapticFeedback.vibrate();
        } catch (_) {
          // ignore: avoid_catches_without_on_clauses
        }
      }
    }
  }

  void unregisterItem(ItemComponent item) {
    final bool removed = _activeItems.remove(item);
    if (!removed) return;
    if (_activeItems.isEmpty) {
      if (_roundActive && timeLeft.value > 0) {
        _scheduleNextSpawn();
      }
    } else {
      _applyTouchAxisToLead();
    }
  }

  String _itemLabel(ItemType type) {
    switch (type) {
      case ItemType.papel:
        return 'Papel';
      case ItemType.metal:
        return 'Metal';
      case ItemType.vidro:
        return 'Vidro';
      case ItemType.plastico:
        return 'Plástico';
      case ItemType.organico:
        return 'Orgânico';
    }
  }

  Future<void> _playResiduoEffect() => _playSfx(_sfxResiduo);
  Future<void> _playPointEffect() => _playSfx(_sfxPoint);
  Future<void> _playNegative() => _playSfx(_sfxNegative);
  Future<void> _playClick() => _playSfx(_sfxClick);
  Future<void> _playEndGameSfx() {
    if (_endGameAudioPlayed) {
      return Future<void>.value();
    }
    _endGameAudioPlayed = true;
    return _playSfx(score.value > 0 ? _sfxEndPositive : _sfxEndNegative);
  }

  Future<void> playPositivePointAudio() => _playPointEffect();

  Future<void> playNegativePointAudio() => _playNegative();

  Future<void> playEndGameAudioIfNeeded() => _playEndGameSfx();

  Future<void> _playSfx(String asset, {double volume = 1.0}) async {
    if (!sfxEnabled.value) return;
    try {
      await ensureAudioUnlocked();
      await FlameAudio.play(asset, volume: volume);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Não foi possível tocar $asset: $e');
      }
    }
  }

  Future<void> _waitForAudioPreload() {
    _audioPreloadFuture ??= preloadAudio();
    return _audioPreloadFuture!;
  }

  Future<void> _unlockAudioInternal() async {
    await _waitForAudioPreload();
    AudioPlayer? player;
    try {
      player = await FlameAudio.play(_unlockAsset, volume: 0);
      _audioUnlocked = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Falha ao desbloquear áudio na Web: $e');
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

  void _spawnScoreDelta(
    int delta,
    Vector2 worldPosition, {
    String? label,
    required String spokenText,
  }) {
    if (!isMounted) return;

    final bool isPositive = delta >= 0;
    final String scoreText = delta > 0 ? '+$delta' : '$delta';
    final String safeLabel = (label == null || label.trim().isEmpty) ? '' : label.trim();
    String composed = scoreText;
    if (safeLabel.isNotEmpty) {
      composed = isPositive ? '$safeLabel $scoreText' : '$scoreText $safeLabel';
    }
    final double baseFont =
        (size.y * (isPositive ? 0.045 : 0.04)).clamp(13.0, 22.0).toDouble();
    final Color baseColor = isPositive ? Colors.white : const Color(0xFFE53935);

    final TextPaint paint = TextPaint(
      style: TextStyle(
        fontSize: baseFont,
        fontWeight: FontWeight.w900,
        color: baseColor,
        fontFamily: 'PressStart2P',
        shadows: const [
          Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 2)),
          Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
    );

    final floating = _FloatingScoreDelta(
      text: composed,
      textPaint: paint,
      start: worldPosition,
      travelDistance: _reduceMotion ? 18 : 28,
      duration: _reduceMotion ? 0.6 : 1.1,
      spokenText: spokenText,
      bounds: Vector2(size.x, size.y),
      icon: isPositive ? _successIcon : null,
    );

    _root.add(floating);
  }

  // =========================================================
  // Cleanup
  // =========================================================
  @override
  void onRemove() {
    _spawnTimer?.cancel();
    _spawnTimer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;

    score.dispose();
    timeLeft.dispose();
    residuosOrganicos.dispose();
    residuosReciclaveis.dispose();
    sfxEnabled.removeListener(_onSfxPreferenceChanged);
    sfxEnabled.dispose();

    super.onRemove();
  }
}

// ===========================================================
// Floating score/feedback visual
// ===========================================================
class _FloatingScoreDelta extends PositionComponent {
  _FloatingScoreDelta({
    required this.text,
    required this.textPaint,
    required Vector2 start,
    required this.travelDistance,
    required this.duration,
    required this.spokenText,
    required Vector2 bounds,
    Sprite? icon,
  })  : _start = start.clone(),
        _bounds = bounds,
        _label = NarrableTextComponent(
          text: text,
          textRenderer: textPaint,
          anchor: Anchor.center,
          spokenText: spokenText,
          tooltip: '',
          category: 'pontuacao',
          readOnShow: true,
        ),
        _iconSprite = icon,
        super(priority: 2000) {
    anchor = Anchor.center;
    if (_iconSprite != null) {
      _iconComponent = SpriteComponent(sprite: _iconSprite)
        ..anchor = Anchor.centerRight
        ..paint.filterQuality = FilterQuality.none;
      add(_iconComponent!);
      _label.anchor = Anchor.centerLeft;
      _label.position = Vector2(4, 0);
    }
    add(_label);
  }

  final String text;
  final TextPaint textPaint;
  final double travelDistance;
  final double duration;
  final String spokenText;

  final Vector2 _start;
  final Vector2 _bounds;
  final NarrableTextComponent _label;
  final Sprite? _iconSprite;
  SpriteComponent? _iconComponent;

  late final TextStyle _baseStyle = textPaint.style;
  late Vector2 _basePosition;
  double _elapsed = 0;
  double _iconWidthForClamp = 0;
  double _iconHeightForClamp = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _configureChildren();
    _basePosition = _clampStart(_start);
    position = _basePosition.clone();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    final double progress = (_elapsed / duration).clamp(0.0, 1.0);
    final double eased = Curves.easeOut.transform(progress);

    position = Vector2(_basePosition.x, _basePosition.y - travelDistance * eased);

    final Color baseColor = _baseStyle.color ?? Colors.white;
    final double opacity = (1.0 - progress).clamp(0.0, 1.0);
    final TextStyle nextStyle = _baseStyle.copyWith(color: baseColor.withOpacity(opacity));
    _label.textRenderer = TextPaint(style: nextStyle);

    if (progress >= 1.0) {
      removeFromParent();
    }
  }

  void _configureChildren() {
    if (_iconComponent == null) {
      _label.anchor = Anchor.center;
      _label.position = Vector2.zero();
      _iconWidthForClamp = 0;
      _iconHeightForClamp = 0;
      return;
    }

    final double baseFont = textPaint.style.fontSize ?? 16;
    final double iconSize = baseFont * 1.8;
    _iconComponent!
      ..size = Vector2(iconSize, iconSize)
      ..position = Vector2(-4, 0);

    _label.anchor = Anchor.centerLeft;
    _label.position = Vector2(4, 0);

    _iconWidthForClamp = iconSize + 8;
    _iconHeightForClamp = iconSize;
  }

  Vector2 _clampStart(Vector2 desired) {
    final TextStyle style = textPaint.style;
    final int lineCount = text.split('\n').length;
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: lineCount,
    )..layout();

    final double textW = painter.width;
    final double textH = painter.height;

    final double iconW = _iconComponent == null ? 0.0 : _iconWidthForClamp;
    final double iconH = _iconComponent == null ? 0.0 : _iconHeightForClamp;

    final double totalW = textW + iconW;
    final double totalH = max(textH, iconH);

    const double margin = 24.0;
    final double halfW = totalW / 2.0;
    final double halfH = totalH / 2.0;

    final double minX = margin + halfW;
    final double maxX = _bounds.x - margin - halfW;
    double x = desired.x.clamp(minX, maxX).toDouble();

    if (_iconComponent != null) {
      x = x.clamp(minX + iconW * 0.5, maxX);
    }

    final double topMinStart = margin + halfH + travelDistance;
    final double bottomMaxStart = _bounds.y - margin - halfH;
    final double y = desired.y.clamp(topMinStart, bottomMaxStart).toDouble();

    return Vector2(x, y);
  }
}
