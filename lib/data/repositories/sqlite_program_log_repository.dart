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
        throw const LoggingException('unsupported_schema');
      },
      onDowngrade: (db, old, next) async {
        throw const LoggingException('unsupported_schema');
      },
    );
    return SqliteProgramLogRepository._(db);
  }

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
            old.startedAt != log.startedAt) {
          throw const LoggingException('stale_or_invalid_revision');
        }
        ProgramLog? expected;
        if (!old.completed &&
            log.completed &&
            log.sets.length == old.sets.length) {
          expected = old.finish(log.completedAt!);
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
  Future<void> close() => _db.close();
}
