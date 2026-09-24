import 'package:flutter/material.dart';

import '../../data/repositories/sqlite_program_log_repository.dart';
import '../../domain/logging/practice_repository.dart';
import '../../domain/logging/program_log.dart';
import '../../domain/workout/owner_program.dart';
import 'program_log_controller.dart';

class ProgramLoggingPage extends StatefulWidget {
  const ProgramLoggingPage({super.key, this.repository});
  final ProgramLogRepository? repository;
  @override
  State<ProgramLoggingPage> createState() => _ProgramLoggingPageState();
}

class _ProgramLoggingPageState extends State<ProgramLoggingPage> {
  ProgramLogController? controller;
  bool openFailed = false;
  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final repo = widget.repository ?? await SqliteProgramLogRepository.open();
      if (!mounted) {
        if (widget.repository == null) await repo.close();
        return;
      }
      final c = ProgramLogController(repo);
      controller = c;
      c.addListener(_changed);
      setState(() => openFailed = false);
      await c.load();
    } catch (_) {
      if (mounted) setState(() => openFailed = true);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    final c = controller;
    if (c != null) {
      c.removeListener(_changed);
      c.dispose();
      if (widget.repository == null) c.repository.close();
    }
    super.dispose();
  }

  Future<void> _deleteWorkout(ProgramLog log) async {
    final c = controller;
    if (c == null || c.locked) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${log.plan.day} workout?'),
        content: Text(
          '${log.plan.title}\n${log.startedAt.toLocal().toString().split(".").first}\n\nDelete this workout and its ${log.sets.length} saved records, including corrections? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete workout'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || c.locked) return;
    if (await c.delete(log) && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Workout deleted')));
    }
  }

  Future<void> _chooseToday() async {
    final c = controller;
    if (c == null || c.locked) return;
    final plan = await showDialog<ProgramSession>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Choose today’s workout'),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              'Choose any workout for today. Day names are labels from your original plan.',
            ),
          ),
          for (final plan in ownerProgram)
            SimpleDialogOption(
              key: Key('choose_today_${plan.id}'),
              onPressed: () => Navigator.pop(context, plan),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('${plan.day} · ${plan.title}'),
              ),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (plan == null || !mounted || c.locked) return;
    final draft = c.draft;
    if (draft != null && draft.programId != plan.id) {
      final end = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Finish ${draft.plan.day} early?'),
          content: Text(
            'Your unfinished ${draft.plan.title} workout has ${draft.sets.length} saved records. Keep those records and finish it early before starting ${plan.title}? Unrecorded sets will stay unrecorded.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep current workout'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Finish early and continue'),
            ),
          ],
        ),
      );
      if (end != true || !mounted || c.locked) return;
      c.select(draft.id);
      if (!await c.finish(endEarly: true)) return;
      if (!mounted) return;
    }
    await c.start(plan.id);
  }

  Future<void> _edit(
    ProgramLog log,
    ProgramExercise exercise,
    int index,
    LoggedSide side, {
    bool warmup = false,
  }) async {
    final existing = log.sets
        .where(
          (s) =>
              s.slot == exercise.id &&
              s.index == index &&
              s.side == side &&
              s.warmup == warmup,
        )
        .firstOrNull;
    final result = await showDialog<ProgramSet>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SetDialog(
        log: log,
        exercise: exercise,
        index: index,
        side: side,
        warmup: warmup,
        existing: existing,
      ),
    );
    if (result != null && mounted) await controller!.record(result);
  }

  @override
  Widget build(BuildContext context) {
    final c = controller, log = c?.selected;
    final painExerciseNames = log == null
        ? const <String>[]
        : log.exercises
              .where(
                (exercise) => log.sets.any(
                  (set) =>
                      set.slot == exercise.id &&
                      set.validity == SetValidity.pain,
                ),
              )
              .map((exercise) => exercise.name)
              .toList(growable: false);
    return PopScope(
      canPop: c?.locked != true,
      child: Scaffold(
        appBar: AppBar(
          title: Text(log == null ? 'Workout log' : log.plan.day),
          actions: [
            if (log != null)
              IconButton(
                key: const Key('delete_selected_workout'),
                tooltip: 'Delete workout',
                onPressed: c!.locked ? null : () => _deleteWorkout(log),
                icon: const Icon(Icons.delete_outline),
              ),
          ],
          leading: log == null
              ? null
              : IconButton(
                  tooltip: 'Workout history',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: c!.locked ? null : () => c.select(null),
                ),
        ),
        body: SafeArea(
          child: c == null
              ? Center(
                  child: openFailed
                      ? TextButton(
                          onPressed: _open,
                          child: const Text('Could not open workouts. Retry'),
                        )
                      : const CircularProgressIndicator(),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      'Manual workout log',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'Record what you actually did. These entries do not verify a baseline or enable weight recommendations.',
                    ),
                    if (c.busy) const LinearProgressIndicator(),
                    OutlinedButton.icon(
                      key: const Key('choose_today_workout'),
                      onPressed: c.locked ? null : _chooseToday,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: const Text('Choose today’s workout'),
                    ),
                    if (c.pending != null && c.error != null)
                      for (final set in c.pending!.sets.where(
                        (s) => !c.selected!.sets.contains(s),
                      ))
                        Text(
                          'Unconfirmed entry: ${set.slot}, set ${set.index}, ${set.side.name}: ${set.skipped ? 'skipped' : '${set.reps} reps, ${set.load == null ? 'bodyweight' : '${formatPounds(set.load!)} lb'}, RIR ${set.rir ?? 'unknown'}'}',
                        ),
                    if (c.error != null) ...[
                      Text(c.error!, key: const Key('program_error')),
                      TextButton(
                        onPressed: c.busy
                            ? null
                            : () async {
                                if (c.locked) {
                                  await c.retry();
                                } else {
                                  await c.load();
                                }
                              },
                        child: const Text('Retry'),
                      ),
                    ],
                    if (log == null) ...[
                      if (c.draft != null)
                        FilledButton(
                          onPressed: c.locked
                              ? null
                              : () => c.select(c.draft!.id),
                          child: Text('Resume ${c.draft!.plan.day}'),
                        ),
                      if (c.draft == null)
                        for (final plan in ownerProgram)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: OutlinedButton(
                              onPressed: c.locked
                                  ? null
                                  : () => c.start(plan.id),
                              child: Text('Start ${plan.day}'),
                            ),
                          ),
                      const SizedBox(height: 20),
                      const Text('History'),
                      for (final saved in c.logs.where((l) => l.completed))
                        ListTile(
                          title: Text(
                            '${saved.plan.day} · ${saved.endedEarly
                                ? 'Finished early'
                                : saved.hasSkips
                                ? 'Finished with skipped sets'
                                : 'Finished'}',
                          ),
                          subtitle: Text(
                            saved.startedAt
                                .toLocal()
                                .toString()
                                .split('.')
                                .first,
                          ),
                          onTap: c.locked ? null : () => c.select(saved.id),
                          trailing: IconButton(
                            key: Key('delete_workout_${saved.id}'),
                            tooltip: 'Delete workout',
                            onPressed: c.locked
                                ? null
                                : () => _deleteWorkout(saved),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ),
                    ] else ...[
                      Text(
                        log.plan.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        log.completed
                            ? log.endedEarly
                                  ? 'Finished early · Saved records kept'
                                  : 'Saved workout · Tap a set to correct it'
                            : 'Draft · Each accepted set is saved',
                      ),
                      if (painExerciseNames.isNotEmpty)
                        Semantics(
                          liveRegion: true,
                          container: true,
                          child: Text(
                            'Pain was recorded for ${painExerciseNames.join(', ')}. Stop the affected exercise. Do not add another set, automatically substitute it, or increase its load or volume.',
                            key: const Key('program_pain_stop'),
                          ),
                        ),
                      for (final block in log.plan.blocks) ...[
                        const SizedBox(height: 16),
                        Text(
                          block.isSuperset
                              ? 'Superset · Rest ${block.restSeconds} sec after both exercises'
                              : 'Rest ${block.restSeconds} sec${block.exercises.single.eachSide ? ' after both sides' : ''}',
                        ),
                        for (final exercise in block.exercises) ...[
                          Text(
                            '${exercise.name} · ${exercise.sets} × ${exercise.minReps}–${exercise.maxReps} · 2–3 RIR',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          for (var i = 1; i <= exercise.sets; i++)
                            for (final side
                                in exercise.eachSide
                                    ? [LoggedSide.left, LoggedSide.right]
                                    : [LoggedSide.both])
                              _setTile(log, exercise, i, side),
                          for (final set in log.sets.where(
                            (s) => s.slot == exercise.id && s.warmup,
                          ))
                            _setTile(
                              log,
                              exercise,
                              set.index,
                              set.side,
                              warmup: true,
                            ),
                          if (!log.completed)
                            for (final warmupSide
                                in exercise.eachSide
                                    ? [LoggedSide.left, LoggedSide.right]
                                    : [LoggedSide.both])
                              TextButton(
                                onPressed: c.locked
                                    ? null
                                    : () {
                                        final indices = log.sets
                                            .where(
                                              (s) =>
                                                  s.slot == exercise.id &&
                                                  s.warmup &&
                                                  s.side == warmupSide,
                                            )
                                            .map((s) => s.index);
                                        final next = indices.isEmpty
                                            ? 1
                                            : indices.reduce(
                                                    (a, b) => a > b ? a : b,
                                                  ) +
                                                  1;
                                        _edit(
                                          log,
                                          exercise,
                                          next,
                                          warmupSide,
                                          warmup: true,
                                        );
                                      },
                                child: Text(
                                  'Record a warm-up set${exercise.eachSide ? ' · ${warmupSide.name}' : ''}',
                                ),
                              ),
                        ],
                      ],
                      if (!log.completed)
                        FilledButton(
                          onPressed: c.locked ? null : () => c.finish(),
                          child: const Text('Finish workout'),
                        ),
                      if (!log.completed)
                        TextButton(
                          onPressed: c.locked ? null : () => c.select(null),
                          child: const Text('Leave saved as draft'),
                        ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _setTile(
    ProgramLog log,
    ProgramExercise e,
    int index,
    LoggedSide side, {
    bool warmup = false,
  }) {
    final s = log.sets
        .where(
          (s) =>
              s.slot == e.id &&
              s.index == index &&
              s.side == side &&
              s.warmup == warmup,
        )
        .firstOrNull;
    return ListTile(
      key: Key('${e.id}_${warmup}_${index}_${side.name}'),
      title: Text(
        '${warmup ? 'Warm-up' : 'Set'} $index${side == LoggedSide.both ? '' : ' · ${side.name}'}',
      ),
      subtitle: Text(
        s == null
            ? 'Not recorded'
            : s.skipped
            ? 'Skipped'
            : '${s.load == null ? 'Bodyweight' : '${formatPounds(s.load!)} lb (${s.convention.name})'} · ${s.reps} reps · RIR ${s.rir ?? 'unknown'} · ${s.validity.name}',
      ),
      trailing: Icon(
        s == null ? Icons.edit_outlined : Icons.check_circle_outline,
      ),
      onTap: controller!.locked || (log.completed && s == null)
          ? null
          : () => _edit(log, e, index, side, warmup: warmup),
    );
  }
}

class _SetDialog extends StatefulWidget {
  const _SetDialog({
    required this.log,
    required this.exercise,
    required this.index,
    required this.side,
    required this.warmup,
    this.existing,
  });
  final ProgramLog log;
  final ProgramExercise exercise;
  final int index;
  final LoggedSide side;
  final bool warmup;
  final ProgramSet? existing;
  @override
  State<_SetDialog> createState() => _SetDialogState();
}

class _SetDialogState extends State<_SetDialog> {
  final setup = TextEditingController(),
      load = TextEditingController(),
      reps = TextEditingController(),
      rir = TextEditingController();
  String? variant, error;
  LoadConvention? convention;
  SetValidity validity = SetValidity.unknown;
  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    variant =
        s?.variant ??
        (widget.exercise.alternatives.isEmpty ? widget.exercise.id : null);
    setup.text = s?.setup ?? '';
    load.text = s?.load == null ? '' : formatPounds(s!.load!);
    reps.text = s?.reps?.toString() ?? '';
    rir.text = s?.rir?.toString() ?? '';
    convention = s?.convention;
    validity = s?.validity ?? SetValidity.unknown;
  }

  @override
  void dispose() {
    setup.dispose();
    load.dispose();
    reps.dispose();
    rir.dispose();
    super.dispose();
  }

  void _submit(bool skip) {
    try {
      if (widget.exercise.alternatives.isNotEmpty &&
          !widget.exercise.alternatives.contains(variant)) {
        throw const LoggingException('variation_required');
      }
      if (setup.text.trim().isEmpty || convention == null) {
        throw const LoggingException('setup_required');
      }
      final s = ProgramSet(
        slot: widget.exercise.id,
        index: widget.index,
        side: widget.side,
        variant: variant ?? '',
        setup: setup.text.trim(),
        convention: convention ?? LoadConvention.bodyweight,
        load: skip || convention == LoadConvention.bodyweight
            ? null
            : parsePounds(load.text),
        reps: skip ? null : int.parse(reps.text),
        rir: skip || rir.text.trim().isEmpty ? null : int.parse(rir.text),
        validity: skip ? SetValidity.unknown : validity,
        warmup: widget.warmup,
        skipped: skip,
      );
      widget.log.validateSet(s);
      Navigator.of(context).pop(s);
    } catch (_) {
      setState(
        () => error = 'Check the variation, setup, load convention and numbers. RIR may be blank.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('${widget.exercise.name} · ${widget.index}'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.exercise.alternatives.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: variant,
              isExpanded: true,
              itemHeight: null,
              decoration: const InputDecoration(labelText: 'Variation'),
              items: [
                for (final v in widget.exercise.alternatives)
                  DropdownMenuItem(
                    value: v,
                    child: Text(v.replaceAll('_', ' ')),
                  ),
              ],
              onChanged: (v) => setState(() => variant = v),
            ),
          TextField(
            controller: setup,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Exact machine / setup',
              helperText: 'Use a label you can recognize next time.',
            ),
          ),
          DropdownButtonFormField<LoadConvention>(
            initialValue: convention,
            isExpanded: true,
            itemHeight: null,
            decoration: const InputDecoration(
              labelText: 'How this load is measured',
            ),
            items: [
              for (final v in LoadConvention.values)
                DropdownMenuItem(
                  value: v,
                  child: Text(switch (v) {
                    LoadConvention.perDumbbell => 'Pounds per dumbbell',
                    LoadConvention.machineSetting =>
                      'Displayed machine setting (lb)',
                    LoadConvention.platesOnly => 'Added plates only (lb)',
                    LoadConvention.totalLoad => 'Total load (lb)',
                    LoadConvention.assistance => 'Assistance (lb)',
                    LoadConvention.bodyweight => 'Bodyweight, no added load',
                  }),
                ),
            ],
            onChanged: (v) => setState(() => convention = v),
          ),
          if (convention != LoadConvention.bodyweight)
            TextField(
              controller: load,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Actual load (lb)'),
            ),
          TextField(
            controller: reps,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Actual reps'),
          ),
          TextField(
            controller: rir,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Reps in reserve (optional)',
            ),
          ),
          DropdownButtonFormField<SetValidity>(
            initialValue: validity,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Set quality'),
            items: [
              for (final v in SetValidity.values)
                DropdownMenuItem(value: v, child: Text(v.name)),
            ],
            onChanged: (v) => setState(() => validity = v!),
          ),
          if (error != null) Text(error!),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      TextButton(onPressed: () => _submit(true), child: const Text('Skip set')),
      FilledButton(
        onPressed: () => _submit(false),
        child: const Text('Save set'),
      ),
    ],
  );
}
