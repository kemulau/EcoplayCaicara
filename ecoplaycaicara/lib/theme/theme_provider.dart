import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  bool isDark = false;
  bool highContrast = false;
  bool largeText = false;

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    isDark = prefs.getBool('modoEscuro') ?? false;
    highContrast = prefs.getBool('textoAltoContraste') ?? false;
    largeText = prefs.getBool('textoGrande') ?? false;
    notifyListeners();
  }

  Future<void> updatePreferences({
    required bool dark,
    required bool contrast,
    required bool large,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('modoEscuro', dark);
    await prefs.setBool('textoAltoContraste', contrast);
    await prefs.setBool('textoGrande', large);
    await loadPreferences();
  }

  ThemeData get currentTheme {
    return ThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: isDark ? Colors.teal : Colors.blue,
        brightness: isDark ? Brightness.dark : Brightness.light,
      ),
      textTheme: (isDark ? ThemeData.dark() : ThemeData.light()).textTheme.apply(
        fontSizeFactor: largeText ? 1.3 : 1.0,
        bodyColor: highContrast ? Colors.white : null,
        displayColor: highContrast ? Colors.white : null,
      ),
    );
  }
}
