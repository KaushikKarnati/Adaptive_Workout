import 'dart:convert';

import 'package:adaptive_workout/domain/logging/practice_repository.dart';
import 'package:adaptive_workout/domain/logging/program_log.dart';
import 'package:adaptive_workout/domain/progression/load_progression_policy.dart';
import 'package:adaptive_workout/domain/recommendations/recommendation_history.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/recommendation_fixture.dart';

void main() {
  test(
    'immutable historical snapshot retains explicit old versions and targets',
    () {
      final plan = generatedPlan(program: 'historic_program_0');
      final restored = RecommendationSnapshot.decode(plan.encode());
      expect(restored.encode(), plan.encode());
      expect(restored.programVersion, 'historic_program_0');
      expect(() => restored.slots.clear(), throwsUnsupportedError);
      expect(() => restored.inputRevisions.clear(), throwsUnsupportedError);
      expect(
        () => restored.slots.single.targets.clear(),
        throwsUnsupportedError,
      );
      expect(restored.estimatedSeconds, isNull);
    },
  );
  test(
    'malformed schemas, units, unknown fields and missing references reject',
    () {
      final j = generatedPlan().toJson();
      for (final patch in [
        {'schema': 2},
        {'unit': 'kg'},
        {'unexpected': true},
        {'historyRevision': -1},
        {'catalogDigest': 'x'},
        {'inputRevisions': <String, int>{}},
        {'preferredMinutes': 0},
        {'slots': []},
        {'createdAt': '2026-09-25T00:00:00'},
      ]) {
        expect(
          () => RecommendationSnapshot.decode(jsonEncode({...j, ...patch})),
          throwsA(anything),
        );
      }
      expect(
        () => RecommendationSnapshot.decode('x' * 2000001),
        throwsA(isA<LoggingException>()),
      );
    },
  );
  test('blocked results cannot carry executable targets or start', () {
    final r = generatedPlan(status: RecommendationStatus.blocked);
    expect(RecommendationSnapshot.decode(r.encode()).slots, isEmpty);
    expect(
      () => generatedStart(r).validateAgainst(r),
      throwsA(isA<LoggingException>()),
    );
  });
  test('draft, completion, audited correction and warmup identities', () {
    final r = generatedPlan();
    var s = generatedStart(r);
    expect(
      () => s.finish(generatedTime, OccurrenceStatus.completed, r),
      throwsA(isA<LoggingException>()),
    );
    s = s.record(generatedActual(warmup: true), generatedTime, r);
    expect(
      () => s.finish(generatedTime, OccurrenceStatus.completed, r),
      throwsA(isA<LoggingException>()),
    );
    s = s.record(generatedActual(), generatedTime, r);
    s = s.record(generatedActual(index: 2, skipped: true), generatedTime, r);
    final finished = s.finish(generatedTime, OccurrenceStatus.completed, r);
    validateOccurrenceTransition(s, finished, r);
    final corrected = finished.record(
      generatedActual(reps: 8, rir: null),
      generatedTime,
      r,
    );
    validateOccurrenceTransition(finished, corrected, r);
    expect(corrected.sets.length, 3);
    expect(finished.sets.where((s) => !s.warmup).first.reps, 12);
    expect(
      GeneratedOccurrence.decode(corrected.encode()).encode(),
      corrected.encode(),
    );
    expect(
      () => corrected.record(generatedActual(index: 3), generatedTime, r),
      throwsA(isA<LoggingException>()),
    );
  });
  test(
    'invalid contexts, numbers, duplicate identities and backwards time reject',
    () {
      final r = generatedPlan();
      final s = generatedStart(r);
      for (final set in [
        generatedActual(slot: generatedSlot(setup: 'other')),
        generatedActual(side: LoggedSide.left),
        generatedActual(index: 0),
        generatedActual(reps: -1),
        generatedActual(rir: -1),
        generatedActual(load: null),
      ]) {
        expect(() => s.record(set, generatedTime, r), throwsA(anything));
      }
      expect(
        () => s.record(
          generatedActual(),
          generatedTime.subtract(const Duration(seconds: 1)),
          r,
        ),
        throwsA(anything),
      );
      final j = s.record(generatedActual(), generatedTime, r).toJson();
      expect(
        () => GeneratedOccurrence.decode(
          jsonEncode({
            ...j,
            'sets': [...(j['sets'] as List), ...(j['sets'] as List)],
          }),
        ),
        throwsA(anything),
      );
    },
  );
  test(
    'pain correction cannot erase durable stop or permit additional work',
    () {
      final r = generatedPlan();
      final stopped = generatedStart(
        r,
      ).record(generatedActual(validity: SetValidity.pain), generatedTime, r);
      final corrected = stopped.record(generatedActual(), generatedTime, r);
      expect(corrected.stoppedSlots, ['press']);
      expect(
        () => corrected.record(generatedActual(index: 2), generatedTime, r),
        throwsA(isA<LoggingException>()),
      );
      final skipped = corrected.record(
        generatedActual(index: 2, skipped: true),
        generatedTime,
        r,
      );
      expect(skipped.sets.length, 2);
    },
  );
  test(
    'incomplete and incomparable exposures are retained, current records once',
    () {
      final r0 = generatedPlan();
      final s0 = generatedComplete(r0);
      final r1 = generatedPlan(
        id: 'rec1',
        at: generatedTime.add(const Duration(days: 1)),
      );
      final s1 = generatedComplete(r1, id: 'session1', sequence: 1);
      LoadProgressionResult evaluate(
        List<GeneratedOccurrence> sessions, {
        RecommendedSlot? slot,
      }) {
        final current = slot ?? generatedSlot();
        final history = generatedHistory([r0, r1], sessions);
        final context = progressionContext(
          'fixture',
          'fixture_program',
          'session_a',
          current,
        );
        return const LoadProgressionPolicy().evaluate(
          LoadProgressionInput(
            context: context,
            gate: ProgressionGate.permitted,
            baseline: VerifiedLoadBaseline(
              context: context,
              microPounds: 100000000,
            ),
            availableLoadsMicroPounds: [95000000, 100000000, 105000000],
            history: history.progression(
              programId: 'fixture_program',
              programVersion: 'fixture_program_v1',
              sessionTemplate: 'session_a',
              current: current,
            ),
          ),
        );
      }

      expect(evaluate([s1, s0]).action, ProgressionAction.increase);
      final corrected = s1.record(generatedActual(rir: null), s1.updatedAt, r1);
      expect(evaluate([s0, corrected]).action, ProgressionAction.hold);
      final interrupted = generatedStart(r1, id: 'session1', sequence: 1);
      expect(evaluate([s0, interrupted]).action, ProgressionAction.hold);
      final early = interrupted.finish(
        interrupted.updatedAt,
        OccurrenceStatus.endedEarly,
        r1,
      );
      expect(evaluate([s0, early]).action, ProgressionAction.hold);
      expect(
        evaluate([s0, s1], slot: generatedSlot(baseline: 'reconfirmed')).action,
        ProgressionAction.hold,
      );
      expect(
        evaluate([s0, s1], slot: generatedSlot(setupRevision: 1)).action,
        ProgressionAction.hold,
      );
      expect(
        evaluate([s0, s1], slot: generatedSlot(exercise: 'alternative')).action,
        ProgressionAction.hold,
      );
      final exposures = generatedHistory([r0, r1], [s0, corrected]).progression(
        programId: 'fixture_program',
        programVersion: 'fixture_program_v1',
        sessionTemplate: 'session_a',
        current: generatedSlot(),
      );
      expect(exposures.length, 2);
      expect(exposures.last.sets.length, 2);
    },
  );
  test(
    'both sides required, warmups excluded, bodyweight and assistance distinct',
    () {
      final slot = generatedSlot(unilateral: true);
      final r = generatedPlan(slot: slot);
      var s = generatedStart(r).record(
        generatedActual(slot: slot, side: LoggedSide.left, warmup: true),
        generatedTime,
        r,
      );
      for (final t in slot.targets.where((t) => !t.warmup)) {
        if (t.index == 2 && t.side == LoggedSide.right) continue;
        s = s.record(
          generatedActual(slot: slot, index: t.index, side: t.side),
          generatedTime,
          r,
        );
      }
      expect(
        () => s.finish(generatedTime, OccurrenceStatus.completed, r),
        throwsA(isA<LoggingException>()),
      );
      s = s.record(
        generatedActual(slot: slot, index: 2, side: LoggedSide.right),
        generatedTime,
        r,
      );
      s = s.finish(generatedTime, OccurrenceStatus.completed, r);
      final exposures = generatedHistory([r], [s]).progression(
        programId: 'fixture_program',
        programVersion: r.programVersion,
        sessionTemplate: r.sessionTemplate,
        current: slot,
      );
      expect(exposures.single.sets.length, 4);
      expect(exposures.single.sets.every((s) => s.working), isTrue);
      expect(
        progressionContext(
          'fixture',
          'p',
          's',
          generatedSlot(convention: LoadConvention.bodyweight),
        ).loadKind,
        ProgressionLoadKind.bodyweight,
      );
      expect(
        progressionContext(
          'fixture',
          'p',
          's',
          generatedSlot(convention: LoadConvention.assistance),
        ).loadKind,
        ProgressionLoadKind.assistance,
      );
    },
  );
  test(
    'complete envelopes reject omitted tail revision, gaps and profile mixing',
    () {
      final r = generatedPlan();
      final s = generatedComplete(r);
      expect(
        () => GeneratedHistory(
          profile: 'fixture',
          revision: 9,
          recommendations: [r],
          occurrences: [s],
        ),
        throwsA(anything),
      );
      expect(
        () => generatedHistory([r], [generatedComplete(r, sequence: 1)]),
        throwsA(anything),
      );
      expect(
        () => GeneratedHistory(
          profile: 'other',
          revision: 0,
          recommendations: [r],
          occurrences: [],
        ),
        throwsA(anything),
      );
      expect(() => generatedHistory([], [s]), throwsA(anything));
      expect(() => generatedHistory([r], [s, s]), throwsA(anything));
    },
  );
  test(
    'intervening historical program version remains a streak-breaking exposure',
    () {
      final first = generatedPlan();
      final middle = generatedPlan(
        id: 'middle',
        program: 'fixture_program_v2',
        at: generatedTime.add(const Duration(days: 1)),
      );
      final last = generatedPlan(
        id: 'last',
        at: generatedTime.add(const Duration(days: 2)),
      );
      final history = generatedHistory(
        [first, middle, last],
        [
          generatedComplete(first),
          generatedComplete(middle, id: 'middle_session', sequence: 1),
          generatedComplete(last, id: 'last_session', sequence: 2),
        ],
      );
      final exposures = history.progression(
        programId: 'fixture_program',
        programVersion: 'fixture_program_v1',
        sessionTemplate: 'session_a',
        current: generatedSlot(),
      );
      expect(exposures.length, 3);
      expect(exposures[1].completed, isFalse);
      final context = progressionContext(
        'fixture',
        'fixture_program',
        'session_a',
        generatedSlot(),
      );
      final result = const LoadProgressionPolicy().evaluate(
        LoadProgressionInput(
          context: context,
          gate: ProgressionGate.permitted,
          baseline: VerifiedLoadBaseline(
            context: context,
            microPounds: 100000000,
          ),
          availableLoadsMicroPounds: [100000000, 105000000],
          history: exposures,
        ),
      );
      expect(result.action, ProgressionAction.hold);
    },
  );
  test('target validation rejects duplicate, missing side, wrong convention and excessive bounds', () {
    final slot = generatedSlot();
    final target = slot.targets.last;
    RecommendedSlot replace(
      List<SetTarget> targets, {
      bool unilateral = false,
      LoadConvention convention = LoadConvention.machineSetting,
    }) => RecommendedSlot(
      id: slot.id,
      exerciseId: slot.exerciseId,
      blockId: slot.blockId,
      setupId: slot.setupId,
      setupRevision: 0,
      baselineReference: slot.baselineReference,
      convention: convention,
      unilateral: unilateral,
      targets: targets,
    );
    expect(() => replace([target, target]), throwsA(isA<LoggingException>()));
    expect(() => replace([target]), throwsA(isA<LoggingException>()));
    expect(
      () => replace(slot.targets, unilateral: true),
      throwsA(isA<LoggingException>()),
    );
    expect(
      () => replace(slot.targets, convention: LoadConvention.bodyweight),
      throwsA(isA<LoggingException>()),
    );
    final j = target.toJson();
    for (final patch in [
      {'load': -1},
      {'load': 1000000000001},
      {'index': 0},
      {'minReps': 0},
      {'maxReps': 7},
      {'minRir': -1},
      {'restSeconds': -1},
    ]) {
      expect(() => SetTarget.fromJson({...j, ...patch}), throwsA(anything));
    }
    final boundary = SetTarget.fromJson({
      ...j,
      'load': 1000000000000,
      'restSeconds': 0,
    });
    expect(boundary.load, 1000000000000);
  });
}
