import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../audio/typing_loop_sfx.dart';
import '../../../services/user_prefs.dart';
import '../../../theme/game_styles.dart';
import '../../../theme/theme_provider.dart';
import '../../../widgets/game_frame.dart';
import '../../../widgets/link_button.dart';
import '../../../widgets/pixel_button.dart';
import '../../../widgets/typing_text.dart';

import 'game.dart' deferred as game;
import 'missao_reciclagem_game.dart';

class MissaoReciclagemTutorialScreen extends StatefulWidget {
  const MissaoReciclagemTutorialScreen({super.key});

  @override
  State<MissaoReciclagemTutorialScreen> createState() =>
      _MissaoReciclagemTutorialScreenState();
}

class _MissaoReciclagemTutorialScreenState
    extends State<MissaoReciclagemTutorialScreen>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<bool> _sfxEnabled = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _typingRunning = ValueNotifier<bool>(false);
  final ValueNotifier<int> _paraIndex = ValueNotifier<int>(0);
  final TypingTextController _typingController = TypingTextController();
  final ValueNotifier<bool> _showScrollHint = ValueNotifier<bool>(false);
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _arrowCtrl;
  late final Animation<Offset> _arrowOffset;

  late final TypingLoopSfx _typingSfx;
  final ValueNotifier<bool> _audioUnlocked = ValueNotifier<bool>(false);
  bool _audioStarted = false;

  Future<void> _loadAudioPreference() async {
    final stored = await UserPrefs.getAudioEnabled();
    if (!mounted) return;
    _sfxEnabled.value = stored;
  }

  @override
  void initState() {
    super.initState();
    _typingSfx = TypingLoopSfx(volume: 0.25);
    _loadAudioPreference();
    _arrowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _arrowOffset = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 0.18),
    ).animate(CurvedAnimation(parent: _arrowCtrl, curve: Curves.easeInOut));
    _scrollController.addListener(_updateScrollHint);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollHint());
  }

  @override
  void dispose() {
    _sfxEnabled.dispose();
    _typingRunning.dispose();
    _paraIndex.dispose();
    _showScrollHint.dispose();
    _audioUnlocked.dispose();
    _scrollController.removeListener(_updateScrollHint);
    _scrollController.dispose();
    _arrowCtrl.dispose();
    _typingSfx.dispose();
    super.dispose();
  }

  void _updateScrollHint() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final show = max > 10 && _scrollController.position.pixels < max - 10;
    if (_showScrollHint.value != show) _showScrollHint.value = show;
  }

  Future<void> _scrollStepDown() async {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final step = pos.viewportDimension * 0.8;
    final target = (pos.pixels + step).clamp(0.0, pos.maxScrollExtent);
    final reduceMotion = context.read<ThemeProvider>().reduceMotion;
    await _scrollController.animateTo(
      target,
      duration: Duration(milliseconds: reduceMotion ? 160 : 300),
      curve: reduceMotion ? Curves.linear : Curves.easeOut,
    );
    _updateScrollHint();
  }

  Future<void> _scrollToBottom() async {
    if (!_scrollController.hasClients) return;
    final reduceMotion = context.read<ThemeProvider>().reduceMotion;
    await _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: Duration(milliseconds: reduceMotion ? 180 : 350),
      curve: reduceMotion ? Curves.linear : Curves.easeOut,
    );
    _showScrollHint.value = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = context.watch<ThemeProvider>().reduceMotion;
    final styles = theme.extension<GameStyles>();

    final List<String> paragraphs = [
      'Você está ajudando a equipe de coleta seletiva de Morretes a separar os resíduos da cidade.',
      'Arraste cada item até a lixeira com a cor correspondente.',
      'Você pode mover o item usando as setas na tela ou as setas do teclado (← →).',
      'Quando o item correto encosta na área da lixeira, ele é recolhido automaticamente.',
      'Acertar rende +10 pontos e atualiza os contadores no topo da tela.',
      'Se errar, você perde 5 pontos. Observe o formato e o material de cada resíduo.',
      'A rodada dura ${MissaoReciclagemGame.roundDurationSeconds} segundos. Ao tocar em "Iniciar", os itens começam a cair.',
      'Ao final, o painel de resultados mostra sua pontuação e quantos resíduos você separou. Tente superar seu recorde!',
    ];

    const List<_BinLegendData> binLegend = [
      _BinLegendData(
        colorName: 'Azul',
        material: 'Papel',
        assetPath: 'assets/games/missao-reciclagem/papel.png',
        labelColor: Color(0xFF1565C0),
      ),
      _BinLegendData(
        colorName: 'Vermelho',
        material: 'Plástico',
        assetPath: 'assets/games/missao-reciclagem/plastico.png',
        labelColor: Color(0xFFC62828),
      ),
      _BinLegendData(
        colorName: 'Amarelo',
        material: 'Metal',
        assetPath: 'assets/games/missao-reciclagem/metal.png',
        labelColor: Color(0xFFF9A825),
      ),
      _BinLegendData(
        colorName: 'Verde',
        material: 'Vidro',
        assetPath: 'assets/games/missao-reciclagem/vidro.png',
        labelColor: Color(0xFF2E7D32),
      ),
      _BinLegendData(
        colorName: 'Marrom',
        material: 'Orgânicos',
        assetPath: 'assets/games/missao-reciclagem/organico.png',
        labelColor: Color(0xFF6D4C41),
      ),
    ];

    final listenAll = Listenable.merge([
      _sfxEnabled,
      _typingRunning,
      _paraIndex,
      _showScrollHint,
      _audioUnlocked,
    ]);

    return GameScaffold(
      title: 'Missão Reciclagem',
      backgroundAsset:
          'assets/games/missao-reciclagem/background-reciclagem.png',
      mobileBackgroundAsset:
          'assets/games/missao-reciclagem/background-missao-mobile.png',
      fill: false,
      child: Listener(
        onPointerDown: (_) async {
          final firstUnlock = !_audioUnlocked.value;
          if (firstUnlock) {
            _audioUnlocked.value = true;
            await _typingSfx.unlock();
            if (_typingRunning.value && _sfxEnabled.value && !_audioStarted) {
              await _typingSfx.start(segment: const Duration(seconds: 4));
              _audioStarted = true;
            }
            return;
          }
          if (_typingRunning.value) _typingController.skip();
        },
        child: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.space ||
                  event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.arrowRight) {
                if (_typingRunning.value) {
                  _typingController.skip();
                  return KeyEventResult.handled;
                }
              }
            }
            return KeyEventResult.ignored;
          },
          child: AnimatedBuilder(
            animation: listenAll,
            builder: (context, _) => Stack(
              children: [
                SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const GameSectionTitle('Como Jogar'),
                          const Spacer(),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              border: Border.all(color: Colors.brown),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: IconButton(
                              tooltip: 'Som do Texto',
                              icon: Icon(
                                _sfxEnabled.value
                                    ? Icons.volume_up_rounded
                                    : Icons.volume_off_rounded,
                                color: Colors.brown,
                              ),
                              onPressed: () async {
                                final next = !_sfxEnabled.value;
                                _sfxEnabled.value = next;
                                await UserPrefs.setAudioEnabled(next);
                                if (!next) {
                                  if (_audioStarted) {
                                    await _typingSfx.stop();
                                    _audioStarted = false;
                                  }
                                } else if (_typingRunning.value &&
                                    _audioUnlocked.value &&
                                    !_audioStarted) {
                                  await _typingSfx.start(
                                    segment: const Duration(seconds: 4),
                                  );
                                  _audioStarted = true;
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_paraIndex.value > 0) ...[
                        for (int i = 0; i < _paraIndex.value; i++) ...[
                          Text(
                            paragraphs[i],
                            textAlign: TextAlign.center,
                            style: styles?.tutorialBody,
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                      _TypingParagraph(
                        text: paragraphs[_paraIndex.value],
                        controller: _typingController,
                        enableSound: _sfxEnabled.value,
                        reduceMotion: reduceMotion,
                        showSkipAll: _paraIndex.value < paragraphs.length - 1,
                        onStart: () {
                          _typingRunning.value = true;
                          if (_sfxEnabled.value &&
                              _audioUnlocked.value &&
                              !_audioStarted) {
                            _typingSfx.start(
                              segment: const Duration(seconds: 4),
                            );
                            _audioStarted = true;
                          }
                        },
                        onFinished: () {
                          _typingRunning.value = false;
                          if (_audioStarted) {
                            _typingSfx.stop();
                            _audioStarted = false;
                          }
                          if (_paraIndex.value >= paragraphs.length - 1) {
                            _scrollToBottom();
                          }
                        },
                        onSkipAll: () {
                          _typingRunning.value = false;
                          _paraIndex.value = paragraphs.length - 1;
                          _scrollToBottom();
                          if (_audioStarted) {
                            _typingSfx.stop();
                            _audioStarted = false;
                          }
                        },
                      ),
                      if (_paraIndex.value >= 2) ...[
                        const SizedBox(height: 16),
                        _BinLegend(items: binLegend, styles: styles),
                        const SizedBox(height: 24),
                      ],
                      if (!_typingRunning.value)
                        Center(
                          child: (_paraIndex.value < paragraphs.length - 1)
                              ? PixelButton(
                                  label: 'Continuar',
                                  icon: Icons.navigate_next_rounded,
                                  iconRight: true,
                                  width: 200,
                                  height: 48,
                                  onPressed: () {
                                    _paraIndex.value++;
                                  },
                                )
                              : PixelButton(
                                  label: 'Jogar',
                                  icon: Icons.play_arrow_rounded,
                                  iconRight: true,
                                  onPressed: () async {
                                    await game.loadLibrary();
                                    if (!context.mounted) return;
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            game.MissaoReciclagemGameScreen(),
                                      ),
                                    );
                                  },
                                  width: 220,
                                  height: 56,
                                ),
                        ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          tooltip: 'Voltar ao início',
                          icon: const Icon(
                            Icons.home_rounded,
                            color: Colors.brown,
                          ),
                          iconSize: 28,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 6,
                  left: 0,
                  right: 0,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _showScrollHint,
                    builder: (context, show, _) => AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      opacity: show ? 1 : 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: _scrollStepDown,
                          child: SlideTransition(
                            position: _arrowOffset,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.85),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.95),
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BinLegendData {
  const _BinLegendData({
    required this.colorName,
    required this.material,
    required this.assetPath,
    required this.labelColor,
  });

  final String colorName;
  final String material;
  final String assetPath;
  final Color labelColor;
}

class _BinLegend extends StatelessWidget {
  const _BinLegend({required this.items, required this.styles});

  final List<_BinLegendData> items;
  final GameStyles? styles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseLabelStyle =
        styles?.tutorialBody ??
        theme.textTheme.bodyMedium ??
        const TextStyle(fontSize: 14);
    final labelStyle = baseLabelStyle.copyWith(fontWeight: FontWeight.w600);
    final baseMaterialStyle =
        styles?.hint ??
        theme.textTheme.bodySmall ??
        const TextStyle(fontSize: 12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Legenda das lixeiras',
          textAlign: TextAlign.center,
          style: labelStyle,
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 20,
          runSpacing: 16,
          children: items
              .map(
                (item) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.colorName,
                      style: labelStyle.copyWith(color: item.labelColor),
                    ),
                    Text(item.material, style: baseMaterialStyle),
                    const SizedBox(height: 6),
                    Container(
                      width: 84,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: item.labelColor.withOpacity(0.45),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        item.assetPath,
                        height: 54,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _TypingParagraph extends StatefulWidget {
  const _TypingParagraph({
    required this.text,
    required this.onStart,
    required this.onFinished,
    required this.onSkipAll,
    this.controller,
    this.showSkipAll = true,
    this.enableSound = true,
    this.reduceMotion = false,
  });

  final String text;
  final VoidCallback onStart;
  final VoidCallback onFinished;
  final VoidCallback onSkipAll;
  final TypingTextController? controller;
  final bool showSkipAll;
  final bool enableSound;
  final bool reduceMotion;

  @override
  State<_TypingParagraph> createState() => _TypingParagraphState();
}

class _TypingParagraphState extends State<_TypingParagraph> {
  final TypingTextController _controller = TypingTextController();

  @override
  Widget build(BuildContext context) {
    final styles = Theme.of(context).extension<GameStyles>();
    final bool reduceMotion = widget.reduceMotion;
    final column = Column(
      key: ValueKey<String>(widget.text),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TypingText(
          key: ValueKey<bool>(widget.enableSound),
          controller: widget.controller ?? _controller,
          showSkipButton: false,
          text: widget.text,
          charDelay: Duration(milliseconds: reduceMotion ? 5 : 45),
          clickEvery: reduceMotion ? 6 : 2,
          enableSound: reduceMotion ? false : widget.enableSound,
          style: styles?.tutorialBody,
          onStart: widget.onStart,
          onFinished: widget.onFinished,
        ),
        if (widget.showSkipAll) ...[
          const SizedBox(height: 4),
          LinkButton(label: 'Pular', onPressed: widget.onSkipAll),
        ],
      ],
    );

    return AnimatedSwitcher(
      duration: Duration(milliseconds: reduceMotion ? 80 : 320),
      switchInCurve: reduceMotion ? Curves.linear : Curves.easeOutCubic,
      switchOutCurve: reduceMotion ? Curves.linear : Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        if (reduceMotion) {
          return FadeTransition(opacity: animation, child: child);
        }
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.24),
          end: Offset.zero,
        ).animate(curved);
        final fade = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
          reverseCurve: Curves.easeIn,
        );
        return ClipRect(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: slide,
              child: FadeTransition(opacity: fade, child: child),
            ),
          ),
        );
      },
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: column,
    );
  }
}
