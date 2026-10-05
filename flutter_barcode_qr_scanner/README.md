# flutter_barcode_qr_scanner

This README is written for developers working on the **SDK/plugin itself** (architecture, folder structure, and how to run/build/test the plugin).

If you're only integrating the plugin into an app, use the example app in `example/` as the reference integration.

## What this plugin does

`flutter_barcode_qr_scanner` is a Flutter **federated-style plugin** (platform interface + method channel + native implementations) that:

- Presents a **native full-screen** scanner UI.
- Returns the **first** detected code.
- Normalizes the returned result into a Dart `ScanResult` with:
  - `value`: decoded payload
  - `type`: normalized `BarcodeFormat` enum

Native implementations:

- Android: ZXing Embedded (`com.journeyapps:zxing-android-embedded`) with a lightweight Kotlin `Activity`.
- iOS: AVFoundation camera capture + metadata output in Swift.

Supported runtime platforms:

- Android (minSdk 24)
- iOS (iOS 13+)

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
5. Native platform returns either:
   - `null` (canceled / permission denied)
   - a map `{ "value": String, "type": String }`
6. Dart converts map to `ScanResult` via `ScanResult.fromMap`

### Method-channel contract

Channel name:

- `flutter_barcode_qr_scanner`

Supported methods:

- `getPlatformVersion` -> `String?`
- `scan` (optional `formats: List<String>`) -> `Map<String, dynamic>?`

Native return map shape:

```json
{ "value": "...", "type": "qr" }
```

## Key behaviors to know when developing

### Cancellation and “no result”

This plugin uses `null` as the “no result” signal.

`scan()` resolves to `null` when:

- The user cancels the scanner UI.
- The user denies camera permission.
- The scanner cannot be presented (for example, no root view controller on iOS).

### Concurrency

The plugin rejects concurrent scans.

If `scan()` is invoked while another scan is in progress, native code throws a `PlatformException` with:

- code: `ALREADY_ACTIVE`

Android can also throw:

- code: `NO_ACTIVITY` (no foreground activity to launch the scanner activity)

## Barcode format model (and how to extend it)

### Dart: `BarcodeFormat`

The canonical keys are the Dart enum names (e.g. `qr`, `ean13`, `code128`).

To add a new format:

1. Add the enum value in `lib/flutter_barcode_qr_scanner.dart`.
2. Update `barcodeFormatFromKey` for reverse mapping.

### Android: key <-> ZXing mapping

Android maps keys in `android/src/main/kotlin/.../SimpleScanActivity.kt`:

- `keyToFormat(key)` converts Dart keys to `com.google.zxing.BarcodeFormat`
- `formatToKey(format)` converts ZXing format back to Dart key

If you add a new Dart enum value, you must update both functions.

### iOS: key <-> AVFoundation mapping

iOS maps keys in `ios/Classes/FlutterBarcodeQrScannerPlugin.swift`:

- `keyToType(key)` converts Dart keys to `AVMetadataObject.ObjectType`
- `typeToKey(type)` converts AVFoundation type back to Dart key

Important: some Dart keys do not have AVFoundation equivalents. Today:

- `upca` and `codabar` exist on the Dart side, but are not mapped on iOS.

If you extend format support, keep Android/iOS parity in mind and document any platform gaps.

## Local development

### Prerequisites

- Flutter SDK matching the repo constraints (`sdk: ^3.9.2`, Flutter `>=3.3.0`).
- Android: Android Studio + an emulator/device.
- iOS: Xcode + a real device or simulator (camera availability varies).

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
- Prefer a real device for camera scanning.

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

### iOS scanner UI

- Uses `AVCaptureSession` + `AVCaptureMetadataOutput`.
- Permission flow:
  - Uses `AVCaptureDevice.requestAccess(for: .video)`.
  - Returns canceled if permission is denied.

## iOS privacy manifest note

This repo includes `ios/Resources/PrivacyInfo.xcprivacy`, but the podspec currently does **not** bundle it (the `resource_bundles` line is commented).

If you introduce any APIs that require Apple privacy manifest declarations, update the `.xcprivacy` file and enable bundling in `ios/flutter_barcode_qr_scanner.podspec`.

## Release checklist (internal)

- Update `pubspec.yaml` version.
- Update `CHANGELOG.md` with real release notes.
- Run `flutter test`.
- Smoke-test the example on Android + iOS.

## Where to look first

- Public API: `lib/flutter_barcode_qr_scanner.dart`
- Method-channel glue: `lib/flutter_barcode_qr_scanner_method_channel.dart`
- Android entrypoint: `android/src/main/kotlin/.../FlutterBarcodeQrScannerPlugin.kt`
- Android scanner UI: `android/src/main/kotlin/.../SimpleScanActivity.kt`
- iOS implementation: `ios/Classes/FlutterBarcodeQrScannerPlugin.swift`

