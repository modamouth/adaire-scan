# flutter_barcode_qr_scanner

This README is written for developers working on the **SDK/plugin itself** (architecture, folder structure, and how to run/build/test the plugin).

If you're only integrating the plugin into an app, use the example app in `example/` as the reference integration.

## What this plugin does

`flutter_barcode_qr_scanner` is a private-source Flutter plugin candidate that:

- Presents a **native full-screen** scanner UI.
- Returns the **first** detected code through a typed terminal outcome.
- Normalizes the returned result into a Dart `ScanResult` with:
  - `value`: decoded payload
  - `type`: normalized `BarcodeFormat` enum

Phase 2 supported implementation:

- Android: ZXing Embedded (`com.journeyapps:zxing-android-embedded`) with a lightweight Kotlin `Activity`.

Private-evaluation scope:

- Android only. The candidate compiles with `minSdk 24`, but current physical-device evidence is limited to the recorded test matrix.
- QR, EAN-13, and Code 128 only.
- iOS source remains in the repository but is not implemented, verified, or supported by this increment.
- This package is not approved for public distribution or production claims.

## Repository layout

Top-level folders in this plugin package:

- `lib/`
  - `flutter_barcode_qr_scanner.dart`: public Dart API (`FlutterBarcodeQrScanner`, `ScanResult`, `BarcodeFormat`)
  - `flutter_barcode_qr_scanner_platform_interface.dart`: platform interface contract
  - `flutter_barcode_qr_scanner_method_channel.dart`: method-channel implementation
- `android/`
  - `src/main/AndroidManifest.xml`: declares `android.permission.CAMERA` + scanner activity
  - `src/main/kotlin/.../FlutterBarcodeQrScannerPlugin.kt`: method-channel handler + activity launch
  - `src/main/kotlin/.../SimpleScanActivity.kt`: scanner UI + permission flow + format mapping
  - `src/test/kotlin/...`: Kotlin unit tests
- `ios/`
  - `Classes/FlutterBarcodeQrScannerPlugin.swift`: method-channel handler + AVFoundation scanner UI
  - `Resources/PrivacyInfo.xcprivacy`: placeholder privacy manifest (not bundled by default)
- `example/`: a full Flutter app used for local development and manual testing
- `test/`: Dart unit tests for the platform interface and method channel

## Architecture (end-to-end)

Call path when Dart code invokes `scan()`:

1. `FlutterBarcodeQrScanner.scan()` (in `lib/flutter_barcode_qr_scanner.dart`)
2. Calls `FlutterBarcodeQrScannerPlatform.instance.scan(formats: ...)`
3. Default instance is `MethodChannelFlutterBarcodeQrScanner`
4. Sends `MethodChannel('flutter_barcode_qr_scanner')` method call:
   - method: `scan`
   - args: `{ "formats": ["qr", "ean13", ...] }` (optional)
5. Android returns one terminal envelope with `outcome`.
6. Dart validates the envelope and returns a typed `ScanOutcome`.

### Method-channel contract

Channel name:

- `flutter_barcode_qr_scanner`

Supported methods:

- `getPlatformVersion` -> `String?`
- `scan` (`formats: List<String>`) -> `Map<String, dynamic>`

Successful native envelope:

```json
{ "outcome": "success", "value": "...", "type": "qr" }
```

Non-success envelopes contain no decoded payload:

```json
{ "outcome": "permission_denied" }
```

Valid outcomes are `success`, `cancelled`, `permission_denied`, `unavailable`, `busy`, and `failure`.

## Key behaviors to know when developing

### Typed outcomes

`FlutterBarcodeQrScanner.scan()` returns `ScanOutcome`. Handle its `type` without parsing messages:

```dart
final outcome = await FlutterBarcodeQrScanner().scan(
  formats: const [BarcodeFormat.qr],
);

switch (outcome.type) {
  case ScanOutcomeType.success:
    final result = outcome.result!;
    // Treat result.value as sensitive inert data.
    return;
  case ScanOutcomeType.cancelled:
    break;
  case ScanOutcomeType.permissionDenied:
    // Offer a settings recovery path.
    return;
  case ScanOutcomeType.unavailable:
  case ScanOutcomeType.busy:
  case ScanOutcomeType.failure:
    // Present an appropriate payload-free recovery message.
    return;
}
```

Decoded values are intentionally excluded from `ScanResult.toString()` and `ScanOutcome.toString()`. Applications must not log, persist, transmit, open, or execute values automatically.

### Concurrency

The plugin returns `ScanOutcomeType.busy` for a concurrent scan. Missing activity and launch problems return `ScanOutcomeType.unavailable`. Expected outcomes do not require `PlatformException` message parsing.

## Barcode format model (and how to extend it)

### Dart: `BarcodeFormat`

The approved Android keys are `qr`, `ean13`, and `code128`. Omitting `formats` selects exactly that set. An empty list or any unsupported format fails before launch and never broadens scanning.

To add a new format:

1. Add the enum value in `lib/flutter_barcode_qr_scanner.dart`.
2. Update `barcodeFormatFromKey` for reverse mapping.

### Android: key <-> ZXing mapping

Android maps keys in `android/src/main/kotlin/.../SimpleScanActivity.kt`:

- `keyToFormat(key)` converts Dart keys to `com.google.zxing.BarcodeFormat`
- `formatToKey(format)` converts ZXing format back to Dart key

If you add a new Dart enum value, you must update both functions.

Formats outside the approved set remain legacy enum values and are rejected by the Phase 2 scan entry point. Adding a format requires a separate evidence-backed contract decision and mapping tests.

## Local development

### Prerequisites

- Flutter SDK matching the repo constraints (`sdk: ^3.9.2`, Flutter `>=3.3.0`).
- Android: Android Studio + an emulator/device.

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

Use a real Android device for camera, permission, lifecycle, torch, and TalkBack evidence. A successful build or emulator run does not substitute for physical-device evidence.

### Run Dart tests (plugin)

From the plugin root:

```bash
flutter test
```

These tests cover the platform interface and method-channel wiring.

### Run Android unit tests (native)

There is no Gradle wrapper in `flutter_barcode_qr_scanner/android/`, so run via the example app’s wrapper.

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

If you prefer an IDE workflow, open `example/android/` in Android Studio and run the Kotlin tests under `flutter_barcode_qr_scanner/android/src/test/...`.

## Debugging

### Dart <-> native communication

- Confirm the method channel name is exactly `flutter_barcode_qr_scanner`.
- Confirm method names: `scan`, `getPlatformVersion`.

### Android scanner UI

- Scanner activity: `SimpleScanActivity`.
- Permission flow:
  - Requests `Manifest.permission.CAMERA` at runtime.
  - Returns canceled if permission is denied.

## Release checklist (internal)

- Update `pubspec.yaml` version.
- Update `CHANGELOG.md` with real release notes.
- Run `flutter test`.
- Execute the approved Android physical-device, privacy, accessibility, and clean-host matrix.
- Record Architect, QA, Security, UX/UI, and Product Owner decisions.
- Obtain a separate human decision before external distribution.

## Where to look first

- Public API: `lib/flutter_barcode_qr_scanner.dart`
- Method-channel glue: `lib/flutter_barcode_qr_scanner_method_channel.dart`
- Android entrypoint: `android/src/main/kotlin/.../FlutterBarcodeQrScannerPlugin.kt`
- Android scanner UI: `android/src/main/kotlin/.../SimpleScanActivity.kt`
- Phase 2 contract ADR: the agentic-dev-team repository decision `0011`
