import 'package:sqflite/sqflite.dart';

import '../../application/appearance_preferences.dart';

final class SqliteAppearanceRepository
    implements AppearancePreferencesRepository {
  SqliteAppearanceRepository({this.path = 'appearance.sqlite'});
  final String path;
  Database? _db;

  Future<Database> _open() async => _db ??= await openDatabase(
    path,
    version: 1,
    onCreate: (db, _) => db.execute(
      'CREATE TABLE preferences (id INTEGER PRIMARY KEY CHECK(id=1), appearance TEXT NOT NULL CHECK(appearance IN (\'system\',\'light\',\'dark\')))',
    ),
    onUpgrade: (_, old, next) async =>
        throw StateError('Unsupported appearance schema'),
    onDowngrade: (_, old, next) async =>
        throw StateError('Unsupported appearance schema'),
  );

  @override
  Future<AppAppearance> load() async {
    final rows = await (await _open()).query(
      'preferences',
      where: 'id=?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return AppAppearance.system;
    return AppAppearance.values.byName(rows.single['appearance'] as String);
  }

  @override
  Future<void> save(AppAppearance appearance) async {
    await (await _open()).insert('preferences', {
      'id': 1,
      'appearance': appearance.name,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
