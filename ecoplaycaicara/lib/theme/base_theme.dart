import 'package:flutter/material.dart';
// Removemos GoogleFonts para evitar fetch em Web.

// Base visual do app (tons terrosos). As variações e ajustes finos
// são aplicados via ThemeProvider (ColorScheme.fromSeed, highContrast etc.).
final ThemeData baseGameTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: const Color(0xFFF3EEE6),
  primaryColor: const Color(0xFF7A5230),

  // Use fonte local 'PressStart2P' para evitar requisições externas no Web.
  fontFamily: 'PressStart2P',
  textTheme: const TextTheme(
    // Estes estilos são base; ThemeProvider ajusta cores posteriormente.
    titleLarge: TextStyle(
      fontSize: 18,
      color: Color(0xFF523823),
      fontFamily: 'PressStart2P',
    ),
    bodyMedium: TextStyle(
      fontSize: 12,
      color: Color(0xFF2B241E),
      fontFamily: 'PressStart2P',
    ),
  ),

  appBarTheme: const AppBarTheme(
    backgroundColor: const Color(0xFF6D4A2F),
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(fontFamily: 'PressStart2P', fontSize: 14, color: Colors.white),
    shape: const Border(
      bottom: BorderSide(color: Color(0xFF3F2A1D), width: 4),
    ),
  ),

  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white.withOpacity(0.95),
    labelStyle: const TextStyle(fontFamily: 'PressStart2P', fontSize: 10, color: Color(0xFF3A2C20)),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: const BorderSide(color: Color(0xFF6B4E33), width: 2),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: const BorderSide(color: Color(0xFF6B4E33), width: 2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: const BorderSide(color: Color(0xFFD29B59), width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: const BorderSide(color: Colors.red, width: 2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: const BorderSide(color: Colors.redAccent, width: 2),
    ),
  ),

  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return const Color(0xFFD29B59);
      return const Color(0xFFB08C6B);
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return const Color(0xFF5E3E27);
      return const Color(0xFF8C6A4C);
    }),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF6D4A2F),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      textStyle: const TextStyle(fontFamily: 'PressStart2P', fontSize: 12),
      elevation: 6,
      shadowColor: const Color(0xFF3F2A1D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF3F2A1D), width: 1),
      ),
    ),
  ),
);
