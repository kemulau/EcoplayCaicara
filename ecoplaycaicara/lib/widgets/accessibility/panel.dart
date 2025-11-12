// Acessibilidade - painel compacto/responsivo reutilizável em todos os jogos.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/tts_defaults.dart';
import '../../services/tts_service.dart';
import '../../services/user_prefs.dart';
import '../../theme/color_blindness.dart';
import '../../theme/theme_provider.dart';
import '../narrable.dart';

typedef A11ySectionBuilder = Widget Function(BuildContext context);

Future<T?> showA11yPanelBottomSheet<T>(
  BuildContext context, {
  List<A11ySectionBuilder> extraSections = const <A11ySectionBuilder>[],
}) {
  final media = MediaQuery.of(context);
  final bool isMobileLayout =
      media.size.width <= _PanelLayout.mobileBreakpoint ||
      media.orientation == Orientation.portrait;

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      if (isMobileLayout) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.92,
          minChildSize: 0.6,
          maxChildSize: 0.96,
          builder: (context, scrollController) {
            return PrimaryScrollController(
              controller: scrollController,
              child: A11yPanel(
                extraSections: extraSections,
                layout: const _PanelLayout.mobile(),
              ),
            );
          },
        );
      }
      return A11yPanel(
        extraSections: extraSections,
        layout: const _PanelLayout.desktop(),
      );
    },
  );
}

class A11yPanel extends StatefulWidget {
  const A11yPanel({
    super.key,
    this.extraSections = const <A11ySectionBuilder>[],
    required this.layout,
  });

  final List<A11ySectionBuilder> extraSections;
  final _PanelLayout layout;

  @override
  State<A11yPanel> createState() => _A11yPanelState();
}

