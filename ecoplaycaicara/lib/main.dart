import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/cadastro.dart';
import 'theme/retro.dart';

void main() {
  runApp(const EcoplayCaicaraCadastroApp());
}

class EcoplayCaicaraCadastroApp extends StatelessWidget {
  const EcoplayCaicaraCadastroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ecoplay Caiçara - Cadastro',
      debugShowCheckedModeBanner: false,
      theme: retroGameTheme.copyWith(
        textTheme: GoogleFonts.pressStart2pTextTheme(),
      ),
      home: const CadastroJogadorScreen(),
    );
  }
}
