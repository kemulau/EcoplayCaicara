import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:page_flip/page_flip.dart';

import '/widgets/curl_book_view.dart';
import '/widgets/book_view.dart';
import '/theme/theme_provider.dart';
import '/theme/book_theme.dart';

class LivroDoMangueScreen extends StatefulWidget {
  const LivroDoMangueScreen({super.key});

  @override
  State<LivroDoMangueScreen> createState() => _LivroDoMangueScreenState();
}

class _LivroDoMangueScreenState extends State<LivroDoMangueScreen> {
  BookTheme _paletteOf(BuildContext context) =>
      Theme.of(context).extension<BookTheme>() ?? BookTheme.standard;

  final GlobalKey<PageFlipWidgetState> _flipKey =
      GlobalKey<PageFlipWidgetState>();
  PageController? _pageController;

  final FocusNode _focusNode = FocusNode();
  int _currentPage = 0;
  int _currentSpread = 0;
  int _pageCount = 0;
  DateTime? _lastNavigation;

  static const Duration _navigationThrottle = Duration(milliseconds: 260);

  bool get _isReduceMotion => context.read<ThemeProvider>().reduceMotion;

  static const int _pgCapa = 0;
  static const int _pgMenu = 1;
  static const int _pgCaranguejo = 2;
  static const int _pgGuara = 3;
  static const int _pgMangue = 4;
  static const int _pgResiduos = 5;

  void _goTo(int index) {
    if (_pageCount == 0) return;
    final int clamped = _clampPage(index);

    if (_isReduceMotion) {
      final controller = _pageController;
      if (controller == null) return;
      final int targetSpread = clamped ~/ 2;
      if (controller.hasClients) {
        controller.animateToPage(
          targetSpread,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctrl = _pageController;
          if (!mounted || ctrl == null || !ctrl.hasClients) return;
          ctrl.animateToPage(
            targetSpread,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
          );
        });
      }
    } else {
      _flipKey.currentState?.goToPage(clamped);
    }

