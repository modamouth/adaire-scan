# flutter_credit_card_scanner

This README is written for developers working on the **SDK/plugin itself** (architecture, folder structure, and how to run/build/test the plugin).

If you're only integrating the plugin into an app, use the example app in `example/` as the reference integration.

## What this plugin does

`flutter_credit_card_scanner` is a Flutter plugin (platform interface + method channel + native implementations) that:

- Presents a **native full-screen** credit card scanner UI.
- Uses **on-device OCR** only (no network calls).
- Returns a Dart `CreditCardScanResult` with:
  - `cardNumber` (PAN, Luhn-validated)
  - `cardBrand` (best-effort)
  - `expiryMonth`/`expiryYear` (optional)
  - `cardholderName` (optional)

Native implementations:

- Android: CameraX + ML Kit Text Recognition (`com.google.mlkit:text-recognition`).
- iOS: VisionKit DataScanner (iOS 16+ when supported) with a fallback flow that captures a still image and runs on-device parsing.

Supported runtime platforms:

- Android (minSdk 24)
- iOS (iOS 13+)

Non-goals:

- CVV scanning (intentionally not supported).
- Persisting or transmitting PANs.

## Repository layout

Top-level folders in this plugin package:

- `lib/`
  - `flutter_credit_card_scanner.dart`: public Dart API (`FlutterCreditCardScanner`, `CreditCardScanResult`)
  - `flutter_credit_card_scanner_platform_interface.dart`: platform interface contract
  - `flutter_credit_card_scanner_method_channel.dart`: method-channel implementation
- `android/`
  - `src/main/AndroidManifest.xml`: declares `android.permission.CAMERA`
  - `src/main/kotlin/.../FlutterCreditCardScannerPlugin.kt`: method-channel handler + activity launch
  - `src/main/kotlin/.../CardScanActivity.kt`: CameraX + OCR + stability logic + overlays
  - `src/test/kotlin/...`: Kotlin unit tests
- `ios/`
  - `Classes/FlutterCreditCardScannerPlugin.swift`: method-channel handler + VisionKit / fallback flow
- `example/`: a full Flutter app used for local development and manual testing
- `test/`: Dart unit tests for the platform interface and method channel

## Architecture (end-to-end)

Call path when Dart code invokes `scanCard()`:

1. `FlutterCreditCardScanner.scanCard(...)` (in `lib/flutter_credit_card_scanner.dart`)
2. Calls `FlutterCreditCardScannerPlatform.instance.scanCard(options)`
3. Default instance is `MethodChannelFlutterCreditCardScanner`
4. Sends `MethodChannel('flutter_credit_card_scanner')` method call:
   - method: `scanCard`
   - args: a `Map<String, Object?>` containing scan options
5. Native platform returns either:
   - `null` (canceled / permission denied)
   - a map payload that becomes `CreditCardScanResult`

### Method-channel contract

Channel name:

- `flutter_credit_card_scanner`

Supported methods:

- `getPlatformVersion` -> `String?`
- `scanCard` (options map) -> `Map<String, dynamic>?`

Options map keys (Dart):

- `scanExpiry`: `bool` (default `true`)
- `scanCardholderName`: `bool` (default `false`)
- `restrictBrand`: `String?` (`visa`, `mastercard`, `amex`, `discover`, `diners`, `jcb`, `unionpay`)
- `timeoutMs`: `int?` (if `> 0`, native enforces a timeout)
- `debug`: `bool` (Android-only today)
- `showDetectedQuad`: `bool` (Android-only today)
- `cropToGuide`: `bool` (Android-only today)
- `consensusRequired`: `int` (Android-only today; default `3`)
- `stabilityRequired`: `int` (Android-only today; default `2`)

Native return map shape:

```json
{
  "cardNumber": "4111111111111111",
  "expiryMonth": 12,
  "expiryYear": 2030,
  "cardholderName": "JANE DOE",
  "cardBrand": "visa"
}
```

Notes:

