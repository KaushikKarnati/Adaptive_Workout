import Foundation
import WorkoutPersistence
import XCTest

@testable import WorkoutDomain

final class EngineCatalogTests: XCTestCase {
  let date = BenchmarkCatalogSlice.retrievedAt
  func entry(
    id: String = "synthetic_press", name: String = "Synthetic press", enabled: Bool = true,
    reviewsApproved: Bool = true, capabilities: Set<String> = ["standing_supported"],
    exclusions: Set<String> = ["avoid_sustained_grip"],
    equipment: [EquipmentRequirement] = [
      .init(equipmentId: "dumbbells", quantity: 2, capabilityIds: ["incremental_loading"])
    ]
  ) -> ExerciseCatalogEntry {
    let review =
      reviewsApproved
      ? CatalogReview(
        status: .approved, reviewerId: "test_owner", reviewedAt: date,
        evidenceReference: "docs/SCIENCE.md") : CatalogReview(status: .pending)
    let attribution = CatalogAttribution(
      licenseId: "cc0-1.0", licenseUrl: "https://creativecommons.org/publicdomain/zero/1.0/",
      attributionSourceUrl: "https://wger.de/api/v2/exerciseinfo/1/")
    return .init(
      id: id, wgerBaseId: 1, wgerBaseUuid: "a2f5b6ef-b780-49c0-8d96-fdaff23e27ce",
      wgerTranslationId: 1, wgerTranslationUuid: "c4856da3-8454-4857-8997-336d06df590f",
      wgerApiUrl: "https://wger.de/api/v2/exerciseinfo/1/",
      wgerPageUrl: "https://wger.de/en/exercise/1/view", name: name,
      movementPatternIds: ["horizontal_push"], primaryMuscleIds: ["chest"],
      equipmentRequirements: equipment, laterality: .bilateral, trackingMode: .loadReps,
      capabilityIds: capabilities, exclusionTagIds: exclusions, baseAttribution: attribution,
      translationAttribution: attribution, wasModified: false, productReview: review,
      scienceReview: review, safetyReview: review, equipmentReview: review, licenseReview: review,
      availability: enabled ? .enabled : .disabled,
      disabledReason: enabled ? nil : "Pending review.")
  }
  func manifest(
    _ entries: [ExerciseCatalogEntry], digest: String? = nil, version: String = "2026.09.08.1"
  ) -> ExerciseCatalogManifest {
    .init(
      schemaVersion: "1.0.0", catalogVersion: version, upstreamBaseUrl: "https://wger.de/api/v2/",
      retrievedAt: date, entryCount: entries.count,
      contentSha256: digest ?? sha256Hex(canonicalCatalogEntriesBytes(entries)),
      importToolVersion: "1.0.0")
  }
  func request(
    entries: [ExerciseCatalogEntry]? = nil, candidates: [String]? = nil,
    inventory: [EquipmentInventoryItem]? = nil, supported: [String] = ["standing_supported"],
    unsupported: [String] = [], limitations: [String] = [], temporary: [String] = [],
    persistent: [String] = [], excluded: [String] = [], safety: EligibilitySafetyState? = nil,
    digest: String? = nil, catalogDigest: String? = nil
  ) -> ExerciseEligibilityRequest {
    let catalog = entries ?? [entry()]
    let manifest = manifest(catalog, digest: catalogDigest)
    let items =
      inventory ?? [
        .init(equipmentId: "dumbbells", quantity: 2, capabilityIds: ["incremental_loading"])
      ]
    let functional = FunctionalCapabilityAssessment(
      supportedIds: supported, unsupportedIds: unsupported)
    let limitation = LimitationAssessment(ids: limitations)
    let actualDigest = eligibilityConstraintSnapshotSha256(
      equipmentInventory: items, temporarilyUnavailableEquipmentIds: temporary,
      functionalCapabilityAssessment: functional, limitationAssessment: limitation,
      persistentExerciseExclusionIds: persistent, requestExerciseExclusionIds: excluded)
    return .init(
      eligibilityRuleSetVersion: "1.0.0", schemaVersion: manifest.schemaVersion,
      catalogVersion: manifest.catalogVersion, taxonomyVersion: manifest.taxonomyVersion,
      catalogContentSha256: manifest.contentSha256,
      constraintSnapshotSha256: digest ?? actualDigest, manifest: manifest, catalog: catalog,
      candidateExerciseIds: candidates ?? catalog.map(\.id), equipmentInventory: items,
      temporarilyUnavailableEquipmentIds: temporary, functionalCapabilityAssessment: functional,
      limitationAssessment: limitation, persistentExerciseExclusionIds: persistent,
      requestExerciseExclusionIds: excluded,
      safetyState: safety ?? .init(version: "1.0.0", kind: .clear))
  }
  var evaluator: ExerciseEligibilityEvaluator { .init(catalogValidator: .init(importedAt: date)) }
  func testPinnedRealCatalogExactLegacyDigestAndDisabledStatus() {
    XCTAssertEqual(
      sha256Hex(canonicalCatalogEntriesBytes(BenchmarkCatalogSlice.entries)),
      BenchmarkCatalogSlice.contentSha256)
    XCTAssertTrue(
      ExerciseCatalogManifestValidator(importedAt: date).validate(
        BenchmarkCatalogSlice.manifest, BenchmarkCatalogSlice.entries
      ).isEmpty)
    XCTAssertEqual(BenchmarkCatalogSlice.entries.count, 3)
    XCTAssertTrue(BenchmarkCatalogSlice.entries.allSatisfy { !$0.isSelectable })
    XCTAssertEqual(
      sha256Hex(Data("abc".utf8)),
      "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    XCTAssertEqual(
      EngineJSON.object(["z": .null, "a": .string("a/b\n\"😀")]).canonical,
      "{\"a\":\"a/b\\n\\\"😀\",\"z\":null}")
  }
  func testCatalogRejectsUnsafeUnknownUnreviewedAndDuplicateData() {
    let validator = ExerciseCatalogValidator(importedAt: date)
    XCTAssertTrue(validator.validate(entry()).isEmpty)
    XCTAssertTrue(
      validator.validate(entry(name: "<script>bad</script>")).contains { $0.code == "unsafe_text" })
    XCTAssertTrue(validator.validate(entry(id: "bad id")).contains { $0.code == "invalid_id" })
    XCTAssertTrue(
      validator.validate(entry(reviewsApproved: false)).contains {
        $0.code == "enabled_without_approvals"
      })
    XCTAssertTrue(
      validator.validate(entry(capabilities: ["unknown"])).contains {
        $0.code == "unknown_taxonomy_id"
      })
    XCTAssertTrue(
      validator.validate(entry(equipment: [.init(equipmentId: "dumbbells", quantity: 0)])).contains
      { $0.code == "out_of_range" })
    let duplicate = [entry(), entry()]
    XCTAssertTrue(
      ExerciseCatalogManifestValidator(importedAt: date).validate(manifest(duplicate), duplicate)
        .contains { $0.code == "duplicate_value" })
    XCTAssertTrue(
      ExerciseCatalogManifestValidator(importedAt: date).validate(
        manifest([entry()], version: "2026.02.30.1"), [entry()]
      ).contains { $0.code == "invalid_catalog_version" })
    XCTAssertEqual(
      evaluator.evaluate(request(catalogDigest: String(repeating: "0", count: 64))).status,
      .catalogUnavailable)
  }
  func testGuardedEligibilityNormalAndFailClosedRequest() {
    XCTAssertEqual(evaluator.evaluate(request()).eligibleExerciseIds, ["synthetic_press"])
    XCTAssertEqual(evaluator.evaluate(.init()).status, .invalidInput)
    XCTAssertEqual(
      evaluator.evaluate(request(digest: String(repeating: "0", count: 64))).status, .invalidInput)
    XCTAssertEqual(
      evaluator.evaluate(request(candidates: ["synthetic_press", "synthetic_press"])).status,
      .invalidInput)
    XCTAssertEqual(evaluator.evaluate(request(candidates: ["unknown"])).status, .invalidInput)
    XCTAssertEqual(
      evaluator.evaluate(
        request(supported: ["standing_supported"], unsupported: ["standing_supported"])
      ).status, .invalidInput)
    XCTAssertEqual(
      evaluator.evaluate(request(inventory: [.init(equipmentId: "dumbbells", quantity: 0)])).status,
      .invalidInput)
    XCTAssertEqual(
      evaluator.evaluate(request(inventory: [.init(equipmentId: "unknown", quantity: 1)])).status,
      .invalidInput)
    XCTAssertEqual(evaluator.evaluate(request(candidates: [])).status, .constrainedNoCandidate)
  }
  func testEveryStructuralFilterAndStableReasonOrder() {
    let cases: [(ExerciseEligibilityRequest, String)] = [
      (request(entries: [entry(enabled: false)]), "catalog_entry_unselectable"),
      (request(inventory: []), "equipment_missing"),
      (
        request(inventory: [
          .init(equipmentId: "dumbbells", quantity: 1, capabilityIds: ["incremental_loading"])
        ]), "equipment_quantity_insufficient"
      ),
      (
        request(inventory: [.init(equipmentId: "dumbbells", quantity: 2)]),
        "equipment_capability_missing"
      ),
      (request(supported: []), "functional_capability_unconfirmed"),
      (
        request(supported: [], unsupported: ["standing_supported"]),
        "functional_capability_unsupported"
      ),
      (request(limitations: ["avoid_sustained_grip"]), "limitation_conflict"),
      (request(temporary: ["dumbbells"]), "equipment_temporarily_unavailable"),
      (request(persistent: ["synthetic_press"]), "exercise_excluded_persistent"),
      (request(excluded: ["synthetic_press"]), "exercise_excluded_for_request"),
    ]
    for (input, code) in cases {
      let result = evaluator.evaluate(input)
      XCTAssertEqual(result.status, .constrainedNoCandidate)
      XCTAssertTrue(result.candidateEvaluations[0].reasons.contains { $0.code == code }, code)
    }
    let many = evaluator.evaluate(
      request(
        inventory: [], supported: [], limitations: ["avoid_sustained_grip"],
        temporary: ["dumbbells"], persistent: ["synthetic_press"], excluded: ["synthetic_press"]))
    XCTAssertEqual(
      many.candidateEvaluations[0].reasons.map(\.code),
      [
        "exercise_excluded_persistent", "exercise_excluded_for_request", "limitation_conflict",
        "functional_capability_unconfirmed", "equipment_missing",
        "equipment_temporarily_unavailable",
      ])
  }
  func testSafetyStopsAndRestrictionsAreValidatedBeforeFiltering() {
    XCTAssertEqual(
      evaluator.evaluate(
        request(safety: .init(version: "1.0.0", kind: .stop, affectedExerciseId: "synthetic_press"))
      ).status, .safetyStop)
    XCTAssertEqual(
      evaluator.evaluate(request(safety: .init(version: "1.0.0", kind: .stop))).status,
      .invalidInput)
    let base = request()
    func restriction(version: String = "2026.09.08.1", digest: String? = nil)
      -> SafetyRestrictionReference
    {
      .init(
        exerciseId: "synthetic_press",
        constraintSnapshotSha256: digest ?? base.constraintSnapshotSha256!, catalogVersion: version,
        taxonomyVersion: "v2", eligibilityRuleSetVersion: "1.0.0",
        originatingRecommendationId: "recommendation1", regressionTestReference: "test1",
        reviewState: .unresolved, reviewReference: "review1")
    }
    let stopped = evaluator.evaluate(
      request(safety: .init(version: "1.0.0", kind: .restricted, restrictions: [restriction()])))
    XCTAssertEqual(stopped.status, .safetyStop)
    XCTAssertEqual(stopped.requestIssues[0].code, "unresolved_safety_incident")
    XCTAssertEqual(
      evaluator.evaluate(
        request(
          safety: .init(
            version: "1.0.0", kind: .restricted, restrictions: [restriction(version: "old")]))
      ).status, .invalidInput)
    XCTAssertEqual(
      evaluator.evaluate(
        request(
          safety: .init(
            version: "1.0.0", kind: .restricted,
            restrictions: [restriction(digest: String(repeating: "0", count: 64))]))
      ).status, .evaluated)
    XCTAssertEqual(
      evaluator.evaluate(request(safety: .init(version: "1.0.0", kind: .restricted))).status,
      .invalidInput)
    XCTAssertEqual(
      evaluator.evaluate(
        request(safety: .init(version: "1.0.0", kind: .clear, restrictions: [restriction()]))
      ).status, .invalidInput)
    XCTAssertEqual(
      evaluator.evaluate(
        request(
          safety: .init(
            version: "1.0.0", kind: .restricted, restrictions: [restriction(), restriction()]))
      ).status, .invalidInput)
  }
  func testConstraintDigestPreservesDuplicatesAndNormalizesOrdering() {
    func digest(_ items: [EquipmentInventoryItem], _ ids: [String]) -> String {
      eligibilityConstraintSnapshotSha256(
        equipmentInventory: items, temporarilyUnavailableEquipmentIds: ids,
        functionalCapabilityAssessment: .init(), limitationAssessment: .init(),
        persistentExerciseExclusionIds: [], requestExerciseExclusionIds: [])
    }
    let items: [EquipmentInventoryItem] = [
      .init(
        equipmentId: "dumbbells", quantity: 2,
        capabilityIds: ["adjustable_angle", "incremental_loading"]),
      .init(equipmentId: "flat_bench", quantity: 1),
    ]
    XCTAssertEqual(
      digest(items, ["dumbbells", "flat_bench"]),
      digest(items.reversed(), ["flat_bench", "dumbbells"]))
    XCTAssertNotEqual(digest(items, []), digest(items + [items[0]], []))
  }
}

