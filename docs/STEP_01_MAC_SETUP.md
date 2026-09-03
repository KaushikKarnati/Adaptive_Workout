# Step 1 — Mac Repository Setup

## Outcome

At the end of this step, the Mac can build a stock Flutter application for iOS and Android, Git tracks the project, and the repository contains permanent engineering rules.

## 1. Install development tools

Install and open each application once:

- Codex desktop app
- Xcode from the Mac App Store
- Android Studio
- VS Code, optional but recommended for inspection
- GitHub Desktop, optional if terminal Git feels unfamiliar

Install Homebrew only from its official website if it is not already available.

## 2. Install Flutter

Use Flutter's current official macOS installation instructions. Choose the Apple Silicon download on M-series Macs and the Intel download on Intel Macs. Add Flutter's `bin` directory to the shell PATH.

Then run:

```bash
flutter doctor -v
```

Resolve every required iOS and Android item. Optional platform warnings can remain only if that platform is intentionally unsupported.

Typical additional steps include:

```bash
sudo xcodebuild -runFirstLaunch
sudo xcodebuild -license
flutter doctor --android-licenses
```

Read every command before approving elevated access.

## 3. Create the Flutter shell

From the directory containing this repository, run:

```bash
flutter create --org com.adaptiveworkout --platforms=ios,android .
```

The reverse-domain identifier is provisional. Change `com.adaptiveworkout` before store release if a company domain or final brand is selected.

Do not add Riverpod, Drift, RevenueCat, or workout features in this step.

## 4. Validate the generated application

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter devices
```

Launch at least one simulator or emulator, then run:

```bash
flutter run
```

The stock counter application must build and open before proceeding.

## 5. Initialize and checkpoint Git

If this repository was not already initialized:

```bash
git init
git add .
git commit -m "chore: initialize adaptive workout project"
```

Create an empty private GitHub repository, then follow GitHub's displayed commands to add the remote and push. Do not commit credentials, provisioning profiles, signing keys, or `.env` files.

## Step 1 acceptance criteria

- `flutter doctor -v` has no unresolved required-platform failures.
- Stock Flutter app builds and opens on at least one simulator/emulator.
- `flutter analyze` passes.
- `flutter test` passes.
- Git working tree is clean after the initial commit.
- Private GitHub remote is configured and the commit is pushed.
- `AGENTS.md` and the files in `docs/` are present.

## Stop point

Do not build the workout engine yet. The next step is completing and approving `docs/PRODUCT.md`, followed by the scientific decision specifications.
