# Adaire SDK Suite — Developer Onboarding Guide (Internal)

**Audience:** in-house engineers working on the SDKs and demo app (not external integrators)

**Applies to:** this repo: demo app + Flutter plugins

**Last updated:** 2026-02-18

## 0. What you’re joining

This repository contains:

- **Demo app**: `adaire_sdk_app/` — internal showcase and QA harness
- **SDK plugins**:
  - `flutter_barcode_qr_scanner/`
  - `flutter_credit_card_scanner/`
  - `flutter_id_scanner/`
  - `flutter_passport_scanner/`

If you haven’t already, read:

- Requirements: [REQUIREMENTS.md](REQUIREMENTS.md)
- System architecture: [SYSTEM_ARCHITECTURE.md](SYSTEM_ARCHITECTURE.md)

For deeper implementation details per SDK (method contracts, folder structure, native entrypoints, and how to run tests), see the individual plugin READMEs. These are designed to be browsed in GitHub:

- Barcode/QR SDK: [flutter_barcode_qr_scanner/README.md](flutter_barcode_qr_scanner/README.md)
- Credit Card SDK: [flutter_credit_card_scanner/README.md](flutter_credit_card_scanner/README.md)
- ID SDK: [flutter_id_scanner/README.md](flutter_id_scanner/README.md)
- Passport SDK: [flutter_passport_scanner/README.md](flutter_passport_scanner/README.md)

## 1. Key concepts (quick, practical)

### 1.1 How SDK calls cross the Dart/native boundary

All plugins in this repo communicate using Flutter **method channels**:

- Dart calls `MethodChannel('<channel-name>').invokeMethod(...)`
- Native Android/iOS receives that call and presents a native UI
- Native returns either:
  - `null` (usually cancel/permission denied), or
  - a map payload with keys/values

Terminology used in docs:

- **Channel**: the string name, e.g. `flutter_id_scanner`
- **Method contract**: the agreed method names/args/return-shapes/error codes
- **Error codes**: stable strings inside `PlatformException` (`ALREADY_ACTIVE`, `SCAN_ERROR`, …)

See the glossary in [SYSTEM_ARCHITECTURE.md](SYSTEM_ARCHITECTURE.md).

### 1.2 Where “the work” happens (per SDK)

- Barcode/QR + Credit Card: most detection happens **natively**.
- ID + Passport: native side mostly does **document capture**; OCR/parsing happens in **Dart**.

This matters when deciding where to implement changes:

- UI/permissions/camera pipeline → native
- Parsing, heuristics, testable logic → Dart (preferred)

## 2. Prerequisites

### 2.1 Required tools

- Flutter SDK (must satisfy repo constraints; packages use Dart `^3.9.2`)
- Git
- A code editor (VS Code recommended)

### 2.2 Android prerequisites

- Android Studio (or Android SDK + command line tools)
- One of:
  - Android emulator
  - Physical Android device with USB debugging

### 2.3 iOS prerequisites (macOS only)

- Xcode
- CocoaPods (`pod`)
- A physical iOS device is strongly recommended for camera features

### 2.4 Hardware expectations

Camera-based SDKs are difficult to validate on simulators. Plan to test on:

- At least 1 modern Android device
- At least 1 iOS device (iOS 16+ recommended for credit card live scanning)

## 3. Repo layout (where to look)

### 3.1 Demo app

- `adaire_sdk_app/lib/features/sdk_showcase/` — grid UI and user flows
- `adaire_sdk_app/lib/services/` — thin wrapper layer per SDK

### 3.2 Plugin layout (all SDKs)

Each plugin follows the standard Flutter plugin structure:

- `lib/`
  - Public API + platform interface + method channel
- `android/`
  - Android plugin + Activities / scanner UI
- `ios/`
  - iOS plugin + view controllers / capture pipelines
- `example/`
  - standalone app for testing the plugin in isolation
- `test/`
  - Dart unit tests (method channel + platform interface)

## 4. First-time setup (Windows + Android)

> This is the fastest path to becoming productive.

### 4.1 Verify Flutter install

From anywhere:

```powershell
flutter --version
flutter doctor -v
```

Resolve any missing Android licenses:

```powershell
flutter doctor --android-licenses
```

### 4.2 Fetch dependencies (entire repo)

There’s no single workspace-level tool; run `flutter pub get` per package:

```powershell
cd c:\Users\ApollosDavid\Documents\Adaire_SDKs\adaire_sdk_app
flutter pub get
```

Repeat for each plugin folder if you’ll work on it directly.

### 4.3 Run the demo app (recommended)

```powershell
cd c:\Users\ApollosDavid\Documents\Adaire_SDKs\adaire_sdk_app
flutter run
```

Optional: set app mode:

```powershell
flutter run --dart-define=APP_MODE=dev
# or
flutter run --dart-define=APP_MODE=production
```

