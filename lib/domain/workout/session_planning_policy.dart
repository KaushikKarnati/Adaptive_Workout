/// Calendar planning only: never authorizes an exercise or a training load.
library;

enum PlannedSessionState { active, completed, endedEarly }

final class SessionSequenceEntry {
  const SessionSequenceEntry({
    required this.id,
    required this.sequence,
    required this.sessionId,
    required this.state,
  });

  final String id;
  final int sequence;
  final String sessionId;
  final PlannedSessionState state;
}

final class SessionPlanningInput {
  SessionPlanningInput({
    required List<String>? orderedSessionIds,
    required List<int>? trainingWeekdays,
    required List<SessionSequenceEntry>? history,
    required this.requestedDate,
  }) : orderedSessionIds = orderedSessionIds == null
           ? null
           : List.unmodifiable(orderedSessionIds),
       trainingWeekdays = trainingWeekdays == null
           ? null
           : List.unmodifiable(trainingWeekdays),
       history = history == null ? null : List.unmodifiable(history);

  final List<String>? orderedSessionIds;
  // ISO weekdays, 1–7. Empty means no scheduled training days.
  final List<int>? trainingWeekdays;
  // Complete history for one profile/program, starting with sequence zero.
  final List<SessionSequenceEntry>? history;
  // User's civil date encoded as UTC midnight, not a UTC-converted local instant.
  final DateTime? requestedDate;
}

final class SessionPlanningResult {
  const SessionPlanningResult(this.reasonCode, {this.sessionId, this.date});
  final String ruleVersion = 'session-planning-v1';
  final String reasonCode;
  final String? sessionId;
  final DateTime? date;
}

final class SessionPlanningPolicy {
  const SessionPlanningPolicy();

  SessionPlanningResult evaluate(SessionPlanningInput input) {
    const invalid = SessionPlanningResult('invalid_input');
    final sessions = input.orderedSessionIds;
    final weekdays = input.trainingWeekdays;
    final history = input.history;
    final date = input.requestedDate;
    if (sessions == null ||
        weekdays == null ||
        history == null ||
        date == null) {
      return const SessionPlanningResult('required_input_missing');
    }
    if (sessions.isEmpty ||
        sessions.any((id) => id.trim().isEmpty || id != id.trim()) ||
        sessions.toSet().length != sessions.length ||
        weekdays.any((day) => day < 1 || day > 7) ||
        weekdays.toSet().length != weekdays.length ||
        !date.isUtc ||
        date != DateTime.utc(date.year, date.month, date.day) ||
        date.year < 1 ||
        date.year > 9998) {
      return invalid;
    }
    final ordered = [...history]
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    final ids = <String>{};
    for (var i = 0; i < ordered.length; i++) {
      final entry = ordered[i];
      if (entry.id.trim().isEmpty ||
          !ids.add(entry.id) ||
          entry.sequence != i ||
          entry.sessionId != sessions[i % sessions.length] ||
          (entry.state == PlannedSessionState.active &&
              i != ordered.length - 1)) {
        return const SessionPlanningResult('invalid_history');
      }
    }
    if (ordered.isNotEmpty &&
        ordered.last.state == PlannedSessionState.active) {
      return SessionPlanningResult(
        'resume_session',
        sessionId: ordered.last.sessionId,
      );
    }
    final nextId = sessions[ordered.length % sessions.length];
    if (weekdays.isEmpty) {
      return SessionPlanningResult('schedule_required', sessionId: nextId);
    }
    for (var offset = 0; offset < 7; offset++) {
      final nextDate = date.add(Duration(days: offset));
      if (weekdays.contains(nextDate.weekday)) {
        return SessionPlanningResult(
          'next_session',
          sessionId: nextId,
          date: nextDate,
        );
      }
    }
    return invalid;
  }
}

enum DurationFit {
  withinPreference,
  exceedsPreference,
  estimateRequired,
  invalidInput,
}

/// Compares an explicit estimate; does not invent tempo or transition durations.
DurationFit compareSessionDuration({
  required int? preferredMinutes,
  required int? estimatedSeconds,
}) {
  if (preferredMinutes == null ||
      preferredMinutes <= 0 ||
      (estimatedSeconds != null && estimatedSeconds < 0)) {
    return DurationFit.invalidInput;
  }
  if (estimatedSeconds == null) return DurationFit.estimateRequired;
  return BigInt.from(estimatedSeconds) <=
          BigInt.from(preferredMinutes) * BigInt.from(60)
      ? DurationFit.withinPreference
      : DurationFit.exceedsPreference;
}
