import 'dart:collection';
import 'dart:convert';

import '../catalog/catalog_integrity.dart';
import '../catalog/exercise_catalog.dart';
import '../catalog/exercise_catalog_manifest_validator.dart';
import '../catalog/exercise_catalog_validator.dart';

part 'eligibility_integrity.dart';
part 'exercise_eligibility_evaluator.dart';
part 'exercise_eligibility_filter.dart';
part 'safety_gate.dart';

enum EligibilityResultStatus {
  evaluated,
  constrainedNoCandidate,
  invalidInput,
  catalogUnavailable,
  safetyStop,
}

extension EligibilityResultStatusWireName on EligibilityResultStatus {
  String get wireName => switch (this) {
    EligibilityResultStatus.evaluated => 'evaluated',
    EligibilityResultStatus.constrainedNoCandidate =>
      'constrained_no_candidate',
    EligibilityResultStatus.invalidInput => 'invalid_input',
    EligibilityResultStatus.catalogUnavailable => 'catalog_unavailable',
    EligibilityResultStatus.safetyStop => 'safety_stop',
  };
}

abstract final class EligibilityReasonCode {
  static const catalogEntryUnselectable = 'catalog_entry_unselectable';
  static const exerciseExcludedPersistent = 'exercise_excluded_persistent';
  static const exerciseExcludedForRequest = 'exercise_excluded_for_request';
  static const limitationConflict = 'limitation_conflict';
  static const functionalCapabilityUnsupported =
      'functional_capability_unsupported';
  static const functionalCapabilityUnconfirmed =
      'functional_capability_unconfirmed';
  static const equipmentMissing = 'equipment_missing';
  static const equipmentQuantityInsufficient =
      'equipment_quantity_insufficient';
  static const equipmentCapabilityMissing = 'equipment_capability_missing';
  static const equipmentTemporarilyUnavailable =
      'equipment_temporarily_unavailable';

  static const catalogInvalid = 'catalog_invalid';
  static const schemaVersionMismatch = 'schema_version_mismatch';
  static const catalogVersionMismatch = 'catalog_version_mismatch';
  static const taxonomyVersionMismatch = 'taxonomy_version_mismatch';
  static const catalogDigestMismatch = 'catalog_digest_mismatch';
  static const constraintDigestMismatch = 'constraint_digest_mismatch';
  static const eligibilityRulesUnsupported = 'eligibility_rules_unsupported';
  static const requiredInputMissing = 'required_input_missing';
  static const invalidValue = 'invalid_value';
  static const unknownTaxonomyId = 'unknown_taxonomy_id';
  static const unknownExerciseId = 'unknown_exercise_id';
  static const duplicateInput = 'duplicate_input';
  static const staleSafetyReference = 'stale_safety_reference';
  static const noEligibleExercise = 'no_eligible_exercise';
  static const painReportRequiresStop = 'pain_report_requires_stop';
  static const unresolvedSafetyIncident = 'unresolved_safety_incident';

  static const ordered = <String>[
    catalogEntryUnselectable,
    exerciseExcludedPersistent,
    exerciseExcludedForRequest,
    limitationConflict,
    functionalCapabilityUnsupported,
    functionalCapabilityUnconfirmed,
    equipmentMissing,
    equipmentQuantityInsufficient,
    equipmentCapabilityMissing,
    equipmentTemporarilyUnavailable,
    catalogInvalid,
    schemaVersionMismatch,
    catalogVersionMismatch,
    taxonomyVersionMismatch,
    catalogDigestMismatch,
    constraintDigestMismatch,
    eligibilityRulesUnsupported,
    requiredInputMissing,
    invalidValue,
    unknownTaxonomyId,
    unknownExerciseId,
    duplicateInput,
    staleSafetyReference,
    noEligibleExercise,
    painReportRequiresStop,
    unresolvedSafetyIncident,
  ];
}

final class EligibilityIssue implements Comparable<EligibilityIssue> {
  EligibilityIssue._(this.code, [Map<String, Object?> parameters = const {}])
    : parameters = _freezeParameters(parameters);

  final String code;
  final Map<String, Object?> parameters;

  Map<String, Object?> toJson() => <String, Object?>{
    'code': code,
    'parameters': parameters,
  };

  @override
  int compareTo(EligibilityIssue other) {
    final codeComparison = _reasonRank(code).compareTo(_reasonRank(other.code));
    if (codeComparison != 0) return codeComparison;
    return jsonEncode(parameters).compareTo(jsonEncode(other.parameters));
  }

  static int _reasonRank(String code) {
    final index = EligibilityReasonCode.ordered.indexOf(code);
    return index < 0 ? EligibilityReasonCode.ordered.length : index;
  }
}

