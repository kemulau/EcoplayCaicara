import 'dart:math' as math;

import 'package:flutter/material.dart';

/// BookView
/// 
/// Um widget que exibe páginas em pares (esquerda/direita)
/// com visual de livro antigo e uma animação simples de virada
/// ao paginar via swipe/arrasto. Cada item da lista [pages]
/// representa UMA página (não um spread). O widget renderiza duas
/// por vez.
class BookView extends StatefulWidget {
  const BookView({
    super.key,
    required this.pages,
    this.controller,
    this.aspectRatio = 3 / 2,
    this.cornerRadius = 16,
    this.gutter = 16,
    this.pagePadding = const EdgeInsets.fromLTRB(18, 22, 18, 22),
    this.flipDuration = const Duration(milliseconds: 350),
    this.onSpreadChanged,
    this.allowUserScroll = true,
    this.backgroundColor,
  });

  /// Lista de páginas (cada item é UMA página). O componente mostra em pares.
  final List<Widget> pages;

  /// Controlador opcional para controlar a navegação de fora.
  final PageController? controller;

  /// Proporção Largura:Altura do livro aberto (spread). 3/2 funciona bem.
  final double aspectRatio;

  /// Raio dos cantos das páginas.
  final double cornerRadius;

  /// Largura do vinco central (miolo/gutter).
  final double gutter;

  /// Padding interno de cada página.
  final EdgeInsets pagePadding;

  /// Duração da animação ao usar next/previous programaticamente.
  final Duration flipDuration;

  /// Callback quando o índice do spread (par de páginas) muda.
  final ValueChanged<int>? onSpreadChanged;

  /// Permite scroll do usuário (gesto). Se falso, use os métodos do controller.
  final bool allowUserScroll;

  /// Cor base do papel. Se null, usa um tom de pergaminho.
  final Color? backgroundColor;

  @override
  State<BookView> createState() => _BookViewState();
}

class _BookViewState extends State<BookView> {
  late final PageController _controller =
      widget.controller ?? PageController(initialPage: 0, viewportFraction: 1);

  int get _spreadCount => (widget.pages.length + 1) >> 1; // ceil(length/2)

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.backgroundColor ?? const Color(0xFFF2E2C2);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Mantém uma proporção agradável (livro deitado).
        final width = constraints.maxWidth;
        final height = width / widget.aspectRatio;
        final boundedHeight = height.clamp(220.0, constraints.maxHeight);

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: width,
              // não expande além do disponível, mas tenta manter a proporção
              maxHeight: boundedHeight,
            ),
            child: AspectRatio(
              aspectRatio: widget.aspectRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.cornerRadius + 6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    // Moldura externa leve para dar cara de capa
                    color: Color.alphaBlend(
                      Colors.brown.withOpacity(0.10),
                      color,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final page = _pageValueSafe(_controller);
                      return PageView.builder(
                        controller: _controller,
                        physics: widget.allowUserScroll
                            ? const BouncingScrollPhysics()
                            : const NeverScrollableScrollPhysics(),
                        itemCount: _spreadCount,
                        onPageChanged: widget.onSpreadChanged,
                        itemBuilder: (context, index) {
                          final delta = page - index;
                          return _BookSpread(
                            left: _pageOrPlaceholder(2 * index),
                            right: _pageOrPlaceholder(2 * index + 1),
                            gutter: widget.gutter,
                            cornerRadius: widget.cornerRadius,
                            pagePadding: widget.pagePadding,
                            paperColor: color,
                            // Progresso de virada deduzido do deslocamento da PageView
                            leftTurn: _leftTurnFor(delta),
                            rightTurn: _rightTurnFor(delta),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Retorna um widget de página ou um placeholder vazio (caso de páginas ímpares).
  Widget _pageOrPlaceholder(int index) {
    if (index < 0 || index >= widget.pages.length) {
      return const SizedBox.shrink();
    }
    return widget.pages[index];
  }

  // Captura segura do valor da PageController.page sem travar antes de layout.
  double _pageValueSafe(PageController controller) {
    try {
      if (!controller.hasClients || !controller.position.haveDimensions) {
        return controller.initialPage.toDouble();
      }
      return controller.page ?? controller.initialPage.toDouble();
    } catch (_) {
      return controller.initialPage.toDouble();
    }
  }

  // Ângulos (em radianos) reduzidos para 0..pi/2 a fim de simular virada
  // de meia folha. Esses valores são consumidos pelo _BookSpread.
  double _rightTurnFor(double delta) {
    // Ao avançar para o próximo spread, o item atual (delta>0) gira a página direita.
    final progress = delta.clamp(0.0, 1.0);
    return -math.pi / 2 * progress;
  }

  double _leftTurnFor(double delta) {
    // Quando o spread está vindo da direita (delta<0), a página esquerda finaliza a virada.
    final progress = (-delta).clamp(0.0, 1.0);
    return math.pi / 2 * progress;
  }
}

/// Responsável por pintar o par de páginas com o efeito de virada parcial.
class _BookSpread extends StatelessWidget {
  const _BookSpread({
    required this.left,
    required this.right,
    required this.gutter,
    required this.cornerRadius,
    required this.pagePadding,
    required this.paperColor,
    required this.leftTurn,
    required this.rightTurn,
  });

  final Widget left;
  final Widget right;
  final double gutter;
  final double cornerRadius;
  final EdgeInsets pagePadding;
  final Color paperColor;
  final double leftTurn; // 0..pi/2 (positivo)
  final double rightTurn; // 0..-pi/2 (negativo)

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.black.withOpacity(0.06),
            Colors.transparent,
            Colors.black.withOpacity(0.06),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PaperPage(
              alignment: Alignment.centerRight,
              angleY: leftTurn, // gira ao entrar da direita
              cornerRadius: cornerRadius,
              padding: pagePadding.copyWith(
                right: pagePadding.right + gutter / 2,
              ),
              paperColor: paperColor,
              child: left,
            ),
          ),
          _Gutter(width: gutter),
          Expanded(
            child: _PaperPage(
              alignment: Alignment.centerLeft,
              angleY: rightTurn, // gira ao sair para a esquerda
              cornerRadius: cornerRadius,
              padding: pagePadding.copyWith(
                left: pagePadding.left + gutter / 2,
              ),
              paperColor: paperColor,
              child: right,
            ),
          ),
        ],
      ),
    );
  }
}

