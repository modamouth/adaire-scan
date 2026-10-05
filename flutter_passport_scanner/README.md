# flutter_passport_scanner

This README is written for developers working on the **SDK/plugin itself** (architecture, folder structure, and how to run/build/test the plugin).

If you're only integrating the plugin into an app, use the example app in `example/` as the reference integration.

## What this plugin does

`flutter_passport_scanner` is a Flutter plugin (platform interface + method channel + native implementations) that:

- Provides a **native document capture UI** (edge detection/cropping handled by the platform scanner).
- Returns local file paths for captured passport images (and optional PDF on Android).
- Optionally runs **OCR + MRZ parsing in Dart** (on-device) to produce a structured `PassportMrz`.

Key design choice:

- Native layers only do **document capture**.
- Dart layer performs **OCR + MRZ parsing/validation**, which makes it easier to test and evolve.

Supported runtime platforms:

- Android (minSdk 24)
- iOS (iOS 13+)

## Repository layout

Top-level folders in this plugin package:

- `lib/`
	- `flutter_passport_scanner.dart`: public Dart API (`FlutterPassportScanner`, `PassportScanOptions`, `PassportScanResult`)
	- `flutter_passport_scanner_platform_interface.dart`: platform interface contract
	- `flutter_passport_scanner_method_channel.dart`: method-channel implementation
	- `src/`
		- `passport_ocr.dart`: OCR helper (ML Kit Text Recognition via `google_mlkit_text_recognition`)
		- `mrz.dart`: MRZ model + `MrzParser` (check-digit validation)
- `android/`
	- `src/main/kotlin/.../FlutterPassportScannerPlugin.kt`: method-channel handler for `scanPassport` using ML Kit Document Scanner
- `ios/`
	- `Classes/FlutterPassportScannerPlugin.swift`: method-channel handler using VisionKit document camera
- `example/`: a full Flutter app used for local development and manual testing
- `test/`: Dart unit tests for MRZ parsing and helpers

## Architecture (end-to-end)

There are two related flows:

1) **Low-level document capture**: `scanPassport` (MethodChannel)
2) **High-level passport scan**: `FlutterPassportScanner.scanPassport()` (Dart optionally runs OCR + parses MRZ)

### Flow A: native capture (`scanPassport`)

1. Dart calls `FlutterPassportScannerPlatform.instance.scanPassport(options)`
2. Default instance is `MethodChannelFlutterPassportScanner`
3. Sends `MethodChannel('flutter_passport_scanner')` method call:
	 - method: `scanPassport`
	 - args: `{ "pageLimit": 1, "allowGalleryImport": false, "performOcr": true }`
4. Native returns either:
	 - `null` (canceled)
	 - a map `{ "imagePaths": [String...], "pdfPath": String? }`

### Flow B: OCR + MRZ parsing (Dart)

If `PassportScanOptions.performOcr` is `true` and at least one image is returned:

1. Dart runs OCR against the first image
2. Dart attempts to locate and parse MRZ lines (TD3-style) via `MrzParser`
3. Dart returns `PassportScanResult` containing:
	 - `mrz`: `PassportMrz?` (null when not found/invalid)
	 - `rawOcrText`: `String?` (for debugging/telemetry in secure environments)

### Method-channel contract

Channel name:

- `flutter_passport_scanner`

Supported methods:

- `getPlatformVersion` -> `String?`
- `scanPassport` (options map) -> `Map<String, Object?>?`

Options map keys:

- `pageLimit`: `int` (default `1`, clamped to `1..10`)
- `allowGalleryImport`: `bool` (default `false`; Android-only today)
- `performOcr`: `bool` (default `true`; Dart-only today)

Native return map shape:

```json
{
	"imagePaths": ["/local/cache/path/page_0_...jpg"],
	"pdfPath": "/local/cache/path/file_...pdf"
}
```

Notes:

- Android returns both `imagePaths` and (optionally) `pdfPath`.
- iOS returns `imagePaths` only.

## Key behaviors to know when developing

### Cancellation and “no result”

This plugin uses `null` as the “no result” signal.

`scanPassport()` resolves to `null` when:

- the user cancels the document camera
- the scanner cannot be presented (for example, no root view controller on iOS)

### Errors and error codes

Common error codes:

- `ALREADY_ACTIVE`: you started a second scan too early
- `NO_ACTIVITY` (Android): plugin not attached to an Activity
- `NO_VIEW` (iOS): no top view controller found
- `UNAVAILABLE` (iOS): VisionKit document camera not supported/available
- `SCAN_ERROR`: capture pipeline failed

## Local development

### Prerequisites

- Flutter SDK matching the repo constraints (`sdk: ^3.9.2`, Flutter `>=3.3.0`).
- Android: Android Studio + an emulator/device with Google Play services available.
- iOS: Xcode + a real device (document camera support depends on device).

### Get dependencies

From the plugin root:

```bash
flutter pub get
```

### Run the example app

```bash
cd example
flutter pub get
flutter run
```

Tips:

- For iOS, ensure the example app’s `Info.plist` contains `NSCameraUsageDescription`.
- Prefer a real device to validate capture quality.

### Run Dart tests (plugin)

From the plugin root:

```bash
flutter test
```

### Run Android unit tests (native)

There is no Gradle wrapper in `flutter_passport_scanner/android/`, so run via the example app’s wrapper.

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

## Extension points

Most of the “value” of this SDK is in Dart-side MRZ parsing and validation.

- Improve MRZ line detection and normalization in `lib/src/passport_ocr.dart`.
- Improve parsing/validation rules in `lib/src/mrz.dart`.
- Add unit tests for MRZ parsing without touching native code.

If you change native capture behavior, update both Android + iOS and keep the method contract stable.

## Security & privacy rules

Treat scan outputs as sensitive by default.

- Do NOT log:
	- raw OCR text
	- MRZ lines
- Returned file paths are temporary/cache paths and may not persist forever.

## Release checklist (internal)

- Update `pubspec.yaml` version.
- Update `CHANGELOG.md` with real release notes.
- Run `flutter test`.
- Smoke-test the example on Android + iOS.

## Where to look first

- Public API: `lib/flutter_passport_scanner.dart`
- OCR helper: `lib/src/passport_ocr.dart`
- MRZ parser: `lib/src/mrz.dart`
- Native Android: `android/src/main/kotlin/.../FlutterPassportScannerPlugin.kt`
- Native iOS: `ios/Classes/FlutterPassportScannerPlugin.swift`

