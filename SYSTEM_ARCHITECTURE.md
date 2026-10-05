# Adaire SDK Suite — System Architecture

**Audience:** engineers working on the demo app and SDKs

**Scope:** this repository (demo app + 4 Flutter plugins)

**Last updated:** 2026-02-18

## 1. Executive summary

This repo is a Flutter-based SDK suite that provides **on-device scanning/capture** experiences via four plugins and a demo application.

- The **demo app** (`adaire_sdk_app/`) is a showcase/test harness that calls into each plugin and displays results.
- Each **SDK** is a Flutter plugin using the same overall pattern:
  - Public Dart API (`lib/*.dart`)
  - A platform interface and method channel implementation
  - Native Android (Kotlin) + iOS (Swift) implementations

All SDKs present **native full-screen UIs** for scanning/capture and return results back to Dart via **Flutter method channels**.

For a deeper dive into each SDK’s implementation details (method-channel contract, native entrypoints, debugging, and how to run plugin tests), refer to the individual plugin READMEs (intended to be browsed in GitHub):

- Barcode/QR SDK: [flutter_barcode_qr_scanner/README.md](flutter_barcode_qr_scanner/README.md)
- Credit Card SDK: [flutter_credit_card_scanner/README.md](flutter_credit_card_scanner/README.md)
- ID SDK: [flutter_id_scanner/README.md](flutter_id_scanner/README.md)
- Passport SDK: [flutter_passport_scanner/README.md](flutter_passport_scanner/README.md)

## 1.1 Glossary (how to read this document)

This section defines the recurring terms used throughout the architecture sections.

### Channel

In this repo, **channel** means a Flutter **method channel name** (a string identifier) used as a communication bridge between:

- **Dart code** (running in the Flutter engine), and
- **native code** (Android/iOS)

Example:

- The barcode SDK uses the channel name `flutter_barcode_qr_scanner`.

Think of a channel like a “phone line” between Dart and native. Both sides must agree on the exact channel name.

### Dart layers

**Dart layers** are the Dart/Flutter-side parts of a plugin. In these SDKs you’ll typically see three layers:

1. **Public API** (what app code calls)
   - Example: `FlutterBarcodeQrScanner.scan()`
2. **Platform interface** (an abstract contract)
   - Defines what methods the platform must implement.
3. **Method channel implementation** (the default implementation)
   - Sends method calls across the channel and converts native results into Dart types.

The separation keeps the public API stable and makes it easier to test/migrate implementations.

### Native layers

**Native layers** are the Android/iOS implementations of the plugin.

- **Android (Kotlin)**
  - A plugin class that receives method calls (e.g., "scan") and launches native UI (Activities/IntentSenders).
  - Optionally one or more Activities/Views that present camera UI and return a result.
- **iOS (Swift)**
  - A plugin class that receives method calls and presents native view controllers.

Native layers are responsible for:

- Permissions and device capabilities
- Presenting the camera UI
- Returning a result map (or `nil`) back to Dart

### Method contract

A **method contract** is the agreement between Dart and native about:

- Channel name
- Method names (strings)
- Arguments shape (keys + types)
- Return type/shape
- Error codes

Example (barcode scan):

- Channel: `flutter_barcode_qr_scanner`
- Method: `scan`
- Args: `{ formats?: List<String> }`
- Return:
  - `null` if user cancels / denies permission
  - `{ "value": String, "type": String }` on success

If either side changes this contract (e.g., renaming a method or return key), the SDK breaks at runtime.

### Error codes

When native code fails unexpectedly, it can return a **platform error** to Dart.
In Flutter this typically arrives as a `PlatformException` containing:

- `code`: a stable string like `ALREADY_ACTIVE`
- `message`: human-readable details

Example meanings used across these SDKs:

- `ALREADY_ACTIVE`: you tried to start a second scan while one is still running.
- `NO_ACTIVITY` (Android): the plugin can’t access a foreground Android Activity to launch UI.
- `NO_VIEW` (iOS): the plugin can’t find a top view controller to present UI.
- `SCAN_ERROR`: an error occurred while scanning/capturing.
- `TIMEOUT`: scan UI timed out (credit card SDK).

Cancellation is generally **not** an error in this repo; it returns `null`.

