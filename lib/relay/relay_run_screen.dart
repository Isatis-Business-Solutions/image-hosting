import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../theme.dart';
import '../widgets/page.dart';
import 'relay_models.dart';
import 'relay_store.dart';

class RelayRunScreen extends StatefulWidget {
  const RelayRunScreen({super.key});

  @override
  State<RelayRunScreen> createState() => _RelayRunScreenState();
}

class _RelayRunScreenState extends State<RelayRunScreen> {
  Timer? _ticker;
  bool _wakelock = false;
  final List<String> _selected = [];

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (_wakelock) WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }

  bool get _running {
    final r = relay.current;
    return r != null && r.started && !r.allStopped;
  }

  void _tick() {
    final run = _running;
    if (run != _wakelock) {
      _wakelock = run;
      WakelockPlus.toggle(enable: run).catchError((_) {});
    }
    if (run && mounted) setState(() {});
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else if (_selected.length < relay.groupsPerRun) {
        _selected.add(id);
      } else {
        toast(context,
            'Er doen ${relay.groupsPerRun} groepen per ronde mee. Haal er eerst '
            'een weg of pas het aantal aan bij Instellingen.');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: relay.current == null ? 'Ronde' : 'Ronde ${relay.current!.number}',
      subtitle: () {
        final r = relay.current;
        if (r == null) return 'Kies ${relay.groupsPerRun} groepen';
        if (!r.started) return 'Klaar om te starten';
        final left = r.entries.where((e) => e.timeMs == null).length;
        return left == 0 ? 'Alle groepen zijn binnen' : '$left nog bezig';
      },
      builder: (context) {
        final r = relay.current;
        if (r == null) return _choose(context);
        return _run(context, r);
      },
    );
  }

  // ------------------------------------------------------------ kiezen

  List<Widget> _choose(BuildContext context) {
    final groups = relay.sortedGroups;
    _selected.removeWhere((id) => relay.group(id) == null);
    if (groups.length < relay.groupsPerRun) {
      return [
        EmptyState(
          icon: Icons.diversity_3_rounded,
          title: 'Te weinig groepen',
          text: 'Er zijn ${groups.length} groepen; per ronde doen er '
              '${relay.groupsPerRun} mee. Deel eerst groepen in bij '
              '"Groepen", of pas het aantal aan bij Instellingen.',
        ),
      ];
    }
    final n = relay.groupsPerRun;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
        child: Text(
          'Kies de $n groepen die tegelijk starten '
          '(${_selected.length}/$n gekozen).',
          style: const TextStyle(color: AppColors.muted),
        ),
      ),
      for (final g in groups)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Glass(
            highlight: _selected.contains(g.id),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onTap: () => _toggle(g.id),
            child: Row(
              children: [
                Icon(
                  _selected.contains(g.id)
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: _selected.contains(g.id)
                      ? AppColors.yellow
                      : AppColors.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.label,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                      Text(
                        relay.groupPlayers(g).map((p) => p.name).join(', '),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                if (relay.timesRun(g.id) > 0)
                  const Pill('gelopen', color: AppColors.ok),
              ],
            ),
          ),
        ),
      const SizedBox(height: 8),
      GradientButton(
        label: 'Start de timer',
        icon: Icons.play_arrow_rounded,
        height: 64,
        onPressed: _selected.length == n
            ? () {
                relay.prepareRun(
                    _selected.map((id) => relay.group(id)!).toList());
                relay.startRun();
                _selected.clear();
              }
            : null,
      ),
    ];
  }

  // ------------------------------------------------------------ ronde

  List<Widget> _run(BuildContext context, RelayRun r) {
    final now = DateTime.now();
    final elapsed = r.elapsedAt(now);
    return [
      Glass(
        highlight: _running,
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Column(
          children: [
            Text(
              formatTenths(r.started ? elapsed : 0),
              style: const TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w900,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              !r.started
                  ? 'Nog niet gestart'
                  : (r.allStopped ? 'Alle groepen gestopt' : 'Loopt…'),
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      for (var i = 0; i < r.entries.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _EntryCard(run: r, index: i, now: now),
        ),
      const SizedBox(height: 6),
      if (!r.started)
        GradientButton(
          label: 'Start de timer',
          icon: Icons.play_arrow_rounded,
          height: 64,
          onPressed: relay.startRun,
        ),
      if (r.started && r.allStopped)
        GradientButton(
          label: 'Ronde opslaan',
          icon: Icons.save_rounded,
          onPressed: () {
            relay.saveRun();
            toast(context, 'Opgeslagen! Bekijk het klassement bij "Scores".');
          },
        ),
      const SizedBox(height: 10),
      if (r.started)
        OutlinedButton.icon(
          icon: const Icon(Icons.replay_rounded),
          label: const Text('Timer resetten'),
          onPressed: () async {
            if (await confirmDialog(context,
                title: 'Timer resetten?',
                message: 'De timer gaat terug naar 0 en alle tijden van deze '
                    'ronde worden gewist.',
                confirm: 'Resetten')) {
              relay.resetRun();
            }
          },
        ),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Center(
          child: TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: AppColors.muted),
            icon: const Icon(Icons.close_rounded),
            label: const Text('Ronde annuleren'),
            onPressed: () async {
              if (await confirmDialog(context,
                  title: 'Ronde annuleren?',
                  message: 'Deze ronde wordt weggegooid en telt niet mee.',
                  confirm: 'Weggooien',
                  danger: true)) {
                relay.cancelRun();
              }
            },
          ),
        ),
      ),
    ];
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.run, required this.index, required this.now});

  final RelayRun run;
  final int index;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final e = run.entries[index];
    final stopped = e.timeMs != null;
    final time = stopped ? e.timeMs! : run.elapsedAt(now);
    return Glass(
      highlight: stopped,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.label,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                Text(e.playersText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 4),
                Text(
                  formatTenths(run.started ? time : 0),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: stopped ? AppColors.yellow : AppColors.text,
                  ),
                ),
              ],
            ),
          ),
          if (run.started && !stopped)
            SizedBox(
              width: 120,
              height: 76,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: () => relay.stopEntry(index),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stop_rounded, size: 30),
                    Text('STOP',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 16)),
                  ],
                ),
              ),
            ),
          if (stopped)
            Column(
              children: [
                const Icon(Icons.flag_rounded,
                    color: AppColors.yellow, size: 30),
                TextButton(
                  style:
                      TextButton.styleFrom(foregroundColor: AppColors.muted),
                  onPressed: () async {
                    if (await confirmDialog(context,
                        title: '${e.label} verder laten lopen?',
                        message: 'Per ongeluk gestopt? De tijd loopt weer '
                            'door vanaf de gezamenlijke start.',
                        confirm: 'Verder')) {
                      relay.resumeEntry(index);
                    }
                  },
                  child: const Text('Oeps, verder'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
