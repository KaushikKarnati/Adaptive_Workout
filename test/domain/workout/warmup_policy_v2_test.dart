import 'package:adaptive_workout/domain/progression/load_progression_policy.dart';
import 'package:adaptive_workout/domain/workout/warmup_policy.dart';
import 'package:adaptive_workout/domain/workout/warmup_policy_v2.dart';
import 'package:flutter_test/flutter_test.dart';

RehearsalContext context(
  RehearsalMovement movement, {
  String profile = 'fixture',
  String slot = 'slot',
  String setup = 'setup',
}) => (
  profileId: profile,
  slotId: slot,
  exerciseId: movement.name,
  setupId: setup,
  movement: movement,
);
VerifiedRehearsalSetup setup(
  RehearsalMovement movement, {
  RehearsalContext? identity,
  String verification = 'verification-1',
  bool? easy = true,
  int? assistance = 90000000,
  List<int>? settings = const [60000000, 90000000, 110000000],
  String? workRange = 'working-range',
  String? rehearsalRange,
  bool? within = true,
}) => VerifiedRehearsalSetup(
  context: identity ?? context(movement),
  verificationRef: verification,
  easyAndControlled: easy,
  assistanceMicroPounds: movement == RehearsalMovement.assistedPullUp
      ? assistance
      : null,
  availableAssistanceMicroPounds: movement == RehearsalMovement.assistedPullUp
      ? settings
      : null,
  workingRangeRef:
      movement == RehearsalMovement.supportedKneeRaise ||
          movement == RehearsalMovement.kneelingRollout
      ? workRange
      : null,
  rehearsalRangeRef: movement == RehearsalMovement.supportedKneeRaise
      ? (rehearsalRange ?? workRange)
      : movement == RehearsalMovement.kneelingRollout
      ? (rehearsalRange ?? 'short-range')
      : null,
  rehearsalWithinWorkingRange:
      movement == RehearsalMovement.supportedKneeRaise ||
          movement == RehearsalMovement.kneelingRollout
      ? within
      : null,
);
const policy = BodyweightWarmupPolicy();
RehearsalPlan mixed({
  VerifiedRehearsalSetup? assisted,
  VerifiedRehearsalSetup? unassisted,
  ProgressionGate? gate = ProgressionGate.permitted,
}) => policy.pullUps(
  gate: gate,
  includesUnassistedWork: true,
  assistedContext: context(RehearsalMovement.assistedPullUp),
  assistedSetup: assisted,
  unassistedContext: context(RehearsalMovement.unassistedPullUp),
  unassistedSetup: unassisted,
);
String advance({
  ProgressionGate? gate = ProgressionGate.permitted,
  bool? interrupted = false,
  bool? completed = true,
  RehearsalFeedback? feedback = RehearsalFeedback.easyAndControlled,
  int? elapsed = 60,
  int rest = 60,
  bool? continues = true,
}) => evaluateWarmupContinuation(
  gate: gate,
  interrupted: interrupted,
  targetCompleted: completed,
  feedback: feedback,
  elapsedRestSeconds: elapsed,
  prescribedRestSeconds: rest,
  userContinues: continues,
);

