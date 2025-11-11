import 'package:flutter/material.dart';
import 'flame_game.dart';

class DebugBurrowsOverlay extends StatelessWidget {
  const DebugBurrowsOverlay(this.game, {super.key});
  final CrabGame game;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final sx = w / game.size.x;
          final sy = h / game.size.y;
          return CustomPaint(
            size: Size.infinite,
            painter: _BurrowsPainter(
              burrows: game.burrows,
              burrowMinY: game.burrowMinYWorld,
              roiY0: game.roiY0World,
              roiY1: game.roiY1World,
              crabRect: game.crabRect,
              sx: sx,
              sy: sy,
            ),
          );
        },
      ),
    );
  }
}

class _BurrowsPainter extends CustomPainter {
  _BurrowsPainter({
    required this.burrows,
    required this.burrowMinY,
    required this.roiY0,
    required this.roiY1,
    required this.crabRect,
    required this.sx,
    required this.sy,
  });

  final List<Offset> burrows;
  final double burrowMinY;
  final double roiY0;
  final double roiY1;
  final Rect crabRect;
  final double sx;
  final double sy;

  @override
  void paint(Canvas canvas, Size size) {
    // Header com contagem
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Tocas: ${burrows.length} / 17',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.drawRect(
      Rect.fromLTWH(8, 8, textPainter.width + 12, textPainter.height + 8),
      Paint()..color = const Color(0xAA000000),
    );
    textPainter.paint(canvas, const Offset(14, 12));

    // Linha limite das tocas
    final linePaint = Paint()
      ..color = Colors.amberAccent
      ..strokeWidth = 2.5;
    final y = burrowMinY * sy;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);

    // Faixa ROI
    final roiPaint = Paint()
      ..color = const Color(0x55FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final ry0 = roiY0 * sy;
    final ry1 = roiY1 * sy;
    canvas.drawLine(Offset(0, ry0), Offset(size.width, ry0), roiPaint);
    canvas.drawLine(Offset(0, ry1), Offset(size.width, ry1), roiPaint);

    // Marcadores de tocas
    final fill = Paint()..color = Colors.redAccent.withOpacity(0.9);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white;

    const double r = 8.0; // raio do marcador
    final tpStyle = TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold);
    for (int i = 0; i < burrows.length; i++) {
      final p = Offset(burrows[i].dx * sx, burrows[i].dy * sy);
      canvas.drawCircle(p, r, fill);
      canvas.drawCircle(p, r, stroke);
      // cruzeta
      canvas.drawLine(Offset(p.dx - r, p.dy), Offset(p.dx + r, p.dy), stroke);
      canvas.drawLine(Offset(p.dx, p.dy - r), Offset(p.dx, p.dy + r), stroke);
      // índice
      final tp = TextPainter(
        text: TextSpan(text: '#$i', style: tpStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p + const Offset(10, -10));
    }

    // Retângulo do caranguejo
    final crab = Rect.fromLTWH(
      crabRect.left * sx,
      crabRect.top * sy,
      crabRect.width * sx,
      crabRect.height * sy,
    );
    final crabPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.limeAccent;
    canvas.drawRect(crab, crabPaint);
  }

  @override
  bool shouldRepaint(covariant _BurrowsPainter oldDelegate) {
    return oldDelegate.burrows != burrows ||
        oldDelegate.burrowMinY != burrowMinY ||
        oldDelegate.roiY0 != roiY0 ||
        oldDelegate.roiY1 != roiY1 ||
        oldDelegate.crabRect != crabRect ||
        oldDelegate.sx != sx ||
        oldDelegate.sy != sy;
  }
}