- iOS currently reads only `scanExpiry`, `scanCardholderName`, `restrictBrand`, `timeoutMs`. Other keys are ignored.
- `expiryMonth`/`expiryYear` may be omitted when parsing is disabled or not detected.

## Key behaviors to know when developing

### Cancellation and “no result”

This plugin uses `null` as the “no result” signal.

`scanCard()` resolves to `null` when:

- The user cancels the scanner UI.
- The user denies camera permission.
- The scanner cannot be presented (for example, no root view controller on iOS).

### Concurrency

The plugin rejects concurrent scans.

If `scanCard()` is invoked while another scan is in progress, native code throws a `PlatformException` with:

- code: `ALREADY_ACTIVE`

Android can also throw:

- code: `NO_ACTIVITY` (no foreground activity to launch the scanner activity)

### Errors and error codes

Common error codes:

- `ALREADY_ACTIVE`: you started a second scan too early
- `NO_ACTIVITY` (Android): plugin not attached to an Activity
- `NO_VIEW` (iOS): no top view controller found
- `TIMEOUT`: scan timed out
- `SCAN_ERROR`: scanning/capture pipeline failed

## Android implementation notes

### Stability/consensus knobs

Android has additional tuning controls to avoid returning transient OCR noise:

- `consensusRequired`: number of times a candidate PAN must appear in a sliding window
- `stabilityRequired`: number of consecutive frames the same PAN must be stable

The logic lives in `CardScanActivity.kt`.

### Quad overlay and edge detection

When `showDetectedQuad` is enabled, Android attempts to display a detected card quad.

Implementation detail:

- The plugin tries to reflectively load `OpenCvEdgeDetector` if present.
- This repo intentionally does **not** ship OpenCV `.so` binaries (see `android/build.gradle`), so the runtime typically falls back to an OCR-box-based overlay.

## Local development

### Prerequisites

- Flutter SDK matching the repo constraints (`sdk: ^3.9.2`, Flutter `>=3.3.0`).
- Android: Android Studio + an emulator/device.
- iOS: Xcode + a real device (camera reliability varies in simulators).

### Get dependencies

From the plugin root:

```bash
flutter pub get
```

### Run the example app

The example app is the primary way to manual-test native scanning flows.

```bash
cd example
flutter pub get
flutter run
```

Tips:

- For iOS, ensure the example app’s `Info.plist` contains `NSCameraUsageDescription`.
- Prefer a real device to validate scanning performance.

### Run Dart tests (plugin)

From the plugin root:

```bash
flutter test
```

### Run Android unit tests (native)

There is no Gradle wrapper in `flutter_credit_card_scanner/android/`, so run via the example app’s wrapper.

From the plugin root:

```bash
cd example/android
./gradlew testDebugUnitTest
```

On Windows:

```bat
cd example\android
gradlew.bat testDebugUnitTest
```

## Debugging

### Dart <-> native communication

- Confirm the method channel name is exactly `flutter_credit_card_scanner`.
- Confirm method names: `scanCard`, `getPlatformVersion`.

### Android logging

Android uses log tags like `CardScan` in debug mode. Avoid logging sensitive values (see Security).

## Security & privacy rules

Treat scan outputs as sensitive by default.

- Do NOT log:
  - PANs
  - raw OCR text that may contain PAN/PII
- If you need debug diagnostics, log only metadata:
  - last 4 digits
  - length
  - detected brand

## Release checklist (internal)

- Update `pubspec.yaml` version.
- Update `CHANGELOG.md` with real release notes.
- Run `flutter test`.
- Smoke-test the example on Android + iOS.

## Where to look first

- Public API: `lib/flutter_credit_card_scanner.dart`
- Method-channel glue: `lib/flutter_credit_card_scanner_method_channel.dart`
- Android entrypoint: `android/src/main/kotlin/.../FlutterCreditCardScannerPlugin.kt`
- Android scanner UI: `android/src/main/kotlin/.../CardScanActivity.kt`
- iOS implementation: `ios/Classes/FlutterCreditCardScannerPlugin.swift`

