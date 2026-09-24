import 'package:adaptive_workout/domain/gyms/gym_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final at = DateTime.utc(2026, 9, 24);
  GymEquipment item(EquipmentAvailability status) => GymEquipment(
    category: 'dumbbells',
    availability: status,
    checkedAt: status == EquipmentAvailability.unknown ? null : at,
  );
  test('Homewood has no inferred equipment and unknown is not available', () {
    final gym = homewoodProfile();
    expect(gym.equipment, isEmpty);
    expect(
      gym.update(item(EquipmentAvailability.unknown)).availableCategories,
      isEmpty,
    );
    expect(
      gym.update(item(EquipmentAvailability.unavailable)).availableCategories,
      isEmpty,
    );
    expect(
      gym.update(item(EquipmentAvailability.available)).availableCategories,
      ['dumbbells'],
    );
  });
  test('round trip preserves per-gym corrections and selection', () {
    final first = homewoodProfile().update(
      item(EquipmentAvailability.available),
    );
    final second = GymProfile(
      id: 'other',
      name: 'Other gym',
      address: '',
      equipment: [],
    );
    final state = GymProfiles(profiles: []).select(first).select(second);
    final restored = GymProfiles.decode(state.encode());
    expect(restored.selected!.availableCategories, isEmpty);
    expect(
      restored.select(restored.profiles.first).selected!.availableCategories,
      ['dumbbells'],
    );
    final corrected = first.update(item(EquipmentAvailability.unavailable));
    expect(corrected.equipment, hasLength(1));
    expect(corrected.availableCategories, isEmpty);
    expect(GymProfiles.decode(state.encode()).encode(), state.encode());
  });
  test('rejects invalid missing duplicate and unsupported data', () {
    expect(
      () => GymEquipment(
        category: 'invented',
        availability: EquipmentAvailability.unknown,
        checkedAt: null,
      ),
      throwsA(anything),
    );
    expect(
      () => GymEquipment(
        category: 'dumbbells',
        availability: EquipmentAvailability.available,
        checkedAt: null,
      ),
      throwsA(anything),
    );
    expect(
      () => GymEquipment(
        category: 'dumbbells',
        availability: EquipmentAvailability.unknown,
        checkedAt: at,
      ),
      throwsA(anything),
    );
    expect(
      () => GymEquipment(
        category: 'dumbbells',
        availability: EquipmentAvailability.available,
        checkedAt: DateTime(2026),
      ),
      throwsA(anything),
    );
    expect(
      () => GymProfile(id: 'x', name: '', address: '', equipment: []),
      throwsA(anything),
    );
    expect(
      () => GymProfile(id: 'x', name: '<script>', address: '', equipment: []),
      throwsA(anything),
    );
    expect(
      () => GymProfile(
        id: 'x',
        name: 'Gym',
        address: '',
        equipment: [
          item(EquipmentAvailability.available),
          item(EquipmentAvailability.available),
        ],
      ),
      throwsA(anything),
    );
    expect(
      () => GymProfiles(profiles: [homewoodProfile(), homewoodProfile()]),
      throwsA(anything),
    );
    expect(
      () => GymProfiles(selectedId: 'missing', profiles: []),
      throwsA(anything),
    );
    expect(() => GymProfiles.decode('{"schema":2}'), throwsA(anything));
    expect(() => GymProfiles.decode('{}'), throwsA(anything));
    expect(
      () => GymEquipment(
        category: 'dumbbells',
        availability: EquipmentAvailability.unknown,
        checkedAt: null,
        notes: 'x' * 501,
      ),
      throwsA(anything),
    );
  });
  test('text and profile count boundaries', () {
    validateGymText('x' * 120, 120);
    expect(() => validateGymText('x' * 121, 120), throwsA(anything));
    final profiles = List.generate(
      50,
      (i) =>
          GymProfile(id: 'gym_$i', name: 'Gym $i', address: '', equipment: []),
    );
    expect(GymProfiles(profiles: profiles).profiles, hasLength(50));
    expect(
      () => GymProfiles(profiles: [...profiles, homewoodProfile()]),
      throwsA(anything),
    );
  });
}
