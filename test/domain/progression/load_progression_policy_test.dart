import 'package:adaptive_workout/domain/progression/load_progression_policy.dart';
import 'package:flutter_test/flutter_test.dart';

const _policy = LoadProgressionPolicy();
const _pound = 1000000;

ProgressionContext _context({
  String profile = 'owner',
  String slot = 'monday_press',
  String setup = 'machine_1',
  bool unilateral = false,
  ProgressionLoadKind kind = ProgressionLoadKind.external,
  int minReps = 8,
  int maxReps = 12,
}) => (
  profileId: profile,
  slotId: slot,
  exerciseId: 'fixture_press',
  setupId: setup,
  loadConventionId: 'displayed_pounds',
  setCount: 3,
  minReps: minReps,
  maxReps: maxReps,
  unilateral: unilateral,
  loadKind: kind,
);

ProgressionExposure _exposure(
  int sequence, {
  ProgressionContext? context,
  int reps = 12,
  int? rir = 2,
  bool? valid = true,
  bool completed = true,
  bool correctedOut = false,
  int load = 50 * _pound,
  List<ProgressionSet>? sets,
  String? id,
  DateTime? date,
}) {
  final scope = context ?? _context();
  return ProgressionExposure(
    id: id ?? 'session_$sequence',
    sequence: sequence,
    occurredAt: date ?? DateTime.utc(2026, 9, sequence + 1),
    context: scope,
    completed: completed,
    correctedOut: correctedOut,
    sets:
        sets ??
        [
          for (var index = 1; index <= scope.setCount; index++)
            for (final side
                in scope.unilateral
                    ? [SetSide.left, SetSide.right]
                    : [SetSide.bilateral])
              ProgressionSet(
                index: index,
                side: side,
                microPounds: load,
                reps: reps,
                rir: rir,
                valid: valid,
              ),
        ],
  );
}

LoadProgressionInput _input({
  List<ProgressionExposure>? history,
  List<int>? loads,
  ProgressionContext? context,
  ProgressionContext? baselineContext,
  ProgressionGate? gate = ProgressionGate.permitted,
  int load = 50 * _pound,
  bool missingBaseline = false,
}) {
  final scope = context ?? _context();
  return LoadProgressionInput(
    context: scope,
    gate: gate,
    baseline: missingBaseline
        ? null
        : VerifiedLoadBaseline(
            context: baselineContext ?? scope,
            microPounds: load,
          ),
    availableLoadsMicroPounds:
        loads ?? [45 * _pound, 47500000, 50 * _pound, 52500000, 55 * _pound],
    history: history ?? [_exposure(1), _exposure(2)],
  );
}

