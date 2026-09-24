import 'package:adaptive_workout/domain/workout/session_planning_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = SessionPlanningPolicy();
  const sessions = ['upper', 'legs', 'shoulders', 'back', 'legs_abs'];
  SessionPlanningInput input({
    List<int>? days = const [2, 4, 7],
    List<SessionSequenceEntry>? history = const [],
    DateTime? date,
    List<String>? order = sessions,
  }) => SessionPlanningInput(
    orderedSessionIds: order,
    trainingWeekdays: days,
    history: history,
    requestedDate: date ?? DateTime.utc(2026, 9, 23),
  );
  SessionSequenceEntry entry(int sequence, PlannedSessionState state) =>
      SessionSequenceEntry(
        id: 'session-$sequence',
        sequence: sequence,
        sessionId: sessions[sequence % sessions.length],
        state: state,
      );

  test('user days replace owner weekdays; misses retain next session', () {
    final result = policy.evaluate(input());
    expect(result.sessionId, 'upper');
    expect(result.date, DateTime.utc(2026, 9, 24));
    expect(
      policy.evaluate(input(date: DateTime.utc(2026, 10, 1))).sessionId,
      'upper',
    );
    expect(policy.evaluate(input(days: [7])).date, DateTime.utc(2026, 9, 27));
  });

  test(
    'explicit early ending advances just like completion, including wrap',
    () {
      for (final state in [
        PlannedSessionState.completed,
        PlannedSessionState.endedEarly,
      ]) {
        expect(
          policy.evaluate(input(history: [entry(0, state)])).sessionId,
          'legs',
        );
        expect(
          policy
              .evaluate(
                input(history: [for (var i = 0; i < 5; i++) entry(i, state)]),
              )
              .sessionId,
          'upper',
        );
      }
    },
  );

  test('interruption resumes active session even on unscheduled day', () {
    final result = policy.evaluate(
      input(days: [], history: [entry(0, PlannedSessionState.active)]),
    );
    expect(result.reasonCode, 'resume_session');
    expect(result.sessionId, 'upper');
    expect(result.date, isNull);
  });

  test('explicit empty schedule differs from missing schedule and history', () {
    expect(policy.evaluate(input(days: [])).reasonCode, 'schedule_required');
    expect(
      policy.evaluate(input(days: null)).reasonCode,
      'required_input_missing',
    );
    expect(
      policy.evaluate(input(history: null)).reasonCode,
      'required_input_missing',
    );
    expect(
      policy.evaluate(input(order: null)).reasonCode,
      'required_input_missing',
    );
    expect(
      policy
          .evaluate(
            SessionPlanningInput(
              orderedSessionIds: sessions,
              trainingWeekdays: [1],
              history: [],
              requestedDate: null,
            ),
          )
          .reasonCode,
      'required_input_missing',
    );
  });

  test('date and sequence boundaries are deterministic', () {
    expect(policy.evaluate(input(days: [3])).date, DateTime.utc(2026, 9, 23));
    expect(policy.evaluate(input(days: [2])).date, DateTime.utc(2026, 9, 29));
    expect(
      policy.evaluate(input(days: [1], date: DateTime.utc(2026, 12, 31))).date,
      DateTime.utc(2027, 1, 4),
    );
    final history = [
      entry(0, PlannedSessionState.completed),
      entry(1, PlannedSessionState.endedEarly),
    ];
    final a = policy.evaluate(input(history: history));
    final b = policy.evaluate(
      input(history: history.reversed.toList(), days: [7, 4, 2]),
    );
    expect(
      [a.reasonCode, a.sessionId, a.date],
      [b.reasonCode, b.sessionId, b.date],
    );
  });

  test(
    'rejects invalid days, dates, program identifiers and partial history',
    () {
      for (final days in [
        [0],
        [8],
        [1, 1],
      ]) {
        expect(policy.evaluate(input(days: days)).reasonCode, 'invalid_input');
      }
      for (final order in <List<String>>[
        [],
        ['a', 'a'],
        [''],
        [' a'],
      ]) {
        expect(
          policy.evaluate(input(order: order)).reasonCode,
          'invalid_input',
        );
      }
      for (final date in [
        DateTime(2026, 9, 23),
        DateTime.utc(2026, 9, 23, 1),
        DateTime.utc(9999),
      ]) {
        expect(policy.evaluate(input(date: date)).reasonCode, 'invalid_input');
      }
      for (final history in [
        [entry(1, PlannedSessionState.completed)],
        [
          entry(0, PlannedSessionState.completed),
          entry(0, PlannedSessionState.completed),
        ],
        [
          entry(0, PlannedSessionState.active),
          entry(1, PlannedSessionState.completed),
        ],
        [
          const SessionSequenceEntry(
            id: '',
            sequence: 0,
            sessionId: 'upper',
            state: PlannedSessionState.completed,
          ),
        ],
        [
          const SessionSequenceEntry(
            id: 'x',
            sequence: 0,
            sessionId: 'legs',
            state: PlannedSessionState.completed,
          ),
        ],
      ]) {
        expect(
          policy.evaluate(input(history: history)).reasonCode,
          'invalid_history',
        );
      }
    },
  );

  test('input collections are copied and immutable', () {
    final days = [1];
    final history = <SessionSequenceEntry>[];
    final order = ['a'];
    final snapshot = input(days: days, history: history, order: order);
    days.clear();
    history.add(entry(0, PlannedSessionState.active));
    order.clear();
    expect(policy.evaluate(snapshot).reasonCode, 'next_session');
    expect(() => snapshot.trainingWeekdays!.clear(), throwsUnsupportedError);
    expect(() => snapshot.history!.clear(), throwsUnsupportedError);
    expect(() => snapshot.orderedSessionIds!.clear(), throwsUnsupportedError);
  });

  test('duration preference has no 45, 60 or 75 minute cutoff', () {
    for (final minutes in [1, 30, 45, 60, 75, 90, 120]) {
      expect(
        compareSessionDuration(
          preferredMinutes: minutes,
          estimatedSeconds: minutes * 60,
        ),
        DurationFit.withinPreference,
      );
      expect(
        compareSessionDuration(
          preferredMinutes: minutes,
          estimatedSeconds: minutes * 60 + 1,
        ),
        DurationFit.exceedsPreference,
      );
    }
    expect(
      compareSessionDuration(preferredMinutes: 45, estimatedSeconds: 0),
      DurationFit.withinPreference,
    );
    expect(
      compareSessionDuration(preferredMinutes: 45, estimatedSeconds: null),
      DurationFit.estimateRequired,
    );
    for (final minutes in [null, 0, -1]) {
      expect(
        compareSessionDuration(
          preferredMinutes: minutes,
          estimatedSeconds: 3600,
        ),
        DurationFit.invalidInput,
      );
    }
    expect(
      compareSessionDuration(preferredMinutes: 45, estimatedSeconds: -1),
      DurationFit.invalidInput,
    );
  });
}
