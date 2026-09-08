import 'package:adaptive_workout/domain/exercises/catalog/catalog_integrity.dart';
import 'package:adaptive_workout/domain/exercises/catalog/exercise_catalog.dart';
import 'package:adaptive_workout/domain/exercises/catalog/exercise_catalog_manifest_validator.dart';
import 'package:adaptive_workout/domain/exercises/eligibility/exercise_eligibility.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final evaluator = ExerciseEligibilityEvaluator(
    catalogValidator: ExerciseCatalogManifestValidator(
      importedAt: DateTime.utc(2026, 9, 8, 13),
    ),
  );

  test('eligible candidate passes the complete guarded pipeline', () {
    final entries = <ExerciseCatalogEntry>[_entry(seed: 1)];
    final result = evaluator.evaluate(_request(entries));

    expect(result.status, EligibilityResultStatus.evaluated);
    expect(result.eligibleExerciseIds, <String>['exercise_01']);
    expect(result.candidateEvaluations.single.isEligible, isTrue);
    expect(result.requestIssues, isEmpty);
    expect(result.catalogValidationReferenceTime, DateTime.utc(2026, 9, 8, 13));
    expect(
      result.toJson()['catalogValidationReferenceTime'],
      '2026-09-08T13:00:00Z',
    );
  });

  test('empty candidate list returns an explicit constrained result', () {
    final entries = <ExerciseCatalogEntry>[_entry(seed: 1)];
    final result = evaluator.evaluate(
      _request(entries, candidateIds: const []),
    );

    expect(result.status, EligibilityResultStatus.constrainedNoCandidate);
    expect(result.candidateEvaluations, isEmpty);
    expect(
      result.requestIssues.single.code,
      EligibilityReasonCode.noEligibleExercise,
    );
  });

  test('every required input distinguishes missing from explicit empty', () {
    final entries = <ExerciseCatalogEntry>[_entry(seed: 1)];
    const requiredFields = <String>[
      'eligibilityRuleSetVersion',
      'schemaVersion',
      'catalogVersion',
      'taxonomyVersion',
      'catalogContentSha256',
      'constraintSnapshotSha256',
      'manifest',
      'catalog',
      'candidateExerciseIds',
      'equipmentInventory',
      'temporarilyUnavailableEquipmentIds',
      'functionalCapabilityAssessment',
      'limitationAssessment',
      'persistentExerciseExclusionIds',
      'requestExerciseExclusionIds',
      'safetyState',
    ];

    for (final field in requiredFields) {
      final result = evaluator.evaluate(_request(entries, missingField: field));
      expect(
        result.status,
        EligibilityResultStatus.invalidInput,
        reason: field,
      );
      expect(
        result.requestIssues.map((issue) => issue.code),
        contains(EligibilityReasonCode.requiredInputMissing),
        reason: field,
      );
      expect(result.candidateEvaluations, isEmpty, reason: field);
    }

    final explicitEmpty = evaluator.evaluate(
      _request(entries, candidateIds: const []),
    );
    expect(
      explicitEmpty.status,
      EligibilityResultStatus.constrainedNoCandidate,
    );
  });

  test('duplicate and unknown inputs fail before filtering', () {
    final entries = <ExerciseCatalogEntry>[_entry(seed: 1)];
    final duplicate = evaluator.evaluate(
      _request(entries, candidateIds: const ['exercise_01', 'exercise_01']),
    );
    final unknown = evaluator.evaluate(
      _request(entries, limitations: const ['unknown_limitation']),
    );
    final unknownExercise = evaluator.evaluate(
      _request(entries, candidateIds: const ['unknown_exercise']),
    );

    expect(duplicate.status, EligibilityResultStatus.invalidInput);
    expect(
      duplicate.requestIssues.map((issue) => issue.code),
      contains(EligibilityReasonCode.duplicateInput),
    );
    expect(unknown.status, EligibilityResultStatus.invalidInput);
    expect(
      unknown.requestIssues.map((issue) => issue.code),
      contains(EligibilityReasonCode.unknownTaxonomyId),
    );
    expect(unknownExercise.status, EligibilityResultStatus.invalidInput);
    expect(
      unknownExercise.requestIssues.map((issue) => issue.code),
      contains(EligibilityReasonCode.unknownExerciseId),
    );
    expect(duplicate.candidateEvaluations, isEmpty);
    expect(unknown.candidateEvaluations, isEmpty);
    expect(unknownExercise.candidateEvaluations, isEmpty);
  });

  test('malformed inventory and conflicting capabilities fail closed', () {
    final entries = <ExerciseCatalogEntry>[_entry(seed: 1)];
    final results = <ExerciseEligibilityResult>[
      evaluator.evaluate(
        _request(
          entries,
          inventory: <EquipmentInventoryItem>[
            EquipmentInventoryItem(equipmentId: 'dumbbells', quantity: 1),
            EquipmentInventoryItem(equipmentId: 'dumbbells', quantity: 2),
          ],
        ),
      ),
      evaluator.evaluate(
        _request(
          entries,
          inventory: <EquipmentInventoryItem>[
            EquipmentInventoryItem(
              equipmentId: 'cable_station',
              quantity: 1,
              capabilityIds: const ['rope_attachment', 'rope_attachment'],
            ),
          ],
        ),
      ),
      evaluator.evaluate(
        _request(
          entries,
          inventory: <EquipmentInventoryItem>[
            EquipmentInventoryItem(equipmentId: 'dumbbells', quantity: 0),
          ],
        ),
      ),
      evaluator.evaluate(
        _request(
          entries,
          inventory: <EquipmentInventoryItem>[
            EquipmentInventoryItem(equipmentId: 'dumbbells', quantity: 9),
          ],
        ),
      ),
      evaluator.evaluate(
        _request(
          entries,
          supportedCapabilities: const ['floor_transfer'],
          unsupportedCapabilities: const ['floor_transfer'],
        ),
      ),
    ];

    for (final result in results) {
      expect(result.status, EligibilityResultStatus.invalidInput);
      expect(result.candidateEvaluations, isEmpty);
    }
    expect(
      results[0].requestIssues.map((issue) => issue.code),
      contains(EligibilityReasonCode.duplicateInput),
    );
    expect(
      results[1].requestIssues.map((issue) => issue.code),
      contains(EligibilityReasonCode.duplicateInput),
    );
    expect(
      results[2].requestIssues.map((issue) => issue.code),
      contains(EligibilityReasonCode.invalidValue),
    );
    expect(
      results[3].requestIssues.map((issue) => issue.code),
      contains(EligibilityReasonCode.invalidValue),
    );
    expect(
      results[4].requestIssues.map((issue) => issue.code),
      contains(EligibilityReasonCode.duplicateInput),
    );
  });

  test('invalid complete catalog is unavailable and never partially used', () {
    final entries = <ExerciseCatalogEntry>[_entry(seed: 1)];
    final request = _request(entries);
    final invalidManifest = ExerciseCatalogManifest(
      schemaVersion: request.manifest!.schemaVersion,
      catalogVersion: request.manifest!.catalogVersion,
      upstreamBaseUrl: request.manifest!.upstreamBaseUrl,
      retrievedAt: request.manifest!.retrievedAt,
      sourceRevision: request.manifest!.sourceRevision,
      entryCount: request.manifest!.entryCount,
      contentSha256: '0' * 64,
      importToolVersion: request.manifest!.importToolVersion,
    );
    final result = evaluator.evaluate(
      _request(entries, manifest: invalidManifest),
    );

    expect(result.status, EligibilityResultStatus.catalogUnavailable);
    expect(result.eligibleExerciseIds, isEmpty);
    expect(result.candidateEvaluations, isEmpty);
    expect(
      result.requestIssues.single.code,
      EligibilityReasonCode.catalogInvalid,
    );
  });

  test(
    'stale request identity is invalid while the catalog remains trusted',
    () {
      final entries = <ExerciseCatalogEntry>[_entry(seed: 1)];
      final result = evaluator.evaluate(
        _request(entries, requestCatalogVersion: '2026.09.08.2'),
      );

      expect(result.status, EligibilityResultStatus.invalidInput);
      expect(
        result.requestIssues.map((issue) => issue.code),
        contains(EligibilityReasonCode.catalogVersionMismatch),
      );
      expect(result.candidateEvaluations, isEmpty);
    },
  );

  test('each request identity mismatch has a stable reason', () {
    final entries = <ExerciseCatalogEntry>[_entry(seed: 1)];
    final cases = <String, ExerciseEligibilityRequest>{
      EligibilityReasonCode.schemaVersionMismatch: _request(
        entries,
        requestSchemaVersion: '1.0.1',
      ),
      EligibilityReasonCode.taxonomyVersionMismatch: _request(
        entries,
        requestTaxonomyVersion: 'v1',
      ),
      EligibilityReasonCode.catalogDigestMismatch: _request(
        entries,
        requestCatalogDigest: 'b' * 64,
      ),
      EligibilityReasonCode.eligibilityRulesUnsupported: _request(
        entries,
        eligibilityRuleSetVersion: '1.0.1',
      ),
    };

    for (final entry in cases.entries) {
      final result = evaluator.evaluate(entry.value);
      expect(
        result.status,
        EligibilityResultStatus.invalidInput,
        reason: entry.key,
      );
      expect(
        result.requestIssues.map((issue) => issue.code),
        contains(entry.key),
        reason: entry.key,
      );
      expect(result.candidateEvaluations, isEmpty, reason: entry.key);
    }
  });

  test('pain stop short-circuits ordinary eligibility', () {
    final entries = <ExerciseCatalogEntry>[_entry(seed: 1)];
    final result = evaluator.evaluate(
      _request(
        entries,
        safetyState: EligibilitySafetyState(
          version: '1.0.0',
          kind: EligibilitySafetyStateKind.stop,
          affectedExerciseId: 'exercise_01',
        ),
        persistentExclusions: const ['exercise_01'],
      ),
    );

    expect(result.status, EligibilityResultStatus.safetyStop);
    expect(result.candidateEvaluations, isEmpty);
    expect(
      result.requestIssues.single.code,
      EligibilityReasonCode.painReportRequiresStop,
    );
  });

  test('only an exact current-context safety restriction stops evaluation', () {
    final entries = <ExerciseCatalogEntry>[_entry(seed: 1)];
    final matching = evaluator.evaluate(
      _request(
        entries,
        safetyState: _restrictedState(constraintDigest: _emptyConstraintDigest),
      ),
    );
    final unrelated = evaluator.evaluate(
      _request(
        entries,
        safetyState: _restrictedState(constraintDigest: 'b' * 64),
      ),
    );

    expect(matching.status, EligibilityResultStatus.safetyStop);
    expect(
      matching.requestIssues.single.code,
      EligibilityReasonCode.unresolvedSafetyIncident,
    );
    expect(unrelated.status, EligibilityResultStatus.evaluated);
  });

  test('a forged constraint digest cannot bypass a safety restriction', () {
    final entries = <ExerciseCatalogEntry>[_entry(seed: 1)];
    final result = evaluator.evaluate(
      _request(
        entries,
        requestConstraintDigest: 'b' * 64,
        safetyState: _restrictedState(constraintDigest: _emptyConstraintDigest),
      ),
    );

    expect(result.status, EligibilityResultStatus.invalidInput);
    expect(result.candidateEvaluations, isEmpty);
    expect(
      result.requestIssues.map((issue) => issue.code),
      contains(EligibilityReasonCode.constraintDigestMismatch),
    );
  });

  test('stale safety restriction fails closed', () {
    final entries = <ExerciseCatalogEntry>[_entry(seed: 1)];
    final result = evaluator.evaluate(
      _request(
        entries,
        safetyState: EligibilitySafetyState(
          version: '1.0.0',
          kind: EligibilitySafetyStateKind.restricted,
          restrictions: <SafetyRestrictionReference>[
            SafetyRestrictionReference(
              exerciseId: 'exercise_01',
              constraintSnapshotSha256: _emptyConstraintDigest,
              catalogVersion: '2026.09.07.1',
              taxonomyVersion: 'v2',
              eligibilityRuleSetVersion: '1.0.0',
              originatingRecommendationId: 'recommendation_01',
              regressionTestReference: 'regression_01',
              reviewState: SafetyRestrictionReviewState.unresolved,
              reviewReference: 'review_01',
            ),
          ],
        ),
      ),
    );

    expect(result.status, EligibilityResultStatus.invalidInput);
    expect(
      result.requestIssues.map((issue) => issue.code),
      contains(EligibilityReasonCode.staleSafetyReference),
    );
  });

  test('active safety restriction requires its audit references', () {
    final entries = <ExerciseCatalogEntry>[_entry(seed: 1)];
    final result = evaluator.evaluate(
      _request(
        entries,
        safetyState: EligibilitySafetyState(
          version: '1.0.0',
          kind: EligibilitySafetyStateKind.restricted,
          restrictions: <SafetyRestrictionReference>[
            SafetyRestrictionReference(
              exerciseId: 'exercise_01',
              constraintSnapshotSha256: _emptyConstraintDigest,
              catalogVersion: '2026.09.08.1',
              taxonomyVersion: 'v2',
              eligibilityRuleSetVersion: '1.0.0',
              originatingRecommendationId: null,
              regressionTestReference: null,
              reviewState: null,
              reviewReference: null,
            ),
          ],
        ),
      ),
    );

    expect(result.status, EligibilityResultStatus.invalidInput);
    expect(
      result.requestIssues
          .where(
            (issue) => issue.code == EligibilityReasonCode.requiredInputMissing,
          )
          .length,
      4,
    );
    expect(result.candidateEvaluations, isEmpty);
  });

  test('disabled catalog member is valid but cannot be eligible', () {
    final entries = <ExerciseCatalogEntry>[
      _entry(
        seed: 1,
        availability: ExerciseAvailability.disabled,
        disabledReason: 'Not released.',
      ),
    ];
    final result = evaluator.evaluate(_request(entries));

    expect(result.status, EligibilityResultStatus.constrainedNoCandidate);
    expect(_codes(result.candidateEvaluations.single), <String>[
      EligibilityReasonCode.catalogEntryUnselectable,
    ]);
  });

  test('persistent and request exclusions are both retained in order', () {
    final entries = <ExerciseCatalogEntry>[_entry(seed: 1)];
    final result = evaluator.evaluate(
      _request(
        entries,
        persistentExclusions: const ['exercise_01'],
        requestExclusions: const ['exercise_01'],
      ),
    );

    expect(_codes(result.candidateEvaluations.single), <String>[
      EligibilityReasonCode.exerciseExcludedPersistent,
      EligibilityReasonCode.exerciseExcludedForRequest,
    ]);
  });

  test('limitation and tri-state capability failures are all retained', () {
    final entries = <ExerciseCatalogEntry>[
      _entry(
        seed: 1,
        capabilityIds: const {
          'loaded_hip_hinge',
          'sustained_grip',
          'standing_unsupported',
        },
        exclusionTagIds: const {
          'avoid_loaded_hip_hinge',
          'avoid_sustained_grip',
        },
      ),
    ];
    final result = evaluator.evaluate(
      _request(
        entries,
        supportedCapabilities: const ['standing_unsupported'],
        unsupportedCapabilities: const ['loaded_hip_hinge'],
        limitations: const ['avoid_sustained_grip', 'avoid_loaded_hip_hinge'],
      ),
    );

    expect(_codes(result.candidateEvaluations.single), <String>[
      EligibilityReasonCode.limitationConflict,
      EligibilityReasonCode.limitationConflict,
      EligibilityReasonCode.functionalCapabilityUnsupported,
      EligibilityReasonCode.functionalCapabilityUnconfirmed,
    ]);
  });

  test(
    'equipment quantity, item capability, and temporary state all apply',
    () {
      final entries = <ExerciseCatalogEntry>[
        _entry(
          seed: 1,
          equipmentRequirements: const <EquipmentRequirement>[
            EquipmentRequirement(
              equipmentId: 'cable_station',
              quantity: 2,
              capabilityIds: {'rope_attachment'},
            ),
          ],
        ),
      ];
      final result = evaluator.evaluate(
        _request(
          entries,
          inventory: <EquipmentInventoryItem>[
            EquipmentInventoryItem(equipmentId: 'cable_station', quantity: 1),
          ],
          temporarilyUnavailable: const ['cable_station'],
        ),
      );

      expect(_codes(result.candidateEvaluations.single), <String>[
        EligibilityReasonCode.equipmentQuantityInsufficient,
        EligibilityReasonCode.equipmentCapabilityMissing,
        EligibilityReasonCode.equipmentTemporarilyUnavailable,
      ]);
    },
  );

  test('equal or greater equipment quantity satisfies the requirement', () {
    final entries = <ExerciseCatalogEntry>[
      _entry(
        seed: 1,
        equipmentRequirements: const <EquipmentRequirement>[
          EquipmentRequirement(equipmentId: 'flat_bench', quantity: 1),
        ],
      ),
    ];

    for (final quantity in <int>[1, 2]) {
      final result = evaluator.evaluate(
        _request(
          entries,
          inventory: <EquipmentInventoryItem>[
            EquipmentInventoryItem(
              equipmentId: 'flat_bench',
              quantity: quantity,
            ),
          ],
        ),
      );
      expect(result.status, EligibilityResultStatus.evaluated);
    }
  });

  test('equipment capabilities are item-scoped', () {
    final entries = <ExerciseCatalogEntry>[
      _entry(
        seed: 1,
        equipmentRequirements: const <EquipmentRequirement>[
          EquipmentRequirement(
            equipmentId: 'cable_station',
            quantity: 1,
            capabilityIds: {'rope_attachment'},
          ),
        ],
      ),
    ];
    final result = evaluator.evaluate(
      _request(
        entries,
        inventory: <EquipmentInventoryItem>[
          EquipmentInventoryItem(equipmentId: 'cable_station', quantity: 1),
          EquipmentInventoryItem(
            equipmentId: 'lat_pulldown_machine',
            quantity: 1,
            capabilityIds: const ['rope_attachment'],
          ),
        ],
      ),
    );

    expect(_codes(result.candidateEvaluations.single), <String>[
      EligibilityReasonCode.equipmentCapabilityMissing,
    ]);
  });

  test('missing and temporarily unavailable equipment report both facts', () {
    final entries = <ExerciseCatalogEntry>[
      _entry(
        seed: 1,
        equipmentRequirements: const <EquipmentRequirement>[
          EquipmentRequirement(equipmentId: 'flat_bench', quantity: 1),
        ],
      ),
    ];
    final result = evaluator.evaluate(
      _request(entries, temporarilyUnavailable: const ['flat_bench']),
    );

    expect(_codes(result.candidateEvaluations.single), <String>[
      EligibilityReasonCode.equipmentMissing,
      EligibilityReasonCode.equipmentTemporarilyUnavailable,
    ]);
  });

  test('eligible and ineligible candidates remain independent', () {
    final entries = <ExerciseCatalogEntry>[
      _entry(seed: 1),
      _entry(
        seed: 2,
        equipmentRequirements: const <EquipmentRequirement>[
          EquipmentRequirement(equipmentId: 'dumbbells', quantity: 2),
        ],
      ),
    ];
    final result = evaluator.evaluate(_request(entries));

    expect(result.status, EligibilityResultStatus.evaluated);
    expect(result.eligibleExerciseIds, <String>['exercise_01']);
    expect(result.candidateEvaluations[0].isEligible, isTrue);
    expect(_codes(result.candidateEvaluations[1]), <String>[
      EligibilityReasonCode.equipmentMissing,
    ]);
  });

  test('candidate and constraint ordering cannot change canonical output', () {
    final entries = <ExerciseCatalogEntry>[_entry(seed: 2), _entry(seed: 1)];
    final forward = evaluator.evaluate(
      _request(
        entries,
        candidateIds: const ['exercise_02', 'exercise_01'],
        limitations: const ['avoid_sustained_grip', 'avoid_loaded_hip_hinge'],
      ),
    );
    final reversedEntries = entries.reversed.toList();
    final reversed = evaluator.evaluate(
      _request(
        reversedEntries,
        candidateIds: const ['exercise_01', 'exercise_02'],
        limitations: const ['avoid_loaded_hip_hinge', 'avoid_sustained_grip'],
      ),
    );

    expect(reversed.toCanonicalJson(), forward.toCanonicalJson());
    expect(
      forward.candidateEvaluations.map((value) => value.exerciseId),
      <String>['exercise_01', 'exercise_02'],
    );
  });

  test('unrelated constraints cannot alter candidate eligibility facts', () {
    final entries = <ExerciseCatalogEntry>[_entry(seed: 1)];
    final baseline = evaluator.evaluate(_request(entries));
    final withUnrelated = evaluator.evaluate(
      _request(
        entries,
        inventory: <EquipmentInventoryItem>[
          EquipmentInventoryItem(equipmentId: 'dumbbells', quantity: 8),
        ],
        supportedCapabilities: const ['floor_transfer'],
        limitations: const ['avoid_overhead_arm_position'],
      ),
    );

    expect(
      withUnrelated.candidateEvaluations.single.toJson(),
      baseline.candidateEvaluations.single.toJson(),
    );
  });

  test('presentation content cannot alter eligibility facts', () {
    final originalEntries = <ExerciseCatalogEntry>[_entry(seed: 1)];
    final renamedEntries = <ExerciseCatalogEntry>[
      _entry(seed: 1, name: 'Completely different display name'),
    ];
    final original = evaluator.evaluate(_request(originalEntries));
    final renamed = evaluator.evaluate(_request(renamedEntries));

    expect(
      renamed.candidateEvaluations.single.toJson(),
      original.candidateEvaluations.single.toJson(),
    );
  });

  test(
    'constraint digest has a fixed non-empty vector and canonical order',
    () {
      final forward = eligibilityConstraintSnapshotSha256(
        equipmentInventory: <EquipmentInventoryItem>[
          EquipmentInventoryItem(
            equipmentId: 'dumbbells',
            quantity: 2,
            capabilityIds: const ['incremental_loading'],
          ),
          EquipmentInventoryItem(
            equipmentId: 'cable_station',
            quantity: 1,
            capabilityIds: const ['rope_attachment', 'high_pulley'],
          ),
        ],
        temporarilyUnavailableEquipmentIds: const ['cable_station'],
        functionalCapabilityAssessment: FunctionalCapabilityAssessment(
          supportedIds: const ['standing_unsupported', 'floor_transfer'],
          unsupportedIds: const ['sustained_grip'],
        ),
        limitationAssessment: LimitationAssessment(
          ids: const ['avoid_sustained_grip'],
        ),
        persistentExerciseExclusionIds: const ['exercise_02'],
        requestExerciseExclusionIds: const ['exercise_01'],
      );
      final permuted = eligibilityConstraintSnapshotSha256(
        equipmentInventory: <EquipmentInventoryItem>[
          EquipmentInventoryItem(
            equipmentId: 'cable_station',
            quantity: 1,
            capabilityIds: const ['high_pulley', 'rope_attachment'],
          ),
          EquipmentInventoryItem(
            equipmentId: 'dumbbells',
            quantity: 2,
            capabilityIds: const ['incremental_loading'],
          ),
        ],
        temporarilyUnavailableEquipmentIds: const ['cable_station'],
        functionalCapabilityAssessment: FunctionalCapabilityAssessment(
          supportedIds: const ['floor_transfer', 'standing_unsupported'],
          unsupportedIds: const ['sustained_grip'],
        ),
        limitationAssessment: LimitationAssessment(
          ids: const ['avoid_sustained_grip'],
        ),
        persistentExerciseExclusionIds: const ['exercise_02'],
        requestExerciseExclusionIds: const ['exercise_01'],
      );

      expect(
        forward,
        '36c103763b7324555b86d8113c4a9fc17d5f3370671537c8e2e38d274d704326',
      );
      expect(permuted, forward);

      String digest({
        List<EquipmentInventoryItem>? inventory,
        List<String>? temporary,
        List<String>? supported,
        List<String>? unsupported,
        List<String>? limitations,
        List<String>? persistent,
        List<String>? request,
      }) => eligibilityConstraintSnapshotSha256(
        equipmentInventory:
            inventory ??
            <EquipmentInventoryItem>[
              EquipmentInventoryItem(
                equipmentId: 'dumbbells',
                quantity: 2,
                capabilityIds: const ['incremental_loading'],
              ),
              EquipmentInventoryItem(
                equipmentId: 'cable_station',
                quantity: 1,
                capabilityIds: const ['rope_attachment', 'high_pulley'],
              ),
            ],
        temporarilyUnavailableEquipmentIds:
            temporary ?? const ['cable_station'],
        functionalCapabilityAssessment: FunctionalCapabilityAssessment(
          supportedIds:
              supported ?? const ['standing_unsupported', 'floor_transfer'],
          unsupportedIds: unsupported ?? const ['sustained_grip'],
        ),
        limitationAssessment: LimitationAssessment(
          ids: limitations ?? const ['avoid_sustained_grip'],
        ),
        persistentExerciseExclusionIds: persistent ?? const ['exercise_02'],
        requestExerciseExclusionIds: request ?? const ['exercise_01'],
      );

      final changed = <String>[
        digest(
          inventory: <EquipmentInventoryItem>[
            EquipmentInventoryItem(
              equipmentId: 'dumbbells',
              quantity: 3,
              capabilityIds: const ['incremental_loading'],
            ),
          ],
        ),
        digest(temporary: const ['flat_bench']),
        digest(supported: const ['floor_transfer']),
        digest(unsupported: const ['loaded_hip_hinge']),
        digest(limitations: const ['avoid_loaded_hip_hinge']),
        digest(persistent: const ['exercise_01']),
        digest(request: const ['exercise_02']),
      ];
      expect(changed, everyElement(isNot(forward)));
      expect(changed.toSet(), hasLength(changed.length));
    },
  );

  test('one candidate retains every hard failure in canonical order', () {
    final entries = <ExerciseCatalogEntry>[
      _entry(
        seed: 1,
        availability: ExerciseAvailability.disabled,
        disabledReason: 'Synthetic disabled entry.',
        capabilityIds: const {'loaded_hip_hinge', 'sustained_grip'},
        exclusionTagIds: const {
          'avoid_loaded_hip_hinge',
          'avoid_sustained_grip',
        },
        equipmentRequirements: const <EquipmentRequirement>[
          EquipmentRequirement(equipmentId: 'standard_barbell', quantity: 1),
          EquipmentRequirement(equipmentId: 'dumbbells', quantity: 2),
          EquipmentRequirement(
            equipmentId: 'cable_station',
            quantity: 1,
            capabilityIds: {'rope_attachment'},
          ),
          EquipmentRequirement(equipmentId: 'flat_bench', quantity: 1),
        ],
      ),
    ];
    final result = evaluator.evaluate(
      _request(
        entries,
        inventory: <EquipmentInventoryItem>[
          EquipmentInventoryItem(equipmentId: 'flat_bench', quantity: 1),
          EquipmentInventoryItem(equipmentId: 'dumbbells', quantity: 1),
          EquipmentInventoryItem(equipmentId: 'cable_station', quantity: 1),
        ],
        temporarilyUnavailable: const ['flat_bench'],
        unsupportedCapabilities: const ['loaded_hip_hinge'],
        limitations: const ['avoid_sustained_grip', 'avoid_loaded_hip_hinge'],
        persistentExclusions: const ['exercise_01'],
        requestExclusions: const ['exercise_01'],
      ),
    );

    expect(result.status, EligibilityResultStatus.constrainedNoCandidate);
    final evaluation = result.candidateEvaluations.single;
    expect(_codes(evaluation), <String>[
      EligibilityReasonCode.catalogEntryUnselectable,
      EligibilityReasonCode.exerciseExcludedPersistent,
      EligibilityReasonCode.exerciseExcludedForRequest,
      EligibilityReasonCode.limitationConflict,
      EligibilityReasonCode.limitationConflict,
      EligibilityReasonCode.functionalCapabilityUnsupported,
      EligibilityReasonCode.functionalCapabilityUnconfirmed,
      EligibilityReasonCode.equipmentMissing,
      EligibilityReasonCode.equipmentQuantityInsufficient,
      EligibilityReasonCode.equipmentCapabilityMissing,
      EligibilityReasonCode.equipmentTemporarilyUnavailable,
    ]);
    expect(
      evaluation.reasons
          .where(
            (reason) => reason.code == EligibilityReasonCode.limitationConflict,
          )
          .map((reason) => reason.parameters['limitationId']),
      <String>['avoid_loaded_hip_hinge', 'avoid_sustained_grip'],
    );
    final quantity = evaluation.reasons.singleWhere(
      (reason) =>
          reason.code == EligibilityReasonCode.equipmentQuantityInsufficient,
    );
    expect(quantity.parameters['requiredQuantity'], 2);
    expect(quantity.parameters['availableQuantity'], 1);
  });

  test('every hard constraint is monotonic from an eligible baseline', () {
    final eligibleEntry = _entry(seed: 1);
    final cases = <({String name, ExerciseEligibilityResult result})>[
      (
        name: 'catalog selectability',
        result: evaluator.evaluate(
          _request(<ExerciseCatalogEntry>[
            _entry(
              seed: 1,
              availability: ExerciseAvailability.disabled,
              disabledReason: 'Synthetic disabled entry.',
            ),
          ]),
        ),
      ),
      (
        name: 'persistent exclusion',
        result: evaluator.evaluate(
          _request(
            <ExerciseCatalogEntry>[eligibleEntry],
            persistentExclusions: const ['exercise_01'],
          ),
        ),
      ),
      (
        name: 'request exclusion',
        result: evaluator.evaluate(
          _request(
            <ExerciseCatalogEntry>[eligibleEntry],
            requestExclusions: const ['exercise_01'],
          ),
        ),
      ),
      (
        name: 'limitation',
        result: evaluator.evaluate(
          _request(
            <ExerciseCatalogEntry>[
              _entry(seed: 1, exclusionTagIds: const {'avoid_sustained_grip'}),
            ],
            limitations: const ['avoid_sustained_grip'],
          ),
        ),
      ),
      (
        name: 'unsupported capability',
        result: evaluator.evaluate(
          _request(
            <ExerciseCatalogEntry>[
              _entry(seed: 1, capabilityIds: const {'sustained_grip'}),
            ],
            unsupportedCapabilities: const ['sustained_grip'],
          ),
        ),
      ),
      (
        name: 'unconfirmed capability',
        result: evaluator.evaluate(
          _request(<ExerciseCatalogEntry>[
            _entry(seed: 1, capabilityIds: const {'sustained_grip'}),
          ]),
        ),
      ),
      (
        name: 'missing equipment',
        result: evaluator.evaluate(
          _request(<ExerciseCatalogEntry>[
            _entry(
              seed: 1,
              equipmentRequirements: const [
                EquipmentRequirement(equipmentId: 'flat_bench', quantity: 1),
              ],
            ),
          ]),
        ),
      ),
      (
        name: 'insufficient equipment',
        result: evaluator.evaluate(
          _request(
            <ExerciseCatalogEntry>[
              _entry(
                seed: 1,
                equipmentRequirements: const [
                  EquipmentRequirement(equipmentId: 'dumbbells', quantity: 2),
                ],
              ),
            ],
            inventory: <EquipmentInventoryItem>[
              EquipmentInventoryItem(equipmentId: 'dumbbells', quantity: 1),
            ],
          ),
        ),
      ),
      (
        name: 'missing equipment capability',
        result: evaluator.evaluate(
          _request(
            <ExerciseCatalogEntry>[
              _entry(
                seed: 1,
                equipmentRequirements: const [
                  EquipmentRequirement(
                    equipmentId: 'cable_station',
                    quantity: 1,
                    capabilityIds: {'rope_attachment'},
                  ),
                ],
              ),
            ],
            inventory: <EquipmentInventoryItem>[
              EquipmentInventoryItem(equipmentId: 'cable_station', quantity: 1),
            ],
          ),
        ),
      ),
      (
        name: 'temporary equipment',
        result: evaluator.evaluate(
          _request(
            <ExerciseCatalogEntry>[
              _entry(
                seed: 1,
                equipmentRequirements: const [
                  EquipmentRequirement(equipmentId: 'flat_bench', quantity: 1),
                ],
              ),
            ],
            inventory: <EquipmentInventoryItem>[
              EquipmentInventoryItem(equipmentId: 'flat_bench', quantity: 1),
            ],
            temporarilyUnavailable: const ['flat_bench'],
          ),
        ),
      ),
      (
        name: 'safety restriction',
        result: evaluator.evaluate(
          _request(
            <ExerciseCatalogEntry>[eligibleEntry],
            safetyState: _restrictedState(
              constraintDigest: _emptyConstraintDigest,
            ),
          ),
        ),
      ),
    ];

    final baselines = <ExerciseEligibilityResult>[
      evaluator.evaluate(_request(<ExerciseCatalogEntry>[eligibleEntry])),
      evaluator.evaluate(_request(<ExerciseCatalogEntry>[eligibleEntry])),
      evaluator.evaluate(_request(<ExerciseCatalogEntry>[eligibleEntry])),
      evaluator.evaluate(
        _request(<ExerciseCatalogEntry>[
          _entry(seed: 1, exclusionTagIds: const {'avoid_sustained_grip'}),
        ]),
      ),
      evaluator.evaluate(
        _request(
          <ExerciseCatalogEntry>[
            _entry(seed: 1, capabilityIds: const {'sustained_grip'}),
          ],
          supportedCapabilities: const ['sustained_grip'],
        ),
      ),
      evaluator.evaluate(
        _request(
          <ExerciseCatalogEntry>[
            _entry(seed: 1, capabilityIds: const {'sustained_grip'}),
          ],
          supportedCapabilities: const ['sustained_grip'],
        ),
      ),
      evaluator.evaluate(
        _request(
          <ExerciseCatalogEntry>[
            _entry(
              seed: 1,
              equipmentRequirements: const [
                EquipmentRequirement(equipmentId: 'flat_bench', quantity: 1),
              ],
            ),
          ],
          inventory: <EquipmentInventoryItem>[
            EquipmentInventoryItem(equipmentId: 'flat_bench', quantity: 1),
          ],
        ),
      ),
      evaluator.evaluate(
        _request(
          <ExerciseCatalogEntry>[
            _entry(
              seed: 1,
              equipmentRequirements: const [
                EquipmentRequirement(equipmentId: 'dumbbells', quantity: 2),
              ],
            ),
          ],
          inventory: <EquipmentInventoryItem>[
            EquipmentInventoryItem(equipmentId: 'dumbbells', quantity: 2),
          ],
        ),
      ),
      evaluator.evaluate(
        _request(
          <ExerciseCatalogEntry>[
            _entry(
              seed: 1,
              equipmentRequirements: const [
                EquipmentRequirement(
                  equipmentId: 'cable_station',
                  quantity: 1,
                  capabilityIds: {'rope_attachment'},
                ),
              ],
            ),
          ],
          inventory: <EquipmentInventoryItem>[
            EquipmentInventoryItem(
              equipmentId: 'cable_station',
              quantity: 1,
              capabilityIds: const ['rope_attachment'],
            ),
          ],
        ),
      ),
      evaluator.evaluate(
        _request(
          <ExerciseCatalogEntry>[
            _entry(
              seed: 1,
              equipmentRequirements: const [
                EquipmentRequirement(equipmentId: 'flat_bench', quantity: 1),
              ],
            ),
          ],
          inventory: <EquipmentInventoryItem>[
            EquipmentInventoryItem(equipmentId: 'flat_bench', quantity: 1),
          ],
        ),
      ),
      evaluator.evaluate(_request(<ExerciseCatalogEntry>[eligibleEntry])),
    ];

    for (final indexed in cases.indexed) {
      final testCase = indexed.$2;
      expect(
        baselines[indexed.$1].status,
        EligibilityResultStatus.evaluated,
        reason: '${testCase.name} baseline',
      );
      expect(
        testCase.result.status,
        isNot(EligibilityResultStatus.evaluated),
        reason: testCase.name,
      );
      expect(
        testCase.result.eligibleExerciseIds,
        isEmpty,
        reason: testCase.name,
      );
    }
  });

  test('invalid safety states and references fail before filtering', () {
    final entries = <ExerciseCatalogEntry>[_entry(seed: 1)];
    final invalidStates = <EligibilitySafetyState>[
      EligibilitySafetyState(
        version: '2.0.0',
        kind: EligibilitySafetyStateKind.clear,
      ),
      EligibilitySafetyState(
        version: '1.0.0',
        kind: EligibilitySafetyStateKind.stop,
      ),
      EligibilitySafetyState(
        version: '1.0.0',
        kind: EligibilitySafetyStateKind.clear,
        affectedExerciseId: 'exercise_01',
      ),
      EligibilitySafetyState(
        version: '1.0.0',
        kind: EligibilitySafetyStateKind.clear,
        restrictions: <SafetyRestrictionReference>[_restriction()],
      ),
      EligibilitySafetyState(
        version: '1.0.0',
        kind: EligibilitySafetyStateKind.restricted,
      ),
      EligibilitySafetyState(
        version: '1.0.0',
        kind: EligibilitySafetyStateKind.restricted,
        restrictions: <SafetyRestrictionReference>[
          _restriction(constraintDigest: 'not-a-digest'),
        ],
      ),
      EligibilitySafetyState(
        version: '1.0.0',
        kind: EligibilitySafetyStateKind.restricted,
        restrictions: <SafetyRestrictionReference>[
          _restriction(exerciseId: 'unknown_exercise'),
        ],
      ),
      EligibilitySafetyState(
        version: '1.0.0',
        kind: EligibilitySafetyStateKind.restricted,
        restrictions: <SafetyRestrictionReference>[
          _restriction(taxonomyVersion: 'v1'),
        ],
      ),
      EligibilitySafetyState(
        version: '1.0.0',
        kind: EligibilitySafetyStateKind.restricted,
        restrictions: <SafetyRestrictionReference>[
          _restriction(eligibilityRuleSetVersion: '2.0.0'),
        ],
      ),
      EligibilitySafetyState(
        version: '1.0.0',
        kind: EligibilitySafetyStateKind.restricted,
        restrictions: <SafetyRestrictionReference>[
          _restriction(originatingRecommendationId: ''),
        ],
      ),
      EligibilitySafetyState(
        version: '1.0.0',
        kind: EligibilitySafetyStateKind.restricted,
        restrictions: <SafetyRestrictionReference>[
          _restriction(),
          _restriction(),
        ],
      ),
    ];

    for (final state in invalidStates) {
      final result = evaluator.evaluate(_request(entries, safetyState: state));
      expect(result.status, EligibilityResultStatus.invalidInput);
      expect(result.candidateEvaluations, isEmpty);
      expect(result.requestIssues, isNotEmpty);
    }
  });

  test('duplicates and unknown IDs fail in every core input collection', () {
    final entries = <ExerciseCatalogEntry>[_entry(seed: 1)];
    final cases = <ExerciseEligibilityResult>[
      evaluator.evaluate(
        _request(
          entries,
          temporarilyUnavailable: const ['flat_bench', 'flat_bench'],
        ),
      ),
      evaluator.evaluate(
        _request(entries, temporarilyUnavailable: const ['unknown_equipment']),
      ),
      evaluator.evaluate(
        _request(
          entries,
          supportedCapabilities: const ['floor_transfer', 'floor_transfer'],
        ),
      ),
      evaluator.evaluate(
        _request(entries, supportedCapabilities: const ['unknown_capability']),
      ),
      evaluator.evaluate(
        _request(
          entries,
          unsupportedCapabilities: const ['sustained_grip', 'sustained_grip'],
        ),
      ),
      evaluator.evaluate(
        _request(
          entries,
          limitations: const ['avoid_sustained_grip', 'avoid_sustained_grip'],
        ),
      ),
      evaluator.evaluate(
        _request(
          entries,
          persistentExclusions: const ['exercise_01', 'exercise_01'],
        ),
      ),
      evaluator.evaluate(
        _request(entries, persistentExclusions: const ['unknown_exercise']),
      ),
      evaluator.evaluate(
        _request(
          entries,
          requestExclusions: const ['exercise_01', 'exercise_01'],
        ),
      ),
      evaluator.evaluate(
        _request(entries, requestExclusions: const ['unknown_exercise']),
      ),
      evaluator.evaluate(
        _request(
          entries,
          inventory: <EquipmentInventoryItem>[
            EquipmentInventoryItem(
              equipmentId: 'unknown_equipment',
              quantity: 1,
            ),
          ],
        ),
      ),
      evaluator.evaluate(
        _request(
          entries,
          inventory: <EquipmentInventoryItem>[
            EquipmentInventoryItem(
              equipmentId: 'cable_station',
              quantity: 1,
              capabilityIds: const ['unknown_capability'],
            ),
          ],
        ),
      ),
    ];

    for (final result in cases) {
      expect(result.status, EligibilityResultStatus.invalidInput);
      expect(result.candidateEvaluations, isEmpty);
      expect(result.requestIssues, isNotEmpty);
    }
  });
}

