import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class BackendException implements Exception {
  BackendException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'BackendException(statusCode: $statusCode, message: $message)';
}

class SessionData {
  const SessionData({
    required this.id,
    required this.nome,
    required this.email,
    required this.token,
  });

  final int id;
  final String nome;
  final String email;
  final String token;
}

class PersonalBest {
  const PersonalBest({
    required this.posicao,
    required this.pontuacao,
    required this.dataHora,
  });

  final int posicao;
  final int pontuacao;
  final DateTime dataHora;
}

class PersonalHistoryEntry {
  const PersonalHistoryEntry({
    required this.pontuacao,
    required this.dataHora,
  });

  final int pontuacao;
  final DateTime dataHora;
}

class GameRankingResult {
  const GameRankingResult({
    required this.slug,
    required this.nome,
    this.descricao,
    this.melhor,
    this.historico = const <PersonalHistoryEntry>[],
  });

  final String slug;
  final String nome;
  final String? descricao;
  final PersonalBest? melhor;
  final List<PersonalHistoryEntry> historico;
}

class BackendClient {
  BackendClient._internal();

  static final BackendClient instance = BackendClient._internal();

  static const Duration _defaultTimeout = Duration(seconds: 12);
  static const String _defaultBaseUrl = String.fromEnvironment(
    'ECO_BACKEND_URL',
    defaultValue: 'http://localhost:5001',
  );

  static const String _prefsTokenKey = 'auth.token';
  static const String _prefsUserIdKey = 'auth.user.id';
  static const String _prefsUserNameKey = 'auth.user.nome';
  static const String _prefsUserEmailKey = 'auth.user.email';

  final String _baseUrl = _defaultBaseUrl;
  SessionData? _session;
  bool _sessionLoaded = false;
  Future<void>? _sessionLoading;

  Uri _resolve(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse(_baseUrl);
    final resolved = base.resolve(path);
    if (query == null || query.isEmpty) {
      return resolved;
    }
    final queryParams = <String, String>{
      for (final entry in query.entries)
        if (entry.value != null) entry.key: entry.value.toString(),
    };
    return resolved.replace(queryParameters: queryParams);
  }

  Future<void> _ensureSessionLoaded() async {
    if (_sessionLoaded) return;
    if (_sessionLoading != null) {
      await _sessionLoading;
      return;
    }
    _sessionLoading = _loadSession();
    try {
      await _sessionLoading;
    } finally {
      _sessionLoading = null;
    }
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_prefsTokenKey);
    final id = prefs.getInt(_prefsUserIdKey);
    final nome = prefs.getString(_prefsUserNameKey);
    final email = prefs.getString(_prefsUserEmailKey);

