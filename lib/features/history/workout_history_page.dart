import 'package:flutter/material.dart';

import '../../data/repositories/sqlite_program_log_repository.dart';
import '../../domain/history/workout_history.dart';
import '../../domain/logging/program_log.dart';
import '../../domain/logging/practice_repository.dart';
import '../../ui/app_components.dart';
import '../../ui/app_haptics.dart';
import '../program/program_log_controller.dart';
import '../program/program_logging_page.dart';

class WorkoutHistoryPage extends StatefulWidget {
  const WorkoutHistoryPage({
    super.key,
    this.repository,
    this.graphs = false,
    this.embedded = false,
    this.onOpenLog,
    this.reloadToken = 0,
  });
  final ProgramLogRepository? repository;
  final bool graphs;
  final bool embedded;
  final Future<void> Function(ProgramLog)? onOpenLog;
  final int reloadToken;
  @override
  State<WorkoutHistoryPage> createState() => _WorkoutHistoryPageState();
}

class _WorkoutHistoryPageState extends State<WorkoutHistoryPage> {
  ProgramLogController? controller;
  bool failed = false;
  late bool graphs = widget.graphs;
  String query = '';
  int days = 0;
  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    setState(() => failed = false);
    try {
      final repo = widget.repository ?? await SqliteProgramLogRepository.open();
      if (!mounted) {
        if (widget.repository == null) await repo.close();
        return;
      }
      controller = ProgramLogController(repo)..addListener(_changed);
      await controller!.load();
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(WorkoutHistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) controller?.load();
  }

  @override
  void dispose() {
    controller?.removeListener(_changed);
    if (widget.repository == null) controller?.repository.close();
    controller?.dispose();
    super.dispose();
  }

