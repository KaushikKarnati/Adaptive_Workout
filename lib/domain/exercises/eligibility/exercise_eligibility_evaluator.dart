part of 'exercise_eligibility.dart';

final class ExerciseEligibilityEvaluator {
  ExerciseEligibilityEvaluator({
    required this.catalogValidator,
    this.supportedEligibilityRuleSetVersion = '1.0.0',
    this.supportedSafetyStateVersion = '1.0.0',
  });

  final ExerciseCatalogManifestValidator catalogValidator;
  final String supportedEligibilityRuleSetVersion;
  final String supportedSafetyStateVersion;

  static final RegExp _sha256 = RegExp(r'^[0-9a-f]{64}$');
  static final RegExp _auditReference = RegExp(r'^[\x20-\x7e]{1,128}$');
  static const _SafetyGate _safetyGate = _SafetyGate();
  static const _ExerciseEligibilityFilter _filter =
      _ExerciseEligibilityFilter();

  ExerciseEligibilityResult evaluate(ExerciseEligibilityRequest request) {
    final manifest = request.manifest;
    final catalog = request.catalog;
    if (manifest == null || catalog == null) {
      final issues = <EligibilityIssue>[];
      if (manifest == null) {
        issues.add(_missing('manifest'));
      }
      if (catalog == null) {
        issues.add(_missing('catalog'));
      }
      return _result(
        request,
        EligibilityResultStatus.invalidInput,
        requestIssues: _sortedEligibilityIssues(issues),
      );
    }

    final catalogIssues = catalogValidator.validate(manifest, catalog);
    if (catalogIssues.isNotEmpty) {
      final details = catalogIssues.map((issue) => issue.toString()).toList()
        ..sort();
      return _result(
        request,
        EligibilityResultStatus.catalogUnavailable,
        requestIssues: <EligibilityIssue>[
          EligibilityIssue._(EligibilityReasonCode.catalogInvalid, {
            'issues': details,
          }),
        ],
      );
    }

    final catalogById = <String, ExerciseCatalogEntry>{
      for (final entry in catalog) entry.id: entry,
    };
    final validationIssues = _validateRequest(
      request,
      manifest,
      catalogById.keys.toSet(),
    );
    if (validationIssues.isNotEmpty) {
      return _result(
        request,
        EligibilityResultStatus.invalidInput,
        requestIssues: _sortedEligibilityIssues(validationIssues),
      );
    }

    final constraintDigest = eligibilityConstraintSnapshotSha256(
      equipmentInventory: request.equipmentInventory!,
      temporarilyUnavailableEquipmentIds:
          request.temporarilyUnavailableEquipmentIds!,
      functionalCapabilityAssessment: request.functionalCapabilityAssessment!,
      limitationAssessment: request.limitationAssessment!,
      persistentExerciseExclusionIds: request.persistentExerciseExclusionIds!,
      requestExerciseExclusionIds: request.requestExerciseExclusionIds!,
    );

    final candidateIds = request.candidateExerciseIds!.toSet();
    final safetyDecision = _safetyGate.evaluate(
      safetyState: request.safetyState!,
      candidateExerciseIds: candidateIds,
      constraintSnapshotSha256: constraintDigest,
    );
    if (safetyDecision.disposition == _SafetyGateDisposition.safetyStop) {
      return _result(
        request,
        EligibilityResultStatus.safetyStop,
        requestIssues: safetyDecision.issues,
      );
    }

    final candidateEntries = candidateIds
        .map((id) => _projectCandidate(catalogById[id]!))
        .toList();
    final evaluations = _filter.evaluate(
      _EligibilityFilterInput(
        candidates: candidateEntries,
        equipmentInventory: request.equipmentInventory!,
        temporarilyUnavailableEquipmentIds: request
            .temporarilyUnavailableEquipmentIds!
            .toSet(),
        supportedCapabilityIds: request
            .functionalCapabilityAssessment!
            .supportedIds
            .toSet(),
        unsupportedCapabilityIds: request
            .functionalCapabilityAssessment!
            .unsupportedIds
            .toSet(),
        limitationIds: request.limitationAssessment!.ids.toSet(),
        persistentExerciseExclusionIds: request.persistentExerciseExclusionIds!
            .toSet(),
        requestExerciseExclusionIds: request.requestExerciseExclusionIds!
            .toSet(),
      ),
    );
    final eligibleIds = evaluations
        .where((evaluation) => evaluation.isEligible)
        .map((evaluation) => evaluation.exerciseId)
        .toList();
    if (eligibleIds.isEmpty) {
      return _result(
        request,
        EligibilityResultStatus.constrainedNoCandidate,
        candidateEvaluations: evaluations,
        requestIssues: <EligibilityIssue>[
          EligibilityIssue._(EligibilityReasonCode.noEligibleExercise),
        ],
      );
    }
    return _result(
      request,
      EligibilityResultStatus.evaluated,
      eligibleExerciseIds: eligibleIds,
      candidateEvaluations: evaluations,
    );
  }

