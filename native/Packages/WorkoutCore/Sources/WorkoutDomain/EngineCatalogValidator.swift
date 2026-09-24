import Foundation

public struct CatalogValidationIssue: Equatable, Sendable, CustomStringConvertible {
  public let code: String
  public let field: String
  public init(_ code: String, _ field: String) {
    self.code = code
    self.field = field
  }
  public var description: String { "\(code):\(field)" }
}

public struct ExerciseCatalogValidator: Sendable {
  public let importedAt: Date
  public let allowedEvidenceHosts: Set<String>
  public init(importedAt: Date, allowedEvidenceHosts: Set<String> = []) {
    self.importedAt = importedAt
    self.allowedEvidenceHosts = allowedEvidenceHosts
  }
  public static let movementPatternIds: Set<String> = [
    "squat", "hinge", "lunge", "horizontal_push", "vertical_push", "horizontal_pull",
    "vertical_pull", "loaded_carry", "elbow_flexion", "elbow_extension", "knee_flexion",
    "knee_extension", "hip_abduction", "hip_adduction", "shoulder_abduction",
    "shoulder_external_rotation", "calf_raise", "trunk_flexion", "trunk_extension",
    "trunk_rotation", "anti_extension", "anti_rotation", "anti_lateral_flexion", "mobility",
  ]
  public static let muscleIds: Set<String> = [
    "chest", "lats", "upper_back", "trapezius", "front_deltoids", "side_deltoids", "rear_deltoids",
    "biceps", "triceps", "forearms_grip", "abdominals", "obliques", "spinal_erectors", "quadriceps",
    "hamstrings", "glutes", "hip_adductors", "hip_abductors", "calves",
  ]
  public static let equipmentIds: Set<String> = [
    "bodyweight_space", "exercise_mat", "standard_barbell", "ez_curl_bar", "weight_plates",
    "power_rack", "flat_bench", "adjustable_bench", "dumbbells", "kettlebells", "stability_ball",
    "cable_station", "pull_up_station", "dip_station", "smith_machine", "leg_press_machine",
    "hack_squat_machine", "leg_extension_machine", "leg_curl_machine", "chest_press_machine",
    "shoulder_press_machine", "row_machine", "lat_pulldown_machine", "pec_fly_reverse_fly_machine",
    "hip_abduction_adduction_machine", "calf_raise_machine", "plate_loaded_machine",
    "resistance_bands", "cardio_machine",
  ]
  public static let equipmentCapabilityIds: Set<String> = [
    "safety_arms", "adjustable_height", "adjustable_angle", "independent_arms", "dual_cable",
    "high_pulley", "low_pulley", "straight_bar_attachment", "rope_attachment",
    "single_handle_attachment", "ankle_strap_attachment", "weight_assistance",
    "incremental_loading",
  ]
  public static let functionalCapabilityIds: Set<String> = [
    "standing_supported", "standing_unsupported", "seated_supported", "supine_position",
    "prone_position", "floor_transfer", "overhead_arm_position", "front_rack_position",
    "bar_on_back_position", "single_leg_support", "deep_knee_flexion", "loaded_hip_hinge",
    "sustained_grip",
  ]
  public static let limitationConflictIds: Set<String> = [
    "avoid_overhead_arm_position", "avoid_front_rack_position", "avoid_bar_on_back_position",
    "avoid_floor_transfer", "avoid_prone_position", "avoid_single_leg_support",
    "avoid_deep_knee_flexion", "avoid_loaded_hip_hinge", "avoid_sustained_grip",
  ]
  public static let licenseUrls: [String: String] = [
    "cc0-1.0": "https://creativecommons.org/publicdomain/zero/1.0/",
    "cc-by-4.0": "https://creativecommons.org/licenses/by/4.0/",
    "cc-by-sa-3.0": "https://creativecommons.org/licenses/by-sa/3.0/",
    "cc-by-sa-4.0": "https://creativecommons.org/licenses/by-sa/4.0/",
  ]
  public func validate(_ entry: ExerciseCatalogEntry) -> [CatalogValidationIssue] {
    var issues: [CatalogValidationIssue] = []
    func issue(_ code: String, _ field: String) { issues.append(.init(code, field)) }
    if !stableId(entry.id) { issue("invalid_id", "id") }
    if entry.wgerBaseId < 1 { issue("invalid_positive_integer", "wgerBaseId") }
    if entry.wgerTranslationId < 1 { issue("invalid_positive_integer", "wgerTranslationId") }
    for (field, value) in [
      ("wgerBaseUuid", entry.wgerBaseUuid), ("wgerTranslationUuid", entry.wgerTranslationUuid),
    ] {
      if !engineMatches(
        value, #"^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"#)
      {
        issue("invalid_uuid", field)
      }
    }
    validateURL(entry.wgerApiUrl, "wgerApiUrl", "wger.de", &issues)
    validateURL(entry.wgerPageUrl, "wgerPageUrl", "wger.de", &issues)
    if let date = entry.sourceModifiedAt { validateDate(date, "sourceModifiedAt", &issues) }
    validateText(entry.name, "name", 80, &issues)
    if entry.aliases.count > 20 { issue("too_many_values", "aliases") }
    for alias in entry.aliases.sorted() { validateText(alias, "aliases", 80, &issues) }
    if let instructions = entry.instructions {
      validateText(instructions, "instructions", 4000, &issues, allowLineFeed: true)
    }
    if entry.language != "en" { issue("unsupported_language", "language") }
    validateIds(
      entry.movementPatternIds, Self.movementPatternIds, "movementPatternIds", 1...4, &issues)
    validateIds(entry.primaryMuscleIds, Self.muscleIds, "primaryMuscleIds", 1...8, &issues)
    validateIds(entry.secondaryMuscleIds, Self.muscleIds, "secondaryMuscleIds", 0...12, &issues)
    if !entry.primaryMuscleIds.intersection(entry.secondaryMuscleIds).isEmpty {
      issue("overlapping_muscles", "secondaryMuscleIds")
    }
    if entry.equipmentRequirements.count > 8 { issue("too_many_values", "equipmentRequirements") }
    var seen: Set<String> = []
    for requirement in entry.equipmentRequirements {
      if !Self.equipmentIds.contains(requirement.equipmentId) {
        issue("unknown_taxonomy_id", "equipmentRequirements.equipmentId")
      }
      if !seen.insert(requirement.equipmentId).inserted {
        issue("duplicate_value", "equipmentRequirements.equipmentId")
      }
      if !(1...8).contains(requirement.quantity) {
        issue("out_of_range", "equipmentRequirements.quantity")
      }
      validateIds(
        requirement.capabilityIds, Self.equipmentCapabilityIds,
        "equipmentRequirements.capabilityIds", 0...8, &issues)
    }
    validateIds(entry.capabilityIds, Self.functionalCapabilityIds, "capabilityIds", 0...32, &issues)
    validateIds(
      entry.exclusionTagIds, Self.limitationConflictIds, "exclusionTagIds", 0...32, &issues)
    if let variation = entry.variationGroupId, !stableId(variation) {
      issue("invalid_id", "variationGroupId")
    }
    if entry.substitutionGroupIds.count > 8 { issue("too_many_values", "substitutionGroupIds") }
    if entry.substitutionGroupIds.contains(where: { !stableId($0) }) {
      issue("invalid_id", "substitutionGroupIds")
    }
    validateAttribution(entry.baseAttribution, "baseAttribution", &issues)
    validateAttribution(entry.translationAttribution, "translationAttribution", &issues)
    if entry.wasModified {
      if let note = entry.modificationNote {
        validateText(note, "modificationNote", 500, &issues)
      } else {
        issue("required_when_modified", "modificationNote")
      }
    } else if entry.modificationNote != nil {
      issue("must_be_null", "modificationNote")
    }
    for (index, review) in entry.reviews.enumerated() {
      validateReview(review, "reviews.\(index)", &issues)
    }
    if entry.availability == .enabled {
      if entry.disabledReason != nil { issue("must_be_null", "disabledReason") }
      if entry.reviews.contains(where: { $0.status != .approved }) {
        issue("enabled_without_approvals", "availability")
      }
    } else if let reason = entry.disabledReason {
      validateText(reason, "disabledReason", 500, &issues)
    } else {
      issue("required_when_disabled", "disabledReason")
    }
    return issues
  }
  private func stableId(_ value: String) -> Bool {
    engineMatches(value, #"^[a-z][a-z0-9_]{1,63}$"#)
  }
  private func validateIds(
    _ values: Set<String>, _ allowed: Set<String>, _ field: String, _ bounds: ClosedRange<Int>,
    _ issues: inout [CatalogValidationIssue]
  ) {
    if !bounds.contains(values.count) { issues.append(.init("value_count_out_of_range", field)) }
    if !values.isSubset(of: allowed) { issues.append(.init("unknown_taxonomy_id", field)) }
  }
  private func validateDate(
    _ value: Date, _ field: String, _ issues: inout [CatalogValidationIssue]
  ) {
    if !engineSecondPrecision(value) {
      issues.append(.init("invalid_timestamp", field))
    } else if value > importedAt {
      issues.append(.init("future_timestamp", field))
    }
  }
  private func validateReview(
    _ review: CatalogReview, _ field: String, _ issues: inout [CatalogValidationIssue]
  ) {
    if review.status == .pending {
      if review.reviewerId != nil || review.reviewedAt != nil || review.evidenceReference != nil {
        issues.append(.init("pending_review_has_decision", field))
      }
      return
    }
    guard let reviewer = review.reviewerId, let date = review.reviewedAt,
      let evidence = review.evidenceReference
    else {
      issues.append(.init("decided_review_incomplete", field))
      return
    }
    if !stableId(reviewer) { issues.append(.init("invalid_reviewer_id", field)) }
    validateDate(date, field, &issues)
    validateText(evidence, field, 500, &issues, allowURL: true)
    let components = URLComponents(string: evidence)
    let decodedPath = components?.percentEncodedPath.removingPercentEncoding
    let isRepositoryDocument =
      evidence.hasPrefix("docs/") && !evidence.contains("\\") && !evidence.contains("//")
      && components?.scheme == nil && components?.query == nil && components?.fragment == nil
      && decodedPath?.split(separator: "/", omittingEmptySubsequences: false).allSatisfy {
        !$0.isEmpty && $0 != "." && $0 != ".."
      } == true
    let isAllowedURL =
      components?.host.map {
        allowedEvidenceHosts.contains($0) && engineValidURL(evidence, host: $0)
      } ?? false
    if !isRepositoryDocument && !isAllowedURL {
      issues.append(.init("invalid_evidence_reference", field))
    }
  }
  private func validateAttribution(
    _ value: CatalogAttribution, _ field: String, _ issues: inout [CatalogValidationIssue]
  ) {
    if let expected = Self.licenseUrls[value.licenseId] {
      if value.licenseUrl != expected { issues.append(.init("license_url_mismatch", field)) }
    } else {
      issues.append(.init("unsupported_license", field))
    }
    validateURL(value.licenseUrl, field, "creativecommons.org", &issues)
    validateURL(value.attributionSourceUrl, field, "wger.de", &issues)
    if value.licenseId != "cc0-1.0" && value.licenseAuthor == nil {
      issues.append(.init("missing_license_author", field))
    }
    if let author = value.licenseAuthor { validateText(author, field, 200, &issues) }
    if let title = value.licenseTitle { validateText(title, field, 200, &issues) }
  }
  private func validateURL(
    _ value: String, _ field: String, _ host: String, _ issues: inout [CatalogValidationIssue]
  ) {
    if !engineValidURL(value, host: host) { issues.append(.init("invalid_url", field)) }
  }
  private func validateText(
    _ value: String, _ field: String, _ maximum: Int, _ issues: inout [CatalogValidationIssue],
    allowLineFeed: Bool = false, allowURL: Bool = false
  ) {
    if value != value.trimmingCharacters(in: .whitespacesAndNewlines) || value.isEmpty
      || value.unicodeScalars.count > maximum
    {
      issues.append(.init("invalid_text_length_or_whitespace", field))
    }
    let forbidden = value.unicodeScalars.contains { scalar in
      let code = scalar.value
      return (code <= 0x1f && !(allowLineFeed && code == 0x0a)) || (0x7f...0x9f).contains(code)
        || (0x202a...0x202e).contains(code) || (0x2066...0x2069).contains(code)
    }
    if forbidden || engineMatches(value, "<[^>]*>")
      || (!allowURL && engineMatches(value, "https?://"))
    {
      issues.append(.init("unsafe_text", field))
    }
  }
}
func engineSecondPrecision(_ value: Date) -> Bool {
  value.timeIntervalSince1970.isFinite
    && value.timeIntervalSince1970.rounded(.towardZero) == value.timeIntervalSince1970
}
func engineValidURL(_ value: String, host: String) -> Bool {
  guard value.utf8.count <= 2048, value.utf8.allSatisfy({ $0 <= 0x7f }),
    let url = URLComponents(string: value)
  else { return false }
  return url.scheme == "https" && url.host == host && url.fragment == nil && url.user == nil
    && url.password == nil
}

public struct ExerciseCatalogManifestValidator: Sendable {
  public let importedAt: Date
  public let allowedEvidenceHosts: Set<String>
  public init(importedAt: Date, allowedEvidenceHosts: Set<String> = []) {
    self.importedAt = importedAt
    self.allowedEvidenceHosts = allowedEvidenceHosts
  }
  public func validate(_ manifest: ExerciseCatalogManifest, _ entries: [ExerciseCatalogEntry])
    -> [CatalogValidationIssue]
  {
    var issues: [CatalogValidationIssue] = []
    func issue(_ code: String, _ field: String) { issues.append(.init(code, field)) }
    if manifest.schemaVersion != "1.0.0" {
      issue("unsupported_schema_version", "manifest.schemaVersion")
    }
    if !validCatalogVersion(manifest.catalogVersion) {
      issue("invalid_catalog_version", "manifest.catalogVersion")
    }
    if manifest.taxonomyVersion != "v2" {
      issue("unsupported_taxonomy_version", "manifest.taxonomyVersion")
    }
    if manifest.provider != "wger" { issue("unsupported_provider", "manifest.provider") }
    if !engineValidURL(manifest.upstreamBaseUrl, host: "wger.de") {
      issue("invalid_url", "manifest.upstreamBaseUrl")
    }
    if !engineSecondPrecision(manifest.retrievedAt) || manifest.retrievedAt > importedAt {
      issue("invalid_retrieved_at", "manifest.retrievedAt")
    }
    if let revision = manifest.sourceRevision,
      revision.isEmpty || revision.utf8.count > 128
        || !revision.utf8.allSatisfy({ (0x20...0x7e).contains($0) })
    {
      issue("invalid_source_revision", "manifest.sourceRevision")
    }
    if !(1...5000).contains(manifest.entryCount) {
      issue("entry_count_out_of_range", "manifest.entryCount")
    }
    if manifest.entryCount != entries.count { issue("entry_count_mismatch", "manifest.entryCount") }
    let validDigest = engineMatches(manifest.contentSha256, "^[0-9a-f]{64}$")
    if !validDigest { issue("invalid_sha256", "manifest.contentSha256") }
    if !engineMatches(
      manifest.importToolVersion,
      #"^(?:[0-9]|[1-9][0-9]{1,2})\.(?:[0-9]|[1-9][0-9]{1,2})\.(?:[0-9]|[1-9][0-9]{1,2})$"#)
    {
      issue("unsupported_import_tool_version", "manifest.importToolVersion")
    }
    var ids: Set<String> = []
    var baseIds: Set<Int> = []
    var baseUUIDs: Set<String> = []
    var translationIds: Set<Int> = []
    var translationUUIDs: Set<String> = []
    var benchmarks: Set<Benchmark> = []
    let validator = ExerciseCatalogValidator(
      importedAt: importedAt, allowedEvidenceHosts: allowedEvidenceHosts)
    for (index, entry) in entries.enumerated() {
      for (inserted, field) in [
        (ids.insert(entry.id).inserted, "id"),
        (baseIds.insert(entry.wgerBaseId).inserted, "wgerBaseId"),
        (baseUUIDs.insert(entry.wgerBaseUuid).inserted, "wgerBaseUuid"),
        (translationIds.insert(entry.wgerTranslationId).inserted, "wgerTranslationId"),
        (translationUUIDs.insert(entry.wgerTranslationUuid).inserted, "wgerTranslationUuid"),
      ] {
        if !inserted { issue("duplicate_value", "entries.\(index).\(field)") }
      }
      if let benchmark = entry.benchmark, !benchmarks.insert(benchmark).inserted {
        issue("duplicate_value", "entries.\(index).benchmark")
      }
      issues += validator.validate(entry).map { .init($0.code, "entries.\(index).\($0.field)") }
    }
    let bytes = canonicalCatalogEntriesBytes(entries)
    if bytes.count > 16 * 1024 * 1024 { issue("entries_payload_too_large", "entries") }
    if validDigest && sha256Hex(bytes) != manifest.contentSha256 {
      issue("integrity_digest_mismatch", "manifest.contentSha256")
    }
    return issues
  }
  private func validCatalogVersion(_ value: String) -> Bool {
    guard
      engineMatches(
        value,
        #"^[0-9]{4}\.(?:0[1-9]|1[0-2])\.(?:0[1-9]|[12][0-9]|3[01])\.(?:[1-9]|[1-9][0-9]{1,2})$"#)
    else { return false }
    let parts = value.split(separator: ".").compactMap { Int($0) }
    let civil = String(format: "%04d-%02d-%02d", parts[0], parts[1], parts[2])
    guard let timestamp = try? ManualTimestamp(parsing: civil + "T00:00:00Z") else { return false }
    return timestamp.encoded.hasPrefix(civil + "T")
  }
}
