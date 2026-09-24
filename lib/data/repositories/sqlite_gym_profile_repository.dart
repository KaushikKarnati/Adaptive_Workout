import 'package:sqflite/sqflite.dart';

import '../../domain/gyms/gym_profile.dart';

final class SqliteGymProfileRepository implements GymProfileRepository {
  SqliteGymProfileRepository({this.path = 'gym_profiles.sqlite'});
  final String path;
  Database? _db;
  Future<Database> _open() async => _db ??= await openDatabase(
    path,
    version: 1,
    onCreate: (db, _) => db.execute(
      'CREATE TABLE gym_profiles (id INTEGER PRIMARY KEY CHECK(id=1), payload TEXT NOT NULL)',
    ),
    onUpgrade: (_, old, next) async =>
        throw StateError('Unsupported gym schema'),
    onDowngrade: (_, old, next) async =>
        throw StateError('Unsupported gym schema'),
  );
  Future<GymProfiles> _read(DatabaseExecutor db) async {
    final rows = await db.query('gym_profiles', where: 'id=?', whereArgs: [1]);
    return rows.isEmpty
        ? GymProfiles(profiles: [])
        : GymProfiles.decode(rows.single['payload'] as String);
  }

  @override
  Future<GymProfiles> load() async => _read(await _open());
  @override
  Future<void> save(GymProfiles next, {required GymProfiles expected}) async {
    final payload = GymProfiles.decode(next.encode()).encode();
    await (await _open()).transaction((txn) async {
      final current = (await _read(txn)).encode();
      if (current == payload) {
        return; // Safe retry after an uncertain acknowledgement.
      }
      if (current != expected.encode()) throw StateError('Gym profile changed');
      await txn.insert('gym_profiles', {
        'id': 1,
        'payload': payload,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  @override
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