  List<EligibilityIssue> _validateRequest(
    ExerciseEligibilityRequest request,
    ExerciseCatalogManifest manifest,
    Set<String> catalogIds,
  ) {
    final issues = <EligibilityIssue>[];
    void missingIfNull(Object? value, String field) {
      if (value == null) issues.add(_missing(field));
    }

    missingIfNull(
      request.eligibilityRuleSetVersion,
      'eligibilityRuleSetVersion',
    );
    missingIfNull(request.schemaVersion, 'schemaVersion');
    missingIfNull(request.catalogVersion, 'catalogVersion');
    missingIfNull(request.taxonomyVersion, 'taxonomyVersion');
    missingIfNull(request.catalogContentSha256, 'catalogContentSha256');
    missingIfNull(request.constraintSnapshotSha256, 'constraintSnapshotSha256');
    missingIfNull(request.candidateExerciseIds, 'candidateExerciseIds');
    missingIfNull(request.equipmentInventory, 'equipmentInventory');
    missingIfNull(
      request.temporarilyUnavailableEquipmentIds,
      'temporarilyUnavailableEquipmentIds',
    );
    missingIfNull(
      request.functionalCapabilityAssessment,
      'functionalCapabilityAssessment',
    );
    missingIfNull(request.limitationAssessment, 'limitationAssessment');
    missingIfNull(
      request.persistentExerciseExclusionIds,
      'persistentExerciseExclusionIds',
    );
    missingIfNull(
      request.requestExerciseExclusionIds,
      'requestExerciseExclusionIds',
    );
    missingIfNull(request.safetyState, 'safetyState');

    if (request.eligibilityRuleSetVersion != null &&
        request.eligibilityRuleSetVersion !=
            supportedEligibilityRuleSetVersion) {
      issues.add(
        EligibilityIssue._(EligibilityReasonCode.eligibilityRulesUnsupported, {
          'actual': request.eligibilityRuleSetVersion,
          'expected': supportedEligibilityRuleSetVersion,
        }),
      );
    }
    _mismatch(
      issues,
      request.schemaVersion,
      manifest.schemaVersion,
      'schemaVersion',
      EligibilityReasonCode.schemaVersionMismatch,
    );
    _mismatch(
      issues,
      request.catalogVersion,
      manifest.catalogVersion,
      'catalogVersion',
      EligibilityReasonCode.catalogVersionMismatch,
    );
    _mismatch(
      issues,
      request.taxonomyVersion,
      manifest.taxonomyVersion,
      'taxonomyVersion',
      EligibilityReasonCode.taxonomyVersionMismatch,
    );
    _mismatch(
      issues,
      request.catalogContentSha256,
      manifest.contentSha256,
      'catalogContentSha256',
      EligibilityReasonCode.catalogDigestMismatch,
    );
    if (request.constraintSnapshotSha256 != null &&
        !_sha256.hasMatch(request.constraintSnapshotSha256!)) {
      issues.add(
        EligibilityIssue._(EligibilityReasonCode.invalidValue, {
          'field': 'constraintSnapshotSha256',
        }),
      );
    }
    if (request.constraintSnapshotSha256 != null &&
        request.equipmentInventory != null &&
        request.temporarilyUnavailableEquipmentIds != null &&
        request.functionalCapabilityAssessment != null &&
        request.limitationAssessment != null &&
        request.persistentExerciseExclusionIds != null &&
        request.requestExerciseExclusionIds != null) {
      final expectedDigest = eligibilityConstraintSnapshotSha256(
        equipmentInventory: request.equipmentInventory!,
        temporarilyUnavailableEquipmentIds:
            request.temporarilyUnavailableEquipmentIds!,
        functionalCapabilityAssessment: request.functionalCapabilityAssessment!,
        limitationAssessment: request.limitationAssessment!,
        persistentExerciseExclusionIds: request.persistentExerciseExclusionIds!,
        requestExerciseExclusionIds: request.requestExerciseExclusionIds!,
      );
      if (request.constraintSnapshotSha256 != expectedDigest) {
        issues.add(
          EligibilityIssue._(EligibilityReasonCode.constraintDigestMismatch, {
            'actual': request.constraintSnapshotSha256,
            'expected': expectedDigest,
          }),
        );
      }
    }

    _validateIdList(
      issues,
      request.candidateExerciseIds,
      'candidateExerciseIds',
      catalogIds,
      unknownCode: EligibilityReasonCode.unknownExerciseId,
    );
    final candidateExerciseIds = request.candidateExerciseIds;
    if (candidateExerciseIds != null && candidateExerciseIds.length > 5000) {
      issues.add(
        EligibilityIssue._(EligibilityReasonCode.invalidValue, {
          'field': 'candidateExerciseIds',
        }),
      );
    }
    _validateInventory(issues, request.equipmentInventory);
    _validateIdList(
      issues,
      request.temporarilyUnavailableEquipmentIds,
      'temporarilyUnavailableEquipmentIds',
      ExerciseCatalogValidator.equipmentIds,
    );
    _validateCapabilities(issues, request.functionalCapabilityAssessment);
    _validateIdList(
      issues,
      request.limitationAssessment?.ids,
      'limitationAssessment.ids',
      ExerciseCatalogValidator.limitationConflictIds,
    );
    _validateIdList(
      issues,
      request.persistentExerciseExclusionIds,
      'persistentExerciseExclusionIds',
      catalogIds,
      unknownCode: EligibilityReasonCode.unknownExerciseId,
    );
    _validateIdList(
      issues,
      request.requestExerciseExclusionIds,
      'requestExerciseExclusionIds',
      catalogIds,
      unknownCode: EligibilityReasonCode.unknownExerciseId,
    );
    _validateSafetyState(issues, request, catalogIds);
    return issues;
  }

