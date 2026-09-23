import 'package:flutter/material.dart';

import '../store.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // De "alles verwijderen"-knop is verstopt: tik 5x op de versie.
  int _taps = 0;
  bool get _unlocked => _taps >= 5;

  Future<void> _wipe() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setState) => AlertDialog(
          title: const Text('Alles verwijderen?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Alle spelers, teams, foto\'s en uitslagen worden '
                  'definitief verwijderd. Typ VERWIJDER om te bevestigen.'),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Annuleren')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 44)),
              onPressed: ctrl.text.trim().toUpperCase() == 'VERWIJDER'
                  ? () => Navigator.pop(c, true)
                  : null,
              child: const Text('Alles verwijderen'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await store.wipeAll();
    if (!mounted) return;
    toast(context, 'Alles is verwijderd.');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        appBar: AppBar(title: const Text('Instellingen')),
        body: ListenableBuilder(
          listenable: store,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SectionTitle('Timer'),
              Glass(
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Speeltijd per potje',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    IconButton(
                      onPressed: store.timerMinutes > 1
                          ? () =>
                              store.setTimerMinutes(store.timerMinutes - 1)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                    ),
                    Text('${store.timerMinutes} min',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    IconButton(
                      onPressed: store.timerMinutes < 30
                          ? () =>
                              store.setTimerMinutes(store.timerMinutes + 1)
                          : null,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                    ),
                  ],
                ),
              ),
              const SectionTitle('Overzicht'),
              Glass(
                child: Column(
                  children: [
                    _stat('Spelers', store.players.length),
                    _stat('Teams', store.teams.length),
                    _stat("Foto's", store.photos.length),
                    _stat('Gespeelde potjes', store.history.length),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: GestureDetector(
                  onTap: () => setState(() => _taps++),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Spelleider · versie 1.0',
                        style: TextStyle(color: AppColors.muted)),
                  ),
                ),
              ),
              if (_unlocked) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                  ),
                  icon: const Icon(Icons.delete_forever_rounded),
                  label: const Text('Alles verwijderen'),
                  onPressed: _wipe,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, int n) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
                child:
                    Text(label, style: const TextStyle(color: AppColors.muted))),
            Text('$n', style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      );
}
