import 'package:adaptive_workout/data/repositories/sqlite_practice_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('prior-process acknowledged records survive app relaunch', (
    _,
  ) async {
    final path = '${await getDatabasesPath()}/practice_restart_fixture.sqlite';
    final repo = await SqlitePracticeRepository.open(path: path);
    final session = (await repo.load('restart_fixture')).single;
    expect(session.revision, 3);
    expect(session.completed, isFalse);
    expect(session.sets.map((s) => s.id), ['set_1', 'set_2', 'set_3']);
    expect(
      session.sets.every(
        (s) => s.microPounds == 30000000 && s.reps == 10 && s.rir == 2,
      ),
      isTrue,
    );
    await repo.close();
    await deleteDatabase(path);
  });
}
