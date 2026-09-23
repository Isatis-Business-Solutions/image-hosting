import 'package:flutter/material.dart';

import '../logic.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';

/// Punten, winnaar en "telt mee"-vinkjes van een potje. Wordt gebruikt na
/// afloop van een potje en om een eerder potje te corrigeren.
class ResultEditor extends StatelessWidget {
  const ResultEditor({super.key, required this.match});

  final GameMatch match;

  @override
  Widget build(BuildContext context) {
    final m = match;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < 2; i++) ...[
          _SideResult(match: m, side: i),
          const SizedBox(height: 10),
        ],
        const SectionTitle('Winnaar'),
        SegmentedButton<int>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: AppColors.yellow,
            selectedForegroundColor: AppColors.black,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          ),
          segments: [
            ButtonSegment(value: 0, label: Text(m.a!.teamLabel)),
            const ButtonSegment(value: -1, label: Text('Geen')),
            ButtonSegment(value: 1, label: Text(m.b!.teamLabel)),
          ],
          selected: {m.winnerSide ?? -1},
          onSelectionChanged: (s) =>
              store.setWinner(m, s.first == -1 ? null : s.first),
        ),
        if (m.winnerSide == null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Nog geen winnaar: vul de punten in of kies zelf.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),
      ],
    );
  }
}

class _SideResult extends StatelessWidget {
  const _SideResult({required this.match, required this.side});

  final GameMatch match;
  final int side;

  @override
  Widget build(BuildContext context) {
    final s = match.side(side);
    final isWinner = match.winnerSide == side;
    final finished = match.finishedSide == side;
    return Glass(
      highlight: isWinner,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isWinner) ...[
                const Icon(Icons.emoji_events_rounded,
                    color: AppColors.yellow),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.teamLabel,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                    Text(s.playersText,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted)),
                  ],
                ),
              ),
              if (finished && match.finishTimeMs != null)
                Pill('Klaar in ${formatMs(match.finishTimeMs!)}',
                    icon: Icons.timer_rounded),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Punten', style: TextStyle(color: AppColors.muted)),
              const Spacer(),
              _Stepper(
                value: s.points,
                onChanged: (v) => store.setPoints(match, side, v),
              ),
            ],
          ),
          Row(
            children: [
              const Expanded(
                child: Text('Telt mee voor het klassement',
                    style: TextStyle(color: AppColors.muted)),
              ),
              Switch(
                value: s.counts,
                activeThumbColor: AppColors.black,
                activeTrackColor: AppColors.yellow,
                onChanged: (v) => store.setCounts(match, side, v),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  Future<void> _type(BuildContext context) async {
    final ctrl = TextEditingController(text: value?.toString() ?? '');
    final r = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Punten'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          onSubmitted: (v) => Navigator.pop(c, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, ''), child: const Text('Leeg')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(c, ctrl.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (r == null) return;
    final n = int.tryParse(r.trim());
    onChanged(n?.clamp(0, 999));
  }

  @override
  Widget build(BuildContext context) {
    final v = value;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _round(Icons.remove_rounded,
            v == null || v <= 0 ? null : () => onChanged(v - 1)),
        GestureDetector(
          onTap: () => _type(context),
          child: Container(
            width: 64,
            alignment: Alignment.center,
            child: Text(
              v?.toString() ?? '–',
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text),
            ),
          ),
        ),
        _round(Icons.add_rounded, () => onChanged((v ?? 0) + 1)),
      ],
    );
  }

  Widget _round(IconData icon, VoidCallback? onTap) => IconButton.filledTonal(
        onPressed: onTap,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.10),
          foregroundColor: AppColors.yellow,
        ),
        icon: Icon(icon),
      );
}
