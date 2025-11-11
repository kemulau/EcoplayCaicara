import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/pixel_button.dart';
import '../widgets/game_frame.dart';
import '../widgets/link_button.dart';
import '../app_scroll_behavior.dart';
import 'cadastro.dart';
import 'home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  String email = '';
  String senha = '';

  Future<void> _realizarLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('email');
    final savedSenha = prefs.getString('senha');

    if (savedEmail == email && savedSenha == senha) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Login realizado com sucesso!',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white),
            ),
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Email ou senha inválidos',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.white),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GameScaffold(
      title: 'Login',
      child: ScrollConfiguration(
        behavior: const AppScrollBehavior(),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                              _buildTextField(
                                'Email',
                                theme,
                                hint: 'Digite seu email',
                                onChanged: (v) => email = v,
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Campo obrigatório';
                                  }
                                  if (!v.contains('@')) return 'Email inválido';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              _buildTextField(
                                'Senha',
                                theme,
                                hint: 'Digite sua senha',
                                obscure: true,
                                onChanged: (v) => senha = v,
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Campo obrigatório';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 30),
                              Center(
                                child: PixelButton(
                                  label: 'Entrar',
                                  onPressed: () {
                                    if (_formKey.currentState!.validate()) {
                                      _realizarLogin();
                                    }
                                  },
                                  width: 220,
                                  height: 60,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Center(
                                child: LinkButton(
                                  label: 'Não tem conta? Cadastre-se',
                                  alignment: Alignment.center,
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const CadastroJogadorScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                    ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    ThemeData theme, {
    String? hint,
    bool obscure = false,
    required Function(String) onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      obscureText: obscure,
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
      onChanged: onChanged,
      validator: validator,
    );
  }
}