    if (token != null &&
        token.isNotEmpty &&
        id != null &&
        nome != null &&
        email != null) {
      _session = SessionData(
        id: id,
        nome: nome,
        email: email,
        token: token,
      );
    } else {
      _session = null;
    }
    _sessionLoaded = true;
  }

  Future<SessionData?> getCurrentSession() async {
    await _ensureSessionLoaded();
    return _session;
  }

  Future<void> saveSession(SessionData session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsTokenKey, session.token);
    await prefs.setInt(_prefsUserIdKey, session.id);
    await prefs.setString(_prefsUserNameKey, session.nome);
    await prefs.setString(_prefsUserEmailKey, session.email);
    _session = session;
    _sessionLoaded = true;
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsTokenKey);
    await prefs.remove(_prefsUserIdKey);
    await prefs.remove(_prefsUserNameKey);
    await prefs.remove(_prefsUserEmailKey);
    _session = null;
    _sessionLoaded = true;
  }

  Map<String, String> _jsonHeaders({bool authorized = false}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (authorized && _session != null) {
      headers['Authorization'] = 'Bearer ${_session!.token}';
    }
    return headers;
  }

  Future<void> createJogador(Map<String, dynamic> payload) async {
    final uri = _resolve('/api/jogadores');
    final response = await http
        .post(
          uri,
          headers: _jsonHeaders(),
          body: jsonEncode(payload),
        )
        .timeout(_defaultTimeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw _toBackendException(response);
  }

  Future<SessionData> login(String email, String senha) async {
    final uri = _resolve('/api/login');
    final response = await http
        .post(
          uri,
          headers: _jsonHeaders(),
          body: jsonEncode({
            'email': email.trim(),
            'senha': senha,
          }),
        )
        .timeout(_defaultTimeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = _decodeJson(response.body);
      final token = decoded['token'] as String?;
      final usuario = decoded['usuario'] as Map<String, dynamic>?;
      if (token == null || usuario == null) {
        throw BackendException(
          'Resposta inesperada do servidor.',
          statusCode: response.statusCode,
        );
      }
      final id = usuario['id'];
      final nome = usuario['nome'];
      final mail = usuario['email'];
      if (id is! int || nome is! String || mail is! String) {
        throw BackendException(
          'Dados de usuário inválidos no retorno.',
          statusCode: response.statusCode,
        );
      }
      final session = SessionData(
        id: id,
        nome: nome,
        email: mail,
        token: token,
      );
      await saveSession(session);
      return session;
    }

    throw _toBackendException(response);
  }

  Future<GameRankingResult> fetchRanking(String miniJogoSlug) async {
    await _ensureSessionLoaded();
    if (_session == null) {
      throw BackendException(
        'Faça login para consultar seu ranking pessoal.',
        statusCode: 401,
      );
    }

    final uri = _resolve('/api/mini-jogos/$miniJogoSlug/ranking');
    final response = await http
        .get(uri, headers: _jsonHeaders(authorized: true))
        .timeout(_defaultTimeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = _decodeJson(response.body);
      final miniJogo = decoded['miniJogo'] as Map<String, dynamic>? ?? {};
      final pessoaRaw = decoded['pessoal'] as Map<String, dynamic>? ?? {};

      final melhorRaw = pessoaRaw['melhor'];
      final PersonalBest? melhor = melhorRaw is Map<String, dynamic>
          ? PersonalBest(
              posicao: _coerceInt(melhorRaw['posicao']),
              pontuacao: _coerceInt(melhorRaw['pontuacao']),
              dataHora: _coerceDate(melhorRaw['dataHora']),
            )
          : null;

      final historicoRaw = pessoaRaw['historico'];
      final List<PersonalHistoryEntry> historico =
          historicoRaw is List<dynamic>
              ? historicoRaw
                  .map((item) => item as Map<String, dynamic>)
                  .map(
                    (map) => PersonalHistoryEntry(
                      pontuacao: _coerceInt(map['pontuacao']),
                      dataHora: _coerceDate(map['dataHora']),
                    ),
                  )
                  .toList(growable: false)
              : const [];

      return GameRankingResult(
        slug: (miniJogo['slug'] as String? ?? miniJogoSlug).trim(),
        nome: (miniJogo['nome'] as String? ?? miniJogoSlug).trim(),
        descricao: (miniJogo['descricao'] as String?)?.trim(),
        melhor: melhor,
        historico: historico,
      );
    }

    throw _toBackendException(response);
  }

  Future<void> submitPontuacao(
    String miniJogoSlug,
    int pontuacao,
  ) async {
    await _ensureSessionLoaded();
    if (_session == null) {
      throw BackendException(
        'Faça login para registrar pontuações.',
        statusCode: 401,
      );
    }

    final uri = _resolve('/api/mini-jogos/$miniJogoSlug/pontuacoes');
    final response = await http
        .post(
          uri,
          headers: _jsonHeaders(authorized: true),
          body: jsonEncode({'pontuacao': pontuacao}),
        )
        .timeout(_defaultTimeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw _toBackendException(response);
  }

  Future<SessionData> registerAndLogin(
    Map<String, dynamic> payload,
    String senha,
  ) async {
    await createJogador(payload);
    final email = (payload['email'] as String? ?? '').trim();
    if (email.isEmpty) {
      throw BackendException(
        'Email ausente ao tentar autenticar após cadastro.',
      );
    }
    return login(email, senha);
  }

  Map<String, dynamic> _decodeJson(String body) {
    if (body.isEmpty) return const {};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw BackendException('Resposta inesperada do servidor.');
  }

  BackendException _toBackendException(http.Response response) {
    String message = 'Falha ao comunicar com o servidor.';
    try {
      final decoded = _decodeJson(response.body);
      final candidates = [
        decoded['erro'],
        decoded['error'],
        decoded['message'],
      ];
      for (final candidate in candidates) {
        if (candidate is String && candidate.trim().isNotEmpty) {
          message = candidate.trim();
          break;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Falha ao analisar erro do backend: $e');
      }
    }
    return BackendException(
      message,
      statusCode: response.statusCode,
    );
  }

  int _coerceInt(Object? value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    return 0;
  }

  DateTime _coerceDate(Object? value) {
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed.toLocal();
    }
    return DateTime.now();
  }
}
