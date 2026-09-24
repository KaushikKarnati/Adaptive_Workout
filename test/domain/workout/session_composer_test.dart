import 'dart:convert';

import 'package:adaptive_workout/domain/logging/practice_repository.dart';
import 'package:adaptive_workout/domain/logging/program_log.dart';
import 'package:adaptive_workout/domain/recommendations/recommendation_history.dart';
import 'package:adaptive_workout/domain/workout/owner_program.dart';
import 'package:adaptive_workout/domain/workout/session_composer.dart';
import 'package:adaptive_workout/domain/workout/session_planning_policy.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/session_composer_fixture.dart';

void main() {
  test('excluded rehearsal equipment cannot prepare unassisted pull-ups', () {
    final f = ComposerFixture('friday', excluded: ['assisted_machine_pull_up']);
    expect(f.composer.compose(f.input()).isReady, isFalse);
  });
  test(
    'schema two rejects null working effort and work identity overrides',
    () {
      final f = ComposerFixture('friday');
      final r = f.composer.compose(f.input()).snapshot!;
      for (final mutation in [
        <String, Object?>{'minRir': null, 'maxRir': null},
        <String, Object?>{
          'rehearsalIdentity': r.slots.first.targets.first.rehearsalIdentity!
              .toJson(),
        },
      ]) {
        final work = r.slots.first.targets
            .firstWhere((t) => !t.warmup)
            .toJson();
        expect(
          () => SetTarget.fromJson({...work, ...mutation}),
          throwsA(isA<LoggingException>()),
        );
      }
      final json = r.toJson();
      expect(
        () => RecommendationSnapshot.decode(jsonEncode({...json, 'schema': 3})),
        throwsA(isA<LoggingException>()),
      );
      expect(
        () => RecommendationSnapshot.decode(jsonEncode({...json, 'schema': 1})),
        throwsA(isA<LoggingException>()),
      );
      expect(
        () => RecommendationSnapshot.decode(
          jsonEncode({...json, 'generationReferences': null}),
        ),
        throwsA(isA<LoggingException>()),
      );
    },
  );
  test('catalog versions with dots survive immutable snapshot encoding', () {
    final f = ComposerFixture('monday');
    final r = f.composer.compose(f.input()).snapshot!;
    expect(r.catalogVersion, '2026.09.08.1');
    expect(
      RecommendationSnapshot.decode(r.encode()).catalogVersion,
      r.catalogVersion,
    );
  });

  test('eligible shared inventory cannot substitute for exact setup equipment verification', () {
    final f = ComposerFixture('monday', requireCatalogEquipment: true);
    final r = f.composer.compose(f.input());
    expect(r.isReady, isFalse);
    expect(r.slotReasons.values, everyElement('catalog_setup_mismatch'));
  });
  test(
    'missing history or profile and invalid civil date cannot generate targets',
    () {
      final f = ComposerFixture('monday');
      final i = f.input();
      for (var n = 0; n < 4; n++) {
        final changed = SessionCompositionInput(
          id: i.id,
          profile: n == 2 ? 'other' : i.profile,
          sessionId: i.sessionId,
          createdAt: i.createdAt,
          requestedDate: n == 3
              ? i.requestedDate.add(const Duration(hours: 1))
              : i.requestedDate,
          timezone: i.timezone,
          setup: n == 0 ? null : i.setup,
          history: n == 1 ? null : i.history,
          eligibility: i.eligibility,
          inputRevisions: i.inputRevisions,
          rehearsals: i.rehearsals,
        );
        final result = f.composer.compose(changed);
        expect(result.snapshot, isNull);
        expect(
          result.reason,
          n < 2 ? 'required_input_missing' : 'invalid_input',
        );
      }
    },
  );
  for (final template in ownerProgram) {
    test(
      '${template.id}: complete ordered deterministic session and snapshot reopen',
      () {
        final f = ComposerFixture(template.id);
        final result = f.composer.compose(f.input());
        expect(
          result.reason,
          'session_ready',
          reason: result.slotReasons.toString(),
        );
        final r = result.snapshot!;
        expect(r.walkSeconds, 300);
        expect(
          r.slots.map((s) => s.id),
          template.blocks.expand((b) => b.exercises).map((e) => e.id),
        );
        expect(
          r.slots.expand((s) => s.targets).where((t) => !t.warmup).length,
          template.blocks
              .expand((b) => b.exercises)
              .fold<int>(0, (n, e) => n + e.sets * (e.eachSide ? 2 : 1)),
        );
        expect(
          r.slots
              .expand((s) => s.targets)
              .where((t) => t.warmup)
              .every((t) => t.minRir == null && t.maxRir == null),
          isTrue,
        );
        expect(RecommendationSnapshot.decode(r.encode()).encode(), r.encode());
        final reversed = ComposerFixture(template.id, reverse: true);
        expect(
          reversed.composer.compose(reversed.input()).snapshot!.encode(),
          r.encode(),
        );
        expect(result.durationFit, DurationFit.estimateRequired);
        expect(r.estimatedSeconds, isNull);
      },
    );
  }
  test('paired execution rehearses both members before alternating rounds', () {
    final f = ComposerFixture('monday');
    final r = f.composer.compose(f.input());
    final paired = r.executionOrder
        .where(
          (a) => [
            'incline_machine_press',
            'chest_supported_row',
          ].contains(a.slotId),
        )
        .toList();
    expect(paired.take(2).every((a) => a.target.warmup), isTrue);
    expect(paired.skip(2).map((a) => a.slotId), [
      'incline_machine_press',
      'chest_supported_row',
      'incline_machine_press',
      'chest_supported_row',
      'incline_machine_press',
      'chest_supported_row',
    ]);
  });

  test(
    'two exposures propose a change without changing work or warmup targets',
    () {
      final f = ComposerFixture('monday');
      final plans = <RecommendationSnapshot>[];
      final occurrences = <GeneratedOccurrence>[];
      for (var n = 0; n < 2; n++) {
        final fixture = ComposerFixture(
          'monday',
          history: GeneratedHistory(
            profile: 'fixture',
            revision: occurrences.fold(0, (sum, s) => sum + s.revision + 1),
            recommendations: plans,
            occurrences: occurrences,
          ),
        );
        final at = fixtureAt.add(Duration(days: n));
        final r = fixture.composer
            .compose(fixture.input(id: 'r$n', at: at))
            .snapshot!;
        plans.add(r);
        var occurrence = GeneratedOccurrence(
          id: 's$n',
          profile: 'fixture',
          recommendationId: r.id,
          sequence: n,
          revision: 0,
          startedAt: at,
          updatedAt: at,
          endedAt: null,
          status: OccurrenceStatus.active,
          sets: [],
          stoppedSlots: [],
        );
        for (final slot in r.slots) {
          for (final t in slot.targets.where((t) => !t.warmup)) {
            occurrence = occurrence.record(
              ProgramSet(
                slot: slot.id,
                index: t.index,
                side: t.side,
                variant: slot.exerciseId,
                setup: slot.setupId,
                convention: slot.convention,
                load: t.load,
                reps: t.maxReps,
                rir: 2,
                validity: SetValidity.valid,
                warmup: false,
                skipped: false,
              ),
              at,
              r,
            );
          }
        }
        occurrences.add(occurrence.finish(at, OccurrenceStatus.completed, r));
      }
      final next = ComposerFixture(
        'monday',
        history: GeneratedHistory(
          profile: 'fixture',
          revision: occurrences.fold(0, (sum, s) => sum + s.revision + 1),
          recommendations: plans,
          occurrences: occurrences,
        ),
      );
      final r = next.composer.compose(
        next.input(id: 'next', at: fixtureAt.add(const Duration(days: 2))),
      );
      expect(r.isReady, isTrue);
      expect(r.proposals, hasLength(6));
      expect(r.snapshot!.proposedLoads.values, everyElement(105000000));
      expect(
        r.snapshot!.slots
            .expand((s) => s.targets)
            .where((t) => !t.warmup)
            .map((t) => t.load),
        everyElement(100000000),
      );
      expect(r.snapshot!.slots.first.targets.first.load, 50000000);
      expect(r.snapshot!.evidence.keys.toSet(), {'s0', 's1'});
      expect(
        r.snapshot!.slots.first.baselineReference,
        f.composer.compose(f.input()).snapshot!.slots.first.baselineReference,
      );
      final reversed = ComposerFixture(
        'monday',
        history: GeneratedHistory(
          profile: 'fixture',
          revision: next.history!.revision,
          recommendations: plans.reversed.toList(),
          occurrences: occurrences.reversed.toList(),
        ),
      );
      expect(
        reversed.composer
            .compose(
              reversed.input(
                id: 'next',
                at: fixtureAt.add(const Duration(days: 2)),
              ),
            )
            .snapshot!
            .encode(),
        r.snapshot!.encode(),
      );
    },
  );

  test('new bodyweight work retains the verified working range', () {
    final f = ComposerFixture('saturday');
    final r = f.composer.compose(f.input()).snapshot!;
    expect(
      r.slots.last.targets.where((t) => !t.warmup).map((t) => t.rangeReference),
      everyElement('range'),
    );
  });

  test(
    'walking once, exact first-exercise ramps, paired rest after second member',
    () {
      final f = ComposerFixture('monday');
      final r = f.composer.compose(f.input()).snapshot!;
      expect(
        r.slots.first.targets
            .where((t) => t.warmup)
            .map((t) => [t.load, t.minReps, t.restSeconds]),
        [
          [50000000, 8, 60],
          [75000000, 5, 90],
        ],
      );
      for (final slot in r.slots.skip(1)) {
        expect(slot.targets.where((t) => t.warmup), hasLength(1));
      }
      expect(
        r.slots[2].targets.where((t) => !t.warmup).map((t) => t.restSeconds),
        [0, 0, 0],
      );
      expect(
        r.slots[3].targets.where((t) => !t.warmup).map((t) => t.restSeconds),
        [90, 90, 90],
      );
    },
  );
  test(
    'Friday cross-setup pull-up rehearsal and first external press ramp',
    () {
      final f = ComposerFixture('friday');
      final r = f.composer.compose(f.input()).snapshot!;
      final rehearsals = r.slots.first.targets.where((t) => t.warmup).toList();
      expect(rehearsals.map((t) => t.load), [70000000, null]);
      expect(rehearsals.map((t) => t.minReps), [5, 2]);
      expect(rehearsals.map((t) => t.restSeconds), [60, 120]);
      expect(
        rehearsals.first.rehearsalIdentity!.convention,
        LoadConvention.assistance,
      );
      expect(r.slots[1].targets.where((t) => t.warmup), hasLength(2));
      final arm = r.slots.singleWhere(
        (s) => s.id == 'single_arm_cable_pulldown',
      );
      expect(arm.targets.where((t) => !t.warmup).map((t) => t.side), [
        LoggedSide.left,
        LoggedSide.right,
        LoggedSide.left,
        LoggedSide.right,
        LoggedSide.left,
        LoggedSide.right,
      ]);
      final occurrence = GeneratedOccurrence(
        id: 'occ',
        profile: 'fixture',
        recommendationId: r.id,
        sequence: 0,
        revision: 0,
        startedAt: fixtureAt,
        updatedAt: fixtureAt,
        endedAt: null,
        status: OccurrenceStatus.active,
        sets: [],
        stoppedSlots: [],
      );
      final t = rehearsals.first;
      final identity = t.rehearsalIdentity!;
      final actual = ProgramSet(
        slot: r.slots.first.id,
        index: t.index,
        side: t.side,
        variant: identity.exerciseId,
        setup: identity.setupId,
        convention: identity.convention,
        load: t.load,
        reps: 5,
        rir: null,
        validity: SetValidity.valid,
        warmup: true,
        skipped: false,
      );
      final recorded = occurrence.record(actual, fixtureAt, r);
      expect(recorded.sets.single.load, 70000000);
      expect(
        GeneratedOccurrence.decode(recorded.encode()).encode(),
        recorded.encode(),
      );
    },
  );
  test('approved preferences and alternatives select in order', () {
    for (final day in ['tuesday', 'saturday']) {
      final first = ComposerFixture(day);
      final second = ComposerFixture(day, excluded: ['seated_leg_curl']);
      expect(
        first.composer
            .compose(first.input())
            .snapshot!
            .slots
            .any((s) => s.setupId == 'seated_leg_curl'),
        isTrue,
      );
      expect(
        second.composer
            .compose(second.input())
            .snapshot!
            .slots
            .any((s) => s.setupId == 'lying_leg_curl'),
        isTrue,
      );
    }
    final shoulders = ComposerFixture(
      'wednesday',
      missing: ['machine_shoulder_press'],
    );
    expect(
      shoulders.composer
          .compose(shoulders.input())
          .snapshot!
          .slots
          .first
          .setupId,
      'dumbbell_shoulder_press',
    );
    final assisted = ComposerFixture('friday', assistedOnly: true);
    final first = assisted.composer
        .compose(assisted.input())
        .snapshot!
        .slots
        .first;
    expect(first.convention, LoadConvention.assistance);
    expect(
      first.targets
          .where((t) => t.warmup)
          .map((t) => [t.minReps, t.restSeconds]),
      [
        [5, 120],
      ],
    );
  });
  test('missing equipment, all excluded, disabled catalog, missing rehearsal fail closed', () {
    for (final f in [
      ComposerFixture('monday', missing: ['incline_dumbbell_press']),
      ComposerFixture(
        'tuesday',
        excluded: ['seated_leg_curl', 'lying_leg_curl'],
      ),
      ComposerFixture('monday', disabled: true),
      ComposerFixture('friday', missingRehearsal: true),
    ]) {
      final result = f.composer.compose(f.input());
      expect(result.isReady, isFalse);
      expect(result.snapshot!.slots, isEmpty);
      expect(result.snapshot!.walkSeconds, 0);
      expect(result.proposals, isEmpty);
    }
  });
  test(
    'safety stop and stale setup revision return no executable snapshot',
    () {
      final stopped = ComposerFixture('monday', stop: true);
      expect(stopped.composer.compose(stopped.input()).reason, 'safety_stop');
      final f = ComposerFixture('monday');
      expect(
        f.composer.compose(f.input(revisionOverride: 1)).reason,
        'stale_input',
      );
    },
  );
  test(
    'zero rehearsal setting remains separate from positive working settings',
    () {
      final f = ComposerFixture('monday', rehearsalLoads: [0]);
      final r = f.composer.compose(f.input()).snapshot!;
      expect(r.status, RecommendationStatus.ready);
      expect(
        r.slots.first.targets.where((t) => t.warmup).every((t) => t.load == 0),
        isTrue,
      );
      final missing = ComposerFixture('monday', rehearsalLoads: []);
      expect(missing.composer.compose(missing.input()).isReady, isFalse);
    },
  );
  test(
    'a one-minute preference does not shorten or block the prescription',
    () {
      final f = ComposerFixture('monday', preferredMinutes: 1);
      final r = f.composer.compose(f.input());
      expect(r.isReady, isTrue);
      expect(r.snapshot!.preferredMinutes, 1);
      expect(r.snapshot!.walkSeconds, 300);
    },
  );
}
