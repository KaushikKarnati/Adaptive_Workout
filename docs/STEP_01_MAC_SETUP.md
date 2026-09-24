# Mac setup for native iOS development

The maintained app is Swift/SwiftUI. The original Flutter setup recipe remains in Git history before ADR 0018.

1. Install Xcode and complete its first-launch setup. This migration was checked using Xcode 27.0 and Swift 6.4.
2. Open `native/AdaptiveWorkout.xcodeproj`, choose **AdaptiveWorkout**, and select your development team if Xcode requests signing configuration.
3. Build with Product → Build. The deployment target is iOS 17.0.
4. Run the local package tests from the repository root:

   ```sh
   swift test --package-path native/Packages/WorkoutCore
   ```

5. Use [Testing](TESTING.md) for formatting, static analysis, generic iOS builds and optional physical-iPhone checks. No simulator download is required for the build or local package tests.

The app uses SwiftUI, Foundation, CryptoKit, UIKit and the system SQLite library. Flutter, Dart, Android Studio, CocoaPods and external Swift packages are unnecessary. Do not add a dependency without approval.

Read [Architecture](ARCHITECTURE.md) and the relevant approved product/science specifications before changing behavior. Never commit credentials, provisioning profiles or signing keys. Android and App Store distribution are separate future work.
