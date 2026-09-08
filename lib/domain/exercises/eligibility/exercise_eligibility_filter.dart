part of 'exercise_eligibility.dart';

final class _EligibilityFilterInput {
  _EligibilityFilterInput({
    required List<_EligibilityCandidate> candidates,
    required List<EquipmentInventoryItem> equipmentInventory,
    required Set<String> temporarilyUnavailableEquipmentIds,
    required Set<String> supportedCapabilityIds,
    required Set<String> unsupportedCapabilityIds,
    required Set<String> limitationIds,
    required Set<String> persistentExerciseExclusionIds,
    required Set<String> requestExerciseExclusionIds,
  }) : candidates = List.unmodifiable(candidates),
       equipmentInventory = List.unmodifiable(equipmentInventory),
       temporarilyUnavailableEquipmentIds = Set.unmodifiable(
         temporarilyUnavailableEquipmentIds,
       ),
       supportedCapabilityIds = Set.unmodifiable(supportedCapabilityIds),
       unsupportedCapabilityIds = Set.unmodifiable(unsupportedCapabilityIds),
       limitationIds = Set.unmodifiable(limitationIds),
       persistentExerciseExclusionIds = Set.unmodifiable(
         persistentExerciseExclusionIds,
       ),
       requestExerciseExclusionIds = Set.unmodifiable(
         requestExerciseExclusionIds,
       );

  final List<_EligibilityCandidate> candidates;
  final List<EquipmentInventoryItem> equipmentInventory;
  final Set<String> temporarilyUnavailableEquipmentIds;
  final Set<String> supportedCapabilityIds;
  final Set<String> unsupportedCapabilityIds;
  final Set<String> limitationIds;
  final Set<String> persistentExerciseExclusionIds;
  final Set<String> requestExerciseExclusionIds;
}

final class _ExerciseEligibilityFilter {
  const _ExerciseEligibilityFilter();

  List<CandidateEligibilityEvaluation> evaluate(_EligibilityFilterInput input) {
    final inventory = <String, EquipmentInventoryItem>{
      for (final item in input.equipmentInventory) item.equipmentId: item,
    };
    final candidates = input.candidates.toList()
      ..sort((left, right) => left.id.compareTo(right.id));

    return candidates.map((candidate) {
      final reasons = <EligibilityIssue>[];
      void reason(String code, Map<String, Object?> parameters) {
        reasons.add(EligibilityIssue._(code, parameters));
      }

      if (!candidate.isSelectable) {
        reason(EligibilityReasonCode.catalogEntryUnselectable, {
          'exerciseId': candidate.id,
        });
      }
      if (input.persistentExerciseExclusionIds.contains(candidate.id)) {
        reason(EligibilityReasonCode.exerciseExcludedPersistent, {
          'exerciseId': candidate.id,
        });
      }
      if (input.requestExerciseExclusionIds.contains(candidate.id)) {
        reason(EligibilityReasonCode.exerciseExcludedForRequest, {
          'exerciseId': candidate.id,
        });
      }

      final limitationConflicts =
          candidate.exclusionTagIds.intersection(input.limitationIds).toList()
            ..sort();
      for (final limitationId in limitationConflicts) {
        reason(EligibilityReasonCode.limitationConflict, {
          'exerciseId': candidate.id,
          'limitationId': limitationId,
        });
      }

      final requiredCapabilities = candidate.capabilityIds.toList()..sort();
      for (final capabilityId in requiredCapabilities) {
        if (input.unsupportedCapabilityIds.contains(capabilityId)) {
          reason(EligibilityReasonCode.functionalCapabilityUnsupported, {
            'capabilityId': capabilityId,
            'exerciseId': candidate.id,
          });
        } else if (!input.supportedCapabilityIds.contains(capabilityId)) {
          reason(EligibilityReasonCode.functionalCapabilityUnconfirmed, {
            'capabilityId': capabilityId,
            'exerciseId': candidate.id,
          });
        }
      }

      final requirements = candidate.equipmentRequirements.toList()
        ..sort((left, right) => left.equipmentId.compareTo(right.equipmentId));
      for (final requirement in requirements) {
        final available = inventory[requirement.equipmentId];
        if (available == null) {
          reason(EligibilityReasonCode.equipmentMissing, {
            'equipmentId': requirement.equipmentId,
            'exerciseId': candidate.id,
          });
        } else {
          if (available.quantity < requirement.quantity) {
            reason(EligibilityReasonCode.equipmentQuantityInsufficient, {
              'availableQuantity': available.quantity,
              'equipmentId': requirement.equipmentId,
              'exerciseId': candidate.id,
              'requiredQuantity': requirement.quantity,
            });
          }
          final availableCapabilities = available.capabilityIds.toSet();
          final missingCapabilities =
              requirement.capabilityIds
                  .difference(availableCapabilities)
                  .toList()
                ..sort();
          for (final capabilityId in missingCapabilities) {
            reason(EligibilityReasonCode.equipmentCapabilityMissing, {
              'capabilityId': capabilityId,
              'equipmentId': requirement.equipmentId,
              'exerciseId': candidate.id,
            });
          }
        }
        if (input.temporarilyUnavailableEquipmentIds.contains(
          requirement.equipmentId,
        )) {
          reason(EligibilityReasonCode.equipmentTemporarilyUnavailable, {
            'equipmentId': requirement.equipmentId,
            'exerciseId': candidate.id,
          });
        }
      }

      final sortedReasons = _sortedEligibilityIssues(reasons);
      return CandidateEligibilityEvaluation._(
        exerciseId: candidate.id,
        isEligible: sortedReasons.isEmpty,
        reasons: sortedReasons,
      );
    }).toList();
  }
}
