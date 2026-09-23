import 'package:flutter/material.dart';

import '../logic.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/page.dart';
import '../widgets/result_editor.dart';

class ScoreboardScreen extends StatelessWidget {
  const ScoreboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Scorebord',
      subtitle: () => '${store.history.length} potjes gespeeld',
      builder: (context) {
        if (store.history.isEmpty) {
          return const [
            EmptyState(
              icon: Icons.emoji_events_rounded,
              title: 'Nog geen uitslagen',
              text: 'Na elk potje verschijnt hier het klassement.',
            ),
          ];
        }
        final rows = scoreboard(store.history);
        return [
          const _HeaderRow(),
          const SizedBox(height: 6),
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RankRow(rank: i + 1, row: rows[i]),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Text(
              'Volgorde: gewonnen, dan snelste tijd, dan meeste punten. '
              'Alleen scores met het vinkje "telt mee" tellen.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
          const SectionTitle('Gespeelde potjes'),
          for (final m in store.history.reversed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _MatchRow(match: m),
            ),
        ];
      },
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
        color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w700);
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          SizedBox(width: 40),
          Expanded(child: Text('TEAM', style: style)),
          SizedBox(
              width: 52,
              child: Text('WINST', textAlign: TextAlign.center, style: style)),
          SizedBox(
              width: 52,
              child: Text('TIJD', textAlign: TextAlign.center, style: style)),
          SizedBox(
              width: 52,
              child: Text('PUNTEN', textAlign: TextAlign.center, style: style)),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.row});

  final int rank;
  final ScoreRow row;

  @override
  Widget build(BuildContext context) {
    final top = rank <= 3 && row.won;
    return Glass(
      highlight: rank == 1 && row.won,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: top ? AppColors.yellowGradient : null,
                color: top ? null : Colors.white.withValues(alpha: 0.08),
              ),
              child: Text('$rank',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: top ? AppColors.black : AppColors.text)),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.teamLabel,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(row.players,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
          SizedBox(
            width: 52,
            child: Center(
              child: row.won
                  ? Icon(Icons.emoji_events_rounded,
                      color: AppColors.yellow,
                      semanticLabel: '${row.wins}x gewonnen')
                  : const Icon(Icons.remove_rounded, color: AppColors.muted),
            ),
          ),
          _num(row.bestTimeMs == null ? '–' : formatMs(row.bestTimeMs!)),
          _num('${row.points}'),
        ],
      ),
    );
  }

  Widget _num(String v) => SizedBox(
        width: 52,
        child: Text(v,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                fontFeatures: [FontFeature.tabularFigures()])),
      );
}

class _MatchRow extends StatelessWidget {
  const _MatchRow({required this.match});

  final GameMatch match;

  @override
  Widget build(BuildContext context) {
    final m = match;
    String sideText(int i) {
      final s = m.side(i);
      final pts = s.points == null ? '' : ' · ${s.points} pt';
      final time = m.finishedSide == i && m.finishTimeMs != null
          ? ' · ${formatMs(m.finishTimeMs!)}'
          : '';
      return '${s.teamLabel}$pts$time${s.counts ? '' : ' (telt niet)'}';
    }

    return Glass(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => _EditMatchScreen(match: m))),
      child: Row(
        children: [
          Text('#${m.number}',
              style: const TextStyle(
                  color: AppColors.yellow, fontWeight: FontWeight.w900)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < 2; i++)
                  Row(
                    children: [
                      Icon(
                        m.winnerSide == i
                            ? Icons.emoji_events_rounded
                            : Icons.circle,
                        size: m.winnerSide == i ? 16 : 6,
                        color: m.winnerSide == i
                            ? AppColors.yellow
                            : AppColors.muted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(sideText(i),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontWeight: m.winnerSide == i
                                    ? FontWeight.w800
                                    : FontWeight.w500)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _EditMatchScreen extends StatelessWidget {
  const _EditMatchScreen({required this.match});

  final GameMatch match;

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        appBar: AppBar(title: Text('Potje ${match.number} corrigeren')),
        body: ListenableBuilder(
          listenable: store,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (match.finishedSide != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${match.side(match.finishedSide!).teamLabel} was klaar '
                    'in ${formatMs(match.finishTimeMs ?? 0)}.',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ),
              ResultEditor(match: match),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Potje verwijderen'),
                onPressed: () async {
                  if (await confirmDialog(context,
                      title: 'Potje ${match.number} verwijderen?',
                      message: 'Dit potje verdwijnt van het scorebord.',
                      confirm: 'Verwijderen',
                      danger: true)) {
                    store.removeFromHistory(match);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
