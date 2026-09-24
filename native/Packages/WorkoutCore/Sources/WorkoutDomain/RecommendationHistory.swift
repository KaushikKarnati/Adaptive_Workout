import Foundation

public func checkHistory(_ condition: Bool, _ reason: String) throws {
  if !condition { throw LoggingException(reason) }
}
private func historyNumber(_ value: Int, _ max: Int, _ min: Int = 0) throws {
  try checkHistory(value >= min && value <= max, "invalid_number")
}
private func historyReference(_ value: String) throws {
  try checkHistory(
    !value.isEmpty && value.utf8.count <= 128
      && value.utf8.allSatisfy {
        (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0)
          || [95, 46, 58, 47, 45].contains($0)
      }, "invalid_reference")
}
private enum HistoryJSON {
  static func strings(_ json: [String: Any], _ key: String) throws -> [String] {
    guard let array = json[key] as? [String] else { throw LoggingException("invalid_json_field") }
    return array
  }
  static func objects(_ json: [String: Any], _ key: String) throws -> [[String: Any]] {
    guard let array = json[key] as? [[String: Any]] else {
      throw LoggingException("invalid_json_field")
    }
    return array
  }
  static func stringMap(_ json: [String: Any], _ key: String) throws -> [String: String] {
    guard let map = json[key] as? [String: String] else {
      throw LoggingException("invalid_generation_metadata")
    }
    return map
  }
  static func intMap(_ json: [String: Any], _ key: String) throws -> [String: Int] {
    guard let map = json[key] as? [String: Any] else {
      throw LoggingException("invalid_json_field")
    }
    return try Dictionary(uniqueKeysWithValues: map.keys.map { ($0, try ManualJSON.int(map, $0)) })
  }
  static func encoded(_ map: [String: String]) -> String {
    ManualJSON.object(map.keys.sorted().map { ($0, ManualJSON.string(map[$0]!)) })
  }
  static func encoded(_ map: [String: Int]) -> String {
    ManualJSON.object(map.keys.sorted().map { ($0, String(map[$0]!)) })
  }
  static func optionalString(_ json: [String: Any], _ key: String) throws -> String? {
    json[key] == nil || json[key] is NSNull ? nil : try ManualJSON.text(json, key)
  }
  static func decode(_ payload: String, recommendation: Bool = false) throws -> [String: Any] {
    try checkHistory(payload.utf16.count <= 2_000_000, "payload_too_large")
    let json = try ManualJSON.decode(payload)
    let schema = try ManualJSON.int(json, "schema")
    try checkHistory(
      (schema == 1 || (recommendation && schema == 2))
        && (try ManualJSON.text(json, "unit")) == "lb", "unsupported_snapshot")
    return json
  }
}

public struct RehearsalIdentity: Equatable, Sendable {
  public let exerciseId: String
  public let setupId: String
  public let setupRevision: Int
  public let convention: LoadConvention
  public let verificationReference: String
  public init(
    exerciseId: String, setupId: String, setupRevision: Int, convention: LoadConvention,
    verificationReference: String
  ) throws {
    for value in [exerciseId, setupId, verificationReference] { try validateStorageId(value) }
    try historyNumber(setupRevision, 2_147_483_647)
    self.exerciseId = exerciseId
    self.setupId = setupId
    self.setupRevision = setupRevision
    self.convention = convention
    self.verificationReference = verificationReference
  }
  public func encodedJSON() -> String {
    ManualJSON.object([
      ("exerciseId", ManualJSON.string(exerciseId)), ("setupId", ManualJSON.string(setupId)),
      ("setupRevision", String(setupRevision)),
      ("convention", ManualJSON.string(convention.rawValue)),
      ("verificationReference", ManualJSON.string(verificationReference)),
    ])
  }
  public init(json: [String: Any]) throws {
    guard let convention = LoadConvention(rawValue: try ManualJSON.text(json, "convention")) else {
      throw LoggingException("invalid_load_convention")
    }
    try self.init(
      exerciseId: ManualJSON.text(json, "exerciseId"), setupId: ManualJSON.text(json, "setupId"),
      setupRevision: ManualJSON.int(json, "setupRevision"), convention: convention,
      verificationReference: ManualJSON.text(json, "verificationReference"))
  }
}