final class EquipmentInventoryItem {
  EquipmentInventoryItem({
    required this.equipmentId,
    required this.quantity,
    List<String> capabilityIds = const [],
  }) : capabilityIds = List.unmodifiable(capabilityIds);

  final String equipmentId;
  final int quantity;
  final List<String> capabilityIds;
}

final class _EligibilityEquipmentRequirement {
  _EligibilityEquipmentRequirement({
    required this.equipmentId,
    required this.quantity,
    required Set<String> capabilityIds,
  }) : capabilityIds = Set.unmodifiable(capabilityIds);

  final String equipmentId;
  final int quantity;
  final Set<String> capabilityIds;
}

final class _EligibilityCandidate {
  _EligibilityCandidate({
    required this.id,
    required this.isSelectable,
    required List<_EligibilityEquipmentRequirement> equipmentRequirements,
    required Set<String> capabilityIds,
    required Set<String> exclusionTagIds,
  }) : equipmentRequirements = List.unmodifiable(equipmentRequirements),
       capabilityIds = Set.unmodifiable(capabilityIds),
       exclusionTagIds = Set.unmodifiable(exclusionTagIds);

  final String id;
  final bool isSelectable;
  final List<_EligibilityEquipmentRequirement> equipmentRequirements;
  final Set<String> capabilityIds;
  final Set<String> exclusionTagIds;
}

final class FunctionalCapabilityAssessment {
  FunctionalCapabilityAssessment({
    List<String> supportedIds = const [],
    List<String> unsupportedIds = const [],
  }) : supportedIds = List.unmodifiable(supportedIds),
       unsupportedIds = List.unmodifiable(unsupportedIds);

  final List<String> supportedIds;
  final List<String> unsupportedIds;
}

final class LimitationAssessment {
  LimitationAssessment({List<String> ids = const []})
    : ids = List.unmodifiable(ids);

  final List<String> ids;
}

final class SafetyRestrictionReference {
  const SafetyRestrictionReference({
    required this.exerciseId,
    required this.constraintSnapshotSha256,
    required this.catalogVersion,
    required this.taxonomyVersion,
    required this.eligibilityRuleSetVersion,
    required this.originatingRecommendationId,
    required this.regressionTestReference,
    required this.reviewState,
    required this.reviewReference,
  });

  final String? exerciseId;
  final String? constraintSnapshotSha256;
  final String? catalogVersion;
  final String? taxonomyVersion;
  final String? eligibilityRuleSetVersion;
  final String? originatingRecommendationId;
  final String? regressionTestReference;
  final SafetyRestrictionReviewState? reviewState;
  final String? reviewReference;
}

enum SafetyRestrictionReviewState { unresolved }

enum EligibilitySafetyStateKind { clear, stop, restricted }

final class EligibilitySafetyState {
  EligibilitySafetyState({
    required this.version,
    required this.kind,
    this.affectedExerciseId,
    List<SafetyRestrictionReference> restrictions = const [],
  }) : restrictions = List.unmodifiable(restrictions);

  final String? version;
  final EligibilitySafetyStateKind kind;
  final String? affectedExerciseId;
  final List<SafetyRestrictionReference> restrictions;
}

final class ExerciseEligibilityRequest {
  ExerciseEligibilityRequest({
    required this.eligibilityRuleSetVersion,
    required this.schemaVersion,
    required this.catalogVersion,
    required this.taxonomyVersion,
    required this.catalogContentSha256,
    required this.constraintSnapshotSha256,
    required this.manifest,
    required List<ExerciseCatalogEntry>? catalog,
    required List<String>? candidateExerciseIds,
    required List<EquipmentInventoryItem>? equipmentInventory,
    required List<String>? temporarilyUnavailableEquipmentIds,
    required this.functionalCapabilityAssessment,
    required this.limitationAssessment,
    required List<String>? persistentExerciseExclusionIds,
    required List<String>? requestExerciseExclusionIds,
    required this.safetyState,
  }) : catalog = catalog == null ? null : List.unmodifiable(catalog),
       candidateExerciseIds = candidateExerciseIds == null
           ? null
           : List.unmodifiable(candidateExerciseIds),
       equipmentInventory = equipmentInventory == null
           ? null
           : List.unmodifiable(equipmentInventory),
       temporarilyUnavailableEquipmentIds =
           temporarilyUnavailableEquipmentIds == null
           ? null
           : List.unmodifiable(temporarilyUnavailableEquipmentIds),
       persistentExerciseExclusionIds = persistentExerciseExclusionIds == null
           ? null
           : List.unmodifiable(persistentExerciseExclusionIds),
       requestExerciseExclusionIds = requestExerciseExclusionIds == null
           ? null
           : List.unmodifiable(requestExerciseExclusionIds);

