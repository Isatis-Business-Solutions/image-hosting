import 'package:flutter/material.dart';

import '../models.dart';
import '../screens/players_screen.dart' show Avatar;
import '../theme.dart';
import '../widgets/page.dart';
import 'relay_models.dart';
import 'relay_players_screen.dart';
import 'relay_store.dart';

class RelayGroupsScreen extends StatefulWidget {
  const RelayGroupsScreen({super.key});

  @override
  State<RelayGroupsScreen> createState() => _RelayGroupsScreenState();
}

class _RelayGroupsScreenState extends State<RelayGroupsScreen> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

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
    if (relay.groups.isNotEmpty &&
        !await confirmDialog(context,
            title: 'Opnieuw indelen?',
            message: 'Alle huidige groepen worden vervangen door een nieuwe '
                'willekeurige indeling.',
            confirm: 'Indelen')) {
      return;
    }
    relay.randomizeGroups();
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Groepen',
      controller: _scroll,
      subtitle: () {
        final n = relay.players.length;
        return relay.groups.isEmpty
            ? '$n spelers · wordt ${groupCountFor(n)} groepen'
            : '${relay.groups.length} groepen';
      },
      builder: (context) {
        if (relay.players.length < 2) {
          return const [
            EmptyState(
              icon: Icons.diversity_3_rounded,
              title: 'Eerst spelers toevoegen',
              text: 'Voeg spelers toe bij "Spelers".',
            ),
          ];
        }
        final unassigned = relay.unassigned;
        return [
          GradientButton(
            label: relay.groups.isEmpty
                ? 'Willekeurig indelen'
                : 'Opnieuw willekeurig indelen',
            icon: Icons.shuffle_rounded,
            onPressed: _randomize,
          ),
          if (relay.groups.isNotEmpty && unassigned.isNotEmpty) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.group_add_rounded),
              label: Text('${unassigned.length} nieuwe spelers indelen'),
              onPressed: relay.assignRemaining,
            ),
          ],
          if (relay.groups.isNotEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 14, 4, 0),
              child: Text(
                'Houd een speler ingedrukt en sleep hem op een andere speler '
                'om te wisselen, of op een groep om hem te verplaatsen.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ),
          if (unassigned.isNotEmpty) ...[
            SectionTitle('Niet ingedeeld (${unassigned.length})'),
            Glass(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in unassigned)
                    _Chip(player: p, onDragUpdate: _autoScroll),
                ],
              ),
            ),
          ],
          if (relay.groups.isNotEmpty) ...[
            const SectionTitle('Groepen'),
            for (final g in relay.sortedGroups)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _GroupCard(group: g, onDragUpdate: _autoScroll),
              ),
            OutlinedButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: const Text('Lege groep toevoegen'),
              onPressed: relay.addEmptyGroup,
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Groepen wissen'),
                onPressed: () async {
                  if (await confirmDialog(context,
                      title: 'Groepen wissen?',
                      message: 'De indeling wordt gewist. Spelers blijven '
                          'bestaan.',
                      confirm: 'Wissen',
                      danger: true)) {
                    relay.clearGroups();
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

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.onDragUpdate});

  final RelayGroup group;
  final ValueChanged<DragUpdateDetails> onDragUpdate;

  @override
  Widget build(BuildContext context) {
    final players = relay.groupPlayers(group);
    final runs = relay.timesRun(group.id);
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => relay.groupOf(d.data) != group,
      onAcceptWithDetails: (d) => relay.movePlayer(d.data, group),
      builder: (context, candidates, _) => Glass(
        padding: const EdgeInsets.all(12),
        highlight: candidates.isNotEmpty,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(group.label,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                Pill('${players.length} spelers',
                    color: players.length == 4
                        ? AppColors.muted
                        : AppColors.amber),
                const Spacer(),
                if (runs > 0) Pill('gelopen', color: AppColors.ok),
                if (players.isEmpty)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.muted),
                    onPressed: () => relay.removeGroupIfEmpty(group),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (players.isEmpty)
              const Text('Sleep spelers hierheen',
                  style: TextStyle(color: AppColors.muted)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in players)
                  _Chip(player: p, onDragUpdate: onDragUpdate),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.player, required this.onDragUpdate});

  final Player player;
  final ValueChanged<DragUpdateDetails> onDragUpdate;

  Widget _chip({bool hover = false, bool dragging = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.fromLTRB(5, 5, 12, 5),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Avatar(name: player.name, size: 26),
          const SizedBox(width: 8),
          Text(player.name,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: dragging ? AppColors.muted : AppColors.text)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data != player.id,
      onAcceptWithDetails: (d) => relay.swapPlayers(d.data, player.id),
      builder: (context, candidates, _) => LongPressDraggable<String>(
        data: player.id,
        onDragUpdate: onDragUpdate,
        feedback: Material(
          color: Colors.transparent,
          child: Transform.scale(scale: 1.08, child: _chip(hover: true)),
        ),
        childWhenDragging: _chip(dragging: true),
        child: GestureDetector(
          onTap: () => showRelayNameDialog(context, player: player),
          child: _chip(hover: candidates.isNotEmpty),
        ),
      ),
    );
  }
}
