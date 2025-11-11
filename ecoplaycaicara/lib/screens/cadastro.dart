import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';
import '../theme/color_blindness.dart';
import '../widgets/pixel_button.dart';
import '../widgets/game_frame.dart';
import '../app_scroll_behavior.dart';
import 'home.dart';
import '../widgets/link_button.dart';
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
  Uint8List? avatarBytes; // avatar customizado (web/mobile)

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
    'assets/avatares/1.png',
    'assets/avatares/2.png',
    'assets/avatares/3.png',
    'assets/avatares/caranguejo-uca.png',
    'assets/avatares/jaguatirica.png',
    'assets/avatares/guara-vermelho.png',
  ];

  int avatarIndex = 0;

  @override
  void initState() {
    super.initState();
    avatar = avatares[0];
    _restoreCustomAvatar();
    // Inicializa dropdown da fonte conforme ThemeProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tp = context.read<ThemeProvider>();
      setState(() {
        fonteDyslexiaSelecionada = fontToStorage(tp.accessibilityFont);
      });
    });
  }

  Future<void> _restoreCustomAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final b64 = prefs.getString('avatarCustomBase64');
    if (b64 != null && b64.isNotEmpty) {
      try {
        final bytes = base64Decode(b64);
        if (mounted) {
          setState(() {
            avatarBytes = bytes;
            avatar = 'custom';
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _pickAndCropAvatar() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (picked == null) return;

      // Sem recorte para máxima compatibilidade Web/Mobile. Exibição usa ClipOval.
      final bytes = await picked.readAsBytes();
      setState(() {
        avatarBytes = bytes;
        avatar = 'custom';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao selecionar/cortar imagem: $e')),
      );
    }
  }

  Future<void> salvarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    final themeProvider = context.read<ThemeProvider>();

    await prefs.setString('nome', nome);
    await prefs.setString('email', email);
    await prefs.setString('senha', senha);
    await prefs.setString('avatar', avatar);
    if (avatarBytes != null) {
      await prefs.setString('avatarCustomBase64', base64Encode(avatarBytes!));
    } else {
      await prefs.remove('avatarCustomBase64');
    }

    // Persistência legacy para outras telas que ainda leem essas chaves
    await prefs.setBool('textoAltoContraste', themeProvider.highContrast);
    await prefs.setBool('textoGrande', themeProvider.largeText);
    await prefs.setBool('audioGuiado', audioGuiado);
    await prefs.setBool('modoEscuro', themeProvider.isDark);
    await prefs.setBool('leituraTela', leituraTela);
    await prefs.setBool('reducaoMovimento', reducaoMovimento);
    await prefs.setBool('tecladoAdaptado', tecladoAdaptado);

    await prefs.setString('modoDaltonismo', _cvdOptionFromType(themeProvider.colorVision));
    await prefs.setString('fonteDislexia', fontToStorage(themeProvider.accessibilityFont));
  }

  // Mapeamento entre opções do dropdown e enum do ThemeProvider
  String _cvdOptionFromType(ColorVisionType type) {
    switch (type) {
      case ColorVisionType.normal:
        return 'Nenhum';
      case ColorVisionType.protanopia:
        return 'Protanopia';
      case ColorVisionType.deuteranopia:
        return 'Deuteranopia';
      case ColorVisionType.tritanopia:
        return 'Tritanopia';
      case ColorVisionType.achromatopsia:
        return 'Monocromacia';
    }
  }

  ColorVisionType _cvdTypeFromOption(String option) {
    switch (option) {
      case 'Protanopia':
        return ColorVisionType.protanopia;
      case 'Deuteranopia':
        return ColorVisionType.deuteranopia;
      case 'Tritanopia':
        return ColorVisionType.tritanopia;
      case 'Monocromacia':
        return ColorVisionType.achromatopsia;
      case 'Nenhum':
      default:
        return ColorVisionType.normal;
    }
  }

  // Seletor de paleta removido

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = theme.brightness == Brightness.dark;

    return GameScaffold(
      title: 'Cadastro de Jogador',
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
                                const GameSectionTitle('Escolha seu Avatar:'),
                                const SizedBox(height: 10),
                                Center(
                                  child: Column(
                                    children: [
                                      ClipOval(
                                        child: SizedBox(
                                          width: 160,
                                          height: 160,
                                          child: avatarBytes != null
                                              ? Image.memory(
                                                  avatarBytes!,
                                                  fit: BoxFit.cover,
                                                )
                                              : Image.asset(
                                                  avatares[avatarIndex],
                                                  fit: BoxFit.cover,
                                                ),
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
                                                  avatarIndex = (avatarIndex - 1 + avatares.length) % avatares.length;
                                                  avatar = avatares[avatarIndex];
                                                  avatarBytes = null; // voltou a usar avatar padrão
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
                                                  avatarBytes = null;
                                                });
                                              },
                                              icon: const Icon(Icons.chevron_right),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      PixelButton(
                                        label: 'Escolher Foto',
                                        icon: Icons.photo_library_rounded,
                                        iconRight: true,
                                        onPressed: _pickAndCropAvatar,
                                        width: 180,
                                        height: 44,
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
                                  _buildSwitch(
                                    'Texto com Alto Contraste',
                                    theme,
                                    themeProvider.highContrast,
                                    (v) => themeProvider.setHighContrast(v),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Text('Tamanho do Texto', style: theme.textTheme.bodyMedium),
                                        SliderTheme(
                                          data: SliderTheme.of(context).copyWith(
                                            trackHeight: 4,
                                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                                            activeTrackColor: theme.colorScheme.primary,
                                            inactiveTrackColor: theme.colorScheme.onSurface.withOpacity(0.2),
                                            thumbColor: theme.colorScheme.primary,
                                          ),
                                          child: Slider(
                                            value: themeProvider.textScale,
                                            min: 0.9,
                                            max: 1.6,
                                            divisions: 7,
                                            label: '${themeProvider.textScale.toStringAsFixed(1)}x',
                                            onChanged: (v) => themeProvider.setTextScale(v),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _buildSwitch('Áudio Guiado', theme, audioGuiado, (v) => setState(() => audioGuiado = v)),
                                  _buildSwitch(
                                    'Modo Escuro',
                                    theme,
                                    themeProvider.isDark,
                                    (v) => themeProvider.setDark(v),
                                  ),
                                  _buildSwitch('Leitor de Tela', theme, leituraTela, (v) => setState(() => leituraTela = v)),
                                  _buildSwitch('Redução de Movimento', theme, reducaoMovimento, (v) => setState(() => reducaoMovimento = v)),
                                  _buildSwitch('Teclado Adaptado', theme, tecladoAdaptado, (v) => setState(() => tecladoAdaptado = v)),
                                  const SizedBox(height: 20),
                                  _buildDropdown(
                                    'Modo Daltonismo',
                                    theme,
                                    _cvdOptionFromType(themeProvider.colorVision),
                                    const ['Nenhum', 'Protanopia', 'Deuteranopia', 'Tritanopia', 'Monocromacia'],
                                    (val) {
                                      final type = _cvdTypeFromOption(val ?? 'Nenhum');
                                      themeProvider.setColorVision(type);
                                      setState(() => modoDaltonismoSelecionado = val ?? 'Nenhum');
                                    },
                                  ),
                                  _buildDropdown(
                                    'Fonte para Dislexia',
                                    theme,
                                    fontToStorage(themeProvider.accessibilityFont),
                                    const ['Nenhum', 'Arial', 'Comic Sans', 'OpenDyslexic'],
                                    (val) {
                                      final choice = fontFromStorage(val);
                                      themeProvider.setAccessibilityFont(choice);
                                      setState(() => fonteDyslexiaSelecionada = val ?? 'Nenhum');
                                    },
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
                                        if (mounted) {
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => const HomeScreen(),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    label: 'Cadastrar',
                                    icon: Icons.rocket_launch_rounded,
                                    iconRight: true,
                                    width: 220,
                                    height: 60,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Center(
                                  child: LinkButton(
                                    label: 'Já tem conta? Entrar',
                                    alignment: Alignment.center,
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                                      );
                                    },
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



