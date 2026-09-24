import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../domain/logging/program_log.dart';
import '../../ui/app_haptics.dart';
import '../program/program_logging_page.dart';
import '../settings/settings_page.dart';

/// The app's two persistent destinations. Editors remain local to each screen.
class WorkoutHomePage extends StatefulWidget {
  const WorkoutHomePage({super.key, this.workoutRepository, this.settings});

  final ProgramLogRepository? workoutRepository;
  final Widget? settings;

  @override
  State<WorkoutHomePage> createState() => _WorkoutHomePageState();
}

class _WorkoutHomePageState extends State<WorkoutHomePage> {
  int _selected = 0;
  bool _settingsVisited = false;

  void _select(int index) {
    if (_selected == index) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _selected = index;
      _settingsVisited |= index == 1;
    });
    AppHaptics.of(context).selection();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: IndexedStack(
        index: _selected,
        children: [
          TickerMode(
            enabled: _selected == 0,
            child: ProgramLoggingPage(
              repository: widget.workoutRepository,
              active: _selected == 0,
            ),
          ),
          TickerMode(
            enabled: _selected == 1,
            child: _settingsVisited
                ? widget.settings ?? const SettingsPage()
                : const SizedBox.shrink(),
          ),
        ],
      ),
      bottomNavigationBar: CupertinoTabBar(
        height: 58,
        backgroundColor: colors.surface,
        activeColor: colors.primary,
        inactiveColor: colors.onSurfaceVariant,
        border: Border(
          top: BorderSide(color: colors.outlineVariant, width: .5),
        ),
        currentIndex: _selected,
        onTap: _select,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.square_list, key: Key('tab_workout')),
            activeIcon: Icon(
              CupertinoIcons.square_list_fill,
              key: Key('tab_workout'),
            ),
            label: 'Workout',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.settings, key: Key('tab_settings')),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
