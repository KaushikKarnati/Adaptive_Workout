import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../domain/logging/practice_repository.dart';
import '../../domain/logging/program_log.dart';

class SqliteProgramLogRepository implements ProgramLogRepository {
  SqliteProgramLogRepository._(this._db);
  final Database _db;
  static Future<SqliteProgramLogRepository> open({
    String path = 'program_logging.sqlite',
  }) async {
    final db = await openDatabase(
      path,
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.execute('PRAGMA synchronous = FULL');
        final enabled = await db.rawQuery('PRAGMA foreign_keys');
        if (enabled.single.values.single != 1) {
          throw const LoggingException('foreign_keys_required');
        }
      },
      onCreate: (db, version) async {
        await _createDeletions(db);
        await db.execute(
          'CREATE TABLE logs(profile TEXT NOT NULL,id TEXT NOT NULL,revision INTEGER NOT NULL,completed INTEGER NOT NULL,payload TEXT NOT NULL,prescription TEXT NOT NULL,PRIMARY KEY(profile,id))',
        );
        await db.execute(
          'CREATE UNIQUE INDEX one_program_draft ON logs(profile) WHERE completed=0',
        );
        await db.execute(
          'CREATE TABLE receipts(profile TEXT NOT NULL,action TEXT NOT NULL,payload TEXT NOT NULL,PRIMARY KEY(profile,action))',
        );
        await db.execute(
          'CREATE TABLE revisions(profile TEXT NOT NULL,id TEXT NOT NULL,revision INTEGER NOT NULL,payload TEXT NOT NULL,PRIMARY KEY(profile,id,revision),FOREIGN KEY(profile,id) REFERENCES logs(profile,id))',
        );
      },
      onUpgrade: (db, old, next) async {
        if (old != 1 || next != 2) {
          throw const LoggingException('unsupported_schema');
        }
        await _createDeletions(db);
      },
      onDowngrade: (db, old, next) async {
        throw const LoggingException('unsupported_schema');
      },
    );
    return SqliteProgramLogRepository._(db);
  }

  static Future<void> _createDeletions(DatabaseExecutor db) => db.execute(
    'CREATE TABLE deletions(profile TEXT NOT NULL,id TEXT NOT NULL,action TEXT NOT NULL,revision INTEGER NOT NULL,PRIMARY KEY(profile,id),UNIQUE(profile,action))',
  );

  String _prescription(ProgramLog log) => jsonEncode({
    'id': log.plan.id,
    'day': log.plan.day,
    'title': log.plan.title,
    'blocks': log.plan.blocks
        .map(
          (b) => {
            'rest': b.restSeconds,
            'exercises': b.exercises
                .map(
                  (e) => {
                    'id': e.id,
                    'name': e.name,
                    'sets': e.sets,
                    'minReps': e.minReps,
                    'maxReps': e.maxReps,
                    'minRir': e.minRir,
                    'maxRir': e.maxRir,
                    'eachSide': e.eachSide,
                    'alternatives': e.alternatives,
                  },
                )
                .toList(),
          },
        )
        .toList(),
  });

  @override
  Future<List<ProgramLog>> load(String profile) async {
    validateStorageId(profile);
    final rows = await _db.query(
      'logs',
      where: 'profile=?',
      whereArgs: [profile],
    );
    final logs = rows
        .map(
          (r) => ProgramLog.fromJson(
            jsonDecode(r['payload'] as String) as Map<String, dynamic>,
          ),
        )
        .toList();
    if (logs.any((l) => l.profile != profile)) {
      throw const LoggingException('profile_mismatch');
    }
    for (var i = 0; i < logs.length; i++) {
      if (rows[i]['prescription'] != _prescription(logs[i])) {
        throw const LoggingException('unsupported_prescription');
      }
    }
    logs.sort((a, b) {
      final c = b.startedAt.compareTo(a.startedAt);
      return c == 0 ? b.id.compareTo(a.id) : c;
    });
    return logs;
  }

  @override
  Future<void> write(
    ProgramLog log, {
    required int expectedRevision,
    required String actionId,
  }) async {
    validateStorageId(actionId);
    ProgramLog.fromJson(log.toJson());
    final payload = jsonEncode(log.toJson());
    final receipt = jsonEncode({
      'expected': expectedRevision,
      'payload': payload,
    });
    await _db.transaction((txn) async {
      final deleted = await txn.query(
        'deletions',
        where: 'profile=? AND (id=? OR action=?)',
        whereArgs: [log.profile, log.id, actionId],
      );
      if (deleted.isNotEmpty) throw const LoggingException('deleted_workout');
      final receipts = await txn.query(
        'receipts',
        where: 'profile=? AND action=?',
        whereArgs: [log.profile, actionId],
      );
      if (receipts.isNotEmpty) {
        if (receipts.single['payload'] != receipt) {
          throw const LoggingException('action_conflict');
        }
        return;
      }
      final rows = await txn.query(
        'logs',
        where: 'profile=? AND id=?',
        whereArgs: [log.profile, log.id],
      );
      if (rows.isEmpty) {
        if (expectedRevision != -1 ||
            log.revision != 0 ||
            log.sets.isNotEmpty ||
            log.completed) {
          throw const LoggingException('invalid_start');
        }
        await txn.insert('logs', {
          'profile': log.profile,
          'id': log.id,
          'revision': 0,
          'completed': 0,
          'payload': payload,
          'prescription': _prescription(log),
        });
      } else {
        final old = ProgramLog.fromJson(
          jsonDecode(rows.single['payload'] as String) as Map<String, dynamic>,
        );
        if (old.revision != expectedRevision ||
            log.revision != expectedRevision + 1 ||
            old.programId != log.programId ||
            old.programVersion != log.programVersion ||
            old.startedAt != log.startedAt) {
          throw const LoggingException('stale_or_invalid_revision');
        }
        ProgramLog? expected;
        if (!old.completed &&
            log.completed &&
            log.sets.length == old.sets.length) {
          expected = old.finish(log.completedAt!, endEarly: log.endedEarly);
        } else {
          final changed = log.sets
              .where(
                (s) => !old.sets.any(
                  (o) => jsonEncode(o.toJson()) == jsonEncode(s.toJson()),
                ),
              )
              .toList();
          if (changed.length == 1) expected = old.record(changed.single);
          if (changed.isEmpty && log.sets.isNotEmpty) {
            expected = old.record(log.sets.last);
          }
        }
        if (expected == null || jsonEncode(expected.toJson()) != payload) {
          throw const LoggingException('invalid_transition');
        }
        await txn.insert('revisions', {
          'profile': log.profile,
          'id': log.id,
          'revision': old.revision,
          'payload': rows.single['payload'],
        });
        await txn.update(
          'logs',
          {
            'revision': log.revision,
            'completed': log.completed ? 1 : 0,
            'payload': payload,
          },
          where: 'profile=? AND id=?',
          whereArgs: [log.profile, log.id],
        );
      }
      await txn.insert('receipts', {
        'profile': log.profile,
        'action': actionId,
        'payload': receipt,
      });
    });
  }

  @override
  Future<void> delete(
    String profile,
    String id, {
    required int expectedRevision,
    required String actionId,
  }) async {
    validateStorageId(profile);
    validateStorageId(id);
    validateStorageId(actionId);
    if (expectedRevision < 0) throw const LoggingException('invalid_revision');
    await _db.transaction((txn) async {
      final deleted = await txn.query(
        'deletions',
        where: 'profile=? AND (id=? OR action=?)',
        whereArgs: [profile, id, actionId],
      );
      if (deleted.isNotEmpty) {
        if (deleted.length == 1 &&
            deleted.single['id'] == id &&
            deleted.single['action'] == actionId &&
            deleted.single['revision'] == expectedRevision) {
          return;
        }
        throw const LoggingException('action_conflict');
      }
      final receipts = await txn.query(
        'receipts',
        where: 'profile=?',
        whereArgs: [profile],
      );
      if (receipts.any((r) => r['action'] == actionId)) {
        throw const LoggingException('action_conflict');
      }
      final rows = await txn.query(
        'logs',
        where: 'profile=? AND id=?',
        whereArgs: [profile, id],
      );
      if (rows.length != 1 || rows.single['revision'] != expectedRevision) {
        throw const LoggingException('stale_or_missing_workout');
      }
      // Legacy receipts contain full actual payloads; remove them as well as
      // revisions. Decode within the transaction so malformed data rolls back.
      for (final receipt in receipts) {
        final request =
            jsonDecode(receipt['payload'] as String) as Map<String, dynamic>;
        final log =
            jsonDecode(request['payload'] as String) as Map<String, dynamic>;
        if (log['profile'] != profile || log['id'] is! String) {
          throw const LoggingException('invalid_receipt');
        }
        if (log['id'] == id) {
          await txn.delete(
            'receipts',
            where: 'profile=? AND action=?',
            whereArgs: [profile, receipt['action']],
          );
        }
      }
      await txn.delete(
        'revisions',
        where: 'profile=? AND id=?',
        whereArgs: [profile, id],
      );
      await txn.delete(
        'logs',
        where: 'profile=? AND id=?',
        whereArgs: [profile, id],
      );
      // Only opaque IDs and revision remain, preventing an old start retry from
      // recreating the deleted workout. No prescription or actuals are retained.
      await txn.insert('deletions', {
        'profile': profile,
        'id': id,
        'action': actionId,
        'revision': expectedRevision,
      });
    });
  }

  @override
  Future<void> close() => _db.close();
}