  void _validateInventory(
    List<EligibilityIssue> issues,
    List<EquipmentInventoryItem>? inventory,
  ) {
    if (inventory == null) return;
    final seenEquipment = <String>{};
    for (final item in inventory) {
      if (!seenEquipment.add(item.equipmentId)) {
        issues.add(
          EligibilityIssue._(EligibilityReasonCode.duplicateInput, {
            'field': 'equipmentInventory',
            'id': item.equipmentId,
          }),
        );
      }
      if (!ExerciseCatalogValidator.equipmentIds.contains(item.equipmentId)) {
        issues.add(
          EligibilityIssue._(EligibilityReasonCode.unknownTaxonomyId, {
            'field': 'equipmentInventory.equipmentId',
            'id': item.equipmentId,
          }),
        );
      }
      if (item.quantity < 1 || item.quantity > 8) {
        issues.add(
          EligibilityIssue._(EligibilityReasonCode.invalidValue, {
            'field': 'equipmentInventory.quantity',
            'id': item.equipmentId,
          }),
        );
      }
      _validateIdList(
        issues,
        item.capabilityIds,
        'equipmentInventory.capabilityIds',
        ExerciseCatalogValidator.equipmentCapabilityIds,
      );
    }
  }

  void _validateCapabilities(
    List<EligibilityIssue> issues,
    FunctionalCapabilityAssessment? assessment,
  ) {
    if (assessment == null) return;
    _validateIdList(
      issues,
      assessment.supportedIds,
      'functionalCapabilityAssessment.supportedIds',
      ExerciseCatalogValidator.functionalCapabilityIds,
    );
    _validateIdList(
      issues,
      assessment.unsupportedIds,
      'functionalCapabilityAssessment.unsupportedIds',
      ExerciseCatalogValidator.functionalCapabilityIds,
    );
    final overlap =
        assessment.supportedIds
            .toSet()
            .intersection(assessment.unsupportedIds.toSet())
            .toList()
          ..sort();
    for (final id in overlap) {
      issues.add(
        EligibilityIssue._(EligibilityReasonCode.duplicateInput, {
          'field': 'functionalCapabilityAssessment',
          'id': id,
        }),
      );
    }
  }