### 4.4 Smoke test checklist (your first run)

In the demo app:

- Barcode/QR: scan a QR code; confirm type + value show
- Credit card: scan a test card number; confirm brand/expiry (do not use real cards)
- Passport: capture data page; confirm MRZ extracted on at least one passport
- ID: complete front/back capture; confirm some parsed fields

If any flow returns immediately:

- Check camera permission prompts
- Check device camera availability
- Check logs for `PlatformException` codes

## 5. First-time setup (macOS + iOS)

### 5.1 Install pods (per iOS app)

For the demo app:

```bash
cd adaire_sdk_app/ios
pod install
```

For a plugin example app:

```bash
cd <plugin>/example/ios
pod install
```

### 5.2 Run on iOS device

```bash
cd adaire_sdk_app
flutter run
```

Notes:

- Ensure the host app `Info.plist` includes `NSCameraUsageDescription`.
- For credit card scanning:
  - iOS 16+ supports VisionKit live scanning when available.

## 6. Day-to-day workflows

### 6.1 Choose your development loop

**Loop A (recommended): demo app**

- Edit plugin code
- Run `adaire_sdk_app` (path dependencies already wired)
- Validate flows in one place

**Loop B: plugin example app**

- Work inside a plugin
- Run that plugin’s `example/` app
- Faster for isolated debugging

### 6.2 Run a plugin example app

```powershell
cd c:\Users\ApollosDavid\Documents\Adaire_SDKs\flutter_barcode_qr_scanner\example
flutter pub get
flutter run
```

### 6.3 Run Dart tests

From a package root:

```powershell
flutter test
```

This covers method channel wiring and some platform interface behavior.

### 6.4 Run Android native unit tests (where available)

Some plugin `android/` folders do not contain a Gradle wrapper. Use the `example/android` wrapper.

Example pattern:

```powershell
cd <plugin>\example\android
.\gradlew.bat testDebugUnitTest
```

## 7. Debugging guide (the stuff you’ll actually need)

### 7.1 When a scan returns `null`

In this repo, `null` is usually not a crash. It typically means:

- user cancelled
- permission denied
- scanner UI couldn’t be presented (some iOS cases)

Validate:

- permissions granted
- testing on a real device
- no second scan already in progress

### 7.2 When you see `PlatformException`

Common codes across SDKs:

- `ALREADY_ACTIVE`: you started a second scan too early
- `NO_ACTIVITY` (Android): plugin not attached to an Activity
- `NO_VIEW` (iOS): no top view controller found
- `SCAN_ERROR`: scanning/capture pipeline failed
- `TIMEOUT`: credit card scan timed out

Action steps:

- Reproduce with the demo app
- Add temporary debug logging (but never log sensitive values)
- Confirm the method channel name + method name match on both sides

### 7.3 Method-channel sanity checks

If Dart calls aren’t reaching native:

- Confirm channel name strings match exactly:
  - barcode: `flutter_barcode_qr_scanner`
  - credit card: `flutter_credit_card_scanner`
  - id: `flutter_id_scanner`
  - passport: `flutter_passport_scanner`
- Confirm method names match (e.g., `scanCard`, `scanPassport`)
- Confirm plugin is registered (usually automatic in Flutter)

## 8. Development standards (internal)

### 8.1 Security & privacy rules

Treat scan outputs as sensitive by default.

- Do NOT log:
  - credit card PAN
  - raw OCR text containing PII
  - passport MRZ lines
- Prefer redaction if you must debug:
  - show last 4 digits only
  - or show length/format, not raw values

### 8.2 Storage rules

ID/passport SDKs return temporary/cached file paths.

- Do not assume these paths persist forever.
- Avoid copying images into permanent storage unless explicitly required.

### 8.3 Compatibility rules

- Keep method contracts stable.
- If you must change a contract:
  - update Dart + Android + iOS in the same PR
  - update [SYSTEM_ARCHITECTURE.md](SYSTEM_ARCHITECTURE.md)
  - add/update tests

## 9. Common change recipes

### 9.1 Add a new barcode format (barcode SDK)

You typically need to update:

- Dart: add enum value + mapping function
- Android: map key <-> ZXing `BarcodeFormat`
- iOS: map key <-> `AVMetadataObject.ObjectType` (if supported)

After changes:

- Run the plugin example
- Validate Android + iOS parity (or document gaps)

### 9.2 Adjust credit card scanning stability

Knobs exposed to Dart include:

- `consensusRequired`
- `stabilityRequired`
- `showDetectedQuad`

Change approach:

- Prefer deterministic improvements (better filtering) over lowering thresholds.
- Add metrics in debug mode that don’t reveal PAN.

### 9.3 Improve ID/passport parsing

Most parsing logic is in Dart:

- ID: `flutter_id_scanner/lib/src/*`
- Passport: `flutter_passport_scanner/lib/src/*`

This makes it easier to:

