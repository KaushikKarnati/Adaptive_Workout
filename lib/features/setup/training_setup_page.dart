import 'package:flutter/material.dart';

import '../../data/repositories/sqlite_training_setup_repository.dart';
import '../../domain/exercises/catalog/exercise_catalog_validator.dart';
import '../../domain/training/setup_variations.dart';
import '../../domain/training/training_setup.dart';
import '../../domain/workout/owner_program.dart';
import '../../ui/app_components.dart';
import '../../ui/app_haptics.dart';
import 'training_setup_controller.dart';
import '../gyms/gym_profile_page.dart';

class TrainingSetupPage extends StatefulWidget {
  const TrainingSetupPage({super.key, this.repository, this.embedded = false});
  final bool embedded;
  final TrainingSetupRepository? repository;
  @override
  State<TrainingSetupPage> createState() => _TrainingSetupPageState();
}

class _TrainingSetupPageState extends State<TrainingSetupPage> {
  TrainingSetupController? c;
  bool openFailed = false, initialized = false;
  final minutes = TextEditingController();
  final days = <int>{}, exclusions = <String>{};
  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final repo =
          widget.repository ?? await SqliteTrainingSetupRepository.open();
      if (!mounted) {
        if (widget.repository == null) await repo.close();
        return;
      }
      c = TrainingSetupController(repo)..addListener(_changed);
      setState(() {
        openFailed = false;
      });
      await c!.load();
    } catch (_) {
      if (mounted) {
        setState(() {
          openFailed = true;
        });
      }
    }
  }

  void _changed() {
    if (!mounted) return;
    if (!initialized && c!.loaded) {
      days.addAll(c!.saved?.trainingDays ?? []);
      exclusions.addAll(c!.saved?.excludedVariations ?? []);
      minutes.text = c!.saved?.preferredMinutes?.toString() ?? '';
      initialized = true;
    }
    setState(() {});
  }

  @override
  void dispose() {
    minutes.dispose();
    c?.removeListener(_changed);
    c?.dispose();
    if (widget.repository == null) c?.repository.close();
    super.dispose();
  }

  Future<void> _edit([EquipmentSetup? equipment]) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MachineDialog(controller: c!, equipment: equipment),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final content = c == null
        ? Center(
            child: openFailed
                ? TextButton(
                    onPressed: _open,
                    child: const Text('Retry opening setup'),
                  )
                : const CircularProgressIndicator(),
          )
        : ListView(
            shrinkWrap: widget.embedded,
            physics: widget.embedded
                ? const NeverScrollableScrollPhysics()
                : null,
            padding: widget.embedded
                ? EdgeInsets.zero
                : const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              if (!widget.embedded)
                const AppPageHeader(
                  title: 'Your routine',
                  subtitle: 'Save your preferences and verify equipment gradually at the gym. These records stay on this device.',
                ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AppSectionHeader(title: 'Training days'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (var day = 1; day <= 7; day++)
                            FilterChip(
                              label: Text(
                                [
                                  'Mon',
                                  'Tue',
                                  'Wed',
                                  'Thu',
                                  'Fri',
                                  'Sat',
                                  'Sun',
                                ][day - 1],
                              ),
                              selected: days.contains(day),
                              onSelected: c!.locked || !c!.loaded
                                  ? null
                                  : (on) {
                                      if (on == days.contains(day)) {
                                        return;
                                      }
                                      setState(() {
                                        on ? days.add(day) : days.remove(day);
                                      });
                                      AppHaptics.of(context).selection();
                                    },
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: minutes,
                        enabled: !c!.locked,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Preferred workout minutes',
                          helperText: 'A time preference, not a hard cutoff.',
                          helperMaxLines: 3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Exercises to exclude'),
                        children: [
                          for (final entry in setupVariationNames.entries)
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(entry.value),
                              value: exclusions.contains(entry.key),
                              onChanged: c!.locked
                                  ? null
                                  : (on) {
                                      if (on == null ||
                                          on ==
                                              exclusions.contains(entry.key)) {
                                        return;
                                      }
                                      setState(() {
                                        on
                                            ? exclusions.add(entry.key)
                                            : exclusions.remove(entry.key);
                                      });
                                      AppHaptics.of(context).selection();
                                    },
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: c!.locked || !c!.loaded
                            ? null
                            : () async {
                                final ok = await c!.savePreferences(
                                  days.toList(),
                                  minutes.text,
                                  exclusions.toList(),
                                );
                                if (!context.mounted) return;
                                if (ok) {
                                  AppHaptics.of(context).success();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Preferences saved on this device.',
                                      ),
                                    ),
                                  );
                                } else {
                                  AppHaptics.of(context).error();
                                }
                              },
                        child: const Text('Save preferences'),
                      ),
                    ],
                  ),
                ),
              ),
              if (!widget.embedded) ...[
                const SizedBox(height: 28),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: const Text('My gym'),
                    subtitle: const Text(
                      'Choose a location and confirm its equipment',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: c!.locked
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const GymProfilePage(),
                            ),
                          ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const AppSectionHeader(
                title: 'Equipment and starting loads',
                subtitle: 'Add the exact setup you use at the gym.',
              ),
              for (final equipment in c!.saved?.equipment ?? <EquipmentSetup>[])
                Card(
                  child: ListTile(
                    title: Text(equipment.label),
                    subtitle: Text(
                      '${setupVariationNames[equipment.variation]} · ${equipment.confirmed ? 'Settings confirmed by you' : 'Needs confirmation'}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: c!.locked ? null : () => _edit(equipment),
                  ),
                ),
              for (final load in c!.saved?.startingLoads ?? <StartingLoad>[])
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      '${load.sessionId} · ${setupVariationNames[load.variation]}: ${load.microPounds == null ? 'bodyweight' : '${displayPounds(load.microPounds!)} lb${load.convention == SetupLoadConvention.assistance ? ' assistance' : ''}'} · ${c!.saved!.baselineIsCurrent(load) ? 'confirmed' : 'needs reconfirmation'}',
                    ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: c!.locked || !c!.loaded ? null : () => _edit(),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add equipment / starting load'),
              ),
              const SizedBox(height: 20),
              const AppNotice(
                text: 'Exercise review is still pending. Saving setup does not enable weight recommendations. Capabilities and limitations remain unassessed until explicitly recorded.',
              ),
              if (c!.error != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: AppNotice(text: c!.error!, warning: true),
                ),
              ],
              if (c!.canRetry)
                TextButton(
                  onPressed: () async {
                    final ok = await c!.retry();
                    if (!context.mounted) return;
                    if (ok) {
                      AppHaptics.of(context).success();
                    } else {
                      AppHaptics.of(context).error();
                    }
                  },
                  child: const Text('Retry save'),
                ),
              if (!c!.loaded && !c!.busy)
                TextButton(
                  onPressed: c!.load,
                  child: const Text('Retry loading'),
                ),
              if (c!.busy) const LinearProgressIndicator(),
            ],
          );
    if (widget.embedded) return content;
    return PopScope(
      canPop: c?.locked != true,
      child: Scaffold(
        appBar: AppBar(title: const Text('Training setup')),
        body: SafeArea(child: AppContent(child: content)),
      ),
    );
  }
}

