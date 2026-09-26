import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'relay/relay_groups_screen.dart';
import 'relay/relay_players_screen.dart';
import 'relay/relay_run_screen.dart';
import 'relay/relay_score_screen.dart';
import 'relay/relay_store.dart';
import 'screens/match_screen.dart';
import 'screens/photos_screen.dart';
import 'screens/players_screen.dart';
import 'screens/scoreboard_screen.dart';
import 'screens/teams_screen.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.black,
  ));
  await store.load();
  await relay.load();
  runApp(const SpelleiderApp());
}

class SpelleiderApp extends StatelessWidget {
  const SpelleiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spelleider',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      builder: (context, child) => GradientBackground(child: child!),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  // Loopt er nog een potje / ronde, dan meteen daarheen.
  late int _photoIndex = store.current != null ? 3 : 0;
  late int _relayIndex = relay.current != null ? 2 : 0;

  static const _photoScreens = [
    PlayersScreen(),
    TeamsScreen(),
    PhotosScreen(),
    MatchScreen(),
    ScoreboardScreen(),
  ];

  static const _relayScreens = [
    RelayPlayersScreen(),
    RelayGroupsScreen(),
    RelayRunScreen(),
    RelayScoreScreen(),
  ];

  static const _photoItems = [
    (Icons.person_rounded, 'Spelers'),
    (Icons.groups_rounded, 'Teams'),
    (Icons.photo_library_rounded, "Foto's"),
    (Icons.sports_esports_rounded, 'Potje'),
    (Icons.emoji_events_rounded, 'Scores'),
  ];

  static const _relayItems = [
    (Icons.person_rounded, 'Spelers'),
    (Icons.diversity_3_rounded, 'Groepen'),
    (Icons.timer_rounded, 'Ronde'),
    (Icons.emoji_events_rounded, 'Scores'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: relay,
      builder: (context, _) {
        final isRelay = relay.mode == AppMode.relay;
        return Scaffold(
          extendBody: true,
          // Beide delen blijven actief, zodat timers doorlopen.
          body: IndexedStack(
            index: isRelay ? 1 : 0,
            children: [
              IndexedStack(index: _photoIndex, children: _photoScreens),
              IndexedStack(index: _relayIndex, children: _relayScreens),
            ],
          ),
          bottomNavigationBar: _NavBar(
            items: isRelay ? _relayItems : _photoItems,
            index: isRelay ? _relayIndex : _photoIndex,
            onTap: (i) => setState(() {
              if (isRelay) {
                _relayIndex = i;
              } else {
                _photoIndex = i;
              }
            }),
          ),
        );
      },
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar(
      {required this.items, required this.index, required this.onTap});

  final List<(IconData, String)> items;
  final int index;
  final ValueChanged<int> onTap;


  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Glass(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        radius: 26,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: i == index ? AppColors.yellowGradient : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(items[i].$1,
                            size: 22,
                            color: i == index
                                ? AppColors.black
                                : AppColors.muted),
                        const SizedBox(height: 2),
                        Text(
                          items[i].$2,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: i == index
                                ? AppColors.black
                                : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
