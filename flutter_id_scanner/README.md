# flutter_id_scanner

This README is written for developers working on the **SDK/plugin itself** (architecture, folder structure, and how to run/build/test the plugin).

If you're only integrating the plugin into an app, use the example app in `example/` as the reference integration.

## What this plugin does

`flutter_id_scanner` is a Flutter plugin (platform interface + method channel + native implementations) that:

- Provides a **native document capture UI** (edge detection/cropping handled by the platform scanner).
- Returns local file paths for captured images.
- Runs **OCR + parsing in Dart** (on-device) to extract best-effort ID fields.

Key design choice:

- Native layers only do **document capture**.
- Dart layer performs **OCR + parsing**, which makes iteration and testing easier.

Supported runtime platforms:

- Android (minSdk 24)
- iOS (iOS 13+)

## Repository layout

Top-level folders in this plugin package:

- `lib/`
	- `flutter_id_scanner.dart`: public Dart API (`FlutterIdScanner`) and orchestration for 2-step capture
	- `flutter_id_scanner_platform_interface.dart`: platform interface contract
	- `flutter_id_scanner_method_channel.dart`: method-channel implementation
	- `src/`
		- `id_scan.dart`: options + result models (`IdScanOptions`, `IdScanResult`, `IdCardData`)
		- `id_ocr.dart`: OCR helper (ML Kit Text Recognition via `google_mlkit_text_recognition`)
		- `id_text_parser.dart`: heuristic field extraction
- `android/`
	- `src/main/kotlin/.../FlutterIdScannerPlugin.kt`: method-channel handler for `scanDocument` using ML Kit Document Scanner
- `ios/`
	- `Classes/FlutterIdScannerPlugin.swift`: method-channel handler using VisionKit document camera
- `example/`: a full Flutter app used for local development and manual testing
- `test/`: Dart unit tests (parsing/OCR helpers where applicable)

## Architecture (end-to-end)

There are two related flows:

1) **Low-level document capture**: `scanDocument` (MethodChannel)
2) **High-level ID scan**: `scanIdCard` (Dart orchestrates front + back capture, OCR, parsing)

### Flow A: document capture (`scanDocument`)

1. Dart calls `FlutterIdScannerPlatform.instance.scanDocument(options)`
2. Default instance is `MethodChannelFlutterIdScanner`
3. Sends `MethodChannel('flutter_id_scanner')` method call:
	 - method: `scanDocument`
	 - args: `{ "pageLimit": 1, "allowGalleryImport": false }`
4. Native returns either:
	 - `null` (canceled)
	 - a map `{ "imagePaths": [String...], "pdfPath": String? }`

### Flow B: two-step ID scan (`scanIdCard`)

1. Dart calls `scanDocument(pageLimit: 1)` to capture the **front** image
2. Dart (optionally) runs OCR on the front image and stores raw OCR text
3. Dart calls `scanDocument(pageLimit: 1)` to capture the **back** image
4. Dart (optionally) runs OCR on the back image
5. Dart combines lines and performs best-effort parsing into `IdCardData`

This orchestration is implemented in `lib/flutter_id_scanner.dart`.

### Method-channel contract

Channel name:

- `flutter_id_scanner`

Supported methods:

- `getPlatformVersion` -> `String?`
- `scanDocument` (options map) -> `Map<Object?, Object?>?`

Options map keys:

- `pageLimit`: `int` (default `1`, clamped to `1..10`)
- `allowGalleryImport`: `bool` (default `false`; Android-only today)

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

### High-level Dart API options

`scanIdCard()` accepts:

- `IdScanOptions.allowGalleryImport` (forwarded to native; Android-only today)
- `IdScanOptions.performOcr` (Dart-only; controls OCR + parsing)
- `IdScanOptions.returnPartialOnCancel`:
	- if `false` (default), canceling on back capture returns `null`
	- if `true`, canceling on back capture returns a partial result containing the front capture

It also supports an optional progress callback:

- `onProgress(IdCaptureSide.front|back)` so the app can show prompts.

## Key behaviors to know when developing

### Cancellation and “no result”

Both native `scanDocument` and Dart `scanIdCard` use `null` as the “no result” signal.

`scanIdCard()` returns `null` when:

- the user cancels on front capture
- the user cancels on back capture (unless `returnPartialOnCancel` is `true`)

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

There is no Gradle wrapper in `flutter_id_scanner/android/`, so run via the example app’s wrapper.

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

Most of the “value” of this SDK is in Dart-side parsing.

- Add/adjust field extraction in `lib/src/id_text_parser.dart`.
- Add unit tests for parsing without touching native code.

If you need capture changes (page limits, gallery import behavior), update both native implementations and keep method contracts stable.

## Security & privacy rules

Treat scan outputs as sensitive by default.

- Do NOT log raw OCR text that may contain PII.
- Avoid copying images into permanent storage unless explicitly required.
- Returned file paths are temporary/cache paths and may not persist forever.

## Release checklist (internal)

- Update `pubspec.yaml` version.
- Update `CHANGELOG.md` with real release notes.
- Run `flutter test`.
- Smoke-test the example on Android + iOS.

## Where to look first

- High-level API: `lib/flutter_id_scanner.dart`
- Options/results: `lib/src/id_scan.dart`
- OCR helper: `lib/src/id_ocr.dart`
- Parsing: `lib/src/id_text_parser.dart`
- Native Android: `android/src/main/kotlin/.../FlutterIdScannerPlugin.kt`
- Native iOS: `ios/Classes/FlutterIdScannerPlugin.swift`

