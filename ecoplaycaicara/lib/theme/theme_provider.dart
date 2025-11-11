import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'color_blindness.dart';
import 'base_theme.dart';
import 'game_styles.dart';
import 'game_chrome.dart';
import 'book_theme.dart';

class ThemeProvider with ChangeNotifier {
  ThemeProvider() {
    loadPreferences();
  }

  // Estado
  bool isDark = false;
  bool highContrast = false;
  bool reduceMotion = false;
  bool largeText = false; // toggle legado
  double textScale = 1.0; // 0.8..2.0
  ColorVisionType colorVision = ColorVisionType.normal;
  List<ColorVisionType> get availableCvdTypes => ColorVisionType.values;
  AppPalette palette = AppPalette.teal;
  AccessibilityFont accessibilityFont = AccessibilityFont.none;

  // Chaves de persistência
  static const _kDark = 'theme.dark';
  static const _kHighContrast = 'a11y.high_contrast';
  static const _kReduceMotion = 'a11y.reduce_motion';
  static const _kLargeText = 'a11y.large_text';
  static const _kCvdType = 'a11y.cvd_type';
  static const _kPalette = 'theme.palette';
  static const _kTextScale = 'a11y.text_scale';
  static const _kA11yFont = 'a11y.font';

  // Carregar preferências
  Future<void> loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Migração: usa chaves antigas se as novas não existirem
      isDark = prefs.getBool(_kDark) ?? prefs.getBool('modoEscuro') ?? false;
      highContrast =
          prefs.getBool(_kHighContrast) ??
          prefs.getBool('textoAltoContraste') ??
          false;
      largeText =
          prefs.getBool(_kLargeText) ?? prefs.getBool('textoGrande') ?? false;
      textScale = prefs.getDouble(_kTextScale) ?? (largeText ? 1.3 : 1.0);
      colorVision = cvdFromStorage(
        prefs.getString(_kCvdType) ?? prefs.getString('cvdTipo'),
      );
      palette = _paletteFromStorage(prefs.getString(_kPalette));
      final legacyPaletteLabel = prefs.getString('temaPaleta');
      if (legacyPaletteLabel != null) {
        palette = _paletteFromLabel(legacyPaletteLabel);
      }
      final fontLabel =
          prefs.getString(_kA11yFont) ?? prefs.getString('fonteDislexia');
      accessibilityFont = fontFromStorage(fontLabel);
    } catch (error, stack) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('SharedPreferences load failed: $error');
        debugPrintStack(stackTrace: stack);
      }
    }
    notifyListeners();
  }

  // Setters
  Future<void> setDark(bool value) async {
    isDark = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDark, value);
    notifyListeners();
  }

  Future<void> setHighContrast(bool value) async {
    highContrast = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHighContrast, value);
    notifyListeners();
  }

  Future<void> setReduceMotion(bool value) async {
    reduceMotion = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kReduceMotion, value);
    notifyListeners();
  }

  Future<void> setLargeText(bool value) async {
    largeText = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLargeText, value);
    // mantém textScale em sincronia com o toggle legado
    textScale = value ? 1.3 : 1.0;
    await prefs.setDouble(_kTextScale, textScale);
    notifyListeners();
  }

  Future<void> setTextScale(double value) async {
    final double v = value.clamp(0.8, 2.0).toDouble();
    textScale = v;
    largeText = v > 1.05;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kTextScale, textScale);
    await prefs.setBool(_kLargeText, largeText);
    notifyListeners();
  }

  Future<void> setColorVision(ColorVisionType type) async {
    colorVision = type;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCvdType, cvdToStorage(type));
    notifyListeners();
  }

  Future<void> setPalette(AppPalette value) async {
    palette = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPalette, _paletteToStorage(value));
    notifyListeners();
  }

  Future<void> setAccessibilityFont(AccessibilityFont value) async {
    accessibilityFont = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kA11yFont, fontToStorage(value));
    notifyListeners();
  }

  /// Filtro de cor global para simulação/correção de daltonismo
  ColorFilter get colorBlindnessFilter => colorFilterFor(colorVision);

  /// Tema do app: compõe o retroGameTheme com ajustes de acessibilidade
  ThemeData get currentTheme {
    final base = baseGameTheme;

    final brightness = isDark ? Brightness.dark : Brightness.light;
    final seed = _seedForPalette(palette);
    var scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);

    if (highContrast) {
      final bg = brightness == Brightness.dark ? Colors.black : Colors.white;
      final onBg = brightness == Brightness.dark ? Colors.white : Colors.black;
      scheme = scheme.copyWith(
        background: bg,
        surface: bg,
        onBackground: onBg,
        onSurface: onBg,
        primary: brightness == Brightness.dark
            ? Colors.tealAccent
            : Colors.teal.shade800,
        onPrimary: Colors.black,
      );
    }

    // Fonte ativa: acessível ou PressStart2P como padrão
    final String activeFontFamily =
        fontFamilyFor(accessibilityFont) ?? 'PressStart2P';

    // TextTheme com a família ativa
    TextTheme themedText = base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    themedText = _withFontFamily(themedText, activeFontFamily);

    // AppBar
    final appBarTitle =
        (base.appBarTheme.titleTextStyle ?? const TextStyle(fontSize: 14))
            .copyWith(fontFamily: activeFontFamily, color: scheme.onPrimary);

    // ElevatedButton com a fonte ativa
    final baseBtnStyle = base.elevatedButtonTheme.style ?? const ButtonStyle();
    final btnStyle = baseBtnStyle.copyWith(
      textStyle: MaterialStatePropertyAll(
        TextStyle(fontFamily: activeFontFamily, fontSize: 12),
      ),
    );

    // Inputs adotam a fonte ativa (sem usar copyWith que retorna *Data* na sua SDK)
    final inputBase = _buildInputDecorationTheme(
      base,
      scheme,
      brightness,
      highContrast,
    );
    final inputTheme = InputDecorationTheme(
      filled: inputBase.filled,
      fillColor: inputBase.fillColor,
      labelStyle: (inputBase.labelStyle ?? const TextStyle()).copyWith(
        fontFamily: activeFontFamily,
      ),
      hintStyle: inputBase.hintStyle,
      border: inputBase.border,
      enabledBorder: inputBase.enabledBorder,
      focusedBorder: inputBase.focusedBorder,
      errorBorder: inputBase.errorBorder,
      focusedErrorBorder: inputBase.focusedErrorBorder,
    );

    ThemeData theme = base.copyWith(
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.background,
      canvasColor: scheme.background,
      inputDecorationTheme: inputTheme,
      // Escala de texto é aplicada via MediaQuery (ver main.dart)
      textTheme: themedText,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        titleTextStyle: appBarTitle,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: btnStyle),
      extensions: <ThemeExtension<dynamic>>[
        GameStyles.fromScheme(scheme, fontFamily: activeFontFamily),
        GameChrome.fromScheme(scheme),
        BookTheme.standard,
      ],
    );

    if (reduceMotion) {
      const PageTransitionsTheme noTransitions = PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: NoAnimationsPageTransitionsBuilder(),
          TargetPlatform.iOS: NoAnimationsPageTransitionsBuilder(),
          TargetPlatform.macOS: NoAnimationsPageTransitionsBuilder(),
          TargetPlatform.windows: NoAnimationsPageTransitionsBuilder(),
          TargetPlatform.linux: NoAnimationsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: NoAnimationsPageTransitionsBuilder(),
        },
      );

      theme = theme.copyWith(
        pageTransitionsTheme: noTransitions,
        splashFactory: NoSplash.splashFactory,
        hoverColor: theme.colorScheme.primary.withOpacity(0.04),
        focusColor: theme.colorScheme.primary.withOpacity(0.14),
        highlightColor: Colors.transparent,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        snackBarTheme: theme.snackBarTheme.copyWith(
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    return theme;
  }
}

