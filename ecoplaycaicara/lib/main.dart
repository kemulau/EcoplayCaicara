import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/cadastro.dart';
import 'theme/retro.dart';


void main() {
  runApp(const EcoplayCaicaraApp());
}

class EcoplayCaicaraApp extends StatelessWidget {
  const EcoplayCaicaraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ecoplay Caiçara',
      debugShowCheckedModeBanner: false,
      theme: retroGameTheme.copyWith(
        textTheme: GoogleFonts.pressStart2pTextTheme(),
      ),
      home: const CadastroJogadorScreen(),
    );
  }
}

