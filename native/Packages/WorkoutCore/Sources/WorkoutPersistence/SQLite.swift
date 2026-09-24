import CSQLite
import Foundation

public enum SQLValue: Equatable, Sendable {
  case null
  case integer(Int64)
  case real(Double)
  case text(String)
  case blob(Data)
  public var string: String? { if case .text(let value) = self { value } else { nil } }
  public var int: Int? { if case .integer(let value) = self { Int(exactly: value) } else { nil } }
  public var double: Double? {
    switch self {
    case .integer(let value): Double(value)
    case .real(let value): value
    default: nil
    }
  }
}

/// Errors intentionally omit SQL and record contents.
public struct SQLiteFailure: Error, Equatable, Sendable {
  public let code: Int32
  public init(code: Int32) { self.code = code }
}

/// All access is serialized, including the entire transaction closure. No await inside transactions.
public final class SQLiteDatabase: @unchecked Sendable {
  private var handle: OpaquePointer?
  private let lock = NSRecursiveLock()
  private var inTransaction = false

  public init(path: String) throws {
    let status = sqlite3_open_v2(
      path, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil)
    guard status == SQLITE_OK else {
      if let handle { sqlite3_close_v2(handle) }
      handle = nil
      throw SQLiteFailure(code: status)
    }
    sqlite3_busy_timeout(handle, 5_000)
    try execute("PRAGMA foreign_keys = ON")
  }

  deinit { if let handle { sqlite3_close_v2(handle) } }

  public func close() throws {
    lock.lock()
    defer { lock.unlock() }
    guard let handle else { return }
    let status = sqlite3_close(handle)
    guard status == SQLITE_OK else { throw SQLiteFailure(code: status) }
    self.handle = nil
  }

  public func execute(_ sql: String, _ arguments: [SQLValue] = []) throws {
    lock.lock()
    defer { lock.unlock() }
    let statement = try prepare(sql, arguments)
    defer { sqlite3_finalize(statement) }
    let status = sqlite3_step(statement)
    guard status == SQLITE_DONE || status == SQLITE_ROW else { throw SQLiteFailure(code: status) }
  }

  public func rows(_ sql: String, _ arguments: [SQLValue] = []) throws -> [[String: SQLValue]] {
    lock.lock()
    defer { lock.unlock() }
    let statement = try prepare(sql, arguments)
    defer { sqlite3_finalize(statement) }
    var result: [[String: SQLValue]] = []
    while true {
      let status = sqlite3_step(statement)
      if status == SQLITE_DONE { return result }
      guard status == SQLITE_ROW else { throw SQLiteFailure(code: status) }
      var row: [String: SQLValue] = [:]
      for index in 0..<sqlite3_column_count(statement) {
        let key = String(cString: sqlite3_column_name(statement, index))
        switch sqlite3_column_type(statement, index) {
        case SQLITE_INTEGER: row[key] = .integer(sqlite3_column_int64(statement, index))
        case SQLITE_FLOAT: row[key] = .real(sqlite3_column_double(statement, index))
        case SQLITE_TEXT:
          let bytes = sqlite3_column_text(statement, index)
          let count = Int(sqlite3_column_bytes(statement, index))
          guard
            let value = String(
              bytes: UnsafeBufferPointer(start: bytes, count: count), encoding: .utf8)
          else {
            throw SQLiteFailure(code: SQLITE_MISMATCH)
          }
          row[key] = .text(value)
        case SQLITE_BLOB:
          let count = Int(sqlite3_column_bytes(statement, index))
          row[key] = .blob(
            sqlite3_column_blob(statement, index).map { Data(bytes: $0, count: count) } ?? Data())
        default: row[key] = .null
        }
      }
      result.append(row)
    }
  }

  public func transaction<T>(_ body: () throws -> T) throws -> T {
    lock.lock()
    defer { lock.unlock() }
    guard !inTransaction else { throw SQLiteFailure(code: SQLITE_MISUSE) }
    try execute("BEGIN IMMEDIATE")
    inTransaction = true
    defer { inTransaction = false }
    do {
      let result = try body()
      try execute("COMMIT")
      return result
    } catch {
      try? execute("ROLLBACK")
      throw error
    }
  }

  private func prepare(_ sql: String, _ arguments: [SQLValue]) throws -> OpaquePointer {
    guard let handle else { throw SQLiteFailure(code: SQLITE_MISUSE) }
    var statement: OpaquePointer?
    let status = sqlite3_prepare_v2(handle, sql, -1, &statement, nil)
    guard status == SQLITE_OK, let statement else { throw SQLiteFailure(code: status) }
    do {
      guard sqlite3_bind_parameter_count(statement) == arguments.count else {
        throw SQLiteFailure(code: SQLITE_MISUSE)
      }
      let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
      for (offset, argument) in arguments.enumerated() {
        let index = Int32(offset + 1)
        let result: Int32
        switch argument {
        case .null: result = sqlite3_bind_null(statement, index)
        case .integer(let value): result = sqlite3_bind_int64(statement, index, value)
        case .real(let value):
          guard value.isFinite else { throw SQLiteFailure(code: SQLITE_MISMATCH) }
          result = sqlite3_bind_double(statement, index, value)
        case .text(let value):
          result = value.withCString {
            sqlite3_bind_text(statement, index, $0, Int32(value.utf8.count), transient)
          }
        case .blob(let value):
          result =
            value.isEmpty
            ? sqlite3_bind_zeroblob(statement, index, 0)
            : value.withUnsafeBytes {
              sqlite3_bind_blob(statement, index, $0.baseAddress, Int32($0.count), transient)
            }
        }
        guard result == SQLITE_OK else { throw SQLiteFailure(code: result) }
      }
      return statement
    } catch {
      sqlite3_finalize(statement)
      throw error
    }
  }
}