  void _validateSafetyState(
    List<EligibilityIssue> issues,
    ExerciseEligibilityRequest request,
    Set<String> catalogIds,
  ) {
    final state = request.safetyState;
    if (state == null) return;
    if (state.version == null) {
      issues.add(_missing('safetyState.version'));
    } else if (state.version != supportedSafetyStateVersion) {
      issues.add(
        EligibilityIssue._(EligibilityReasonCode.invalidValue, {
          'field': 'safetyState.version',
        }),
      );
    }

    if (state.kind == EligibilitySafetyStateKind.stop) {
      if (state.affectedExerciseId == null) {
        issues.add(_missing('safetyState.affectedExerciseId'));
      } else if (!catalogIds.contains(state.affectedExerciseId)) {
        issues.add(
          EligibilityIssue._(EligibilityReasonCode.unknownExerciseId, {
            'field': 'safetyState.affectedExerciseId',
            'id': state.affectedExerciseId,
          }),
        );
      }
      if (state.restrictions.isNotEmpty) {
        issues.add(
          EligibilityIssue._(EligibilityReasonCode.invalidValue, {
            'field': 'safetyState.restrictions',
          }),
        );
      }
      return;
    }

    if (state.affectedExerciseId != null) {
      issues.add(
        EligibilityIssue._(EligibilityReasonCode.invalidValue, {
          'field': 'safetyState.affectedExerciseId',
        }),
      );
    }
    if (state.kind == EligibilitySafetyStateKind.clear &&
        state.restrictions.isNotEmpty) {
      issues.add(
        EligibilityIssue._(EligibilityReasonCode.invalidValue, {
          'field': 'safetyState.restrictions',
        }),
      );
      return;
    }
    if (state.kind == EligibilitySafetyStateKind.restricted &&
        state.restrictions.isEmpty) {
      issues.add(_missing('safetyState.restrictions'));
      return;
    }

    final seen = <String>{};
    for (final restriction in state.restrictions) {
      final requiredValues = <String, String?>{
        'exerciseId': restriction.exerciseId,
        'constraintSnapshotSha256': restriction.constraintSnapshotSha256,
        'catalogVersion': restriction.catalogVersion,
        'taxonomyVersion': restriction.taxonomyVersion,
        'eligibilityRuleSetVersion': restriction.eligibilityRuleSetVersion,
        'originatingRecommendationId': restriction.originatingRecommendationId,
        'regressionTestReference': restriction.regressionTestReference,
        'reviewReference': restriction.reviewReference,
      };
      for (final entry in requiredValues.entries) {
        if (entry.value == null) {
          issues.add(_missing('safetyState.restrictions.${entry.key}'));
        }
      }
      if (restriction.reviewState == null) {
        issues.add(_missing('safetyState.restrictions.reviewState'));
      }
      final auditReferences = <String, String?>{
        'originatingRecommendationId': restriction.originatingRecommendationId,
        'regressionTestReference': restriction.regressionTestReference,
        'reviewReference': restriction.reviewReference,
      };
      for (final entry in auditReferences.entries) {
        final value = entry.value;
        if (value != null && !_auditReference.hasMatch(value)) {
          issues.add(
            EligibilityIssue._(EligibilityReasonCode.invalidValue, {
              'field': 'safetyState.restrictions.${entry.key}',
            }),
          );
        }
      }
      final exerciseId = restriction.exerciseId;
      if (exerciseId != null && !catalogIds.contains(exerciseId)) {
        issues.add(
          EligibilityIssue._(EligibilityReasonCode.unknownExerciseId, {
            'field': 'safetyState.restrictions.exerciseId',
            'id': exerciseId,
          }),
        );
      }
      final digest = restriction.constraintSnapshotSha256;
      if (digest != null && !_sha256.hasMatch(digest)) {
        issues.add(
          EligibilityIssue._(EligibilityReasonCode.invalidValue, {
            'field': 'safetyState.restrictions.constraintSnapshotSha256',
          }),
        );
      }
      final isStale =
          (restriction.catalogVersion != null &&
              restriction.catalogVersion != request.catalogVersion) ||
          (restriction.taxonomyVersion != null &&
              restriction.taxonomyVersion != request.taxonomyVersion) ||
          (restriction.eligibilityRuleSetVersion != null &&
              restriction.eligibilityRuleSetVersion !=
                  request.eligibilityRuleSetVersion);
      if (isStale) {
        issues.add(
          EligibilityIssue._(EligibilityReasonCode.staleSafetyReference, {
            'exerciseId': exerciseId,
          }),
        );
      }
      final key = '$exerciseId|$digest';
      if (!seen.add(key)) {
        issues.add(
          EligibilityIssue._(EligibilityReasonCode.duplicateInput, {
            'field': 'safetyState.restrictions',
            'id': key,
          }),
        );
      }
    }
  }

