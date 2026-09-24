import Foundation
import WorkoutDomain

public enum WgerImportOutcome: String, Sendable { case acceptedEnabled, acceptedDisabled, rejected }
public struct WgerSnapshotValidationException: Error, Equatable, Sendable {
  public let code: String, field: String
  public init(_ code: String, _ field: String) {
    self.code = code
    self.field = field
  }
}
public struct WgerAttributionCandidate: Equatable, Sendable {
  public let licenseId: String, licenseUrl: String, licenseAuthor: String?, licenseTitle: String?,
    attributionSourceUrl: String
}
public struct WgerEquipmentCandidate: Equatable, Sendable {
  public let equipmentId: String, capabilityIds: Set<String>
}
/// Import candidate only. Source mapping never grants an exercise a review or enabled status.
public struct WgerMappedExerciseCandidate: Equatable, Sendable {
  public let id: String, wgerBaseId: Int, wgerBaseUuid: String, wgerTranslationId: Int,
    wgerTranslationUuid: String, wgerApiUrl: String, wgerPageUrl: String, sourceModifiedAt: Date?,
    name: String
  // An array preserves distinct Unicode spellings that Swift Set<String> folds together.
  public let aliases: [String], instructions: String?, primaryMuscleIds: Set<String>,
    secondaryMuscleIds: Set<String>, equipmentCandidates: [WgerEquipmentCandidate],
    sourceCategoryId: Int, baseAttribution: WgerAttributionCandidate,
    translationAttribution: WgerAttributionCandidate
}
public struct WgerImportResult: Equatable, Sendable {
  public let sourceBaseId: Int?, outcome: WgerImportOutcome, reasonCodes: [String],
    candidate: WgerMappedExerciseCandidate?
}
private struct WgerRecordError: Error {
  let code: String
  init(_ code: String) { self.code = code }
}
public struct WgerSourceMapper: Sendable {
  public init() {}
  private static let categories = [
    8: "Arms", 9: "Legs", 10: "Abs", 11: "Chest", 12: "Back", 13: "Shoulders", 14: "Calves",
    15: "Cardio",
  ]
  private static let muscles = [
    1: "Biceps brachii", 2: "Anterior deltoid", 3: "Serratus anterior", 4: "Pectoralis major",
    5: "Triceps brachii", 6: "Rectus abdominis", 7: "Gastrocnemius", 8: "Gluteus maximus",
    9: "Trapezius", 10: "Quadriceps femoris", 11: "Biceps femoris", 12: "Latissimus dorsi",
    13: "Brachialis", 14: "Obliquus externus abdominis", 15: "Soleus",
  ]
  private static let equipment = [
    1: "Barbell", 2: "SZ-Bar", 3: "Dumbbell", 4: "Gym mat", 5: "Swiss Ball", 6: "Pull-up bar",
    7: "none (bodyweight exercise)", 8: "Bench", 9: "Incline bench", 10: "Kettlebell",
    11: "Resistance band", 12: "Cable machine",
  ]
  private static let licenses = [
    1: "CC-BY-SA 3", 2: "CC-BY-SA 4", 3: "CC0", 4: "CC-BY 4", 5: "ODbL",
  ]
  private static let muscleMappings = [
    1: "biceps", 2: "front_deltoids", 4: "chest", 5: "triceps", 6: "abdominals", 7: "calves",
    8: "glutes", 9: "trapezius", 10: "quadriceps", 11: "hamstrings", 12: "lats", 14: "obliques",
    15: "calves",
  ]
  private static let equipmentMappings = [
    1: "standard_barbell", 2: "ez_curl_bar", 3: "dumbbells", 4: "exercise_mat", 5: "stability_ball",
    6: "pull_up_station", 7: "bodyweight_space", 8: "flat_bench", 9: "adjustable_bench",
    10: "kettlebells", 11: "resistance_bands", 12: "cable_station",
  ]
  private static let licenseMappings = [
    1: ("cc-by-sa-3.0", "https://creativecommons.org/licenses/by-sa/3.0/"),
    2: ("cc-by-sa-4.0", "https://creativecommons.org/licenses/by-sa/4.0/"),
    3: ("cc0-1.0", "https://creativecommons.org/publicdomain/zero/1.0/"),
    4: ("cc-by-4.0", "https://creativecommons.org/licenses/by/4.0/"),
  ]
  public func mapPinnedSnapshot(_ sourceBytes: String) throws -> [WgerImportResult] {
    let decoded: Any
    do {
      decoded = try JSONSerialization.jsonObject(
        with: Data(sourceBytes.utf8), options: .fragmentsAllowed)
    } catch { throw WgerSnapshotValidationException("invalid_json", "root") }
    guard let snapshot = decoded as? [String: Any] else {
      throw WgerSnapshotValidationException("invalid_snapshot_root", "root")
    }
    let exercises: [Any]
    do {
      try validateDictionary(snapshot, "categories", Self.categories)
      try validateDictionary(snapshot, "muscles", Self.muscles)
      try validateDictionary(snapshot, "equipment", Self.equipment)
      try validateDictionary(snapshot, "licenses", Self.licenses)
      try validateEnglish(snapshot)
      exercises = try list(snapshot, "exercises")
    } catch let error as WgerRecordError {
      throw WgerSnapshotValidationException(error.code, "snapshot")
    }
    return exercises.map(mapRecord).sorted {
      if ($0.sourceBaseId ?? -1) != ($1.sourceBaseId ?? -1) {
        return ($0.sourceBaseId ?? -1) < ($1.sourceBaseId ?? -1)
      }
      return $0.reasonCodes.joined(separator: ",") < $1.reasonCodes.joined(separator: ",")
    }
  }
  private func mapRecord(_ raw: Any) -> WgerImportResult {
    var sourceBaseId: Int?
    do {
      let record = try object(raw, "exercise")
      let baseId = try positive(record, "id")
      sourceBaseId = baseId
      let baseUuid = try uuid(record, "uuid")
      let category = try reference(record["category"], "category")
      try known(category, record["category"], Self.categories, "category")
      let translations = try list(record, "translations").map { try object($0, "translations") }
        .filter { try english($0["language"]) }
      guard translations.count == 1 else {
        throw WgerRecordError("english_translation_cardinality")
      }
      let translation = translations[0]
      let translationId = try positive(translation, "id")
      let translationUuid = try uuid(translation, "uuid")
      let name = try text(translation, "name")
      var aliases: [String] = []
      for raw in try list(translation, "aliases") {
        let alias = try text(object(raw, "aliases"), "alias")
        guard !aliases.contains(where: { ManualJSON.bytesEqual($0, alias) }) else {
          throw WgerRecordError("duplicate_alias")
        }
        aliases.append(alias)
      }
      var reasons: Set<String> = ["manual_classification_required", "manual_reviews_required"]
      let instructions = mapInstructions(translation, &reasons)
      let primary = try mapMuscles(record, "muscles")
      let secondary = try mapMuscles(record, "muscles_secondary")
      let equipment = try mapEquipment(record, &reasons)
      let baseAttribution = try attribution(record, baseId, false, &reasons)
      let translationAttribution = try attribution(translation, translationId, true, &reasons)
      let modified: Date? =
        record["last_update_global"] == nil || record["last_update_global"] is NSNull
        ? nil : try timestamp(record["last_update_global"], "last_update_global")
      let candidate = WgerMappedExerciseCandidate(
        id: "wger_" + baseUuid.replacingOccurrences(of: "-", with: ""), wgerBaseId: baseId,
        wgerBaseUuid: baseUuid, wgerTranslationId: translationId,
        wgerTranslationUuid: translationUuid,
        wgerApiUrl: "https://wger.de/api/v2/exerciseinfo/\(baseId)/",
        wgerPageUrl: "https://wger.de/en/exercise/\(translationId)/view",
        sourceModifiedAt: modified, name: name, aliases: aliases, instructions: instructions,
        primaryMuscleIds: primary, secondaryMuscleIds: secondary, equipmentCandidates: equipment,
        sourceCategoryId: category, baseAttribution: baseAttribution,
        translationAttribution: translationAttribution)
      return WgerImportResult(
        sourceBaseId: baseId, outcome: .acceptedDisabled, reasonCodes: reasons.sorted(),
        candidate: candidate)
    } catch let error as WgerRecordError {
      return WgerImportResult(
        sourceBaseId: sourceBaseId, outcome: .rejected, reasonCodes: [error.code], candidate: nil)
    } catch {
      return WgerImportResult(
        sourceBaseId: sourceBaseId, outcome: .rejected, reasonCodes: ["invalid_record"],
        candidate: nil)
    }
  }
  private func mapInstructions(_ source: [String: Any], _ reasons: inout Set<String>) -> String? {
    guard let raw = source["description_source"], !(raw is NSNull), !(raw as? String == "") else {
      return nil
    }
    guard let value = raw as? String,
      value == value.trimmingCharacters(in: .whitespacesAndNewlines),
      !matches(
        value,
        #"<|>|https?://|[\x{0000}-\x{0009}\x{000b}-\x{001f}\x{007f}-\x{009f}\x{202a}-\x{202e}\x{2066}-\x{2069}]"#
      )
    else {
      reasons.insert("instructions_manual_review_required")
      return nil
    }
    return value
  }
  private func mapMuscles(_ record: [String: Any], _ field: String) throws -> Set<String> {
    var mapped: Set<String> = []
    for raw in try list(record, field) {
      let id = try reference(raw, field)
      try known(id, raw, Self.muscles, field)
      guard let value = Self.muscleMappings[id] else {
        throw WgerRecordError("unsupported_muscle_\(id)")
      }
      mapped.insert(value)
    }
    return mapped
  }
  private func mapEquipment(_ record: [String: Any], _ reasons: inout Set<String>) throws
    -> [WgerEquipmentCandidate]
  {
    let source = try list(record, "equipment")
    if source.isEmpty { reasons.insert("equipment_review_empty_source") }
    var mapped: [WgerEquipmentCandidate] = []
    var seen: Set<Int> = []
    for raw in source {
      let id = try reference(raw, "equipment")
      try known(id, raw, Self.equipment, "equipment")
      guard seen.insert(id).inserted else { throw WgerRecordError("duplicate_equipment") }
      mapped.append(
        WgerEquipmentCandidate(
          equipmentId: Self.equipmentMappings[id]!,
          capabilityIds: id == 9 ? ["adjustable_angle"] : []))
      if id == 8 { reasons.insert("bench_requirement_confirmation_required") }
      if id == 12 { reasons.insert("cable_capabilities_review_required") }
    }
    return mapped.sorted { $0.equipmentId < $1.equipmentId }
  }
  private func attribution(
    _ source: [String: Any], _ id: Int, _ translation: Bool, _ reasons: inout Set<String>
  ) throws -> WgerAttributionCandidate {
    let license = try reference(source["license"], "license")
    try known(license, source["license"], Self.licenses, "license")
    guard let mapped = Self.licenseMappings[license] else {
      throw WgerRecordError("unsupported_license_\(license)")
    }
    let author = try optionalText(source["license_author"], "license_author")
    let title = try optionalText(source["license_title"], "license_title")
    if license != 3 && author == nil { reasons.insert("license_author_review_required") }
    return WgerAttributionCandidate(
      licenseId: mapped.0, licenseUrl: mapped.1, licenseAuthor: author, licenseTitle: title,
      attributionSourceUrl: translation
        ? "https://wger.de/en/exercise/\(id)/view" : "https://wger.de/api/v2/exerciseinfo/\(id)/")
  }
  private func validateDictionary(
    _ snapshot: [String: Any], _ field: String, _ expected: [Int: String]
  ) throws {
    var actual: [Int: String] = [:]
    for raw in try list(snapshot, field) {
      let row = try object(raw, field)
      let id = try positive(row, "id")
      let name = try text(row, "name")
      guard actual[id] == nil else {
        throw WgerSnapshotValidationException("duplicate_dictionary_id", field)
      }
      actual[id] = name
    }
    let matches = expected.allSatisfy { key, name in
      actual[key].map { ManualJSON.bytesEqual($0, name) } == true
    }
    guard actual.count == expected.count, matches
    else { throw WgerSnapshotValidationException("dictionary_mismatch", field) }
  }
  private func validateEnglish(_ snapshot: [String: Any]) throws {
    var ids: Set<Int> = []
    var names: Set<String> = []
    var english: [String: Any]?
    for raw in try list(snapshot, "languages") {
      let language = try object(raw, "languages")
      let id = try positive(language, "id")
      let name = try text(language, "short_name")
      guard ids.insert(id).inserted else {
        throw WgerSnapshotValidationException("duplicate_dictionary_id", "languages")
      }
      guard names.insert(name).inserted else {
        throw WgerSnapshotValidationException("duplicate_dictionary_name", "languages")
      }
      if id == 2 { english = language }
    }
    guard english?["short_name"] as? String == "en" else {
      throw WgerSnapshotValidationException("dictionary_mismatch", "languages")
    }
  }
  private func english(_ raw: Any?) throws -> Bool {
    let id = try reference(raw, "language")
    if id != 2 { return false }
    if let object = raw as? [String: Any], object["short_name"] != nil,
      object["short_name"] as? String != "en"
    {
      throw WgerRecordError("language_name_mismatch")
    }
    return true
  }
  private func known(_ id: Int, _ raw: Any?, _ dictionary: [Int: String], _ field: String) throws {
    guard let expected = dictionary[id] else { throw WgerRecordError("unknown_\(field)_id") }
    if let object = raw as? [String: Any], object["name"] != nil {
      guard let name = object["name"] as? String, ManualJSON.bytesEqual(name, expected) else {
        throw WgerRecordError("\(field)_name_mismatch")
      }
    }
  }
  private func reference(_ raw: Any?, _ field: String) throws -> Int {
    if let raw, let value = try? ManualJSON.int(["value": raw], "value"), value > 0 { return value }
    if let object = raw as? [String: Any] { return try positive(object, "id") }
    throw WgerRecordError("invalid_\(field)")
  }
  private func positive(_ object: [String: Any], _ field: String) throws -> Int {
    guard let value = try? ManualJSON.int(object, field), value > 0 else {
      throw WgerRecordError("invalid_\(field)")
    }
    return value
  }
  private func uuid(_ object: [String: Any], _ field: String) throws -> String {
    guard let value = object[field] as? String,
      matches(value, #"^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"#)
    else { throw WgerRecordError("invalid_\(field)") }
    return value
  }
  private func text(_ object: [String: Any], _ field: String) throws -> String {
    guard let value = object[field] as? String, !value.isEmpty,
      value == value.trimmingCharacters(in: .whitespacesAndNewlines)
    else { throw WgerRecordError("invalid_\(field)") }
    return value
  }
  private func optionalText(_ value: Any?, _ field: String) throws -> String? {
    guard let value, !(value is NSNull), !(value as? String == "") else { return nil }
    guard let value = value as? String,
      value == value.trimmingCharacters(in: .whitespacesAndNewlines)
    else { throw WgerRecordError("invalid_\(field)") }
    return value
  }
  private func timestamp(_ raw: Any?, _ field: String) throws -> Date {
    guard let value = raw as? String else { throw WgerRecordError("invalid_\(field)") }
    let pattern =
      #"^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(?:Z|[+-](\d{2}):(\d{2}))$"#
    let regex = try NSRegularExpression(pattern: pattern)
    let ns = value as NSString
    guard let match = regex.firstMatch(in: value, range: NSRange(location: 0, length: ns.length)),
      match.range.length == ns.length
    else { throw WgerRecordError("invalid_\(field)") }
    func component(_ index: Int) -> Int {
      match.range(at: index).location == NSNotFound
        ? 0 : Int(ns.substring(with: match.range(at: index)))!
    }
    let year = component(1)
    let month = component(2)
    let day = component(3)
    let hour = component(4)
    let minute = component(5)
    let second = component(6)
    let leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
    let days = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    guard (1...12).contains(month), day >= 1, day <= days[month - 1], hour <= 23, minute <= 59,
      second <= 59, component(7) <= 23, component(8) <= 59,
      let result = try? ManualTimestamp(parsing: value)
    else { throw WgerRecordError("invalid_\(field)") }
    let micros = result.microsecondsSince1970
    let seconds = micros / 1_000_000 - (micros < 0 && micros % 1_000_000 != 0 ? 1 : 0)
    return Date(timeIntervalSince1970: Double(seconds))
  }
  private func list(_ object: [String: Any], _ field: String) throws -> [Any] {
    guard let value = object[field] as? [Any] else { throw WgerRecordError("invalid_\(field)") }
    return value
  }
  private func object(_ raw: Any, _ field: String) throws -> [String: Any] {
    guard let value = raw as? [String: Any] else { throw WgerRecordError("invalid_\(field)") }
    return value
  }
  private func matches(_ text: String, _ pattern: String) -> Bool {
    text.range(of: pattern, options: .regularExpression) != nil
  }
}