public struct SetTarget: Equatable, Sendable {
  public let index: Int
  public let side: LoggedSide
  public let warmup: Bool
  public let load: Int?
  public let minReps: Int
  public let maxReps: Int
  public let minRir: Int?
  public let maxRir: Int?
  public let restSeconds: Int
  public let rangeReference: String?
  public let rehearsalIdentity: RehearsalIdentity?
  public var key: String { "\(warmup ? "warmup" : "work")_\(index)_\(side.rawValue)" }
  public init(
    index: Int, side: LoggedSide, warmup: Bool, load: Int?, minReps: Int, maxReps: Int,
    minRir: Int?, maxRir: Int?, restSeconds: Int, rangeReference: String? = nil,
    rehearsalIdentity: RehearsalIdentity? = nil
  ) throws {
    try historyNumber(index, 1000, 1)
    try historyNumber(minReps, 10_000, 1)
    try historyNumber(maxReps, 10_000, minReps)
    try checkHistory((minRir == nil) == (maxRir == nil), "invalid_effort")
    try checkHistory(warmup || minRir != nil, "working_effort_required")
    if let minRir, let maxRir {
      try historyNumber(minRir, 10_000)
      try historyNumber(maxRir, 10_000, minRir)
    }
    try checkHistory(warmup || rehearsalIdentity == nil, "working_identity_override")
    try historyNumber(restSeconds, 86_400)
    if let load { try historyNumber(load, 1_000_000_000_000) }
    if let rangeReference { try validateStorageId(rangeReference) }
    self.index = index
    self.side = side
    self.warmup = warmup
    self.load = load
    self.minReps = minReps
    self.maxReps = maxReps
    self.minRir = minRir
    self.maxRir = maxRir
    self.restSeconds = restSeconds
    self.rangeReference = rangeReference
    self.rehearsalIdentity = rehearsalIdentity
  }
  public func encodedJSON() -> String {
    var fields: [(String, String)] = [
      ("index", String(index)), ("side", ManualJSON.string(side.rawValue)),
      ("warmup", String(warmup)),
      ("load", ManualJSON.integer(load)), ("minReps", String(minReps)),
      ("maxReps", String(maxReps)), ("minRir", ManualJSON.integer(minRir)),
      ("maxRir", ManualJSON.integer(maxRir)), ("restSeconds", String(restSeconds)),
      ("rangeReference", rangeReference.map(ManualJSON.string) ?? "null"),
    ]
    if let rehearsalIdentity {
      fields.append(("rehearsalIdentity", rehearsalIdentity.encodedJSON()))
    }
    return ManualJSON.object(fields)
  }
  public init(json: [String: Any]) throws {
    guard let side = LoggedSide(rawValue: try ManualJSON.text(json, "side")) else {
      throw LoggingException("invalid_side")
    }
    let identity: RehearsalIdentity?
    if json["rehearsalIdentity"] == nil || json["rehearsalIdentity"] is NSNull {
      identity = nil
    } else {
      guard let object = json["rehearsalIdentity"] as? [String: Any] else {
        throw LoggingException("invalid_json_field")
      }
      identity = try RehearsalIdentity(json: object)
    }
    try self.init(
      index: ManualJSON.int(json, "index"), side: side, warmup: ManualJSON.bool(json, "warmup"),
      load: ManualJSON.optionalInt(json, "load"), minReps: ManualJSON.int(json, "minReps"),
      maxReps: ManualJSON.int(json, "maxReps"),
      minRir: ManualJSON.optionalInt(json, "minRir"),
      maxRir: ManualJSON.optionalInt(json, "maxRir"),
      restSeconds: ManualJSON.int(json, "restSeconds"),
      rangeReference: HistoryJSON.optionalString(json, "rangeReference"),
      rehearsalIdentity: identity)
  }
}

