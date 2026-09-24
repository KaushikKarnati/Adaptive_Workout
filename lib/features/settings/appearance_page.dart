import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../application/appearance_preferences.dart';
import '../../ui/app_components.dart';
import '../../ui/app_haptics.dart';
import 'appearance_controller.dart';

class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppearanceScope.of(context);
    final haptics = AppHaptics.of(context);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Appearance & feedback')),
      body: SafeArea(
        child: AppContent(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              const AppPageHeader(
                title: 'Make it yours.',
                subtitle: 'A quieter view, in any light.',
              ),
              const AppSectionHeader(title: 'Display'),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final appearance in AppAppearance.values) ...[
                      if (appearance != AppAppearance.system)
                        const Divider(indent: 64),
                      _AppearanceOption(
                        value: appearance,
                        selected: controller.preference == appearance,
                        enabled: !controller.busy,
                        onTap: () async {
                          if (appearance == controller.preference) return;
                          await controller.select(appearance);
                          if (!context.mounted) return;
                          if (controller.error == null) {
                            haptics.selection();
                          } else {
                            haptics.error();
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'System follows your device’s Light or Dark Mode automatically. Your choice is saved on this device.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
              if (controller.busy) ...[
                const SizedBox(height: 20),
                const Center(child: CupertinoActivityIndicator()),
              ],
              if (controller.error != null) ...[
                const SizedBox(height: 20),
                Semantics(
                  liveRegion: true,
                  child: AppNotice(text: controller.error!, warning: true),
                ),
                TextButton(
                  onPressed: controller.busy ? null : controller.load,
                  child: const Text('Reload saved appearance'),
                ),
              ],
              const SizedBox(height: 28),
              const AppSectionHeader(title: 'Feedback'),
              Card(
                child: SwitchListTile(
                  enableFeedback: false,
                  key: const Key('haptic_feedback_toggle'),
                  title: const Text('Haptic feedback'),
                  subtitle: Text(
                    haptics.available
                        ? 'Subtle feedback for selections and important actions'
                        : 'Available on supported iPhones',
                  ),
                  value: haptics.enabled,
                  onChanged: haptics.busy || !haptics.available
                      ? null
                      : (value) async {
                          final saved = await haptics.setEnabled(value);
                          if (!context.mounted) return;
                          if (saved && value) haptics.selection();
                          if (!saved) haptics.error();
                        },
                ),
              ),
              if (haptics.preferenceError != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: AppNotice(
                    text: haptics.preferenceError!,
                    warning: true,
                  ),
                ),
                TextButton(
                  onPressed: haptics.busy ? null : haptics.load,
                  child: const Text('Reload haptic preference'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AppearanceOption extends StatelessWidget {
  const _AppearanceOption({
    required this.value,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });
  final AppAppearance value;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (label, subtitle, icon) = switch (value) {
      AppAppearance.system => (
        'System',
        'Match your device',
        CupertinoIcons.circle_lefthalf_fill,
      ),
      AppAppearance.light => (
        'Light',
        'Clean and bright',
        CupertinoIcons.sun_max,
      ),
      AppAppearance.dark => ('Dark', 'Soft on the eyes', CupertinoIcons.moon),
    };
    return Semantics(
      checked: selected,
      inMutuallyExclusiveGroup: true,
      child: ListTile(
        key: Key('appearance_${value.name}'),
        enabled: enabled,
        minVerticalPadding: 18,
        leading: Icon(icon, color: colors.primary),
        title: Text(label),
        subtitle: Text(subtitle),
        trailing: selected
            ? Icon(
                CupertinoIcons.check_mark,
                color: colors.primary,
                semanticLabel: 'Selected',
              )
            : null,
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