class _A11yPanelState extends State<A11yPanel>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  bool _loadingTts = true;
  List<TtsVoiceOption> _voices = const <TtsVoiceOption>[];
  String? _voice;
  double _volume = TtsDefaults.volumeDefault;
  String? _ttsLoadError;
  late bool _compactMode;
  TabController? _tabController;
  final FocusNode _sectionsButtonFocusNode = FocusNode(
    debugLabel: 'a11ySectionsButton',
  );
  final GlobalKey _sectionsButtonKey = GlobalKey(
    debugLabel: 'a11ySectionsButtonKey',
  );

  bool get _isMobile => widget.layout.isMobile;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _compactMode = !_isMobile;
    _ensureTabController(widget.layout.isMobile);
    _bootstrapTts();
  }

  Future<void> _bootstrapTts({bool force = false}) async {
    final prefs = UserPrefs.instance;
    await prefs.ensureLoaded();
    if (mounted) {
      setState(() {
        _loadingTts = true;
        _ttsLoadError = null;
      });
    } else {
      _loadingTts = true;
      _ttsLoadError = null;
    }
    List<TtsVoiceOption> voices = const <TtsVoiceOption>[];
    String? voiceName = prefs.ttsVoiceName;
    double volume = prefs.ttsVolume;
    try {
      if (force || TtsService.instance.voicesPtBr.isEmpty) {
        try {
          await TtsService.instance
              .ensureVoicesLoaded(force: force)
              .timeout(const Duration(seconds: 3));
        } on TimeoutException {
          _ttsLoadError =
              'Não foi possível carregar a lista de vozes. Tente novamente.';
        }
      } else {
        await TtsService.instance.ensureVoicesLoaded(force: force);
      }
      voices = TtsService.instance.voicesPtBr;
      voiceName = prefs.ttsVoiceName;
      final bool voiceExists =
          voiceName != null && voices.any((voice) => voice.name == voiceName);
      final bool migrateFromThalita = (voiceName ?? '').toLowerCase().contains(
        'thalita',
      );
      if (voices.isNotEmpty &&
          (!voiceExists || migrateFromThalita || voiceName == null)) {
        final TtsVoiceOption preferred = _preferredVoiceFor(voices);
        voiceName = preferred.name;
        await prefs.setTtsVoiceName(voiceName);
        TtsService.instance.voiceName = voiceName;
      }
    } catch (error) {
      _ttsLoadError = 'Falha ao carregar vozes: $error';
      voices = TtsService.instance.voicesPtBr;
    }
    if (!mounted) {
      _voices = voices;
      _voice = voiceName;
      _volume = volume;
      _loadingTts = false;
      return;
    }
    setState(() {
      _voices = voices;
      _voice = voiceName;
      _volume = volume
          .clamp(TtsDefaults.volumeMin, TtsDefaults.volumeMax)
          .toDouble();
      _loadingTts = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final prefs = UserPrefs.instance;
    unawaited(prefs.ensureLoaded());

    final ThemeData panelTheme = theme.copyWith(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      listTileTheme: theme.listTileTheme.copyWith(
        dense: true,
        horizontalTitleGap: 10,
        minLeadingWidth: 28,
        contentPadding: EdgeInsets.zero,
      ),
      switchTheme: theme.switchTheme.copyWith(
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      expansionTileTheme: theme.expansionTileTheme.copyWith(
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        childrenPadding: EdgeInsets.zero,
        collapsedIconColor: scheme.onSurfaceVariant,
        iconColor: scheme.primary,
      ),
      dividerTheme: theme.dividerTheme.copyWith(space: 0),
    );

    return Theme(
      data: panelTheme,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final _PanelLayout layout = widget.layout.resolve(constraints);
          _ensureTabController(layout.isMobile);
          final bool allowTwoColumns =
              _compactMode && !layout.isMobile && constraints.maxWidth >= 600;
          final EdgeInsets padding = layout.isMobile
              ? const EdgeInsets.fromLTRB(16, 12, 16, 16)
              : const EdgeInsets.all(20);

          final Widget body = Consumer<ThemeProvider>(
            builder: (context, tp, _) {
              final _PanelContent content = _buildContent(context, tp, prefs);
              return layout.isMobile
                  ? _MobilePanel(
                      tabController: _tabController!,
                      content: content,
                      allowTwoColumns: allowTwoColumns,
                      compactMode: _compactMode,
                      onReset: () => _handleReset(tp),
                      onApply: () => Navigator.of(context).maybePop(),
                      loadingTts: _loadingTts,
                      onOpenSectionsMenu: _openSectionsMenu,
                      sectionsButtonFocusNode: _sectionsButtonFocusNode,
                      sectionsButtonKey: _sectionsButtonKey,
                      onSelectSection: _switchToSection,
                    )
                  : _DesktopPanel(
                      constraints: constraints,
                      padding: padding,
                      content: content,
                      allowTwoColumns: allowTwoColumns,
                      compactMode: _compactMode,
                      onReset: () => _handleReset(tp),
                      onApply: () => Navigator.of(context).maybePop(),
                      loadingTts: _loadingTts,
                    );
            },
          );

          if (layout.isMobile) {
            return Material(
              color: scheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: body,
            );
          }

          final double constrainedWidth = math.min(
            constraints.maxWidth,
            _PanelLayout.desktopMaxWidth,
          );
          final double constrainedHeight = math.min(
            constraints.maxHeight,
            _PanelLayout.desktopMaxHeight,
          );

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constrainedWidth,
                maxHeight: constrainedHeight,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Material(
                  color: scheme.surface,
                  elevation: 6,
                  shadowColor: Colors.black.withOpacity(0.35),
                  child: body,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  _PanelContent _buildContent(
    BuildContext context,
    ThemeProvider tp,
    UserPrefs prefs,
  ) {
    final List<Widget> leitura = <Widget>[
      _buildNarrateUiTile(prefs),
      _buildTtsEnabledTile(context, prefs),
      _buildVolumeSlider(prefs),
      _buildVoiceSelector(context, prefs),
      _buildVoiceActionsRow(),
    ];

    final List<Widget> legibilidade = <Widget>[
      _buildTextScaleSlider(tp),
      _buildFontSelector(tp),
    ];

    final List<Widget> contraste = <Widget>[
      _buildDarkModeTile(tp),
      _buildHighContrastTile(tp),
      _buildColorVisionSelector(tp),
    ];

    final List<Widget> uiAudio = <Widget>[
      _buildReduceMotionTile(tp),
      _buildShowTooltipsTile(prefs),
    ];

    final List<Widget> avancado = _buildExtraSectionWidgets(context);

    return _PanelContent(
      layout: widget.layout,
      leituraDeTela: leitura,
      legibilidade: legibilidade,
      contrasteCores: contraste,
      uiAudio: uiAudio,
      avancado: avancado,
    );
  }

  Narrable _buildDarkModeTile(ThemeProvider tp) {
    return Narrable(
      text: 'Modo escuro',
      tooltip: 'Alternar modo escuro',
      child: SwitchListTile.adaptive(
        value: tp.isDark,
        onChanged: tp.setDark,
        title: const Text('Modo escuro'),
      ),
    );
  }

  Narrable _buildHighContrastTile(ThemeProvider tp) {
    return Narrable(
      text: 'Alto contraste',
      tooltip: 'Ativar alto contraste no app',
      child: SwitchListTile.adaptive(
        value: tp.highContrast,
        onChanged: tp.setHighContrast,
        title: const Text('Alto contraste'),
      ),
    );
  }

  Widget _buildReduceMotionTile(ThemeProvider tp) {
    return Semantics(
      container: true,
      label: 'Reduzir movimento',
      hint: 'Minimiza animações e efeitos intensos',
      toggled: tp.reduceMotion,
      child: Narrable(
        text: 'Reduzir movimento',
        tooltip:
            'Reduzir movimento. Limita animações, tremores e efeitos exagerados.',
        child: SwitchListTile.adaptive(
          value: tp.reduceMotion,
          onChanged: tp.setReduceMotion,
          title: const Text('Reduzir movimento'),
          subtitle: const Text(
            'Limita animações e efeitos exagerados em todas as telas.',
          ),
        ),
      ),
    );
  }

  Widget _buildShowTooltipsTile(UserPrefs prefs) {
    return ValueListenableBuilder<bool>(
      valueListenable: prefs.showTooltipsNotifier,
      builder: (_, showTooltips, __) {
        final bool loaded = prefs.isLoaded;
        return Narrable(
          text: 'Mostrar tooltips',
          tooltip: 'Mostrar tooltips. Exibe dicas ao passar o mouse ou tocar.',
          child: SwitchListTile.adaptive(
            value: showTooltips,
            onChanged: loaded
                ? (value) async {
                    await prefs.setShowTooltips(value);
                    TtsService.instance.updateFromPrefs(prefs);
                  }
                : null,
            title: const Text('Mostrar tooltips'),
          ),
        );
      },
    );
  }

  Widget _buildNarrateUiTile(UserPrefs prefs) {
    return ValueListenableBuilder<bool>(
      valueListenable: prefs.ttsReadUiNotifier,
      builder: (_, readUi, __) {
        final bool loaded = prefs.isLoaded;
        return Narrable(
          text: 'Narrar ao focar/pressionar',
          tooltip:
              'Lê textos da interface ao focar, passar o mouse ou tocar prolongado.',
          child: SwitchListTile.adaptive(
            value: readUi,
            onChanged: loaded
                ? (value) async {
                    await prefs.setTtsReadUi(value);
                    TtsService.instance.updateFromPrefs(prefs);
                    if (value) {
                      await TtsService.instance.ensureUnlockedByUserGesture();
                    }
                  }
                : null,
            title: const Text('Narrar ao focar/pressionar'),
            subtitle: const Text(
              'Lê textos da interface ao focar, passar o mouse ou pressionar.',
            ),
          ),
        );
      },
    );
  }

  Widget _buildTtsEnabledTile(BuildContext context, UserPrefs prefs) {
    return ValueListenableBuilder<bool>(
      valueListenable: prefs.ttsEnabledNotifier,
      builder: (_, ttsEnabled, __) {
        if (ttsEnabled && !_loadingTts && _voices.isEmpty && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _bootstrapTts();
          });
        }
        return Narrable(
          text: 'Ativar narração',
          child: SwitchListTile.adaptive(
            value: ttsEnabled,
            onChanged: (value) async {
              await prefs.setTtsEnabled(value);
              TtsService.instance.updateFromPrefs(prefs);
              if (value) {
                await TtsService.instance.ensureUnlockedByUserGesture();
                if (mounted) _bootstrapTts(force: true);
              }
              if (mounted) setState(() {});
            },
            title: const Text('Ativar narração'),
          ),
        );
      },
    );
  }

  Widget _buildVolumeSlider(UserPrefs prefs) {
    final bool canChange = prefs.ttsEnabledNotifier.value;
    final String label =
        'Volume da narração ${(_volume * 100).round()} por cento';
    return _SliderTile(
      label: 'Volume da narração',
      tooltip: label,
      valueLabel: '${(_volume * 100).round()}%',
      slider: Slider(
        value: _volume.clamp(TtsDefaults.volumeMin, TtsDefaults.volumeMax),
        min: TtsDefaults.volumeMin,
        max: TtsDefaults.volumeMax,
        divisions: 8,
        label: '${(_volume * 100).round()}%',
        onChanged: canChange
            ? (value) {
                setState(() => _volume = value);
              }
            : null,
        onChangeEnd: canChange
            ? (value) async {
                await prefs.setTtsVolume(value);
                TtsService.instance.updateFromPrefs(prefs);
              }
            : null,
      ),
    );
  }

  Widget _buildVoiceSelector(BuildContext context, UserPrefs prefs) {
    final bool enabled = prefs.ttsEnabledNotifier.value;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (_loadingTts) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_voices.isEmpty) {
      return Narrable.text(
        _ttsLoadError ?? 'Nenhuma voz de narração disponível.',
        textAlign: TextAlign.start,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: _ttsLoadError == null ? scheme.onSurface : scheme.error,
        ),
      );
    }

    return Narrable(
      text: 'Selecionar voz de narração',
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        value: _voice,
        onChanged: enabled
            ? (value) async {
                if (value == null) return;
                setState(() => _voice = value);
                await prefs.setTtsVoiceName(value);
                TtsService.instance.voiceName = value;
                TtsService.instance.updateFromPrefs(prefs);
                await TtsService.instance.ensureUnlockedByUserGesture();
              }
            : null,
        items: _voices
            .map(
              (voice) => DropdownMenuItem<String>(
                value: voice.name,
                child: Narrable.text(
                  _presentableVoiceName(voice.name),
                  readOnFocus: false,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        decoration: const InputDecoration(
          labelText: 'Voz',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildVoiceActionsRow() {
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: [
          TextButton.icon(
            onPressed: _loadingTts ? null : () => _bootstrapTts(force: true),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Recarregar vozes'),
          ),
          TextButton.icon(
            onPressed: UserPrefs.instance.ttsEnabledNotifier.value
                ? () async {
                    await TtsService.instance.ensureVoicesLoaded();
                    await TtsService.instance.ensureUnlockedByUserGesture();
                    await TtsService.instance.speakQueue(const <String>[
                      'Teste da narração. Se você ouviu esta mensagem, a voz está configurada.',
                    ], category: 'ui');
                  }
                : null,
            icon: const Icon(Icons.volume_up_rounded),
            label: const Text('Testar voz'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextScaleSlider(ThemeProvider tp) {
    final double percent = (tp.textScale * 100).roundToDouble();
    return _SliderTile(
      label: 'Tamanho do texto',
      tooltip: 'Definir tamanho do texto para ${percent.round()} por cento',
      leading: const Narrable(
        text: 'Diminuir tamanho do texto',
        child: Text('A-'),
      ),
      trailing: Narrable(
        text: 'Tamanho do texto ${percent.round()} por cento',
        child: Text(
          '${percent.round()}%',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.74),
          ),
        ),
      ),
      slider: Slider(
        value: tp.textScale,
        min: 0.9,
        max: 1.6,
        divisions: 14,
        label: tp.textScale.toStringAsFixed(2),
        onChanged: (v) => tp.setTextScale(v),
      ),
      trailingLabel: const Narrable(
        text: 'Aumentar tamanho do texto',
        child: Text('A+'),
      ),
    );
  }

  Widget _buildFontSelector(ThemeProvider tp) {
    final Color subtitleColor = Theme.of(
      context,
    ).colorScheme.onSurface.withOpacity(0.7);
    final TextStyle? subtitleStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: subtitleColor);
    final List<Widget> options = AccessibilityFont.values.map((font) {
      final String label = _fontLabel(font);
      final String description = _fontDescription(font);
      return Tooltip(
        message: '$label: $description',
        waitDuration: const Duration(milliseconds: 300),
        child: RadioListTile<AccessibilityFont>(
          contentPadding: EdgeInsets.zero,
          dense: true,
          visualDensity: VisualDensity.compact,
          title: Text(label, softWrap: true),
          subtitle: Text(description, style: subtitleStyle, softWrap: true),
          value: font,
          groupValue: tp.accessibilityFont,
          onChanged: (value) {
            if (value == null) return;
            tp.setAccessibilityFont(value);
          },
        ),
      );
    }).toList();
    return Narrable(
      text: 'Fonte acessível',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Column(children: options)],
      ),
    );
  }

  Widget _buildColorVisionSelector(ThemeProvider tp) {
    final Color subtitleColor = Theme.of(
      context,
    ).colorScheme.onSurface.withOpacity(0.7);
    final TextStyle? subtitleStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: subtitleColor);
    final List<Widget> options = tp.availableCvdTypes.map((type) {
      final String label = _cvdLabel(type);
      final String description = _cvdDescription(type);
      return Tooltip(
        message: '$label: $description',
        waitDuration: const Duration(milliseconds: 300),
        child: RadioListTile<ColorVisionType>(
          contentPadding: EdgeInsets.zero,
          dense: true,
          visualDensity: VisualDensity.compact,
          title: Text(label, softWrap: true),
          subtitle: Text(description, style: subtitleStyle, softWrap: true),
          value: type,
          groupValue: tp.colorVision,
          onChanged: (value) {
            if (value == null) return;
            tp.setColorVision(value);
          },
        ),
      );
    }).toList();
    return Narrable(
      text: 'Daltonismo (simulação/correção)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text('Tipo de visão de cor'),
          ),
          Column(children: options),
        ],
      ),
    );
  }

  List<Widget> _buildExtraSectionWidgets(BuildContext context) {
    if (widget.extraSections.isEmpty) {
      return const <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Nenhuma configuração avançada disponível.',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
      ];
    }
    final List<Widget> items = <Widget>[];
    for (final builder in widget.extraSections) {
      final widgetBuilt = builder(context);
      items.add(widgetBuilt);
    }
    return items;
  }

  Future<void> _handleReset(ThemeProvider tp) async {
    final prefs = UserPrefs.instance;
    await prefs.ensureLoaded();
    _restoreDefaults(tp);
    await prefs.setShowTooltips(true);
    await prefs.setTtsReadUi(false);
    await prefs.setTtsVolume(TtsDefaults.volumeDefault);
    TtsService.instance.updateFromPrefs(prefs);
    if (mounted) {
      setState(() {
        _compactMode = !_isMobile;
        _volume = TtsDefaults.volumeDefault;
        _voice = prefs.ttsVoiceName;
      });
    }
  }

  TtsVoiceOption _preferredVoiceFor(List<TtsVoiceOption> voices) {
    TtsVoiceOption? candidate = _voiceByFragment(voices, 'francisca');
    candidate ??= _voiceByFragment(voices, 'maria');
    candidate ??= voices.first;
    return candidate;
  }

  TtsVoiceOption? _voiceByFragment(
    List<TtsVoiceOption> voices,
    String fragment,
  ) {
    final String needle = fragment.toLowerCase();
    for (final voice in voices) {
      if (voice.name.toLowerCase().contains(needle)) {
        return voice;
      }
    }
    return null;
  }

  String _presentableVoiceName(String rawName) {
    final String trimmed = rawName.trim();
    final String withoutMicrosoft = trimmed.replaceFirst(
      RegExp(r'^\s*Microsoft\s+', caseSensitive: false),
      '',
    );
    return withoutMicrosoft.isEmpty ? trimmed : withoutMicrosoft.trim();
  }

  @override
  void didUpdateWidget(covariant A11yPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layout.isMobile != widget.layout.isMobile) {
      _compactMode = !widget.layout.isMobile;
      _ensureTabController(widget.layout.isMobile);
    }
  }

  @override
  void dispose() {
    _sectionsButtonFocusNode.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  void _ensureTabController(bool forMobileLayout) {
    if (!forMobileLayout) {
      if (_tabController != null) {
        _tabController!.dispose();
        _tabController = null;
      }
      return;
    }
    if (_tabController != null) return;
    _tabController =
        TabController(length: _PanelSection.values.length, vsync: this)
          ..addListener(() {
            if (mounted) setState(() {});
          });
  }

  void _switchToSection(int index) {
    final TabController? controller = _tabController;
    if (controller == null) return;
    if (index < 0 || index >= controller.length) return;
    final bool disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations) {
      controller.index = index;
    } else {
      controller.animateTo(
        index,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _openSectionsMenu() async {
    final TabController? controller = _tabController;
    final BuildContext? buttonContext = _sectionsButtonKey.currentContext;
    if (controller == null || buttonContext == null) return;

    final MediaQueryData media = MediaQuery.of(buttonContext);
    final bool useBottomSheet =
        media.size.width <= _PanelLayout.mobileBreakpoint ||
        media.orientation == Orientation.portrait;
    final List<_PanelSection> sections = _PanelSection.values;
    final int currentIndex = controller.index;

    final TextDirection textDirection = Directionality.of(buttonContext);
    if (WidgetsBinding.instance != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SemanticsService.announce('Escolha uma seção', textDirection);
      });
    }

    int? selectedIndex;
    if (useBottomSheet) {
      selectedIndex = await showModalBottomSheet<int>(
        context: buttonContext,
        useSafeArea: true,
        builder: (sheetContext) {
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            itemBuilder: (context, index) {
              final _PanelSection section = sections[index];
              return Semantics(
                button: true,
                label: 'Ir para ${section.label}',
                child: ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  title: Text(
                    section.label,
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                  selected: index == currentIndex,
                  onTap: () => Navigator.of(sheetContext).pop(index),
                ),
              );
            },
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemCount: sections.length,
          );
        },
      );
    } else {
      final RenderBox? buttonBox =
          buttonContext.findRenderObject() as RenderBox?;
      final RenderBox? overlay =
          Overlay.of(buttonContext).context.findRenderObject() as RenderBox?;
      if (buttonBox == null || overlay == null) {
        FocusScope.of(context).requestFocus(_sectionsButtonFocusNode);
        return;
      }
      final RelativeRect position = RelativeRect.fromRect(
        Rect.fromPoints(
          buttonBox.localToGlobal(Offset.zero, ancestor: overlay),
          buttonBox.localToGlobal(
            buttonBox.size.bottomRight(Offset.zero),
            ancestor: overlay,
          ),
        ),
        Offset.zero & overlay.size,
      );

      selectedIndex = await showMenu<int>(
        context: buttonContext,
        position: position,
        items: sections
            .asMap()
            .entries
            .map(
              (entry) => PopupMenuItem<int>(
                value: entry.key,
                child: Semantics(
                  button: true,
                  label: 'Ir para ${entry.value.label}',
                  child: Text(
                    entry.value.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
              ),
            )
            .toList(),
      );
    }

    if (!mounted) return;

    if (selectedIndex != null) {
      _switchToSection(selectedIndex);
    }

    FocusScope.of(context).requestFocus(_sectionsButtonFocusNode);
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.label,
    required this.slider,
    this.tooltip,
    this.valueLabel,
    this.leading,
    this.trailing,
    this.trailingLabel,
  });

  final String label;
  final Slider slider;
  final String? tooltip;
  final String? valueLabel;
  final Widget? leading;
  final Widget? trailing;
  final Widget? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 8)],
            Expanded(child: slider),
            if (trailingLabel != null) ...[
              const SizedBox(width: 8),
              trailingLabel!,
            ],
            if (valueLabel != null) ...[
              const SizedBox(width: 8),
              Text(
                valueLabel!,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ],
    );

    return tooltip == null
        ? body
        : Tooltip(
            message: tooltip!,
            waitDuration: const Duration(milliseconds: 400),
            child: body,
          );
  }
}

