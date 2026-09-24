import 'package:flutter/material.dart';

import '../../data/repositories/sqlite_gym_profile_repository.dart';
import '../../domain/exercises/catalog/exercise_catalog_validator.dart';
import '../../domain/gyms/gym_profile.dart';
import '../../ui/app_components.dart';
import 'gym_profile_controller.dart';

String equipmentLabel(String id) =>
    id.split('_').map((w) => w == 'ez' ? 'EZ' : w).join(' ');
String availabilityLabel(EquipmentAvailability value) => switch (value) {
  EquipmentAvailability.unknown => 'Not checked',
  EquipmentAvailability.available => 'Available',
  EquipmentAvailability.unavailable => 'Unavailable',
};

class GymProfilePage extends StatefulWidget {
  const GymProfilePage({super.key, this.repository});
  final GymProfileRepository? repository;
  @override
  State<GymProfilePage> createState() => _GymProfilePageState();
}

class _GymProfilePageState extends State<GymProfilePage> {
  late final c = GymProfileController(
    widget.repository ?? SqliteGymProfileRepository(),
  );
  @override
  void initState() {
    super.initState();
    c.load();
  }

  @override
  void dispose() {
    c.dispose();
    if (widget.repository == null) c.repository.close();
    super.dispose();
  }

  Future<void> _addGym() async {
    final name = TextEditingController(), address = TextEditingController();
    String? error;
    final gym = await showDialog<GymProfile>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Add another gym'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Gym name'),
                ),
                TextField(
                  controller: address,
                  maxLength: 240,
                  decoration: const InputDecoration(
                    labelText: 'Address (optional)',
                  ),
                ),
                if (error != null) Text(error!),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                try {
                  final gym = GymProfile(
                    id: 'local_${DateTime.now().microsecondsSinceEpoch}',
                    name: name.text.trim(),
                    address: address.text.trim(),
                    equipment: [],
                  );
                  Navigator.pop(context, gym);
                } catch (_) {
                  setLocal(() => error = 'Enter a gym name using plain text.');
                }
              },
              child: const Text('Add gym'),
            ),
          ],
        ),
      ),
    );
    // Wait for route animation before disposing controllers used by the dialog.
    if (gym != null) await c.select(gym);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    name.dispose();
    address.dispose();
  }

  Future<void> _edit(String category) async {
    final existing = c.saved!.selected!.equipment
        .where((e) => e.category == category)
        .firstOrNull;
    var status = existing?.availability ?? EquipmentAvailability.unknown;
    final notes = TextEditingController(text: existing?.notes ?? '');
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(equipmentLabel(category)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Confirm what you checked at this location. Available does not confirm a starting weight.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<EquipmentAvailability>(
                  initialValue: status,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Equipment status',
                  ),
                  items: [
                    for (final s in EquipmentAvailability.values)
                      DropdownMenuItem(
                        value: s,
                        child: Text(availabilityLabel(s)),
                      ),
                  ],
                  onChanged: (s) {
                    if (s != null) setLocal(() => status = s);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notes,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Machine / attachments / settings notes',
                    helperText: 'Optional. Exact starting loads are verified separately.',
                    helperMaxLines: 3,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save equipment'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true) await c.setEquipment(category, status, notes.text);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    notes.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final gym = c.saved?.selected;
      return PopScope(
        canPop: !c.busy && !c.canRetry,
        child: Scaffold(
          appBar: AppBar(title: const Text('My gym')),
          body: SafeArea(
            child: AppContent(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const AppPageHeader(
                    title: 'Equipment at your gym',
                    subtitle: 'Choose a location to load its saved equipment. Your confirmations stay on this device and work offline.',
                  ),
                  if (c.error != null) ...[
                    AppNotice(text: c.error!, warning: true),
                    if (c.canRetry)
                      TextButton(
                        onPressed: c.retry,
                        child: const Text('Retry save'),
                      ),
                    TextButton(
                      onPressed: c.busy ? null : c.discardPendingAndReload,
                      child: const Text('Reload saved gyms'),
                    ),
                  ],
                  if (c.busy) const LinearProgressIndicator(),
                  if (c.saved != null) ...[
                    DropdownButtonFormField<String>(
                      key: ValueKey(c.saved!.selectedId),
                      initialValue: c.saved!.selectedId,
                      isExpanded: true,
                      itemHeight: null,
                      decoration: const InputDecoration(
                        labelText: 'Selected gym',
                      ),
                      hint: const Text('Choose a gym'),
                      items: [
                        for (final p in [
                          if (!c.saved!.profiles.any(
                            (p) => p.id == homewoodGymId,
                          ))
                            homewoodProfile(),
                          ...c.saved!.profiles,
                        ])
                          DropdownMenuItem(value: p.id, child: Text(p.name)),
                      ],
                      onChanged: c.locked
                          ? null
                          : (id) {
                              if (id == null || id == c.saved!.selectedId) {
                                return;
                              }
                              c.select(
                                c.saved!.profiles
                                        .where((p) => p.id == id)
                                        .firstOrNull ??
                                    homewoodProfile(),
                              );
                            },
                    ),
                    TextButton.icon(
                      onPressed: c.locked ? null : _addGym,
                      icon: const Icon(Icons.add),
                      label: const Text('Add another gym'),
                    ),
                    if (gym != null) ...[
                      if (gym.address.isNotEmpty) Text(gym.address),
                      if (gym.id == homewoodGymId)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: AppNotice(
                            text: 'Homewood’s public page lists amenities, not individual machines. This is a general checklist, not a verified inventory. Confirm each item you find.',
                          ),
                        ),
                      if (gym.id == homewoodGymId)
                        const ExpansionTile(
                          title: Text('Location source'),
                          children: [
                            Padding(
                              padding: EdgeInsets.all(12),
                              child: SelectableText(
                                'CLUB4 official location page · reviewed September 24, 2026\n$homewoodSource\nUsed for name and address only.',
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      Text(
                        '${gym.availableCategories.length} equipment categories confirmed available',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Text(
                        'Tap an item to confirm availability or record a correction. Unchecked items are not assumed available.',
                      ),
                      const SizedBox(height: 12),
                      for (final category
                          in ExerciseCatalogValidator.equipmentIds)
                        Builder(
                          builder: (context) {
                            final item = gym.equipment
                                .where((e) => e.category == category)
                                .firstOrNull;
                            final status =
                                item?.availability ??
                                EquipmentAvailability.unknown;
                            return Card(
                              child: ListTile(
                                title: Text(equipmentLabel(category)),
                                subtitle: Text(
                                  '${availabilityLabel(status)}${item?.checkedAt == null ? '' : ' · checked ${item!.checkedAt!.toLocal().toIso8601String().substring(0, 10)}'}${item?.notes.isNotEmpty == true ? '\n${item!.notes}' : ''}',
                                ),
                                leading: Icon(switch (status) {
                                  EquipmentAvailability.available =>
                                    Icons.check_circle_outline,
                                  EquipmentAvailability.unavailable =>
                                    Icons.block,
                                  EquipmentAvailability.unknown =>
                                    Icons.help_outline,
                                }),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: c.locked ? null : () => _edit(category),
                              ),
                            );
                          },
                        ),
                      const AppNotice(
                        text: 'Availability records do not set weights or approve exercises. Use Equipment and starting loads in Training setup to verify your exact setup.',
                      ),
                      TextButton(
                        onPressed: c.locked ? null : c.clearSelection,
                        child: const Text('Clear selected gym'),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
