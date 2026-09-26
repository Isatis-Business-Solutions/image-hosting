import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/page.dart';
import 'relay_models.dart';
import 'relay_store.dart';

class RelayScoreScreen extends StatelessWidget {
  const RelayScoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Scorebord',
      subtitle: () => '${relay.runs.length} rondes gelopen',
      builder: (context) {
        final rows = relay.ranking;
        if (rows.isEmpty) {
          return const [
            EmptyState(
              icon: Icons.emoji_events_rounded,
              title: 'Nog geen tijden',
              text: 'Na elke ronde verschijnt hier het klassement. De twee '
                  'snelste groepen spelen de touwtrekfinale.',
            ),
          ];
        }
        return [
          ..._finale(context, rows),
          const SectionTitle('Klassement estafette'),
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RankRow(rank: i + 1, row: rows[i]),
            ),
          const SectionTitle('Gelopen rondes'),
          for (final r in [...relay.runs]
            ..sort((a, b) => b.number.compareTo(a.number)))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RunRow(run: r),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Text(
              'Loopt een groep vaker, dan telt de tijd van de laatste ronde. '
              'Tik op een ronde om tijden te corrigeren.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
        ];
      },
    );
  }

  List<Widget> _finale(BuildContext context, List<RelayRow> rows) {
    final f = relay.finale;
    if (f == null) {
      if (rows.length < 2) return const [];
      return [
        const SizedBox(height: 4),
        GradientButton(
          label: 'Start touwtrekfinale',
          icon: Icons.sports_kabaddi_rounded,
          height: 60,
          onPressed: () async {
            if (await confirmDialog(context,
                title: 'Touwtrekfinale starten?',
                message: '${rows[0].label} en ${rows[1].label} zijn de twee '
                    'snelste groepen en gaan touwtrekken.',
                confirm: 'Starten')) {
              relay.startFinale();
            }
          },
        ),
      ];
    }

    final w = f.winner;
    return [
      const SectionTitle('Touwtrekfinale'),
      if (w != null)
        Glass(
          highlight: true,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.emoji_events_rounded,
                  size: 64, color: AppColors.yellow),
              const SizedBox(height: 6),
              const Text('WINNAAR',
                  style: TextStyle(
                      color: AppColors.muted,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w800)),
              Text(w.label,
                  style: const TextStyle(
                      fontSize: 32, fontWeight: FontWeight.w900)),
              Text(w.playersText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted)),
            ],
          ),
        )
      else ...[
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text('Tik op de groep die het touwtrekken wint.',
              style: TextStyle(color: AppColors.muted)),
        ),
        Row(
          children: [
            Expanded(child: _FinalCard(entry: f.a)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('VS',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.yellow,
                      fontSize: 18)),
            ),
            Expanded(child: _FinalCard(entry: f.b)),
          ],
        ),
      ],
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (w != null)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: AppColors.muted),
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Winnaar wijzigen'),
              onPressed: () => relay.setFinaleWinner(null),
            ),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: AppColors.muted),
            icon: const Icon(Icons.close_rounded),
            label: const Text('Finale annuleren'),
            onPressed: () async {
              if (await confirmDialog(context,
                  title: 'Finale annuleren?',
                  message: 'De finale wordt gewist. Je kunt hem daarna '
                      'opnieuw starten met de huidige top 2.',
                  confirm: 'Annuleren finale',
                  danger: true)) {
                relay.cancelFinale();
              }
            },
          ),
        ],
      ),
    ];
  }
}

class _FinalCard extends StatelessWidget {
  const _FinalCard({required this.entry});

  final RelayEntry entry;

  @override
  Widget build(BuildContext context) {
    return Glass(
      highlight: true,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
      onTap: () async {
        if (await confirmDialog(context,
            title: '${entry.label} wint?',
            message: '${entry.label} wordt de winnaar van de finale.',
            confirm: 'Winnaar!')) {
          relay.setFinaleWinner(entry.groupId);
        }
      },
      child: Column(
        children: [
          const Icon(Icons.sports_kabaddi_rounded,
              color: AppColors.yellow, size: 34),
          const SizedBox(height: 6),
          Text(entry.label,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          Text(entry.playersText,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.row});

  final int rank;
  final RelayRow row;

  @override
  Widget build(BuildContext context) {
    final finalist = rank <= 2;
    return Glass(
      highlight: finalist,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: finalist ? AppColors.yellowGradient : null,
              color: finalist ? null : Colors.white.withValues(alpha: 0.08),
            ),
            child: Text('$rank',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: finalist ? AppColors.black : AppColors.text)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(row.label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    if (finalist) ...[
                      const SizedBox(width: 8),
                      const Pill('Finale'),
                    ],
                  ],
                ),
                Text(row.players,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
          Text(formatTenths(row.timeMs),
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }
}

class _RunRow extends StatelessWidget {
  const _RunRow({required this.run});

  final RelayRun run;

  @override
  Widget build(BuildContext context) {
    final entries = [...run.entries]..sort((a, b) =>
        (a.timeMs ?? 1 << 30).compareTo(b.timeMs ?? 1 << 30));
    return Glass(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => _EditRunScreen(run: run))),
      child: Row(
        children: [
          Text('#${run.number}',
              style: const TextStyle(
                  color: AppColors.yellow, fontWeight: FontWeight.w900)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final e in entries)
                  Text(
                    '${e.label} · '
                    '${e.timeMs == null ? 'geen tijd' : formatTenths(e.timeMs!)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
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

class _EditRunScreen extends StatelessWidget {
  const _EditRunScreen({required this.run});

  final RelayRun run;

  Future<void> _editTime(BuildContext context, RelayEntry e) async {
    final ctrl = TextEditingController(
        text: e.timeMs == null ? '' : formatTenths(e.timeMs!));
    final formKey = GlobalKey<FormState>();
    final r = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Tijd ${e.label}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'Tijd', hintText: 'bijv. 3:25,4'),
            validator: (v) => parseTenths(v ?? '') == null
                ? 'Gebruik minuten:seconden,tienden'
                : null,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Annuleren')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(c, ctrl.text);
              }
            },
            child: const Text('Opslaan'),
          ),
        ],
      ),
    );
    if (r != null) relay.setEntryTime(e, parseTenths(r));
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        appBar: AppBar(title: Text('Ronde ${run.number} corrigeren')),
        body: ListenableBuilder(
          listenable: relay,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final e in [...run.entries])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Glass(
                    padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.label,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800)),
                              Text(e.playersText,
                                  style: const TextStyle(
                                      color: AppColors.muted, fontSize: 12)),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => _editTime(context, e),
                          child: Text(
                            e.timeMs == null
                                ? 'Tijd invullen'
                                : formatTenths(e.timeMs!),
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: AppColors.muted),
                          onPressed: () async {
                            if (await confirmDialog(context,
                                title: '${e.label} uit deze ronde halen?',
                                message: 'De tijd van deze groep in ronde '
                                    '${run.number} wordt verwijderd.',
                                confirm: 'Verwijderen',
                                danger: true)) {
                              relay.removeEntry(run, e);
                              if (run.entries.isEmpty && context.mounted) {
                                Navigator.pop(context);
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Hele ronde verwijderen'),
                onPressed: () async {
                  if (await confirmDialog(context,
                      title: 'Ronde ${run.number} verwijderen?',
                      message: 'Alle tijden van deze ronde verdwijnen van '
                          'het scorebord.',
                      confirm: 'Verwijderen',
                      danger: true)) {
                    relay.removeRun(run);
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
