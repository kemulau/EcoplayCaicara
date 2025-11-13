import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../screens/games/missao-reciclagem/missao_reciclagem_game.dart';
import '../screens/games/toca-do-caranguejo/flame_game.dart';

class AssetCache {
  static const List<String> _criticalAssets = <String>[
    // Cards & moldura
    'cards/toca-do-caranguejo.jpg',
    'cards/missao-reciclar.jpg',
    'cards/mare-responsa.jpg',
    'cards/trilha-da-fauna.jpg',
    'cards/moldura.png',
    // Toca do Caranguejo
    'games/toca-do-caranguejo/caranguejo.png',
    'games/toca-do-caranguejo/residuo-caixa.png',
    'games/toca-do-caranguejo/lata.png',
    'games/toca-do-caranguejo/pet-sob-areia.png',
    'games/toca-do-caranguejo/cordas.png',
    'games/toca-do-caranguejo/residuo-isopor-boiando.png',
    'games/toca-do-caranguejo/residuo-madeira-musgo.png',
    'games/toca-do-caranguejo/pergaminho-aberto-3.png',
    'games/toca-do-caranguejo/pergaminho-entreaberto-2.png',
    'games/toca-do-caranguejo/pergaminho-fechado-1.png',
    // Missão Reciclagem
    'games/missao-reciclagem/papelao.png',
    'games/missao-reciclagem/garrafa-pet.png',
    'games/missao-reciclagem/garrafa-vidro.png',
    'games/missao-reciclagem/latinha.png',
    'games/missao-reciclagem/casca-banana.png',
    'games/missao-reciclagem/papel.png',
    'games/missao-reciclagem/plastico.png',
    'games/missao-reciclagem/metal.png',
    'games/missao-reciclagem/vidro.png',
    'games/missao-reciclagem/organico.png',
  ];

  static bool _configured = false;
  static bool _warmUpStarted = false;
  static Future<void>? _warmUpFuture;
  static Map<String, dynamic>? _assetManifest;
  static Future<Map<String, dynamic>>? _manifestFuture;
  static const List<String> _imagePrefixes = <String>[
    'cards/',
    'images/',
    'games/toca-do-caranguejo/',
    'games/missao-reciclagem/',
  ];
  static const List<String> _imageExtensions = <String>[
    '.png',
    '.jpg',
    '.jpeg',
    '.webp',
  ];

  static Future<void> warmUp() async {
    if (_warmUpStarted) {
      if (_warmUpFuture != null) {
        await _warmUpFuture;
      }
      return;
    }
    _warmUpStarted = true;
    final cache = PaintingBinding.instance.imageCache;
    if (!_configured) {
      cache.maximumSizeBytes = 256 * 1024 * 1024; // 256 MB
      cache.maximumSize = 800;
      _configured = true;
    }

    Future<List<String>> bulkImagesFuture = _resolveBulkImageAssets();

    _warmUpFuture = Future.wait<void>([
      ..._criticalAssets.map(_precacheAsset),
      bulkImagesFuture.then(
        (assets) => Future.wait<void>(assets.map(_precacheAsset)),
      ),
      CrabGame.preloadAssets(),
      MissaoReciclagemGame.preloadAssets(),
    ]).catchError((_) {});

    await _warmUpFuture;
  }

  static String _normalizeKey(String assetPath) {
    String normalized = assetPath;
    while (normalized.startsWith('assets/')) {
      normalized = normalized.substring(7);
    }
    while (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }
    return normalized;
  }

  static String _assetPath(String assetPath) =>
      'assets/${_normalizeKey(assetPath)}';

  static List<String> _assetCandidates(String assetPath) {
    final String normalized = _normalizeKey(assetPath);
    final Set<String> paths = <String>{
      'assets/$normalized',
      'assets/assets/$normalized',
    };
    return paths.toList(growable: false);
  }

  static Future<void> _precacheAsset(String assetPath) async {
    for (final candidate in _assetCandidates(assetPath)) {
      final bool ok = await _tryPrecacheCandidate(candidate);
      if (ok) return;
    }
  }

  static Future<bool> _tryPrecacheCandidate(String candidate) async {
    final image = AssetImage(candidate);
    final ImageStream stream = image.resolve(ImageConfiguration.empty);
    final Completer<bool> completer = Completer<bool>();
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool sync) {
        if (!completer.isCompleted) completer.complete(true);
        stream.removeListener(listener);
      },
      onError: (Object _, StackTrace? __) {
        if (!completer.isCompleted) completer.complete(false);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  static Future<List<String>> _resolveBulkImageAssets() async {
    final Map<String, dynamic> manifest = await _loadManifest();
    final Set<String> filtered = <String>{};
    for (final String assetPath in manifest.keys.whereType<String>()) {
      if (!_hasSupportedExtension(assetPath)) continue;
      if (!_matchesPrefix(assetPath)) continue;
      filtered.add(assetPath);
    }
    // Já vamos evitar reprecisar imagens críticas
    filtered.removeWhere(_isCriticalAsset);
    return filtered.toList(growable: false);
  }

  static bool _hasSupportedExtension(String assetPath) {
    final lower = assetPath.toLowerCase();
    return _imageExtensions.any(lower.endsWith);
  }

  static bool _matchesPrefix(String assetPath) {
    final String normalized = _normalizeKey(assetPath);
    for (final prefix in _imagePrefixes) {
      if (normalized.startsWith(prefix)) return true;
    }
    return false;
  }

  static bool _isCriticalAsset(String assetPath) {
    final String normalized = _normalizeKey(assetPath);
    return _criticalAssets.contains(normalized);
  }

  static Future<Map<String, dynamic>> _loadManifest() {
    if (_assetManifest != null) {
      return Future<Map<String, dynamic>>.value(_assetManifest);
    }
    _manifestFuture ??= rootBundle.loadString('AssetManifest.json').then((raw) {
      final Map<String, dynamic> manifest =
          json.decode(raw) as Map<String, dynamic>;
      _assetManifest = manifest;
      return manifest;
    });
    return _manifestFuture!;
  }
}