public struct RecommendedSlot: Equatable, Sendable, Identifiable {
  public let id: String
  public let exerciseId: String
  public let blockId: String
  public let setupId: String
  public let setupRevision: Int
  public let baselineReference: String
  public let convention: LoadConvention
  public let unilateral: Bool
  public let targets: [SetTarget]
  public init(
    id: String, exerciseId: String, blockId: String, setupId: String, setupRevision: Int,
    baselineReference: String, convention: LoadConvention, unilateral: Bool, targets: [SetTarget]
  ) throws {
    for value in [id, exerciseId, blockId, setupId, baselineReference] {
      try validateStorageId(value)
    }
    try historyNumber(setupRevision, 2_147_483_647)
    try checkHistory(!targets.isEmpty && targets.count <= 1000, "invalid_targets")
    try checkHistory(Set(targets.map(\.key)).count == targets.count, "duplicate_target")
    let work = targets.filter { !$0.warmup }
    try checkHistory(!work.isEmpty, "working_targets_required")
    for target in targets {
      let kind = target.rehearsalIdentity?.convention ?? convention
      try checkHistory(unilateral ? target.side != .both : target.side == .both, "invalid_side")
      try checkHistory(
        kind == .bodyweight ? target.load == nil : target.load != nil, "invalid_load")
      if kind != .bodyweight {
        try checkHistory(target.load! > 0 || (target.warmup && kind != .assistance), "invalid_load")
      }
    }
    let sides: [LoggedSide] = unilateral ? [.left, .right] : [.both]
    let count = work.count / sides.count
    try checkHistory(count * sides.count == work.count, "invalid_working_sets")
    if count > 0 {
      for index in 1...count {
        for side in sides {
          try checkHistory(
            work.contains { $0.index == index && $0.side == side }, "missing_working_target")
        }
      }
    }
    try checkHistory(
      work.allSatisfy {
        $0.minReps == work[0].minReps && $0.maxReps == work[0].maxReps && $0.load == work[0].load
      }, "mixed_working_prescription")
    self.id = id
    self.exerciseId = exerciseId
    self.blockId = blockId
    self.setupId = setupId
    self.setupRevision = setupRevision
    self.baselineReference = baselineReference
    self.convention = convention
    self.unilateral = unilateral
    self.targets = targets
  }
  public func encodedJSON() -> String {
    ManualJSON.object([
      ("id", ManualJSON.string(id)), ("exerciseId", ManualJSON.string(exerciseId)),
      ("blockId", ManualJSON.string(blockId)),
      ("setupId", ManualJSON.string(setupId)), ("setupRevision", String(setupRevision)),
      ("baselineReference", ManualJSON.string(baselineReference)),
      ("convention", ManualJSON.string(convention.rawValue)), ("unilateral", String(unilateral)),
      ("targets", ManualJSON.array(targets.map { $0.encodedJSON() })),
    ])
  }
  public init(json: [String: Any]) throws {
    guard let convention = LoadConvention(rawValue: try ManualJSON.text(json, "convention")) else {
      throw LoggingException("invalid_load_convention")
    }
    try self.init(
      id: ManualJSON.text(json, "id"), exerciseId: ManualJSON.text(json, "exerciseId"),
      blockId: ManualJSON.text(json, "blockId"),
      setupId: ManualJSON.text(json, "setupId"),
      setupRevision: ManualJSON.int(json, "setupRevision"),
      baselineReference: ManualJSON.text(json, "baselineReference"),
      convention: convention, unilateral: ManualJSON.bool(json, "unilateral"),
      targets: HistoryJSON.objects(json, "targets").map(SetTarget.init(json:)))
  }
}

