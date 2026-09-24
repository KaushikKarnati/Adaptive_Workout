import 'package:flutter/material.dart';

import '../program/program_page.dart';

import '../../data/repositories/sqlite_practice_repository.dart';
import '../../domain/logging/practice_repository.dart';
import '../../ui/app_components.dart';
import 'practice_controller.dart';

class PracticeBootstrap extends StatefulWidget {
  const PracticeBootstrap({super.key});
  @override
  State<PracticeBootstrap> createState() => _PracticeBootstrapState();
}

class _PracticeBootstrapState extends State<PracticeBootstrap> {
  PracticeRepository? _repository;
  String? _error;
  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    setState(() => _error = null);
    try {
      final repository = await SqlitePracticeRepository.open();
      if (!mounted) {
        await repository.close();
        return;
      }
      setState(() => _repository = repository);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Saved workouts could not be opened. No data was cleared.',
        );
      }
    }
  }

  @override
  void dispose() {
    _repository?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = _repository;
    if (repo != null) return PracticePage(repository: repo);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _open,
                        child: const Text('Retry opening'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class PracticePage extends StatefulWidget {
  const PracticePage({super.key, required this.repository});
  final PracticeRepository repository;
  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  late final PracticeController controller;
  final load = TextEditingController(),
      reps = TextEditingController(),
      rir = TextEditingController();
  String exercise = 'practice_press';
  bool working = true;
  SetValidity validity = SetValidity.unknown;
  PracticeSet? editing;
  String? inputError;

  @override
  void initState() {
    super.initState();
    controller = PracticeController(widget.repository)..addListener(_changed);
    controller.load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(_changed);
    controller.dispose();
    load.dispose();
    reps.dispose();
    rir.dispose();
    super.dispose();
  }

  void _clear() {
    editing = null;
    inputError = null;
    load.clear();
    reps.clear();
    rir.clear();
    validity = SetValidity.unknown;
  }

  void _edit(PracticeSet record) {
    setState(() {
      editing = record;
      exercise = record.exerciseId;
      working = record.working;
      validity = record.validity;
      load.text = record.microPounds == null
          ? ''
          : formatPounds(record.microPounds!);
      reps.text = record.reps?.toString() ?? '';
      rir.text = record.rir?.toString() ?? '';
      inputError = null;
    });
  }

  Future<void> _save({bool skipped = false}) async {
    final session = controller.selected;
    if (session == null || controller.controlsLocked) return;
    try {
      final index =
          editing?.index ??
          (session.sets
                  .where((s) => s.exerciseId == exercise)
                  .fold<int>(0, (m, s) => s.index > m ? s.index : m) +
              1);
      int parseCount(String value) {
        if (!RegExp(r'^\d{1,5}$').hasMatch(value.trim())) {
          throw const LoggingException('invalid_number');
        }
        return int.parse(value.trim());
      }

      final record = PracticeSet(
        id: editing?.id ?? '${exercise}_$index',
        exerciseId: exercise,
        index: index,
        microPounds: skipped ? null : parsePounds(load.text),
        reps: skipped ? null : parseCount(reps.text),
        rir: skipped || rir.text.trim().isEmpty ? null : parseCount(rir.text),
        working: working,
        validity: skipped ? SetValidity.unknown : validity,
        skipped: skipped,
      );
      record.validate();
      if (await controller.save(record, correction: editing != null) &&
          mounted) {
        setState(_clear);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => inputError = 'Enter a nonnegative weight and whole-number reps/RIR. RIR may be blank.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = controller.selected;
    final locked = controller.controlsLocked;
    final hasPain =
        session?.sets.any((s) => s.validity == SetValidity.pain) ?? false;
    final selectedExerciseHasPain =
        session?.sets.any(
          (s) => s.exerciseId == exercise && s.validity == SetValidity.pain,
        ) ??
        false;
    return PopScope(
      canPop: session == null && !locked,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !locked) {
          _clear();
          controller.select(null);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              tooltip: 'Your program',
              icon: const Icon(Icons.calendar_view_week),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ProgramPage()),
              ),
            ),
          ],
          title: Text(
            session == null
                ? 'Workout practice'
                : session.completed
                ? 'Saved practice workout'
                : 'Practice session',
          ),
          leading: session == null
              ? null
              : IconButton(
                  key: const Key('practice_back'),
                  tooltip: 'History',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: locked
                      ? null
                      : () {
                          _clear();
                          controller.select(null);
                        },
                ),
        ),
        body: SafeArea(
          child: AppContent(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              children: [
                AppPageHeader(
                  title: session == null
                      ? 'Practice logging'
                      : session.completed
                      ? 'Saved practice'
                      : 'Record your sets',
                  eyebrow: 'Practice only · Saved on this device',
                  subtitle: 'Test logging and recovery here. These entries never change training recommendations. No workout weights are prescribed.',
                ),
                if (controller.busy) const LinearProgressIndicator(),
                if (controller.error != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: AppNotice(
                      key: const Key('save_error'),
                      text: controller.error!,
                      warning: true,
                    ),
                  ),
                  FilledButton(
                    onPressed: controller.busy
                        ? null
                        : () async {
                            if (controller.retryRequired) {
                              if (await controller.retry() && mounted) {
                                setState(_clear);
                              }
                            } else {
                              await controller.load();
                            }
                          },
                    child: const Text('Retry'),
                  ),
                ],
                if (session == null) ...[
                  FilledButton(
                    key: const Key('start_practice'),
                    onPressed: locked || controller.error != null
                        ? null
                        : () async {
                            _clear();
                            await controller.start();
                          },
                    child: Text(
                      controller.draft == null
                          ? 'Start practice session'
                          : 'Resume saved session',
                    ),
                  ),
                  const SizedBox(height: 24),
                  const AppSectionHeader(title: 'Saved history'),
                  if (controller.sessions.isEmpty && !controller.busy)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.history, size: 28),
                            SizedBox(height: 12),
                            Text('No saved sessions yet.'),
                            SizedBox(height: 4),
                            Text('Your practice records will appear here.'),
                          ],
                        ),
                      ),
                    ),
                  for (final item in controller.sessions)
                    Card(
                      child: ListTile(
                        title: Text(
                          item.completed
                              ? 'Completed practice'
                              : 'Unfinished practice',
                        ),
                        subtitle: Text(
                          '${MaterialLocalizations.of(context).formatMediumDate(item.startedAt.toLocal())} · ${item.sets.length} records',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: locked
                            ? null
                            : () {
                                _clear();
                                controller.select(item.id);
                              },
                      ),
                    ),
                ] else ...[
                  Text(
                    '${session.sets.length} saved records',
                    key: const Key('saved_count'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  if (session.completed) ...[
                    const AppNotice(
                      key: Key('completion_saved'),
                      text: 'Completion saved',
                      icon: Icons.check_circle_outline,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (hasPain) ...[
                    const AppNotice(
                      text: 'Pain was reported. Stop the affected exercise. No replacement or increase is suggested.',
                      warning: true,
                    ),
                    const SizedBox(height: 16),
                  ],
                  for (final record in session.sets)
                    Card(
                      child: ListTile(
                        title: Text(
                          '${practiceExercises[record.exerciseId]} · Set ${record.index}',
                        ),
                        subtitle: Text(
                          record.skipped
                              ? 'Skipped'
                              : '${formatPounds(record.microPounds!)} lb × ${record.reps} · ${record.rir == null ? 'RIR unknown' : '${record.rir} RIR'}\n${record.working ? 'Working' : 'Warm-up'} · ${record.validity.name}',
                        ),
                        trailing: TextButton(
                          key: Key('edit_${record.id}'),
                          onPressed: locked ? null : () => _edit(record),
                          child: const Text('Edit'),
                        ),
                      ),
                    ),
                  if (!session.completed || editing != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 16,
                          children: [
                            AppSectionHeader(
                              title: editing == null
                                  ? 'Record a practice set'
                                  : 'Correct saved set',
                            ),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              itemHeight: null,
                              initialValue: exercise,
                              key: ValueKey('exercise_$exercise'),
                              decoration: const InputDecoration(
                                labelText: 'Practice movement',
                              ),
                              items: [
                                for (final entry in practiceExercises.entries)
                                  DropdownMenuItem(
                                    value: entry.key,
                                    child: Text(entry.value),
                                  ),
                              ],
                              onChanged: locked || editing != null
                                  ? null
                                  : (value) =>
                                        setState(() => exercise = value!),
                            ),
                            TextField(
                              key: const Key('practice_load'),
                              controller: load,
                              enabled: !locked,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Weight (lb)',
                                helperText:
                                    'Use the same equipment setting each time.',
                                helperMaxLines: 3,
                              ),
                            ),
                            TextField(
                              key: const Key('practice_reps'),
                              controller: reps,
                              enabled: !locked,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Completed reps',
                              ),
                            ),
                            TextField(
                              key: const Key('practice_rir'),
                              controller: rir,
                              enabled: !locked,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Reps in reserve (optional)',
                              ),
                            ),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Working set'),
                              subtitle: const Text(
                                'Turn off for a warm-up set',
                              ),
                              value: working,
                              onChanged: locked
                                  ? null
                                  : (value) => setState(() => working = value),
                            ),
                            DropdownButtonFormField<SetValidity>(
                              isExpanded: true,
                              itemHeight: null,
                              initialValue: validity,
                              key: ValueKey('validity_${validity.name}'),
                              decoration: const InputDecoration(
                                labelText: 'Set quality',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: SetValidity.unknown,
                                  child: Text('Not assessed'),
                                ),
                                DropdownMenuItem(
                                  value: SetValidity.valid,
                                  child: Text('Good form, unassisted'),
                                ),
                                DropdownMenuItem(
                                  value: SetValidity.invalid,
                                  child: Text('Technique or assistance issue'),
                                ),
                                DropdownMenuItem(
                                  value: SetValidity.pain,
                                  child: Text('Pain affected'),
                                ),
                              ],
                              onChanged: locked
                                  ? null
                                  : (value) =>
                                        setState(() => validity = value!),
                            ),
                            if (inputError != null)
                              Semantics(
                                liveRegion: true,
                                child: AppNotice(
                                  key: const Key('input_error'),
                                  text: inputError!,
                                  warning: true,
                                ),
                              ),
                            const SizedBox(height: 16),
                            FilledButton(
                              key: const Key('save_practice_set'),
                              onPressed:
                                  locked ||
                                      (selectedExerciseHasPain &&
                                          editing == null)
                                  ? null
                                  : () => _save(),
                              child: Text(
                                editing == null
                                    ? 'Save set'
                                    : 'Save correction',
                              ),
                            ),
                            TextButton(
                              onPressed: locked
                                  ? null
                                  : () => _save(skipped: true),
                              child: const Text('Record as skipped'),
                            ),
                            if (editing != null)
                              TextButton(
                                onPressed: locked
                                    ? null
                                    : () => setState(_clear),
                                child: const Text('Cancel correction'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (!session.completed) ...[
                    const SizedBox(height: 16),
                    OutlinedButton(
                      key: const Key('complete_practice'),
                      onPressed: locked || editing != null
                          ? null
                          : () async {
                              if (await controller.complete() && mounted) {
                                setState(_clear);
                              }
                            },
                      child: const Text('Complete practice session'),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
