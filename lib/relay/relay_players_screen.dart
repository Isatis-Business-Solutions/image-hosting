import 'package:flutter/material.dart';

import '../models.dart';
import '../screens/players_screen.dart' show Avatar;
import '../store.dart';
import '../theme.dart';
import '../widgets/page.dart';
import 'relay_store.dart';

class RelayPlayersScreen extends StatelessWidget {
  const RelayPlayersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Spelers',
      subtitle: () => '${relay.players.length} spelers voor de estafette',
      floating: FloatingActionButton.extended(
        heroTag: 'relay-add-player',
        onPressed: () => showRelayNameDialog(context),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Speler',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      builder: (context) {
        final importBtn = store.players.isEmpty
            ? null
            : OutlinedButton.icon(
                icon: const Icon(Icons.download_rounded),
                label: const Text('Namen overnemen uit Fotospel'),
                onPressed: () {
                  final n =
                      relay.importNames(store.players.map((p) => p.name));
                  toast(
                      context,
                      n == 0
                          ? 'Alle namen staan er al in.'
                          : '$n namen overgenomen.');
                },
              );
        if (relay.players.isEmpty) {
          return [
            const EmptyState(
              icon: Icons.directions_run_rounded,
              title: 'Nog geen spelers',
              text: 'Voeg spelers toe voor de estafette. Alleen een naam is '
                  'nodig.',
            ),
            ?importBtn,
          ];
        }
        return [
          ?importBtn,
          if (importBtn != null) const SizedBox(height: 12),
          for (final p in relay.players)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PlayerRow(player: p),
            ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: AppColors.muted),
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Alle spelers wissen'),
              onPressed: () async {
                if (await confirmDialog(context,
                    title: 'Alle spelers wissen?',
                    message: 'Alle estafettespelers en groepen worden '
                        'verwijderd. Tijden op het scorebord blijven staan.',
                    confirm: 'Wissen',
                    danger: true)) {
                  relay.clearPlayers();
                }
              },
            ),
          ),
        ];
      },
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final g = relay.groupOf(player.id);
    return Glass(
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
      onTap: () => showRelayNameDialog(context, player: player),
      child: Row(
        children: [
          Avatar(name: player.name, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Text(player.name,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          if (g != null) Pill(g.label, color: AppColors.muted),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.muted),
            onPressed: () async {
              if (await confirmDialog(context,
                  title: '${player.name} verwijderen?',
                  message: 'Deze speler wordt uit de estafette verwijderd.',
                  confirm: 'Verwijderen',
                  danger: true)) {
                relay.removePlayer(player);
              }
            },
          ),
        ],
      ),
    );
  }
}

Future<void> showRelayNameDialog(BuildContext context, {Player? player}) async {
  final ctrl = TextEditingController(text: player?.name ?? '');
  final formKey = GlobalKey<FormState>();
  var again = false;

  bool submit() {
    if (!formKey.currentState!.validate()) return false;
    if (player == null) {
      relay.addPlayer(ctrl.text);
    } else {
      relay.renamePlayer(player, ctrl.text);
    }
    return true;
  }

  await showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(player == null ? 'Nieuwe speler' : 'Naam wijzigen'),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
              labelText: 'Naam', prefixIcon: Icon(Icons.person_rounded)),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Vul een naam in' : null,
          onFieldSubmitted: (_) {
            if (submit()) {
              again = player == null;
              Navigator.pop(c);
            }
          },
        ),
      ),
      actions: [
        if (player == null)
          TextButton(
            onPressed: () {
              if (submit()) {
                again = true;
                Navigator.pop(c);
              }
            },
            child: const Text('Opslaan + nog één'),
          ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () {
            if (submit()) Navigator.pop(c);
          },
          child: const Text('Opslaan'),
        ),
      ],
    ),
  );
  if (again && context.mounted) await showRelayNameDialog(context);
}