public enum RecommendationStatus: String, Sendable { case ready, blocked }
public struct RecommendationSnapshot: Equatable, Sendable, Identifiable {
  public let schemaVersion: Int
  public let generationReferences: [String: String]
  public let slotReasons: [String: String]
  public let proposedLoads: [String: Int]
  public let id: String
  public let profile: String
  public let programId: String
  public let programVersion: String
  public let sessionTemplate: String
  public let ruleVersion: String
  public let catalogVersion: String
  public let catalogDigest: String
  public private(set) var createdTimestamp: ManualTimestamp
  public private(set) var requestedTimestamp: ManualTimestamp
  public var createdAt: Date { createdTimestamp.date }
  public var requestedDate: Date { requestedTimestamp.date }
  public let timezone: String
  public let historyRevision: Int
  public let inputRevisions: [String: Int]
  public let evidence: [String: Int]
  public let status: RecommendationStatus
  public let reasons: [String]
  public let slots: [RecommendedSlot]
  public let walkSeconds: Int
  public let preferredMinutes: Int
  public let estimatedSeconds: Int?
  public init(
    schemaVersion: Int = 1, generationReferences: [String: String] = [:],
    slotReasons: [String: String] = [:], proposedLoads: [String: Int] = [:],
    id: String, profile: String, programId: String, programVersion: String, sessionTemplate: String,
    ruleVersion: String,
    catalogVersion: String, catalogDigest: String, createdAt: Date, requestedDate: Date,
    timezone: String, historyRevision: Int,
    inputRevisions: [String: Int], evidence: [String: Int], status: RecommendationStatus,
    reasons: [String], slots: [RecommendedSlot],
    walkSeconds: Int, preferredMinutes: Int, estimatedSeconds: Int?
  ) throws {
    self.schemaVersion = schemaVersion
    self.generationReferences = generationReferences
    self.slotReasons = slotReasons
    self.proposedLoads = proposedLoads
    self.id = id
    self.profile = profile
    self.programId = programId
    self.programVersion = programVersion
    self.sessionTemplate = sessionTemplate
    self.ruleVersion = ruleVersion
    self.catalogVersion = catalogVersion
    self.catalogDigest = catalogDigest
    createdTimestamp = ManualTimestamp(createdAt)
    requestedTimestamp = ManualTimestamp(requestedDate)
    self.timezone = timezone
    self.historyRevision = historyRevision
    self.inputRevisions = inputRevisions
    self.evidence = evidence
    self.status = status
    self.reasons = reasons
    self.slots = slots
    self.walkSeconds = walkSeconds
    self.preferredMinutes = preferredMinutes
    self.estimatedSeconds = estimatedSeconds
    try validate()
  }
  private func validate() throws {
    try checkHistory(schemaVersion == 1 || schemaVersion == 2, "unsupported_snapshot")
    try checkHistory(
      generationReferences.count <= 20 && slotReasons.count <= 100 && proposedLoads.count <= 100,
      "too_many_references")
    for map in [generationReferences, slotReasons] {
      for (key, value) in map {
        try validateStorageId(key)
        try historyReference(value)
      }
    }
    for (key, value) in proposedLoads {
      try validateStorageId(key)
      try historyNumber(value, 1_000_000_000_000, 1)
      try checkHistory(
        status == .ready
          && slots.contains {
            $0.id == key && $0.convention != .bodyweight && $0.convention != .assistance
          }, "invalid_proposal")
    }
    try checkHistory(
      schemaVersion == 2
        || (generationReferences.isEmpty && slotReasons.isEmpty && proposedLoads.isEmpty),
      "schema_two_required")
    if schemaVersion == 1 {
      try checkHistory(
        slots.flatMap(\.targets).allSatisfy { $0.minRir != nil && $0.rehearsalIdentity == nil },
        "schema_two_required")
    }
    for value in [id, profile, programId, sessionTemplate] { try validateStorageId(value) }
    for value in [programVersion, ruleVersion, catalogVersion] { try historyReference(value) }
    try checkHistory(
      catalogDigest.utf8.count == 64
        && catalogDigest.utf8.allSatisfy { (97...102).contains($0) || (48...57).contains($0) },
      "invalid_catalog_digest")
    try checkHistory(createdTimestamp.isValid && requestedTimestamp.isValid, "utc_required")
    try checkHistory(
      requestedTimestamp.microsecondsSince1970 % 86_400_000_000 == 0, "invalid_civil_date")
    try checkHistory(!timezone.isEmpty && timezone.utf16.count <= 128, "invalid_timezone")
    try historyNumber(historyRevision, 2_147_483_647)
    try historyNumber(walkSeconds, 86_400)
    try historyNumber(preferredMinutes, 2_147_483_647, 1)
    if let estimatedSeconds { try historyNumber(estimatedSeconds, 2_147_483_647) }
    try checkHistory(
      Set(inputRevisions.keys).isSuperset(of: [
        "profile", "equipment", "baseline", "constraints", "safety", "catalogSchema", "taxonomy",
      ]), "missing_input_references")
    try checkHistory(inputRevisions.count <= 100 && evidence.count <= 10_000, "too_many_references")
    for map in [inputRevisions, evidence] {
      for (key, value) in map {
        try validateStorageId(key)
        try historyNumber(value, 2_147_483_647)
      }
    }
    try checkHistory(
      !reasons.isEmpty && reasons.count <= 100 && Set(reasons).count == reasons.count,
      "invalid_reasons")
    for reason in reasons { try validateStorageId(reason) }
    try checkHistory(
      slots.count <= 100 && Set(slots.map(\.id)).count == slots.count, "invalid_slots")
    try checkHistory(status == .ready ? !slots.isEmpty : slots.isEmpty, "invalid_status_targets")
  }
  public func encode() -> String {
    var fields: [(String, String)] = [("schema", String(schemaVersion))]
    if schemaVersion == 2 {
      fields += [
        ("generationReferences", HistoryJSON.encoded(generationReferences)),
        ("slotReasons", HistoryJSON.encoded(slotReasons)),
        ("proposedLoads", HistoryJSON.encoded(proposedLoads)),
      ]
    }
    fields += [
      ("unit", "\"lb\""), ("id", ManualJSON.string(id)), ("profile", ManualJSON.string(profile)),
      ("programId", ManualJSON.string(programId)),
      ("programVersion", ManualJSON.string(programVersion)),
      ("sessionTemplate", ManualJSON.string(sessionTemplate)),
      ("ruleVersion", ManualJSON.string(ruleVersion)),
      ("catalogVersion", ManualJSON.string(catalogVersion)),
      ("catalogDigest", ManualJSON.string(catalogDigest)),
      ("createdAt", ManualJSON.string(createdTimestamp.encoded)),
      ("requestedDate", ManualJSON.string(requestedTimestamp.encoded)),
      ("timezone", ManualJSON.string(timezone)), ("historyRevision", String(historyRevision)),
      ("inputRevisions", HistoryJSON.encoded(inputRevisions)),
      ("evidence", HistoryJSON.encoded(evidence)), ("status", ManualJSON.string(status.rawValue)),
      ("reasons", ManualJSON.array(reasons.map(ManualJSON.string))),
      ("slots", ManualJSON.array(slots.map { $0.encodedJSON() })),
      ("walkSeconds", String(walkSeconds)), ("preferredMinutes", String(preferredMinutes)),
      ("estimatedSeconds", ManualJSON.integer(estimatedSeconds)),
    ]
    return ManualJSON.object(fields)
  }
  public static func decode(_ payload: String) throws -> RecommendationSnapshot {
    let json = try HistoryJSON.decode(payload, recommendation: true)
    let schema = try ManualJSON.int(json, "schema")
    guard let status = RecommendationStatus(rawValue: try ManualJSON.text(json, "status")) else {
      throw LoggingException("invalid_status_targets")
    }
    let created = try ManualTimestamp(parsing: ManualJSON.text(json, "createdAt"))
    let requested = try ManualTimestamp(parsing: ManualJSON.text(json, "requestedDate"))
    var result = try RecommendationSnapshot(
      schemaVersion: schema,
      generationReferences: schema == 2 ? HistoryJSON.stringMap(json, "generationReferences") : [:],
      slotReasons: schema == 2 ? HistoryJSON.stringMap(json, "slotReasons") : [:],
      proposedLoads: schema == 2 ? HistoryJSON.intMap(json, "proposedLoads") : [:],
      id: ManualJSON.text(json, "id"), profile: ManualJSON.text(json, "profile"),
      programId: ManualJSON.text(json, "programId"),
      programVersion: ManualJSON.text(json, "programVersion"),
      sessionTemplate: ManualJSON.text(json, "sessionTemplate"),
      ruleVersion: ManualJSON.text(json, "ruleVersion"),
      catalogVersion: ManualJSON.text(json, "catalogVersion"),
      catalogDigest: ManualJSON.text(json, "catalogDigest"), createdAt: created.date,
      requestedDate: requested.date,
      timezone: ManualJSON.text(json, "timezone"),
      historyRevision: ManualJSON.int(json, "historyRevision"),
      inputRevisions: HistoryJSON.intMap(json, "inputRevisions"),
      evidence: HistoryJSON.intMap(json, "evidence"), status: status,
      reasons: HistoryJSON.strings(json, "reasons"),
      slots: HistoryJSON.objects(json, "slots").map(RecommendedSlot.init(json:)),
      walkSeconds: ManualJSON.int(json, "walkSeconds"),
      preferredMinutes: ManualJSON.int(json, "preferredMinutes"),
      estimatedSeconds: ManualJSON.optionalInt(json, "estimatedSeconds"))
    result.createdTimestamp = created
    result.requestedTimestamp = requested
    try result.validate()
    try checkHistory(ManualJSON.bytesEqual(result.encode(), payload), "noncanonical_snapshot")
    return result
  }
}

