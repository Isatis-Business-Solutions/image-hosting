import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../logic.dart';
import '../models.dart';
import '../services/alarm.dart';
import '../services/mailer.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/page.dart';
import '../widgets/result_editor.dart';
import 'photos_screen.dart';

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  Timer? _ticker;
  bool _wakelock = false;
  final _scroll = ScrollController();
  Object? _lastStage;

  @override
  void initState() {
    super.initState();
    // Tikt altijd door (ook op andere tabbladen), zodat het alarm afgaat.
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _scroll.dispose();
    WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }

  void _tick() {
    final m = store.current;
    final wantWake = m != null && m.stage == MatchStage.play;
    if (wantWake != _wakelock) {
      _wakelock = wantWake;
      WakelockPlus.toggle(enable: wantWake).catchError((_) {});
    }
    if (store.checkTimeUp()) {
      Alarm.ring();
      if (mounted) toast(context, 'Tijd is om! Vul de punten in.');
    }
    if (m != null && m.running && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      controller: _scroll,
      title: store.current == null
          ? 'Potje'
          : 'Potje ${store.current!.number}',
      subtitle: () => store.current == null
          ? '${store.history.length} potjes gespeeld'
          : _stageTitle(store.current!.stage),
      builder: (context) {
        final m = store.current;
        // Nieuwe stap: terug naar boven scrollen.
        final stage = (m?.id, m?.stage);
        if (stage != _lastStage) {
          _lastStage = stage;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scroll.hasClients) _scroll.jumpTo(0);
          });
        }
        if (m == null) return [_NoMatch()];
        return [
          _StepBar(stage: m.stage),
          const SizedBox(height: 16),
          ...switch (m.stage) {
            MatchStage.teams => [_ChooseTeams(key: ValueKey(m.id))],
            MatchStage.photos => _photos(context, m),
            MatchStage.send => _send(context, m),
            MatchStage.play => _play(context, m),
            MatchStage.result => _result(context, m),
          },
        ];
      },
    );
  }

  static String _stageTitle(MatchStage s) => switch (s) {
        MatchStage.teams => 'Stap 1 · Teams kiezen',
        MatchStage.photos => "Stap 2 · Foto's controleren",
        MatchStage.send => "Stap 3 · Foto's versturen",
        MatchStage.play => 'Stap 4 · Spelen',
        MatchStage.result => 'Stap 5 · Uitslag',
      };

  // ------------------------------------------------------------ stap 2

  List<Widget> _photos(BuildContext context, GameMatch m) {
    return [
      for (var i = 0; i < 2; i++) ...[
        _SideCard(
          side: m.side(i),
          trailing: TextButton.icon(
            icon: const Icon(Icons.casino_rounded),
            label: const Text('Andere foto'),
            onPressed: store.photos.isEmpty ? null : () => store.redrawPhoto(i),
          ),
        ),
        const SizedBox(height: 12),
      ],
      if (m.a!.photoId != null &&
          m.a!.photoId == m.b!.photoId &&
          store.photos.length < 2)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('Let op: er is maar één foto, dus beide teams krijgen '
              'dezelfde.', style: TextStyle(color: AppColors.muted)),
        ),
      GradientButton(
        label: 'Bevestigen',
        icon: Icons.verified_rounded,
        onPressed: m.a!.photoId == null || m.b!.photoId == null
            ? null
            : store.confirmPhotos,
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        icon: const Icon(Icons.undo_rounded),
        label: const Text('Andere teams kiezen'),
        onPressed: () => store.setStage(MatchStage.teams),
      ),
      _CancelButton(),
    ];
  }

  // ------------------------------------------------------------ stap 3

  Future<void> _sendMail(BuildContext context, GameMatch m, int i) async {
    final s = m.side(i);
    final photo = store.photo(s.photoId);
    final to = store.emailsFor(s);
    if (photo == null) {
      toast(context, 'De foto bestaat niet meer. Kies een andere foto.');
      return;
    }
    if (to.isEmpty) {
      toast(context,
          '${s.teamLabel} heeft geen e-mailadres. Voeg er een toe bij Teams.');
      return;
    }
    try {
      await openMailForSide(side: s, recipients: to, photoPath: photo.path);
      store.markSent(i, true);
    } on FlutterEmailSenderNotAvailableException {
      if (context.mounted) {
        toast(context, 'Geen mailapp gevonden. Installeer of koppel Gmail.');
      }
    } catch (e) {
      if (context.mounted) toast(context, 'Mail openen mislukt: $e');
    }
  }

  List<Widget> _send(BuildContext context, GameMatch m) {
    final allSent = m.a!.sent && m.b!.sent;
    return [
      const Padding(
        padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
        child: Text(
          'Per team opent je mailapp met de foto al klaargezet. Druk daar op '
          'verzenden en kom terug naar deze app.',
          style: TextStyle(color: AppColors.muted),
        ),
      ),
      for (var i = 0; i < 2; i++) ...[
        _SideCard(
          side: m.side(i),
          showEmails: true,
          footer: Row(
            children: [
              Expanded(
                child: m.side(i).sent
                    ? OutlinedButton.icon(
                        icon: const Icon(Icons.check_circle_rounded,
                            color: AppColors.ok),
                        label: const Text('Klaargezet · opnieuw'),
                        onPressed: () => _sendMail(context, m, i),
                      )
                    : FilledButton.icon(
                        icon: const Icon(Icons.send_rounded),
                        label: Text('Mail ${m.side(i).teamLabel}'),
                        onPressed: () => _sendMail(context, m, i),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
      GradientButton(
        label: 'Naar het spel',
        icon: Icons.sports_esports_rounded,
        onPressed: () async {
          if (!allSent &&
              !await confirmDialog(context,
                  title: 'Nog niet alles verstuurd',
                  message: 'Niet voor beide teams is de mail klaargezet. '
                      'Toch doorgaan?',
                  confirm: 'Doorgaan')) {
            return;
          }
          store.setStage(MatchStage.play);
        },
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        icon: const Icon(Icons.undo_rounded),
        label: const Text("Foto's aanpassen"),
        onPressed: () => store.setStage(MatchStage.photos),
      ),
      _CancelButton(),
    ];
  }

  // ------------------------------------------------------------ stap 4

  List<Widget> _play(BuildContext context, GameMatch m) {
    final elapsed = m.elapsedAt(DateTime.now());
    final remaining = max(0, store.timerMs - elapsed);
    final started = m.timerStarted;
    return [
      Glass(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            _TimerRing(
              progress: remaining / store.timerMs,
              label: formatMs(remaining),
              sub: !started
                  ? 'Klaar om te starten'
                  : (m.running ? 'Bezig…' : 'Gepauzeerd'),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: !started
                  ? GradientButton(
                      label: 'Start ${store.timerMinutes} minuten',
                      icon: Icons.play_arrow_rounded,
                      height: 64,
                      onPressed: store.startTimer,
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(m.running
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded),
                            label: Text(m.running ? 'Pauze' : 'Hervat'),
                            onPressed: m.running
                                ? store.pauseTimer
                                : store.startTimer,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.replay_rounded),
                            label: const Text('Opnieuw'),
                            onPressed: () async {
                              if (await confirmDialog(context,
                                  title: 'Timer resetten?',
                                  message: 'De timer gaat terug naar '
                                      '${store.timerMinutes}:00.',
                                  confirm: 'Resetten')) {
                                store.resetTimer();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      const SectionTitle('Welk team is als eerste klaar?'),
      Row(
        children: [
          for (var i = 0; i < 2; i++) ...[
            if (i == 1) const SizedBox(width: 12),
            Expanded(
              child: _FinishButton(
                side: m.side(i),
                enabled: started,
                onTap: () => store.finishBy(i),
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 12),
      if (started)
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: AppColors.muted),
          icon: const Icon(Icons.stop_rounded),
          label: const Text('Stoppen en punten invullen'),
          onPressed: () async {
            if (await confirmDialog(context,
                title: 'Potje stoppen?',
                message: 'De timer stopt zonder dat een team klaar is. Je '
                    'vult daarna de punten in.',
                confirm: 'Stoppen')) {
              store.endWithoutFinish();
            }
          },
        ),
      if (!started)
        OutlinedButton.icon(
          icon: const Icon(Icons.undo_rounded),
          label: const Text('Terug naar versturen'),
          onPressed: () => store.setStage(MatchStage.send),
        ),
      _CancelButton(),
    ];
  }

  // ------------------------------------------------------------ stap 5

  List<Widget> _result(BuildContext context, GameMatch m) {
    final headline = m.finishedSide != null
        ? '${m.side(m.finishedSide!).teamLabel} was klaar in '
            '${formatMs(m.finishTimeMs ?? 0)}'
        : (m.timeUp ? 'De tijd is om' : 'Potje gestopt');
    return [
      Glass(
        highlight: true,
        child: Row(
          children: [
            Icon(
                m.finishedSide != null
                    ? Icons.flag_rounded
                    : Icons.alarm_rounded,
                color: AppColors.yellow,
                size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(headline,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                  const Text('Vul de punten in: het aantal dichtgeklapte '
                      'kaartjes op het eigen bord.',
                      style: TextStyle(color: AppColors.muted, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      ResultEditor(match: m),
      const SizedBox(height: 20),
      GradientButton(
        label: 'Uitslag opslaan',
        icon: Icons.save_rounded,
        onPressed: () async {
          if (m.winnerSide == null &&
              !await confirmDialog(context,
                  title: 'Geen winnaar',
                  message: 'Er is geen winnaar gekozen. Toch opslaan?',
                  confirm: 'Opslaan')) {
            return;
          }
          store.saveMatch();
          Alarm.stop();
          if (context.mounted) {
            toast(context, 'Opgeslagen! Bekijk het scorebord bij "Scores".');
          }
        },
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        icon: const Icon(Icons.replay_rounded),
        label: const Text('Terug naar de timer'),
        onPressed: () async {
          if (await confirmDialog(context,
              title: 'Terug naar de timer?',
              message: 'De timer, punten en winnaar worden gewist.',
              confirm: 'Terug')) {
            store.resetTimer();
            store.setStage(MatchStage.play);
          }
        },
      ),
      _CancelButton(),
    ];
  }
}

// ------------------------------------------------------------- onderdelen

class _NoMatch extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final teamsOk = store.teams.length >= 2;
    final photosOk = store.photos.isNotEmpty;
    final ok = teamsOk && photosOk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Glass(
          highlight: ok,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.sports_esports_rounded,
                  size: 56, color: AppColors.yellow),
              const SizedBox(height: 10),
              Text(
                'Potje ${store.history.isEmpty ? 1 : store.history.map((m) => m.number).reduce(max) + 1}',
                style:
                    const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              _check(teamsOk, '${store.teams.length} teams (minstens 2)'),
              _check(photosOk, "${store.photos.length} foto's (minstens 1)"),
              const SizedBox(height: 18),
              GradientButton(
                label: 'Nieuw potje',
                icon: Icons.add_rounded,
                onPressed: ok ? store.newMatch : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _check(bool ok, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 18, color: ok ? AppColors.ok : AppColors.danger),
            const SizedBox(width: 8),
            Flexible(
                child: Text(text,
                    style: const TextStyle(color: AppColors.muted))),
          ],
        ),
      );
}

class _StepBar extends StatelessWidget {
  const _StepBar({required this.stage});

  final MatchStage stage;

  static const _labels = ['Teams', "Foto's", 'Mail', 'Spel', 'Uitslag'];

  @override
  Widget build(BuildContext context) {
    final cur = stage.index;
    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++)
          Expanded(
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: i <= cur ? AppColors.yellowGradient : null,
                    color: i <= cur ? null : Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _labels[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: i == cur ? FontWeight.w800 : FontWeight.w500,
                    color: i == cur ? AppColors.yellow : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ChooseTeams extends StatefulWidget {
  const _ChooseTeams({super.key});

  @override
  State<_ChooseTeams> createState() => _ChooseTeamsState();
}

class _ChooseTeamsState extends State<_ChooseTeams> {
  final List<String> _selected = [];

  @override
  void initState() {
    super.initState();
    final m = store.current!;
    // Terug vanuit stap 2: vorige keuze onthouden.
    for (final s in [m.a, m.b]) {
      if (s != null && store.team(s.teamId) != null) _selected.add(s.teamId);
    }
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        if (_selected.length == 2) _selected.removeAt(0);
        _selected.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final teams = [...store.teams]..sort((a, b) => a.number.compareTo(b.number));
    _selected.removeWhere((id) => store.team(id) == null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Text('Kies de twee teams die tegen elkaar spelen.',
              style: TextStyle(color: AppColors.muted)),
        ),
        for (final t in teams)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _selectableTeam(t),
          ),
        const SizedBox(height: 8),
        GradientButton(
          label: "Foto's trekken",
          icon: Icons.casino_rounded,
          onPressed: _selected.length == 2
              ? () => store.chooseTeams(
                  store.team(_selected[0])!, store.team(_selected[1])!)
              : null,
        ),
        _CancelButton(),
      ],
    );
  }

  Widget _selectableTeam(Team t) {
    final sel = _selected.contains(t.id);
    final played = store.timesPlayed(t.id);
    final hasEmail = store.teamHasEmail(t);
    return Glass(
      highlight: sel,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => _toggle(t.id),
      child: Row(
        children: [
          Icon(sel ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: sel ? AppColors.yellow : AppColors.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.label,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
                Text(store.teamPlayers(t).map((p) => p.name).join(' & '),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
          if (!hasEmail)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.mail_lock_rounded,
                  color: AppColors.danger, size: 20),
            ),
          if (played > 0)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Pill('${played}x', color: AppColors.muted),
            ),
        ],
      ),
    );
  }
}

class _SideCard extends StatelessWidget {
  const _SideCard({
    required this.side,
    this.trailing,
    this.footer,
    this.showEmails = false,
  });

  final Side side;
  final Widget? trailing;
  final Widget? footer;
  final bool showEmails;

  @override
  Widget build(BuildContext context) {
    final photo = store.photo(side.photoId);
    final emails = store.emailsFor(side);
    return Glass(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(side.teamLabel,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                    Text(side.playersText,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted)),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: photo == null
                  ? Container(
                      color: AppColors.grey,
                      alignment: Alignment.center,
                      child: const Text('Geen foto',
                          style: TextStyle(color: AppColors.muted)),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        PhotoImage(path: photo.path),
                        // Voorbeeld van de balk die op de foto komt.
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: const BoxDecoration(
                              color: Color(0xE6101013),
                              border: Border(
                                  top: BorderSide(
                                      color: AppColors.yellow, width: 2)),
                            ),
                            child: Text(
                              side.photoName ?? photo.name,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.yellow,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          if (showEmails) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.alternate_email_rounded,
                    size: 16,
                    color: emails.isEmpty ? AppColors.danger : AppColors.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    emails.isEmpty ? 'Geen e-mailadres!' : emails.join(', '),
                    style: TextStyle(
                        color:
                            emails.isEmpty ? AppColors.danger : AppColors.muted),
                  ),
                ),
              ],
            ),
          ],
          if (footer != null) ...[const SizedBox(height: 10), footer!],
        ],
      ),
    );
  }
}

class _FinishButton extends StatelessWidget {
  const _FinishButton(
      {required this.side, required this.enabled, required this.onTap});

  final Side side;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Glass(
        highlight: enabled,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
        onTap: enabled
            ? () async {
                if (await confirmDialog(context,
                    title: '${side.teamLabel} klaar?',
                    message: 'De timer stopt en ${side.teamLabel} wint.',
                    confirm: 'Klaar!')) {
                  onTap();
                }
              }
            : null,
        child: Column(
          children: [
            const Icon(Icons.flag_rounded, color: AppColors.yellow, size: 30),
            const SizedBox(height: 6),
            Text('${side.teamLabel} klaar',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text(side.playersText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _TimerRing extends StatelessWidget {
  const _TimerRing(
      {required this.progress, required this.label, required this.sub});

  final double progress;
  final String label;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final urgent = progress < 0.1;
    return SizedBox(
      width: 240,
      height: 240,
      child: CustomPaint(
        painter: _RingPainter(progress.clamp(0, 1)),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: urgent ? AppColors.danger : AppColors.text,
                ),
              ),
              Text(sub, style: const TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    canvas.drawArc(
      r,
      0,
      2 * pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.white.withValues(alpha: 0.08),
    );
    if (progress <= 0) return;
    canvas.drawArc(
      r,
      -pi / 2,
      2 * pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = const SweepGradient(
          colors: [AppColors.amber, AppColors.yellow, AppColors.amber],
          transform: GradientRotation(-pi / 2),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

class _CancelButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Center(
        child: TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: AppColors.muted),
          icon: const Icon(Icons.close_rounded),
          label: const Text('Potje annuleren'),
          onPressed: () async {
            if (await confirmDialog(context,
                title: 'Potje annuleren?',
                message: 'Dit potje wordt weggegooid en telt niet mee.',
                confirm: 'Weggooien',
                danger: true)) {
              store.cancelMatch();
              Alarm.stop();
            }
          },
        ),
      ),
    );
  }
}
