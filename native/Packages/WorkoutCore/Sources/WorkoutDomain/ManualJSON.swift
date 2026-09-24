import CoreFoundation
import Foundation

/// Ordered JSON encoding reproduces Dart jsonEncode bytes used by legacy action receipts.
/// Callers supply values that are already JSON encoded; this is not a general import surface.
public enum ManualJSON {
  public static func string(_ value: String) -> String {
    var output = "\""
    for scalar in value.unicodeScalars {
      switch scalar.value {
      case 0x22: output += "\\\""
      case 0x5c: output += "\\\\"
      case 0x08: output += "\\b"
      case 0x0c: output += "\\f"
      case 0x0a: output += "\\n"
      case 0x0d: output += "\\r"
      case 0x09: output += "\\t"
      case 0...0x1f: output += String(format: "\\u%04x", scalar.value)
      default: output.unicodeScalars.append(scalar)
      }
    }
    return output + "\""
  }
  public static func bytesEqual(_ lhs: String, _ rhs: String) -> Bool {
    lhs.utf8.elementsEqual(rhs.utf8)
  }
  public static func object(_ fields: [(String, String)]) -> String {
    "{" + fields.map { string($0.0) + ":" + $0.1 }.joined(separator: ",") + "}"
  }
  public static func array(_ values: [String]) -> String {
    "[" + values.joined(separator: ",") + "]"
  }
  public static func integer(_ value: Int?) -> String { value.map(String.init) ?? "null" }
  public static func decode(_ value: String) throws -> [String: Any] {
    guard let data = value.data(using: .utf8),
      let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      throw LoggingException("invalid_json")
    }
    return object
  }
  public static func text(_ object: [String: Any], _ key: String) throws -> String {
    guard let value = object[key] as? String else { throw LoggingException("invalid_json_field") }
    return value
  }
  public static func int(_ object: [String: Any], _ key: String) throws -> Int {
    guard let number = object[key] as? NSNumber,
      CFGetTypeID(number) != CFBooleanGetTypeID(),
      !["f", "d"].contains(String(cString: number.objCType)),
      let result = Int(number.stringValue)
    else { throw LoggingException("invalid_json_field") }
    return result
  }
  public static func optionalInt(_ object: [String: Any], _ key: String) throws -> Int? {
    if object[key] == nil || object[key] is NSNull { return nil }
    return try int(object, key)
  }
  public static func bool(_ object: [String: Any], _ key: String) throws -> Bool {
    guard let number = object[key] as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else {
      throw LoggingException("invalid_json_field")
    }
    return number.boolValue
  }
}

