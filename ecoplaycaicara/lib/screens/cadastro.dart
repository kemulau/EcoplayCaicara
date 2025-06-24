import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/pixel_button.dart';
import 'home.dart';
import 'login.dart';

class CadastroJogadorScreen extends StatefulWidget {
  const CadastroJogadorScreen({super.key});

  @override
  State<CadastroJogadorScreen> createState() => _CadastroJogadorScreenState();
}

class _CadastroJogadorScreenState extends State<CadastroJogadorScreen> {
  final _formKey = GlobalKey<FormState>();

  String nome = '';
  String email = '';
  String senha = '';
  String avatar = '';

  bool mostrarAcessibilidade = false;
  bool textoAltoContraste = false;
  bool textoGrande = false;
  bool audioGuiado = false;
  bool modoEscuro = false;
  bool leituraTela = false;
  bool reducaoMovimento = false;
  bool tecladoAdaptado = false;

  String modoDaltonismoSelecionado = 'Nenhum';
  String fonteDyslexiaSelecionada = 'Nenhum';

  final List<String> avatares = [
    'lib/assets/avatares/1.png',
    'lib/assets/avatares/2.png',
    'lib/assets/avatares/3.png',
    'lib/assets/avatares/caranguejo-uca.png',
    'lib/assets/avatares/jaguatirica.png',
    'lib/assets/avatares/guara-vermelho.png',
  ];

  int avatarIndex = 0;

  @override
  void initState() {
    super.initState();
    avatar = avatares[0];
  }

  Future<void> salvarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nome', nome);
    await prefs.setString('email', email);
    await prefs.setString('senha', senha);
    await prefs.setString('avatar', avatar);

    await prefs.setBool('textoAltoContraste', textoAltoContraste);
    await prefs.setBool('textoGrande', textoGrande);
    await prefs.setBool('audioGuiado', audioGuiado);
    await prefs.setBool('modoEscuro', modoEscuro);
    await prefs.setBool('leituraTela', leituraTela);
    await prefs.setBool('reducaoMovimento', reducaoMovimento);
    await prefs.setBool('tecladoAdaptado', tecladoAdaptado);

