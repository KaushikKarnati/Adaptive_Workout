import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../ui/app_components.dart';
import '../program/program_logging_page.dart';
import '../program/program_page.dart';
import '../settings/appearance_page.dart';
import '../setup/training_setup_page.dart';

class WorkoutHomePage extends StatelessWidget {
  const WorkoutHomePage({super.key});

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Adaptive Workout'),
        actions: [
          IconButton(
            key: const Key('home_appearance'),
            tooltip: 'Appearance and feedback',
            onPressed: () => _open(context, const AppearancePage()),
            icon: const Icon(CupertinoIcons.circle_lefthalf_fill),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: AppContent(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              const AppPageHeader(
                title: 'Training',
                subtitle: 'Your program. Your pace.',
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        CupertinoIcons.square_list,
                        size: 30,
                        color: colors.primary,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Choose your workout',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Open your log to choose a session, continue a draft, or review your history.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        key: const Key('home_workout_log'),
                        onPressed: () =>
                            _open(context, const ProgramLoggingPage()),
                        child: const Text('Open workout log'),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Manual logging · Saved on this device',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const AppSectionHeader(title: 'Your foundation'),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _DestinationRow(
                      key: const Key('home_program'),
                      icon: CupertinoIcons.rectangle_stack,
                      title: 'Your program',
                      subtitle: 'Five sessions, with sets and rest guidance',
                      onTap: () => _open(context, const ProgramPage()),
                    ),
                    const Divider(height: 1, indent: 64, endIndent: 20),
                    _DestinationRow(
                      key: const Key('home_training_setup'),
                      icon: CupertinoIcons.slider_horizontal_3,
                      title: 'Training setup',
                      subtitle: 'Schedule, equipment and starting loads',
                      onTap: () => _open(context, const TrainingSetupPage()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const AppNotice(
                text: 'Weight recommendations still require verified equipment, starting loads and resolved warm-up setups.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DestinationRow extends StatelessWidget {
  const _DestinationRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 24, color: colors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
