# Repository Instructions

## Mission

Build an offline-first adaptive workout application that generates transparent, deterministic recommendations from approved product and training-science specifications.

## Read before changing code

1. This file.
2. `docs/ARCHITECTURE.md`.
3. The relevant specification under `docs/`.

If a requirement is ambiguous, identify the ambiguity. Do not invent product behavior or fitness science.

## Architecture rules

- Keep domain logic independent of SwiftUI views, databases, and network services.
- Views must not contain workout-generation or progression rules.
- Database access must occur through repositories, never directly from views.
- The workout engine must produce the same output for the same explicit inputs.
- Avoid unnecessary dependencies. Explain and obtain approval before adding one.
- Preserve offline operation for all core workout functionality.
- Open `native/AdaptiveWorkout.xcodeproj` for the app; the local package is `native/Packages/WorkoutCore`. The deployment minimum is iOS 17.
- Put pure rules/records in `WorkoutDomain`, coordinated actions in `WorkoutApplication`, and SQLite adapters in `WorkoutPersistence`. Domain code must not import SwiftUI, UIKit, Combine, or SQLite.
- Keep observable presentation state on the main actor and database serialization inside repository boundaries.
- Preserve canonical legacy JSON, exact integer loads/timestamps, receipts, audit revisions, profile isolation, and the separation of manual/practice/generated evidence.
- Retain approved review and safety gates. A Swift migration does not activate recommendations or supply missing verification.

## Security and privacy

- Never hardcode or commit credentials, tokens, signing keys, or personal secrets.
- Minimize collected user data, permissions, logging, and network access.
- Validate imported, exported, and user-entered data.
- Use parameterized database APIs.
- Do not log sensitive health or workout data in production.
- Do not weaken security controls to make a feature or test pass.

## Testing

- Every algorithmic rule requires unit tests.
- Every bug fix requires a regression test.
- Cover normal, boundary, invalid, and missing-data cases.
- Keep simulations separate from production logic.

Before declaring implementation complete, run when available:

```bash
xcrun swift-format lint --strict --recursive native/AdaptiveWorkout native/AdaptiveWorkoutUITests native/Packages/WorkoutCore/Sources native/Packages/WorkoutCore/Tests native/Packages/WorkoutCore/Package.swift
swift build --build-tests --package-path native/Packages/WorkoutCore
swift test --package-path native/Packages/WorkoutCore
xcodebuild -project native/AdaptiveWorkout.xcodeproj -scheme AdaptiveWorkout -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

Report commands that could not run and why. Never claim a check passed unless it ran successfully.

`AdaptiveWorkoutTests` hosts the core tests on iOS; `AdaptiveWorkoutUITests` covers critical native interactions. Select an explicit supported destination when running Xcode tests. Respect the user's current testing scope: skipped physical-device checks remain unverified, not silently replaced with claimed device acceptance. Test only isolated fixture stores. A package test or build does not establish installed-app persistence, haptic comfort, accessibility acceptance, or real-data transfer.

The maintained app has no Flutter runtime requirement. Historical Dart evidence and prior implementation remain in Git history; current native results and migration limitations belong in `docs/SWIFT_MIGRATION_STATUS.md`.

## Change discipline

- Work on one bounded feature at a time.
- Do not modify unrelated code.
- Inspect the final diff for regressions, security issues, and unnecessary complexity.
- Update relevant documentation when behavior or architecture changes.
- Prefer small, descriptive commits.

## Definition of done

- Approved behavior is implemented without unrelated changes.
- Tests cover the behavior and pass.
- Formatting and static analysis pass.
- No unexplained warnings or hardcoded secrets exist.
- Relevant documentation is current.
- Remaining risks and unverified assumptions are reported.
