import 'package:adaptive_workout/domain/progression/load_progression_policy.dart';
import 'package:adaptive_workout/domain/workout/warmup_policy.dart';
import 'package:flutter_test/flutter_test.dart';

const _context = (
  profileId: 'fixture',
  slotId: 'press',
  exerciseId: 'fixture_press',
  setupId: 'fixture_machine',
  loadConventionId: 'added_pounds',
  setCount: 3,
  minReps: 8,
  maxReps: 12,
  unilateral: false,
  loadKind: ProgressionLoadKind.external,
);
const _baseline = VerifiedLoadBaseline(
  context: _context,
  microPounds: 100000000,
);

WarmupResult _run({
  bool first = true,
  ProgressionGate? gate = ProgressionGate.permitted,
  VerifiedLoadBaseline? baseline = _baseline,
  List<int>? loads = const [40000000, 50000000, 70000000, 80000000, 100000000],
  ProgressionContext context = _context,
}) => const WarmupPolicy().evaluate(
  gate: gate,
  context: context,
  baseline: baseline,
  availableLoadsMicroPounds: loads,
  firstExternalLoadExercise: first,
);

void main() {
  test(
    'approved example rounds second target down, with exact reps and rest',
    () {
      final result = _run();
      expect(result.isBlocked, isFalse);
      expect(result.sets.map((s) => s.microPounds), [50000000, 70000000]);
      expect(result.sets.map((s) => s.reps), [8, 5]);
      expect(result.sets.map((s) => s.restAfterSeconds), [60, 90]);
      expect(result.sets.every((s) => !s.isWorkingSet), isTrue);
      expect(result.ruleSetVersion, 'owner-warmup-v1');
      expect(WarmupPolicy.sessionWalkingSeconds, 300);
    },
  );

  test(
    'later exercise receives one five-rep rehearsal and sixty-second rest',
    () {
      final result = _run(first: false);
      expect(result.sets, hasLength(1));
      expect(result.sets.single.reps, 5);
      expect(result.sets.single.restAfterSeconds, 60);
    },
  );

  test('exact percentage limits accepted, one micro-pound over rejected', () {
    expect(
      _run(loads: [50000000, 75000000, 100000000]).sets.last.microPounds,
      75000000,
    );
    expect(_run(loads: [50000001, 75000000, 100000000]).isBlocked, isTrue);
    expect(
      _run(loads: [50000000, 75000001, 100000000]).sets.last.microPounds,
      50000000,
    );
  });

  test(
    'verified unloaded-machine setting is usable without inferred resistance',
    () {
      expect(_run(loads: [0, 100000000]).sets.map((s) => s.microPounds), [
        0,
        0,
      ]);
    },
  );

  for (final loads in <List<int>?>[
    null,
    [],
    [-1, 100000000],
    [40000000],
    [80000000, 100000000],
  ]) {
    test(
      'missing, invalid or infeasible settings $loads block the whole plan',
      () {
        final result = _run(loads: loads);
        expect(result.reasonCode, 'warmup_setup_required');
        expect(result.sets, isEmpty);
      },
    );
  }

  for (final baseline in <VerifiedLoadBaseline?>[
    null,
    const VerifiedLoadBaseline(context: _context, microPounds: 0),
    const VerifiedLoadBaseline(context: _context, microPounds: -1),
  ]) {
    test(
      'missing or invalid baseline $baseline never produces warmup weights',
      () {
        expect(_run(baseline: baseline).isBlocked, isTrue);
      },
    );
  }

  for (final kind in [
    ProgressionLoadKind.bodyweight,
    ProgressionLoadKind.assistance,
  ]) {
    test('$kind cannot use external-load percentages', () {
      final context = (
        profileId: _context.profileId,
        slotId: _context.slotId,
        exerciseId: _context.exerciseId,
        setupId: _context.setupId,
        loadConventionId: _context.loadConventionId,
        setCount: 3,
        minReps: 8,
        maxReps: 12,
        unilateral: false,
        loadKind: kind,
      );
      expect(
        _run(
          context: context,
          baseline: VerifiedLoadBaseline(
            context: context,
            microPounds: 100000000,
          ),
        ).reasonCode,
        'warmup_setup_required',
      );
    });
  }

  for (final gate in [
    null,
    ProgressionGate.blocked,
    ProgressionGate.safetyStop,
  ]) {
    test('$gate overrides target generation', () {
      final result = _run(gate: gate, baseline: null);
      expect(result.isBlocked, isTrue);
      expect(
        result.reasonCode,
        gate == ProgressionGate.safetyStop
            ? 'safety_stop'
            : 'current_checks_required',
      );
    });
  }

  test('changed setup cannot reuse a baseline from another machine', () {
    final changed = (
      profileId: _context.profileId,
      slotId: _context.slotId,
      exerciseId: _context.exerciseId,
      setupId: 'different_machine',
      loadConventionId: _context.loadConventionId,
      setCount: 3,
      minReps: 8,
      maxReps: 12,
      unilateral: false,
      loadKind: ProgressionLoadKind.external,
    );
    expect(_run(context: changed).reasonCode, 'warmup_setup_required');
  });

  test('ordering and duplicated settings do not change targets', () {
    final result = _run(
      loads: [100000000, 70000000, 50000000, 50000000, 40000000],
    );
    expect(result.sets.map((s) => s.microPounds), [50000000, 70000000]);
    expect(() => result.sets.clear(), throwsUnsupportedError);
  });
}