class _PanelContent {
  const _PanelContent({
    required this.layout,
    required this.leituraDeTela,
    required this.legibilidade,
    required this.contrasteCores,
    required this.uiAudio,
    required this.avancado,
  });

  final _PanelLayout layout;
  final List<Widget> leituraDeTela;
  final List<Widget> legibilidade;
  final List<Widget> contrasteCores;
  final List<Widget> uiAudio;
  final List<Widget> avancado;
}

enum _PanelSection {
  leitura(label: 'Leitura de tela'),
  legibilidade(label: 'Legibilidade'),
  contraste(label: 'Contraste e cores'),
  uiAudio(label: 'UI e áudio'),
  avancado(label: 'Avançado');

  const _PanelSection({required this.label});
  final String label;
}

class _PanelLayout {
  const _PanelLayout._(this.isMobile);
  const _PanelLayout.mobile() : this._(true);
  const _PanelLayout.desktop() : this._(false);

  final bool isMobile;

  static const double mobileBreakpoint = 720;
  static const double desktopMaxWidth = 1200;
  static const double desktopMaxHeight = 760;

  _PanelLayout resolve(BoxConstraints constraints) {
    if (constraints.maxWidth <= mobileBreakpoint) {
      return const _PanelLayout.mobile();
    }
    return this;
  }
}

