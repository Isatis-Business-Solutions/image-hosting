import 'package:flutter/material.dart';

import '../logic.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/page.dart';

class PlayersScreen extends StatelessWidget {
  const PlayersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Spelers',
      subtitle: () {
        final n = store.players.length;
        final m = store.players.where((p) => p.hasEmail).length;
        return '$n spelers · $m met e-mail';
      },
      floating: FloatingActionButton.extended(
        onPressed: () => showPlayerDialog(context),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Speler',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      builder: (context) {
        if (store.players.isEmpty) {
          return const [
            EmptyState(
              icon: Icons.person_add_alt_1_rounded,
              title: 'Nog geen spelers',
              text: 'Voeg spelers toe met een naam en eventueel een '
                  'e-mailadres.',
            ),
          ];
        }
        return [
          for (final p in store.players)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PlayerTile(player: p),
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
                    message:
                        'Alle spelers en teams worden verwijderd. Foto\'s en '
                        'het scorebord blijven bestaan.',
                    confirm: 'Wissen',
                    danger: true)) {
                  store.clearPlayers();
                }
              },
            ),
          ),
        ];
      },
    );
  }
}

class PlayerTile extends StatelessWidget {
  const PlayerTile({super.key, required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final team = store.teamOf(player.id);
    return Glass(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      onTap: () => showPlayerDialog(context, player: player),
      child: Row(
        children: [
          Avatar(name: player.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  player.hasEmail ? player.email! : 'Geen e-mailadres',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: player.hasEmail
                          ? AppColors.muted
                          : AppColors.muted.withValues(alpha: 0.6),
                      fontStyle: player.hasEmail
                          ? FontStyle.normal
                          : FontStyle.italic),
                ),
              ],
            ),
          ),
          if (team != null) Pill(team.label, color: AppColors.muted),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.muted),
            onPressed: () async {
              if (await confirmDialog(context,
                  title: '${player.name} verwijderen?',
                  message: team == null
                      ? 'Deze speler wordt verwijderd.'
                      : 'Deze speler zit in ${team.label}. Dat team wordt '
                          'opgeheven; de teamgenoot komt bij "niet ingedeeld".',
                  confirm: 'Verwijderen',
                  danger: true)) {
                store.removePlayer(player);
              }
            },
          ),
        ],
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.size = 40});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.yellowGradient,
      ),
      child: Text(letter,
          style: TextStyle(
              color: AppColors.black,
              fontWeight: FontWeight.w900,
              fontSize: size * 0.42)),
    );
  }
}

/// Dialoog om een speler toe te voegen of te bewerken.
Future<void> showPlayerDialog(BuildContext context, {Player? player}) async {
  final name = TextEditingController(text: player?.name ?? '');
  final email = TextEditingController(text: player?.email ?? '');
  final formKey = GlobalKey<FormState>();
  var addAnother = false;

  bool submit() {
    if (!formKey.currentState!.validate()) return false;
    if (player == null) {
      store.addPlayer(name.text, email.text);
    } else {
      store.updatePlayer(player, name.text, email.text);
    }
    return true;
  }

  await showDialog<void>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => AlertDialog(
        title: Text(player == null ? 'Nieuwe speler' : 'Speler bewerken'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Naam', prefixIcon: Icon(Icons.person_rounded)),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Vul een naam in' : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'E-mail (optioneel)',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? null
                    : (isValidEmail(v) ? null : 'Ongeldig e-mailadres'),
                onFieldSubmitted: (_) {
                  if (submit()) Navigator.pop(c);
                },
              ),
            ],
          ),
        ),
        actions: [
          if (player == null)
            TextButton(
              onPressed: () {
                if (submit()) {
                  addAnother = true;
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
    ),
  );
  if (addAnother && context.mounted) {
    await showPlayerDialog(context);
  }
}
