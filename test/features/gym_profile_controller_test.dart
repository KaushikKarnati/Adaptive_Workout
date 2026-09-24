import 'package:adaptive_workout/domain/gyms/gym_profile.dart';
import 'package:adaptive_workout/features/gyms/gym_profile_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_gym_profile_repository.dart';

void main() {
  test(
    'select, confirm, correct and restore location inventory offline',
    () async {
      final repo = FakeGymProfileRepository();
      final c = GymProfileController(
        repo,
        now: () => DateTime.utc(2026, 9, 24),
      );
      addTearDown(c.dispose);
      expect(await c.select(homewoodProfile()), isFalse);
      await c.load();
      await c.select(homewoodProfile());
      expect(
        await c.setEquipment(
          'dumbbells',
          EquipmentAvailability.available,
          'Pair rack',
        ),
        isTrue,
      );
      expect(c.saved!.selected!.availableCategories, ['dumbbells']);
      final second = GymProfile(
        id: 'other',
        name: 'Other gym',
        address: '',
        equipment: [],
      );
      await c.select(second);
      expect(c.saved!.selected!.availableCategories, isEmpty);
      await c.select(
        c.saved!.profiles.firstWhere((p) => p.id == homewoodGymId),
      );
      expect(c.saved!.selected!.availableCategories, ['dumbbells']);
      await c.setEquipment(
        'dumbbells',
        EquipmentAvailability.unavailable,
        'Under repair',
      );
      final reopened = GymProfileController(repo);
      addTearDown(reopened.dispose);
      await reopened.load();
      expect(reopened.saved!.selected!.equipment.single.notes, 'Under repair');
      expect(reopened.saved!.selected!.availableCategories, isEmpty);
      await reopened.clearSelection();
      expect(repo.stored.selected, isNull);
      expect(repo.stored.profiles, hasLength(2));
    },
  );
  test(
    'failed acknowledgement keeps pending change and retry is idempotent',
    () async {
      final repo = FakeGymProfileRepository();
      final c = GymProfileController(repo);
      addTearDown(c.dispose);
      await c.load();
      repo.failRead = true;
      expect(await c.select(homewoodProfile()), isFalse);
      expect(c.saved!.selected, isNull);
      expect(c.canRetry, isTrue);
      expect(await c.clearSelection(), isFalse);
      expect(await c.retry(), isTrue);
      expect(c.saved!.profiles, hasLength(1));
    },
  );
  test(
    'write failure, invalid input, load failure and conflict recovery',
    () async {
      final repo = FakeGymProfileRepository()..failRead = true;
      final c = GymProfileController(repo);
      addTearDown(c.dispose);
      await c.load();
      expect(c.saved, isNull);
      expect(c.error, isNotNull);
      await c.load();
      repo.failWrite = true;
      expect(await c.select(homewoodProfile()), isFalse);
      expect(repo.stored.profiles, isEmpty);
      repo.failWrite = false;
      await c.retry();
      expect(
        await c.setEquipment('invalid', EquipmentAvailability.available, ''),
        isFalse,
      );
      expect(c.canRetry, isFalse);
      repo.stored = GymProfiles(profiles: []);
      expect(
        await c.setEquipment('dumbbells', EquipmentAvailability.available, ''),
        isFalse,
      );
      await c.discardPendingAndReload();
      expect(c.saved!.profiles, isEmpty);
      expect(c.locked, isFalse);
    },
  );
}
