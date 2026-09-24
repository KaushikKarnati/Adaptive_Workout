# Adaptive Workout

Native iOS app written in Swift and SwiftUI, with an offline SQLite store and a deterministic workout engine. iOS comes first; Android is deferred.

## Open in Xcode

```sh
open native/AdaptiveWorkout.xcodeproj
```

Select the **AdaptiveWorkout** scheme. The app supports **iOS 17+**. The migration was built with Xcode 27 / Swift 6.4, using Swift 6 language mode. Select your Apple development team under Signing & Capabilities when needed. Flutter, Dart, CocoaPods and third-party Swift packages are not required.

## What works

- Workout logging with the five approved templates, frozen prescriptions, persistent drafts, actuals, skips, warm-ups, corrections, early completion and confirmed deletion.
- Searchable history, comparable graphs, elapsed workout time and explicit rest timers.
- System/Light/Dark appearance, native haptics, retained setup forms, equipment and starting-load confirmations, and local gym inventories.
- Separate SQLite repositories with validation, transactions, audit history, idempotent retries and schema compatibility checks.
- Standalone Swift catalog, eligibility, progression, warm-up, planning, composition and saved-workout services.

Adaptive generation is still gated by the existing product requirements: reviewed catalog bindings, safety inputs, a production atomic capture/save adapter and live generated-workout integration remain future work. Manual and practice records never become progression evidence. The real three-entry catalog remains disabled.

The owner confirmed the deleted Flutter app contained only test data and chose a fresh native start. The Swift app keeps its own `com.adaptiveworkout.adaptiveWorkout.native` identity. No real-data import or recovery is claimed.

## Development

```sh
swift test --package-path native/Packages/WorkoutCore
xcodebuild -project native/AdaptiveWorkout.xcodeproj -scheme AdaptiveWorkout \
  -configuration Release -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build
```

Use Xcode's Product → Analyze for static analysis. See [Testing](docs/TESTING.md) for formatting and optional, isolated iPhone tests. Final physical-device checking was skipped at the owner's request; successful compilation and local tests do not establish device acceptance.

Code lives in:

- `native/AdaptiveWorkout`: SwiftUI presentation and composition.
- `native/Packages/WorkoutCore/Sources/WorkoutDomain`: pure models, codecs and deterministic policies.
- `native/Packages/WorkoutCore/Sources/WorkoutApplication`: controllers and coordinated actions.
- `native/Packages/WorkoutCore/Sources/WorkoutPersistence`: SQLite adapters and offline catalog mapping.
- `native/Packages/WorkoutCore/Tests`: local unit, repository and golden parity tests.
- `native/AdaptiveWorkoutUITests`: isolated screen and restart tests.

Read [AGENTS.md](AGENTS.md), [Architecture](docs/ARCHITECTURE.md), and the relevant approved specification before editing. [Migration evidence](docs/SWIFT_MIGRATION_STATUS.md) and the [behavior map](docs/SWIFT_PARITY_MATRIX.md) record the port and its limits. Historical Flutter code and migration fixture generators remain in Git history; the maintained application is Swift.