enum AppPalette { teal, blue, green, amber, purple }

String _paletteToStorage(AppPalette p) => p.name;

AppPalette _paletteFromStorage(String? value) {
  if (value == null) return AppPalette.teal;
  return AppPalette.values.firstWhere(
    (e) => e.name == value,
    orElse: () => AppPalette.teal,
  );
}

Color _seedForPalette(AppPalette p) {
  switch (p) {
    case AppPalette.teal:
      // Earthy default
      return const Color(0xFF7A5230); // saddle brown
    case AppPalette.blue:
      return Colors.blue;
    case AppPalette.green:
      return const Color(0xFF4F6F52); // moss green
    case AppPalette.amber:
      return const Color(0xFFD29B59); // sand/amber
    case AppPalette.purple:
      return const Color(0xFF6E4E74); // muted plum
  }
}

AppPalette _paletteFromLabel(String label) {
  switch (label) {
    case 'Azul':
      return AppPalette.blue;
    case 'Verde':
      return AppPalette.green;
    case 'Âmbar':
      return AppPalette.amber;
    case 'Roxo':
      return AppPalette.purple;
    case 'Turquesa':
    default:
      return AppPalette.teal;
  }
}

/// Cria um InputDecorationTheme compatível com a sua SDK
InputDecorationTheme _buildInputDecorationTheme(
  ThemeData base,
  ColorScheme scheme,
  Brightness brightness,
  bool highContrast,
) {
  final baseInput = base.inputDecorationTheme;
  final fill = brightness == Brightness.dark
      ? scheme.surface.withOpacity(highContrast ? 0.18 : 0.12)
      : Colors.white.withOpacity(highContrast ? 1.0 : 0.95);
  final borderColor = highContrast
      ? scheme.onSurface
      : (brightness == Brightness.dark
            ? scheme.outline.withOpacity(0.6)
            : const Color(0xFF6B4226));

  OutlineInputBorder outline(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(4),
    borderSide: BorderSide(color: c, width: 2),
  );

  return InputDecorationTheme(
    filled: true,
    fillColor: fill,
    labelStyle:
        (baseInput.labelStyle?.copyWith(color: scheme.onSurface)) ??
        TextStyle(color: scheme.onSurface, fontSize: 12),
    hintStyle: TextStyle(
      // se seu SDK marcar withOpacity como deprecated, pode trocar por:
      // scheme.onSurface.withAlpha((0.7 * 255).round())
      color: scheme.onSurface.withOpacity(0.7),
      fontSize: 12,
    ),
    border: outline(borderColor),
    enabledBorder: outline(borderColor),
    focusedBorder: outline(scheme.primary),
    errorBorder: outline(Colors.red),
    focusedErrorBorder: outline(Colors.redAccent),
  );
}

