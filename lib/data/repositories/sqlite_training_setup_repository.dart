import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../domain/training/training_setup.dart';

final class SqliteTrainingSetupRepository implements TrainingSetupRepository {
  SqliteTrainingSetupRepository._(this._db);
  final Database _db;
  static Future<SqliteTrainingSetupRepository> open({
    String path = 'training_setup.sqlite',
  }) async {
    final db = await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys=ON');
        await db.execute('PRAGMA synchronous=FULL');
        requireSetup(
          (await db.rawQuery('PRAGMA foreign_keys')).single.values.single == 1,
          'foreign_keys_required',
        );
      },
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE profiles(id TEXT PRIMARY KEY,revision INTEGER NOT NULL,payload TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE revisions(profile TEXT NOT NULL,revision INTEGER NOT NULL,payload TEXT NOT NULL,PRIMARY KEY(profile,revision),FOREIGN KEY(profile) REFERENCES profiles(id))',
        );
        await db.execute(
          'CREATE TABLE receipts(profile TEXT NOT NULL,action TEXT NOT NULL,request TEXT NOT NULL,PRIMARY KEY(profile,action),FOREIGN KEY(profile) REFERENCES profiles(id))',
        );
      },
      onUpgrade: (_, old, next) async =>
          throw const SetupException('unsupported_schema'),
      onDowngrade: (_, old, next) async =>
          throw const SetupException('unsupported_schema'),
    );
    return SqliteTrainingSetupRepository._(db);
  }

  TrainingSetup _read(Map<String, Object?> row) {
    final result = TrainingSetup.decode(row['payload'] as String);
    requireSetup(
      result.profileId == row['id'] &&
          result.revision == row['revision'] &&
          result.encode() == row['payload'],
      'stored_identity_mismatch',
    );
    return result;
  }

  @override
  Future<TrainingSetup?> load(String profileId) async {
    validateSetupId(profileId);
    final rows = await _db.query(
      'profiles',
      where: 'id=?',
      whereArgs: [profileId],
    );
    return rows.isEmpty ? null : _read(rows.single);
  }

  @override
  Future<void> save(
    TrainingSetup setup, {
    required int expectedRevision,
    required String actionId,
  }) async {
    validateSetupId(actionId);
    final payload = setup.encode();
    TrainingSetup.decode(payload);
    requireSetup(
      expectedRevision >= -1 && setup.revision == expectedRevision + 1,
      'invalid_revision',
    );
    final request = jsonEncode({
      'expectedRevision': expectedRevision,
      'payload': payload,
    });
    await _db.transaction((txn) async {
      final rows = await txn.query(
        'profiles',
        where: 'id=?',
        whereArgs: [setup.profileId],
      );
      final old = rows.isEmpty ? null : _read(rows.single);
      final receipts = await txn.query(
        'receipts',
        where: 'profile=? AND action=?',
        whereArgs: [setup.profileId, actionId],
      );
      if (receipts.isNotEmpty) {
        requireSetup(
          receipts.single['request'] == request && old != null,
          'action_conflict',
        );
        return;
      }
      requireSetup((old?.revision ?? -1) == expectedRevision, 'stale_revision');
      validateSetupTransition(old, setup);
      if (old == null) {
        await txn.insert('profiles', {
          'id': setup.profileId,
          'revision': setup.revision,
          'payload': payload,
        });
      } else {
        await txn.insert('revisions', {
          'profile': old.profileId,
          'revision': old.revision,
          'payload': old.encode(),
        });
        await txn.update(
          'profiles',
          {'revision': setup.revision, 'payload': payload},
          where: 'id=?',
          whereArgs: [setup.profileId],
        );
      }
      await txn.insert('receipts', {
        'profile': setup.profileId,
        'action': actionId,
        'request': request,
      });
    });
  }

  @override
  Future<void> close() => _db.close();
}