    _registerNavigation(clamped);
  }

  int _clampPage(int value) {
    if (_pageCount <= 0) return 0;
    if (value <= 0) return 0;
    if (value >= _pageCount) return _pageCount - 1;
    return value;
  }

  void _registerNavigation(int pageIndex) {
    final int clamped = _clampPage(pageIndex);
    _lastNavigation = DateTime.now();
    final int clampedSpread = clamped ~/ 2;
    if (_currentPage == clamped && _currentSpread == clampedSpread) {
      return;
    }
    setState(() {
      _currentPage = clamped;
      _currentSpread = clampedSpread;
    });
  }

  void _onCurlPageChanged(int index) {
    if (!mounted || _pageCount == 0) return;
    _registerNavigation(index);
  }

  void _handleSpreadChanged(int spread) {
    if (_pageCount == 0) return;
    final int spreadCount = (_pageCount + 1) >> 1;
    int clamped = spread;
    if (clamped < 0) {
      clamped = 0;
    } else if (clamped >= spreadCount) {
      clamped = spreadCount - 1;
    }

    final int pageIndex = _clampPage(clamped * 2);
    _lastNavigation = DateTime.now();
    if (_currentSpread == clamped && _currentPage == pageIndex) {
      return;
    }
    setState(() {
      _currentSpread = clamped;
      _currentPage = pageIndex;
    });
  }

  void _navigateRelative(int direction) {
    if (direction == 0 || _pageCount == 0) return;
    final DateTime now = DateTime.now();
    if (_lastNavigation != null &&
        now.difference(_lastNavigation!) < _navigationThrottle) {
      return;
    }

    if (_isReduceMotion) {
      final controller = _pageController;
      if (controller == null) return;
      final int spreadCount = (_pageCount + 1) >> 1;
      int targetSpread = _currentSpread + direction;
      if (targetSpread < 0) {
        targetSpread = 0;
      } else if (targetSpread >= spreadCount) {
        targetSpread = spreadCount - 1;
      }
      if (targetSpread == _currentSpread) return;
      if (controller.hasClients) {
        controller.animateToPage(
          targetSpread,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctrl = _pageController;
          if (!mounted || ctrl == null || !ctrl.hasClients) return;
          ctrl.animateToPage(
            targetSpread,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
        });
      }
      _lastNavigation = now;
    } else {
      if (direction > 0) {
        _flipKey.currentState?.nextPage();
      } else {
        _flipKey.currentState?.previousPage();
      }
      _lastNavigation = now;
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.pageDown ||
        key == LogicalKeyboardKey.space) {
      _navigateRelative(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.pageUp ||
        key == LogicalKeyboardKey.backspace) {
      _navigateRelative(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final Offset delta = event.scrollDelta;
    final double vertical = delta.dy.abs();
    final double horizontal = delta.dx.abs();
    final double dominant = vertical >= horizontal ? delta.dy : delta.dx;
    if (dominant.abs() < 4) return;
    _navigateRelative(dominant > 0 ? 1 : -1);
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool portrait = size.height >= size.width;
    const double portraitAr = 0.68;
    const double landscapeAr = 1.38;
    final double ar = portrait ? portraitAr : landscapeAr;

    final pages = <Widget>[
      _buildCapa(context), // 0
      _buildMenuCartas(context), // 1
      _paginaEducativa(
        context,
        titulo: 'Caranguejo-uçá',
        subtitulo: 'Ucides cordatus — símbolo do manguezal',
        corpo: const [
          'Habita tocas no sedimento do manguezal, reciclador de matéria orgânica.',
          'Respeite período de defeso e tamanho mínimo para manejo sustentável.',
          'Coleta responsável mantém o equilíbrio ecológico e a renda local.',
        ],
        imagemAsset: 'assets/games/toca-do-caranguejo/caranguejo.png',
      ),
      _paginaEducativa(
        context,
        titulo: 'Guará-vermelho',
        subtitulo: 'Eudocimus ruber — ave icônica do litoral',
        corpo: const [
          'Vermelho intenso pela dieta rica em carotenoides.',
          'Vive em bandos; usa manguezais e ilhas para descanso e ninho.',
          'Proteger o habitat é vital às rotas de alimentação e reprodução.',
        ],
        imagemAsset: 'assets/games/toca-do-caranguejo/guara-aberto-1.png',
        fallbackAsset: 'assets/games/toca-do-caranguejo/guara-aberto-1.png',
      ),
      _paginaEducativa(
        context,
        titulo: 'Manguezal',
        subtitulo: 'Berçário da vida marinha',
        corpo: const [
          'Ecossistema de transição entre rios e mar, de alta biodiversidade.',
          'Raízes do mangue estabilizam o solo e reduzem a erosão costeira.',
          'Funciona como filtro natural que protege praias e recifes.',
        ],
        imagemAsset: 'assets/games/toca-do-caranguejo/background.png',
        imagemCoverFit: BoxFit.cover,
        imagemHasFrame: true,
      ),
      _paginaEducativa(
        context,
        titulo: 'Resíduos Sólidos',
        subtitulo: 'Impactos e boas práticas',
        corpo: const [
          'Plásticos, cordas e latas ferem animais e contaminam a cadeia alimentar.',
          'Evite descarte irregular, priorize redução, reuso e reciclagem.',
          'Mutirões e educação ambiental fortalecem o cuidado com o território.',
        ],
        imagemAsset: 'assets/games/toca-do-caranguejo/lata.png',
      ),
    ];

    _pageCount = pages.length;

    final reduceMotion = context.watch<ThemeProvider>().reduceMotion;
    if (reduceMotion && _pageController == null) {
      final initialSpread = _pageCount > 0 ? _currentSpread : _pgCapa;
      _pageController = PageController(initialPage: initialSpread);
    }

    final Widget bookCore = reduceMotion
        ? BookView(
            pages: pages,
            controller: _pageController,
            aspectRatio: ar,
            pagePadding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
            flipDuration: const Duration(milliseconds: 160),
            allowUserScroll: true,
            backgroundColor: const Color(0xFFF9E1C6),
            onSpreadChanged: _handleSpreadChanged,
          )
        : CurlBookView(
            pages: pages,
            aspectRatio: landscapeAr,
            portraitAspectRatio: portraitAr,
            pagePadding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
            flipKey: _flipKey,
            backgroundColor: const Color(0xFFF9E1C6),
            outerPadding: const EdgeInsets.symmetric(
              horizontal: 2,
              vertical: 1,
            ),
            gutter: 16,
            onPageChanged: _onCurlPageChanged,
          );

    final bool useMobileBackground = size.width < 720;
    final String backgroundAsset = useMobileBackground
        ? 'assets/games/toca-do-caranguejo/background-mobile.png'
        : 'assets/games/toca-do-caranguejo/background.png';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(backgroundAsset, fit: BoxFit.cover),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, cons) {
                final maxW = cons.maxWidth * 0.995;
                final maxH = cons.maxHeight * 0.995;
                double w = maxW, h = maxH;
                if (w / h > ar) {
                  w = h * ar;
                } else {
                  h = w / ar;
                }

                return Center(
                  child: Focus(
                    focusNode: _focusNode,
                    autofocus: true,
                    onKeyEvent: _handleKeyEvent,
                    child: Listener(
                      onPointerDown: (_) => _focusNode.requestFocus(),
                      onPointerSignal: _handlePointerSignal,
                      behavior: HitTestBehavior.translucent,
                      child: Container(
                        width: w,
                        height: h,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0D6B2),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.brown.shade900.withOpacity(0.85),
                            width: 3.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.20),
                              blurRadius: 22,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: bookCore,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------- moldura interna da página (borda mais escura/visível) ----------
  Widget _pageFrame({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final palette = _paletteOf(context);
        final shortestSide = constraints.biggest.shortestSide;
        final safeSide = shortestSide.isFinite ? shortestSide : 600.0;
        final radius = (safeSide * 0.058).clamp(18.0, 28.0).toDouble();
        final innerRadius = math.max(radius - 8, 14.0);
        final margin = math.max(radius * 0.16, 10.0);
        final spineWidth = math.max(radius * 0.68, 18.0);
        final edgeWidth = math.max(radius * 0.5, 14.0);

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius + 12),
            boxShadow: [
              BoxShadow(
                color: palette.outerShadow,
                blurRadius: 32,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius + 12),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          palette.outerPaperTop,
                          palette.outerPaperBottom,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: palette.paperEdge.withOpacity(0.55),
                        width: 1.1,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: spineWidth,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          palette.spineDark,
                          palette.spineMid,
                          palette.spineHighlight,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: edgeWidth,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.transparent,
                          palette.edgeSheen,
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.58, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.12),
                          Colors.transparent,
                          Colors.black.withOpacity(0.05),
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.all(margin),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(innerRadius),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [palette.parchment, palette.parchmentAlt],
                        ),
                        border: Border.all(
                          color: palette.paperEdge.withOpacity(0.4),
                          width: 1.1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 18,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.all(margin * 1.04),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ----------------- Páginas -----------------

  Widget _buildCapa(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        final palette = _paletteOf(context);
        final w = c.maxWidth;
        final h = c.maxHeight;
        final bool isCompact = w < 520;
        final bool isMedium = w < 900;

        final strapHeight = (h * 0.14)
            .clamp(isCompact ? 48.0 : 56.0, isMedium ? 100.0 : 120.0)
            .toDouble();
        final baseSide = math.min(w, h);
        final emblemSize = (baseSide * (isCompact ? 0.28 : 0.24))
            .clamp(96.0, isMedium ? 200.0 : 235.0)
            .toDouble();
        final buttonWidth = (w * 0.32)
            .clamp(150.0, isMedium ? 240.0 : 260.0)
            .toDouble();
        final horizontalPadding = math.max(w * (isCompact ? 0.06 : 0.08), 24.0);
        final topPadding = math.max(h * (isCompact ? 0.13 : 0.15), 32.0);
        final bottomPadding = math.max(h * (isCompact ? 0.08 : 0.10), 26.0);

        final titleStyle =
            (theme.textTheme.displaySmall ?? theme.textTheme.headlineMedium)
                ?.copyWith(
                  fontSize: isCompact ? 30 : (isMedium ? 34 : 38),
                  fontWeight: FontWeight.w900,
                  color: palette.ink,
                  letterSpacing: 1.1,
                  height: 1.02,
                  shadows: [
                    Shadow(
                      blurRadius: 14,
                      color: Colors.black.withOpacity(0.18),
                      offset: const Offset(0, 6),
                    ),
                  ],
                ) ??
                TextStyle(
                  fontSize: isCompact ? 30 : (isMedium ? 34 : 38),
                  fontWeight: FontWeight.w900,
                  color: palette.ink,
                  letterSpacing: 1.1,
                  height: 1.02,
                );

        final subtitleStyle =
            theme.textTheme.titleMedium?.copyWith(
              color: palette.inkMuted,
              letterSpacing: 0.4,
              height: 1.25,
              fontSize: isCompact ? 15 : 16,
            ) ??
                TextStyle(
                  color: palette.inkMuted,
                  letterSpacing: 0.4,
                  height: 1.25,
                  fontSize: isCompact ? 15 : 16,
                );

        return GestureDetector(
          onTap: () => _goTo(_pgMenu),
          child: _pageFrame(
            child: Stack(
              children: [
                Positioned(
                  top: strapHeight * -0.22,
                  left: horizontalPadding,
                  right: horizontalPadding,
                  child: Container(
                    height: strapHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(strapHeight * 0.35),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          palette.accentLeather,
                          palette.accentLeatherHighlight,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.22),
                          blurRadius: strapHeight * 0.45,
                          offset: Offset(0, strapHeight * 0.32),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'Coleção Guardiões do Mangue',
                        textAlign: TextAlign.center,
                        style:
                            theme.textTheme.titleMedium?.copyWith(
                              color: palette.badgeFill,
                              letterSpacing: 1.0,
                              fontWeight: FontWeight.w800,
                            ) ??
                                TextStyle(
                                  color: palette.badgeFill,
                                  letterSpacing: 1.0,
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      topPadding,
                      horizontalPadding,
                      bottomPadding,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          children: [
                            Text(
                              'Livro do Mangue',
                              textAlign: TextAlign.center,
                              style: titleStyle,
                            ),
                            SizedBox(height: isCompact ? 6 : 10),
                            Text(
                              'Histórias e seres que protegem o manguezal',
                              textAlign: TextAlign.center,
                              style: subtitleStyle,
                            ),
                          ],
                        ),
                        SizedBox(
                          height: emblemSize,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: emblemSize * 0.94,
                                height: emblemSize * 0.94,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [palette.vellum, palette.vellumAlt],
                                  ),
                                  border: Border.all(
                                    color: palette.paperEdge.withOpacity(0.6),
                                    width: 3.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.16),
                                      blurRadius: 24,
                                      offset: const Offset(0, 12),
                                    ),
                                  ],
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: isCompact ? 0.60 : 0.54,
                                child: Image.asset(
                                  'assets/games/toca-do-caranguejo/caranguejo.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            Text(
                              'Toque para folhear',
                              style:
                                  theme.textTheme.titleMedium?.copyWith(
                                    color: palette.inkMuted,
                                    letterSpacing: 0.2,
                                  ) ??
                                      TextStyle(
                                        color: palette.inkMuted,
                                        letterSpacing: 0.2,
                                      ),
                            ),
                            SizedBox(height: (isCompact ? 14.0 : 20.0)),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  width: buttonWidth,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      elevation: 6,
                                      backgroundColor: palette.accentLeather,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                    ),
                                    onPressed: () => _goTo(_pgMenu),
                                    child: Text(
                                      'Abrir o livro',
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                          ) ??
                                              TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                              ),
                                    ),
                                  ),
                                ),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: palette.badgeFill,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: palette.paperEdge.withOpacity(
                                        0.35,
                                      ),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      'Volume I',
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                            color: palette.badgeText,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.6,
                                          ) ??
                                              TextStyle(
                                                color: palette.badgeText,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.6,
                                              ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuCartas(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final palette = _paletteOf(context);
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final bool isCompact = w < 720;
        final bool isTablet = w >= 720 && w < 1080;
        final bool allowScroll = h < (isCompact ? 760 : 680);

        final double horizontal = math.max(w * (isCompact ? 0.03 : 0.05), 14.0);
        final double topPadding = math.max(
          h * (isCompact ? 0.045 : 0.06),
          16.0,
        );
        final double bottomPadding = math.max(
          h * (isCompact ? 0.04 : 0.05),
          14.0,
        );

        final int columns = isCompact ? 2 : (isTablet ? 3 : 4);
        final double spacing = isCompact ? 10.0 : 18.0;
        final double cardAspect = isCompact ? 1.12 : (isTablet ? 1.04 : 1.18);
        final double widthFactor = isCompact ? 0.8 : (isTablet ? 0.84 : 0.88);

        final cards = [
          _cardBoard(
            context,
            titulo: 'Caranguejo',
            asset: 'assets/games/toca-do-caranguejo/caranguejo.png',
            onTap: () => _goTo(_pgCaranguejo),
          ),
          _cardBoard(
            context,
            titulo: 'Guará',
            asset: 'assets/games/toca-do-caranguejo/guara-entreaberto-2.png',
            fallbackAsset: 'assets/games/toca-do-caranguejo/guara-aberto-1.png',
            onTap: () => _goTo(_pgGuara),
          ),
          _cardBoard(
            context,
            titulo: 'Mangue',
            asset: 'assets/games/toca-do-caranguejo/background.png',
            hasFrame: true,
            coverFit: BoxFit.cover,
            onTap: () => _goTo(_pgMangue),
          ),
          _cardBoard(
            context,
            titulo: 'Resíduos',
            asset: 'assets/games/toca-do-caranguejo/lata.png',
            onTap: () => _goTo(_pgResiduos),
          ),
        ];

        final int rowCount = (cards.length / columns).ceil();

        final double estimatedHeader = 92.0;
        final double estimatedHint = 72.0;
        final double availableForGrid = math.max(
          h - topPadding - bottomPadding - estimatedHeader - estimatedHint,
          160.0,
        );
        final double maxRowHeight =
            (availableForGrid - spacing * (rowCount - 1)) / rowCount;

        final grid = LayoutBuilder(
          builder: (context, inner) {
            final width = inner.maxWidth;
            final double available =
                (width - spacing * (columns - 1)) / columns;
            final double cardWidth = available * widthFactor;
            final double cardHeight = math.min(
              maxRowHeight,
              cardWidth / cardAspect,
            );
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              alignment: WrapAlignment.center,
              children: [
                for (final card in cards)
                  SizedBox(width: cardWidth, height: cardHeight, child: card),
              ],
            );
          },
        );

        final header = Column(
          children: [
            Text(
              'Escolha uma carta',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Cada carta abre um capítulo ilustrado do manguezal.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: palette.inkMuted,
                letterSpacing: 0.3,
                height: 1.3,
              ),
            ),
          ],
        );

        final bottomHint = DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [palette.vellum, palette.vellumAlt],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.paperEdge.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Toque em uma carta para folhear o capítulo correspondente.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.inkMuted,
                letterSpacing: 0.2,
              ),
            ),
          ),
        );

        final double afterHeaderSpacing = isCompact ? 10 : topPadding * 0.32;
        final double beforeHintSpacing = isCompact ? 12 : topPadding * 0.28;

        Widget content;
        if (allowScroll) {
          content = SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                SizedBox(height: afterHeaderSpacing),
                grid,
                SizedBox(height: beforeHintSpacing),
                bottomHint,
              ],
            ),
          );
        } else {
          content = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              SizedBox(height: afterHeaderSpacing),
              Expanded(child: grid),
              SizedBox(height: beforeHintSpacing),
              bottomHint,
            ],
          );
        }

        return _pageFrame(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontal,
              topPadding,
              horizontal,
              bottomPadding,
            ),
            child: content,
          ),
        );
      },
    );
  }

  Widget _paginaEducativa(
    BuildContext context, {
    required String titulo,
    String? subtitulo,
    required List<String> corpo,
    String? imagemAsset,
    String? fallbackAsset,
    BoxFit imagemCoverFit = BoxFit.contain,
    bool imagemHasFrame = false,
  }) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final palette = _paletteOf(context);
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final bool isWide = w > 820;
        final bool isCompact = w < 640;

        // Telas pequenas: rolamos a PÁGINA inteira (não só o texto).
        // Isso elimina overflow e dá leitura completa com touch para baixo.
        final bool allowOuterScroll = h < 740 || isCompact;

        final double horizontal = math.max(w * (isCompact ? 0.06 : 0.08), 16.0);
        final double topPadding = math.max(h * 0.07, 18.0);
        final double bottomPadding = math.max(h * 0.06, 16.0);
        final double gap = math.max(h * 0.035, 14.0);

        Widget? imagePanel;
        if (imagemAsset != null) {
          final double maxImageHeight = math.min(
            h * (isWide ? 0.62 : 0.46),
            isWide ? 320.0 : 220.0,
          );
          imagePanel = Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: maxImageHeight,
                maxWidth: isWide ? maxImageHeight * 1.15 : double.infinity,
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(isWide ? 26 : 20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [palette.cardTop, palette.cardBottom],
                  ),
                  border: Border.all(
                    color:
                        (imagemHasFrame ? palette.cardOutline : palette.paperEdge)
                            .withOpacity(imagemHasFrame ? 0.7 : 0.45),
                    width: imagemHasFrame ? 2.6 : 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(isWide ? 26 : 20),
                        child: Image.asset(
                          imagemAsset,
                          fit: imagemCoverFit,
                          errorBuilder: (_, __, ___) => fallbackAsset != null
                              ? Image.asset(fallbackAsset, fit: BoxFit.contain)
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 16,
                      right: 16,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: palette.badgeFill.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: palette.paperEdge.withOpacity(0.4),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Text(
                            'Ilustração',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: palette.badgeText,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.35,
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

        // Painel de texto (duas versões: com rolagem interna ou sem).
        Widget buildTextPanelScrollableInside() {
          final bulletWidgets = [
            for (final text in corpo)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '•',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: palette.inkMuted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        text,
                        style: theme.textTheme.bodyLarge?.copyWith(
                              height: 1.45,
                              color: palette.ink,
                            ) ??
                            TextStyle(height: 1.45, color: palette.ink),
                      ),
                    ),
                  ],
                ),
              ),
          ];

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [palette.vellum, palette.vellumAlt],
              ),
              borderRadius: BorderRadius.circular(isWide ? 24 : 20),
              border: Border.all(
                color: palette.paperEdge.withOpacity(0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 26 : 22,
                vertical: isWide ? 22 : 18,
              ),
              child: LayoutBuilder(
                builder: (context, box) {
                  final double maxBulletHeight =
                      math.max(120.0, (box.maxHeight.isFinite ? box.maxHeight : 280) - 48);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: maxBulletHeight),
                          child: SingleChildScrollView(
                            padding: EdgeInsets.zero,
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: bulletWidgets,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.auto_stories,
                            size: 18,
                            color: palette.inkMuted.withOpacity(0.7),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Passe a página para descobrir mais curiosidades.',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: palette.inkMuted,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        }

        Widget buildTextPanelNoInnerScroll() {
          final bulletWidgets = [
            for (final text in corpo)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '•',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: palette.inkMuted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        text,
                        style: theme.textTheme.bodyLarge?.copyWith(
                              height: 1.45,
                              color: palette.ink,
                            ) ??
                            TextStyle(height: 1.45, color: palette.ink),
                      ),
                    ),
                  ],
                ),
              ),
          ];

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [palette.vellum, palette.vellumAlt],
              ),
              borderRadius: BorderRadius.circular(isWide ? 24 : 20),
              border: Border.all(
                color: palette.paperEdge.withOpacity(0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 26 : 22,
                vertical: isWide ? 22 : 18,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...bulletWidgets,
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.auto_stories,
                        size: 18,
                        color: palette.inkMuted.withOpacity(0.7),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Passe a página para descobrir mais curiosidades.',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: palette.inkMuted,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        // ========= Layouts =========
        // A) Outer scroll (mobile/altura baixa): tudo dentro de SingleChildScrollView
        if (allowOuterScroll) {
          final contentColumnChildren = <Widget>[
            Text(
              titulo,
              textAlign: isWide ? TextAlign.left : TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                    color: palette.ink,
                  ) ??
                  const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                    color: Colors.black,
                  ),
            ),
            if (subtitulo != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitulo,
                textAlign: isWide ? TextAlign.left : TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                      color: palette.inkMuted,
                      letterSpacing: 0.2,
                    ) ??
                    TextStyle(
                      color: palette.inkMuted,
                      letterSpacing: 0.2,
                    ),
              ),
            ],
            SizedBox(height: gap),
            if (imagePanel != null) ...[
              imagePanel,
              SizedBox(height: gap),
            ],
            buildTextPanelNoInnerScroll(),
          ];

          final scrollable = SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                topPadding,
                horizontal,
                bottomPadding,
              ),
              child: Column(
                crossAxisAlignment:
                    isWide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                children: contentColumnChildren,
              ),
            ),
          );

          final page = _pageFrame(child: scrollable);

          // Shield: captura TAP e DRAG VERTICAL para não virar página no curl.
          return _ScrollShield(enabled: true, child: page);
        }

        // B) Sem outer scroll (telas grandes): layout elástico com Expanded
        final textPanel = buildTextPanelScrollableInside();
        Widget detailSection;
        if (isWide) {
          detailSection = Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (imagePanel != null)
                  Expanded(
                    flex: 5,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 20),
                      child: imagePanel,
                    ),
                  ),
                Expanded(flex: imagePanel != null ? 6 : 10, child: textPanel),
              ],
            ),
          );
        } else {
          final children = <Widget>[];
          if (imagePanel != null) {
            children.add(imagePanel);
            children.add(SizedBox(height: gap));
          }
          children.add(Expanded(child: textPanel));
          detailSection = Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          );
        }

        final pageContent = _pageFrame(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontal,
              topPadding,
              horizontal,
              bottomPadding,
            ),
            child: Column(
              crossAxisAlignment:
                  isWide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              children: [
                Text(
                  titulo,
                  textAlign: isWide ? TextAlign.left : TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        color: palette.ink,
                      ) ??
                      const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        color: Colors.black,
                      ),
                ),
                if (subtitulo != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitulo,
                    textAlign: isWide ? TextAlign.left : TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                          color: palette.inkMuted,
                          letterSpacing: 0.2,
                        ) ??
                        TextStyle(color: palette.inkMuted, letterSpacing: 0.2),
                  ),
                ],
                SizedBox(height: gap),
                detailSection,
              ],
            ),
          ),
        );

        return pageContent;
      },
    );
  }

  // ----------------- CARD: sem overflow (conteúdo elástico) -----------------

  Widget _cardBoard(
    BuildContext context, {
    required String titulo,
    required String asset,
    required VoidCallback onTap,
    String? fallbackAsset,
    BoxFit coverFit = BoxFit.contain,
    bool hasFrame = false,
  }) {
    final theme = Theme.of(context);
    final palette = _paletteOf(context);
    return Semantics(
      button: true,
      label: 'Carta ',
      child: LayoutBuilder(
        builder: (context, box) {
          final side = math.min(box.maxWidth, box.maxHeight);
          final radius = (side * 0.16).clamp(14.0, 22.0).toDouble();
          final ribbonHeight = math.max(radius * 0.26, 18.0);
          final inset = math.max(radius * 0.18, 10.0);
          final innerTop = ribbonHeight + math.max(radius * 0.16, 10.0);
          final innerBottom = math.max(radius * 0.22, 12.0);

          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(radius),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(radius),
                splashColor: palette.accentLeather.withOpacity(0.12),
                highlightColor: palette.accentLeather.withOpacity(0.06),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [palette.cardTop, palette.cardBottom],
                    ),
                    border: Border.all(
                      color: palette.cardOutline.withOpacity(0.5),
                      width: 1.4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      inset,
                      innerTop,
                      inset,
                      innerBottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(radius * 0.4),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(
                                  color: hasFrame
                                      ? palette.cardOutline.withOpacity(0.68)
                                      : palette.paperEdge.withOpacity(0.38),
                                  width: hasFrame ? 2.0 : 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.07),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Image.asset(
                                  asset,
                                  fit: coverFit,
                                  errorBuilder: (_, __, ___) =>
                                      fallbackAsset != null
                                          ? Image.asset(
                                              fallbackAsset,
                                              fit: BoxFit.contain,
                                            )
                                          : const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            titulo,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                              color: palette.ink,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Virar capítulo',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: palette.inkMuted.withOpacity(0.7),
                              letterSpacing: 0.4,
                            ),
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
      ),
    );
  }
}

/// Absorve TAP e captura DRAG VERTICAL para impedir que o gesto de rolagem
/// vire a página no componente de curl. Mantém swipe horizontal funcionando.
class _ScrollShield extends StatelessWidget {
  const _ScrollShield({required this.enabled, required this.child});
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      onDoubleTap: () {},
      onVerticalDragStart: (_) {},
      onVerticalDragUpdate: (_) {},
      onVerticalDragEnd: (_) {},
      child: child,
    );
  }
}
