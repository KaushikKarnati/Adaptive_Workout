// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "WorkoutCore",
  platforms: [.iOS(.v17), .macOS(.v12)],
  products: [
    .library(name: "WorkoutDomain", targets: ["WorkoutDomain"]),
    .library(name: "WorkoutApplication", targets: ["WorkoutApplication"]),
    .library(name: "WorkoutPersistence", targets: ["WorkoutPersistence"]),
  ],
  targets: [
    .systemLibrary(name: "CSQLite"),
    .target(name: "WorkoutDomain"),
    .target(name: "WorkoutApplication", dependencies: ["WorkoutDomain"]),
    .target(name: "WorkoutPersistence", dependencies: ["WorkoutDomain", "CSQLite"]),
    .testTarget(
      name: "WorkoutCoreTests",
      dependencies: ["WorkoutDomain", "WorkoutApplication", "WorkoutPersistence"]),
  ],
  swiftLanguageModes: [.v6]
)