class _Gutter extends StatelessWidget {
  const _Gutter({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.black.withOpacity(0.12),
              Colors.black.withOpacity(0.06),
              Colors.black.withOpacity(0.12),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }
}

class _PaperPage extends StatelessWidget {
  const _PaperPage({
    required this.child,
    required this.angleY,
    required this.alignment,
    required this.cornerRadius,
    required this.padding,
    required this.paperColor,
  });

    // Conteúdo da página
  final Widget child;
  // Rotação em Y (radianos). Positivo = gira para trás em torno do lado direito.
  final double angleY;
  // Alinhamento da dobra (right para página esquerda, left para página direita)
  final Alignment alignment;
  final double cornerRadius;
  final EdgeInsets padding;
  final Color paperColor;

  @override
  Widget build(BuildContext context) {
    // Leve perspectiva para dar aspecto 3D.
    final m = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..rotateY(angleY);

    final lightSide = angleY.abs() > 0.001;

    return Transform(
      alignment: alignment,
      transform: m,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cornerRadius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: paperColor,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(Colors.brown.withOpacity(0.05), paperColor),
                Color.alphaBlend(Colors.black.withOpacity(0.03), paperColor),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(
              color: Colors.brown.withOpacity(0.18),
              width: 1.2,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: padding,
                child: DefaultTextStyle(
                  style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(height: 1.35, color: Colors.brown.shade900) ??
                      TextStyle(height: 1.35, color: Colors.brown.shade900),
                  child: child,
                ),
              ),
              // Um brilho leve no lado oposto para sugerir volume
              if (lightSide)
                Align(
                  alignment: alignment == Alignment.centerLeft
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: IgnorePointer(
                    child: Container(
                      width: 28,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: alignment == Alignment.centerLeft
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          end: alignment == Alignment.centerLeft
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          colors: [
                            Colors.black.withOpacity(0.12),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Conveniência: uma página simples de texto com rolagem interna.
class BookTextPage extends StatelessWidget {
  const BookTextPage(
    this.text, {
    super.key,
    this.textAlign = TextAlign.justify,
  });

  final String text;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    // Sem rolagem: o conteúdo extra fica oculto; a navegação é por página.
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      primary: false,
      child: Text(text, textAlign: textAlign),
    );
  }
}
