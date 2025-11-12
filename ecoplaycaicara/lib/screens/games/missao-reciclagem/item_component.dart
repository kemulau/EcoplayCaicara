import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/input.dart';
import 'package:flutter/services.dart';

import 'bin_component.dart';
import 'missao_reciclagem_game.dart';

enum ItemType { papel, metal, vidro, plastico, organico }

class ItemControlProfile {
  const ItemControlProfile({
    required this.maxSpeed,
    required this.targetBlend,
    required this.snapDistance,
  });

  final double maxSpeed;
  final double targetBlend;
  final double snapDistance;
}

ItemType? itemTypeFromAsset(String assetPath) {
  final String name = assetPath.split('/').last.toLowerCase();
  if (name.contains('papelao') || name.contains('papel')) {
    return ItemType.papel;
  }
  if (name.contains('latinha') ||
      name.contains('lata') ||
      name.contains('metal')) {
    return ItemType.metal;
  }
  if (name.contains('vidro')) {
    return ItemType.vidro;
  }
  if (name.contains('pet') || name.contains('plastico')) {
    return ItemType.plastico;
  }
  if (name.contains('banana') || name.contains('organico')) {
    return ItemType.organico;
  }
  return null;
}

class ItemComponent extends SpriteComponent
    with
        CollisionCallbacks,
        KeyboardHandler,
        TapCallbacks,
        HasGameRef<MissaoReciclagemGame> {
  ItemComponent({
    required this.type,
    required Sprite sprite,
    required Vector2 start,
    required double fallSpeed,
    required this.leftClamp,
    required this.rightClamp,
    required this.groundLineY,
    required ItemControlProfile controlProfile,
  }) : _baseVy = fallSpeed,
       _vy = fallSpeed,
       _controlProfile = controlProfile,
       super(
         sprite: sprite,
         position: start,
         size: Vector2(72, 72),
         anchor: Anchor.center,
         priority: 5,
       );

  final ItemType type;
  double leftClamp;
  double rightClamp;
  double groundLineY;

  ItemControlProfile _controlProfile;

  double get _maxSpeed => _controlProfile.maxSpeed;
  double get _targetBlend => _controlProfile.targetBlend;
  double get _snapDistance => _controlProfile.snapDistance;

  final double _blendSpeed = 6;

  final double _baseVy;
  double _vy;
  double _vx = 0;
  double _keyboardAxis = 0;
  double _touchAxis = 0;

  double? _targetX;
  bool reduceMotion = false;
  bool _collected = false;

  double get _combinedAxis =>
      (_keyboardAxis + _touchAxis).clamp(-1, 1).toDouble();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox(collisionType: CollisionType.active));
  }

  @override
  void update(double dt) {
    super.update(dt);
    final double blend = max(0, min(1, dt * _blendSpeed));
    final double inputAxis = _combinedAxis;
    final double desired = inputAxis * _maxSpeed;
    _vx += (desired - _vx) * blend;

    if (_targetX != null) {
      final double clamped = _targetX!.clamp(leftClamp, rightClamp);
      final double delta = clamped - position.x;
      if (delta.abs() < _snapDistance) {
        _targetX = null;
        if (inputAxis.abs() < 0.1) {
          _vx *= 0.6;
        }
      } else {
        final double targetVel = delta.clamp(-_maxSpeed, _maxSpeed).toDouble();
        final double tBlend = max(0, min(1, dt * _targetBlend));
        _vx += (targetVel - _vx) * tBlend;
      }
    }

    position.x = (position.x + _vx * dt).clamp(leftClamp, rightClamp);
    position.y += _vy * dt;

    double landingLine = groundLineY;
    if (!landingLine.isFinite) {
      final double fallback = gameRef.groundLineY;
      if (fallback.isFinite) {
        landingLine = fallback;
        groundLineY = landingLine;
      }
    }

    if (!_collected && landingLine.isFinite && position.y >= landingLine) {
      position.y = landingLine;
      _collected = true;
      final bool nearCatch = gameRef.isWithinCatchMargin(this);
      gameRef.unregisterItem(this);
      gameRef.resolveItem(
        item: this,
        correct: nearCatch,
        failureReason: nearCatch ? null : ItemFailureReason.missed,
      );
      removeFromParent();
      return;
    }

    if (position.y - size.y / 2 > gameRef.size.y + 80) {
      removeFromParent();
    }
  }

  void applyControlProfile(ItemControlProfile profile) {
    _controlProfile = profile;
  }

  void setTouchAxis(double axis) {
    final double clamped = axis.clamp(-1, 1).toDouble();
    if ((_touchAxis - clamped).abs() < 0.001) return;
    _touchAxis = clamped;
    if (clamped.abs() > 0) {
      _targetX = null;
    }
  }

  void setTargetX(double x) {
    if (!x.isFinite) return;
    _targetX = x.clamp(leftClamp, rightClamp);
  }

  void updateGroundLine(double value) {
    if (!value.isFinite) return;
    groundLineY = value;
  }

  void updateBounds(double left, double right) {
    if (!left.isFinite || !right.isFinite || right <= left) return;
    leftClamp = left;
    rightClamp = right;
    position.x = position.x.clamp(leftClamp, rightClamp);
    if (_targetX != null) {
      _targetX = _targetX!.clamp(leftClamp, rightClamp);
    }
  }

  void updateReduceMotion(bool value) {
    if (reduceMotion == value) return;
    reduceMotion = value;
    _vy = value ? _baseVy * 0.75 : _baseVy;
  }

  @override
  void onTapDown(TapDownEvent event) {
    setTargetX(gameRef.globalToWorldX(event.devicePosition));
    event.handled = true;
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    double axis = 0;
    if (keysPressed.contains(LogicalKeyboardKey.arrowLeft) ||
        keysPressed.contains(LogicalKeyboardKey.keyA)) {
      axis -= 1;
    }
    if (keysPressed.contains(LogicalKeyboardKey.arrowRight) ||
        keysPressed.contains(LogicalKeyboardKey.keyD)) {
      axis += 1;
    }
    _keyboardAxis = axis.clamp(-1, 1).toDouble();
    if (_keyboardAxis.abs() > 0) {
      _targetX = null;
    }
    return axis != 0;
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (_collected) return;

    if (other is BinComponent) {
      _collected = true;
      final bool matches = other.matches(type);
      if (!matches) {
        gameRef.notifyWrongBinDrop(other);
      }
      gameRef.unregisterItem(this);
      gameRef.resolveItem(
        item: this,
        correct: matches,
        failureReason: matches ? null : ItemFailureReason.wrongBin,
      );
      removeFromParent();
    }
  }

  @override
  void onRemove() {
    gameRef.unregisterItem(this);
    super.onRemove();
  }
}
