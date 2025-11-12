import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import 'item_component.dart';

enum BinType { papel, metal, vidro, plastico, organico }

/// Representa uma lixeira no cenário. Atua como alvo para colisões dos itens.
/// OBS: Quem manda no tamanho é o Game (_applyBinSizing).
/// Este componente **não** recalcula o size se ele já tiver sido definido pelo Game.
/// Apenas define um tamanho inicial defensivo quando size ainda é zero.
class BinComponent extends SpriteComponent with CollisionCallbacks {
  BinComponent({
    required this.type,
    required Sprite sprite,
    required Vector2 position,
    Vector2? size,
  }) : super(
          sprite: sprite,
          position: position,
          // tamanho será definido pelo Game; se vier nulo, definimos um inicial no onGameResize
          size: size ?? Vector2.zero(),
          anchor: Anchor.bottomCenter,
          priority: 2,
        );

  final BinType type;

  // ===== Config básica para um tamanho inicial defensivo =====
  static int totalBinsInRow = 5;     // nº de lixeiras na fileira
  static const double _minSide = 50; // lado mínimo
  static const double _maxSide = 96; // teto de lado inicial (o Game pode reduzir/depois)
  static const double _targetGap = 6; // espaçamento desejado entre lixeiras
  static const double _hMarginPct = 0.03; // margem horizontal (~3%)

  /// Permite o Game forçar explicitamente um lado.
  void setSide(double side) {
    size = Vector2.all(side.clamp(_minSide, _maxSide));
  }

  /// Mapeia 1:1 tipo da lixeira ↔ tipo de item.
  bool matches(ItemType itemType) => itemType == _asItemType(type);

  static ItemType _asItemType(BinType b) {
    switch (b) {
      case BinType.papel:
        return ItemType.papel;
      case BinType.metal:
        return ItemType.metal;
      case BinType.vidro:
        return ItemType.vidro;
      case BinType.plastico:
        return ItemType.plastico;
      case BinType.organico:
        return ItemType.organico;
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Hitbox acompanha o size do componente automaticamente.
    add(RectangleHitbox(isSolid: true, collisionType: CollisionType.passive));
  }

  /// Define um tamanho inicial apenas se ainda não houver size definido.
  /// Evita "briga" com o cálculo de layout do Game.
  @override
  void onGameResize(Vector2 gameSize) {
    super.onGameResize(gameSize);

    // Se o Game já definiu (ou vai definir) o size, não mexe.
    if (size.x > 0 && size.y > 0) return;

    final double marginX = gameSize.x * _hMarginPct;
    final double available = (gameSize.x - marginX * 2).clamp(0, double.infinity);

    final int n = totalBinsInRow.clamp(1, 12);
    final double rawSide = (available - _targetGap * (n - 1)) / n;

    final double side = rawSide.clamp(_minSide, _maxSide);
    size = Vector2.all(side);
  }
}
