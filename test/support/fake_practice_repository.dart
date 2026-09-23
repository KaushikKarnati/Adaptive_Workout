import 'dart:async';

import 'package:adaptive_workout/domain/logging/practice_repository.dart';

class FakePracticeRepository implements PracticeRepository {
  final List<PracticeSession> sessions = [];
  final Set<String> accepted = {};
  int saveAttempts = 0;
  bool failSave = false, failLoad = false;
  Completer<void>? pause;
  @override
  Future<List<PracticeSession>> load(String profileId) async {
    if (failLoad) throw StateError('fixture read failure');
    return sessions.where((s) => s.profileId == profileId).toList();
  }

  @override
  Future<void> start({
    required String profileId,
    required String sessionId,
    required String actionId,
    required DateTime at,
  }) async {
    if (!accepted.add(actionId)) return;
    sessions.add(
      PracticeSession(
        id: sessionId,
        profileId: profileId,
        startedAt: at,
        completedAt: null,
        revision: 0,
        sets: [],
      ),
    );
  }

  @override
  Future<void> saveSet({
    required String profileId,
    required String sessionId,
    required String actionId,
    required int expectedRevision,
    required PracticeSet record,
    required bool correction,
    required DateTime at,
  }) async {
    saveAttempts++;
    if (pause != null) await pause!.future;
    if (failSave) throw StateError('fixture write failure');
    if (!accepted.add(actionId)) return;
    final i = sessions.indexWhere(
      (s) => s.id == sessionId && s.profileId == profileId,
    );
    final previous = sessions[i];
    sessions[i] = PracticeSession(
      id: previous.id,
      profileId: profileId,
      startedAt: previous.startedAt,
      completedAt: previous.completedAt,
      revision: previous.revision + 1,
      sets: [...previous.sets.where((s) => s.id != record.id), record],
    );
  }

  @override
  Future<void> complete({
    required String profileId,
    required String sessionId,
    required String actionId,
    required int expectedRevision,
    required DateTime at,
  }) async {
    if (failSave) throw StateError('fixture write failure');
    if (!accepted.add(actionId)) return;
    final i = sessions.indexWhere(
      (s) => s.id == sessionId && s.profileId == profileId,
    );
    final previous = sessions[i];
    sessions[i] = PracticeSession(
      id: previous.id,
      profileId: profileId,
      startedAt: previous.startedAt,
      completedAt: at,
      revision: previous.revision + 1,
      sets: previous.sets,
    );
  }

  @override
  Future<void> close() async {}
}