public enum OccurrenceStatus: String, Sendable { case active, completed, endedEarly }
public struct GeneratedOccurrence: Equatable, Sendable, Identifiable {
  public let id: String
  public let profile: String
  public let recommendationId: String
  public let sequence: Int
  public let revision: Int
  public private(set) var startedTimestamp: ManualTimestamp
  public private(set) var updatedTimestamp: ManualTimestamp
  public private(set) var endedTimestamp: ManualTimestamp?
  public var startedAt: Date { startedTimestamp.date }
  public var updatedAt: Date { updatedTimestamp.date }
  public var endedAt: Date? { endedTimestamp?.date }
  public let status: OccurrenceStatus
  public let sets: [ProgramSet]
  public let stoppedSlots: [String]
  public init(
    id: String, profile: String, recommendationId: String, sequence: Int, revision: Int,
    startedAt: Date, updatedAt: Date, endedAt: Date?, status: OccurrenceStatus, sets: [ProgramSet],
    stoppedSlots: [String]
  ) throws {
    self.id = id
    self.profile = profile
    self.recommendationId = recommendationId
    self.sequence = sequence
    self.revision = revision
    startedTimestamp = ManualTimestamp(startedAt)
    updatedTimestamp = ManualTimestamp(updatedAt)
    endedTimestamp = endedAt.map(ManualTimestamp.init)
    self.status = status
    self.sets = sets
    self.stoppedSlots = stoppedSlots
    try validate()
  }
  private func validate() throws {
    for value in [id, profile, recommendationId] { try validateStorageId(value) }
    try historyNumber(sequence, 2_147_483_647)
    try historyNumber(revision, 2_147_483_647)
    try checkHistory(startedTimestamp.isValid && updatedTimestamp.isValid, "utc_required")
    try checkHistory(updatedTimestamp >= startedTimestamp, "invalid_time")
    try checkHistory((status == .active) == (endedTimestamp == nil), "invalid_terminal_state")
    if let end = endedTimestamp {
      try checkHistory(
        end.isValid && end >= startedTimestamp && updatedTimestamp >= end, "invalid_time")
    }
    try checkHistory(
      sets.count <= 100_000 && Set(sets.map(\.key)).count == sets.count, "duplicate_actual")
    try checkHistory(Set(stoppedSlots).count == stoppedSlots.count, "duplicate_stop")
  }
  public func validateAgainst(_ plan: RecommendationSnapshot) throws {
    try checkHistory(
      plan.id == recommendationId && plan.profile == profile && plan.status == .ready,
      "recommendation_mismatch")
    try checkHistory(startedTimestamp >= plan.createdTimestamp, "invalid_start_time")
    for id in stoppedSlots { try checkHistory(plan.slots.contains { $0.id == id }, "unknown_stop") }
    for set in sets {
      guard let slot = plan.slots.first(where: { $0.id == set.slot }) else {
        throw LoggingException("unknown_slot")
      }
      guard let target = slot.targets.first(where: { "\(slot.id)_\($0.key)" == set.key }) else {
        throw LoggingException("unknown_target")
      }
      let identity = target.rehearsalIdentity
      let convention = identity?.convention ?? slot.convention
      try checkHistory(
        set.variant == (identity?.exerciseId ?? slot.exerciseId)
          && set.setup == (identity?.setupId ?? slot.setupId) && set.convention == convention,
        "actual_context_mismatch")
      if set.skipped {
        try checkHistory(
          set.load == nil && set.reps == nil && set.rir == nil && set.validity == .unknown,
          "invalid_skip")
      } else {
        try checkHistory(
          convention == .bodyweight ? set.load == nil : set.load != nil, "invalid_load")
        if let load = set.load { try historyNumber(load, 1_000_000_000_000) }
        guard let reps = set.reps else { throw LoggingException("missing_reps") }
        try historyNumber(reps, 10_000)
        if let rir = set.rir { try historyNumber(rir, 10_000) }
      }
      if set.validity == .pain {
        try checkHistory(stoppedSlots.contains(set.slot), "missing_safety_stop")
      }
    }
    if status == .completed {
      for slot in plan.slots {
        for target in slot.targets where !target.warmup {
          try checkHistory(
            sets.contains { $0.key == "\(slot.id)_\(target.key)" }, "unrecorded_sets")
        }
      }
    }
  }
  public func record(_ set: ProgramSet, at: Date, prescription: RecommendationSnapshot) throws
    -> GeneratedOccurrence
  {
    try record(set, timestamp: ManualTimestamp(at), prescription: prescription)
  }
  public func record(
    _ set: ProgramSet, timestamp: ManualTimestamp, prescription: RecommendationSnapshot
  ) throws -> GeneratedOccurrence {
    let exists = sets.contains { $0.key == set.key }
    try checkHistory(status == .active || exists, "terminal_session")
    try checkHistory(exists || set.skipped || !stoppedSlots.contains(set.slot), "exercise_stopped")
    var stops = Set(stoppedSlots)
    if set.validity == .pain { stops.insert(set.slot) }
    let next = try copy(
      at: timestamp, sets: sets.filter { $0.key != set.key } + [set], stops: stops.sorted())
    try next.validateAgainst(prescription)
    return next
  }
  public func finish(at: Date, status: OccurrenceStatus, prescription: RecommendationSnapshot)
    throws -> GeneratedOccurrence
  {
    try finish(timestamp: ManualTimestamp(at), status: status, prescription: prescription)
  }
  public func finish(
    timestamp: ManualTimestamp, status state: OccurrenceStatus, prescription: RecommendationSnapshot
  ) throws -> GeneratedOccurrence {
    try checkHistory(status == .active && state != .active, "invalid_finish")
    let next = try copy(at: timestamp, state: state, end: timestamp)
    try next.validateAgainst(prescription)
    return next
  }
  private func copy(
    at: ManualTimestamp, sets: [ProgramSet]? = nil, stops: [String]? = nil,
    state: OccurrenceStatus? = nil, end: ManualTimestamp? = nil
  ) throws -> GeneratedOccurrence {
    try checkHistory(at >= updatedTimestamp, "nonmonotonic_time")
    try checkHistory(revision < 2_147_483_647, "invalid_number")
    var next = try GeneratedOccurrence(
      id: id, profile: profile, recommendationId: recommendationId, sequence: sequence,
      revision: revision + 1,
      startedAt: startedAt, updatedAt: at.date, endedAt: (end ?? endedTimestamp)?.date,
      status: state ?? status, sets: sets ?? self.sets, stoppedSlots: stops ?? stoppedSlots)
    next.startedTimestamp = startedTimestamp
    next.updatedTimestamp = at
    next.endedTimestamp = end ?? endedTimestamp
    try next.validate()
    return next
  }
  public func encode() -> String {
    ManualJSON.object([
      ("schema", "1"), ("unit", "\"lb\""), ("id", ManualJSON.string(id)),
      ("profile", ManualJSON.string(profile)),
      ("recommendationId", ManualJSON.string(recommendationId)), ("sequence", String(sequence)),
      ("revision", String(revision)),
      ("startedAt", ManualJSON.string(startedTimestamp.encoded)),
      ("updatedAt", ManualJSON.string(updatedTimestamp.encoded)),
      ("endedAt", endedTimestamp.map { ManualJSON.string($0.encoded) } ?? "null"),
      ("status", ManualJSON.string(status.rawValue)),
      ("sets", ManualJSON.array(sets.sorted { $0.key < $1.key }.map { $0.encodedJSON() })),
      ("stoppedSlots", ManualJSON.array(stoppedSlots.sorted().map(ManualJSON.string))),
    ])
  }
  public static func decode(_ payload: String) throws -> GeneratedOccurrence {
    let json = try HistoryJSON.decode(payload)
    guard let status = OccurrenceStatus(rawValue: try ManualJSON.text(json, "status")) else {
      throw LoggingException("invalid_terminal_state")
    }
    let start = try ManualTimestamp(parsing: ManualJSON.text(json, "startedAt"))
    let update = try ManualTimestamp(parsing: ManualJSON.text(json, "updatedAt"))
    let end = try HistoryJSON.optionalString(json, "endedAt").map {
      try ManualTimestamp(parsing: $0)
    }
    var result = try GeneratedOccurrence(
      id: ManualJSON.text(json, "id"), profile: ManualJSON.text(json, "profile"),
      recommendationId: ManualJSON.text(json, "recommendationId"),
      sequence: ManualJSON.int(json, "sequence"), revision: ManualJSON.int(json, "revision"),
      startedAt: start.date, updatedAt: update.date, endedAt: end?.date, status: status,
      sets: HistoryJSON.objects(json, "sets").map(ProgramSet.init(json:)),
      stoppedSlots: HistoryJSON.strings(json, "stoppedSlots"))
    result.startedTimestamp = start
    result.updatedTimestamp = update
    result.endedTimestamp = end
    try result.validate()
    try checkHistory(ManualJSON.bytesEqual(result.encode(), payload), "noncanonical_occurrence")
    return result
  }
}