  Future<void> _showLog(ProgramLog log) async {
    if (widget.onOpenLog != null) {
      await widget.onOpenLog!(log);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProgramLoggingPage(
          repository: controller!.repository,
          initialSessionId: log.id,
        ),
      ),
    );
    if (mounted) await controller!.load();
  }

  String _date(DateTime date) =>
      MaterialLocalizations.of(context).formatMediumDate(date.toLocal());
  @override
  Widget build(BuildContext context) {
    final c = controller;
    final logs = filterWorkoutHistory(
      c?.logs ?? [],
      profile: c?.profile ?? 'local_owner',
      query: query,
      since: days == 0 ? null : DateTime.now().subtract(Duration(days: days)),
    );
    final series = exerciseHistory(logs);
    final body = SafeArea(
      child: AppContent(
        child: c == null
            ? Center(
                child: failed
                    ? TextButton(
                        onPressed: _open,
                        child: const Text('Could not open history. Retry'),
                      )
                    : const CircularProgressIndicator(),
              )
            : RefreshIndicator(
                onRefresh: c.load,
                child: ListView(
                  key: const PageStorageKey('workout_history_scroll'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    AppPageHeader(
                      title: graphs ? 'Your progress' : 'Your history',
                      subtitle: 'Manual workouts · Saved on this device',
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('History'),
                          selected: !graphs,
                          onSelected: (_) => _selectGraphs(false),
                        ),
                        ChoiceChip(
                          label: const Text('Graphs'),
                          selected: graphs,
                          onSelected: (_) => _selectGraphs(true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('history_search'),
                      decoration: const InputDecoration(
                        labelText: 'Search workouts or exercises',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) => setState(() => query = value),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final value in [0, 30, 90, 365])
                          ChoiceChip(
                            label: Text(
                              value == 0 ? 'All time' : '$value days',
                            ),
                            selected: days == value,
                            onSelected: (_) {
                              if (days == value) return;
                              setState(() => days = value);
                              AppHaptics.of(context).selection();
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (c.busy) const LinearProgressIndicator(),
                    if (c.error != null) ...[
                      AppNotice(text: c.error!, warning: true),
                      TextButton(
                        onPressed: c.busy ? null : c.load,
                        child: const Text('Retry'),
                      ),
                    ] else if (graphs) ...[
                      const AppNotice(
                        text: 'Recorded working sets marked valid only. Warm-ups, skipped and pain-affected sets are excluded. These graphs do not enable weight recommendations.',
                      ),
                      const SizedBox(height: 16),
                      if (series.isEmpty)
                        const AppNotice(
                          text: 'No graph data for these filters. Finish a workout with valid working sets to see it here.',
                        ),
                      for (final item in series)
                        _GraphCard(
                          key: ValueKey(item.key),
                          series: item,
                          date: _date,
                          open: _showLog,
                        ),
                    ] else ...[
                      Text(
                        '${logs.length} finished workouts',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      if (logs.isEmpty)
                        const AppNotice(
                          text: 'No finished workouts for these filters. Your saved workouts will appear here.',
                        ),
                      for (var i = 0; i < logs.length; i++) ...[
                        if (i == 0 ||
                            !DateUtils.isSameDay(
                              logs[i - 1].startedAt.toLocal(),
                              logs[i].startedAt.toLocal(),
                            ))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: AppSectionHeader(
                              title: _date(logs[i].startedAt),
                            ),
                          ),
                        Card(
                          child: ListTile(
                            key: Key('history_workout_${logs[i].id}'),
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(logs[i].plan.title),
                            subtitle: Text(
                              '${logs[i].plan.day} · ${logs[i].endedEarly
                                  ? 'Finished early'
                                  : logs[i].hasSkips
                                  ? 'Finished with skips'
                                  : 'Finished'}\n${logs[i].sets.where((s) => !s.warmup && !s.skipped).length} working-set records · ${TimeOfDay.fromDateTime(logs[i].startedAt.toLocal()).format(context)}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _showLog(logs[i]),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
      ),
    );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: Text(graphs ? 'Graphs' : 'History')),
      body: body,
    );
  }

  void _selectGraphs(bool value) {
    if (graphs == value) return;
    setState(() => graphs = value);
    AppHaptics.of(context).selection();
  }
}

String _convention(LoadConvention value) => switch (value) {
  LoadConvention.perDumbbell => 'lb per dumbbell',
  LoadConvention.machineSetting => 'lb machine setting',
  LoadConvention.platesOnly => 'lb plates only',
  LoadConvention.totalLoad => 'lb total load',
  LoadConvention.assistance => 'lb assistance',
  LoadConvention.bodyweight => 'Bodyweight',
};

class _GraphCard extends StatefulWidget {
  const _GraphCard({
    super.key,
    required this.series,
    required this.date,
    required this.open,
  });
  final ExerciseHistorySeries series;
  final String Function(DateTime) date;
  final void Function(ProgramLog) open;
  @override
  State<_GraphCard> createState() => _GraphCardState();
}

class _GraphCardState extends State<_GraphCard> {
  bool reps = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.series;
    final showReps = reps || s.key.convention == LoadConvention.bodyweight;
    final values = s.points
        .map((p) => showReps ? p.set.reps!.toDouble() : p.set.load! / 1000000)
        .toList();
    final unit = showReps ? 'reps' : _convention(s.key.convention);
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '${s.key.setup}\n${_convention(s.key.convention)} · ${s.key.side == LoggedSide.both ? 'Both sides' : '${s.key.side.name} side'} · ${s.points.first.log.plan.day}',
            ),
            if (s.key.variant != s.key.slot)
              Text(s.key.variant.replaceAll('_', ' ')),
            if (s.key.convention == LoadConvention.assistance)
              const Text('Assistance is support provided, not weight lifted.'),
            const SizedBox(height: 12),
            if (s.key.convention != LoadConvention.bodyweight)
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Load'),
                    selected: !reps,
                    onSelected: (_) => _selectReps(false),
                  ),
                  ChoiceChip(
                    label: const Text('Reps'),
                    selected: reps,
                    onSelected: (_) => _selectReps(true),
                  ),
                ],
              ),
            Text(
              'Latest: ${values.last.toStringAsFixed(showReps ? 0 : 2)} $unit',
            ),
            const SizedBox(height: 12),
            Semantics(
              label:
                  '$unit by recorded set, oldest to newest. Exact values in Recorded sets below.',
              child: SizedBox(
                height: 150,
                width: double.infinity,
                child: CustomPaint(
                  painter: _Plot(
                    values,
                    colors.primary,
                    colors.outlineVariant,
                    Theme.of(context).textTheme.bodySmall!,
                  ),
                ),
              ),
            ),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 20,
              children: [
                Text(widget.date(s.points.first.log.startedAt)),
                Text(widget.date(s.points.last.log.startedAt)),
              ],
            ),
            Text(
              'Recorded sets, oldest → newest · $unit',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (values.length == 1)
              const Text(
                'One recorded set. More records will build the graph.',
              ),
            ExpansionTile(
              key: PageStorageKey(('recorded_sets', s.key)),
              onExpansionChanged: (_) => AppHaptics.of(context).selection(),
              tilePadding: EdgeInsets.zero,
              title: const Text('Recorded sets'),
              children: [
                for (final p in s.points.reversed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${p.set.reps} reps${p.set.load == null ? '' : ' × ${formatPounds(p.set.load!)} ${_convention(p.set.convention)}'}',
                    ),
                    subtitle: Text(
                      '${widget.date(p.log.startedAt)} · Set ${p.set.index}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => widget.open(p.log),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _selectReps(bool value) {
    if (reps == value) return;
    setState(() => reps = value);
    AppHaptics.of(context).selection();
  }
}

class _Plot extends CustomPainter {
  _Plot(this.values, this.color, this.grid, this.labelStyle);
  final TextStyle labelStyle;
  final List<double> values;
  final Color color, grid;
  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = values.fold<double>(0, (a, b) => a > b ? a : b);
    final top = maxValue == 0 ? 1.0 : maxValue * 1.1;
    const left = 58.0;
    final width = size.width - left - 8;
    final height = size.height - 20;
    for (var i = 0; i <= 2; i++) {
      final y = 8 + height * i / 2;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width, y),
        Paint()..color = grid,
      );
      final label = TextPainter(
        text: TextSpan(
          text: (top * (1 - i / 2)).toStringAsFixed(1),
          style: labelStyle.copyWith(fontSize: 11, color: color),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: left - 4);
      label.paint(canvas, Offset(0, y - 6));
    }
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final p = Offset(
        left +
            (values.length == 1 ? width / 2 : width * i / (values.length - 1)),
        8 + height * (1 - values[i] / top),
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawCircle(p, 3.5, Paint()..color = color);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_Plot oldDelegate) => true;
}
