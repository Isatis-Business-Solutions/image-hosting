import 'package:flutter/material.dart';

import '../relay/relay_store.dart';
import '../screens/settings_screen.dart';
import '../store.dart';
import '../theme.dart';

/// Basisopbouw van een tabblad: titel, instellingen-knop en een lijst die
/// automatisch ververst als de gegevens veranderen.
class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    this.subtitle,
    required this.builder,
    this.actions = const [],
    this.floating,
    this.controller,
  });

  final ScrollController? controller;

  final String title;
  final String Function()? subtitle;
  final List<Widget> Function(BuildContext context) builder;
  final List<Widget> actions;
  final Widget? floating;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: floating == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 84), child: floating),
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([store, relay]),
          builder: (context, _) => CustomScrollView(
            controller: controller,
            slivers: [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: ModeSwitch(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShaderMask(
                              shaderCallback: (r) =>
                                  const LinearGradient(colors: [
                                AppColors.text,
                                AppColors.yellow,
                              ]).createShader(r),
                              child: Text(title,
                                  style: const TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white)),
                            ),
                            if (subtitle != null)
                              Text(subtitle!(),
                                  style:
                                      const TextStyle(color: AppColors.muted)),
                          ],
                        ),
                      ),
                      ...actions,
                      IconButton(
                        tooltip: 'Instellingen',
                        icon: const Icon(Icons.tune_rounded,
                            color: AppColors.muted),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const SettingsScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                sliver: SliverList.list(children: builder(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Schakelaar tussen deel 1 (fotospel) en deel 2 (estafette).
class ModeSwitch extends StatelessWidget {
  const ModeSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(AppMode m, IconData icon, String label) {
      final sel = relay.mode == m;
      return Expanded(
        child: GestureDetector(
          onTap: () => relay.setMode(m),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: sel ? AppColors.yellowGradient : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 18,
                    color: sel ? AppColors.black : AppColors.muted),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: sel ? AppColors.black : AppColors.muted)),
              ],
            ),
          ),
        ),
      );
    }

    return Glass(
      padding: const EdgeInsets.all(4),
      radius: 18,
      child: Row(
        children: [
          item(AppMode.photo, Icons.photo_camera_rounded, 'Fotospel'),
          item(AppMode.relay, Icons.directions_run_rounded, 'Estafette'),
        ],
      ),
    );
  }
}