## 2. Component inventory

### 2.1 Top-level components

- Demo app: `adaire_sdk_app/`
- SDKs (plugins):
  - `flutter_barcode_qr_scanner/`
  - `flutter_credit_card_scanner/`
  - `flutter_id_scanner/`
  - `flutter_passport_scanner/`

### 2.2 Plugin responsibilities (at a glance)

| SDK | Primary capability | Native capture | Dart post-processing |
|---|---|---|---|
| Barcode/QR | decode QR + barcodes | Android: ZXing Embedded Activity; iOS: AVFoundation camera session | Normalize type key -> `BarcodeFormat` |
| Credit Card | scan PAN + brand (+ optional expiry/name) | Android: CameraX + ML Kit text recognition; iOS: VisionKit DataScanner (iOS16+) or document camera fallback | Parse/validate in native; map to `CreditCardScanResult` |
| ID Card | capture front + back images | Android: ML Kit Document Scanner; iOS: VisionKit VNDocumentCamera | OCR + parsing in Dart (ML Kit text recognition via Dart) |
| Passport | capture data page image(s) and extract MRZ | Android: ML Kit Document Scanner; iOS: VisionKit VNDocumentCamera | OCR + MRZ parsing in Dart (ICAO 9303 TD3) |

## 3. High-level architecture

### 3.1 System context diagram

```mermaid
flowchart TB
  subgraph DemoApp[Demo App: adaire_sdk_app]
    UI[SdkShowcasePage UI]
    Services[Service wrappers]
  end

  subgraph Plugins[Flutter Plugins]
    BQ[Dart: flutter_barcode_qr_scanner]
    CC[Dart: flutter_credit_card_scanner]
    ID[Dart: flutter_id_scanner]
    PP[Dart: flutter_passport_scanner]
  end

  subgraph Native[Native Platforms]
    Android[Android (Kotlin/Gradle)]
    iOS[iOS (Swift/CocoaPods)]
  end

  UI --> Services
  Services --> BQ
  Services --> CC
  Services --> ID
  Services --> PP

  BQ --> Android
  BQ --> iOS
  CC --> Android
  CC --> iOS
  ID --> Android
  ID --> iOS
  PP --> Android
  PP --> iOS
```

### 3.2 Common plugin pattern

All SDKs follow a consistent plugin layering:

1. **Public Dart API** (e.g., `FlutterBarcodeQrScanner.scan()`)
2. **Platform interface** (`..._platform_interface.dart`) to decouple API from transport
3. **Method channel implementation** (`..._method_channel.dart`) using `MethodChannel('<channel_name>')`
4. **Native plugin** implements method call handlers and presents native UI
5. Results flow back over the method channel as a JSON-like map or `null`

## 4. Demo application architecture (`adaire_sdk_app/`)

### 4.1 Structure

- `lib/app/app.dart`: root `MaterialApp`
- `lib/features/sdk_showcase/`: main UI feature, grid of SDK tiles
- `lib/services/`: thin wrappers around each SDK package
- `lib/core/ui/`: shared UI utilities (e.g., result dialogs)
- `lib/app_mode.dart`: build-time configuration via `--dart-define=APP_MODE=...`

### 4.2 Runtime flow

1. User taps a tile in `SdkShowcasePage`
2. The corresponding service is called:
   - `BarcodeScannerService.scan()`
   - `CreditCardScannerService.scanCard(...)`
   - `PassportScannerService.scanPassport()`
   - `IdScannerService.scanId(...)`
3. Service calls into plugin Dart API.
4. Result or error is rendered in a result dialog.

### 4.3 Design notes

- Services are intentionally thin; they centralize options and future cross-cutting policies (debug flags, logging discipline).
- Error handling uses `PlatformException` catch at the UI boundary.

## 5. SDK architecture (by SDK)

This section documents the runtime layers and method-channel contract for each SDK.

### 5.1 Barcode/QR SDK (`flutter_barcode_qr_scanner/`)

**Channel:** `flutter_barcode_qr_scanner`

**Dart layers**

- Public API: `lib/flutter_barcode_qr_scanner.dart`
- Platform interface: `lib/flutter_barcode_qr_scanner_platform_interface.dart`
- Method channel: `lib/flutter_barcode_qr_scanner_method_channel.dart`