- add unit tests
- iterate quickly without touching native code

## 10. Release and verification (internal)

Before a release candidate:

- Run `flutter test` in:
  - `adaire_sdk_app/`
  - each plugin
- Smoke test with the demo app on:
  - Android
  - iOS
- Update versions + changelogs

## 11. Distribution & publishing options (future)

This section is intentionally forward-looking. Today the demo app consumes the SDKs via local path dependencies, which is ideal for development but not for external distribution.

### 11.1 Clarify the goal (what “proprietary” can mean)

There are a few different goals people sometimes mean by “proprietary”:

- **Private access**: only approved consumers can download the package.
- **No source visibility**: consumers can use the SDK without seeing the implementation.
- **Tamper resistance**: make reverse engineering harder (never fully possible).

Important constraint: **Dart package contents are distributed as source**. Even with a private registry, a consumer who can download the package can read the Dart code.

If you truly want “use it without seeing the implementation”, the typical pattern is:

- ship a **thin Flutter wrapper** (Dart + MethodChannel + minimal glue)
- put the real proprietary logic in **closed-source native binaries** (Android AAR/Maven, iOS XCFramework/CocoaPods)

### 11.2 Options

#### Option A — Publish to pub.dev (public)

Best for open-source.

- Pros: standard Flutter workflow; easiest for external developers.
- Cons: not compatible with “private access”; Dart + plugin code is visible.

#### Option B — Private pub registry (hosted packages)

Host your own pub server / use a commercial registry that supports Dart packages and configure consumers with a hosted URL.

- Pros: private access; supports versioned releases; works with normal `dart pub get`.
- Cons: consumers can still view the Dart/plugin source they download.
- Good fit when: “private access” is the main requirement.

Operational notes:

- Decide auth model (OIDC, token, basic auth) and who issues credentials.
- Keep package names stable; enforce semantic versioning.

#### Option C — Git dependencies (private GitHub/GitLab)

Consumers depend on a git repo + ref/branch/tag.

- Pros: simplest “private distribution” to start; no registry required.
- Cons: source is visible to anyone with repo access; weaker versioning guarantees; slower dependency resolution.
- Good fit when: early pilots with trusted partners.

#### Option D — Open Flutter wrapper + closed-source native SDKs (recommended for “no source visibility”)

This is the most common way to keep the real implementation proprietary.

- Publish (public or private) a Flutter plugin that exposes the Dart API and method-channel contract.
- Android: implement scanning in a closed-source library shipped as an **AAR** (or Maven artifact) and have the plugin depend on it.
- iOS: implement scanning in a closed-source **XCFramework** (or binary CocoaPod) and have the plugin vend it.

Pros:

- External devs can use the SDK without seeing the proprietary native code.
- You can update native implementations independently while keeping Dart API stable.

Cons:

- Requires additional build/release infrastructure (Maven + CocoaPods binary hosting).
- You still ship Dart wrapper source to consumers.

Typical hosting choices:

- Android artifacts: GitHub Packages (Maven), Artifactory, Nexus, or another private Maven repo.
- iOS binaries: a private CocoaPods specs repo referencing hosted XCFramework zips, or a commercial binary distribution solution.

#### Option E — Enterprise delivery (zip installers / manual artifacts)

You ship a bundle containing:

- Flutter wrapper package
- Android AARs and iOS XCFrameworks
- integration instructions

- Pros: maximum control; works in restricted/offline environments.
- Cons: manual updates; higher integration burden; easy for clients to misconfigure.

### 11.3 Recommended direction

If the long-term requirement is **external use without source visibility**, plan toward **Option D**:

- keep each Flutter plugin as a stable API surface + MethodChannel contract
- move proprietary scanning/recognition into native SDKs released as binary artifacts
- maintain a compatibility matrix (Flutter version, Android minSdk, iOS min version)

If the requirement is only **private access** (trusted consumers are OK seeing code), start with **Option B** or **Option C**.

### 11.4 Practical next steps (when you decide to productize)

- Split proprietary logic into native SDK modules (Android + iOS) with clear public APIs.
- Add CI pipelines to build and publish:
  - Android: Maven artifact (AAR)
  - iOS: XCFramework zip + podspec update
- Update each Flutter plugin to depend on the native artifacts rather than embedding full native source.
- Add release automation (version bump, changelog, artifact promotion) and smoke tests.

## 12. FAQ

### “Which app should I run while developing?”

Start with `adaire_sdk_app/` unless you’re debugging a plugin in isolation.

### “Why do some plugins use `com.example...` namespaces?”

This is a legacy template artifact. It’s not a runtime blocker for local work, but should be standardized before publishing.

### “Where do I add a new error code?”

- Android/iOS: when returning `result.error(code, message, details)` / `FlutterError(code:...)`
- Dart: document in README/architecture docs; optionally translate to typed failures if you introduce a wrapper.
