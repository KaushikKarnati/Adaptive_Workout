# ADR 0018: Native Swift migration

Status: accepted and implemented September 24, 2026. Final physical-device checks deferred at the owner's explicit request.

## Context

The owner wants an iOS-first application developed directly in Xcode. Android will be considered only if the iOS app proves useful. The Flutter implementation is the behavioral reference; changing language does not approve new training rules or catalog activation.

During implementation the owner deleted the old Flutter app, confirmed it contained only test data, and chose to start fresh in Swift. The owner later requested: “skip physical device checking just focus on migration.” This supersedes the plan's protected real-data replacement and final iPhone-acceptance gates for this migration; it does not turn unrun device checks into passes.

## Decision

Use a SwiftUI app with a local Swift package split into `WorkoutDomain`, `WorkoutApplication` and `WorkoutPersistence`. SQLite is accessed through Apple's bundled C library. No third-party dependency is added. The project pins iOS 17.0, matching the effective original Runner deployment target. Validation uses Xcode 27.0 and Swift 6.4 with Swift 6 language mode.

Keep the native app identity `com.adaptiveworkout.adaptiveWorkout.native` and display name **Adaptive Workout**. Use its separate sandbox for the fresh start; no existing real-workout import or recovery is required or claimed. Fixtures use separate database directories and UserDefaults domains. Release rejects developer test/practice flags.

Preserve the persistent Workout/Settings shell, manual logging/history, setup, gyms, appearance/haptics, standalone deterministic engine and storage contracts. Unknown equipment, unreviewed catalog entries and unresolved safety inputs stay blocked. No production cross-store generation adapter or live generated-workout caller is registered.

Remove Flutter/Dart runtime, source and build dependencies from the active tree. Preserve the original implementation and parity generators in Git history, frozen golden outputs in Swift tests, and upstream source/license fixtures under `native/ReferenceFixtures`. Native builds and tests must work from a clean checkout without Flutter.

## Consequences

Xcode is the normal build/edit/test workflow. Swift package tests run locally without launching an iPhone or simulator. Optional Xcode hosted and screen tests are retained for later device acceptance. Earlier physical checks are reported separately from the final revision in [migration evidence](../SWIFT_MIGRATION_STATUS.md).

Existing specifications and historical ADRs continue to govern product behavior; their implementation-language references are superseded here. Android is separate future work. SwiftData, cross-platform bridges, cloud services, dependencies and new workout behavior are outside this migration.

## Alternatives considered

Keeping Flutter does not meet the requested native workflow. A SwiftUI wrapper around Dart retains two runtimes/build systems. Changing the storage format at the same time would increase the compatibility burden unnecessarily.
