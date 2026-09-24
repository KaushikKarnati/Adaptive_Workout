import '../domain/logging/program_log.dart';
import '../domain/recommendations/recommendation_history.dart';
import '../domain/workout/session_planning_policy.dart';

/// Immutable retry payload. Keep this action after an uncertain write; do not
/// rebuild it from a newer history revision under the same action ID.
final class SavedWorkoutAction {
  const SavedWorkoutAction._(
    this.occurrence,
    this.historyRevision,
    this.actionId,
  );
  final GeneratedOccurrence occurrence;
  final int historyRevision;
  final String actionId;
}

final class SavedWorkout {
  const SavedWorkout(this.occurrence, this.prescription);
  final GeneratedOccurrence occurrence;
  final RecommendationSnapshot prescription;
}

/// Coordinates saved occurrences only. This is not authorization to generate or
/// execute an exercise: fresh safety and rehearsal checks remain caller gates.
final class SavedWorkoutService {
  const SavedWorkoutService(this.repository);
  final RecommendationHistoryRepository repository;

  Future<SavedWorkout?> resume(String profile) async {
    final history = await repository.load(profile);
    final active = history.occurrences.where(
      (s) => s.status == OccurrenceStatus.active,
    );
    if (active.isEmpty) return null;
    return _saved(history, active.single.id);
  }

  SavedWorkout _saved(GeneratedHistory history, String id) {
    final matches = history.occurrences.where((s) => s.id == id);
    checkHistory(matches.length == 1, 'missing_occurrence');
    final occurrence = matches.single;
    return SavedWorkout(
      occurrence,
      history.recommendations.singleWhere(
        (r) => r.id == occurrence.recommendationId,
      ),
    );
  }

  Future<SavedWorkoutAction> prepareSet({
    required String profile,
    required String occurrenceId,
    required ProgramSet set,
    required DateTime at,
    required String actionId,
  }) async {
    final history = await repository.load(profile);
    final saved = _saved(history, occurrenceId);
    return SavedWorkoutAction._(
      saved.occurrence.record(set, at, saved.prescription),
      history.revision,
      actionId,
    );
  }

  Future<SavedWorkoutAction> prepareFinish({
    required String profile,
    required String occurrenceId,
    required bool endEarly,
    required DateTime at,
    required String actionId,
  }) async {
    final history = await repository.load(profile);
    final saved = _saved(history, occurrenceId);
    return SavedWorkoutAction._(
      saved.occurrence.finish(
        at,
        endEarly ? OccurrenceStatus.endedEarly : OccurrenceStatus.completed,
        saved.prescription,
      ),
      history.revision,
      actionId,
    );
  }

  /// Acknowledges only after commit and a validated read. Repository receipts
  /// make retrying this exact action safe even after a lost acknowledgement.
  Future<SavedWorkout> commit(SavedWorkoutAction action) async {
    await repository.saveOccurrence(
      action.occurrence,
      expectedRevision: action.occurrence.revision - 1,
      expectedHistoryRevision: action.historyRevision,
      actionId: action.actionId,
    );
    return _saved(
      await repository.load(action.occurrence.profile),
      action.occurrence.id,
    );
  }

  /// Queue position derives from terminal records, so a terminal transaction
  /// advances it exactly once without a second cursor write. The adapter must
  /// convert endedAt using the user's explicit calendar/timezone context.
  Future<SessionPlanningResult> nextSession({
    required String profile,
    required String programId,
    required List<String> orderedSessionIds,
    required List<int> trainingWeekdays,
    required DateTime requestedDate,
    required DateTime Function(DateTime endedAt) civilDateOfEnd,
  }) async {
    final history = await repository.load(profile);
    final all = history.occurrences.toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    // Do not hide an active workout from another program by filtering it out.
    if (all.isNotEmpty && all.last.status == OccurrenceStatus.active) {
      final active = _saved(history, all.last.id);
      if (active.prescription.programId != programId) {
        return const SessionPlanningResult('other_program_active');
      }
    }
    final scoped = all
        .where((s) => _saved(history, s.id).prescription.programId == programId)
        .toList();
    var earliest = requestedDate;
    // Validate the caller's civil date before applying any date arithmetic.
    final validation = const SessionPlanningPolicy().evaluate(
      SessionPlanningInput(
        orderedSessionIds: orderedSessionIds,
        trainingWeekdays: trainingWeekdays,
        history: [],
        requestedDate: earliest,
      ),
    );
    if (validation.reasonCode == 'invalid_input') return validation;
    if (all.isNotEmpty && all.last.endedAt != null) {
      final endDate = civilDateOfEnd(all.last.endedAt!);
      checkHistory(
        endDate.isUtc &&
            endDate.year >= 1 &&
            endDate.year <= 9998 &&
            endDate == DateTime.utc(endDate.year, endDate.month, endDate.day),
        'invalid_civil_date',
      );
      if (!earliest.isAfter(endDate)) {
        earliest = endDate.add(const Duration(days: 1));
      }
    }
    return const SessionPlanningPolicy().evaluate(
      SessionPlanningInput(
        orderedSessionIds: orderedSessionIds,
        trainingWeekdays: trainingWeekdays,
        requestedDate: earliest,
        history: [
          for (var i = 0; i < scoped.length; i++)
            SessionSequenceEntry(
              id: scoped[i].id,
              sequence: i,
              sessionId: _saved(
                history,
                scoped[i].id,
              ).prescription.sessionTemplate,
              state: switch (scoped[i].status) {
                OccurrenceStatus.active => PlannedSessionState.active,
                OccurrenceStatus.completed => PlannedSessionState.completed,
                OccurrenceStatus.endedEarly => PlannedSessionState.endedEarly,
              },
            ),
        ],
      ),
    );
  }
}