String _conventionName(SetupLoadConvention c) => switch (c) {
  SetupLoadConvention.perDumbbell => 'Pounds per dumbbell',
  SetupLoadConvention.machineSetting => 'Displayed machine pounds',
  SetupLoadConvention.platesOnly => 'Added plates only, pounds',
  SetupLoadConvention.totalExternal => 'Total external pounds',
  SetupLoadConvention.assistance => 'Machine assistance, pounds',
  SetupLoadConvention.bodyweight => 'Bodyweight (no numeric load)',
};

class _MachineDialog extends StatefulWidget {
  const _MachineDialog({required this.controller, this.equipment});
  final TrainingSetupController controller;
  final EquipmentSetup? equipment;
  @override
  State<_MachineDialog> createState() => _MachineDialogState();
}

class _MachineDialogState extends State<_MachineDialog> {
  final label = TextEditingController(),
      work = TextEditingController(),
      rehearsal = TextEditingController(),
      load = TextEditingController();
  late ProgramSession session;
  late ProgramExercise exercise;
  late String variation;
  late SetupLoadConvention convention;
  String? equipmentId;
  bool confirmed = false;
  @override
  void initState() {
    super.initState();
    final e = widget.equipment;
    session = e == null
        ? ownerProgram.first
        : ownerProgram.firstWhere(
            (s) => s.blocks
                .expand((b) => b.exercises)
                .any((x) => setupVariantsFor(x).contains(e.variation)),
          );
    exercise = session.blocks
        .expand((b) => b.exercises)
        .firstWhere(
          (x) => e == null || setupVariantsFor(x).contains(e.variation),
        );
    variation = e?.variation ?? setupVariantsFor(exercise).first;
    convention = e?.convention ?? setupConventionsFor(variation).first;
    equipmentId = e?.equipmentId;
    label.text = e?.label ?? '';
    work.text = e?.workingLoads.map(displayPounds).join(', ') ?? '';
    rehearsal.text = e?.rehearsalLoads.map(displayPounds).join(', ') ?? '';
    widget.controller.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    for (final c in [label, work, rehearsal, load]) {
      c.dispose();
    }
    super.dispose();
  }