    await prefs.setString('modoDaltonismo', modoDaltonismoSelecionado);
    await prefs.setString('fonteDislexia', fonteDyslexiaSelecionada);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = textoAltoContraste || modoEscuro;
    final escalaTexto = textoGrande ? 1.4 : 1.0;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaleFactor: escalaTexto),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Cadastro de Jogador', style: theme.appBarTheme.titleTextStyle),
          backgroundColor: isDark ? Colors.teal : theme.appBarTheme.backgroundColor,
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset('lib/assets/images/background.png', fit: BoxFit.cover),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                return Center(
                  child: ScrollConfiguration(
                    behavior: const ScrollBehavior().copyWith(overscroll: false, scrollbars: false),
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth < 600 ? double.infinity : 600,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.black.withOpacity(0.7)
                                : Colors.white.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildTextField(
                                  'Nome',
                                  theme,
                                  hint: 'Digite seu nickname',
                                  onChanged: (val) => nome = val,
                                  validator: (val) {
                                    if (val == null || val.isEmpty) return 'Campo obrigatório';
                                    if (val.length < 3) return 'Nome muito curto';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                _buildTextField(
                                  'Email',
                                  theme,
                                  hint: 'Digite seu email',
                                  onChanged: (val) => email = val,
                                  validator: (val) {
                                    if (val == null || val.isEmpty) return 'Campo obrigatório';
                                    if (!val.contains('@')) return 'Email inválido';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                _buildTextField(
                                  'Senha',
                                  theme,
                                  hint: 'Digite sua senha',
                                  obscure: true,
                                  onChanged: (val) => senha = val,
                                  validator: (val) {
                                    if (val == null || val.isEmpty) return 'Campo obrigatório';
                                    if (val.length < 6) return 'Mínimo 6 caracteres';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                Text('Escolha seu Avatar:', style: theme.textTheme.bodyMedium),
                                const SizedBox(height: 10),
                                Center(
                                  child: Column(
                                    children: [
                                      ClipOval(
                                        child: Image.asset(
                                          avatares[avatarIndex],
                                          width: 160,
                                          height: 160,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Tooltip(
                                            message: 'Avatar anterior',
                                            child: IconButton(
                                              onPressed: () {
                                                setState(() {
                                                  avatarIndex =
                                                      (avatarIndex - 1 + avatares.length) % avatares.length;
                                                  avatar = avatares[avatarIndex];
                                                });
                                              },
                                              icon: const Icon(Icons.chevron_left),
                                            ),
                                          ),
                                          const SizedBox(width: 20),
                                          Tooltip(
                                            message: 'Próximo avatar',
                                            child: IconButton(
                                              onPressed: () {
                                                setState(() {
                                                  avatarIndex = (avatarIndex + 1) % avatares.length;
                                                  avatar = avatares[avatarIndex];
                                                });
                                              },
                                              icon: const Icon(Icons.chevron_right),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Tooltip(
                                  message: 'Clique para mostrar opções de acessibilidade',
                                  child: SwitchListTile(
                                    title: Text('Mostrar Opções de Acessibilidade', style: theme.textTheme.bodyMedium),
                                    value: mostrarAcessibilidade,
                                    onChanged: (v) => setState(() => mostrarAcessibilidade = v),
                                  ),
                                ),
                                if (mostrarAcessibilidade) ...[
                                  _buildSwitch('Texto com Alto Contraste', theme, textoAltoContraste, (v) => setState(() => textoAltoContraste = v)),
                                  _buildSwitch('Texto Grande', theme, textoGrande, (v) => setState(() => textoGrande = v)),
                                  _buildSwitch('Áudio Guiado', theme, audioGuiado, (v) => setState(() => audioGuiado = v)),
                                  _buildSwitch('Modo Escuro', theme, modoEscuro, (v) => setState(() => modoEscuro = v)),
                                  _buildSwitch('Leitor de Tela', theme, leituraTela, (v) => setState(() => leituraTela = v)),
                                  _buildSwitch('Redução de Movimento', theme, reducaoMovimento, (v) => setState(() => reducaoMovimento = v)),
                                  _buildSwitch('Teclado Adaptado', theme, tecladoAdaptado, (v) => setState(() => tecladoAdaptado = v)),
                                  const SizedBox(height: 20),
                                  _buildDropdown(
                                    'Modo Daltonismo',
                                    theme,
                                    modoDaltonismoSelecionado,
                                    ['Nenhum', 'Protanopia', 'Deuteranopia', 'Tritanopia', 'Monocromacia'],
                                    (val) => setState(() => modoDaltonismoSelecionado = val ?? 'Nenhum'),
                                  ),
                                  _buildDropdown(
                                    'Fonte para Dislexia',
                                    theme,
                                    fonteDyslexiaSelecionada,
                                    ['Nenhum', 'Arial', 'Comic Sans', 'OpenDyslexic'],
                                    (val) => setState(() => fonteDyslexiaSelecionada = val ?? 'Nenhum'),
                                  ),
                                ],
                                const SizedBox(height: 30),
                                Center(
                                  child: PixelButton(
                                    onPressed: () async {
                                      if (_formKey.currentState!.validate()) {
                                        await salvarPreferencias();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Jogador cadastrado com sucesso!',
                                              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    label: 'Cadastrar',
                                    width: 220,
                                    height: 60,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Center(
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                                      );
                                    },
                                    child: Text(
                                      'Já tem conta? Entrar',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        decoration: TextDecoration.underline,
                                        color: theme.primaryColorDark,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
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

  Widget _buildSwitch(String title, ThemeData theme, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title, style: theme.textTheme.bodyMedium),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.teal,
    );
  }

  Widget _buildDropdown(
    String label,
    ThemeData theme,
    String selectedValue,
    List<String> options,
    Function(String?) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        value: selectedValue,
        items: options.map((String val) {
          return DropdownMenuItem<String>(
            value: val,
            child: Text(val, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 10)),
          );
        }).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
