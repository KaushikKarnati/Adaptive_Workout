import Foundation
import WorkoutDomain

/// Independent generated-history store; manual and practice records are never read.
public final class SqliteRecommendationHistoryRepository: RecommendationHistoryRepository, Sendable
{
  private let db: SQLiteDatabase
  public init(path: String) throws {
    db = try SQLiteDatabase(path: path)
    do {
      try db.execute("PRAGMA synchronous=FULL")
      try checkHistory(
        try db.rows("PRAGMA foreign_keys").first?["foreign_keys"]?.int == 1, "foreign_keys_required"
      )
      try db.transaction {
        guard let version = try db.rows("PRAGMA user_version").first?["user_version"]?.int,
          version == 0 || version == 1
        else { throw LoggingException("unsupported_schema") }
        if version == 0 {
          for sql in [
            "CREATE TABLE profiles(id TEXT PRIMARY KEY,revision INTEGER NOT NULL)",
            "CREATE TABLE recommendations(profile TEXT NOT NULL,id TEXT NOT NULL,payload TEXT NOT NULL,PRIMARY KEY(profile,id),FOREIGN KEY(profile) REFERENCES profiles(id))",
            "CREATE TABLE occurrences(profile TEXT NOT NULL,id TEXT NOT NULL,recommendation TEXT NOT NULL,sequence INTEGER NOT NULL,revision INTEGER NOT NULL,active INTEGER NOT NULL,payload TEXT NOT NULL,PRIMARY KEY(profile,id),UNIQUE(profile,sequence),UNIQUE(profile,recommendation),FOREIGN KEY(profile,recommendation) REFERENCES recommendations(profile,id))",
            "CREATE UNIQUE INDEX one_active_generated_session ON occurrences(profile) WHERE active=1",
            "CREATE TABLE revisions(profile TEXT NOT NULL,id TEXT NOT NULL,revision INTEGER NOT NULL,payload TEXT NOT NULL,PRIMARY KEY(profile,id,revision),FOREIGN KEY(profile,id) REFERENCES occurrences(profile,id))",
            "CREATE TABLE receipts(profile TEXT NOT NULL,action TEXT NOT NULL,request TEXT NOT NULL,PRIMARY KEY(profile,action),FOREIGN KEY(profile) REFERENCES profiles(id))",
          ] { try db.execute(sql) }
          try db.execute("PRAGMA user_version=1")
        }
      }
    } catch {
      try? db.close()
      throw error
    }
  }
  private func loadSnapshot(_ profile: String) throws -> GeneratedHistory {
    try validateStorageId(profile)
    let profiles = try db.rows("SELECT * FROM profiles WHERE id=?", [.text(profile)])
    let rows = try db.rows("SELECT * FROM recommendations WHERE profile=?", [.text(profile)])
    let plans = try rows.map { row in
      guard let payload = row["payload"]?.string else { throw LoggingException("invalid_snapshot") }
      let plan = try RecommendationSnapshot.decode(payload)
      try checkHistory(
        plan.id == row["id"]?.string && plan.profile == row["profile"]?.string,
        "stored_identity_mismatch")
      return plan
    }
    let logs = try db.rows(
      "SELECT * FROM occurrences WHERE profile=? ORDER BY sequence", [.text(profile)])
    let occurrences = try logs.map { row in
      guard let payload = row["payload"]?.string else { throw LoggingException("invalid_snapshot") }
      let occurrence = try GeneratedOccurrence.decode(payload)
      try checkHistory(
        occurrence.id == row["id"]?.string && occurrence.profile == row["profile"]?.string
          && occurrence.recommendationId == row["recommendation"]?.string
          && occurrence.sequence == row["sequence"]?.int
          && occurrence.revision == row["revision"]?.int
          && (occurrence.status == .active ? 1 : 0) == row["active"]?.int,
        "stored_identity_mismatch")
      return occurrence
    }
    try checkHistory(!profiles.isEmpty || (plans.isEmpty && occurrences.isEmpty), "missing_profile")
    let revision: Int
    if profiles.isEmpty {
      revision = 0
    } else {
      guard let stored = profiles[0]["revision"]?.int else {
        throw LoggingException("history_revision_mismatch")
      }
      revision = stored
    }
    let history = try GeneratedHistory(
      profile: profile, revision: revision, recommendations: plans, occurrences: occurrences)
    for occurrence in occurrences {
      guard let plan = plans.first(where: { $0.id == occurrence.recommendationId }) else {
        throw LoggingException("missing_recommendation")
      }
      _ = try auditRows(occurrence, plan)
    }
    return history
  }
  public func load(_ profile: String) throws -> GeneratedHistory {
    try db.transaction { try loadSnapshot(profile) }
  }
  private func retry(_ profile: String, _ action: String, _ request: String) throws -> Bool {
    try validateStorageId(action)
    let rows = try db.rows(
      "SELECT * FROM receipts WHERE profile=? AND action=?", [.text(profile), .text(action)])
    guard let saved = rows.first else { return false }
    try checkHistory(
      saved["request"]?.string.map({ ManualJSON.bytesEqual($0, request) }) == true,
      "action_conflict")
    return true
  }
  private func receipt(_ profile: String, _ action: String, _ request: String) throws {
    try db.execute(
      "INSERT INTO receipts(profile,action,request) VALUES(?,?,?)",
      [.text(profile), .text(action), .text(request)])
  }
  public func saveRecommendation(_ recommendation: RecommendationSnapshot, actionId: String) throws
  {
    let plan = try RecommendationSnapshot.decode(recommendation.encode())
    let request = ManualJSON.object([
      ("operation", "\"recommendation\""), ("payload", ManualJSON.string(plan.encode())),
    ])
    try db.transaction {
      let history = try loadSnapshot(plan.profile)
      if try retry(plan.profile, actionId, request) { return }
      try checkHistory(!history.isStale(plan), "stale_history")
      try checkHistory(
        !history.recommendations.contains { $0.id == plan.id }, "immutable_recommendation")
      for (id, revision) in plan.evidence {
        try checkHistory(
          history.occurrences.contains { $0.id == id && $0.revision == revision },
          "stale_or_missing_evidence")
      }
      if let lastUpdate = history.occurrences.map(\.updatedTimestamp).max() {
        try checkHistory(plan.createdTimestamp >= lastUpdate, "invalid_generation_time")
      }
      try db.execute(
        "INSERT OR IGNORE INTO profiles(id,revision) VALUES(?,?)",
        [.text(plan.profile), .integer(Int64(history.revision))])
      try db.execute(
        "INSERT INTO recommendations(profile,id,payload) VALUES(?,?,?)",
        [.text(plan.profile), .text(plan.id), .text(plan.encode())])
      try receipt(plan.profile, actionId, request)
    }
  }
  public func saveOccurrence(
    _ occurrence: GeneratedOccurrence, expectedRevision: Int, expectedHistoryRevision: Int,
    actionId: String
  ) throws {
    let next = try GeneratedOccurrence.decode(occurrence.encode())
    let request = ManualJSON.object([
      ("operation", "\"occurrence\""), ("expectedRevision", String(expectedRevision)),
      ("expectedHistoryRevision", String(expectedHistoryRevision)),
      ("payload", ManualJSON.string(next.encode())),
    ])
    try db.transaction {
      let history = try loadSnapshot(next.profile)
      if try retry(next.profile, actionId, request) { return }
      try checkHistory(history.revision == expectedHistoryRevision, "stale_history")
      guard let plan = history.recommendations.first(where: { $0.id == next.recommendationId })
      else { throw LoggingException("missing_recommendation") }
      try next.validateAgainst(plan)
      let old = history.occurrences.first { $0.id == next.id }
      if let old {
        try checkHistory(old.revision == expectedRevision, "stale_revision")
        try validateOccurrenceTransition(old, next, plan)
        try db.execute(
          "INSERT INTO revisions(profile,id,revision,payload) VALUES(?,?,?,?)",
          [.text(next.profile), .text(next.id), .integer(Int64(old.revision)), .text(old.encode())])
      } else {
        try checkHistory(
          expectedRevision == -1 && next.revision == 0 && next.sequence == history.occurrences.count
            && next.status == .active && next.sets.isEmpty && next.stoppedSlots.isEmpty
            && next.updatedTimestamp == next.startedTimestamp, "invalid_start")
        try checkHistory(!history.isStale(plan), "stale_recommendation")
        try checkHistory(
          !history.occurrences.contains { $0.status == .active }, "active_session_exists")
      }
      let values: [SQLValue] = [
        .text(next.profile), .text(next.id), .text(next.recommendationId),
        .integer(Int64(next.sequence)),
        .integer(Int64(next.revision)), .integer(next.status == .active ? 1 : 0),
        .text(next.encode()),
      ]
      if old == nil {
        try db.execute(
          "INSERT INTO occurrences(profile,id,recommendation,sequence,revision,active,payload) VALUES(?,?,?,?,?,?,?)",
          values)
      } else {
        try db.execute(
          "UPDATE occurrences SET profile=?,id=?,recommendation=?,sequence=?,revision=?,active=?,payload=? WHERE profile=? AND id=?",
          values + [.text(next.profile), .text(next.id)])
      }
      try checkHistory(history.revision < 2_147_483_647, "history_revision_mismatch")
      try db.execute(
        "UPDATE profiles SET revision=? WHERE id=?",
        [.integer(Int64(history.revision + 1)), .text(next.profile)])
      _ = try loadSnapshot(next.profile)
      try receipt(next.profile, actionId, request)
    }
  }
  private func auditRows(_ current: GeneratedOccurrence, _ plan: RecommendationSnapshot) throws
    -> [GeneratedOccurrence]
  {
    let rows = try db.rows(
      "SELECT * FROM revisions WHERE profile=? AND id=? ORDER BY revision",
      [.text(current.profile), .text(current.id)])
    var result: [GeneratedOccurrence] = []
    for row in rows {
      guard let payload = row["payload"]?.string else { throw LoggingException("invalid_audit") }
      let old = try GeneratedOccurrence.decode(payload)
      try checkHistory(
        old.profile == current.profile && old.id == current.id
          && old.revision == row["revision"]?.int && old.revision == result.count, "invalid_audit")
      try old.validateAgainst(plan)
      result.append(old)
    }
    try checkHistory(result.count == current.revision, "incomplete_audit")
    result.append(current)
    let first = result[0]
    try checkHistory(
      first.status == .active && first.sets.isEmpty && first.stoppedSlots.isEmpty
        && first.updatedTimestamp == first.startedTimestamp, "invalid_audit_origin")
    for index in result.indices.dropFirst() {
      try validateOccurrenceTransition(result[index - 1], result[index], plan)
    }
    return result
  }
  public func audit(_ profile: String, occurrenceId: String) throws -> [GeneratedOccurrence] {
    try validateStorageId(profile)
    try validateStorageId(occurrenceId)
    return try db.transaction {
      let history = try loadSnapshot(profile)
      guard let current = history.occurrences.first(where: { $0.id == occurrenceId }) else {
        return []
      }
      guard let plan = history.recommendations.first(where: { $0.id == current.recommendationId })
      else { throw LoggingException("missing_recommendation") }
      return try auditRows(current, plan)
    }
  }
  public func close() throws { try db.close() }
}