  final String? eligibilityRuleSetVersion;
  final String? schemaVersion;
  final String? catalogVersion;
  final String? taxonomyVersion;
  final String? catalogContentSha256;
  final String? constraintSnapshotSha256;
  final ExerciseCatalogManifest? manifest;
  final List<ExerciseCatalogEntry>? catalog;
  final List<String>? candidateExerciseIds;
  final List<EquipmentInventoryItem>? equipmentInventory;
  final List<String>? temporarilyUnavailableEquipmentIds;
  final FunctionalCapabilityAssessment? functionalCapabilityAssessment;
  final LimitationAssessment? limitationAssessment;
  final List<String>? persistentExerciseExclusionIds;
  final List<String>? requestExerciseExclusionIds;
  final EligibilitySafetyState? safetyState;
}

final class CandidateEligibilityEvaluation {
  CandidateEligibilityEvaluation._({
    required this.exerciseId,
    required this.isEligible,
    required List<EligibilityIssue> reasons,
  }) : reasons = List.unmodifiable(_sortedEligibilityIssues(reasons));

  final String exerciseId;
  final bool isEligible;
  final List<EligibilityIssue> reasons;

  Map<String, Object?> toJson() => <String, Object?>{
    'exerciseId': exerciseId,
    'isEligible': isEligible,
    'reasons': reasons.map((reason) => reason.toJson()).toList(),
  };
}

final class ExerciseEligibilityResult {
  ExerciseEligibilityResult._({
    required this.status,
    required this.eligibilityRuleSetVersion,
    required this.schemaVersion,
    required this.catalogVersion,
    required this.taxonomyVersion,
    required this.catalogContentSha256,
    required this.constraintSnapshotSha256,
    required this.catalogValidationReferenceTime,
    required List<String> eligibleExerciseIds,
    required List<CandidateEligibilityEvaluation> candidateEvaluations,
    required List<EligibilityIssue> requestIssues,
  }) : eligibleExerciseIds = List.unmodifiable(
         eligibleExerciseIds.toList()..sort(),
       ),
       candidateEvaluations = List.unmodifiable(
         candidateEvaluations.toList()
           ..sort((left, right) => left.exerciseId.compareTo(right.exerciseId)),
       ),
       requestIssues = List.unmodifiable(
         _sortedEligibilityIssues(requestIssues),
       );

  final EligibilityResultStatus status;
  final String? eligibilityRuleSetVersion;
  final String? schemaVersion;
  final String? catalogVersion;
  final String? taxonomyVersion;
  final String? catalogContentSha256;
  final String? constraintSnapshotSha256;
  final DateTime catalogValidationReferenceTime;
  final List<String> eligibleExerciseIds;
  final List<CandidateEligibilityEvaluation> candidateEvaluations;
  final List<EligibilityIssue> requestIssues;

  Map<String, Object?> toJson() => <String, Object?>{
    'status': status.wireName,
    'eligibilityRuleSetVersion': eligibilityRuleSetVersion,
    'schemaVersion': schemaVersion,
    'catalogVersion': catalogVersion,
    'taxonomyVersion': taxonomyVersion,
    'catalogContentSha256': catalogContentSha256,
    'constraintSnapshotSha256': constraintSnapshotSha256,
    'catalogValidationReferenceTime': catalogValidationReferenceTime
        .toUtc()
        .toIso8601String()
        .replaceFirst('.000Z', 'Z'),
    'eligibleExerciseIds': eligibleExerciseIds,
    'candidateEvaluations': candidateEvaluations
        .map((evaluation) => evaluation.toJson())
        .toList(),
    'requestIssues': requestIssues.map((issue) => issue.toJson()).toList(),
  };

  String toCanonicalJson() => utf8.decode(canonicalJsonBytes(toJson()));
}

Map<String, Object?> _freezeParameters(Map<String, Object?> parameters) {
  final sorted = SplayTreeMap<String, Object?>();
  for (final entry in parameters.entries) {
    sorted[entry.key] = _freezeJsonValue(entry.value);
  }
  return Map.unmodifiable(sorted);
}

Object? _freezeJsonValue(Object? value) {
  if (value is List<Object?>) {
    return List<Object?>.unmodifiable(value.map(_freezeJsonValue));
  }
  if (value is Map<String, Object?>) return _freezeParameters(value);
  return value;
}

List<EligibilityIssue> _sortedEligibilityIssues(
  Iterable<EligibilityIssue> issues,
) {
  final sorted = issues.toList()..sort();
  return sorted;
}