public func validateOccurrenceTransition(
  _ old: GeneratedOccurrence, _ next: GeneratedOccurrence, _ plan: RecommendationSnapshot
) throws {
  try checkHistory(
    old.id == next.id && old.profile == next.profile
      && old.recommendationId == next.recommendationId && old.sequence == next.sequence
      && old.startedTimestamp == next.startedTimestamp && old.revision < 2_147_483_647
      && next.revision == old.revision + 1, "invalid_transition")
  var expected: GeneratedOccurrence?
  if old.status != next.status {
    expected = try old.finish(
      timestamp: next.updatedTimestamp, status: next.status, prescription: plan)
  } else {
    let changed = next.sets.filter { !old.sets.contains($0) }
    if changed.count == 1 {
      expected = try old.record(changed[0], timestamp: next.updatedTimestamp, prescription: plan)
    }
  }
  try checkHistory(
    expected.map({ ManualJSON.bytesEqual($0.encode(), next.encode()) }) == true,
    "invalid_transition")
}

public struct GeneratedHistory: Equatable, Sendable {
  public let profile: String
  public let revision: Int
  public let recommendations: [RecommendationSnapshot]
  public let occurrences: [GeneratedOccurrence]
  public init(
    profile: String, revision: Int, recommendations: [RecommendationSnapshot],
    occurrences: [GeneratedOccurrence]
  ) throws {
    try validateStorageId(profile)
    try historyNumber(revision, 2_147_483_647)
    try checkHistory(
      recommendations.allSatisfy { $0.profile == profile }
        && Set(recommendations.map(\.id)).count == recommendations.count, "invalid_recommendations")
    let ordered = occurrences.sorted { $0.sequence < $1.sequence }
    try checkHistory(
      Set(ordered.map(\.id)).count == ordered.count
        && Set(ordered.map(\.recommendationId)).count == ordered.count, "duplicate_occurrence")
    for (index, occurrence) in ordered.enumerated() {
      try checkHistory(
        occurrence.profile == profile && occurrence.sequence == index, "incomplete_history")
      try checkHistory(
        index == ordered.count - 1 || occurrence.status != .active, "multiple_active")
      if index > 0 {
        guard let previousEnd = ordered[index - 1].endedTimestamp else {
          throw LoggingException("multiple_active")
        }
        try checkHistory(occurrence.startedTimestamp >= previousEnd, "nonmonotonic_sequence")
      }
      guard let plan = recommendations.first(where: { $0.id == occurrence.recommendationId }) else {
        throw LoggingException("missing_recommendation")
      }
      try occurrence.validateAgainst(plan)
    }
    var expectedRevision = 0
    for occurrence in occurrences {
      let addition = expectedRevision.addingReportingOverflow(occurrence.revision + 1)
      try checkHistory(
        !addition.overflow && addition.partialValue <= 2_147_483_647, "history_revision_mismatch")
      expectedRevision = addition.partialValue
    }
    try checkHistory(revision == expectedRevision, "history_revision_mismatch")
    self.profile = profile
    self.revision = revision
    self.recommendations = recommendations
    self.occurrences = occurrences
  }
  public func isStale(_ recommendation: RecommendationSnapshot) -> Bool {
    recommendation.profile != profile || recommendation.historyRevision != revision
  }
  public func progression(
    programId: String, programVersion: String, sessionTemplate: String, current: RecommendedSlot
  ) -> [ProgressionExposure] {
    let context = progressionContext(profile, programId, sessionTemplate, current)
    var result: [ProgressionExposure] = []
    for occurrence in occurrences {
      guard let plan = recommendations.first(where: { $0.id == occurrence.recommendationId }),
        plan.programId == programId, plan.sessionTemplate == sessionTemplate
      else { continue }
      guard let slot = plan.slots.first(where: { $0.id == current.id }) else {
        result.append(
          ProgressionExposure(
            id: occurrence.id, sequence: occurrence.sequence, occurredAt: occurrence.startedAt,
            context: context,
            completed: false, correctedOut: false, sets: []))
        continue
      }
      let previousContext = progressionContext(profile, programId, sessionTemplate, slot)
      let completed =
        occurrence.status == .completed && plan.programVersion == programVersion
        && slot.baselineReference == current.baselineReference
        && slot.targets.filter { !$0.warmup } == current.targets.filter { !$0.warmup }
        && !occurrence.stoppedSlots.contains(slot.id) && previousContext == context
      let sets = occurrence.sets.filter { $0.slot == slot.id && !$0.warmup }.map { set in
        ProgressionSet(
          index: set.index,
          side: set.side == .both ? .bilateral : set.side == .left ? .left : .right,
          microPounds: set.load, reps: set.reps, rir: set.rir,
          valid: set.skipped
            ? false : set.validity == .valid ? true : set.validity == .unknown ? nil : false)
      }
      result.append(
        ProgressionExposure(
          id: occurrence.id, sequence: occurrence.sequence, occurredAt: occurrence.startedAt,
          context: previousContext, completed: completed, correctedOut: false, sets: sets))
    }
    return result.sorted { $0.sequence < $1.sequence }
  }
}