final _emptyConstraintDigest = eligibilityConstraintSnapshotSha256(
  equipmentInventory: const <EquipmentInventoryItem>[],
  temporarilyUnavailableEquipmentIds: const <String>[],
  functionalCapabilityAssessment: FunctionalCapabilityAssessment(),
  limitationAssessment: LimitationAssessment(),
  persistentExerciseExclusionIds: const <String>[],
  requestExerciseExclusionIds: const <String>[],
);

List<String> _codes(CandidateEligibilityEvaluation evaluation) =>
    evaluation.reasons.map((reason) => reason.code).toList();

EligibilitySafetyState _restrictedState({required String constraintDigest}) =>
    EligibilitySafetyState(
      version: '1.0.0',
      kind: EligibilitySafetyStateKind.restricted,
      restrictions: <SafetyRestrictionReference>[
        SafetyRestrictionReference(
          exerciseId: 'exercise_01',
          constraintSnapshotSha256: constraintDigest,
          catalogVersion: '2026.09.08.1',
          taxonomyVersion: 'v2',
          eligibilityRuleSetVersion: '1.0.0',
          originatingRecommendationId: 'recommendation_01',
          regressionTestReference: 'regression_01',
          reviewState: SafetyRestrictionReviewState.unresolved,
          reviewReference: 'review_01',
        ),
      ],
    );

