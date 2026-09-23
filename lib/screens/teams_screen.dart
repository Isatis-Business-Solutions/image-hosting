import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/page.dart';
import 'players_screen.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scrollt mee als je tijdens het slepen bij de rand van het scherm komt.
  void _autoScroll(DragUpdateDetails d) {
    if (!_scroll.hasClients) return;
    final h = MediaQuery.of(context).size.height;
    final y = d.globalPosition.dy;
    double delta = 0;
    if (y < 160) delta = -18;
    if (y > h - 200) delta = 18;
    if (delta == 0) return;
    final pos = _scroll.position;
    _scroll.jumpTo(
        (pos.pixels + delta).clamp(pos.minScrollExtent, pos.maxScrollExtent));
  }

  Future<void> _randomize() async {
    if (store.teams.isNotEmpty &&
        !await confirmDialog(context,
            title: 'Opnieuw indelen?',
            message: 'Alle huidige teams worden vervangen door een nieuwe '
                'willekeurige indeling.',
            confirm: 'Indelen')) {
      return;
    }
    store.randomizeTeams();
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Teams',
      controller: _scroll,
      subtitle: () {
        final missing =
            store.teams.where((t) => !store.teamHasEmail(t)).length;
        return '${store.teams.length} teams'
            '${missing > 0 ? ' · $missing zonder e-mail' : ''}';
      },
      builder: (context) {
        final players = store.players;
        final unassigned = store.unassigned;
        if (players.length < 2) {
          return const [
            EmptyState(
              icon: Icons.groups_rounded,
              title: 'Eerst spelers toevoegen',
              text: 'Voeg minstens twee spelers toe bij "Spelers".',
            ),
          ];
        }
        return [
          GradientButton(
            label: store.teams.isEmpty
                ? 'Willekeurig indelen'
                : 'Opnieuw willekeurig indelen',
            icon: Icons.shuffle_rounded,
            onPressed: _randomize,
          ),
          if (store.teams.isNotEmpty && unassigned.length >= 2) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.group_add_rounded),
              label: Text('${unassigned.length} nieuwe spelers indelen'),
              onPressed: store.assignRemaining,
            ),
          ],
          if (store.teams.isNotEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 14, 4, 0),
              child: Text(
                'Houd een speler ingedrukt en sleep hem op een andere speler '
                'om ze te wisselen. Tik op een speler om naam of e-mail aan '
                'te passen.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ),
          if (unassigned.isNotEmpty) ...[
            SectionTitle('Niet ingedeeld (${unassigned.length})'),
            Glass(
              borderColor: AppColors.muted.withValues(alpha: 0.3),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in unassigned)
                    _PlayerChip(player: p, onDragUpdate: _autoScroll),
                ],
              ),
            ),
            if (unassigned.length.isOdd)
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Text(
                  'Oneven aantal: er blijft één speler over.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ),
          ],
          if (store.teams.isNotEmpty) ...[
            const SectionTitle('Teams'),
            for (final t in [...store.teams]
              ..sort((a, b) => a.number.compareTo(b.number)))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TeamCard(team: t, onDragUpdate: _autoScroll),
              ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Teams wissen'),
                onPressed: () async {
                  if (await confirmDialog(context,
                      title: 'Teams wissen?',
                      message: 'De indeling wordt gewist. Spelers blijven '
                          'bestaan.',
                      confirm: 'Wissen',
                      danger: true)) {
                    store.clearTeams();
                  }
                },
              ),
            ),
          ],
        ];
      },
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.team, required this.onDragUpdate});

  final Team team;
  final ValueChanged<DragUpdateDetails> onDragUpdate;

  @override
  Widget build(BuildContext context) {
    final hasEmail = store.teamHasEmail(team);
    final played = store.timesPlayed(team.id);
    return Glass(
      padding: const EdgeInsets.all(12),
      borderColor: hasEmail ? null : AppColors.danger.withValues(alpha: 0.6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(team.label,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              const Spacer(),
              if (played > 0) ...[
                Pill('${played}x gespeeld', color: AppColors.muted),
                const SizedBox(width: 6),
              ],
              if (!hasEmail)
                const Pill('Geen e-mail',
                    color: AppColors.danger, icon: Icons.warning_rounded),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final p in store.teamPlayers(team))
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _PlayerChip(
                        player: p, expand: true, onDragUpdate: onDragUpdate),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  const _PlayerChip({
    required this.player,
    required this.onDragUpdate,
    this.expand = false,
  });

  final Player player;
  final bool expand;
  final ValueChanged<DragUpdateDetails> onDragUpdate;

  Widget _chip({bool hover = false, bool dragging = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        color: hover
            ? AppColors.yellow.withValues(alpha: 0.25)
            : Colors.white.withValues(alpha: dragging ? 0.02 : 0.08),
        border: Border.all(
          color: hover
              ? AppColors.yellow
              : Colors.white.withValues(alpha: dragging ? 0.05 : 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Avatar(name: player.name, size: 28),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              player.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: dragging ? AppColors.muted : AppColors.text,
              ),
            ),
          ),
          if (player.hasEmail) ...[
            const SizedBox(width: 6),
            const Icon(Icons.mail_rounded, size: 16, color: AppColors.yellow),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data != player.id,
      onAcceptWithDetails: (d) => store.swapPlayers(d.data, player.id),
      builder: (context, candidates, _) => LongPressDraggable<String>(
        data: player.id,
        onDragUpdate: onDragUpdate,
        feedback: Material(
          color: Colors.transparent,
          child: Transform.scale(scale: 1.08, child: _chip(hover: true)),
        ),
        childWhenDragging: _chip(dragging: true),
        child: GestureDetector(
          onTap: () => showPlayerDialog(context, player: player),
          child: _chip(hover: candidates.isNotEmpty),
        ),
      ),
    );
  }
}
