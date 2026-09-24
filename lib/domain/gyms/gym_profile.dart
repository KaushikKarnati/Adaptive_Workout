import 'dart:convert';

import '../exercises/catalog/exercise_catalog_validator.dart';
import '../training/training_setup.dart';

const homewoodGymId = 'club4_homewood';
const homewoodSource =
    'https://www.club4fitness.com/location/homewood-birmingham-al/';

enum EquipmentAvailability { unknown, available, unavailable }

/// Location observations only; never a load, catalog approval or safety gate.
final class GymEquipment {
  GymEquipment({
    required this.category,
    required this.availability,
    required this.checkedAt,
    this.notes = '',
  }) {
    requireSetup(
      ExerciseCatalogValidator.equipmentIds.contains(category),
      'unknown_equipment',
    );
    requireSetup(
      availability == EquipmentAvailability.unknown
          ? checkedAt == null
          : checkedAt != null && checkedAt!.isUtc,
      'invalid_confirmation',
    );
    validateGymText(notes, 500, allowEmpty: true);
  }
  final String category, notes;
  final EquipmentAvailability availability;
  final DateTime? checkedAt;
  Map<String, Object?> toJson() => {
    'category': category,
    'availability': availability.name,
    'checkedAt': checkedAt?.toIso8601String(),
    'notes': notes,
  };
  factory GymEquipment.fromJson(Map<String, dynamic> j) => GymEquipment(
    category: j['category'] as String,
    availability: EquipmentAvailability.values.byName(
      j['availability'] as String,
    ),
    checkedAt: j['checkedAt'] == null
        ? null
        : DateTime.parse(j['checkedAt'] as String),
    notes: j['notes'] as String,
  );
}

void validateGymText(String value, int max, {bool allowEmpty = false}) {
  requireSetup(
    value == value.trim() &&
        (allowEmpty || value.isNotEmpty) &&
        value.length <= max &&
        !RegExp(r'[\x00-\x1f\x7f-\x9f\u202a-\u202e\u2066-\u2069<>]')
            .hasMatch(value),
    'invalid_gym_text',
  );
}

final class GymProfile {
  GymProfile({
    required this.id,
    required this.name,
    required this.address,
    required List<GymEquipment> equipment,
  }) : equipment = List.unmodifiable(equipment) {
    validateSetupId(id);
    validateGymText(name, 120);
    validateGymText(address, 240, allowEmpty: true);
    requireSetup(
      equipment.length <= ExerciseCatalogValidator.equipmentIds.length &&
          equipment.map((e) => e.category).toSet().length == equipment.length,
      'duplicate_equipment',
    );
  }
  final String id, name, address;
  final List<GymEquipment> equipment;
  List<String> get availableCategories => List.unmodifiable(
    equipment
        .where((e) => e.availability == EquipmentAvailability.available)
        .map((e) => e.category)
        .toList()
      ..sort(),
  );
  GymProfile update(GymEquipment item) => GymProfile(
    id: id,
    name: name,
    address: address,
    equipment: [...equipment.where((e) => e.category != item.category), item],
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'equipment':
        (equipment.toList()..sort((a, b) => a.category.compareTo(b.category)))
            .map((e) => e.toJson())
            .toList(),
  };
  factory GymProfile.fromJson(Map<String, dynamic> j) => GymProfile(
    id: j['id'] as String,
    name: j['name'] as String,
    address: j['address'] as String,
    equipment: (j['equipment'] as List)
        .map((e) => GymEquipment.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

GymProfile homewoodProfile() => GymProfile(
  id: homewoodGymId,
  name: 'CLUB4 Homewood',
  address: '257 Lakeshore Pkwy, Birmingham, AL 35209',
  equipment: [],
);

final class GymProfiles {
  GymProfiles({this.selectedId, required List<GymProfile> profiles})
    : profiles = List.unmodifiable(profiles) {
    requireSetup(
      profiles.length <= 50 &&
          profiles.map((p) => p.id).toSet().length == profiles.length,
      'duplicate_or_excess_gyms',
    );
    requireSetup(
      selectedId == null || profiles.any((p) => p.id == selectedId),
      'unknown_selected_gym',
    );
  }
  final String? selectedId;
  final List<GymProfile> profiles;
  GymProfile? get selected =>
      profiles.where((p) => p.id == selectedId).firstOrNull;
  GymProfiles select(GymProfile gym) => GymProfiles(
    selectedId: gym.id,
    profiles: [...profiles.where((p) => p.id != gym.id), gym],
  );
  String encode() => jsonEncode({
    'schema': 1,
    'selectedId': selectedId,
    'profiles': (profiles.toList()..sort((a, b) => a.id.compareTo(b.id)))
        .map((p) => p.toJson())
        .toList(),
  });
  factory GymProfiles.decode(String value) {
    final j = jsonDecode(value) as Map<String, dynamic>;
    requireSetup(j['schema'] == 1, 'unsupported_gym_schema');
    return GymProfiles(
      selectedId: j['selectedId'] as String?,
      profiles: (j['profiles'] as List)
          .map((p) => GymProfile.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}

abstract interface class GymProfileRepository {
  Future<GymProfiles> load();

  /// Compare-and-save prevents another screen from overwriting newer edits.
  Future<void> save(GymProfiles next, {required GymProfiles expected});
  Future<void> close();
}