void main() {
  test('two qualifying exposures increase by exactly five percent', () {
    final result = _policy.evaluate(_input());
    expect(result.action, ProgressionAction.increase);
    expect(result.candidateMicroPounds, 52500000);
    expect(result.reasonCode, 'progress_two_qualifying_exposures');
    expect(result.evidenceIds, ['session_1', 'session_2']);
    expect(result.ruleSetVersion, 'owner-program-v1');
  });

  test('one micro-pound above five percent holds', () {
    final result = _policy.evaluate(_input(loads: [50000000, 52500001]));
    expect(result.candidateMicroPounds, 50000000);
    expect(result.reasonCode, 'increment_above_five_percent');
  });

  test('no higher load holds instead of inventing an increment', () {
    expect(
      _policy.evaluate(_input(loads: [50000000])).reasonCode,
      'no_higher_load',
    );
  });

  for (final count in [0, 1]) {
    test('$count exposures cannot trigger progression', () {
      final result = _policy.evaluate(
        _input(history: [if (count == 1) _exposure(1)]),
      );
      expect(result.action, ProgressionAction.hold);
      expect(result.reasonCode, 'insufficient_progression_streak');
    });
  }

  test('one low-effort-reserve exposure explains hold accurately', () {
    final result = _policy.evaluate(
      _input(history: [_exposure(1), _exposure(2, rir: 1)]),
    );
    expect(result.action, ProgressionAction.hold);
    expect(result.reasonCode, 'effort_target_not_met');
  });

  test('one weak side cannot be hidden by the stronger side', () {
    final context = _context(unilateral: true);
    final sets = _exposure(2, context: context).sets.toList();
    sets[1] = const ProgressionSet(
      index: 1,
      side: SetSide.right,
      microPounds: 50000000,
      reps: 11,
      rir: 2,
      valid: true,
    );
    final result = _policy.evaluate(
      _input(
        context: context,
        history: [
          _exposure(1, context: context),
          _exposure(2, context: context, sets: sets),
        ],
      ),
    );
    expect(result.action, ProgressionAction.hold);
    expect(result.reasonCode, 'rep_ceiling_not_met');
  });

  test('missing actual load or reps cannot authorize adjustment', () {
    for (final missingLoad in [true, false]) {
      final sets = _exposure(2).sets.toList();
      sets[0] = ProgressionSet(
        index: 1,
        side: SetSide.bilateral,
        microPounds: missingLoad ? null : 50000000,
        reps: missingLoad ? 12 : null,
        rir: 2,
        valid: true,
      );
      expect(
        _policy
            .evaluate(
              _input(
                history: [
                  _exposure(1),
                  _exposure(2, sets: sets),
                ],
              ),
            )
            .reasonCode,
        'insufficient_evidence',
      );
    }
  });

  test('one rep below the ceiling holds', () {
    final result = _policy.evaluate(
      _input(history: [_exposure(1), _exposure(2, reps: 11)]),
    );
    expect(result.reasonCode, 'rep_ceiling_not_met');
  });

  test('reps above ceiling and higher RIR can qualify', () {
    expect(
      _policy
          .evaluate(
            _input(history: [_exposure(1, reps: 13), _exposure(2, rir: 4)]),
          )
          .action,
      ProgressionAction.increase,
    );
  });

  for (final weak in ['reps', 'rir']) {
    test('two $weak underperformances use nearest lower load', () {
      final result = _policy.evaluate(
        _input(
          history: [
            for (var i = 1; i <= 2; i++)
              _exposure(
                i,
                reps: weak == 'reps' ? 7 : 12,
                rir: weak == 'rir' ? 1 : 2,
              ),
          ],
        ),
      );
      expect(result.action, ProgressionAction.decrease);
      expect(result.candidateMicroPounds, 47500000);
    });
  }

  for (final lower in [45000000, 44999999]) {
    test('ten-percent reduction boundary at $lower', () {
      final result = _policy.evaluate(
        _input(
          loads: [lower, 50000000],
          history: [_exposure(1, reps: 7), _exposure(2, reps: 7)],
        ),
      );
      expect(
        result.action,
        lower == 45000000
            ? ProgressionAction.decrease
            : ProgressionAction.blocked,
      );
      expect(result.candidateMicroPounds, lower == 45000000 ? lower : null);
    });
  }

  test('no lower load requests baseline review', () {
    final result = _policy.evaluate(
      _input(
        loads: [50000000],
        history: [_exposure(1, rir: 0), _exposure(2, rir: 1)],
      ),
    );
    expect(result.reasonCode, 'baseline_review_required');
    expect(result.candidateMicroPounds, isNull);
  });

  test('one weak exposure holds', () {
    expect(
      _policy
          .evaluate(_input(history: [_exposure(1), _exposure(2, reps: 7)]))
          .action,
      ProgressionAction.hold,
    );
  });

  test('rep minimum and RIR two do not trigger reduction', () {
    expect(
      _policy
          .evaluate(
            _input(history: [_exposure(1, reps: 8), _exposure(2, reps: 8)]),
          )
          .action,
      ProgressionAction.hold,
    );
  });

  final invalidEvidence = <String, ProgressionExposure>{
    'incomplete': _exposure(2, completed: false),
    'corrected out': _exposure(2, correctedOut: true),
    'missing RIR': _exposure(2, rir: null),
    'negative RIR': _exposure(2, rir: -1),
    'invalid set': _exposure(2, valid: false),
    'unknown validity': _exposure(2, valid: null),
    'negative reps': _exposure(2, reps: -1),
    'different load': _exposure(2, load: 45000000),
    'changed setup': _exposure(2, context: _context(setup: 'machine_2')),
    'no sets': _exposure(2, sets: []),
    'duplicate set': _exposure(
      2,
      sets: List.filled(3, _exposure(1).sets.first),
    ),
    'missing set': _exposure(2, sets: _exposure(1).sets.take(2).toList()),
    'warmups only': _exposure(
      2,
      sets: [
        const ProgressionSet(
          index: 1,
          side: SetSide.bilateral,
          microPounds: 50000000,
          reps: 12,
          rir: 2,
          valid: true,
          working: false,
        ),
      ],
    ),
  };
  for (final entry in invalidEvidence.entries) {
    test('${entry.key} cannot authorize either adjustment', () {
      final result = _policy.evaluate(
        _input(history: [_exposure(1), entry.value]),
      );
      expect(result.action, ProgressionAction.hold);
      expect(result.reasonCode, 'insufficient_evidence');
    });
  }

  test('intervening incomplete session cannot be filtered away', () {
    final result = _policy.evaluate(
      _input(
        history: [_exposure(1), _exposure(2, completed: false), _exposure(3)],
      ),
    );
    expect(result.reasonCode, 'insufficient_evidence');
    expect(result.evidenceIds, ['session_2', 'session_3']);
  });

  test('only two latest exposures affect the streak', () {
    final result = _policy.evaluate(
      _input(
        history: [_exposure(1, completed: false), _exposure(2), _exposure(3)],
      ),
    );
    expect(result.action, ProgressionAction.increase);
    expect(result.evidenceIds, ['session_2', 'session_3']);
  });

  test('history, set and equipment ordering do not change output', () {
    final result = _policy.evaluate(
      _input(
        loads: [55000000, 52500000, 50000000, 52500000, 47500000],
        history: [
          _exposure(2, sets: _exposure(2).sets.reversed.toList()),
          _exposure(1),
        ],
      ),
    );
    expect(result.candidateMicroPounds, 52500000);
    expect(result.evidenceIds, ['session_1', 'session_2']);
  });

  test('different profiles and session slots cannot supply evidence', () {
    final result = _policy.evaluate(
      _input(
        history: [
          _exposure(1),
          _exposure(2, context: _context(profile: 'other')),
          _exposure(3, context: _context(slot: 'friday_press')),
        ],
      ),
    );
    expect(result.reasonCode, 'insufficient_progression_streak');
    expect(result.evidenceIds, ['session_1']);
  });

  for (final (index, history) in [
    [_exposure(1), _exposure(1)],
    [_exposure(1), _exposure(2, id: 'session_1')],
    [_exposure(1), _exposure(2, date: DateTime.utc(2020))],
    [_exposure(1, date: DateTime(2026))],
    [_exposure(-1)],
  ].indexed) {
    test('invalid sequence, identity or date blocks history case $index', () {
      expect(
        _policy.evaluate(_input(history: history)).reasonCode,
        'invalid_history',
      );
    });
  }

  for (final gate in [
    null,
    ProgressionGate.blocked,
    ProgressionGate.safetyStop,
  ]) {
    test('gate $gate prevents all loads even with qualifying evidence', () {
      final result = _policy.evaluate(
        _input(gate: gate, missingBaseline: true),
      );
      expect(result.action, ProgressionAction.blocked);
      expect(result.candidateMicroPounds, isNull);
      expect(
        result.reasonCode,
        gate == ProgressionGate.safetyStop
            ? 'safety_stop'
            : 'current_checks_required',
      );
    });
  }

  test('missing or changed baseline cannot transfer loads', () {
    for (final input in [
      _input(missingBaseline: true),
      _input(baselineContext: _context(setup: 'other_machine')),
    ]) {
      expect(_policy.evaluate(input).reasonCode, 'baseline_required');
    }
  });

  for (final load in [0, -1]) {
    test('invalid external baseline $load blocks', () {
      expect(
        _policy.evaluate(_input(load: load)).reasonCode,
        'invalid_baseline',
      );
    });
  }

  test('missing history never authorizes a change', () {
    final input = _input();
    final result = _policy.evaluate(
      LoadProgressionInput(
        context: input.context,
        gate: input.gate,
        baseline: input.baseline,
        availableLoadsMicroPounds: input.availableLoadsMicroPounds,
        history: null,
      ),
    );
    expect(result.reasonCode, 'insufficient_evidence');
  });

  for (final loads in <List<int>?>[
    null,
    [],
    [-1, 50000000],
    [0, 50000000],
    [45000000],
  ]) {
    test('invalid or unavailable load list $loads blocks', () {
      final input = _input();
      final result = _policy.evaluate(
        LoadProgressionInput(
          context: input.context,
          gate: input.gate,
          baseline: input.baseline,
          availableLoadsMicroPounds: loads,
          history: input.history,
        ),
      );
      expect(result.action, ProgressionAction.blocked);
      expect(result.candidateMicroPounds, isNull);
    });
  }

  for (final kind in [
    ProgressionLoadKind.bodyweight,
    ProgressionLoadKind.assistance,
  ]) {
    test('$kind holds verified baseline without automatic loading', () {
      final context = _context(kind: kind);
      final result = _policy.evaluate(
        _input(context: context, load: 0, loads: [0, 5000000], history: []),
      );
      expect(result.action, ProgressionAction.hold);
      expect(result.candidateMicroPounds, 0);
      expect(result.reasonCode, 'bodyweight_or_assistance_hold');
    });
  }

  test('unilateral progression requires both sides', () {
    final context = _context(unilateral: true);
    final complete = [
      _exposure(1, context: context),
      _exposure(2, context: context),
    ];
    expect(
      _policy.evaluate(_input(context: context, history: complete)).action,
      ProgressionAction.increase,
    );
    final missingRight = _exposure(
      2,
      context: context,
      sets: complete.last.sets.where((s) => s.side == SetSide.left).toList(),
    );
    expect(
      _policy
          .evaluate(
            _input(context: context, history: [complete.first, missingRight]),
          )
          .reasonCode,
      'insufficient_evidence',
    );
  });

  test('invalid context blocks', () {
    for (final context in [
      _context(profile: ''),
      _context(minReps: 0),
      _context(minReps: 13),
    ]) {
      expect(
        _policy.evaluate(_input(context: context)).reasonCode,
        'invalid_input',
      );
    }
  });

  test('caller collections are copied and result evidence is immutable', () {
    final history = [_exposure(1), _exposure(2)];
    final loads = [50000000, 52500000];
    final input = _input(history: history, loads: loads);
    history.clear();
    loads.clear();
    final result = _policy.evaluate(input);
    expect(result.action, ProgressionAction.increase);
    expect(() => result.evidenceIds.add('injected'), throwsUnsupportedError);
  });
}
