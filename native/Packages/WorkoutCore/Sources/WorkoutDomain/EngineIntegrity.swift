import CryptoKit
import Foundation

/// Canonical value subset used by the approved engine integrity contracts.
/// Floating-point values are deliberately unsupported.
public indirect enum EngineJSON: Equatable, Sendable {
  case null
  case bool(Bool)
  case integer(Int)
  case string(String)
  case array([EngineJSON])
  case object([String: EngineJSON])
  public static func strings<S: Sequence>(_ strings: S) -> EngineJSON where S.Element == String {
    .array(strings.map { .string($0) })
  }
  public var canonical: String {
    switch self {
    case .null: return "null"
    case .bool(let value): return value ? "true" : "false"
    case .integer(let value): return String(value)
    case .string(let value): return ManualJSON.string(value)
    case .array(let values): return "[" + values.map(\.canonical).joined(separator: ",") + "]"
    case .object(let values):
      return "{"
        + values.keys.sorted(by: engineUTF16Less).map {
          ManualJSON.string($0) + ":" + values[$0]!.canonical
        }.joined(separator: ",") + "}"
    }
  }
}
func engineUnicodeLess(_ lhs: String, _ rhs: String) -> Bool {
  lhs.unicodeScalars.lexicographicallyPrecedes(rhs.unicodeScalars) { $0.value < $1.value }
}
func engineUTF16Less(_ lhs: String, _ rhs: String) -> Bool {
  lhs.utf16.lexicographicallyPrecedes(rhs.utf16)
}
public func canonicalJsonBytes(_ value: EngineJSON) -> Data { Data(value.canonical.utf8) }
public func sha256Hex(_ bytes: Data) -> String {
  SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
}
public func canonicalCatalogEntriesBytes(_ entries: [ExerciseCatalogEntry]) -> Data {
  canonicalJsonBytes(.array(entries.sorted { $0.id < $1.id }.map(\.canonical)))
}
func engineTimestamp(_ date: Date) -> String {
  dartISOString(date).replacingOccurrences(of: ".000Z", with: "Z")
}
func engineMatches(_ text: String, _ pattern: String) -> Bool {
  text.range(of: pattern, options: .regularExpression) != nil
}
