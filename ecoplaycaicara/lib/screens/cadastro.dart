import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/theme_provider.dart';
import '../theme/color_blindness.dart';
import '../widgets/pixel_button.dart';
import '../widgets/game_frame.dart';
import '../app_scroll_behavior.dart';
import 'home.dart';
import '../widgets/link_button.dart';
import '../widgets/narrable.dart';
import 'login.dart';
import '../services/backend_client.dart';
import '../widgets/form_section_card.dart';
import '../services/user_prefs.dart';

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
  bool narracaoAtiva = false;
  bool narrarAoFocar = false;
  bool mostrarTooltips = true;

  bool _cadastrando = false;
  String? _backendErro;

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
    _loadA11yPrefs();
    // Inicializa dropdown da fonte conforme ThemeProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tp = context.read<ThemeProvider>();
      setState(() {
        fonteDyslexiaSelecionada = fontToStorage(tp.accessibilityFont);
      });
    });
  }

  Future<void> _loadA11yPrefs() async {
    final prefs = UserPrefs.instance;
    await prefs.ensureLoaded();
    if (!mounted) return;
    setState(() {
      narracaoAtiva = prefs.ttsEnabled;
      narrarAoFocar = prefs.ttsReadUi;
      mostrarTooltips = prefs.showTooltips;
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
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
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
        SnackBar(
          content: Narrable.text(
            'Falha ao selecionar ou cortar imagem: $e',
            readOnFocus: false,
          ),
        ),
      );
    }
  }

  Future<void> salvarPreferencias(SessionData session) async {
    final prefs = await SharedPreferences.getInstance();
    final themeProvider = context.read<ThemeProvider>();

    nome = session.nome;
    email = session.email;

    await prefs.setString('nome', session.nome);
    await prefs.setString('email', session.email);
    await prefs.remove('senha');
    await prefs.setString('avatar', avatar);
    if (avatarBytes != null) {
      await prefs.setString('avatarCustomBase64', base64Encode(avatarBytes!));
    } else {
      await prefs.remove('avatarCustomBase64');
    }

    // Persistência legacy para outras telas que ainda leem essas chaves
    await prefs.setBool('textoAltoContraste', themeProvider.highContrast);
    await prefs.setBool('textoGrande', themeProvider.largeText);
    await prefs.setBool('audioGuiado', narracaoAtiva);
    await prefs.setBool('modoEscuro', themeProvider.isDark);
    await prefs.setBool('leituraTela', narrarAoFocar);
    await prefs.setBool('reducaoMovimento', themeProvider.reduceMotion);
    await prefs.setBool('mostrarTooltips', mostrarTooltips);

    await prefs.setString(
      'modoDaltonismo',
      _cvdOptionFromType(themeProvider.colorVision),
    );
    await prefs.setString(
      'fonteDislexia',
      fontToStorage(themeProvider.accessibilityFont),
    );
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

  String _modoDaltonismoBackendValue() {
    switch (modoDaltonismoSelecionado) {
      case 'Protanopia':
        return 'protanopia';
      case 'Deuteranopia':
        return 'deuteranopia';
      case 'Tritanopia':
        return 'tritanopia';
      case 'Monocromacia':
        return 'acromatopsia';
      case 'Nenhum':
      default:
        return 'nenhum';
    }
  }

  String _fonteDislexiaBackendValue() {
    switch (fonteDyslexiaSelecionada) {
      case 'Arial':
        return 'arial';
      case 'Comic Sans':
        return 'comicsans';
      case 'OpenDyslexic':
        return 'opendyslexic';
      case 'Nenhum':
      default:
        return 'nenhuma';
    }
  }

  Map<String, dynamic> _buildCadastroPayload(ThemeProvider themeProvider) {
    final trimmedEmail = email.trim();
    final normalizedEmail = trimmedEmail.isEmpty
        ? email.trim()
        : trimmedEmail.toLowerCase();
    final bool hasCustomAvatar = avatar == 'custom' && avatarBytes != null;

    final payload = <String, dynamic>{
      'nome': nome.trim(),
      'email': normalizedEmail.isEmpty ? email : normalizedEmail,
      'senha': senha,
      'avatarAsset': hasCustomAvatar ? null : avatar,
      'avatarBase64': hasCustomAvatar ? base64Encode(avatarBytes!) : null,
      'preferencias': <String, dynamic>{
        'usar_contraste': themeProvider.highContrast,
        'usar_narracao': narracaoAtiva,
        'usar_leitura_tela': narrarAoFocar,
        'usar_reducao_movimento': themeProvider.reduceMotion,
        'usar_modo_escuro': themeProvider.isDark,
        'usar_texto_grande': themeProvider.largeText,
        'escala_texto': themeProvider.textScale,
        'fonte_dislexia': _fonteDislexiaBackendValue(),
        'modo_daltonismo': _modoDaltonismoBackendValue(),
        'mostrar_tooltips': mostrarTooltips,
      },
    };

    payload.removeWhere((key, value) => value == null);
    final prefs = payload['preferencias'] as Map<String, dynamic>;
    prefs.removeWhere((key, value) => value == null);

    return payload;
  }

  void _showSnackBar(
    String message, {
    bool isError = false,
    bool persist = false,
  }) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError
            ? theme.colorScheme.error
            : theme.colorScheme.primary,
        duration: persist
            ? const Duration(seconds: 5)
            : const Duration(seconds: 3),
        content: Narrable.text(
          message,
          readOnFocus: false,
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _submeterCadastro() async {
    if (_cadastrando) return;

    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    FocusScope.of(context).unfocus();
    final themeProvider = context.read<ThemeProvider>();

    setState(() {
      _cadastrando = true;
      _backendErro = null;
    });

    final backend = BackendClient.instance;
    final payload = _buildCadastroPayload(themeProvider);

    try {
      final session = await backend.registerAndLogin(payload, senha);
      await salvarPreferencias(session);
      if (!mounted) return;
      _showSnackBar('Jogador cadastrado com sucesso!');
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on BackendException catch (e) {
      final message = e.message.isNotEmpty
          ? e.message
          : 'Não foi possível concluir o cadastro.';
      if (!mounted) return;
      setState(() => _backendErro = message);
      _showSnackBar(message, isError: true, persist: true);
    } on TimeoutException {
      const message =
          'Tempo esgotado ao contatar o servidor. Verifique sua conexão e tente novamente.';
      if (!mounted) return;
      setState(() => _backendErro = message);
      _showSnackBar(message, isError: true, persist: true);
    } catch (_) {
      const message =
          'Falha ao conectar com o servidor. Tente novamente em instantes.';
      if (!mounted) return;
      setState(() => _backendErro = message);
      _showSnackBar(message, isError: true, persist: true);
    } finally {
      if (mounted) {
        setState(() => _cadastrando = false);
      }
    }
  }

  Future<void> _entrarComoVisitante() async {
    if (_cadastrando) return;
    FocusScope.of(context).unfocus();
    setState(() => _backendErro = null);
    final backend = BackendClient.instance;
    await backend.clearSession();
    if (!mounted) return;
    _showSnackBar(
      'Modo visitante ativado. Pontuações não serão salvas.',
      persist: true,
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
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
                  FormSectionCard(
                    icon: Icons.person_outline,
                    title: 'Informações básicas',
                    description:
                        'Use o mesmo apelido e contato que usa nas missões.',
                    child: Column(
                      children: [
                        _buildTextField(
                          'Nome',
                          theme,
                          hint: 'Digite seu nickname',
                          onChanged: (val) => nome = val,
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Campo obrigatório';
                            }
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
                            if (val == null || val.isEmpty) {
                              return 'Campo obrigatório';
                            }
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
                            if (val == null || val.isEmpty) {
                              return 'Campo obrigatório';
                            }
                            if (val.length < 6) return 'Mínimo 6 caracteres';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FormSectionCard(
                    icon: Icons.emoji_emotions_outlined,
                    title: 'Avatar e identidade visual',
                    description:
                        'Escolha um mascote da comunidade ou envie sua foto.',
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final double previewSize = constraints.maxWidth > 520
                            ? 190
                            : 160;

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: previewSize + 20,
                              height: previewSize + 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    theme.colorScheme.primary.withOpacity(0.15),
                                    theme.colorScheme.primary.withOpacity(0.05),
                                  ],
                                ),
                              ),
                              alignment: Alignment.center,
                              child: ClipOval(
                                child: SizedBox(
                                  width: previewSize,
                                  height: previewSize,
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
                            ),
                            const SizedBox(height: 12),
                            PixelButton(
                              label: 'Escolher Foto',
                              icon: Icons.photo_library_rounded,
                              iconRight: true,
                              onPressed: _pickAndCropAvatar,
                              width: 200,
                              height: 46,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Tooltip(
                                  message: 'Avatar anterior',
                                  child: IconButton.filledTonal(
                                    onPressed: () {
                                      setState(() {
                                        avatarIndex =
                                            (avatarIndex -
                                                1 +
                                                avatares.length) %
                                            avatares.length;
                                        avatar = avatares[avatarIndex];
                                        avatarBytes = null;
                                      });
                                    },
                                    icon: const Icon(Icons.chevron_left),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Tooltip(
                                  message: 'Próximo avatar',
                                  child: IconButton.filledTonal(
                                    onPressed: () {
                                      setState(() {
                                        avatarIndex =
                                            (avatarIndex + 1) % avatares.length;
                                        avatar = avatares[avatarIndex];
                                        avatarBytes = null;
                                      });
                                    },
                                    icon: const Icon(Icons.chevron_right),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Dica: você pode personalizar depois nas configurações.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  FormSectionCard(
                    icon: Icons.settings_accessibility_rounded,
                    title: 'Experiência e acessibilidade',
                    description:
                        'Personalize texto, narração, contraste e preferências visuais.',
                    trailing: Narrable(
                      text: mostrarAcessibilidade
                          ? 'Ocultar ajustes de acessibilidade'
                          : 'Mostrar ajustes de acessibilidade',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            mostrarAcessibilidade ? 'Ativado' : 'Desativado',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Switch.adaptive(
                            value: mostrarAcessibilidade,
                            onChanged: (v) =>
                                setState(() => mostrarAcessibilidade = v),
                          ),
                        ],
                      ),
                    ),
                    child: AnimatedCrossFade(
                      duration: const Duration(milliseconds: 250),
                      crossFadeState: mostrarAcessibilidade
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Use o controle acima para revelar as opções de acessibilidade.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      secondChild: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceVariant
                                  .withOpacity(
                                    theme.brightness == Brightness.dark
                                        ? 0.35
                                        : 0.9,
                                  ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: theme.colorScheme.primary.withOpacity(
                                  0.18,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Tamanho do texto',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    Text(
                                      '${themeProvider.textScale.toStringAsFixed(1)}x',
                                      style: theme.textTheme.labelLarge,
                                    ),
                                  ],
                                ),
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 4,
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 10,
                                    ),
                                    activeTrackColor: theme.colorScheme.primary,
                                    inactiveTrackColor: theme
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.2),
                                    thumbColor: theme.colorScheme.primary,
                                  ),
                                  child: Slider(
                                    value: themeProvider.textScale,
                                    min: 0.9,
                                    max: 1.6,
                                    divisions: 7,
                                    label:
                                        '${themeProvider.textScale.toStringAsFixed(1)}x',
                                    onChanged: (v) =>
                                        themeProvider.setTextScale(v),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildSwitch(
                            'Modo Escuro',
                            theme,
                            themeProvider.isDark,
                            (v) => themeProvider.setDark(v),
                          ),
                          _buildSwitch(
                            'Texto com Alto Contraste',
                            theme,
                            themeProvider.highContrast,
                            (v) => themeProvider.setHighContrast(v),
                          ),
                          _buildSwitch(
                            'Reduzir movimento',
                            theme,
                            themeProvider.reduceMotion,
                            (v) => themeProvider.setReduceMotion(v),
                          ),
                          _buildSwitch(
                            'Mostrar dicas (tooltips)',
                            theme,
                            mostrarTooltips,
                            (v) => _setMostrarTooltips(v),
                          ),
                          _buildSwitch(
                            'Ativar narração (TTS)',
                            theme,
                            narracaoAtiva,
                            (v) => _setNarracaoAtiva(v),
                          ),
                          _buildSwitch(
                            'Narrar ao focar/pressionar',
                            theme,
                            narrarAoFocar,
                            (v) => _setNarrarAoFocar(v),
                          ),
                          const SizedBox(height: 12),
                          _buildDropdown(
                            'Modo Daltonismo',
                            theme,
                            _cvdOptionFromType(themeProvider.colorVision),
                            const [
                              'Nenhum',
                              'Protanopia',
                              'Deuteranopia',
                              'Tritanopia',
                              'Monocromacia',
                            ],
                            (val) {
                              final type = _cvdTypeFromOption(val ?? 'Nenhum');
                              themeProvider.setColorVision(type);
                              setState(
                                () =>
                                    modoDaltonismoSelecionado = val ?? 'Nenhum',
                              );
                            },
                          ),
                          _buildDropdown(
                            'Fonte para Dislexia',
                            theme,
                            fontToStorage(themeProvider.accessibilityFont),
                            const [
                              'Nenhum',
                              'Arial',
                              'Comic Sans',
                              'OpenDyslexic',
                            ],
                            (val) {
                              final choice = fontFromStorage(val);
                              themeProvider.setAccessibilityFont(choice);
                              setState(
                                () =>
                                    fonteDyslexiaSelecionada = val ?? 'Nenhum',
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FormSectionCard(
                    icon: Icons.flag_circle_outlined,
                    title: 'Tudo pronto?',
                    description: 'Revise os dados antes de iniciar a aventura.',
                    child: Column(
                      children: [
                        Center(
                          child: IgnorePointer(
                            ignoring: _cadastrando,
                            child: PixelButton(
                              onPressed: _submeterCadastro,
                              label: _cadastrando ? 'Enviando...' : 'Cadastrar',
                              icon: Icons.rocket_launch_rounded,
                              iconRight: true,
                              width: 220,
                              height: 60,
                            ),
                          ),
                        ),
                        if (_cadastrando) ...[
                          const SizedBox(height: 12),
                          const SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ],
                        if (_backendErro != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _backendErro!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        PixelButton(
                          label: 'Jogar sem cadastro',
                          icon: Icons.person_outline,
                          onPressed: _entrarComoVisitante,
                          width: 220,
                          height: 52,
                        ),
                        const SizedBox(height: 12),
                        LinkButton(
                          label: 'Já tem conta? Entrar',
                          alignment: Alignment.center,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
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

  void _setNarracaoAtiva(bool value) {
    setState(() => narracaoAtiva = value);
    unawaited(UserPrefs.instance.setTtsEnabled(value));
  }

  void _setNarrarAoFocar(bool value) {
    setState(() => narrarAoFocar = value);
    unawaited(UserPrefs.instance.setTtsReadUi(value));
  }

  void _setMostrarTooltips(bool value) {
    setState(() => mostrarTooltips = value);
    unawaited(UserPrefs.instance.setShowTooltips(value));
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

  Widget _buildSwitch(
    String title,
    ThemeData theme,
    bool value,
    Function(bool) onChanged,
  ) {
    final scheme = theme.colorScheme;
    final tileColor = scheme.surfaceVariant.withOpacity(
      theme.brightness == Brightness.dark ? 0.35 : 0.9,
    );

    return Narrable(
      text: title,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.primary.withOpacity(0.15)),
        ),
        child: SwitchListTile.adaptive(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          value: value,
          onChanged: onChanged,
          activeColor: scheme.primary,
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    ThemeData theme,
    String selectedValue,
    List<String> options,
    Function(String?) onChanged,
  ) {
    final scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color fillColor = scheme.surfaceVariant.withOpacity(
      isDark ? 0.35 : 0.9,
    );
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(
        color: scheme.primary.withOpacity(0.2),
        width: 1.2,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Narrable(
        text: label,
        child: DropdownButtonFormField<String>(
          value: selectedValue,
          items: options.map((String val) {
            return DropdownMenuItem<String>(
              value: val,
              child: Narrable.text(
                val,
                readOnFocus: false,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 10),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            label: Narrable.text(label, readOnFocus: false),
            filled: true,
            fillColor: fillColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: BorderSide(color: scheme.primary, width: 1.6),
            ),
          ),
        ),
      ),
    );
  }
}