class _DesktopPanel extends StatelessWidget {
  const _DesktopPanel({
    required this.constraints,
    required this.padding,
    required this.content,
    required this.allowTwoColumns,
    required this.compactMode,
    required this.onReset,
    required this.onApply,
    required this.loadingTts,
  });

  final BoxConstraints constraints;
  final EdgeInsets padding;
  final _PanelContent content;
  final bool allowTwoColumns;
  final bool compactMode;
  final VoidCallback onReset;
  final VoidCallback onApply;
  final bool loadingTts;

  @override
  Widget build(BuildContext context) {
    final ScrollPhysics physics = compactMode
        ? const ClampingScrollPhysics()
        : const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics());
    final double spacing = compactMode ? 12 : 16;

    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _PanelHeader(),
          const SizedBox(height: 12),
          Expanded(
            child: ScrollConfiguration(
              behavior: const _A11yPanelScrollBehavior(),
              child: SingleChildScrollView(
                physics: physics,
                child: Column(
                  children: [
                    _DesktopSection(
                      title: _PanelSection.leitura.label,
                      children: content.leituraDeTela,
                      allowTwoColumns: allowTwoColumns,
                      spacing: spacing,
                    ),
                    _DesktopSection(
                      title: _PanelSection.legibilidade.label,
                      children: content.legibilidade,
                      allowTwoColumns: allowTwoColumns,
                      spacing: spacing,
                    ),
                    _DesktopSection(
                      title: _PanelSection.contraste.label,
                      children: content.contrasteCores,
                      allowTwoColumns: allowTwoColumns,
                      spacing: spacing,
                    ),
                    _DesktopSection(
                      title: _PanelSection.uiAudio.label,
                      children: content.uiAudio,
                      allowTwoColumns: allowTwoColumns,
                      spacing: spacing,
                    ),
                    _DesktopSection(
                      title: _PanelSection.avancado.label,
                      children: content.avancado,
                      allowTwoColumns: allowTwoColumns,
                      spacing: spacing,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _PanelActions(onReset: onReset, onApply: onApply),
          if (loadingTts) const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _DesktopSection extends StatelessWidget {
  const _DesktopSection({
    required this.title,
    required this.children,
    required this.allowTwoColumns,
    required this.spacing,
  });

  final String title;
  final List<Widget> children;
  final bool allowTwoColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    final TextStyle? titleStyle = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tooltip(
            message: title,
            child: Text(
              title,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: titleStyle,
            ),
          ),
          const SizedBox(height: 12),
          _ResponsiveWrap(
            children: children,
            allowTwoColumns: allowTwoColumns,
            spacing: spacing,
          ),
        ],
      ),
    );
  }
}

class _ChangeTabIntent extends Intent {
  const _ChangeTabIntent(this.delta);
  final int delta;
}

class _MobilePanel extends StatelessWidget {
  const _MobilePanel({
    required this.tabController,
    required this.content,
    required this.allowTwoColumns,
    required this.compactMode,
    required this.onReset,
    required this.onApply,
    required this.loadingTts,
    required this.onOpenSectionsMenu,
    required this.sectionsButtonFocusNode,
    required this.sectionsButtonKey,
    required this.onSelectSection,
  });

  final TabController tabController;
  final _PanelContent content;
  final bool allowTwoColumns;
  final bool compactMode;
  final VoidCallback onReset;
  final VoidCallback onApply;
  final bool loadingTts;
  final VoidCallback onOpenSectionsMenu;
  final FocusNode sectionsButtonFocusNode;
  final GlobalKey sectionsButtonKey;
  final ValueChanged<int> onSelectSection;

  @override
  Widget build(BuildContext context) {
    final double spacing = compactMode ? 12 : 16;
    final List<_PanelSection> sections = _PanelSection.values;

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.arrowRight): const _ChangeTabIntent(1),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): const _ChangeTabIntent(-1),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _ChangeTabIntent: CallbackAction<_ChangeTabIntent>(
            onInvoke: (intent) {
              final int nextIndex = (tabController.index + intent.delta).clamp(
                0,
                tabController.length - 1,
              );
              if (nextIndex != tabController.index) {
                onSelectSection(nextIndex);
              }
              return null;
            },
          ),
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.24),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const _PanelHeader(),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TabBar(
                      controller: tabController,
                      isScrollable: true,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                      indicatorSize: TabBarIndicatorSize.label,
                      tabs: sections
                          .map(
                            (section) => Tab(
                              child: Tooltip(
                                message: section.label,
                                child: Text(
                                  section.label,
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Semantics(
                    button: true,
                    label: 'Ver outras seções',
                    child: Tooltip(
                      message: 'Lista de seções',
                      child: TextButton.icon(
                        key: sectionsButtonKey,
                        focusNode: sectionsButtonFocusNode,
                        icon: const Icon(Icons.view_list, size: 18),
                        onPressed: onOpenSectionsMenu,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        label: const Text(
                          'Ver outras seções ▸',
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: AnimatedBuilder(
                  animation: tabController,
                  builder: (context, _) {
                    return TabBarView(
                      controller: tabController,
                      physics: const BouncingScrollPhysics(),
                      children: List<Widget>.generate(sections.length, (index) {
                        final _PanelSection section = sections[index];
                        final List<Widget> children = _panelSectionWidgets(
                          content,
                          section,
                        );
                        final bool isActive = tabController.index == index;
                        final bool isLast = index == sections.length - 1;
                        final Widget? footer = isLast
                            ? null
                            : Align(
                                alignment: Alignment.centerRight,
                                child: Semantics(
                                  button: true,
                                  label: 'Ir para ${sections[index + 1].label}',
                                  child: TextButton(
                                    onPressed: () => onSelectSection(index + 1),
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      alignment: Alignment.centerRight,
                                    ),
                                    child: Text(
                                      'Ir para: ${sections[index + 1].label} »',
                                      maxLines: 2,
                                      softWrap: true,
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ),
                              );
                        return _MobileSectionPage(
                          key: PageStorageKey<String>('a11y-tab-$index'),
                          children: children,
                          allowTwoColumns: allowTwoColumns,
                          spacing: spacing,
                          attachPrimary: isActive,
                          footer: footer,
                        );
                      }),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              _PanelActions(
                onReset: onReset,
                onApply: onApply,
                alignment: Alignment.centerRight,
              ),
              if (loadingTts) const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}

List<Widget> _panelSectionWidgets(
  _PanelContent content,
  _PanelSection section,
) {
  switch (section) {
    case _PanelSection.leitura:
      return content.leituraDeTela;
    case _PanelSection.legibilidade:
      return content.legibilidade;
    case _PanelSection.contraste:
      return content.contrasteCores;
    case _PanelSection.uiAudio:
      return content.uiAudio;
    case _PanelSection.avancado:
      return content.avancado;
  }
}

class _MobileSectionPage extends StatelessWidget {
  const _MobileSectionPage({
    super.key,
    required this.children,
    required this.allowTwoColumns,
    required this.spacing,
    required this.attachPrimary,
    this.footer,
  });

  final List<Widget> children;
  final bool allowTwoColumns;
  final double spacing;
  final bool attachPrimary;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final TargetPlatform platform = Theme.of(context).platform;
    final bool useBouncingPhysics =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    final ScrollPhysics physics = useBouncingPhysics
        ? const BouncingScrollPhysics()
        : const ClampingScrollPhysics();

    return ScrollConfiguration(
      behavior: const _A11yPanelScrollBehavior(),
      child: ListView(
        primary: attachPrimary,
        physics: physics,
        padding: EdgeInsets.zero,
        children: [
          _ResponsiveWrap(
            children: children,
            spacing: spacing,
            allowTwoColumns: allowTwoColumns,
          ),
          if (footer != null)
            Padding(padding: const EdgeInsets.only(top: 12), child: footer!),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _A11yPanelScrollBehavior extends ScrollBehavior {
  const _A11yPanelScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({this.alignment = Alignment.centerLeft});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800);
    final Widget title = Tooltip(
      message: 'Acessibilidade',
      child: Text(
        'Acessibilidade',
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );

    return Align(alignment: alignment, child: title);
  }
}

class _PanelActions extends StatelessWidget {
  const _PanelActions({
    required this.onReset,
    required this.onApply,
    this.alignment = Alignment.centerRight,
  });

  final VoidCallback onReset;
  final VoidCallback onApply;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final Wrap buttons = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        OutlinedButton(onPressed: onReset, child: const Text('Resetar')),
        FilledButton.icon(
          onPressed: onApply,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Aplicar'),
        ),
      ],
    );

    return Align(alignment: alignment, child: buttons);
  }
}

class _ResponsiveWrap extends StatelessWidget {
  const _ResponsiveWrap({
    required this.children,
    required this.allowTwoColumns,
    required this.spacing,
  });

  final List<Widget> children;
  final bool allowTwoColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final bool canTwoColumns =
            allowTwoColumns && maxWidth >= 600 && children.length > 1;
        final double itemWidth = canTwoColumns
            ? (maxWidth - spacing) / 2
            : maxWidth;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }
}

void _restoreDefaults(ThemeProvider tp) {
  tp.setDark(false);
  tp.setHighContrast(false);
  tp.setReduceMotion(false);
  tp.setTextScale(1.0);
  tp.setColorVision(ColorVisionType.normal);
  tp.setAccessibilityFont(AccessibilityFont.none);
}

String _cvdLabel(ColorVisionType t) {
  switch (t) {
    case ColorVisionType.normal:
      return 'Normal';
    case ColorVisionType.protanopia:
      return 'Protanopia';
    case ColorVisionType.deuteranopia:
      return 'Deuteranopia';
    case ColorVisionType.tritanopia:
      return 'Tritanopia';
    case ColorVisionType.achromatopsia:
      return 'Acromatopsia';
  }
}

String _cvdDescription(ColorVisionType type) {
  switch (type) {
    case ColorVisionType.normal:
      return 'Sem correção aplicada.';
    case ColorVisionType.protanopia:
      return 'Compensa a ausência de percepção do vermelho.';
    case ColorVisionType.deuteranopia:
      return 'Compensa a ausência de percepção do verde.';
    case ColorVisionType.tritanopia:
      return 'Compensa a ausência de percepção do azul.';
    case ColorVisionType.achromatopsia:
      return 'Converte para tons neutros em escala de cinza.';
  }
}

String _fontLabel(AccessibilityFont f) {
  switch (f) {
    case AccessibilityFont.none:
      return 'Nenhum';
    case AccessibilityFont.arial:
      return 'Arial';
    case AccessibilityFont.comicSans:
      return 'Comic Sans';
    case AccessibilityFont.openDyslexic:
      return 'OpenDyslexic';
  }
}

String _fontDescription(AccessibilityFont font) {
  switch (font) {
    case AccessibilityFont.none:
      return 'Mantém a fonte padrão do aplicativo.';
    case AccessibilityFont.arial:
      return 'Fonte sem serifa, legível em telas e interfaces.';
    case AccessibilityFont.comicSans:
      return 'Letras arredondadas que ajudam alguns leitores novos.';
    case AccessibilityFont.openDyslexic:
      return 'Fonte projetada para reduzir confusões comuns na dislexia.';
  }
}