SafetyRestrictionReference _restriction({
  String exerciseId = 'exercise_01',
  String? constraintDigest,
  String catalogVersion = '2026.09.08.1',
  String taxonomyVersion = 'v2',
  String eligibilityRuleSetVersion = '1.0.0',
  String originatingRecommendationId = 'recommendation_01',
}) => SafetyRestrictionReference(
  exerciseId: exerciseId,
  constraintSnapshotSha256: constraintDigest ?? _emptyConstraintDigest,
  catalogVersion: catalogVersion,
  taxonomyVersion: taxonomyVersion,
  eligibilityRuleSetVersion: eligibilityRuleSetVersion,
  originatingRecommendationId: originatingRecommendationId,
  regressionTestReference: 'regression_01',
  reviewState: SafetyRestrictionReviewState.unresolved,
  reviewReference: 'review_01',
);

ExerciseEligibilityRequest _request(
  List<ExerciseCatalogEntry> entries, {
  ExerciseCatalogManifest? manifest,
  String eligibilityRuleSetVersion = '1.0.0',
  String? requestSchemaVersion,
  String requestCatalogVersion = '2026.09.08.1',
  String? requestTaxonomyVersion,
  String? requestCatalogDigest,
  String? requestConstraintDigest,
  List<String>? candidateIds,
  List<EquipmentInventoryItem> inventory = const [],
  List<String> temporarilyUnavailable = const [],
  List<String> supportedCapabilities = const [],
  List<String> unsupportedCapabilities = const [],
  List<String> limitations = const [],
  List<String> persistentExclusions = const [],
  List<String> requestExclusions = const [],
  EligibilitySafetyState? safetyState,
  String? missingField,
}) {
  final actualManifest = manifest ?? _manifest(entries);
  final actualConstraintDigest = eligibilityConstraintSnapshotSha256(
    equipmentInventory: inventory,
    temporarilyUnavailableEquipmentIds: temporarilyUnavailable,
    functionalCapabilityAssessment: FunctionalCapabilityAssessment(
      supportedIds: supportedCapabilities,
      unsupportedIds: unsupportedCapabilities,
    ),
    limitationAssessment: LimitationAssessment(ids: limitations),
    persistentExerciseExclusionIds: persistentExclusions,
    requestExerciseExclusionIds: requestExclusions,
  );
  return ExerciseEligibilityRequest(
    eligibilityRuleSetVersion: missingField == 'eligibilityRuleSetVersion'
        ? null
        : eligibilityRuleSetVersion,
    schemaVersion: missingField == 'schemaVersion'
        ? null
        : requestSchemaVersion ?? actualManifest.schemaVersion,
    catalogVersion: missingField == 'catalogVersion'
        ? null
        : requestCatalogVersion,
    taxonomyVersion: missingField == 'taxonomyVersion'
        ? null
        : requestTaxonomyVersion ?? actualManifest.taxonomyVersion,
    catalogContentSha256: missingField == 'catalogContentSha256'
        ? null
        : requestCatalogDigest ?? actualManifest.contentSha256,
    constraintSnapshotSha256: missingField == 'constraintSnapshotSha256'
        ? null
        : requestConstraintDigest ?? actualConstraintDigest,
    manifest: missingField == 'manifest' ? null : actualManifest,
    catalog: missingField == 'catalog' ? null : entries,
    candidateExerciseIds: missingField == 'candidateExerciseIds'
        ? null
        : candidateIds ?? entries.map((entry) => entry.id).toList(),
    equipmentInventory: missingField == 'equipmentInventory' ? null : inventory,
    temporarilyUnavailableEquipmentIds:
        missingField == 'temporarilyUnavailableEquipmentIds'
        ? null
        : temporarilyUnavailable,
    functionalCapabilityAssessment:
        missingField == 'functionalCapabilityAssessment'
        ? null
        : FunctionalCapabilityAssessment(
            supportedIds: supportedCapabilities,
            unsupportedIds: unsupportedCapabilities,
          ),
    limitationAssessment: missingField == 'limitationAssessment'
        ? null
        : LimitationAssessment(ids: limitations),
    persistentExerciseExclusionIds:
        missingField == 'persistentExerciseExclusionIds'
        ? null
        : persistentExclusions,
    requestExerciseExclusionIds: missingField == 'requestExerciseExclusionIds'
        ? null
        : requestExclusions,
    safetyState: missingField == 'safetyState'
        ? null
        : safetyState ??
              EligibilitySafetyState(
                version: '1.0.0',
                kind: EligibilitySafetyStateKind.clear,
              ),
  );
}

