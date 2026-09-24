import 'dart:convert';

import 'package:adaptive_workout/domain/logging/program_log.dart';

class FakeProgramLogRepository implements ProgramLogRepository {
  final logs = <String, ProgramLog>{};
  final actions = <String, String>{};
  final deleted = <String, String>{};
  bool failWrite = false, failRead = false;
  int writes = 0;
  @override
  Future<List<ProgramLog>> load(String profile) async {
    if (failRead) {
      failRead = false;
      throw StateError('read');
    }
    return logs.values.where((l) => l.profile == profile).toList();
  }

  @override
  Future<void> write(
    ProgramLog log, {
    required int expectedRevision,
    required String actionId,
  }) async {
    if (failWrite) throw StateError('write');
    if (deleted.containsKey('${log.profile}_${log.id}')) {
      throw StateError('deleted');
    }
    final key = '${log.profile}_$actionId', payload = jsonEncode(log.toJson());
    if (actions.containsKey(key)) {
      if (actions[key] != payload) throw StateError('conflict');
      return;
    }
    if ((logs[log.id]?.revision ?? -1) != expectedRevision) {
      throw StateError('stale');
    }
    logs[log.id] = log;
    actions[key] = payload;
    writes++;
  }

  @override
  Future<void> delete(
    String profile,
    String id, {
    required int expectedRevision,
    required String actionId,
  }) async {
    if (failWrite) throw StateError('delete');
    final key = '${profile}_$id', request = '$expectedRevision/$actionId';
    if (deleted.containsKey(key)) {
      if (deleted[key] != request) throw StateError('conflict');
      return;
    }
    final log = logs[id];
    if (log == null ||
        log.profile != profile ||
        log.revision != expectedRevision) {
      throw StateError('stale');
    }
    logs.remove(id);
    actions.removeWhere((key, value) {
      final j = jsonDecode(value) as Map<String, dynamic>;
      return j['profile'] == profile && j['id'] == id;
    });
    deleted[key] = request;
  }

  @override
  Future<void> close() async {}
}
