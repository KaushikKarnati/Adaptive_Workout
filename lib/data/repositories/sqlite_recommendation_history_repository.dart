import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../domain/logging/practice_repository.dart';
import '../../domain/recommendations/recommendation_history.dart';

final class SqliteRecommendationHistoryRepository
    implements RecommendationHistoryRepository {
  SqliteRecommendationHistoryRepository._(this._db);
  final Database _db;
  static Future<SqliteRecommendationHistoryRepository> open({
    String path = 'recommendations.sqlite',
  }) async {
    final db = await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys=ON');
        await db.execute('PRAGMA synchronous=FULL');
        checkHistory(
          (await db.rawQuery('PRAGMA foreign_keys')).single.values.single == 1,
          'foreign_keys_required',
        );
      },
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE profiles(id TEXT PRIMARY KEY,revision INTEGER NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE recommendations(profile TEXT NOT NULL,id TEXT NOT NULL,payload TEXT NOT NULL,PRIMARY KEY(profile,id),FOREIGN KEY(profile) REFERENCES profiles(id))',
        );
        await db.execute(
          'CREATE TABLE occurrences(profile TEXT NOT NULL,id TEXT NOT NULL,recommendation TEXT NOT NULL,sequence INTEGER NOT NULL,revision INTEGER NOT NULL,active INTEGER NOT NULL,payload TEXT NOT NULL,PRIMARY KEY(profile,id),UNIQUE(profile,sequence),UNIQUE(profile,recommendation),FOREIGN KEY(profile,recommendation) REFERENCES recommendations(profile,id))',
        );
        await db.execute(
          'CREATE UNIQUE INDEX one_active_generated_session ON occurrences(profile) WHERE active=1',
        );
        await db.execute(
          'CREATE TABLE revisions(profile TEXT NOT NULL,id TEXT NOT NULL,revision INTEGER NOT NULL,payload TEXT NOT NULL,PRIMARY KEY(profile,id,revision),FOREIGN KEY(profile,id) REFERENCES occurrences(profile,id))',
        );
        await db.execute(
          'CREATE TABLE receipts(profile TEXT NOT NULL,action TEXT NOT NULL,request TEXT NOT NULL,PRIMARY KEY(profile,action),FOREIGN KEY(profile) REFERENCES profiles(id))',
        );
      },
      onUpgrade: (_, a, b) async =>
          throw const LoggingException('unsupported_schema'),
      onDowngrade: (_, a, b) async =>
          throw const LoggingException('unsupported_schema'),
    );
    return SqliteRecommendationHistoryRepository._(db);
  }

  Future<GeneratedHistory> _load(DatabaseExecutor db, String profile) async {
    validateStorageId(profile);
    final profiles = await db.query(
      'profiles',
      where: 'id=?',
      whereArgs: [profile],
    );
    final rows = await db.query(
      'recommendations',
      where: 'profile=?',
      whereArgs: [profile],
    );
    final plans = <RecommendationSnapshot>[];
    for (final row in rows) {
      final r = RecommendationSnapshot.decode(row['payload'] as String);
      checkHistory(
        r.id == row['id'] && r.profile == row['profile'],
        'stored_identity_mismatch',
      );
      plans.add(r);
    }
    final logs = await db.query(
      'occurrences',
      where: 'profile=?',
      whereArgs: [profile],
      orderBy: 'sequence',
    );
    final occurrences = <GeneratedOccurrence>[];
    for (final row in logs) {
      final s = GeneratedOccurrence.decode(row['payload'] as String);
      checkHistory(
        s.id == row['id'] &&
            s.profile == row['profile'] &&
            s.recommendationId == row['recommendation'] &&
            s.sequence == row['sequence'] &&
            s.revision == row['revision'] &&
            (s.status == OccurrenceStatus.active ? 1 : 0) == row['active'],
        'stored_identity_mismatch',
      );
      occurrences.add(s);
    }
    checkHistory(
      profiles.isNotEmpty || (plans.isEmpty && occurrences.isEmpty),
      'missing_profile',
    );
    final history = GeneratedHistory(
      profile: profile,
      revision: profiles.isEmpty ? 0 : profiles.single['revision'] as int,
      recommendations: plans,
      occurrences: occurrences,
    );
    for (final occurrence in occurrences) {
      final plan = plans.singleWhere(
        (r) => r.id == occurrence.recommendationId,
      );
      await _auditRows(db, occurrence, plan);
    }
    return history;
  }

  @override
  Future<GeneratedHistory> load(String profile) =>
      _db.transaction((txn) => _load(txn, profile));

  Future<bool> _retry(
    DatabaseExecutor db,
    String profile,
    String action,
    String request,
  ) async {
    validateStorageId(action);
    final rows = await db.query(
      'receipts',
      where: 'profile=? AND action=?',
      whereArgs: [profile, action],
    );
    if (rows.isEmpty) return false;
    checkHistory(rows.single['request'] == request, 'action_conflict');
    return true;
  }

  Future<void> _receipt(
    DatabaseExecutor db,
    String profile,
    String action,
    String request,
  ) => db
      .insert('receipts', {
        'profile': profile,
        'action': action,
        'request': request,
      })
      .then((_) {});

  @override
  Future<void> saveRecommendation(
    RecommendationSnapshot recommendation, {
    required String actionId,
  }) async {
    final r = RecommendationSnapshot.decode(recommendation.encode());
    final request = jsonEncode({
      'operation': 'recommendation',
      'payload': r.encode(),
    });
    await _db.transaction((txn) async {
      final history = await _load(txn, r.profile);
      if (await _retry(txn, r.profile, actionId, request)) return;
      checkHistory(!history.isStale(r), 'stale_history');
      checkHistory(
        !history.recommendations.any((o) => o.id == r.id),
        'immutable_recommendation',
      );
      for (final entry in r.evidence.entries) {
        checkHistory(
          history.occurrences.any(
            (s) => s.id == entry.key && s.revision == entry.value,
          ),
          'stale_or_missing_evidence',
        );
      }
      if (history.occurrences.isNotEmpty) {
        checkHistory(
          !r.createdAt.isBefore(
            history.occurrences
                .map((s) => s.updatedAt)
                .reduce((a, b) => a.isAfter(b) ? a : b),
          ),
          'invalid_generation_time',
        );
      }
      await txn.insert('profiles', {
        'id': r.profile,
        'revision': history.revision,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await txn.insert('recommendations', {
        'profile': r.profile,
        'id': r.id,
        'payload': r.encode(),
      });
      await _receipt(txn, r.profile, actionId, request);
    });
  }

  @override
  Future<void> saveOccurrence(
    GeneratedOccurrence occurrence, {
    required int expectedRevision,
    required int expectedHistoryRevision,
    required String actionId,
  }) async {
    final next = GeneratedOccurrence.decode(occurrence.encode());
    final request = jsonEncode({
      'operation': 'occurrence',
      'expectedRevision': expectedRevision,
      'expectedHistoryRevision': expectedHistoryRevision,
      'payload': next.encode(),
    });
    await _db.transaction((txn) async {
      final history = await _load(txn, next.profile);
      if (await _retry(txn, next.profile, actionId, request)) return;
      checkHistory(
        history.revision == expectedHistoryRevision,
        'stale_history',
      );
      final plans = history.recommendations.where(
        (r) => r.id == next.recommendationId,
      );
      checkHistory(plans.length == 1, 'missing_recommendation');
      final plan = plans.single;
      next.validateAgainst(plan);
      final old = history.occurrences.where((s) => s.id == next.id);
      if (old.isEmpty) {
        checkHistory(
          expectedRevision == -1 &&
              next.revision == 0 &&
              next.sequence == history.occurrences.length &&
              next.status == OccurrenceStatus.active &&
              next.sets.isEmpty &&
              next.stoppedSlots.isEmpty &&
              next.updatedAt == next.startedAt,
          'invalid_start',
        );
        checkHistory(!history.isStale(plan), 'stale_recommendation');
        checkHistory(
          !history.occurrences.any((s) => s.status == OccurrenceStatus.active),
          'active_session_exists',
        );
      } else {
        checkHistory(old.single.revision == expectedRevision, 'stale_revision');
        validateOccurrenceTransition(old.single, next, plan);
        await txn.insert('revisions', {
          'profile': next.profile,
          'id': next.id,
          'revision': old.single.revision,
          'payload': old.single.encode(),
        });
      }
      final values = {
        'profile': next.profile,
        'id': next.id,
        'recommendation': next.recommendationId,
        'sequence': next.sequence,
        'revision': next.revision,
        'active': next.status == OccurrenceStatus.active ? 1 : 0,
        'payload': next.encode(),
      };
      if (old.isEmpty) {
        await txn.insert('occurrences', values);
      } else {
        await txn.update(
          'occurrences',
          values,
          where: 'profile=? AND id=?',
          whereArgs: [next.profile, next.id],
        );
      }
      await txn.update(
        'profiles',
        {'revision': history.revision + 1},
        where: 'id=?',
        whereArgs: [next.profile],
      );
      // Validate the complete resulting envelope before committing any mutation.
      await _load(txn, next.profile);
      await _receipt(txn, next.profile, actionId, request);
    });
  }

  Future<List<GeneratedOccurrence>> _auditRows(
    DatabaseExecutor db,
    GeneratedOccurrence current,
    RecommendationSnapshot plan,
  ) async {
    final rows = await db.query(
      'revisions',
      where: 'profile=? AND id=?',
      whereArgs: [current.profile, current.id],
      orderBy: 'revision',
    );
    final result = <GeneratedOccurrence>[];
    for (final row in rows) {
      final old = GeneratedOccurrence.decode(row['payload'] as String);
      checkHistory(
        old.profile == current.profile &&
            old.id == current.id &&
            old.revision == row['revision'] &&
            old.revision == result.length,
        'invalid_audit',
      );
      old.validateAgainst(plan);
      result.add(old);
    }
    checkHistory(result.length == current.revision, 'incomplete_audit');
    result.add(current);
    final first = result.first;
    checkHistory(
      first.status == OccurrenceStatus.active &&
          first.sets.isEmpty &&
          first.stoppedSlots.isEmpty &&
          first.updatedAt == first.startedAt,
      'invalid_audit_origin',
    );
    for (var i = 1; i < result.length; i++) {
      validateOccurrenceTransition(result[i - 1], result[i], plan);
    }
    return List.unmodifiable(result);
  }

  @override
  Future<List<GeneratedOccurrence>> audit(
    String profile,
    String occurrenceId,
  ) async {
    validateStorageId(profile);
    validateStorageId(occurrenceId);
    return _db.transaction((txn) async {
      final history = await _load(txn, profile);
      final current = history.occurrences.where((s) => s.id == occurrenceId);
      if (current.isEmpty) return [];
      return _auditRows(
        txn,
        current.single,
        history.recommendations.singleWhere(
          (r) => r.id == current.single.recommendationId,
        ),
      );
    });
  }

  @override
  Future<void> close() => _db.close();
}