extension EngineCatalogTests {
  private func mutate<T: Codable>(_ original: T, _ changes: [String: Any]) throws -> T {
    let bytes = try JSONEncoder().encode(original)
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    for (key, value) in changes { object[key] = value }
    return try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: object))
  }
  func testCatalogFieldBoundsLicenseAndReviewValidation() throws {
    let validator = ExerciseCatalogValidator(importedAt: date)
    let cases: [([String: Any], String)] = [
      (["wgerBaseId": 0], "invalid_positive_integer"),
      (["wgerTranslationId": -1], "invalid_positive_integer"),
      (["wgerBaseUuid": "invalid"], "invalid_uuid"),
      (["wgerTranslationUuid": "invalid"], "invalid_uuid"),
      (["wgerApiUrl": "http://wger.de/api/"], "invalid_url"),
      (["wgerPageUrl": "https://wger.de@evil.example/test"], "invalid_url"),
      (["name": " leading"], "invalid_text_length_or_whitespace"),
      (["name": String(repeating: "x", count: 81)], "invalid_text_length_or_whitespace"),
      (["name": "line\nfeed"], "unsafe_text"),
      (["instructions": "https://example.org"], "unsafe_text"),
      (["aliases": (0..<21).map { "Alias \($0)" }], "too_many_values"),
      (["language": "unknown"], "unsupported_language"),
      (["movementPatternIds": []], "value_count_out_of_range"),
      (["movementPatternIds": ["unknown"]], "unknown_taxonomy_id"),
      (["primaryMuscleIds": []], "value_count_out_of_range"),
      (["secondaryMuscleIds": ["chest"]], "overlapping_muscles"),
      (["variationGroupId": "bad group"], "invalid_id"),
      (["substitutionGroupIds": ["bad group"]], "invalid_id"),
      (["substitutionGroupIds": (0..<9).map { "group_\($0)" }], "too_many_values"),
      (["wasModified": true], "required_when_modified"),
      (["modificationNote": "Unexpected note"], "must_be_null"),
      (["availability": "disabled", "disabledReason": NSNull()], "required_when_disabled"),
      (["disabledReason": "Contradiction"], "must_be_null"),
    ]
    for (changes, code) in cases {
      XCTAssertTrue(
        validator.validate(try mutate(entry(), changes)).contains { $0.code == code },
        "\(changes) should produce \(code)")
    }
    XCTAssertTrue(
      validator.validate(try mutate(entry(), ["instructions": "Line one\nLine two"])).isEmpty)
    for (key, value, code) in [
      ("licenseId", "odbl", "unsupported_license"),
      ("licenseUrl", "https://creativecommons.org/licenses/by/4.0/", "license_url_mismatch"),
    ] {
      let attribution = try mutate(entry().baseAttribution, [key: value])
      let data = try JSONEncoder().encode(attribution)
      XCTAssertTrue(
        validator.validate(
          try mutate(entry(), ["baseAttribution": JSONSerialization.jsonObject(with: data)])
        ).contains { $0.code == code })
    }
    let withBadEquipment = entry(equipment: [
      .init(equipmentId: "dumbbells", quantity: 1),
      .init(equipmentId: "dumbbells", quantity: 1, capabilityIds: ["unknown"]),
    ])
    XCTAssertTrue(validator.validate(withBadEquipment).contains { $0.code == "duplicate_value" })
    XCTAssertTrue(
      validator.validate(withBadEquipment).contains { $0.code == "unknown_taxonomy_id" })
    for (review, code) in [
      (CatalogReview(status: .pending, reviewerId: "reviewer"), "pending_review_has_decision"),
      (CatalogReview(status: .approved), "decided_review_incomplete"),
      (
        CatalogReview(
          status: .approved, reviewerId: "bad id", reviewedAt: date,
          evidenceReference: "docs/review.md"), "invalid_reviewer_id"
      ),
      (
        CatalogReview(
          status: .approved, reviewerId: "reviewer", reviewedAt: date.addingTimeInterval(1),
          evidenceReference: "docs/review.md"), "future_timestamp"
      ),
      (
        CatalogReview(
          status: .approved, reviewerId: "reviewer", reviewedAt: date.addingTimeInterval(0.5),
          evidenceReference: "docs/review.md"), "invalid_timestamp"
      ),
    ] {
      let reviewObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(review))
      XCTAssertTrue(
        validator.validate(try mutate(entry(), ["scienceReview": reviewObject])).contains {
          $0.code == code
        })
    }
  }
  func testReviewEvidenceRejectsUnsafePathsAndUnapprovedHosts() throws {
    func replaced(_ reference: String) throws -> ExerciseCatalogEntry {
      let review = CatalogReview(
        status: .approved, reviewerId: "reviewer", reviewedAt: date, evidenceReference: reference)
      return try mutate(
        entry(), ["scienceReview": JSONSerialization.jsonObject(with: JSONEncoder().encode(review))]
      )
    }
    for reference in [
      "../review.md", "docs/../private", "docs/%2e%2e/private", "docs//review.md",
      "docs/review.md?x=1", "docs/review.md#anchor", "docs/\\review.md", "<script>",
      "https://evil.example/review",
    ] {
      XCTAssertFalse(
        ExerciseCatalogValidator(importedAt: date).validate(try replaced(reference)).isEmpty,
        reference)
    }
    let approved = try replaced("https://approved.example/review")
    XCTAssertTrue(
      ExerciseCatalogValidator(importedAt: date, allowedEvidenceHosts: ["approved.example"])
        .validate(approved).isEmpty)
    XCTAssertTrue(
      ExerciseCatalogManifestValidator(importedAt: date, allowedEvidenceHosts: ["approved.example"])
        .validate(manifest([approved]), [approved]).isEmpty)
  }
  func testManifestAllIdentityAndTimestampBounds() throws {
    let entries = [entry()]
    let original = manifest(entries)
    let cases: [([String: Any], String)] = [
      (["schemaVersion": "2.0.0"], "unsupported_schema_version"),
      (["taxonomyVersion": "v3"], "unsupported_taxonomy_version"),
      (["provider": "other"], "unsupported_provider"),
      (["upstreamBaseUrl": "https://evil.example"], "invalid_url"),
      (["catalogVersion": "2026.1.1.1"], "invalid_catalog_version"),
      (["catalogVersion": "2026.02.29.1"], "invalid_catalog_version"),
      (["sourceRevision": ""], "invalid_source_revision"),
      (["sourceRevision": String(repeating: "x", count: 129)], "invalid_source_revision"),
      (["sourceRevision": "control\n"], "invalid_source_revision"),
      (["entryCount": 0], "entry_count_out_of_range"),
      (["entryCount": 5001], "entry_count_out_of_range"),
      (["entryCount": 2], "entry_count_mismatch"),
      (["contentSha256": "bad"], "invalid_sha256"),
      (["importToolVersion": "01.0.0"], "unsupported_import_tool_version"),
    ]
    for (changes, code) in cases {
      XCTAssertTrue(
        ExerciseCatalogManifestValidator(importedAt: date).validate(
          try mutate(original, changes), entries
        ).contains { $0.code == code }, "\(changes)")
    }
    for timestamp in [date.addingTimeInterval(1), date.addingTimeInterval(-0.5)] {
      XCTAssertTrue(
        ExerciseCatalogManifestValidator(importedAt: date).validate(
          try mutate(original, ["retrievedAt": timestamp.timeIntervalSinceReferenceDate]), entries
        ).contains { $0.code == "invalid_retrieved_at" })
    }
  }
}

