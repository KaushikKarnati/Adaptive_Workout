import Foundation

public let homewoodGymId = "club4_homewood"
public let homewoodSource = "https://www.club4fitness.com/location/homewood-birmingham-al/"
public enum EquipmentAvailability: String, Codable, CaseIterable, Sendable {
  case unknown, available, unavailable
}
public struct GymEquipment: Equatable, Sendable {
  public let category: String, availability: EquipmentAvailability, notes: String
  var checkedStamp: ManualTimestamp?
  public var checkedAt: Date? { checkedStamp?.date }
  public init(
    category: String, availability: EquipmentAvailability, checkedAt: Date?, notes: String = ""
  ) throws {
    self.category = category
    self.availability = availability
    self.checkedStamp = checkedAt.map(ManualTimestamp.init)
    self.notes = notes
    try requireSetup(SetupTaxonomy.equipmentIds.contains(category), "unknown_equipment")
    try requireSetup(
      availability == .unknown ? checkedAt == nil : checkedAt != nil, "invalid_confirmation")
    if let checkedAt {
      try requireSetup(ManualTimestamp(checkedAt).isValid, "invalid_confirmation")
    }
    try validateGymText(notes, maximum: 500, allowEmpty: true)
  }
  public var canonicalJSON: String {
    SetupJSON.object([
      ("category", SetupJSON.string(category)),
      ("availability", SetupJSON.string(availability.rawValue)),
      ("checkedAt", SetupJSON.string(checkedStamp?.encoded)), ("notes", SetupJSON.string(notes)),
    ])
  }
  public static func fromJSON(_ j: [String: Any]) throws -> GymEquipment {
    guard let status = EquipmentAvailability(rawValue: try ManualJSON.text(j, "availability"))
    else { throw SetupException("invalid_availability") }
    var result = try GymEquipment(
      category: ManualJSON.text(j, "category"), availability: status,
      checkedAt: SetupJSON.optionalDate(j, "checkedAt"), notes: ManualJSON.text(j, "notes"))
    result.checkedStamp = try SetupJSON.optionalString(j, "checkedAt").map(
      ManualTimestamp.init(parsing:))
    return result
  }
}
public struct GymProfile: Equatable, Identifiable, Sendable {
  public let id: String, name: String, address: String, equipment: [GymEquipment]
  public init(id: String, name: String, address: String, equipment: [GymEquipment]) throws {
    self.id = id
    self.name = name
    self.address = address
    self.equipment = equipment
    try validateSetupId(id)
    try validateGymText(name, maximum: 120)
    try validateGymText(address, maximum: 240, allowEmpty: true)
    try setupUnique(equipment.map(\.category), SetupTaxonomy.equipmentIds.count)
  }
  public var availableCategories: [String] {
    equipment.filter { $0.availability == .available }.map(\.category).sorted()
  }
  public func update(_ item: GymEquipment) throws -> GymProfile {
    try GymProfile(
      id: id, name: name, address: address,
      equipment: equipment.filter { $0.category != item.category } + [item])
  }
  public var canonicalJSON: String {
    SetupJSON.object([
      ("id", SetupJSON.string(id)), ("name", SetupJSON.string(name)),
      ("address", SetupJSON.string(address)),
      (
        "equipment",
        ManualJSON.array(equipment.sorted { $0.category < $1.category }.map(\.canonicalJSON))
      ),
    ])
  }
  public static func fromJSON(_ j: [String: Any]) throws -> GymProfile {
    try GymProfile(
      id: ManualJSON.text(j, "id"), name: ManualJSON.text(j, "name"),
      address: ManualJSON.text(j, "address"),
      equipment: SetupJSON.array(j, "equipment") { try GymEquipment.fromJSON(SetupJSON.dict($0)) })
  }
}
public func homewoodProfile() -> GymProfile {
  try! GymProfile(
    id: homewoodGymId, name: "CLUB4 Homewood", address: "257 Lakeshore Pkwy, Birmingham, AL 35209",
    equipment: [])
}
public struct GymProfiles: Equatable, Sendable {
  public let selectedId: String?, profiles: [GymProfile]
  public init(selectedId: String? = nil, profiles: [GymProfile]) throws {
    self.selectedId = selectedId
    self.profiles = profiles
    try setupUnique(profiles.map(\.id), 50)
    try requireSetup(
      selectedId == nil || profiles.contains { $0.id == selectedId }, "unknown_selected_gym")
  }
  public var selected: GymProfile? { profiles.first { $0.id == selectedId } }
  public func select(_ gym: GymProfile) throws -> GymProfiles {
    try GymProfiles(selectedId: gym.id, profiles: profiles.filter { $0.id != gym.id } + [gym])
  }
  public func encode() -> String {
    SetupJSON.object([
      ("schema", "1"), ("selectedId", SetupJSON.string(selectedId)),
      ("profiles", ManualJSON.array(profiles.sorted { $0.id < $1.id }.map(\.canonicalJSON))),
    ])
  }
  public static func decode(_ value: String) throws -> GymProfiles {
    let j = try ManualJSON.decode(value)
    try requireSetup(ManualJSON.int(j, "schema") == 1, "unsupported_gym_schema")
    return try GymProfiles(
      selectedId: SetupJSON.optionalString(j, "selectedId"),
      profiles: SetupJSON.array(j, "profiles") { try GymProfile.fromJSON(SetupJSON.dict($0)) })
  }
}
public protocol GymProfileRepository {
  func load() throws -> GymProfiles
  func save(_ next: GymProfiles, expected: GymProfiles) throws
}