  void _chooseExercise(ProgramExercise value) {
    exercise = value;
    variation = setupVariantsFor(value).first;
    convention = setupConventionsFor(variation).first;
    work.clear();
    rehearsal.clear();
    load.clear();
    confirmed = false;
    equipmentId = null;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller, editing = widget.equipment != null;
    return PopScope(
      canPop: !c.locked,
      child: AlertDialog(
        title: Text(editing ? 'Verify equipment again' : 'Add equipment'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                DropdownButtonFormField<ProgramSession>(
                  initialValue: session,
                  isExpanded: true,
                  itemHeight: null,
                  decoration: const InputDecoration(
                    labelText: 'Program session (original label)',
                  ),
                  items: [
                    for (final s in ownerProgram.where(
                      (s) =>
                          !editing ||
                          s.blocks
                              .expand((b) => b.exercises)
                              .any(
                                (e) => setupVariantsFor(e).contains(variation),
                              ),
                    ))
                      DropdownMenuItem(
                        value: s,
                        child: Text('${s.day}: ${s.title}'),
                      ),
                  ],
                  onChanged: c.locked
                      ? null
                      : (s) {
                          if (s == null || s == session) return;
                          setState(() {
                            session = s;
                            if (editing) {
                              exercise = s.blocks
                                  .expand((b) => b.exercises)
                                  .firstWhere(
                                    (e) =>
                                        setupVariantsFor(e).contains(variation),
                                  );
                              confirmed = false;
                              load.clear();
                            } else {
                              _chooseExercise(s.blocks.first.exercises.first);
                            }
                          });
                          AppHaptics.of(context).selection();
                        },
                ),
                DropdownButtonFormField<ProgramExercise>(
                  key: ValueKey(session.id),
                  initialValue: exercise,
                  isExpanded: true,
                  itemHeight: null,
                  decoration: const InputDecoration(labelText: 'Exercise slot'),
                  items: [
                    for (final e in session.blocks.expand((b) => b.exercises))
                      DropdownMenuItem(value: e, child: Text(e.name)),
                  ],
                  onChanged: c.locked || editing
                      ? null
                      : (e) {
                          if (e == null || e == exercise) return;
                          setState(() => _chooseExercise(e));
                          AppHaptics.of(context).selection();
                        },
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey('${session.id}/${exercise.id}'),
                  initialValue: variation,
                  isExpanded: true,
                  itemHeight: null,
                  decoration: const InputDecoration(
                    labelText: 'Exact variation',
                  ),
                  items: [
                    for (final v in setupVariantsFor(exercise))
                      DropdownMenuItem(
                        value: v,
                        child: Text(setupVariationNames[v]!),
                      ),
                  ],
                  onChanged: c.locked || editing
                      ? null
                      : (v) {
                          if (v == null || v == variation) return;
                          setState(() {
                            variation = v;
                            convention = setupConventionsFor(v).first;
                            work.clear();
                            rehearsal.clear();
                            load.clear();
                            confirmed = false;
                          });
                          AppHaptics.of(context).selection();
                        },
                ),
                TextField(
                  controller: label,
                  enabled: !c.locked,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Machine / setup label',
                    hintText: 'Enough detail to identify this exact setup',
                  ),
                ),
                DropdownButtonFormField<SetupLoadConvention>(
                  key: ValueKey(variation),
                  initialValue: convention,
                  isExpanded: true,
                  itemHeight: null,
                  decoration: const InputDecoration(
                    labelText: 'How weight is recorded',
                  ),
                  items: [
                    for (final v in setupConventionsFor(variation))
                      DropdownMenuItem(
                        value: v,
                        child: Text(_conventionName(v)),
                      ),
                  ],
                  onChanged: c.locked || editing
                      ? null
                      : (v) {
                          if (v == null || v == convention) return;
                          setState(() {
                            convention = v;
                            work.clear();
                            rehearsal.clear();
                            load.clear();
                            confirmed = false;
                          });
                          AppHaptics.of(context).selection();
                        },
                ),
                DropdownButtonFormField<String>(
                  initialValue: equipmentId ?? '',
                  isExpanded: true,
                  itemHeight: null,
                  decoration: const InputDecoration(
                    labelText: 'Equipment category',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Not mapped yet'),
                    ),
                    for (final id in ExerciseCatalogValidator.equipmentIds)
                      DropdownMenuItem(
                        value: id,
                        child: Text(id.replaceAll('_', ' ')),
                      ),
                  ],
                  onChanged: c.locked
                      ? null
                      : (v) {
                          if (v == null) return;
                          final nextId = v == '' ? null : v;
                          if (nextId == equipmentId) return;
                          setState(() {
                            equipmentId = nextId;
                            confirmed = false;
                          });
                          AppHaptics.of(context).selection();
                        },
                ),
                if (convention != SetupLoadConvention.bodyweight) ...[
                  TextField(
                    controller: work,
                    enabled: !c.locked,
                    decoration: const InputDecoration(
                      labelText: 'Checked working settings (lb)',
                      hintText: 'Separate each exact setting with a comma',
                    ),
                  ),
                  TextField(
                    controller: rehearsal,
                    enabled: !c.locked,
                    decoration: const InputDecoration(
                      labelText: 'Checked warm-up settings (lb)',
                      helperText: 'May stay blank until checked.',
                      helperMaxLines: 3,
                    ),
                  ),
                  TextField(
                    controller: load,
                    enabled: !c.locked,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: convention == SetupLoadConvention.assistance
                          ? 'Confirmed starting assistance (lb)'
                          : 'Confirmed starting weight (lb)',
                    ),
                  ),
                ],
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'I checked this exact setup, its settings and my starting load.',
                  ),
                  value: confirmed,
                  onChanged: c.locked
                      ? null
                      : (v) {
                          if (v == null || v == confirmed) return;
                          setState(() => confirmed = v);
                          AppHaptics.of(context).selection();
                        },
                ),
                const AppNotice(
                  text: 'Leave confirmation off and starting weight blank to save equipment for later verification. This does not clear safety restrictions or approve the exercise catalog.',
                ),
                if (c.error != null)
                  Semantics(
                    liveRegion: true,
                    child: AppNotice(text: c.error!, warning: true),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: c.locked ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (c.canRetry)
            TextButton(
              onPressed: () async {
                final ok = await c.retry();
                if (!context.mounted) return;
                if (ok) {
                  AppHaptics.of(context).success();
                  Navigator.pop(context);
                } else {
                  AppHaptics.of(context).error();
                }
              },
              child: const Text('Retry save'),
            ),
          FilledButton(
            onPressed: c.locked
                ? null
                : () async {
                    final ok = await c.saveMachine(
                      existingId: widget.equipment?.id,
                      label: label.text,
                      sessionId: session.id,
                      slotId: exercise.id,
                      variation: variation,
                      convention: convention,
                      workingSettings: work.text,
                      rehearsalSettings: rehearsal.text,
                      startingWeight: load.text,
                      confirmed: confirmed,
                      equipmentId: equipmentId,
                      quantity: widget.equipment?.quantity ?? 1,
                      capabilities: widget.equipment?.capabilities ?? [],
                    );
                    if (!context.mounted) return;
                    if (ok) {
                      AppHaptics.of(context).success();
                      Navigator.pop(context);
                    } else {
                      AppHaptics.of(context).error();
                    }
                  },
            child: Text(
              confirmed ? 'Save confirmed setup' : 'Save unverified setup',
            ),
          ),
        ],
      ),
    );
  }
}