void main() {
  test('mixed pull-ups use exact independently confirmed assistance and separate setups', () {
    final result = mixed(
      assisted: setup(RehearsalMovement.assistedPullUp),
      unassisted: setup(RehearsalMovement.unassistedPullUp),
    );
    expect(result.ruleSetVersion, 'owner-warmup-v2');
    expect(result.reasonCode, 'warmup_targets_ready');
    expect(result.sets.map((s) => s.reps), [5, 2]);
    expect(result.sets.map((s) => s.restAfterSeconds), [60, 120]);
    expect(result.sets.map((s) => s.assistanceMicroPounds), [90000000, null]);
    expect(result.sets.map((s) => s.context.movement), [
      RehearsalMovement.assistedPullUp,
      RehearsalMovement.unassistedPullUp,
    ]);
    expect(
      result.sets.every(
        (s) => !s.isWorkingSet && s.verificationRef == 'verification-1',
      ),
      isTrue,
    );
    expect(() => result.sets.clear(), throwsUnsupportedError);
  });

  test('assisted-only branch never prescribes unassisted rehearsal', () {
    final result = policy.pullUps(
      gate: ProgressionGate.permitted,
      includesUnassistedWork: false,
      assistedContext: context(RehearsalMovement.assistedPullUp),
      assistedSetup: setup(RehearsalMovement.assistedPullUp),
      unassistedContext: null,
      unassistedSetup: null,
    );
    expect(result.sets, hasLength(1));
    expect(result.sets.single.reps, 5);
    expect(result.sets.single.restAfterSeconds, 120);
  });

  test('absent branch or contradictory assisted-only input fails closed', () {
    for (final branch in <bool?>[null, false]) {
      final result = policy.pullUps(
        gate: ProgressionGate.permitted,
        includesUnassistedWork: branch,
        assistedContext: context(RehearsalMovement.assistedPullUp),
        assistedSetup: setup(RehearsalMovement.assistedPullUp),
        unassistedContext: context(RehearsalMovement.unassistedPullUp),
        unassistedSetup: setup(RehearsalMovement.unassistedPullUp),
      );
      expect(result.isBlocked, isTrue);
    }
  });

  test('no partial targets when either required setup is missing', () {
    expect(
      mixed(assisted: setup(RehearsalMovement.assistedPullUp)).sets,
      isEmpty,
    );
    expect(
      mixed(unassisted: setup(RehearsalMovement.unassistedPullUp)).sets,
      isEmpty,
    );
  });

  test('unknown or non-easy confirmation cannot turn a working setting into a rehearsal', () {
    for (final easy in <bool?>[false, null]) {
      expect(
        mixed(
          assisted: setup(RehearsalMovement.assistedPullUp, easy: easy),
          unassisted: setup(RehearsalMovement.unassistedPullUp),
        ).isBlocked,
        isTrue,
      );
    }
  });

  test('missing unavailable negative zero and duplicate assistance settings rejected', () {
    for (final settings in <List<int>?>[
      null,
      [],
      [60000000],
      [-1, 90000000],
      [0, 90000000],
      [90000000, 90000000],
    ]) {
      expect(
        mixed(
          assisted: setup(RehearsalMovement.assistedPullUp, settings: settings),
          unassisted: setup(RehearsalMovement.unassistedPullUp),
        ).isBlocked,
        isTrue,
      );
    }
    for (final value in <int?>[null, 0, -1]) {
      expect(
        mixed(
          assisted: setup(RehearsalMovement.assistedPullUp, assistance: value),
          unassisted: setup(RehearsalMovement.unassistedPullUp),
        ).isBlocked,
        isTrue,
      );
    }
  });

  test('smallest positive exact setting and order invariance without percentage math', () {
    for (final values in [
      [1, 2],
      [2, 1],
    ]) {
      final result = mixed(
        assisted: setup(
          RehearsalMovement.assistedPullUp,
          assistance: 1,
          settings: values,
        ),
        unassisted: setup(RehearsalMovement.unassistedPullUp),
      );
      expect(result.sets.first.assistanceMicroPounds, 1);
    }
    final values = [90000000];
    final saved = setup(RehearsalMovement.assistedPullUp, settings: values);
    values.clear();
    expect(saved.availableAssistanceMicroPounds, [90000000]);
    expect(
      () => saved.availableAssistanceMicroPounds!.clear(),
      throwsUnsupportedError,
    );
  });

  test(
    'changed profile slot machine and malformed verification reject reuse',
    () {
      for (final identity in [
        context(RehearsalMovement.assistedPullUp, profile: 'other'),
        context(RehearsalMovement.assistedPullUp, slot: 'other'),
        context(RehearsalMovement.assistedPullUp, setup: 'other'),
      ]) {
        expect(
          mixed(
            assisted: setup(
              RehearsalMovement.assistedPullUp,
              identity: identity,
            ),
            unassisted: setup(RehearsalMovement.unassistedPullUp),
          ).isBlocked,
          isTrue,
        );
      }
      for (final ref in ['', 'bad\nref', 'x' * 129]) {
        expect(
          mixed(
            assisted: setup(
              RehearsalMovement.assistedPullUp,
              verification: ref,
            ),
            unassisted: setup(RehearsalMovement.unassistedPullUp),
          ).isBlocked,
          isTrue,
        );
      }
      expect(
        mixed(
          assisted: setup(
            RehearsalMovement.assistedPullUp,
            verification: 'x' * 128,
          ),
          unassisted: setup(RehearsalMovement.unassistedPullUp),
        ).isBlocked,
        isFalse,
      );
    },
  );

  test('supported knee raises retain confirmed working range and never become hanging', () {
    final result = policy.core(
      gate: ProgressionGate.permitted,
      context: context(RehearsalMovement.supportedKneeRaise),
      setup: setup(RehearsalMovement.supportedKneeRaise),
    );
    final target = result.sets.single;
    expect(
      [target.reps, target.restAfterSeconds, target.rangeRef],
      [5, 60, 'working-range'],
    );
    expect(target.context.movement, RehearsalMovement.supportedKneeRaise);
    expect(target.assistanceMicroPounds, isNull);
    expect(target.isWorkingSet, isFalse);
  });

  test('kneeling rollout uses separately confirmed short endpoint', () {
    final result = policy.core(
      gate: ProgressionGate.permitted,
      context: context(RehearsalMovement.kneelingRollout),
      setup: setup(RehearsalMovement.kneelingRollout),
    );
    expect(result.sets.single.reps, 3);
    expect(result.sets.single.restAfterSeconds, 60);
    expect(result.sets.single.rangeRef, 'short-range');
    expect(result.sets.single.isWorkingSet, isFalse);
  });

  test('core refuses unknown ranges, farther endpoints, missing and mismatched setups', () {
    for (final movement in [
      RehearsalMovement.supportedKneeRaise,
      RehearsalMovement.kneelingRollout,
    ]) {
      for (final candidate in <VerifiedRehearsalSetup?>[
        null,
        setup(movement, workRange: null),
        setup(movement, rehearsalRange: ''),
        setup(movement, within: null),
        setup(movement, within: false),
        setup(movement, easy: false),
        setup(movement, identity: context(movement, setup: 'other')),
      ]) {
        expect(
          policy
              .core(
                gate: ProgressionGate.permitted,
                context: context(movement),
                setup: candidate,
              )
              .isBlocked,
          isTrue,
        );
      }
    }
    expect(
      policy
          .core(
            gate: ProgressionGate.permitted,
            context: context(RehearsalMovement.supportedKneeRaise),
            setup: setup(
              RehearsalMovement.supportedKneeRaise,
              rehearsalRange: 'other',
            ),
          )
          .isBlocked,
      isTrue,
    );
  });

  test('methods cannot silently substitute a different movement or load convention', () {
    expect(
      policy
          .core(
            gate: ProgressionGate.permitted,
            context: context(RehearsalMovement.assistedPullUp),
            setup: setup(RehearsalMovement.assistedPullUp),
          )
          .isBlocked,
      isTrue,
    );
    final contaminated = VerifiedRehearsalSetup(
      context: context(RehearsalMovement.unassistedPullUp),
      verificationRef: 'v',
      easyAndControlled: true,
      assistanceMicroPounds: 90000000,
    );
    expect(
      mixed(
        assisted: setup(RehearsalMovement.assistedPullUp),
        unassisted: contaminated,
      ).isBlocked,
      isTrue,
    );
  });

  test(
    'safety and unknown current checks take precedence over missing setup',
    () {
      for (final gate in <ProgressionGate?>[
        null,
        ProgressionGate.blocked,
        ProgressionGate.safetyStop,
      ]) {
        final reason = gate == ProgressionGate.safetyStop
            ? 'safety_stop'
            : 'current_checks_required';
        expect(mixed(gate: gate).reasonCode, reason);
        expect(
          policy
              .core(
                gate: gate,
                context: context(RehearsalMovement.kneelingRollout),
                setup: null,
              )
              .reasonCode,
          reason,
        );
        expect(advance(gate: gate, completed: null, elapsed: -1), reason);
      }
    },
  );

  test(
    'continuation requires completion feedback rest and explicit action',
    () {
      expect(advance(), 'next_planned_action_permitted');
      expect(advance(elapsed: 59), 'rest_incomplete');
      expect(advance(elapsed: 120), 'next_planned_action_permitted');
      expect(advance(elapsed: null), 'rest_time_required');
      expect(advance(elapsed: -1), 'invalid_input');
      expect(advance(rest: 0), 'invalid_input');
      for (final value in <bool?>[false, null]) {
        expect(advance(completed: value), 'rehearsal_completion_required');
        expect(advance(continues: value), 'continuation_required');
      }
      for (final feedback in <RehearsalFeedback?>[
        null,
        RehearsalFeedback.unknown,
      ]) {
        expect(advance(feedback: feedback), 'warmup_feedback_required');
      }
      expect(
        advance(feedback: RehearsalFeedback.notEasyOrNotControlled),
        'warmup_setup_review_required',
      );
      for (final interrupted in <bool?>[true, null]) {
        expect(
          advance(interrupted: interrupted),
          'preparation_review_required',
        );
      }
    },
  );

  test(
    'v2 retains external percentages, rounding, rests and walking default',
    () {
      const identity = (
        profileId: 'fixture',
        slotId: 'press',
        exerciseId: 'press',
        setupId: 'machine',
        loadConventionId: 'display_pounds',
        setCount: 3,
        minReps: 8,
        maxReps: 12,
        unilateral: false,
        loadKind: ProgressionLoadKind.external,
      );
      for (final first in [true, false]) {
        final result = externalWarmupV2(
          gate: ProgressionGate.permitted,
          context: identity,
          baseline: const VerifiedLoadBaseline(
            context: identity,
            microPounds: 100000000,
          ),
          availableLoadsMicroPounds: [100000000, 70000000, 50000000],
          firstExternalLoadExercise: first,
        );
        expect(result.ruleSetVersion, 'owner-warmup-v2');
        expect(
          result.sets.map((s) => s.microPounds),
          first ? [50000000, 70000000] : [50000000],
        );
        expect(result.sets.map((s) => s.reps), first ? [8, 5] : [5]);
        expect(
          result.sets.map((s) => s.restAfterSeconds),
          first ? [60, 90] : [60],
        );
        expect(result.sets.every((s) => !s.isWorkingSet), isTrue);
      }
      expect(WarmupPolicy.sessionWalkingSeconds, 300);
    },
  );
}
