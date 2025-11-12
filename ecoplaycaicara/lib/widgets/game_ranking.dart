import 'package:flutter/material.dart';

import '../services/backend_client.dart';

enum RankingStatus {
  loading,
  requiresLogin,
  error,
  ready,
}

class GameRankingSection extends StatelessWidget {
  const GameRankingSection({
    super.key,
    required this.status,
    required this.title,
    this.result,
    this.message,
  });

  final RankingStatus status;
  final String title;
  final GameRankingResult? result;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    switch (status) {
      case RankingStatus.loading:
        return _buildMessage(theme, 'Carregando placar...');
      case RankingStatus.requiresLogin:
        return _buildMessage(
          theme,
          message ?? 'Entre com sua conta para registrar e ver seu placar pessoal.',
        );
      case RankingStatus.error:
        return _buildMessage(
          theme,
          message ?? 'Não foi possível carregar seu placar agora.',
          isError: true,
        );
      case RankingStatus.ready:
        final data = result;
        if (data == null) {
          return _buildMessage(
            theme,
            'Placar indisponível no momento.',
            isError: true,
          );
        }
        final info = message;
        final PersonalBest? best = data.melhor;
        final List<PersonalHistoryEntry> history = data.historico;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              textAlign: TextAlign.left,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            if (info != null && info.isNotEmpty)
              _buildMessage(theme, info),
            if (best == null)
              _buildMessage(
                theme,
                'Você ainda não registrou pontuações neste jogo. Jogue para registrar sua primeira!',
              )
            else
              _BestScoreHighlight(best: best),
            if (history.isNotEmpty) ...[
              const SizedBox(height: 12),
              _HistoryChips(entries: history),
            ],
          ],
        );
    }
  }

  Widget _buildMessage(
    ThemeData theme,
    String text, {
    bool isError = false,
  }) {
    final Color baseColor =
        isError ? theme.colorScheme.error : theme.colorScheme.primary;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color background = isError
        ? baseColor.withOpacity(isDark ? 0.16 : 0.12)
        : baseColor.withOpacity(isDark ? 0.18 : 0.12);
    final Color textColor = isError
        ? baseColor
        : (isDark ? theme.colorScheme.onSurface : baseColor.darken(0.15));

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: baseColor.withOpacity(isError ? 0.45 : 0.35),
          width: 1.2,
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BestScoreHighlight extends StatelessWidget {
  const _BestScoreHighlight({required this.best});

  final PersonalBest best;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color background = isDark
        ? const Color(0xFF1F2A33).withOpacity(0.92)
        : const Color(0xFFE3F2FD);
    final Color border = isDark
        ? const Color(0xFF64B5F6)
        : const Color(0xFF1976D2).withOpacity(0.65);
    final Color textPrimary =
        isDark ? const Color(0xFFBBDEFB) : const Color(0xFF0D47A1);
    final Color textSecondary =
        isDark ? const Color(0xFF90CAF9) : const Color(0xFF1565C0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seu melhor resultado',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${best.pontuacao} pontos • ${_ordinal(best.posicao)} lugar',
            style: theme.textTheme.bodySmall?.copyWith(
              color: textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Registrado em ${_formatDate(best.dataHora)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: textSecondary.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  static String _ordinal(int posicao) {
    if (posicao <= 0) return '${posicao}º';
    if (posicao == 1) return '1º';
    if (posicao == 2) return '2º';
    if (posicao == 3) return '3º';
    return '${posicao}º';
  }
}

class _HistoryChips extends StatelessWidget {
  const _HistoryChips({required this.entries});

  final List<PersonalHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color labelColor =
        isDark ? const Color(0xFFB0BEC5) : const Color(0xFF37474F);

    final displayed = entries.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Últimas partidas',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: labelColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: displayed
              .map(
                (entry) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF263238).withOpacity(0.9)
                        : const Color(0xFFE0F2F1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF546E7A)
                          : const Color(0xFF80CBC4),
                    ),
                  ),
                  child: Text(
                    '${entry.pontuacao} pts • ${_formatDate(entry.dataHora)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? const Color(0xFFB2DFDB)
                          : const Color(0xFF00695C),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

extension on Color {
  Color darken(double amount) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness(
      (hsl.lightness - amount).clamp(0.0, 1.0),
    );
    return hslDark.toColor();
  }
}

String _formatDate(DateTime date) {
  final now = DateTime.now();
  final twoDigits = (int value) => value.toString().padLeft(2, '0');
  final datePart = '${twoDigits(date.day)}/${twoDigits(date.month)}';
  final timePart = '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  final bool sameDay = now.year == date.year &&
      now.month == date.month &&
      now.day == date.day;
  if (sameDay) {
    return 'hoje às $timePart';
  }
  return '$datePart às $timePart';
}
