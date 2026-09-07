import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons, CupertinoTabBar;
import 'package:flutter/material.dart';

enum _FlowScreen { welcome, today, preview, active, completion }

const _sampleExercises = <({String name, String target, String detail})>[
  (name: 'Barbell bench press', target: '4 × 5–7', detail: '165 lb · 2 RIR'),
  (name: 'Chest-supported row', target: '3 × 8–10', detail: '70 lb · 2 RIR'),
  (name: 'Seated dumbbell press', target: '3 × 8–10', detail: '45 lb · 2 RIR'),
  (name: 'Cable lateral raise', target: '3 × 12–15', detail: '15 lb · 2 RIR'),
  (name: 'Rope pressdown', target: '3 × 10–12', detail: '45 lb · 2 RIR'),
];

class SampleWorkoutFlow extends StatefulWidget {
  const SampleWorkoutFlow({super.key, this.now = DateTime.now});

  final DateTime Function() now;

  @override
  State<SampleWorkoutFlow> createState() => _SampleWorkoutFlowState();
}

class _SampleWorkoutFlowState extends State<SampleWorkoutFlow>
    with WidgetsBindingObserver {
  _FlowScreen _screen = _FlowScreen.welcome;
  int _selectedTab = 0;
  int _load = 165;
  int _reps = 6;
  int _rir = 2;
  int _loggedSets = 0;
  int _restSeconds = 90;
  Timer? _restTimer;
  DateTime? _restDeadline;
  String? _lastSetSummary;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _restTimer?.cancel();
    _notesController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshRestTimer();
  }

  void _goTo(_FlowScreen screen) => setState(() {
    _screen = screen;
    _selectedTab = 0;
  });

  void _goBack() {
    switch (_screen) {
      case _FlowScreen.welcome:
        return;
      case _FlowScreen.today:
        return _goTo(_FlowScreen.welcome);
      case _FlowScreen.preview:
        return _goTo(_FlowScreen.today);
      case _FlowScreen.active:
        return _goTo(_FlowScreen.preview);
      case _FlowScreen.completion:
        return _goTo(_FlowScreen.active);
    }
  }

  void _logSet() {
    if (_loggedSets >= 4) return;
    _restTimer?.cancel();
    _restDeadline = widget.now().add(const Duration(seconds: 90));
    setState(() {
      _loggedSets += 1;
      _lastSetSummary = '$_load lb × $_reps @ $_rir RIR';
      _restSeconds = 90;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      _refreshRestTimer();
    });
  }

  void _refreshRestTimer() {
    final deadline = _restDeadline;
    if (deadline == null || !mounted) return;
    final milliseconds = deadline.difference(widget.now()).inMilliseconds;
    final remaining = milliseconds <= 0 ? 0 : (milliseconds + 999) ~/ 1000;
    if (remaining == _restSeconds) return;
    setState(() => _restSeconds = remaining);
    if (remaining == 0) _restTimer?.cancel();
  }

  void _finishWorkout() {
    _restTimer?.cancel();
    _goTo(_FlowScreen.completion);
  }

  void _resetSampleSession() {
    _restTimer?.cancel();
    setState(() {
      _screen = _FlowScreen.today;
      _selectedTab = 0;
      _load = 165;
      _reps = 6;
      _rir = 2;
      _loggedSets = 0;
      _restSeconds = 90;
      _restDeadline = null;
      _lastSetSummary = null;
      _notesController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_screen == _FlowScreen.welcome) {
      return _WelcomeScreen(onStarted: () => _goTo(_FlowScreen.today));
    }
    final content = _selectedTab == 0
        ? switch (_screen) {
            _FlowScreen.today => _TodayScreen(
              onPreview: () => _goTo(_FlowScreen.preview),
            ),
            _FlowScreen.preview => _PreviewScreen(
              onBack: _goBack,
              onStart: () => _goTo(_FlowScreen.active),
            ),
            _FlowScreen.active => _ActiveWorkoutScreen(
              load: _load,
              reps: _reps,
              rir: _rir,
              loggedSets: _loggedSets,
              restSeconds: _restSeconds,
              lastSetSummary: _lastSetSummary,
              onBack: _goBack,
              onLoadChanged: (value) => setState(() => _load = value),
              onRepsChanged: (value) => setState(() => _reps = value),
              onRirChanged: (value) => setState(() => _rir = value),
              onLogSet: _logSet,
              onFinish: _finishWorkout,
            ),
            _FlowScreen.completion => _CompletionScreen(
              loggedSets: _loggedSets,
              lastSetSummary: _lastSetSummary,
              notesController: _notesController,
              onBack: _goBack,
              onDone: _resetSampleSession,
            ),
            _FlowScreen.welcome => const SizedBox.shrink(),
          }
        : _PlaceholderScreen(tabIndex: _selectedTab);
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedTab != 0) {
          setState(() => _selectedTab = 0);
        } else if (!didPop) {
          _goBack();
        }
      },
      child: Scaffold(
        body: SafeArea(bottom: false, child: content),
        bottomNavigationBar: CupertinoTabBar(
          currentIndex: _selectedTab,
          activeColor: theme.colorScheme.primary,
          inactiveColor: theme.colorScheme.onSurfaceVariant,
          backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.94),
          onTap: (index) => setState(() => _selectedTab = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.calendar_today),
              label: 'Today',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.clock),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.chart_bar),
              label: 'Progress',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.gear_alt),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeScreen extends StatelessWidget {
  const _WelcomeScreen({required this.onStarted});

  final VoidCallback onStarted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 38,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _BrandMark(),
                    const Spacer(),
                    const _SamplePill(),
                    const SizedBox(height: 18),
                    Text(
                      'Your next workout, made clear.',
                      style: theme.textTheme.displaySmall,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'A focused training experience that will adapt to your history, goals, and equipment.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const _ValueLine(
                      icon: Icons.route_outlined,
                      title: 'Know exactly what to do',
                      detail: 'A complete session with clear targets.',
                    ),
                    const SizedBox(height: 18),
                    const _ValueLine(
                      icon: Icons.tune,
                      title: 'Built around your training',
                      detail: 'The validated engine will connect later.',
                    ),
                    const Spacer(),
                    FilledButton(
                      key: const Key('get_started'),
                      onPressed: onStarted,
                      child: const Text('Get started'),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        'Fixed sample data · Nothing is saved',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayScreen extends StatelessWidget {
  const _TodayScreen({required this.onPreview});

  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: _BrandMark()),
              SizedBox(width: 10),
              _SamplePill(),
            ],
          ),
          const SizedBox(height: 34),
          Text(
            'TODAY · SAMPLE',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text('Upper strength', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'A focused upper-body session with strength work first.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Expanded(
                        child: _Metric(
                          icon: Icons.schedule,
                          value: '52 min',
                          label: 'Estimated',
                        ),
                      ),
                      _CardDivider(),
                      Expanded(
                        child: _Metric(
                          icon: Icons.fitness_center,
                          value: '5',
                          label: 'Exercises',
                        ),
                      ),
                      _CardDivider(),
                      Expanded(
                        child: _Metric(
                          icon: Icons.layers_outlined,
                          value: '16',
                          label: 'Sets',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    key: const Key('preview_workout'),
                    onPressed: onPreview,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Preview workout'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'This recommendation is illustrative. No workout engine is connected yet.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewScreen extends StatelessWidget {
  const _PreviewScreen({required this.onBack, required this.onStart});

  final VoidCallback onBack;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        _TopBar(title: 'Workout preview', onBack: onBack),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: [
              Text('Upper strength', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text(
                '52 min · 16 working sets',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              ..._sampleExercises.indexed.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ExerciseRow(index: item.$1 + 1, exercise: item.$2),
                ),
              ),
              Card(
                child: ExpansionTile(
                  leading: const Icon(Icons.lightbulb_outline),
                  title: const Text('Why this workout?'),
                  subtitle: const Text('Sample explanation'),
                  childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  children: const [
                    Text(
                      'This placeholder shows where the validated engine will explain its recommendation.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('start_workout'),
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start sample workout'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActiveWorkoutScreen extends StatelessWidget {
  const _ActiveWorkoutScreen({
    required this.load,
    required this.reps,
    required this.rir,
    required this.loggedSets,
    required this.restSeconds,
    required this.lastSetSummary,
    required this.onBack,
    required this.onLoadChanged,
    required this.onRepsChanged,
    required this.onRirChanged,
    required this.onLogSet,
    required this.onFinish,
  });

  final int load;
  final int reps;
  final int rir;
  final int loggedSets;
  final int restSeconds;
  final String? lastSetSummary;
  final VoidCallback onBack;
  final ValueChanged<int> onLoadChanged;
  final ValueChanged<int> onRepsChanged;
  final ValueChanged<int> onRirChanged;
  final VoidCallback onLogSet;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rest =
        '${(restSeconds ~/ 60).toString().padLeft(2, '0')}:${(restSeconds % 60).toString().padLeft(2, '0')}';
    return Column(
      children: [
        _TopBar(title: 'Exercise 1 of 5', onBack: onBack),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
            children: [
              LinearProgressIndicator(
                value: 0.2,
                minHeight: 5,
                borderRadius: BorderRadius.circular(6),
              ),
              const SizedBox(height: 26),
              Semantics(
                header: true,
                child: Text(
                  'Barbell bench press',
                  style: theme.textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Set ${loggedSets.clamp(0, 3) + 1} of 4 · Target 5–7 reps · 2 RIR',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Text(
                        'Previous: 165 lb × 6 @ 2 RIR',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _SetControl(
                        label: 'Load',
                        value: '$load lb',
                        minusKey: const Key('load_minus'),
                        plusKey: const Key('load_plus'),
                        onMinus: load > 0
                            ? () => onLoadChanged(load - 5)
                            : null,
                        onPlus: () => onLoadChanged(load + 5),
                      ),
                      const Divider(height: 28),
                      _SetControl(
                        label: 'Reps',
                        value: '$reps',
                        minusKey: const Key('reps_minus'),
                        plusKey: const Key('reps_plus'),
                        onMinus: reps > 0
                            ? () => onRepsChanged(reps - 1)
                            : null,
                        onPlus: () => onRepsChanged(reps + 1),
                      ),
                      const Divider(height: 28),
                      _SetControl(
                        label: 'RIR',
                        value: '$rir',
                        minusKey: const Key('rir_minus'),
                        plusKey: const Key('rir_plus'),
                        onMinus: rir > 0 ? () => onRirChanged(rir - 1) : null,
                        onPlus: rir < 5 ? () => onRirChanged(rir + 1) : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (lastSetSummary != null)
                Card(
                  key: const Key('rest_timer_card'),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(
                                liveRegion: true,
                                label: 'Set logged: $lastSetSummary',
                                excludeSemantics: true,
                                child: Text('Logged: $lastSetSummary'),
                              ),
                              Semantics(
                                label: _restAccessibilityLabel(restSeconds),
                                excludeSemantics: true,
                                child: Text(
                                  'Rest $rest',
                                  key: const Key('rest_timer'),
                                  style: theme.textTheme.titleLarge,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const Key('log_set'),
                onPressed: loggedSets < 4 ? onLogSet : null,
                icon: const Icon(Icons.check),
                label: Text(
                  loggedSets >= 4
                      ? 'All sample sets logged'
                      : lastSetSummary == null
                      ? 'Log set'
                      : 'Log next set',
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                key: const Key('finish_workout'),
                onPressed: onFinish,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Finish sample workout'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _restAccessibilityLabel(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    if (minutes == 0) return 'Rest timer, $remainder seconds remaining';
    return 'Rest timer, $minutes minute${minutes == 1 ? '' : 's'} and '
        '$remainder seconds remaining';
  }
}

class _CompletionScreen extends StatelessWidget {
  const _CompletionScreen({
    required this.loggedSets,
    required this.lastSetSummary,
    required this.notesController,
    required this.onBack,
    required this.onDone,
  });

  final int loggedSets;
  final String? lastSetSummary;
  final TextEditingController notesController;
  final VoidCallback onBack;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        _TopBar(title: 'Workout summary', onBack: onBack),
        Expanded(
          child: _PageScroll(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 38,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 22),
                Semantics(
                  header: true,
                  child: Text(
                    'Workout complete',
                    style: theme.textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Nice work. This summary uses sample session data.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: _Metric(
                                icon: Icons.timer_outlined,
                                value: '48 min',
                                label: 'Duration',
                              ),
                            ),
                            const _CardDivider(),
                            Expanded(
                              child: _Metric(
                                icon: Icons.check_circle_outline,
                                value: '$loggedSets',
                                label: 'Sets logged',
                              ),
                            ),
                          ],
                        ),
                        if (lastSetSummary != null) ...[
                          const Divider(height: 30),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Last set: $lastSetSummary',
                              key: const Key('completion_last_set'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Session notes (sample only)',
                    hintText: 'How did the workout feel?',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('return_today'),
                  onPressed: onDone,
                  child: const Text('Return to Today'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.tabIndex});

  final int tabIndex;

  @override
  Widget build(BuildContext context) {
    const labels = ['Today', 'History', 'Progress', 'Settings'];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.construction_outlined, size: 42),
            const SizedBox(height: 16),
            Text(
              labels[tabIndex],
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'This area is a placeholder for a later milestone.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 6, 18, 8),
    child: Row(
      children: [
        IconButton(
          key: const Key('flow_back'),
          onPressed: onBack,
          tooltip: 'Back',
          icon: const Icon(CupertinoIcons.back),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        const _SamplePill(),
      ],
    ),
  );
}

class _PageScroll extends StatelessWidget {
  const _PageScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 100),
    child: child,
  );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          Icons.bolt_rounded,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
      const SizedBox(width: 10),
      const Flexible(
        child: Text(
          'Adaptive Workout',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );
}

class _SamplePill extends StatelessWidget {
  const _SamplePill();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outline),
      borderRadius: BorderRadius.circular(99),
    ),
    child: const Text(
      'SAMPLE',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      ),
    ),
  );
}

class _ValueLine extends StatelessWidget {
  const _ValueLine({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: Theme.of(context).colorScheme.primary, size: 26),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(
              detail,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 7),
      Text(
        value,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ],
  );
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 54,
    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.65),
  );
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.index, required this.exercise});

  final int index;
  final ({String name, String target, String detail}) exercise;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 24;
    final number = Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$index',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          exercise.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        Text(
          exercise.detail,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    final target = Text(
      exercise.target,
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w800,
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: largeText
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      number,
                      const SizedBox(width: 13),
                      Expanded(child: details),
                    ],
                  ),
                  const SizedBox(height: 12),
                  target,
                ],
              )
            : Row(
                children: [
                  number,
                  const SizedBox(width: 13),
                  Expanded(child: details),
                  const SizedBox(width: 8),
                  target,
                ],
              ),
      ),
    );
  }
}

class _SetControl extends StatelessWidget {
  const _SetControl({
    required this.label,
    required this.value,
    required this.minusKey,
    required this.plusKey,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final String value;
  final Key minusKey;
  final Key plusKey;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    final semanticLabel = label == 'RIR' ? 'repetitions in reserve' : label;
    final valueControls = Row(
      children: [
        IconButton.filledTonal(
          key: minusKey,
          onPressed: onMinus,
          tooltip: 'Decrease $semanticLabel',
          icon: const Icon(Icons.remove),
        ),
        Expanded(
          child: Semantics(
            label: '$semanticLabel $value',
            liveRegion: true,
            excludeSemantics: true,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        IconButton.filledTonal(
          key: plusKey,
          onPressed: onPlus,
          tooltip: 'Increase $semanticLabel',
          icon: const Icon(Icons.add),
        ),
      ],
    );
    final labelWidget = Text(
      label,
      style: const TextStyle(fontWeight: FontWeight.w700),
    );
    if (MediaQuery.textScalerOf(context).scale(16) > 24) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [labelWidget, const SizedBox(height: 8), valueControls],
      );
    }
    return Row(
      children: [
        SizedBox(width: 58, child: labelWidget),
        Expanded(child: valueControls),
      ],
    );
  }
}