public func progressionContext(
  _ profile: String, _ program: String, _ session: String, _ slot: RecommendedSlot
) -> ProgressionContext {
  let work = slot.targets.filter { !$0.warmup }
  return ProgressionContext(
    profileId: profile,
    slotId: ManualJSON.array([program, session, slot.id].map(ManualJSON.string)),
    exerciseId: slot.exerciseId,
    setupId: ManualJSON.array([ManualJSON.string(slot.setupId), String(slot.setupRevision)]),
    loadConventionId: slot.convention.rawValue,
    setCount: work.count / (slot.unilateral ? 2 : 1), minReps: work[0].minReps,
    maxReps: work[0].maxReps, unilateral: slot.unilateral,
    loadKind: slot.convention == .bodyweight
      ? .bodyweight : slot.convention == .assistance ? .assistance : .external)
}
public protocol RecommendationHistoryRepository: Sendable {
  func load(_ profile: String) throws -> GeneratedHistory
  func saveRecommendation(_ recommendation: RecommendationSnapshot, actionId: String) throws
  func saveOccurrence(
    _ occurrence: GeneratedOccurrence, expectedRevision: Int, expectedHistoryRevision: Int,
    actionId: String) throws
  func audit(_ profile: String, occurrenceId: String) throws -> [GeneratedOccurrence]
  func close() throws
}