// --- Fontes Acessibilidade ---
enum AccessibilityFont { none, arial, comicSans, openDyslexic }

String fontToStorage(AccessibilityFont f) {
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

AccessibilityFont fontFromStorage(String? label) {
  switch (label) {
    case 'Arial':
      return AccessibilityFont.arial;
    case 'Comic Sans':
    case 'Comic Sans MS':
      return AccessibilityFont.comicSans;
    case 'OpenDyslexic':
      return AccessibilityFont.openDyslexic;
    case 'Nenhum':
    default:
      return AccessibilityFont.none;
  }
}

/// Retorna a família de fonte a usar para o texto padrão
/// (null => mantém a fonte do tema base).
String? fontFamilyFor(AccessibilityFont font) {
  switch (font) {
    case AccessibilityFont.none:
      return null;
    case AccessibilityFont.arial:
      return 'Arial';
    case AccessibilityFont.comicSans:
      return 'ComicSansLdf';
    case AccessibilityFont.openDyslexic:
      return 'OpenDyslexic';
  }
}

TextTheme _withFontFamily(TextTheme base, String family) {
  TextStyle? apply(TextStyle? s) => s?.copyWith(fontFamily: family);
  return TextTheme(
    displayLarge: apply(base.displayLarge),
    displayMedium: apply(base.displayMedium),
    displaySmall: apply(base.displaySmall),
    headlineLarge: apply(base.headlineLarge),
    headlineMedium: apply(base.headlineMedium),
    headlineSmall: apply(base.headlineSmall),
    titleLarge: apply(base.titleLarge),
    titleMedium: apply(base.titleMedium),
    titleSmall: apply(base.titleSmall),
    bodyLarge: apply(base.bodyLarge),
    bodyMedium: apply(base.bodyMedium),
    bodySmall: apply(base.bodySmall),
    labelLarge: apply(base.labelLarge),
    labelMedium: apply(base.labelMedium),
    labelSmall: apply(base.labelSmall),
  );
}

/// Transições sem animação (usado quando reduceMotion = true)
class NoAnimationsPageTransitionsBuilder extends PageTransitionsBuilder {
  const NoAnimationsPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
