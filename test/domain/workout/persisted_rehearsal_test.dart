import 'package:adaptive_workout/domain/training/training_setup.dart';
import 'package:adaptive_workout/domain/workout/session_composer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/session_composer_fixture.dart';
import '../../support/setup_intake_fixture.dart';

SessionCompositionInput persistedInput(
  ComposerFixture f, {
  bool unlink = false,
  bool stale = false,
  bool? symptoms = false,
  bool? easy = true,
  bool duplicate = false,
  bool includeInjected = false,
}) {
  final i = f.input();
  final slot = switch (f.sessionId) {
    'friday' => 'pull_up',
    'wednesday' => 'hanging_knee_raise',
    _ => 'ab_wheel_rollout',
  };
  final variations = switch (f.sessionId) {
    'friday' => ['assisted_machine_pull_up', 'unassisted_pull_up'],
    'wednesday' => ['supported_knee_raise'],
    _ => ['kneeling_ab_wheel'],
  };
  final confirmations = <RehearsalConfirmation>[];
  for (final variant in variations) {
    final r = i.rehearsals.singleWhere(
      (v) =>
          v.setup.context.slotId == '${f.sessionId}/$slot' &&
          v.setup.context.setupId == variant,
    );
    final s = r.setup;
    confirmations.add(
      RehearsalConfirmation(
        id: 'saved_$variant',
        sourceReference: 'synthetic',
        recordedAt: fixtureAt,
        sessionId: f.sessionId,
        slotId: slot,
        variation: variant,
        setupId: unlink ? null : variant,
        setupRevision: unlink
            ? null
            : stale
            ? 0
            : r.setupRevision,
        easyAndControlled: easy,
        symptomsReported: symptoms,
        assistance: s.assistanceMicroPounds,
        workingRangeRef: s.workingRangeRef,
        rehearsalRangeRef: s.rehearsalRangeRef,
        withinWorkingRange: s.rehearsalWithinWorkingRange,
      ),
    );
  }
  if (duplicate) {
    confirmations.add(
      RehearsalConfirmation.fromJson({
        ...confirmations.first.toJson(),
        'id': 'duplicate',
      }),
    );
  }
  final setup = withIntake(i.setup!, rehearsals: confirmations);
  final reopened = TrainingSetup.decode(setup.encode());
  return SessionCompositionInput(
    id: i.id,
    profile: i.profile,
    sessionId: i.sessionId,
    createdAt: i.createdAt,
    requestedDate: i.requestedDate,
    timezone: i.timezone,
    setup: reopened,
    history: i.history,
    eligibility: i.eligibility,
    inputRevisions: i.inputRevisions,
    rehearsals: includeInjected ? i.rehearsals : [],
  );
}

void main() {
  for (final day in ['wednesday', 'friday', 'saturday']) {
    test(
      '$day: durable exact confirmations supply composer without injected rehearsals',
      () {
        final f = ComposerFixture(day);
        final r = f.composer.compose(persistedInput(f));
        expect(r.isReady, isTrue, reason: r.slotReasons.toString());
        final rehearsals = r.snapshot!.slots
            .expand((s) => s.targets)
            .where((t) => t.rehearsalIdentity != null);
        expect(rehearsals, isNotEmpty);
        expect(
          rehearsals.every(
            (t) =>
                t.rehearsalIdentity!.verificationReference.startsWith('saved_'),
          ),
          isTrue,
        );
      },
    );
  }
  test('unlinked or stale confirmations, missing feedback and ambiguity stay blocked', () {
    final f = ComposerFixture('friday');
    final revised = ComposerFixture('friday', setupRevision: 1);
    for (final i in [
      persistedInput(f, unlink: true),
      persistedInput(f, symptoms: null),
      persistedInput(f, easy: null),
      persistedInput(f, duplicate: true),
      persistedInput(revised, stale: true),
    ]) {
      expect(f.composer.compose(i).isReady, isFalse);
    }
  });
  test(
    'durable symptom and not-easy reports are not silently filtered away',
    () {
      final f = ComposerFixture('friday');
      expect(
        f.composer
            .compose(persistedInput(f, symptoms: true, includeInjected: true))
            .reason,
        'safety_stop',
      );
      expect(
        f.composer
            .compose(persistedInput(f, easy: false, includeInjected: true))
            .reason,
        'warmup_setup_review_required',
      );
    },
  );
}