**Native layers**

- Android:
  - Plugin: `android/src/main/kotlin/.../FlutterBarcodeQrScannerPlugin.kt`
  - UI: `android/src/main/kotlin/.../SimpleScanActivity.kt`
  - Dependency: ZXing Embedded
- iOS:
  - Plugin/UI: `ios/Classes/FlutterBarcodeQrScannerPlugin.swift` (includes a custom scanner view controller)

**Method contract**

- `getPlatformVersion` -> `String`
- `scan` args: `{ formats?: List<String> }`
- `scan` returns:
  - `null` on cancel/permission denied
  - `{ value: String, type: String }` on success

**Key implementation behaviors**

- Android requests `CAMERA` permission inside `SimpleScanActivity`.
- iOS requests camera permission via `AVCaptureDevice`.

### 5.2 Credit card SDK (`flutter_credit_card_scanner/`)

**Channel:** `flutter_credit_card_scanner`

**Dart layers**

- Public API: `lib/flutter_credit_card_scanner.dart`
- Platform interface: `lib/flutter_credit_card_scanner_platform_interface.dart`
- Method channel: `lib/flutter_credit_card_scanner_method_channel.dart`

**Native layers**

- Android:
  - Plugin: `android/src/main/kotlin/.../FlutterCreditCardScannerPlugin.kt`
  - UI: `android/src/main/kotlin/.../CardScanActivity.kt`
  - Camera: CameraX
  - OCR: ML Kit Text Recognition
  - Optional edge/quad overlay: pluggable edge detector (OpenCV if present, OCR fallback otherwise)
- iOS:
  - Plugin/UI: `ios/Classes/FlutterCreditCardScannerPlugin.swift`
  - iOS 16+: VisionKit DataScanner (live)
  - Fallback: document camera capture + OCR via Vision

**Method contract**

- `getPlatformVersion` -> `String`
- `scanCard` args include:
  - `scanExpiry: bool`
  - `scanCardholderName: bool`
  - `restrictBrand: String?`
  - `timeoutMs: int?`
  - `debug: bool`
  - `showDetectedQuad: bool`
  - `cropToGuide: bool`
  - `consensusRequired: int`
  - `stabilityRequired: int`
- `scanCard` returns:
  - `null` on cancel/permission denied
  - map keys: `cardNumber`, `expiryMonth`, `expiryYear`, `cardholderName`, `cardBrand`

**Error codes (native -> Dart)**

- `ALREADY_ACTIVE`, `NO_ACTIVITY`
- `TIMEOUT`
- `SCAN_ERROR`

### 5.3 ID card SDK (`flutter_id_scanner/`)

**Channel:** `flutter_id_scanner`

**Dart layers**

- Public API: `lib/flutter_id_scanner.dart`
  - Orchestrates a **two-step capture** (front then back)
  - Performs OCR in Dart (via `google_mlkit_text_recognition`)
  - Parses recognized text into `IdCardData`
- Platform interface + method channel: `scanDocument(options)`

**Native layers**

- Android:
  - Capture: ML Kit Document Scanner (`GmsDocumentScanning`)
  - Copies returned `content://` URIs into app cache and returns file paths
- iOS:
  - Capture: VisionKit `VNDocumentCameraViewController`
  - Saves JPEGs into a temporary directory and returns file paths

**Method contract**

- `scanDocument` args:
  - `pageLimit: int` (clamped 1..10)
  - `allowGalleryImport: bool` (Android supports it; iOS implementation currently ignores this)
- `scanDocument` returns:
  - `null` on cancel
  - `{ imagePaths: List<String>, pdfPath?: String }` on Android
  - `{ imagePaths: List<String> }` on iOS

**Design note**

- The ID SDK is split: **native capture** + **Dart OCR/parsing**. This makes parsing easier to iterate without changing native code.

### 5.4 Passport SDK (`flutter_passport_scanner/`)

**Channel:** `flutter_passport_scanner`

**Dart layers**

- Public API: `lib/flutter_passport_scanner.dart`
  - Calls native capture: `scanPassport(options)`
  - Optionally runs OCR in Dart on the first image
  - Extracts + parses TD3 MRZ via `MrzParser`

