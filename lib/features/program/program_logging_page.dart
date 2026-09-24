import 'package:flutter/material.dart';

import '../../data/repositories/sqlite_program_log_repository.dart';
import '../../domain/logging/practice_repository.dart';
import '../../domain/logging/program_log.dart';
import '../../domain/workout/owner_program.dart';
import '../../ui/app_components.dart';
import '../../ui/app_haptics.dart';
import 'program_log_controller.dart';
import 'session_timer.dart';

class ProgramLoggingPage extends StatefulWidget {
  const ProgramLoggingPage({super.key, this.repository});
  final ProgramLogRepository? repository;
  @override
  State<ProgramLoggingPage> createState() => _ProgramLoggingPageState();
}

class _ProgramLoggingPageState extends State<ProgramLoggingPage> {
  ProgramLogController? controller;
  bool openFailed = false;
  final rest = RestCountdown();
  String? timedSessionId;
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
    final selected = controller?.selected;
    if (selected?.id != timedSessionId || selected?.completed == true) {
      timedSessionId = selected?.id;
      rest.clear();
    }
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
    rest.dispose();
    super.dispose();
  }

  Future<void> _deleteWorkout(ProgramLog log) async {
    final c = controller;
    if (c == null || c.locked) return;
    AppHaptics.of(context).warning();
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
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete workout'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || c.locked) return;
    final deleted = await c.delete(log);
    if (!mounted) return;
    if (deleted) {
      AppHaptics.of(context).success();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Workout deleted')));
    } else {
      AppHaptics.of(context).error();
    }
  }

  Future<void> _start(String programId) async {
    final c = controller;
    if (c == null || c.locked) return;
    final resuming = c.draft != null;
    final started = await c.start(programId);
    if (!mounted) return;
    if (!started) {
      AppHaptics.of(context).error();
    } else if (!resuming) {
      AppHaptics.of(context).impact();
    }
  }

  Future<void> _finish() async {
    final c = controller;
    if (c == null || c.locked) return;
    final finished = await c.finish();
    if (!mounted) return;
    if (finished) {
      AppHaptics.of(context).success();
    } else {
      AppHaptics.of(context).error();
    }
  }

  Future<void> _retry() async {
    final c = controller;
    if (c == null || c.busy) return;
    if (!c.locked) {
      await c.load();
      return;
    }
    final starting = c.pending?.revision == 0;
    final saved = await c.retry();
    if (!mounted) return;
    if (!saved) {
      AppHaptics.of(context).error();
    } else if (starting) {
      AppHaptics.of(context).impact();
    } else {
      AppHaptics.of(context).success();
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
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('${plan.day} · ${plan.title}'),
              ),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Cancel'),
            ),
          ),
        ],
      ),
    );
    if (plan == null || !mounted || c.locked) return;
    final draft = c.draft;
    if (draft != null && draft.programId != plan.id) {
      AppHaptics.of(context).warning();
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
      final finished = await c.finish(endEarly: true);
      if (!mounted) return;
      if (!finished) {
        AppHaptics.of(context).error();
        return;
      }
    }
    await _start(plan.id);
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
    if (result == null || !mounted) return;
    final saved = await controller!.record(result);
    if (!mounted) return;
    if (saved) {
      AppHaptics.of(context).success();
    } else {
      AppHaptics.of(context).error();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = controller, log = c?.selected;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
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
        bottomNavigationBar: log == null
            ? null
            : SessionTimerPanel(
                start: log.startedAt,
                end: log.completedAt,
                rest: rest,
              ),
        appBar: AppBar(
          title: Text(log == null ? 'Workout log' : log.plan.day),
          actions: [
            if (log != null)
              IconButton(
                key: const Key('delete_selected_workout'),
                tooltip: 'Delete workout',
                color: colors.error,
                onPressed: c!.locked ? null : () => _deleteWorkout(log),
                icon: const Icon(Icons.delete_outline),
              ),
          ],
          leading: log == null
              ? null
              : IconButton(
                  tooltip: 'Workout history',
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
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
              : AppContent(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      if (log == null)
                        const AppPageHeader(
                          title: 'Manual workout log',
                          subtitle: 'Record what you actually did. These entries do not verify a baseline or enable weight recommendations.',
                        )
                      else ...[
                        AppPageHeader(
                          title: log.plan.title,
                          eyebrow: 'MANUAL WORKOUT LOG',
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _statusLabel(
                            log.completed
                                ? log.endedEarly
                                      ? 'Finished early · Saved records kept'
                                      : 'Saved workout · Tap a set to correct it'
                                : 'Draft · Each accepted set is saved',
                            icon: log.completed
                                ? Icons.check_circle_outline_rounded
                                : Icons.circle_outlined,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Record what you actually did. These entries do not verify a baseline or enable weight recommendations.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (c.busy) ...[
                        const LinearProgressIndicator(),
                        const SizedBox(height: 12),
                      ],
                      OutlinedButton.icon(
                        key: const Key('choose_today_workout'),
                        onPressed: c.locked ? null : _chooseToday,
                        icon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 19,
                        ),
                        label: const Text('Choose today’s workout'),
                      ),
                      if (c.pending != null && c.error != null)
                        for (final set in c.pending!.sets.where(
                          (s) => !c.selected!.sets.contains(s),
                        ))
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: AppNotice(
                              text:
                                  'Unconfirmed entry: ${set.slot}, set ${set.index}, ${set.side.name}: ${set.skipped ? 'skipped' : '${set.reps} reps, ${set.load == null ? 'bodyweight' : '${formatPounds(set.load!)} lb'}, RIR ${set.rir ?? 'unknown'}'}',
                              warning: true,
                            ),
                          ),
                      if (c.error != null) ...[
                        const SizedBox(height: 12),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            c.error!,
                            key: const Key('program_error'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.error,
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: c.busy ? null : _retry,
                            child: const Text('Retry'),
                          ),
                        ),
                      ],
                      if (log == null) ...[
                        const SizedBox(height: 20),
                        if (c.draft != null)
                          FilledButton.icon(
                            onPressed: c.locked
                                ? null
                                : () => c.select(c.draft!.id),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: Text('Resume ${c.draft!.plan.day}'),
                          ),
                        if (c.draft == null)
                          Card(
                            child: Column(
                              children: [
                                for (final plan in ownerProgram) ...[
                                  if (plan != ownerProgram.first)
                                    const Divider(
                                      height: 1,
                                      indent: 16,
                                      endIndent: 16,
                                    ),
                                  ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    title: Text('Start ${plan.day}'),
                                    subtitle: Text(plan.title),
                                    trailing: const Icon(
                                      Icons.chevron_right_rounded,
                                    ),
                                    onTap: c.locked
                                        ? null
                                        : () => _start(plan.id),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        const SizedBox(height: 28),
                        const AppSectionHeader(title: 'History'),
                        const SizedBox(height: 12),
                        if (!c.logs.any((l) => l.completed))
                          const AppNotice(
                            text: 'Your finished workouts will appear here.',
                            icon: Icons.history_rounded,
                          ),
                        for (final saved in c.logs.where((l) => l.completed))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Card(
                              child: ListTile(
                                contentPadding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  8,
                                  8,
                                ),
                                title: Text(
                                  '${saved.plan.day} · ${saved.endedEarly
                                      ? 'Finished early'
                                      : saved.hasSkips
                                      ? 'Finished with skipped sets'
                                      : 'Finished'}',
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    saved.startedAt
                                        .toLocal()
                                        .toString()
                                        .split('.')
                                        .first,
                                  ),
                                ),
                                onTap: c.locked
                                    ? null
                                    : () => c.select(saved.id),
                                trailing: IconButton(
                                  key: Key('delete_workout_${saved.id}'),
                                  tooltip: 'Delete workout',
                                  color: colors.error,
                                  onPressed: c.locked
                                      ? null
                                      : () => _deleteWorkout(saved),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ),
                            ),
                          ),
                      ] else ...[
                        if (painExerciseNames.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Semantics(
                            liveRegion: true,
                            container: true,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colors.errorContainer,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                'Pain was recorded for ${painExerciseNames.join(', ')}. Stop the affected exercise. Do not add another set, automatically substitute it, or increase its load or volume.',
                                key: const Key('program_pain_stop'),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.onErrorContainer,
                                ),
                              ),
                            ),
                          ),
                        ],
                        for (final block in log.plan.blocks) ...[
                          const SizedBox(height: 24),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12, left: 4),
                            child: Text(
                              block.isSuperset
                                  ? 'Superset · Rest ${block.restSeconds} sec after both exercises'
                                  : 'Rest ${block.restSeconds} sec${block.exercises.single.eachSide ? ' after both sides' : ''}',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (!log.completed)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => rest.start(
                                  block.restSeconds,
                                  DateTime.now(),
                                ),
                                icon: const Icon(Icons.timer_outlined),
                                label: Text('Start ${block.restSeconds}s rest'),
                              ),
                            ),
                          for (final exercise in block.exercises)
                            _exerciseCard(log, exercise),
                        ],
                        if (!log.completed) ...[
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: c.locked ? null : _finish,
                            child: const Text('Finish workout'),
                          ),
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: c.locked ? null : () => c.select(null),
                            child: const Text('Leave saved as draft'),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _statusLabel(String text, {required IconData icon}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Flexible(child: Text(text, style: theme.textTheme.labelMedium)),
        ],
      ),
    );
  }

  Widget _exerciseCard(ProgramLog log, ProgramExercise exercise) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
              child: Text(
                '${exercise.name} · ${exercise.sets} × ${exercise.minReps}–${exercise.maxReps} · 2–3 RIR',
                style: theme.textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            for (var i = 1; i <= exercise.sets; i++)
              for (final side
                  in exercise.eachSide
                      ? [LoggedSide.left, LoggedSide.right]
                      : [LoggedSide.both])
                _setTile(log, exercise, i, side),
            for (final set in log.sets.where(
              (s) => s.slot == exercise.id && s.warmup,
            ))
              _setTile(log, exercise, set.index, set.side, warmup: true),
            if (!log.completed)
              for (final warmupSide
                  in exercise.eachSide
                      ? [LoggedSide.left, LoggedSide.right]
                      : [LoggedSide.both])
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: TextButton.icon(
                    onPressed: controller!.locked
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
                                : indices.reduce((a, b) => a > b ? a : b) + 1;
                            _edit(
                              log,
                              exercise,
                              next,
                              warmupSide,
                              warmup: true,
                            );
                          },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(
                      'Record a warm-up set${exercise.eachSide ? ' · ${warmupSide.name}' : ''}',
                    ),
                  ),
                ),
          ],
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
        s == null
            ? Icons.add_circle_outline_rounded
            : s.skipped
            ? Icons.remove_circle_outline_rounded
            : s.validity == SetValidity.pain
            ? Icons.warning_amber_rounded
            : Icons.check_circle_outline_rounded,
        color: s?.validity == SetValidity.pain
            ? Theme.of(context).colorScheme.error
            : s == null || s.skipped
            ? Theme.of(context).colorScheme.onSurfaceVariant
            : Theme.of(context).colorScheme.primary,
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
      AppHaptics.of(context).error();
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.exercise.name),
        const SizedBox(height: 8),
        Text(
          '${widget.warmup ? 'Warm-up' : 'Working set'} ${widget.index}${widget.side == LoggedSide.both ? '' : ' · ${widget.side.name}'}',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    ),
    content: SizedBox(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.exercise.alternatives.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              initialValue: variant,
              isExpanded: true,
              itemHeight: null,
              decoration: const InputDecoration(labelText: 'Variation'),
              items: [
                for (final v in widget.exercise.alternatives)
                  DropdownMenuItem(
                    value: v,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(v.replaceAll('_', ' ')),
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v == null || v == variant) return;
                setState(() => variant = v);
                AppHaptics.of(context).selection();
              },
            ),
            const SizedBox(height: 20),
          ],
          TextField(
            controller: setup,
            maxLength: 120,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Exact machine / setup',
              helperText: 'Use a label you can recognize next time.',
              helperMaxLines: 3,
              counterText: '',
            ),
          ),
          const SizedBox(height: 20),
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
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
                ),
            ],
            onChanged: (v) {
              if (v == null || v == convention) return;
              setState(() => convention = v);
              AppHaptics.of(context).selection();
            },
          ),
          if (convention != LoadConvention.bodyweight) ...[
            const SizedBox(height: 20),
            TextField(
              controller: load,
              textInputAction: TextInputAction.next,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Actual load (lb)'),
            ),
          ],
          const SizedBox(height: 20),
          TextField(
            controller: reps,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Actual reps'),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: rir,
            textInputAction: TextInputAction.done,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Reps in reserve (optional)',
            ),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<SetValidity>(
            initialValue: validity,
            isExpanded: true,
            itemHeight: null,
            decoration: const InputDecoration(labelText: 'Set quality'),
            items: [
              for (final v in SetValidity.values)
                DropdownMenuItem(
                  value: v,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(v.name),
                  ),
                ),
            ],
            onChanged: (v) {
              if (v == null || v == validity) return;
              setState(() => validity = v);
              if (v == SetValidity.pain) {
                AppHaptics.of(context).warning();
              } else {
                AppHaptics.of(context).selection();
              }
            },
          ),
          if (error != null) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: AppNotice(text: error!, warning: true),
            ),
          ],
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
