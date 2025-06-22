import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

final ThemeData retroGameTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: const Color(0xFF8B4B35),
  scaffoldBackgroundColor: const Color(0xFFF5F0E1),

  textTheme: GoogleFonts.pressStart2pTextTheme().copyWith(
    titleLarge: GoogleFonts.pressStart2p(
      fontSize: 18,
      color: Colors.brown,
    ),
    bodyMedium: GoogleFonts.pressStart2p(
      fontSize: 12,
      color: Colors.black,
    ),
  ),

  appBarTheme: AppBarTheme(
    backgroundColor: const Color(0xFF8B4B35),
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: GoogleFonts.pressStart2p(
      fontSize: 14,
      color: Colors.white,
    ),
    shape: const Border(
      bottom: BorderSide(color: Color(0xFF442A1B), width: 4),
    ),
  ),

  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    labelStyle: GoogleFonts.pressStart2p(fontSize: 10, color: Color(0xFF333333)),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: const BorderSide(color: Color(0xFF6B4226), width: 2),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: const BorderSide(color: Color(0xFF6B4226), width: 2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: const BorderSide(color: Color(0xFFDBA159), width: 2),
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
    thumbColor: WidgetStateProperty.all(const Color(0xFFECA400)),
    trackColor: WidgetStateProperty.all(const Color(0xFF8B4B35)),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF6B4226),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      textStyle: GoogleFonts.pressStart2p(fontSize: 12),
      elevation: 4,
      shadowColor: const Color(0xFF442A1B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2),
        side: const BorderSide(color: Colors.black, width: 1),
      ),
    ),
  ),
);