**Native layers**

- Android:
  - Capture: ML Kit Document Scanner
  - Returns image paths + optional PDF path
- iOS:
  - Capture: VisionKit VNDocumentCamera
  - Returns image paths

**Method contract**

- `scanPassport` args:
  - `pageLimit: int` (clamped 1..10)
  - `allowGalleryImport: bool` (Android supports it; iOS implementation currently ignores this)
  - `performOcr: bool` (used by Dart only)
- `scanPassport` returns:
  - `null` on cancel
  - `{ imagePaths: List<String>, pdfPath?: String }` (Android)
  - `{ imagePaths: List<String> }` (iOS)

**MRZ pipeline (Dart)**

- OCR: `google_mlkit_text_recognition`
- MRZ extraction: robust line extraction + reconstruction
- Validation: ICAO 9303 check digits, with error reporting

## 6. Cross-cutting concerns

### 6.1 Permissions

- All SDKs rely on camera.
- Android: camera permission is declared in each plugin manifest. Runtime requests are handled by the native UI flow (barcode/credit card) or the document scanner UI (ID/passport).
- iOS: host apps must provide `NSCameraUsageDescription`.

### 6.2 Data and storage

- Barcode: returns decoded string; no image files returned.
- Credit card: returns structured text fields; no image files returned.
- ID/passport: return file paths to temporary/cached images (and PDF on Android).

**Storage policy (implicit today)**

- Image files are stored under cache/temp directories and are not automatically purged by the SDK.
- Host apps (including the demo app) should treat these paths as temporary and delete if needed.

### 6.3 Error handling model

- Cancellation typically returns `null`.
- Concurrency is guarded by `pendingResult` in native plugins (`ALREADY_ACTIVE`).
- Presentation failures may return `NO_ACTIVITY` (Android) or `NO_VIEW` (iOS).

### 6.4 Privacy and compliance

- All scanning is on-device.
- Credit card scanning explicitly does not support CVV.
- Logging:
  - Credit card Android implementation supports a `debug` option; this must remain **off by default** in production.

## 7. Build, run, and test topology

### 7.1 Local development entrypoints

There are two common workflows:

1. **Demo app workflow** (recommended):
   - Run `adaire_sdk_app` which depends on plugins via path dependencies.
2. **Per-plugin workflow**:
   - Use each plugin’s `example/` app for isolated testing.

### 7.2 Commands

**Demo app**

```bash
cd adaire_sdk_app
flutter pub get
flutter run
```

**Dart tests (per package)**

```bash
cd <package>
flutter test
```

**Android native unit tests (where present)**

Some plugins do not include a Gradle wrapper in their own `android/` folder.
Use the corresponding `example/android` wrapper for that plugin.

Example (barcode plugin):

```bat
cd flutter_barcode_qr_scanner\example\android
gradlew.bat testDebugUnitTest
```

## 8. Known gaps / inconsistencies (current state)

- Package namespaces differ across plugins:
  - Barcode/Credit card use `com.adaireTech...`
  - ID/Passport use `com.example...`
  This is not a runtime blocker but is a maintainability/publishing concern.
- ID/Passport `allowGalleryImport` is supported on Android but not currently wired on iOS.
- Passport plugin README is minimal (developer docs exist for barcode plugin only).

## 9. Extension points and evolution

- Add new scanning SDKs by following the established plugin pattern:
  - Dart API + platform interface + method channel + native UI
- Prefer moving fast-iterating logic to Dart when possible (as done in ID/passport OCR parsing).
- Standardize error codes across plugins (`ALREADY_ACTIVE`, `NO_ACTIVITY`/`NO_VIEW`, `SCAN_ERROR`, `TIMEOUT`) and document them.

## 10. Appendix: Method channels summary

| SDK | Channel | Primary methods |
|---|---|---|
| Barcode/QR | `flutter_barcode_qr_scanner` | `scan`, `getPlatformVersion` |
| Credit Card | `flutter_credit_card_scanner` | `scanCard`, `getPlatformVersion` |
| ID | `flutter_id_scanner` | `scanDocument`, `getPlatformVersion` |
| Passport | `flutter_passport_scanner` | `scanPassport`, `getPlatformVersion` |