extension EngineCatalogTests {
  func testEveryRequiredEnvelopeFieldAndIdentityMismatchFailsBeforeSafety() {
    let input = request()
    let required = [
      "eligibilityRuleSetVersion", "schemaVersion", "catalogVersion", "taxonomyVersion",
      "catalogContentSha256", "constraintSnapshotSha256", "manifest", "catalog",
      "candidateExerciseIds", "equipmentInventory", "temporarilyUnavailableEquipmentIds",
      "functionalCapabilityAssessment", "limitationAssessment", "persistentExerciseExclusionIds",
      "requestExerciseExclusionIds", "safetyState",
    ]
    func changed(missing: String? = nil, identity: String? = nil) -> ExerciseEligibilityRequest {
      func value(_ field: String, _ existing: String?) -> String? {
        field == missing ? nil : field == identity ? "unsupported" : existing
      }
      return .init(
        eligibilityRuleSetVersion: value(
          "eligibilityRuleSetVersion", input.eligibilityRuleSetVersion),
        schemaVersion: value("schemaVersion", input.schemaVersion),
        catalogVersion: value("catalogVersion", input.catalogVersion),
        taxonomyVersion: value("taxonomyVersion", input.taxonomyVersion),
        catalogContentSha256: value("catalogContentSha256", input.catalogContentSha256),
        constraintSnapshotSha256: value("constraintSnapshotSha256", input.constraintSnapshotSha256),
        manifest: missing == "manifest" ? nil : input.manifest,
        catalog: missing == "catalog" ? nil : input.catalog,
        candidateExerciseIds: missing == "candidateExerciseIds" ? nil : input.candidateExerciseIds,
        equipmentInventory: missing == "equipmentInventory" ? nil : input.equipmentInventory,
        temporarilyUnavailableEquipmentIds: missing == "temporarilyUnavailableEquipmentIds"
          ? nil : input.temporarilyUnavailableEquipmentIds,
        functionalCapabilityAssessment: missing == "functionalCapabilityAssessment"
          ? nil : input.functionalCapabilityAssessment,
        limitationAssessment: missing == "limitationAssessment" ? nil : input.limitationAssessment,
        persistentExerciseExclusionIds: missing == "persistentExerciseExclusionIds"
          ? nil : input.persistentExerciseExclusionIds,
        requestExerciseExclusionIds: missing == "requestExerciseExclusionIds"
          ? nil : input.requestExerciseExclusionIds,
        safetyState: missing == "safetyState" ? nil : input.safetyState)
    }
    for field in required {
      let result = evaluator.evaluate(changed(missing: field))
      XCTAssertEqual(result.status, .invalidInput, field)
      XCTAssertTrue(
        result.requestIssues.contains {
          $0.code == "required_input_missing" && $0.parameters["field"] == .string(field)
        }, field)
      XCTAssertTrue(result.candidateEvaluations.isEmpty)
    }
    for (field, code) in [
      ("eligibilityRuleSetVersion", "eligibility_rules_unsupported"),
      ("schemaVersion", "schema_version_mismatch"), ("catalogVersion", "catalog_version_mismatch"),
      ("taxonomyVersion", "taxonomy_version_mismatch"),
      ("catalogContentSha256", "catalog_digest_mismatch"),
      ("constraintSnapshotSha256", "constraint_digest_mismatch"),
    ] {
      let result = evaluator.evaluate(changed(identity: field))
      XCTAssertEqual(result.status, .invalidInput)
      XCTAssertTrue(result.requestIssues.contains { $0.code == code }, field)
    }
  }
  func testSafetyAuditReferencesAndMalformedStatesNeverReachFiltering() {
    let input = request()
    func restriction(missing: String? = nil, invalid: String? = nil) -> SafetyRestrictionReference {
      let values: [String: String] = [
        "exerciseId": "synthetic_press",
        "constraintSnapshotSha256": input.constraintSnapshotSha256!,
        "catalogVersion": "2026.09.08.1", "taxonomyVersion": "v2",
        "eligibilityRuleSetVersion": "1.0.0", "originatingRecommendationId": "recommendation",
        "regressionTestReference": "regression", "reviewReference": "review",
      ]
      func v(_ field: String) -> String? {
        field == missing ? nil : field == invalid ? "bad\nvalue" : values[field]
      }
      return .init(
        exerciseId: v("exerciseId"), constraintSnapshotSha256: v("constraintSnapshotSha256"),
        catalogVersion: v("catalogVersion"), taxonomyVersion: v("taxonomyVersion"),
        eligibilityRuleSetVersion: v("eligibilityRuleSetVersion"),
        originatingRecommendationId: v("originatingRecommendationId"),
        regressionTestReference: v("regressionTestReference"),
        reviewState: missing == "reviewState" ? nil : .unresolved,
        reviewReference: v("reviewReference"))
    }
    for field in [
      "exerciseId", "constraintSnapshotSha256", "catalogVersion", "taxonomyVersion",
      "eligibilityRuleSetVersion", "originatingRecommendationId", "regressionTestReference",
      "reviewState", "reviewReference",
    ] {
      XCTAssertEqual(
        evaluator.evaluate(
          request(
            safety: .init(
              version: "1.0.0", kind: .restricted, restrictions: [restriction(missing: field)]))
        ).status, .invalidInput, field)
    }
    for field in [
      "exerciseId", "constraintSnapshotSha256", "originatingRecommendationId",
      "regressionTestReference", "reviewReference",
    ] {
      XCTAssertEqual(
        evaluator.evaluate(
          request(
            safety: .init(
              version: "1.0.0", kind: .restricted, restrictions: [restriction(invalid: field)]))
        ).status, .invalidInput, field)
    }
    for state in [
      EligibilitySafetyState(version: nil, kind: .clear), .init(version: "old", kind: .clear),
      .init(version: "1.0.0", kind: .clear, affectedExerciseId: "synthetic_press"),
      .init(version: "1.0.0", kind: .stop, affectedExerciseId: "unknown"),
      .init(
        version: "1.0.0", kind: .stop, affectedExerciseId: "synthetic_press",
        restrictions: [restriction()]),
    ] {
      XCTAssertEqual(evaluator.evaluate(request(safety: state)).status, .invalidInput)
    }
  }
  func testDuplicateOrUnknownConstraintsRetainFailClosedEnvelope() {
    let inputs = [
      request(inventory: [
        .init(equipmentId: "dumbbells", quantity: 2), .init(equipmentId: "dumbbells", quantity: 2),
      ]),
      request(inventory: [
        .init(
          equipmentId: "dumbbells", quantity: 2,
          capabilityIds: ["incremental_loading", "incremental_loading"])
      ]),
      request(inventory: [.init(equipmentId: "dumbbells", quantity: 2, capabilityIds: ["unknown"])]
      ),
      request(supported: ["standing_supported", "standing_supported"]),
      request(supported: ["unknown"]),
      request(supported: [], unsupported: ["standing_supported", "standing_supported"]),
      request(unsupported: ["unknown"]),
      request(limitations: ["avoid_sustained_grip", "avoid_sustained_grip"]),
      request(limitations: ["unknown"]),
      request(temporary: ["dumbbells", "dumbbells"]), request(temporary: ["unknown"]),
      request(persistent: ["synthetic_press", "synthetic_press"]), request(persistent: ["unknown"]),
      request(excluded: ["synthetic_press", "synthetic_press"]), request(excluded: ["unknown"]),
    ]
    for input in inputs {
      let result = evaluator.evaluate(input)
      XCTAssertEqual(result.status, .invalidInput)
      XCTAssertTrue(result.eligibleExerciseIds.isEmpty)
      XCTAssertTrue(result.candidateEvaluations.isEmpty)
    }
  }
}
