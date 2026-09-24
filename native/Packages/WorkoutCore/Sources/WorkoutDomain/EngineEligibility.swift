import Foundation

public enum EligibilityResultStatus: String, Sendable {
  case evaluated
  case constrainedNoCandidate = "constrained_no_candidate"
  case invalidInput = "invalid_input"
  case catalogUnavailable = "catalog_unavailable"
  case safetyStop = "safety_stop"
}
public enum SafetyRestrictionReviewState: String, Sendable {
  case unresolved
}
public enum EligibilitySafetyStateKind: String, Sendable {
  case clear
  case stop
  case restricted
}

public struct EquipmentInventoryItem: Sendable {
  public let equipmentId: String
  public let quantity: Int
  public let capabilityIds: [String]
  public init(equipmentId: String, quantity: Int, capabilityIds: [String] = []) {
    self.equipmentId = equipmentId
    self.quantity = quantity
    self.capabilityIds = capabilityIds
  }
}

public struct FunctionalCapabilityAssessment: Sendable {
  public let supportedIds: [String]
  public let unsupportedIds: [String]
  public init(supportedIds: [String] = [], unsupportedIds: [String] = []) {
    self.supportedIds = supportedIds
    self.unsupportedIds = unsupportedIds
  }
}

public struct LimitationAssessment: Sendable {
  public let ids: [String]
  public init(ids: [String] = []) {
    self.ids = ids
  }
}

public struct SafetyRestrictionReference: Sendable {
  public let exerciseId: String?
  public let constraintSnapshotSha256: String?
  public let catalogVersion: String?
  public let taxonomyVersion: String?
  public let eligibilityRuleSetVersion: String?
  public let originatingRecommendationId: String?
  public let regressionTestReference: String?
  public let reviewState: SafetyRestrictionReviewState?
  public let reviewReference: String?
  public init(
    exerciseId: String? = nil, constraintSnapshotSha256: String? = nil,
    catalogVersion: String? = nil, taxonomyVersion: String? = nil,
    eligibilityRuleSetVersion: String? = nil, originatingRecommendationId: String? = nil,
    regressionTestReference: String? = nil, reviewState: SafetyRestrictionReviewState? = nil,
    reviewReference: String? = nil
  ) {
    self.exerciseId = exerciseId
    self.constraintSnapshotSha256 = constraintSnapshotSha256
    self.catalogVersion = catalogVersion
    self.taxonomyVersion = taxonomyVersion
    self.eligibilityRuleSetVersion = eligibilityRuleSetVersion
    self.originatingRecommendationId = originatingRecommendationId
    self.regressionTestReference = regressionTestReference
    self.reviewState = reviewState
    self.reviewReference = reviewReference
  }
}

public struct EligibilitySafetyState: Sendable {
  public let version: String?
  public let kind: EligibilitySafetyStateKind
  public let affectedExerciseId: String?
  public let restrictions: [SafetyRestrictionReference]
  public init(
    version: String? = nil, kind: EligibilitySafetyStateKind, affectedExerciseId: String? = nil,
    restrictions: [SafetyRestrictionReference] = []
  ) {
    self.version = version
    self.kind = kind
    self.affectedExerciseId = affectedExerciseId
    self.restrictions = restrictions
  }
}

