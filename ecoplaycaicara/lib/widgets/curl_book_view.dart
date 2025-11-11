import 'package:flutter/material.dart';
import 'package:page_flip/page_flip.dart';

/// CurlBookView
///
/// Envelopa o PageFlipWidget com um visual de livro antigo.
/// Forneça uma lista de [pages] (cada item é uma página) e o
/// componente aplica o estilo de "pergaminho" e moldura de livro.
class CurlBookView extends StatefulWidget {
  const CurlBookView({
    super.key,
    required this.pages,
    this.aspectRatio = 3 / 2,
    this.cornerRadius = 16,
    this.gutter = 18,
    this.pagePadding = const EdgeInsets.fromLTRB(6, 8, 6, 8),
    this.backgroundColor,
    this.outerPadding = const EdgeInsets.all(1),
    this.flipKey, // <<< permite controlar o PageFlip de fora
    // --------- NOVOS PARÂMETROS (opcionais / compatíveis) ----------
    this.autoAspect = true,                 // alterna AR em portrait
    this.portraitAspectRatio = 3 / 4,       // AR usado quando "em pé"
    this.edgeTapWidthFraction = 0.33,       // faixa lateral de toque
    this.onPageChanged,
  });

  final List<Widget> pages;
  final double aspectRatio;
  final double cornerRadius;

  /// Largura do vinco central (gutter) em px.
  final double gutter;

  final EdgeInsets pagePadding;
  final Color? backgroundColor;

  /// Pequena borda externa entre o livro e o fundo branco do painel.
  final EdgeInsets outerPadding;

  /// (Opcional) GlobalKey do PageFlipWidget para permitir chamadas externas como
  /// flipKey.currentState?.goToPage(index), nextPage(), previousPage(), etc.
  final GlobalKey<PageFlipWidgetState>? flipKey;

  /// Se true (padrão), usa [portraitAspectRatio] quando a área disponível
  /// for mais alta que larga (portrait).
  final bool autoAspect;

  /// Aspect ratio usado em portrait quando [autoAspect] = true.
  final double portraitAspectRatio;

  /// Fração (0–1) da largura, em cada lateral, que responde a toque
  /// para voltar/avançar. Padrão 0.33 (33%).
  final double edgeTapWidthFraction;

  final ValueChanged<int>? onPageChanged;

  @override
  State<CurlBookView> createState() => _CurlBookViewState();
}

class _CurlBookViewState extends State<CurlBookView> {
  late final GlobalKey<PageFlipWidgetState> _flipKey;

  @override
  void initState() {
    super.initState();
    _flipKey = widget.flipKey ?? GlobalKey<PageFlipWidgetState>();
  }

  @override
  Widget build(BuildContext context) {
    final Color paper = widget.backgroundColor ?? const Color(0xFFF2E2C2);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Espaço útil menos a borda externa desejada
        final availW = constraints.maxWidth - widget.outerPadding.horizontal;
        final availH = constraints.maxHeight - widget.outerPadding.vertical;

        // Aspect ratio adaptativo em portrait (opcional)
        final bool portrait = availH >= availW;
        final double targetAR = (widget.autoAspect && portrait)
            ? widget.portraitAspectRatio
            : widget.aspectRatio;

        // Calcula largura/altura máximas respeitando a proporção para ocupar
        // praticamente todo o painel (apenas uma pequena borda).
        double w = availW;
        double h = w / targetAR;
        if (h > availH) {
          h = availH;
          w = h * targetAR;
        }

        final double edgeFrac =
            widget.edgeTapWidthFraction.clamp(0.05, 0.5); // sanidade

        return Padding(
          padding: widget.outerPadding,
          child: Center(
            child: SizedBox(
              width: w,
              height: h,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.cornerRadius + 6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                      Colors.brown.withOpacity(0.12),
                      paper,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Vinco central para o miolo do livro
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _CenterGutterPainter(
                            color: Colors.black.withOpacity(0.18),
                            gutterWidth: widget.gutter, // <<< usa prop real
                          ),
                        ),
                      ),

                      // PageFlip com camada de repaint boundary (perf)
                      RepaintBoundary(
                        child: PageFlipWidget(
                          key: _flipKey,
                          backgroundColor: Colors.transparent,
                          onPageFlipped: widget.onPageChanged,
                          children: [
                            for (final p in widget.pages)
                              _Paper(
                                paper: paper,
                                padding: widget.pagePadding,
                                radius: widget.cornerRadius,
                                child: p,
                              ),
                          ],
                          lastPage: _Paper(
                            paper: paper,
                            padding: widget.pagePadding,
                            radius: widget.cornerRadius,
                            child: const Center(
                              child: Text(
                                'Fim',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Overlay para toques (qualquer toque vira página; toque na esquerda volta)
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTapUp: (details) {
                            final local = details.localPosition;
                            final leftBand = w * edgeFrac;
                            final rightBand = w * (1 - edgeFrac);
                            if (local.dx < leftBand) {
                              _flipKey.currentState?.previousPage();
                            } else if (local.dx > rightBand) {
                              _flipKey.currentState?.nextPage();
                            } else {
                              // região central: avanço (mantém o hábito do usuário)
                              _flipKey.currentState?.nextPage();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Paper extends StatelessWidget {
  const _Paper({
    required this.child,
    required this.paper,
    required this.padding,
    required this.radius,
  });

  final Widget child;
  final Color paper;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: paper,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(Colors.brown.withOpacity(0.05), paper),
              Color.alphaBlend(Colors.black.withOpacity(0.03), paper),
            ],
          ),
          border: Border.all(
            color: Colors.brown.withOpacity(0.2),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.16),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: padding,
          child: DefaultTextStyle(
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.35,
                      color: Colors.brown.shade900,
                    ) ??
                TextStyle(height: 1.35, color: Colors.brown.shade900),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _CenterGutterPainter extends CustomPainter {
  const _CenterGutterPainter({
    required this.color,
    this.gutterWidth = 20, // <<< NOVO: padrão compatível
  });

  final Color color;
  final double gutterWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final half = gutterWidth / 2;
    final rect = Rect.fromLTWH(x - half, 0, gutterWidth, size.height);

    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Colors.transparent, Colors.black54, Colors.transparent],
        stops: [0.0, 0.5, 1.0],
      ).createShader(rect)
      ..color = color.withOpacity(0.10);

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _CenterGutterPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.gutterWidth != gutterWidth;
}
