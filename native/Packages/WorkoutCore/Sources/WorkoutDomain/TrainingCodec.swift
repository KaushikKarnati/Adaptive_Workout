import Foundation

// Field order, explicit nulls, list ordering, and timestamp precision are part of
// the existing Dart storage/receipt contract, not ordinary Codable defaults.
public enum SetupJSON {
  public static func string(_ value: String?) -> String { value.map(ManualJSON.string) ?? "null" }
  public static func bool(_ value: Bool?) -> String {
    value.map { $0 ? "true" : "false" } ?? "null"
  }
  public static func integer(_ value: Int?) -> String { value.map(String.init) ?? "null" }
  public static func date(_ value: Date?) -> String { string(value.map(dartISOString)) }
  public static func strings(_ values: [String]?) -> String {
    values.map { ManualJSON.array($0.sorted().map(ManualJSON.string)) } ?? "null"
  }
  public static func integers(_ values: [Int]) -> String {
    ManualJSON.array(values.sorted().map(String.init))
  }
  public static func object(_ fields: [(String, String)]) -> String { ManualJSON.object(fields) }
  public static func optionalString(_ j: [String: Any], _ key: String) throws -> String? {
    if j[key] == nil || j[key] is NSNull { return nil }
    return try ManualJSON.text(j, key)
  }
  public static func optionalInt(_ j: [String: Any], _ key: String) throws -> Int? {
    if j[key] == nil || j[key] is NSNull { return nil }
    return try ManualJSON.int(j, key)
  }
  public static func optionalBool(_ j: [String: Any], _ key: String) throws -> Bool? {
    if j[key] == nil || j[key] is NSNull { return nil }
    return try ManualJSON.bool(j, key)
  }
  public static func array<T>(_ j: [String: Any], _ key: String, convert: (Any) throws -> T) throws
    -> [T]
  {
    guard let list = j[key] as? [Any] else { throw SetupException("invalid_setup_payload") }
    return try list.map(convert)
  }
  public static func strings(_ j: [String: Any], _ key: String) throws -> [String] {
    try array(j, key) {
      guard let s = $0 as? String else { throw SetupException("invalid_setup_payload") }
      return s
    }
  }
  public static func optionalStrings(_ j: [String: Any], _ key: String) throws -> [String]? {
    if j[key] == nil || j[key] is NSNull { return nil }
    return try strings(j, key)
  }
  public static func integers(_ j: [String: Any], _ key: String) throws -> [Int] {
    try array(j, key) { try ManualJSON.int(["v": $0], "v") }
  }
  public static func dict(_ value: Any) throws -> [String: Any] {
    guard let d = value as? [String: Any] else { throw SetupException("invalid_setup_payload") }
    return d
  }
  public static func convention(_ j: [String: Any]) throws -> SetupLoadConvention {
    guard let c = SetupLoadConvention(rawValue: try ManualJSON.text(j, "convention")) else {
      throw SetupException("invalid_variation_convention")
    }
    return c
  }
  public static func optionalDate(_ j: [String: Any], _ key: String) throws -> Date? {
    try optionalString(j, key).map(dartDate)
  }
  // Validate the integer source instant first. At the final microsecond of
  // year 9999, a Date view rounds into year 10000; use a bounded validation
  // view until the exact source stamp is installed by the decoder below.
  public static func trainingDate(_ text: String) throws -> Date {
    let stamp = try ManualTimestamp(parsing: text)
    try requireSetup(
      (-62_135_596_800_000_000...253_402_300_799_999_999).contains(stamp.microsecondsSince1970),
      "invalid_time")
    return stamp.date.timeIntervalSince1970 >= 253_402_300_800
      ? Date(timeIntervalSince1970: 253_402_300_799.999) : stamp.date
  }
  public static func trainingOptionalDate(_ j: [String: Any], _ key: String) throws -> Date? {
    try optionalString(j, key).map(trainingDate)
  }

}
extension EquipmentSetup {
  public var canonicalJSON: String {
    SetupJSON.object([
      ("id", SetupJSON.string(id)), ("revision", String(revision)),
      ("label", SetupJSON.string(label)), ("variation", SetupJSON.string(variation)),
      ("equipmentId", SetupJSON.string(equipmentId)), ("quantity", String(quantity)),
      ("capabilities", SetupJSON.strings(capabilities)),
      ("convention", SetupJSON.string(convention.rawValue)),
      ("workingLoads", SetupJSON.integers(workingLoads)),
      ("rehearsalLoads", SetupJSON.integers(rehearsalLoads)),
      ("confirmedAt", SetupJSON.string(confirmedStamp?.encoded)),
    ])
  }
  public static func fromJSON(_ j: [String: Any]) throws -> EquipmentSetup {
    var result = try EquipmentSetup(
      id: ManualJSON.text(j, "id"), revision: ManualJSON.int(j, "revision"),
      label: ManualJSON.text(j, "label"), variation: ManualJSON.text(j, "variation"),
      equipmentId: SetupJSON.optionalString(j, "equipmentId"),
      quantity: ManualJSON.int(j, "quantity"), capabilities: SetupJSON.strings(j, "capabilities"),
      convention: SetupJSON.convention(j), workingLoads: SetupJSON.integers(j, "workingLoads"),
      rehearsalLoads: SetupJSON.integers(j, "rehearsalLoads"),
      confirmedAt: SetupJSON.trainingOptionalDate(j, "confirmedAt"))
    result.confirmedStamp = try SetupJSON.optionalString(j, "confirmedAt").map(
      ManualTimestamp.init(parsing:))
    return result
  }
}
extension StartingLoad {
  public var canonicalJSON: String {
    SetupJSON.object([
      ("id", SetupJSON.string(id)), ("sessionId", SetupJSON.string(sessionId)),
      ("slotId", SetupJSON.string(slotId)), ("variation", SetupJSON.string(variation)),
      ("setupId", SetupJSON.string(setupId)), ("setupRevision", String(setupRevision)),
      ("convention", SetupJSON.string(convention.rawValue)),
      ("microPounds", SetupJSON.integer(microPounds)),
      ("confirmedAt", SetupJSON.string(confirmedStamp.encoded)),
    ])
  }
  public static func fromJSON(_ j: [String: Any]) throws -> StartingLoad {
    var result = try StartingLoad(
      id: ManualJSON.text(j, "id"), sessionId: ManualJSON.text(j, "sessionId"),
      slotId: ManualJSON.text(j, "slotId"), variation: ManualJSON.text(j, "variation"),
      setupId: ManualJSON.text(j, "setupId"), setupRevision: ManualJSON.int(j, "setupRevision"),
      convention: SetupJSON.convention(j), microPounds: SetupJSON.optionalInt(j, "microPounds"),
      confirmedAt: SetupJSON.trainingDate(ManualJSON.text(j, "confirmedAt")))
    result.confirmedStamp = try ManualTimestamp(parsing: ManualJSON.text(j, "confirmedAt"))
    return result
  }
}
extension ReportedWorkingSetup {
  public var canonicalJSON: String {
    SetupJSON.object([
      ("id", SetupJSON.string(id)), ("sourceReference", SetupJSON.string(sourceReference)),
      ("recordedAt", SetupJSON.string(recordedStamp.encoded)),
      ("sessionId", SetupJSON.string(sessionId)), ("slotId", SetupJSON.string(slotId)),
      ("variation", SetupJSON.string(variation)),
      ("convention", SetupJSON.string(convention.rawValue)), ("load", SetupJSON.integer(load)),
      ("loadScope", SetupJSON.string(loadScope?.rawValue)),
      ("loadIncrement", SetupJSON.integer(loadIncrement)), ("sets", String(sets)),
      ("minReps", SetupJSON.integer(minReps)), ("maxReps", SetupJSON.integer(maxReps)),
      ("minRir", SetupJSON.integer(minRir)), ("maxRir", SetupJSON.integer(maxRir)),
      ("eachSide", SetupJSON.bool(eachSide)),
    ])
  }
  public static func fromJSON(_ j: [String: Any]) throws -> ReportedWorkingSetup {
    let scope = try SetupJSON.optionalString(j, "loadScope")
    try requireSetup(
      scope == nil || ReportedLoadScope(rawValue: scope!) != nil, "invalid_load_scope")
    var result = try ReportedWorkingSetup(
      id: ManualJSON.text(j, "id"), sourceReference: ManualJSON.text(j, "sourceReference"),
      recordedAt: SetupJSON.trainingDate(ManualJSON.text(j, "recordedAt")),
      sessionId: ManualJSON.text(j, "sessionId"), slotId: ManualJSON.text(j, "slotId"),
      variation: ManualJSON.text(j, "variation"), convention: SetupJSON.convention(j),
      load: SetupJSON.optionalInt(j, "load"), sets: ManualJSON.int(j, "sets"),
      minReps: SetupJSON.optionalInt(j, "minReps"), maxReps: SetupJSON.optionalInt(j, "maxReps"),
      minRir: SetupJSON.optionalInt(j, "minRir"), maxRir: SetupJSON.optionalInt(j, "maxRir"),
      eachSide: ManualJSON.bool(j, "eachSide"),
      loadIncrement: SetupJSON.optionalInt(j, "loadIncrement"),
      loadScope: scope.flatMap(ReportedLoadScope.init(rawValue:)))
    result.recordedStamp = try ManualTimestamp(parsing: ManualJSON.text(j, "recordedAt"))
    return result
  }
}
extension RehearsalConfirmation {
  public var canonicalJSON: String {
    SetupJSON.object([
      ("id", SetupJSON.string(id)), ("sourceReference", SetupJSON.string(sourceReference)),
      ("recordedAt", SetupJSON.string(recordedStamp.encoded)),
      ("sessionId", SetupJSON.string(sessionId)), ("slotId", SetupJSON.string(slotId)),
      ("variation", SetupJSON.string(variation)), ("setupId", SetupJSON.string(setupId)),
      ("setupRevision", SetupJSON.integer(setupRevision)),
      ("easyAndControlled", SetupJSON.bool(easyAndControlled)),
      ("symptomsReported", SetupJSON.bool(symptomsReported)),
      ("assistance", SetupJSON.integer(assistance)),
      ("workingRangeRef", SetupJSON.string(workingRangeRef)),
      ("rehearsalRangeRef", SetupJSON.string(rehearsalRangeRef)),
      ("withinWorkingRange", SetupJSON.bool(withinWorkingRange)),
    ])
  }
  public static func fromJSON(_ j: [String: Any]) throws -> RehearsalConfirmation {
    var result = try RehearsalConfirmation(
      id: ManualJSON.text(j, "id"), sourceReference: ManualJSON.text(j, "sourceReference"),
      recordedAt: SetupJSON.trainingDate(ManualJSON.text(j, "recordedAt")),
      sessionId: ManualJSON.text(j, "sessionId"), slotId: ManualJSON.text(j, "slotId"),
      variation: ManualJSON.text(j, "variation"),
      easyAndControlled: SetupJSON.optionalBool(j, "easyAndControlled"),
      symptomsReported: SetupJSON.optionalBool(j, "symptomsReported"),
      setupId: SetupJSON.optionalString(j, "setupId"),
      setupRevision: SetupJSON.optionalInt(j, "setupRevision"),
      assistance: SetupJSON.optionalInt(j, "assistance"),
      workingRangeRef: SetupJSON.optionalString(j, "workingRangeRef"),
      rehearsalRangeRef: SetupJSON.optionalString(j, "rehearsalRangeRef"),
      withinWorkingRange: SetupJSON.optionalBool(j, "withinWorkingRange"))
    result.recordedStamp = try ManualTimestamp(parsing: ManualJSON.text(j, "recordedAt"))
    return result
  }
}
extension TrainingSetup {
  public func encode() -> String {
    var fields: [(String, String)] = [("schema", String(schemaVersion))]
    if schemaVersion == 2 {
      fields += [
        (
          "reportedWork",
          ManualJSON.array(reportedWork.sorted { $0.id < $1.id }.map(\.canonicalJSON))
        ),
        (
          "rehearsalConfirmations",
          ManualJSON.array(rehearsalConfirmations.sorted { $0.id < $1.id }.map(\.canonicalJSON))
        ),
      ]
    }
    fields += [
      ("programVersion", SetupJSON.string(programVersion)), ("unit", "\"lb\""),
      ("profileId", SetupJSON.string(profileId)), ("revision", String(revision)),
      ("updatedAt", SetupJSON.string(updatedStamp.encoded)),
      ("trainingDays", SetupJSON.integers(trainingDays)),
      ("preferredMinutes", SetupJSON.integer(preferredMinutes)),
      ("supportedCapabilities", SetupJSON.strings(supportedCapabilities)),
      ("unsupportedCapabilities", SetupJSON.strings(unsupportedCapabilities)),
      ("limitations", SetupJSON.strings(limitations)),
      ("excludedVariations", SetupJSON.strings(excludedVariations)),
      ("equipment", ManualJSON.array(equipment.sorted { $0.id < $1.id }.map(\.canonicalJSON))),
      (
        "startingLoads",
        ManualJSON.array(startingLoads.sorted { $0.id < $1.id }.map(\.canonicalJSON))
      ),
    ]
    return SetupJSON.object(fields)
  }
  public static func decode(_ payload: String) throws -> TrainingSetup {
    try requireSetup(payload.utf16.count <= 2_000_000, "payload_too_large")
    do {
      let j = try ManualJSON.decode(payload)
      let schema = try ManualJSON.int(j, "schema")
      try requireSetup(
        [1, 2].contains(schema) && (try ManualJSON.text(j, "unit")) == "lb",
        "unsupported_setup_version_or_unit")
      var result = try TrainingSetup(
        schemaVersion: schema,
        reportedWork: schema == 2
          ? SetupJSON.array(j, "reportedWork") {
            try ReportedWorkingSetup.fromJSON(SetupJSON.dict($0))
          } : [],
        rehearsalConfirmations: schema == 2
          ? SetupJSON.array(j, "rehearsalConfirmations") {
            try RehearsalConfirmation.fromJSON(SetupJSON.dict($0))
          } : [], programVersion: ManualJSON.text(j, "programVersion"),
        profileId: ManualJSON.text(j, "profileId"), revision: ManualJSON.int(j, "revision"),
        updatedAt: dartDate(ManualJSON.text(j, "updatedAt")),
        trainingDays: SetupJSON.integers(j, "trainingDays"),
        preferredMinutes: SetupJSON.optionalInt(j, "preferredMinutes"),
        supportedCapabilities: SetupJSON.optionalStrings(j, "supportedCapabilities"),
        unsupportedCapabilities: SetupJSON.optionalStrings(j, "unsupportedCapabilities"),
        limitations: SetupJSON.optionalStrings(j, "limitations"),
        excludedVariations: SetupJSON.strings(j, "excludedVariations"),
        equipment: SetupJSON.array(j, "equipment") {
          try EquipmentSetup.fromJSON(SetupJSON.dict($0))
        },
        startingLoads: SetupJSON.array(j, "startingLoads") {
          try StartingLoad.fromJSON(SetupJSON.dict($0))
        }, exactUpdatedAt: ManualTimestamp(parsing: ManualJSON.text(j, "updatedAt")))
      result.updatedStamp = try ManualTimestamp(parsing: ManualJSON.text(j, "updatedAt"))
      try result.validateExactChronology()
      try requireSetup(
        ManualJSON.bytesEqual(result.encode(), payload), "noncanonical_setup_payload")
      return result
    } catch let e as SetupException { throw e } catch {
      throw SetupException("invalid_setup_payload")
    }
  }
}
