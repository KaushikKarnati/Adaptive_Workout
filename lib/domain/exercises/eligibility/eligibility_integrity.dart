part of 'exercise_eligibility.dart';

String eligibilityConstraintSnapshotSha256({
  required List<EquipmentInventoryItem> equipmentInventory,
  required List<String> temporarilyUnavailableEquipmentIds,
  required FunctionalCapabilityAssessment functionalCapabilityAssessment,
  required LimitationAssessment limitationAssessment,
  required List<String> persistentExerciseExclusionIds,
  required List<String> requestExerciseExclusionIds,
}) {
  final inventory =
      equipmentInventory
          .map(
            (item) => <String, Object?>{
              'equipmentId': item.equipmentId,
              'quantity': item.quantity,
              'capabilityIds': _sortedStrings(item.capabilityIds),
            },
          )
          .toList()
        ..sort((left, right) {
          final idComparison = (left['equipmentId']! as String).compareTo(
            right['equipmentId']! as String,
          );
          if (idComparison != 0) return idComparison;
          return utf8
              .decode(canonicalJsonBytes(left))
              .compareTo(utf8.decode(canonicalJsonBytes(right)));
        });
  final snapshot = <String, Object?>{
    'equipmentInventory': inventory,
    'functionalCapabilityAssessment': <String, Object?>{
      'supportedIds': _sortedStrings(
        functionalCapabilityAssessment.supportedIds,
      ),
      'unsupportedIds': _sortedStrings(
        functionalCapabilityAssessment.unsupportedIds,
      ),
    },
    'limitationAssessment': <String, Object?>{
      'ids': _sortedStrings(limitationAssessment.ids),
    },
    'persistentExerciseExclusionIds': _sortedStrings(
      persistentExerciseExclusionIds,
    ),
    'requestExerciseExclusionIds': _sortedStrings(requestExerciseExclusionIds),
    'temporarilyUnavailableEquipmentIds': _sortedStrings(
      temporarilyUnavailableEquipmentIds,
    ),
  };
  return sha256Hex(canonicalJsonBytes(snapshot));
}

List<String> _sortedStrings(Iterable<String> values) => values.toList()..sort();
