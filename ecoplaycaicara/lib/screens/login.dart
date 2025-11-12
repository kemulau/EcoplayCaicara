import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/pixel_button.dart';
import '../widgets/game_frame.dart';
import '../widgets/link_button.dart';
import '../app_scroll_behavior.dart';
import 'cadastro.dart';
import 'home.dart';
import '../widgets/narrable.dart';
import '../services/backend_client.dart';
import '../widgets/form_section_card.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  String email = '';
  String senha = '';
  bool _autenticando = false;
  String? _erro;

  Future<void> _realizarLogin() async {
    if (_autenticando) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _autenticando = true;
      _erro = null;
    });

    final backend = BackendClient.instance;
    try {
      await backend.login(email.trim(), senha);
      if (!mounted) return;
      _mostrarSnackBar('Login realizado com sucesso!');
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } on BackendException catch (e) {
      final message = e.message.isNotEmpty
          ? e.message
          : 'Não foi possível realizar o login.';
      if (!mounted) return;
      setState(() => _erro = message);
      _mostrarSnackBar(message, erro: true);
    } on TimeoutException {
      const message = 'Tempo esgotado ao contatar o servidor. Tente novamente.';
      if (!mounted) return;
      setState(() => _erro = message);
      _mostrarSnackBar(message, erro: true);
    } catch (_) {
      const message = 'Falha inesperada ao tentar entrar.';
      if (!mounted) return;
      setState(() => _erro = message);
      _mostrarSnackBar(message, erro: true);
    } finally {
      if (mounted) {
        setState(() => _autenticando = false);
      }
    }
  }

  Future<void> _entrarComoVisitante() async {
    if (_autenticando) return;
    FocusScope.of(context).unfocus();
    setState(() => _erro = null);
    final backend = BackendClient.instance;
    await backend.clearSession();
    if (!mounted) return;
    _mostrarSnackBar('Modo visitante ativado. Pontuações não serão salvas.');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  void _mostrarSnackBar(String mensagem, {bool erro = false}) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: erro
            ? theme.colorScheme.error
            : theme.colorScheme.primary,
        content: Narrable.text(
          mensagem,
          readOnFocus: false,
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
        ),
      ),
    );
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
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FormSectionCard(
                    icon: Icons.key_rounded,
                    title: 'Acesse sua conta',
                    description: 'Use o mesmo email e senha do cadastro.',
                    child: Column(
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FormSectionCard(
                    icon: Icons.flag_circle_outlined,
                    title: 'Como deseja entrar?',
                    description: 'Escolha a forma de acesso para seguir.',
                    child: Column(
                      children: [
                        Center(
                          child: IgnorePointer(
                            ignoring: _autenticando,
                            child: PixelButton(
                              label: _autenticando ? 'Entrando...' : 'Entrar',
                              icon: Icons.login_rounded,
                              iconRight: true,
                              onPressed: () {
                                if (_formKey.currentState!.validate()) {
                                  _realizarLogin();
                                }
                              },
                              width: 220,
                              height: 60,
                            ),
                          ),
                        ),
                        if (_autenticando) ...[
                          const SizedBox(height: 12),
                          const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ],
                        if (!_autenticando && _erro != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _erro!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        PixelButton(
                          label: 'Jogar como visitante',
                          icon: Icons.person_outline,
                          onPressed: _entrarComoVisitante,
                          width: 220,
                          height: 52,
                        ),
                        const SizedBox(height: 12),
                        LinkButton(
                          label: 'Não tem conta? Cadastre-se',
                          alignment: Alignment.center,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const CadastroJogadorScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
    final scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color fillColor = scheme.surfaceVariant.withOpacity(
      isDark ? 0.3 : 0.85,
    );
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(
        color: scheme.primary.withOpacity(0.25),
        width: 1.2,
      ),
    );

    return Narrable(
      text: label,
      tooltip: hint ?? label,
      child: TextFormField(
        obscureText: obscure,
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          label: Narrable.text(label, readOnFocus: false),
          hint: hint == null ? null : Narrable.text(hint, readOnFocus: false),
          filled: true,
          fillColor: fillColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(color: scheme.primary, width: 1.6),
          ),
        ),
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }
}