  void _validateIdList(
    List<EligibilityIssue> issues,
    List<String>? values,
    String field,
    Set<String> allowed, {
    String unknownCode = EligibilityReasonCode.unknownTaxonomyId,
  }) {
    if (values == null) return;
    final seen = <String>{};
    for (final value in values) {
      if (!seen.add(value)) {
        issues.add(
          EligibilityIssue._(EligibilityReasonCode.duplicateInput, {
            'field': field,
            'id': value,
          }),
        );
      }
      if (!allowed.contains(value)) {
        issues.add(
          EligibilityIssue._(unknownCode, {'field': field, 'id': value}),
        );
      }
    }
  }

  void _mismatch(
    List<EligibilityIssue> issues,
    String? actual,
    String expected,
    String field,
    String code,
  ) {
    if (actual != null && actual != expected) {
      issues.add(
        EligibilityIssue._(code, {
          'actual': actual,
          'expected': expected,
          'field': field,
        }),
      );
    }
  }

  _EligibilityCandidate _projectCandidate(ExerciseCatalogEntry entry) {
    final requirements = entry.equipmentRequirements
        .map(
          (requirement) => _EligibilityEquipmentRequirement(
            equipmentId: requirement.equipmentId,
            quantity: requirement.quantity,
            capabilityIds: Set<String>.of(requirement.capabilityIds),
          ),
        )
        .toList();
    return _EligibilityCandidate(
      id: entry.id,
      isSelectable: entry.isSelectable,
      equipmentRequirements: requirements,
      capabilityIds: Set<String>.of(entry.capabilityIds),
      exclusionTagIds: Set<String>.of(entry.exclusionTagIds),
    );
  }

  EligibilityIssue _missing(String field) => EligibilityIssue._(
    EligibilityReasonCode.requiredInputMissing,
    {'field': field},
  );

  ExerciseEligibilityResult _result(
    ExerciseEligibilityRequest request,
    EligibilityResultStatus status, {
    List<String> eligibleExerciseIds = const [],
    List<CandidateEligibilityEvaluation> candidateEvaluations = const [],
    List<EligibilityIssue> requestIssues = const [],
  }) => ExerciseEligibilityResult._(
    status: status,
    eligibilityRuleSetVersion: request.eligibilityRuleSetVersion,
    schemaVersion: request.schemaVersion,
    catalogVersion: request.catalogVersion,
    taxonomyVersion: request.taxonomyVersion,
    catalogContentSha256: request.catalogContentSha256,
    constraintSnapshotSha256: request.constraintSnapshotSha256,
    catalogValidationReferenceTime: catalogValidator.importedAt,
    eligibleExerciseIds: eligibleExerciseIds,
    candidateEvaluations: candidateEvaluations,
    requestIssues: _sortedEligibilityIssues(requestIssues),
  );
}
