# Adaire SDK Suite — Requirements (Demo App + SDKs)

**Document type:** Product/Engineering requirements (high-level)

**Audience:** SDK engineers, mobile engineers, QA, product owners

**Last updated:** 2026-02-18

## 1. High-level overview

This repository contains:

- A **demo application** (Flutter app) used as an internal showcase and test harness.
- A set of **Flutter SDKs (plugins)** providing native scanning/capture capabilities:
  - Barcode/QR scanning
  - Credit card scanning
  - ID card scanning
  - Passport scanning (MRZ extraction)

The primary goals are:

- Provide **reusable SDKs** that integrate cleanly into Flutter apps.
- Provide an internal **demo app** that exercises SDK flows end-to-end for manual QA, sales demos, and developer debugging.

## 2. Goals and non-goals

### 2.1 Goals

- Each SDK MUST expose a **small, stable Dart API** that returns structured results.
- Each SDK MUST provide a **native UI** for capture/scan (full-screen) and return the first successful result.
- The demo app MUST provide **one-tap access** to each supported SDK flow and display results.
- All scanning/capture MUST be **on-device** (no network required to function).

### 2.2 Non-goals

- The demo app is NOT intended to be a consumer-ready product (no user accounts, no backend dependencies).
- The SDKs are NOT required to support desktop/web platforms unless explicitly added.
- The SDKs are NOT required to provide deep UI customization at this stage (unless a specific SDK already supports it).

## 3. Repository components

### 3.1 Demo application: `adaire_sdk_app/`

**Purpose**

- Acts as a **showcase** of available Adaire SDK capabilities.
- Serves as a **manual test harness** for validating SDK changes during development.
- Provides a **single place** where QA/product can verify common flows.

**Primary user personas**

- SDK developer validating a change.
- QA tester verifying a release.
- Product/sales demo operator.

**Core UX**

- The home screen MUST present a **grid/list of SDK features**.
- Each feature tile MUST launch its respective SDK flow.
- Results MUST be shown in a clear, copyable text summary (e.g., dialog).

**Feature coverage (current)**

- Barcode / QR Scanner
- Credit Card Scanner
- Passport Scanner
- ID Scanner
- Placeholders shown as “Coming soon”:
  - Fingerprint Scanner
  - Face Recognition

**Functional requirements**

- The demo app MUST:
  - Start successfully on Android and iOS.
  - Provide actions to invoke each implemented SDK.
  - Handle cancellation gracefully (show “No data returned.” or equivalent).
  - Handle platform errors gracefully (show error message).
  - Avoid logging sensitive values by default.

**Non-functional requirements**

- The demo app SHOULD:
  - Be stable across app background/foreground transitions.
  - Avoid retaining captured images longer than necessary for the session.
  - Use Material 3 styling and maintain a consistent look.

**Configuration requirements**

- The app MUST support a build-time mode flag:
  - `--dart-define=APP_MODE=dev` (default)
  - `--dart-define=APP_MODE=production`

**Build/run requirements**

- From `adaire_sdk_app/` the following MUST work for contributors:
  - `flutter pub get`
  - `flutter run`
  - `flutter test` (where tests exist)

**Platform requirements**

- iOS:
  - The app MUST declare `NSCameraUsageDescription`.
- Android:
  - Camera runtime permissions MUST be handled by the underlying SDK UIs.

### 3.2 SDKs (Flutter plugins)

The SDKs in this repo are Flutter plugins that:

- Provide a Dart API in `lib/`.
- Implement native platform logic in `android/` (Kotlin) and `ios/` (Swift).
- Typically include an `example/` app for isolated testing.

#### Common requirements across all SDKs

**Platform support**

- Each SDK MUST clearly define supported platforms (Android/iOS) and minimum OS/SDK versions.
- If a platform is not implemented (web/desktop), the SDK MUST fail predictably (documentation + consistent errors).

**Permissions**

- Any SDK requiring camera access MUST:
  - Declare/request camera permission as needed.
  - Return `null` (or a documented equivalent) if the user denies permission.

**Data handling and privacy**

- SDKs MUST process data on-device.
- SDKs MUST NOT transmit captured images or extracted values to the network.
- SDKs MUST treat outputs as potentially sensitive (PII/PCI) and MUST NOT log them by default.

**Error model**

- SDKs MUST define a consistent cancellation model (typically returning `null`).
- SDKs SHOULD use `PlatformException` for unexpected failures with stable error codes.
- SDKs MUST reject invalid concurrent usage (for example, scanning twice simultaneously) with a deterministic error.

**Developer experience**

- Each SDK MUST provide:
  - A clear README (developer-focused, including how to run example apps).
  - A minimal set of automated tests (Dart unit tests at minimum).

