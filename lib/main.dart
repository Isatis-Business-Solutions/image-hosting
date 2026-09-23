import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  // Loopt er nog een potje, dan meteen daarheen.
  late int _index = store.current != null ? 3 : 0;

  static const _screens = [
    PlayersScreen(),
    TeamsScreen(),
    PhotosScreen(),
    MatchScreen(),
    ScoreboardScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: _NavBar(
        index: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.person_rounded, 'Spelers'),
    (Icons.groups_rounded, 'Teams'),
    (Icons.photo_library_rounded, "Foto's"),
    (Icons.sports_esports_rounded, 'Potje'),
    (Icons.emoji_events_rounded, 'Scores'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Glass(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        radius: 26,
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
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
                        Icon(_items[i].$1,
                            size: 22,
                            color: i == index
                                ? AppColors.black
                                : AppColors.muted),
                        const SizedBox(height: 2),
                        Text(
                          _items[i].$2,
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