public struct ExerciseEligibilityRequest: Sendable {
  public let eligibilityRuleSetVersion: String?
  public let schemaVersion: String?
  public let catalogVersion: String?
  public let taxonomyVersion: String?
  public let catalogContentSha256: String?
  public let constraintSnapshotSha256: String?
  public let manifest: ExerciseCatalogManifest?
  public let catalog: [ExerciseCatalogEntry]?
  public let candidateExerciseIds: [String]?
  public let equipmentInventory: [EquipmentInventoryItem]?
  public let temporarilyUnavailableEquipmentIds: [String]?
  public let functionalCapabilityAssessment: FunctionalCapabilityAssessment?
  public let limitationAssessment: LimitationAssessment?
  public let persistentExerciseExclusionIds: [String]?
  public let requestExerciseExclusionIds: [String]?
  public let safetyState: EligibilitySafetyState?
  public init(
    eligibilityRuleSetVersion: String? = nil, schemaVersion: String? = nil,
    catalogVersion: String? = nil, taxonomyVersion: String? = nil,
    catalogContentSha256: String? = nil, constraintSnapshotSha256: String? = nil,
    manifest: ExerciseCatalogManifest? = nil, catalog: [ExerciseCatalogEntry]? = nil,
    candidateExerciseIds: [String]? = nil, equipmentInventory: [EquipmentInventoryItem]? = nil,
    temporarilyUnavailableEquipmentIds: [String]? = nil,
    functionalCapabilityAssessment: FunctionalCapabilityAssessment? = nil,
    limitationAssessment: LimitationAssessment? = nil,
    persistentExerciseExclusionIds: [String]? = nil, requestExerciseExclusionIds: [String]? = nil,
    safetyState: EligibilitySafetyState? = nil
  ) {
    self.eligibilityRuleSetVersion = eligibilityRuleSetVersion
    self.schemaVersion = schemaVersion
    self.catalogVersion = catalogVersion
    self.taxonomyVersion = taxonomyVersion
    self.catalogContentSha256 = catalogContentSha256
    self.constraintSnapshotSha256 = constraintSnapshotSha256
    self.manifest = manifest
    self.catalog = catalog
    self.candidateExerciseIds = candidateExerciseIds
    self.equipmentInventory = equipmentInventory
    self.temporarilyUnavailableEquipmentIds = temporarilyUnavailableEquipmentIds
    self.functionalCapabilityAssessment = functionalCapabilityAssessment
    self.limitationAssessment = limitationAssessment
    self.persistentExerciseExclusionIds = persistentExerciseExclusionIds
    self.requestExerciseExclusionIds = requestExerciseExclusionIds
    self.safetyState = safetyState
  }
}
public enum EligibilityReasonCode {
  public static let catalogEntryUnselectable = "catalog_entry_unselectable"
  public static let exerciseExcludedPersistent = "exercise_excluded_persistent"
  public static let exerciseExcludedForRequest = "exercise_excluded_for_request"
  public static let limitationConflict = "limitation_conflict"
  public static let functionalCapabilityUnsupported = "functional_capability_unsupported"
  public static let functionalCapabilityUnconfirmed = "functional_capability_unconfirmed"
  public static let equipmentMissing = "equipment_missing"
  public static let equipmentQuantityInsufficient = "equipment_quantity_insufficient"
  public static let equipmentCapabilityMissing = "equipment_capability_missing"
  public static let equipmentTemporarilyUnavailable = "equipment_temporarily_unavailable"
  public static let catalogInvalid = "catalog_invalid"
  public static let schemaVersionMismatch = "schema_version_mismatch"
  public static let catalogVersionMismatch = "catalog_version_mismatch"
  public static let taxonomyVersionMismatch = "taxonomy_version_mismatch"
  public static let catalogDigestMismatch = "catalog_digest_mismatch"
  public static let constraintDigestMismatch = "constraint_digest_mismatch"
  public static let eligibilityRulesUnsupported = "eligibility_rules_unsupported"
  public static let requiredInputMissing = "required_input_missing"
  public static let invalidValue = "invalid_value"
  public static let unknownTaxonomyId = "unknown_taxonomy_id"
  public static let unknownExerciseId = "unknown_exercise_id"
  public static let duplicateInput = "duplicate_input"
  public static let staleSafetyReference = "stale_safety_reference"
  public static let noEligibleExercise = "no_eligible_exercise"
  public static let painReportRequiresStop = "pain_report_requires_stop"
  public static let unresolvedSafetyIncident = "unresolved_safety_incident"
  public static let ordered: [String] = [
    catalogEntryUnselectable, exerciseExcludedPersistent, exerciseExcludedForRequest,
    limitationConflict, functionalCapabilityUnsupported, functionalCapabilityUnconfirmed,
    equipmentMissing, equipmentQuantityInsufficient, equipmentCapabilityMissing,
    equipmentTemporarilyUnavailable, catalogInvalid, schemaVersionMismatch, catalogVersionMismatch,
    taxonomyVersionMismatch, catalogDigestMismatch, constraintDigestMismatch,
    eligibilityRulesUnsupported, requiredInputMissing, invalidValue, unknownTaxonomyId,
    unknownExerciseId, duplicateInput, staleSafetyReference, noEligibleExercise,
    painReportRequiresStop, unresolvedSafetyIncident,
  ]
}
public struct EligibilityIssue: Equatable, Comparable, Sendable {
  public let code: String
  public let parameters: [String: EngineJSON]
  init(_ code: String, _ parameters: [String: EngineJSON] = [:]) {
    self.code = code
    self.parameters = parameters
  }
  public static func < (lhs: Self, rhs: Self) -> Bool {
    let left =
      EligibilityReasonCode.ordered.firstIndex(of: lhs.code) ?? EligibilityReasonCode.ordered.count
    let right =
      EligibilityReasonCode.ordered.firstIndex(of: rhs.code) ?? EligibilityReasonCode.ordered.count
    if left != right { return left < right }
    return engineUTF16Less(
      EngineJSON.object(lhs.parameters).canonical, EngineJSON.object(rhs.parameters).canonical)
  }
  public var json: EngineJSON {
    .object(["code": .string(code), "parameters": .object(parameters)])
  }
}
public struct CandidateEligibilityEvaluation: Equatable, Sendable {
  public let exerciseId: String
  public let isEligible: Bool
  public let reasons: [EligibilityIssue]
  init(exerciseId: String, reasons: [EligibilityIssue]) {
    self.exerciseId = exerciseId
    self.isEligible = reasons.isEmpty
    self.reasons = reasons.sorted()
  }
  public var json: EngineJSON {
    .object([
      "exerciseId": .string(exerciseId), "isEligible": .bool(isEligible),
      "reasons": .array(reasons.map(\.json)),
    ])
  }
}
public struct ExerciseEligibilityResult: Sendable {
  public let status: EligibilityResultStatus
  public let eligibilityRuleSetVersion: String?
  public let schemaVersion: String?
  public let catalogVersion: String?
  public let taxonomyVersion: String?
  public let catalogContentSha256: String?
  public let constraintSnapshotSha256: String?
  public let catalogValidationReferenceTime: Date
  public let eligibleExerciseIds: [String]
  public let candidateEvaluations: [CandidateEligibilityEvaluation]
  public let requestIssues: [EligibilityIssue]
  public var json: EngineJSON {
    .object([
      "status": .string(status.rawValue),
      "eligibilityRuleSetVersion": eligibilityRuleSetVersion.map(EngineJSON.string) ?? .null,
      "schemaVersion": schemaVersion.map(EngineJSON.string) ?? .null,
      "catalogVersion": catalogVersion.map(EngineJSON.string) ?? .null,
      "taxonomyVersion": taxonomyVersion.map(EngineJSON.string) ?? .null,
      "catalogContentSha256": catalogContentSha256.map(EngineJSON.string) ?? .null,
      "constraintSnapshotSha256": constraintSnapshotSha256.map(EngineJSON.string) ?? .null,
      "catalogValidationReferenceTime": .string(engineTimestamp(catalogValidationReferenceTime)),
      "eligibleExerciseIds": .strings(eligibleExerciseIds),
      "candidateEvaluations": .array(candidateEvaluations.map(\.json)),
      "requestIssues": .array(requestIssues.map(\.json)),
    ])
  }
  public func toCanonicalJson() -> String { json.canonical }
}
public func eligibilityConstraintSnapshotSha256(
  equipmentInventory: [EquipmentInventoryItem], temporarilyUnavailableEquipmentIds: [String],
  functionalCapabilityAssessment: FunctionalCapabilityAssessment,
  limitationAssessment: LimitationAssessment, persistentExerciseExclusionIds: [String],
  requestExerciseExclusionIds: [String]
) -> String {
  let inventory = equipmentInventory.map { item in
    (
      item.equipmentId,
      EngineJSON.object([
        "equipmentId": .string(item.equipmentId), "quantity": .integer(item.quantity),
        "capabilityIds": .strings(item.capabilityIds.sorted(by: engineUTF16Less)),
      ])
    )
  }.sorted {
    $0.0 == $1.0 ? engineUTF16Less($0.1.canonical, $1.1.canonical) : engineUTF16Less($0.0, $1.0)
  }.map(\.1)
  let snapshot: EngineJSON = .object([
    "equipmentInventory": .array(inventory),
    "functionalCapabilityAssessment": .object([
      "supportedIds": .strings(
        functionalCapabilityAssessment.supportedIds.sorted(by: engineUTF16Less)),
      "unsupportedIds": .strings(
        functionalCapabilityAssessment.unsupportedIds.sorted(by: engineUTF16Less)),
    ]),
    "limitationAssessment": .object([
      "ids": .strings(limitationAssessment.ids.sorted(by: engineUTF16Less))
    ]),
    "persistentExerciseExclusionIds": .strings(
      persistentExerciseExclusionIds.sorted(by: engineUTF16Less)),
    "requestExerciseExclusionIds": .strings(
      requestExerciseExclusionIds.sorted(by: engineUTF16Less)),
    "temporarilyUnavailableEquipmentIds": .strings(
      temporarilyUnavailableEquipmentIds.sorted(by: engineUTF16Less)),
  ])
  return sha256Hex(canonicalJsonBytes(snapshot))
}