## 4. SDK-specific requirements

### 4.1 Barcode/QR SDK: `flutter_barcode_qr_scanner/`

**Purpose**

- Provide a fast, full-screen native barcode & QR scanner.

**Key behaviors**

- The SDK MUST:
  - Present a full-screen scanner UI.
  - Return the **first** detected code.
  - Return both:
    - `value` (decoded payload)
    - `type` (normalized barcode format)
  - Support optional format filtering.
  - Provide best-effort torch/flash controls.

**Technical constraints**

- Android implementation uses ZXing Embedded.
- iOS implementation uses AVFoundation.

**Outputs**

- `ScanResult(value: String, type: BarcodeFormat)`

### 4.2 Credit card SDK: `flutter_credit_card_scanner/`

**Purpose**

- Provide camera-based credit card scanning that returns a sanitized PAN and metadata.

**Key behaviors**

- The SDK MUST:
  - Present a capture/scanning UI.
  - Return a Luhn-validated primary account number (PAN).
  - Detect card brand when possible.
  - Support optional expiry and cardholder name extraction.
  - Explicitly NOT support CVV scanning.

**Configuration options (high-level)**

- The SDK SHOULD support tuning of stability/consensus thresholds to reduce false positives.

**Outputs**

- `CreditCardScanResult` with:
  - `cardNumber` (required)
  - `cardBrand` (optional)
  - `expiryMonth` / `expiryYear` (optional)
  - `cardholderName` (optional)

**Security requirements**

- The SDK MUST:
  - Avoid logging PAN.
  - Keep PAN in memory only as long as necessary.

### 4.3 ID card SDK: `flutter_id_scanner/`

**Purpose**

- Provide a two-step ID capture flow (front then back), with on-device OCR and heuristic field extraction.

**Key behaviors**

- The SDK MUST:
  - Capture exactly two images per session (front then back).
  - Optionally perform OCR on each side.
  - Extract common ID fields best-effort from recognized text.
  - Provide progress callbacks so host apps can guide the user (e.g., “Capture the front”).

**Outputs**

- `IdScanResult` containing:
  - front/back image paths
  - raw OCR text (optional)
  - parsed `IdCardData` fields (best-effort)

**Field extraction requirements**

- Extraction MUST be heuristic and resilient to:
  - OCR noise
  - minor layout changes
- Extraction SHOULD support common fields such as:
  - ID number, surname, first names, DOB, citizenship/nationality, gender, height, date of issue

### 4.4 Passport SDK: `flutter_passport_scanner/`

**Purpose**

- Provide camera-based passport capture and MRZ extraction/parsing.

**Key behaviors**

- The SDK MUST:
  - Capture passport data page image(s) via a document scanner UI.
  - Optionally run OCR.
  - Attempt to extract a TD3 MRZ (ICAO 9303) from OCR results.
  - Validate MRZ check digits and return validation errors.

**Outputs**

- `PassportScanResult` containing:
  - `imagePaths` (captured images)
  - `pdfPath` (optional)
  - `mrz` (`PassportMrz`, optional)
  - `rawOcrText` (optional)

**MRZ parsing requirements**

- Parser MUST:
  - Sanitize to `[A-Z0-9<]`.
  - Be robust to split lines / partial OCR fragments.
  - Validate check digits and provide error list.

## 5. Quality, compliance, and operational requirements

### 5.1 Testing requirements

- Each SDK MUST have:
  - Dart unit tests for platform interface / method channel wiring.
  - A runnable `example/` app for manual QA.
- The suite SHOULD have:
  - Manual QA scripts/checklists for each SDK flow (scan success + cancel + permission denied).

### 5.2 Performance requirements

- SDKs SHOULD:
  - Return results quickly (first good detection).
  - Avoid heavy allocations on the Dart UI thread.
  - Avoid repeated initialization of OCR engines where possible.

### 5.3 Security and privacy requirements

- SDKs MUST be safe-by-default:
  - No sensitive logs
  - No network calls
  - No persistent storage of scans unless explicitly requested by the host app

### 5.4 Release requirements

- Each release MUST include:
  - Updated package version (`pubspec.yaml`).
  - Updated `CHANGELOG.md` with meaningful notes.
  - Smoke test results for Android and iOS using the demo app.

## 6. Open questions / TBD

- Passport SDK README is currently minimal; ensure it is expanded to match the level of the barcode SDK developer docs.
- Define the required iOS privacy manifest (`PrivacyInfo.xcprivacy`) bundling strategy for each plugin.
- Define whether the demo app should support exporting results for QA (e.g., share sheet) while still protecting sensitive data.