/// Stores the integer microseconds separately from Foundation Date, so decoding then
/// correcting a legacy record never rounds its six-digit timestamp through a Double.
public struct ManualTimestamp: Equatable, Sendable {
  public let microsecondsSince1970: Int64
  public var date: Date { Date(timeIntervalSince1970: Double(microsecondsSince1970) / 1_000_000) }
  public init(_ date: Date) {
    let seconds = date.timeIntervalSince1970
    // Invalid dates remain rejectable rather than trapping during conversion.
    microsecondsSince1970 =
      seconds.isFinite && abs(seconds) <= 8_640_000_000_000
      ? Int64((seconds * 1_000_000).rounded()) : Int64.min
  }
  private init(microseconds: Int64) { microsecondsSince1970 = microseconds }
  public init(parsing text: String) throws {
    let pattern =
      #"^([+-]?\d{4,6})-(\d{2})-(\d{2})[Tt ](\d{2}):(\d{2}):(\d{2})(?:[.,](\d+))?([Zz]|[+-]\d{2}(?::?\d{2})?)$"#
    let expression = try NSRegularExpression(pattern: pattern)
    let ns = text as NSString
    guard
      let match = expression.firstMatch(in: text, range: NSRange(location: 0, length: ns.length))
    else {
      throw LoggingException("invalid_session")
    }
    func capture(_ index: Int) -> String {
      let range = match.range(at: index)
      return range.location == NSNotFound ? "" : ns.substring(with: range)
    }
    guard let year = Int64(capture(1)), let month = Int64(capture(2)), let day = Int64(capture(3)),
      let hour = Int64(capture(4)), let minute = Int64(capture(5)), let second = Int64(capture(6))
    else {
      throw LoggingException("invalid_session")
    }
    // Dart DateTime uses the proleptic Gregorian calendar and normalizes
    // overflow components. Foundation's historical Gregorian cutover does not.
    let monthIndex = month - 1
    let normalizedYear = year + Self.floorDiv(monthIndex, 12)
    let normalizedMonth = monthIndex - Self.floorDiv(monthIndex, 12) * 12 + 1
    let days = Self.daysFromCivil(normalizedYear, normalizedMonth, 1) + day - 1
    let baseSeconds = days * 86_400 + hour * 3600 + minute * 60 + second
    let zone = capture(8)
    var offset = 0
    if zone.lowercased() != "z" {
      let digits = String(zone.dropFirst()).replacingOccurrences(of: ":", with: "")
      guard let hours = Int(digits.prefix(2)),
        let minutes = Int(digits.count > 2 ? String(digits.suffix(2)) : "0")
      else {
        throw LoggingException("invalid_session")
      }
      offset = (hours * 60 + minutes) * 60 * (zone.first == "-" ? -1 : 1)
    }
    let fraction = String((capture(7) + "000000").prefix(6))
    let seconds = baseSeconds - Int64(offset)
    guard abs(seconds) <= 8_640_000_000_000, let micros = Int64(fraction) else {
      throw LoggingException("invalid_session")
    }
    let total = seconds * 1_000_000 + micros
    guard abs(total) <= 8_640_000_000_000_000_000 else { throw LoggingException("invalid_session") }
    self.init(microseconds: total)
  }
  public var isValid: Bool { microsecondsSince1970 != Int64.min }
  public var encoded: String {
    guard isValid else { return "invalid" }
    var seconds = microsecondsSince1970 / 1_000_000
    var fraction = microsecondsSince1970 % 1_000_000
    if fraction < 0 {
      seconds -= 1
      fraction += 1_000_000
    }
    let days = Self.floorDiv(seconds, 86_400)
    let daySeconds = seconds - days * 86_400
    let (year, month, day) = Self.civilFromDays(days)
    let prefix =
      (0...9999).contains(year)
      ? String(format: "%04lld", year)
      : year >= -9999 && year < 0
        ? "-" + String(format: "%04lld", -year)
        : String(format: "%+07lld", year)
    let digits =
      fraction % 1000 == 0
      ? String(format: "%03lld", fraction / 1000) : String(format: "%06lld", fraction)
    return prefix
      + String(
        format: "-%02lld-%02lldT%02lld:%02lld:%02lld.", month, day,
        daySeconds / 3600, (daySeconds % 3600) / 60, daySeconds % 60) + digits + "Z"
  }
  private static func floorDiv(_ numerator: Int64, _ denominator: Int64) -> Int64 {
    let quotient = numerator / denominator
    return numerator % denominator < 0 ? quotient - 1 : quotient
  }
  // Civil-date algorithms use 400-year eras with a March-based year. Both
  // directions operate only on integers; there is no locale, timezone or cutover.
  private static func daysFromCivil(_ year: Int64, _ month: Int64, _ day: Int64) -> Int64 {
    let y = year - (month <= 2 ? 1 : 0)
    let era = floorDiv(y, 400)
    let yoe = y - era * 400
    let shiftedMonth = month + (month > 2 ? -3 : 9)
    let doy = (153 * shiftedMonth + 2) / 5 + day - 1
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
    return era * 146_097 + doe - 719_468
  }
  private static func civilFromDays(_ days: Int64) -> (Int64, Int64, Int64) {
    let z = days + 719_468
    let era = floorDiv(z, 146_097)
    let doe = z - era * 146_097
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365
    let year = yoe + era * 400
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
    let mp = (5 * doy + 2) / 153
    let day = doy - (153 * mp + 2) / 5 + 1
    let month = mp + (mp < 10 ? 3 : -9)
    return (year + (month <= 2 ? 1 : 0), month, day)
  }
}
public func dartISOString(_ date: Date) -> String { ManualTimestamp(date).encoded }
public func dartDate(_ value: String) throws -> Date { try ManualTimestamp(parsing: value).date }

extension ManualTimestamp: Comparable {
  public static func < (lhs: ManualTimestamp, rhs: ManualTimestamp) -> Bool {
    lhs.microsecondsSince1970 < rhs.microsecondsSince1970
  }
}
