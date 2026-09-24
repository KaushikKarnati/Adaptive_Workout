# Native iOS project

Open `AdaptiveWorkout.xcodeproj` and select the **AdaptiveWorkout** scheme. The app is **Adaptive Workout**, supports iOS 17+, and depends only on Apple SDKs and the local `WorkoutCore` package. No Flutter installation is needed.

```sh
swift test --package-path Packages/WorkoutCore
```

Use your development team in Xcode for signed runs. The bundle identity is `com.adaptiveworkout.adaptiveWorkout.native`; the owner chose a fresh start after deleting the old test-only Flutter app.

Domain rules live in `WorkoutDomain`, coordinated actions in `WorkoutApplication`, and database adapters in `WorkoutPersistence`. Views do not execute SQL or calculate workout prescriptions.

Debug screen tests use unique fixture directories and preference domains. Hosted unit tests also isolate app startup. `--fixture-directory NAME` and `--reset-fixture` never reset normal app storage. Release builds reject developer fixture/practice arguments. Practice is available only through explicit Debug `--practice` injection and remains separate from progression evidence.

See [testing](../docs/TESTING.md), [migration evidence](../docs/SWIFT_MIGRATION_STATUS.md), and the [behavior map](../docs/SWIFT_PARITY_MATRIX.md). Final physical-device checks were waived by the owner; local build/test evidence is reported separately.
