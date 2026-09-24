import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../domain/gyms/gym_profile.dart';
import '../../domain/training/training_setup.dart';
import '../../ui/app_components.dart';
import '../gyms/gym_profile_page.dart';
import '../program/program_page.dart';
import '../setup/training_setup_page.dart';
import 'appearance_page.dart';

/// The settings destination keeps its sections inline and retains unfinished
/// edits after a disclosure closes or the parent switches to the workout tab.
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    this.trainingSetupRepository,
    this.gymRepository,
  });

  final TrainingSetupRepository? trainingSetupRepository;
  final GymProfileRepository? gymRepository;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: SafeArea(
      child: AppContent(
        child: SingleChildScrollView(
          key: const Key('settings_scroll'),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppPageHeader(
                title: 'Make it yours.',
                subtitle: 'Your preferences and training, in one place.',
              ),
              _SettingsSection(
                key: const Key('settings_appearance'),
                icon: CupertinoIcons.circle_lefthalf_fill,
                title: 'Appearance & feedback',
                subtitle: 'Display and haptics',
                builder: (_) => const AppearancePage(embedded: true),
              ),
              _SettingsSection(
                key: const Key('settings_program'),
                icon: CupertinoIcons.rectangle_stack,
                title: 'Your program',
                subtitle: 'Your five-day plan',
                builder: (_) => const ProgramPage(embedded: true),
              ),
              _SettingsSection(
                key: const Key('settings_setup'),
                icon: CupertinoIcons.slider_horizontal_3,
                title: 'Training setup',
                subtitle: 'Schedule, equipment and starting loads',
                builder: (_) => TrainingSetupPage(
                  repository: trainingSetupRepository,
                  embedded: true,
                ),
              ),
              _SettingsSection(
                key: const Key('settings_gym'),
                icon: CupertinoIcons.location,
                title: 'My gym',
                subtitle: 'Location and equipment availability',
                builder: (_) =>
                    GymProfilePage(repository: gymRepository, embedded: true),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SettingsSection extends StatefulWidget {
  const _SettingsSection({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.builder,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final WidgetBuilder builder;

  @override
  State<_SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<_SettingsSection> {
  bool opened = false;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      maintainState: true,
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      shape: const Border(),
      collapsedShape: const Border(),
      leading: Icon(widget.icon, color: Theme.of(context).colorScheme.primary),
      title: Text(widget.title),
      subtitle: Text(widget.subtitle),
      onExpansionChanged: (expanded) {
        if (expanded && !opened) setState(() => opened = true);
        if (!expanded) FocusManager.instance.primaryFocus?.unfocus();
      },
      children: [if (opened) widget.builder(context)],
    ),
  );
}
