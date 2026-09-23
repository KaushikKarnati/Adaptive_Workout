import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../domain/logging/practice_repository.dart';

final class SqlitePracticeRepository implements PracticeRepository {
  SqlitePracticeRepository._(this._db);
  final Database _db;

  static Future<SqlitePracticeRepository> open({String? path}) async {
    final db = await openDatabase(
      path ?? 'adaptive_workout.sqlite',
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.execute('PRAGMA synchronous = FULL');
        final enabled = await db.rawQuery('PRAGMA foreign_keys');
        if (enabled.single.values.single != 1) {
          throw const LoggingException('foreign_keys_required');
        }
      },
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE profiles (id TEXT PRIMARY KEY NOT NULL)',
        );
        await db.execute(
          '''CREATE TABLE sessions (
          id TEXT NOT NULL, profile_id TEXT NOT NULL, started_at TEXT NOT NULL,
          completed_at TEXT, revision INTEGER NOT NULL DEFAULT 0 CHECK(revision >= 0),
          practice INTEGER NOT NULL DEFAULT 1 CHECK(practice = 1),
          PRIMARY KEY(profile_id, id), FOREIGN KEY(profile_id) REFERENCES profiles(id))''',
        );
        await db.execute(
          'CREATE UNIQUE INDEX one_draft ON sessions(profile_id) WHERE completed_at IS NULL',
        );
        await db.execute(
          '''CREATE TABLE session_exercises (
          profile_id TEXT NOT NULL, session_id TEXT NOT NULL, exercise_id TEXT NOT NULL,
          ordinal INTEGER NOT NULL, target_json TEXT,
          PRIMARY KEY(profile_id, session_id, exercise_id),
          FOREIGN KEY(profile_id, session_id) REFERENCES sessions(profile_id, id))''',
        );
        await db.execute(
          '''CREATE TABLE set_records (
          profile_id TEXT NOT NULL, session_id TEXT NOT NULL, id TEXT NOT NULL,
          exercise_id TEXT NOT NULL, set_index INTEGER NOT NULL CHECK(set_index > 0),
          payload TEXT NOT NULL,
          PRIMARY KEY(profile_id, session_id, id),
          UNIQUE(profile_id, session_id, exercise_id, set_index),
          FOREIGN KEY(profile_id, session_id, exercise_id)
          REFERENCES session_exercises(profile_id, session_id, exercise_id))''',
        );
        await db.execute(
          '''CREATE TABLE set_revisions (
          profile_id TEXT NOT NULL, session_id TEXT NOT NULL, set_id TEXT NOT NULL,
          revision INTEGER NOT NULL, prior_payload TEXT NOT NULL, changed_at TEXT NOT NULL,
          PRIMARY KEY(profile_id, session_id, set_id, revision),
          FOREIGN KEY(profile_id, session_id, set_id) REFERENCES set_records(profile_id, session_id, id))''',
        );
        await db.execute(
          '''CREATE TABLE actions (
          profile_id TEXT NOT NULL, id TEXT NOT NULL, session_id TEXT NOT NULL,
          payload TEXT NOT NULL, resulting_revision INTEGER NOT NULL,
          PRIMARY KEY(profile_id, id),
          FOREIGN KEY(profile_id, session_id) REFERENCES sessions(profile_id, id))''',
        );
      },
      onUpgrade: (_, _, _) =>
          throw const LoggingException('unsupported_schema'),
      onDowngrade: (_, _, _) =>
          throw const LoggingException('unsupported_schema'),
    );
    return SqlitePracticeRepository._(db);
  }

  void _validate(
    String profileId,
    String sessionId,
    String actionId,
    DateTime at,
  ) {
    for (final id in [profileId, sessionId, actionId]) {
      validateStorageId(id);
    }
    if (!at.isUtc) throw const LoggingException('utc_required');
  }

  Future<bool> _replayed(
    Transaction txn,
    String profileId,
    String actionId,
    String payload,
  ) async {
    final rows = await txn.query(
      'actions',
      where: 'profile_id = ? AND id = ?',
      whereArgs: [profileId, actionId],
    );
    if (rows.isEmpty) return false;
    if (rows.single['payload'] != payload) {
      throw const LoggingException('action_conflict');
    }
    return true;
  }

  Future<Map<String, Object?>> _session(
    Transaction txn,
    String profileId,
    String sessionId,
  ) async {
    final rows = await txn.query(
      'sessions',
      where: 'profile_id = ? AND id = ?',
      whereArgs: [profileId, sessionId],
    );
    if (rows.length != 1) throw const LoggingException('session_not_found');
    return rows.single;
  }

  Future<void> _receipt(
    Transaction txn,
    String profileId,
    String sessionId,
    String actionId,
    String payload,
    int revision,
  ) => txn
      .insert('actions', {
        'profile_id': profileId,
        'session_id': sessionId,
        'id': actionId,
        'payload': payload,
        'resulting_revision': revision,
      })
      .then((_) {});

  @override
  Future<void> start({
    required String profileId,
    required String sessionId,
    required String actionId,
    required DateTime at,
  }) async {
    _validate(profileId, sessionId, actionId, at);
    final payload = jsonEncode(['start', sessionId, at.toIso8601String()]);
    await _db.transaction((txn) async {
      if (await _replayed(txn, profileId, actionId, payload)) return;
      await txn.insert('profiles', {
        'id': profileId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await txn.insert('sessions', {
        'id': sessionId,
        'profile_id': profileId,
        'started_at': at.toIso8601String(),
      });
      for (final (index, id) in practiceExercises.keys.indexed) {
        await txn.insert('session_exercises', {
          'profile_id': profileId,
          'session_id': sessionId,
          'exercise_id': id,
          'ordinal': index,
        });
      }
      await _receipt(txn, profileId, sessionId, actionId, payload, 0);
    });
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
    _validate(profileId, sessionId, actionId, at);
    record.validate();
    if (expectedRevision < 0) throw const LoggingException('invalid_revision');
    final recordJson = jsonEncode(record.toJson());
    final payload = jsonEncode([
      'set',
      sessionId,
      expectedRevision,
      record.toJson(),
      correction,
      at.toIso8601String(),
    ]);
    await _db.transaction((txn) async {
      if (await _replayed(txn, profileId, actionId, payload)) return;
      final session = await _session(txn, profileId, sessionId);
      if (session['revision'] != expectedRevision) {
        throw const LoggingException('stale_revision');
      }
      if (at.isBefore(DateTime.parse(session['started_at'] as String))) {
        throw const LoggingException('invalid_action_time');
      }
      if (session['completed_at'] != null && !correction) {
        throw const LoggingException('session_completed');
      }
      final previous = await txn.query(
        'set_records',
        where: 'profile_id = ? AND session_id = ? AND id = ?',
        whereArgs: [profileId, sessionId, record.id],
      );
      if (correction) {
        if (previous.length != 1 ||
            previous.single['exercise_id'] != record.exerciseId ||
            previous.single['set_index'] != record.index) {
          throw const LoggingException('correction_target_mismatch');
        }
        await txn.insert('set_revisions', {
          'profile_id': profileId,
          'session_id': sessionId,
          'set_id': record.id,
          'revision': expectedRevision + 1,
          'prior_payload': previous.single['payload'],
          'changed_at': at.toIso8601String(),
        });
        await txn.update(
          'set_records',
          {'payload': recordJson},
          where: 'profile_id = ? AND session_id = ? AND id = ?',
          whereArgs: [profileId, sessionId, record.id],
        );
      } else {
        await txn.insert('set_records', {
          'profile_id': profileId,
          'session_id': sessionId,
          'id': record.id,
          'exercise_id': record.exerciseId,
          'set_index': record.index,
          'payload': recordJson,
        });
      }
      await txn.update(
        'sessions',
        {'revision': expectedRevision + 1},
        where: 'profile_id = ? AND id = ?',
        whereArgs: [profileId, sessionId],
      );
      await _receipt(
        txn,
        profileId,
        sessionId,
        actionId,
        payload,
        expectedRevision + 1,
      );
    });
  }

  @override
  Future<void> complete({
    required String profileId,
    required String sessionId,
    required String actionId,
    required int expectedRevision,
    required DateTime at,
  }) async {
    _validate(profileId, sessionId, actionId, at);
    if (expectedRevision < 0) throw const LoggingException('invalid_revision');
    final payload = jsonEncode([
      'complete',
      sessionId,
      expectedRevision,
      at.toIso8601String(),
    ]);
    await _db.transaction((txn) async {
      if (await _replayed(txn, profileId, actionId, payload)) return;
      final session = await _session(txn, profileId, sessionId);
      if (session['completed_at'] != null) {
        await _receipt(
          txn,
          profileId,
          sessionId,
          actionId,
          payload,
          session['revision'] as int,
        );
        return;
      }
      if (session['revision'] != expectedRevision) {
        throw const LoggingException('stale_revision');
      }
      if (at.isBefore(DateTime.parse(session['started_at'] as String))) {
        throw const LoggingException('invalid_action_time');
      }
      await txn.update(
        'sessions',
        {
          'completed_at': at.toIso8601String(),
          'revision': expectedRevision + 1,
        },
        where: 'profile_id = ? AND id = ?',
        whereArgs: [profileId, sessionId],
      );
      await _receipt(
        txn,
        profileId,
        sessionId,
        actionId,
        payload,
        expectedRevision + 1,
      );
    });
  }

  @override
  Future<List<PracticeSession>> load(String profileId) async {
    validateStorageId(profileId);
    return _db.transaction((txn) async {
      final rows = await txn.query(
        'sessions',
        where: 'profile_id = ?',
        whereArgs: [profileId],
        orderBy: 'started_at DESC, id DESC',
      );
      final sessions = <PracticeSession>[];
      for (final row in rows) {
        final setRows = await txn.query(
          'set_records',
          where: 'profile_id = ? AND session_id = ?',
          whereArgs: [profileId, row['id']],
          orderBy: 'exercise_id, set_index',
        );
        sessions.add(
          PracticeSession(
            id: row['id'] as String,
            profileId: profileId,
            startedAt: DateTime.parse(row['started_at'] as String),
            completedAt: row['completed_at'] == null
                ? null
                : DateTime.parse(row['completed_at'] as String),
            revision: row['revision'] as int,
            sets: [
              for (final item in setRows)
                PracticeSet.fromJson(
                  jsonDecode(item['payload'] as String) as Map<String, dynamic>,
                ),
            ],
          ),
        );
      }
      return List.unmodifiable(sessions);
    });
  }

  @override
  Future<void> close() => _db.close();
}
