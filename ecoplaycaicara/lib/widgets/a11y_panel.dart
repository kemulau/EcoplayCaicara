// [A11Y] Painel de acessibilidade (mesma base do cadastro, ligado ao ThemeProvider)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/theme_provider.dart';
import '../theme/color_blindness.dart';
import 'pixel_button.dart';

class A11yPanel extends StatelessWidget {
  const A11yPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      child: Material(
        color: scheme.surface.withOpacity(theme.brightness == Brightness.dark ? 0.98 : 1.0),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Consumer<ThemeProvider>(
            builder: (context, tp, _) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // grab handle
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: scheme.onSurface.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    Text(
                      'Acessibilidade',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Modo escuro
                    SwitchListTile.adaptive(
                      value: tp.isDark,
                      onChanged: (v) => tp.setDark(v),
                      title: const Text('Modo escuro'),
                      contentPadding: EdgeInsets.zero,
                    ),

                    // Alto contraste
                    SwitchListTile.adaptive(
                      value: tp.highContrast,
                      onChanged: (v) => tp.setHighContrast(v),
                      title: const Text('Alto contraste'),
                      contentPadding: EdgeInsets.zero,
                    ),

                    Semantics(
                      container: true,
                      label: 'Reduzir movimento',
                      hint: 'Minimiza animações e efeitos intensos',
                      toggled: tp.reduceMotion,
                      child: SwitchListTile.adaptive(
                        value: tp.reduceMotion,
                        onChanged: (v) => tp.setReduceMotion(v),
                        title: const Text('Reduzir movimento'),
                        subtitle: const Text('Limita animações, tremores e efeitos exagerados'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Tamanho do texto
                    _Section(title: 'Tamanho do texto'),
                    Row(
                      children: [
                        const Text('A-'),
                        Expanded(
                          child: Slider(
                            value: tp.textScale,
                            min: 0.9,
                            max: 1.6,
                            divisions: 14, // passos de ~0.05
                            label: tp.textScale.toStringAsFixed(2),
                            onChanged: (v) => tp.setTextScale(v),
                          ),
                        ),
                        const Text('A+'),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${(tp.textScale * 100).round()}%',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Daltonismo
                    _Section(title: 'Daltonismo (simulação/correção)'),
                    DropdownButtonFormField<ColorVisionType>(
                      value: tp.colorVision,
                      onChanged: (v) {
                        if (v != null) tp.setColorVision(v);
                      },
                      items: tp.availableCvdTypes
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(_cvdLabel(t)),
                              ))
                          .toList(),
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Tipo de visão de cor',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Fonte acessível
                    _Section(title: 'Fonte acessível'),
                    DropdownButtonFormField<AccessibilityFont>(
                      value: tp.accessibilityFont,
                      onChanged: (v) {
                        if (v != null) tp.setAccessibilityFont(v);
                      },
                      items: AccessibilityFont.values
                          .map((f) => DropdownMenuItem(
                                value: f,
                                child: Text(_fontLabel(f)),
                              ))
                          .toList(),
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Fonte',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Ações
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => _restoreDefaults(tp),
                          child: const Text('Restaurar padrões'),
                        ),
                        const Spacer(),
                        PixelButton(
                          label: 'Fechar',
                          iconRight: true,
                          icon: Icons.check_rounded,
                          width: 160,
                          height: 46,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  static void _restoreDefaults(ThemeProvider tp) {
    tp.setDark(false);
    tp.setHighContrast(false);
    tp.setReduceMotion(false);
    tp.setTextScale(1.0);
    tp.setColorVision(ColorVisionType.normal);
    tp.setAccessibilityFont(AccessibilityFont.none);
  }

  static String _cvdLabel(ColorVisionType t) {
    // Tenta nomes amigáveis; fallback para enum.name
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
      default:
        return t.name;
    }
  }

  static String _fontLabel(AccessibilityFont f) {
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
}

class _Section extends StatelessWidget {
  const _Section({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.primary.withOpacity(0.35), width: 1.5),
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}
