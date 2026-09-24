import 'package:adaptive_workout/data/repositories/sqlite_gym_profile_repository.dart';
import 'package:adaptive_workout/domain/gyms/gym_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'gym inventory survives SQLite reopen, rejects conflicts and corruption',
    (_) async {
      const path = 'gym_inventory_test_fixture.sqlite';
      await deleteDatabase(path);
      var repo = SqliteGymProfileRepository(path: path);
      final empty = await repo.load();
      expect(empty.selected, isNull);
      final selected = empty.select(
        homewoodProfile().update(
          GymEquipment(
            category: 'dumbbells',
            availability: EquipmentAvailability.available,
            checkedAt: DateTime.utc(2026, 9, 24),
            notes: 'Fixture only',
          ),
        ),
      );
      await repo.save(selected, expected: empty);
      await repo.close();
      repo = SqliteGymProfileRepository(path: path);
      expect((await repo.load()).encode(), selected.encode());
      await repo.save(selected, expected: empty);
      final corrected = selected.select(
        selected.selected!.update(
          GymEquipment(
            category: 'dumbbells',
            availability: EquipmentAvailability.unavailable,
            checkedAt: DateTime.utc(2026, 9, 25),
          ),
        ),
      );
      await expectLater(
        repo.save(corrected, expected: empty),
        throwsStateError,
      );
      expect((await repo.load()).encode(), selected.encode());
      await repo.save(corrected, expected: selected);
      await repo.close();
      repo = SqliteGymProfileRepository(path: path);
      expect((await repo.load()).selected!.availableCategories, isEmpty);
      await repo.close();
      final db = await openDatabase(path);
      await db.update(
        'gym_profiles',
        {'payload': '{"schema":99}'},
        where: 'id=?',
        whereArgs: [1],
      );
      await db.close();
      repo = SqliteGymProfileRepository(path: path);
      await expectLater(repo.load(), throwsA(anything));
      await expectLater(
        repo.save(selected, expected: empty),
        throwsA(anything),
      );
      await repo.close();
      await deleteDatabase(path);
    },
  );
}