/// The only public selection entry point. Validates catalog and the whole request
/// before the private safety gate and minimal eligibility projection can run.
public struct ExerciseEligibilityEvaluator: Sendable {
  public let catalogValidator: ExerciseCatalogManifestValidator
  public let supportedEligibilityRuleSetVersion: String
  public let supportedSafetyStateVersion: String
  public init(
    catalogValidator: ExerciseCatalogManifestValidator,
    supportedEligibilityRuleSetVersion: String = "1.0.0",
    supportedSafetyStateVersion: String = "1.0.0"
  ) {
    self.catalogValidator = catalogValidator
    self.supportedEligibilityRuleSetVersion = supportedEligibilityRuleSetVersion
    self.supportedSafetyStateVersion = supportedSafetyStateVersion
  }
  public func evaluate(_ request: ExerciseEligibilityRequest) -> ExerciseEligibilityResult {
    guard let manifest = request.manifest, let catalog = request.catalog else {
      var issues: [EligibilityIssue] = []
      if request.manifest == nil { issues.append(missing("manifest")) }
      if request.catalog == nil { issues.append(missing("catalog")) }
      return result(request, .invalidInput, issues: issues)
    }
    let catalogIssues = catalogValidator.validate(manifest, catalog)
    if !catalogIssues.isEmpty {
      return result(
        request, .catalogUnavailable,
        issues: [
          .init("catalog_invalid", ["issues": .strings(catalogIssues.map(\.description).sorted())])
        ])
    }
    let catalogById = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
    let issues = validateRequest(request, manifest, Set(catalogById.keys))
    if !issues.isEmpty { return result(request, .invalidInput, issues: issues) }
    let candidates = Set(request.candidateExerciseIds!)
    let safetyIssues = safetyGate(request.safetyState!, candidates, constraintDigest(request))
    if !safetyIssues.isEmpty { return result(request, .safetyStop, issues: safetyIssues) }
    let projected = candidates.map { id in
      let entry = catalogById[id]!
      return EligibilityCandidate(
        id: id, isSelectable: entry.isSelectable, equipment: entry.equipmentRequirements,
        capabilities: entry.capabilityIds, exclusions: entry.exclusionTagIds)
    }
    let evaluations = filter(projected, request)
    let eligible = evaluations.filter(\.isEligible).map(\.exerciseId)
    return result(
      request, eligible.isEmpty ? .constrainedNoCandidate : .evaluated, eligible: eligible,
      candidates: evaluations, issues: eligible.isEmpty ? [.init("no_eligible_exercise")] : [])
  }
  private func constraintDigest(_ request: ExerciseEligibilityRequest) -> String {
    eligibilityConstraintSnapshotSha256(
      equipmentInventory: request.equipmentInventory!,
      temporarilyUnavailableEquipmentIds: request.temporarilyUnavailableEquipmentIds!,
      functionalCapabilityAssessment: request.functionalCapabilityAssessment!,
      limitationAssessment: request.limitationAssessment!,
      persistentExerciseExclusionIds: request.persistentExerciseExclusionIds!,
      requestExerciseExclusionIds: request.requestExerciseExclusionIds!)
  }
  private func validateRequest(
    _ request: ExerciseEligibilityRequest, _ manifest: ExerciseCatalogManifest,
    _ catalogIds: Set<String>
  ) -> [EligibilityIssue] {
    var issues: [EligibilityIssue] = []
    let fields: [(String, Bool)] = [
      ("eligibilityRuleSetVersion", request.eligibilityRuleSetVersion == nil),
      ("schemaVersion", request.schemaVersion == nil),
      ("catalogVersion", request.catalogVersion == nil),
      ("taxonomyVersion", request.taxonomyVersion == nil),
      ("catalogContentSha256", request.catalogContentSha256 == nil),
      ("constraintSnapshotSha256", request.constraintSnapshotSha256 == nil),
      ("candidateExerciseIds", request.candidateExerciseIds == nil),
      ("equipmentInventory", request.equipmentInventory == nil),
      ("temporarilyUnavailableEquipmentIds", request.temporarilyUnavailableEquipmentIds == nil),
      ("functionalCapabilityAssessment", request.functionalCapabilityAssessment == nil),
      ("limitationAssessment", request.limitationAssessment == nil),
      ("persistentExerciseExclusionIds", request.persistentExerciseExclusionIds == nil),
      ("requestExerciseExclusionIds", request.requestExerciseExclusionIds == nil),
      ("safetyState", request.safetyState == nil),
    ]
    for (field, absent) in fields where absent { issues.append(missing(field)) }
    if let version = request.eligibilityRuleSetVersion,
      version != supportedEligibilityRuleSetVersion
    {
      issues.append(
        .init(
          "eligibility_rules_unsupported",
          ["actual": .string(version), "expected": .string(supportedEligibilityRuleSetVersion)]))
    }
    for (actual, expected, field, code) in [
      (request.schemaVersion, manifest.schemaVersion, "schemaVersion", "schema_version_mismatch"),
      (
        request.catalogVersion, manifest.catalogVersion, "catalogVersion",
        "catalog_version_mismatch"
      ),
      (
        request.taxonomyVersion, manifest.taxonomyVersion, "taxonomyVersion",
        "taxonomy_version_mismatch"
      ),
      (
        request.catalogContentSha256, manifest.contentSha256, "catalogContentSha256",
        "catalog_digest_mismatch"
      ),
    ] {
      if let actual, actual != expected {
        issues.append(
          .init(
            code,
            ["actual": .string(actual), "expected": .string(expected), "field": .string(field)]))
      }
    }
    if let digest = request.constraintSnapshotSha256 {
      if !engineMatches(digest, "^[0-9a-f]{64}$") {
        issues.append(.init("invalid_value", ["field": .string("constraintSnapshotSha256")]))
      }
      if request.equipmentInventory != nil && request.temporarilyUnavailableEquipmentIds != nil
        && request.functionalCapabilityAssessment != nil && request.limitationAssessment != nil
        && request.persistentExerciseExclusionIds != nil
        && request.requestExerciseExclusionIds != nil
      {
        let expected = constraintDigest(request)
        if digest != expected {
          issues.append(
            .init(
              "constraint_digest_mismatch",
              ["actual": .string(digest), "expected": .string(expected)]))
        }
      }
    }
    validateList(
      request.candidateExerciseIds, "candidateExerciseIds", catalogIds, &issues,
      unknown: "unknown_exercise_id")
    if (request.candidateExerciseIds?.count ?? 0) > 5000 {
      issues.append(.init("invalid_value", ["field": .string("candidateExerciseIds")]))
    }
    var equipmentIds: Set<String> = []
    for item in request.equipmentInventory ?? [] {
      if !equipmentIds.insert(item.equipmentId).inserted {
        issues.append(
          .init(
            "duplicate_input",
            ["field": .string("equipmentInventory"), "id": .string(item.equipmentId)]))
      }
      if !ExerciseCatalogValidator.equipmentIds.contains(item.equipmentId) {
        issues.append(
          .init(
            "unknown_taxonomy_id",
            ["field": .string("equipmentInventory.equipmentId"), "id": .string(item.equipmentId)]))
      }
      if !(1...8).contains(item.quantity) {
        issues.append(
          .init(
            "invalid_value",
            ["field": .string("equipmentInventory.quantity"), "id": .string(item.equipmentId)]))
      }
      validateList(
        item.capabilityIds, "equipmentInventory.capabilityIds",
        ExerciseCatalogValidator.equipmentCapabilityIds, &issues)
    }
    validateList(
      request.temporarilyUnavailableEquipmentIds, "temporarilyUnavailableEquipmentIds",
      ExerciseCatalogValidator.equipmentIds, &issues)
    if let assessment = request.functionalCapabilityAssessment {
      validateList(
        assessment.supportedIds, "functionalCapabilityAssessment.supportedIds",
        ExerciseCatalogValidator.functionalCapabilityIds, &issues)
      validateList(
        assessment.unsupportedIds, "functionalCapabilityAssessment.unsupportedIds",
        ExerciseCatalogValidator.functionalCapabilityIds, &issues)
      for id in Set(assessment.supportedIds).intersection(assessment.unsupportedIds).sorted() {
        issues.append(
          .init(
            "duplicate_input",
            ["field": .string("functionalCapabilityAssessment"), "id": .string(id)]))
      }
    }
    validateList(
      request.limitationAssessment?.ids, "limitationAssessment.ids",
      ExerciseCatalogValidator.limitationConflictIds, &issues)
    validateList(
      request.persistentExerciseExclusionIds, "persistentExerciseExclusionIds", catalogIds, &issues,
      unknown: "unknown_exercise_id")
    validateList(
      request.requestExerciseExclusionIds, "requestExerciseExclusionIds", catalogIds, &issues,
      unknown: "unknown_exercise_id")
    validateSafety(request, catalogIds, &issues)
    return issues
  }
  private func validateList(
    _ values: [String]?, _ field: String, _ allowed: Set<String>,
    _ issues: inout [EligibilityIssue], unknown: String = "unknown_taxonomy_id"
  ) {
    var seen: Set<String> = []
    for value in values ?? [] {
      if !seen.insert(value).inserted {
        issues.append(.init("duplicate_input", ["field": .string(field), "id": .string(value)]))
      }
      if !allowed.contains(value) {
        issues.append(.init(unknown, ["field": .string(field), "id": .string(value)]))
      }
    }
  }
  private func validateSafety(
    _ request: ExerciseEligibilityRequest, _ catalogIds: Set<String>,
    _ issues: inout [EligibilityIssue]
  ) {
    guard let state = request.safetyState else { return }
    if let version = state.version {
      if version != supportedSafetyStateVersion {
        issues.append(.init("invalid_value", ["field": .string("safetyState.version")]))
      }
    } else {
      issues.append(missing("safetyState.version"))
    }
    if state.kind == .stop {
      if let id = state.affectedExerciseId {
        if !catalogIds.contains(id) {
          issues.append(
            .init(
              "unknown_exercise_id",
              ["field": .string("safetyState.affectedExerciseId"), "id": .string(id)]))
        }
      } else {
        issues.append(missing("safetyState.affectedExerciseId"))
      }
      if !state.restrictions.isEmpty {
        issues.append(.init("invalid_value", ["field": .string("safetyState.restrictions")]))
      }
      return
    }
    if state.affectedExerciseId != nil {
      issues.append(.init("invalid_value", ["field": .string("safetyState.affectedExerciseId")]))
    }
    if state.kind == .clear && !state.restrictions.isEmpty {
      issues.append(.init("invalid_value", ["field": .string("safetyState.restrictions")]))
      return
    }
    if state.kind == .restricted && state.restrictions.isEmpty {
      issues.append(missing("safetyState.restrictions"))
      return
    }
    var seen: Set<String> = []
    for restriction in state.restrictions {
      let values = [
        "exerciseId": restriction.exerciseId,
        "constraintSnapshotSha256": restriction.constraintSnapshotSha256,
        "catalogVersion": restriction.catalogVersion,
        "taxonomyVersion": restriction.taxonomyVersion,
        "eligibilityRuleSetVersion": restriction.eligibilityRuleSetVersion,
        "originatingRecommendationId": restriction.originatingRecommendationId,
        "regressionTestReference": restriction.regressionTestReference,
        "reviewReference": restriction.reviewReference,
      ]
      for (field, value) in values where value == nil {
        issues.append(missing("safetyState.restrictions.\(field)"))
      }
      if restriction.reviewState == nil {
        issues.append(missing("safetyState.restrictions.reviewState"))
      }
      for (field, value) in [
        ("originatingRecommendationId", restriction.originatingRecommendationId),
        ("regressionTestReference", restriction.regressionTestReference),
        ("reviewReference", restriction.reviewReference),
      ] {
        if let value, !engineMatches(value, #"^[\x20-\x7e]{1,128}$"#) {
          issues.append(
            .init("invalid_value", ["field": .string("safetyState.restrictions.\(field)")]))
        }
      }
      if let id = restriction.exerciseId, !catalogIds.contains(id) {
        issues.append(
          .init(
            "unknown_exercise_id",
            ["field": .string("safetyState.restrictions.exerciseId"), "id": .string(id)]))
      }
      if let digest = restriction.constraintSnapshotSha256, !engineMatches(digest, "^[0-9a-f]{64}$")
      {
        issues.append(
          .init(
            "invalid_value", ["field": .string("safetyState.restrictions.constraintSnapshotSha256")]
          ))
      }
      if (restriction.catalogVersion != nil && restriction.catalogVersion != request.catalogVersion)
        || (restriction.taxonomyVersion != nil
          && restriction.taxonomyVersion != request.taxonomyVersion)
        || (restriction.eligibilityRuleSetVersion != nil
          && restriction.eligibilityRuleSetVersion != request.eligibilityRuleSetVersion)
      {
        issues.append(
          .init(
            "stale_safety_reference",
            ["exerciseId": restriction.exerciseId.map(EngineJSON.string) ?? .null]))
      }
      let key =
        "\(restriction.exerciseId ?? "null")|\(restriction.constraintSnapshotSha256 ?? "null")"
      if !seen.insert(key).inserted {
        issues.append(
          .init(
            "duplicate_input", ["field": .string("safetyState.restrictions"), "id": .string(key)]))
      }
    }
  }
  private func safetyGate(
    _ state: EligibilitySafetyState, _ candidates: Set<String>, _ digest: String
  ) -> [EligibilityIssue] {
    if state.kind == .stop {
      return [
        .init(
          "pain_report_requires_stop",
          ["exerciseId": state.affectedExerciseId.map(EngineJSON.string) ?? .null])
      ]
    }
    return state.restrictions.filter {
      candidates.contains($0.exerciseId!) && $0.constraintSnapshotSha256 == digest
    }.map {
      .init(
        "unresolved_safety_incident",
        [
          "exerciseId": .string($0.exerciseId!),
          "originatingRecommendationId": .string($0.originatingRecommendationId!),
          "regressionTestReference": .string($0.regressionTestReference!),
          "reviewReference": .string($0.reviewReference!),
          "reviewState": .string($0.reviewState!.rawValue),
        ])
    }.sorted()
  }
  private struct EligibilityCandidate {
    let id: String
    let isSelectable: Bool
    let equipment: [EquipmentRequirement]
    let capabilities: Set<String>
    let exclusions: Set<String>
  }
  private func filter(_ candidates: [EligibilityCandidate], _ request: ExerciseEligibilityRequest)
    -> [CandidateEligibilityEvaluation]
  {
    let inventory = Dictionary(
      uniqueKeysWithValues: request.equipmentInventory!.map { ($0.equipmentId, $0) })
    return candidates.sorted { $0.id < $1.id }.map { candidate in
      var reasons: [EligibilityIssue] = []
      func reason(_ code: String, _ extra: [String: EngineJSON] = [:]) {
        var parameters = extra
        parameters["exerciseId"] = .string(candidate.id)
        reasons.append(.init(code, parameters))
      }
      if !candidate.isSelectable { reason("catalog_entry_unselectable") }
      if request.persistentExerciseExclusionIds!.contains(candidate.id) {
        reason("exercise_excluded_persistent")
      }
      if request.requestExerciseExclusionIds!.contains(candidate.id) {
        reason("exercise_excluded_for_request")
      }
      for id in candidate.exclusions.intersection(request.limitationAssessment!.ids).sorted() {
        reason("limitation_conflict", ["limitationId": .string(id)])
      }
      for id in candidate.capabilities.sorted() {
        if request.functionalCapabilityAssessment!.unsupportedIds.contains(id) {
          reason("functional_capability_unsupported", ["capabilityId": .string(id)])
        } else if !request.functionalCapabilityAssessment!.supportedIds.contains(id) {
          reason("functional_capability_unconfirmed", ["capabilityId": .string(id)])
        }
      }
      for requirement in candidate.equipment.sorted(by: { $0.equipmentId < $1.equipmentId }) {
        let parameters: [String: EngineJSON] = ["equipmentId": .string(requirement.equipmentId)]
        if let available = inventory[requirement.equipmentId] {
          if available.quantity < requirement.quantity {
            reason(
              "equipment_quantity_insufficient",
              parameters.merging([
                "availableQuantity": .integer(available.quantity),
                "requiredQuantity": .integer(requirement.quantity),
              ]) { _, rhs in rhs })
          }
          for id in requirement.capabilityIds.subtracting(available.capabilityIds).sorted() {
            reason(
              "equipment_capability_missing",
              parameters.merging(["capabilityId": .string(id)]) { _, rhs in rhs })
          }
        } else {
          reason("equipment_missing", parameters)
        }
        if request.temporarilyUnavailableEquipmentIds!.contains(requirement.equipmentId) {
          reason("equipment_temporarily_unavailable", parameters)
        }
      }
      return .init(exerciseId: candidate.id, reasons: reasons)
    }
  }
  private func missing(_ field: String) -> EligibilityIssue {
    .init("required_input_missing", ["field": .string(field)])
  }
  private func result(
    _ request: ExerciseEligibilityRequest, _ status: EligibilityResultStatus,
    eligible: [String] = [], candidates: [CandidateEligibilityEvaluation] = [],
    issues: [EligibilityIssue] = []
  ) -> ExerciseEligibilityResult {
    .init(
      status: status, eligibilityRuleSetVersion: request.eligibilityRuleSetVersion,
      schemaVersion: request.schemaVersion, catalogVersion: request.catalogVersion,
      taxonomyVersion: request.taxonomyVersion, catalogContentSha256: request.catalogContentSha256,
      constraintSnapshotSha256: request.constraintSnapshotSha256,
      catalogValidationReferenceTime: catalogValidator.importedAt,
      eligibleExerciseIds: eligible.sorted(),
      candidateEvaluations: candidates.sorted { $0.exerciseId < $1.exerciseId },
      requestIssues: issues.sorted())
  }
}