ExerciseCatalogManifest _manifest(List<ExerciseCatalogEntry> entries) =>
    ExerciseCatalogManifest(
      schemaVersion: '1.0.0',
      catalogVersion: '2026.09.08.1',
      upstreamBaseUrl: Uri.parse('https://wger.de/api/v2/'),
      retrievedAt: DateTime.utc(2026, 9, 8, 12),
      sourceRevision: null,
      entryCount: entries.length,
      contentSha256: sha256Hex(canonicalCatalogEntriesBytes(entries)),
      importToolVersion: '1.0.0',
    );

ExerciseCatalogEntry _entry({
  required int seed,
  List<EquipmentRequirement> equipmentRequirements = const [],
  Set<String> capabilityIds = const {},
  Set<String> exclusionTagIds = const {},
  ExerciseAvailability availability = ExerciseAvailability.enabled,
  String? disabledReason,
  String? name,
}) {
  final approved = CatalogReview(
    status: ReviewStatus.approved,
    reviewerId: 'reviewer_one',
    reviewedAt: DateTime.utc(2026, 9, 8, 10),
    evidenceReference: 'docs/reviews/example.md',
  );
  final attribution = CatalogAttribution(
    licenseId: 'cc-by-4.0',
    licenseUrl: Uri.parse('https://creativecommons.org/licenses/by/4.0/'),
    licenseAuthor: 'Example author',
    licenseTitle: 'Example title',
    attributionSourceUrl: Uri.parse(
      'https://wger.de/api/v2/exerciseinfo/$seed/',
    ),
  );
  final suffix = seed.toString().padLeft(12, '0');
  final translationSuffix = (seed + 100).toString().padLeft(12, '0');
  return ExerciseCatalogEntry(
    id: 'exercise_${seed.toString().padLeft(2, '0')}',
    wgerBaseId: seed,
    wgerBaseUuid: '10000000-0000-4000-8000-$suffix',
    wgerTranslationId: seed + 100,
    wgerTranslationUuid: '20000000-0000-4000-8000-$translationSuffix',
    wgerApiUrl: Uri.parse('https://wger.de/api/v2/exerciseinfo/$seed/'),
    wgerPageUrl: Uri.parse('https://wger.de/en/exercise/${seed + 100}/view'),
    sourceModifiedAt: DateTime.utc(2026, 9, 8, 9),
    name: name ?? 'Synthetic exercise $seed',
    instructions: 'Synthetic test-only instructions.',
    movementPatternIds: const {'horizontal_push'},
    primaryMuscleIds: const {'chest'},
    equipmentRequirements: equipmentRequirements,
    laterality: Laterality.bilateral,
    trackingMode: TrackingMode.loadReps,
    capabilityIds: capabilityIds,
    exclusionTagIds: exclusionTagIds,
    variationGroupId: null,
    benchmark: null,
    baseAttribution: attribution,
    translationAttribution: attribution,
    wasModified: false,
    modificationNote: null,
    productReview: approved,
    scienceReview: approved,
    safetyReview: approved,
    equipmentReview: approved,
    licenseReview: approved,
    availability: availability,
    disabledReason: disabledReason,
  );
}
