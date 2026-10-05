# Adaire SDK Suite — External Developer Integration Guide

**Audience:** external developers integrating Adaire SDKs into their Flutter applications

**Scope:** integrating these Flutter plugins into a host Flutter app:

- `flutter_barcode_qr_scanner`
- `flutter_credit_card_scanner`
- `flutter_id_scanner`
- `flutter_passport_scanner`

**Last updated:** 2026-02-18

---

## 1. What you get (high level)

All Adaire SDKs in this repo are Flutter plugins that:

- present a **native full-screen** scan/capture UI
- perform scanning/recognition **on-device**
- return a **structured result** back to Dart
- return **`null`** when the user cancels or permission is denied

These SDKs are designed to be integrated into your app’s normal UX (buttons, flows, etc.) without requiring you to build camera preview UIs yourself.

---

## 2. Prerequisites

### 2.1 Flutter / Dart

- Flutter installed and able to build for Android and iOS.
- Your project should use a modern Flutter/Dart toolchain (these SDKs are authored with Dart 3.x).

### 2.2 Devices

Camera-based features are best validated on real devices:

- Android device (recommended) or emulator with camera support
- iOS device (recommended). Some VisionKit features are unavailable on simulator.

---

## 3. Installing the SDKs

You can consume the SDKs via:

- **Pub** (recommended for external apps) if/when published, or
- **Git/path** dependency if you’re consuming the source directly (common for private distribution)

### 3.1 Pub dependency (typical)

In your `pubspec.yaml`:

```yaml
dependencies:
  flutter_barcode_qr_scanner: ^0.0.2
  flutter_credit_card_scanner: ^0.0.1
  flutter_id_scanner: ^0.0.1
  flutter_passport_scanner: ^0.0.1
```

Then:

```bash
flutter pub get
```

### 3.2 Path dependency (if you vendor the SDK source)

```yaml
dependencies:
  flutter_barcode_qr_scanner:
    path: ../flutter_barcode_qr_scanner
  flutter_credit_card_scanner:
    path: ../flutter_credit_card_scanner
  flutter_id_scanner:
    path: ../flutter_id_scanner
  flutter_passport_scanner:
    path: ../flutter_passport_scanner
```

---

## 4. Platform setup (required)

### 4.1 iOS: camera usage description

Add this key to your app’s `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required to scan documents.</string>
```

If this is missing, iOS will crash/deny permission and scans will not work.

### 4.2 Android: camera permission

Each plugin declares `android.permission.CAMERA` in its plugin manifest.

- Your app does not usually need to declare camera permission again.
- Camera permission is requested at runtime by the SDK’s native UI flows.

### 4.3 Platform availability notes

- Barcode/QR + Credit Card SDKs are implemented for Android and iOS.
- ID + Passport SDKs rely on document scanner capabilities:
  - Android: ML Kit Document Scanner (requires Google Play services on device)
  - iOS: VisionKit document camera (device support varies)

---

## 5. Common integration patterns

### 5.1 Handle `null` results

Across these SDKs, `null` typically means:

- user cancelled
- permission denied
- scanner UI could not be presented

You should treat `null` as “no result” rather than an error.

### 5.2 Handle platform errors (`PlatformException`)

Unexpected failures are delivered as `PlatformException` with a stable `code`.

Common codes you may encounter:

- `ALREADY_ACTIVE`: a scan is already in progress (avoid double-taps)
- `NO_ACTIVITY` (Android): SDK could not access a foreground Activity
- `NO_VIEW` (iOS): SDK could not find a view controller to present
- `SCAN_ERROR`: scanning pipeline failed
- `TIMEOUT` (credit card): scan timed out

Recommended handling:

- Disable the scan button while a scan is in progress.
- Show a user-friendly error message for exceptions.

---

## 6. SDK: Barcode / QR (`flutter_barcode_qr_scanner`)

### 6.1 What it does

- Presents a full-screen scanner UI
- Returns the first detected barcode/QR code

### 6.2 Usage

```dart
import 'package:flutter/services.dart';
import 'package:flutter_barcode_qr_scanner/flutter_barcode_qr_scanner.dart';

final scanner = FlutterBarcodeQrScanner();

Future<void> scanBarcode() async {
  try {
    final result = await scanner.scan(
      // Optional filtering:
      // formats: [BarcodeFormat.qr, BarcodeFormat.code128],
    );

    if (result == null) {
      // Cancelled/permission denied
      return;
    }

    // Use result.value and result.type
    // Example: print(result.type.name);
  } on PlatformException catch (e) {
    // Handle errors by code/message
    // Example: e.code == 'ALREADY_ACTIVE'
    rethrow;
  }
}
```

### 6.3 Returned types

- `ScanResult`
  - `value: String`
  - `type: BarcodeFormat`

### 6.4 Format filtering

You can pass `formats: List<BarcodeFormat>`.

Note: iOS format support may be more limited than Android for some formats. If strict cross-platform filtering is critical, validate your chosen format list on both platforms.

---

## 7. SDK: Credit Card (`flutter_credit_card_scanner`)

### 7.1 What it does

- Presents a full-screen card scanning UI
- Extracts a Luhn-valid PAN and returns brand and optionally expiry/name

Security note:

- CVV scanning is intentionally not supported.

### 7.2 Usage

```dart
import 'package:flutter/services.dart';
import 'package:flutter_credit_card_scanner/flutter_credit_card_scanner.dart';

final scanner = FlutterCreditCardScanner();

Future<void> scanCard() async {
  try {
    final result = await scanner.scanCard(
      scanExpiry: true,
      scanCardholderName: false,
      restrictBrand: null, // e.g. 'visa'
      timeoutMs: null,
      debug: false,
      showDetectedQuad: false,
      cropToGuide: false,
      consensusRequired: 3,
      stabilityRequired: 2,
    );

    if (result == null) {
      return; // cancelled
    }

    // result.cardNumber (PAN), result.cardBrand, result.expiryMonth/year, result.cardholderName
  } on PlatformException catch (e) {
    // TIMEOUT, SCAN_ERROR, ALREADY_ACTIVE, ...
    rethrow;
  }
}
```

### 7.3 Returned types

- `CreditCardScanResult`
  - `cardNumber: String` (Luhn-validated)
  - `cardBrand: String?` (`visa`, `mastercard`, `amex`, `discover`, `diners`, `jcb`, `unionpay`)
  - `expiryMonth: int?`, `expiryYear: int?`
  - `cardholderName: String?`

### 7.4 Platform behavior

- Android: CameraX + ML Kit text recognition; additional stability/consensus logic to reduce false positives.
- iOS:
  - iOS 16+: VisionKit DataScanner when available
  - fallback: document capture + OCR

---

## 8. SDK: ID Card (`flutter_id_scanner`)

### 8.1 What it does

- Two-step capture: **front**, then **back**
- Performs on-device OCR and best-effort parsing of common ID fields

### 8.2 Usage (with progress callback)

```dart
import 'package:flutter/services.dart';
import 'package:flutter_id_scanner/flutter_id_scanner.dart';

final scanner = FlutterIdScanner();

Future<void> scanId() async {
  try {
    final result = await scanner.scanIdCard(
      options: const IdScanOptions(
        allowGalleryImport: false,
        performOcr: true,
        returnPartialOnCancel: false,
      ),
      onProgress: (side) {
        // side == IdCaptureSide.front or IdCaptureSide.back
        // Update your UI prompt.
      },
    );

    if (result == null) return;

    // result.data contains best-effort parsed fields
    // result.frontImagePath/backImagePath contain captured images
  } on PlatformException catch (e) {
    rethrow;
  }
}
```

### 8.3 Returned types

- `IdScanResult`
  - `frontImagePath: String`
  - `backImagePath: String?`
  - `frontRawOcrText: String?`, `backRawOcrText: String?`
  - `data: IdCardData`

`IdCardData` is best-effort:

- `idNumber`, `surname`, `firstNames`, `citizenship`, `placeOfBirth`, `gender`
- `dateOfBirth`, `dateOfIssue` (as `ParsedDate`)
- `heightMeters`

---

## 9. SDK: Passport (`flutter_passport_scanner`)

### 9.1 What it does

- Captures passport data page image(s)
- Optionally runs OCR and attempts to extract a **TD3 MRZ** (ICAO 9303)
- Returns MRZ validation status and error list

### 9.2 Usage

```dart
import 'package:flutter/services.dart';
import 'package:flutter_passport_scanner/flutter_passport_scanner.dart';

final scanner = FlutterPassportScanner();

Future<void> scanPassport() async {
  try {
    final result = await scanner.scanPassport(
      options: const PassportScanOptions(
        pageLimit: 1,
        allowGalleryImport: false,
        performOcr: true,
      ),
    );

    if (result == null) return;

    final mrz = result.mrz;
    if (mrz == null) {
      // MRZ not found
      return;
    }

    // mrz.isValid indicates check-digit validation
    // mrz.errors contains validation issues
  } on PlatformException catch (e) {
    rethrow;
  }
}
```

### 9.3 Returned types

- `PassportScanResult`
  - `imagePaths: List<String>`
  - `pdfPath: String?` (Android only)
  - `mrz: PassportMrz?`
  - `rawOcrText: String?`

`PassportMrz` includes:

- `passportNumber`, `nationality`, `givenNames`, `surnames`, `sex`
- `dateOfBirth`, `dateOfExpiry` (as `DateParts?`)
- `mrzLine1`, `mrzLine2`
- `isValid: bool`, `errors: List<String>`

---

## 10. Privacy, security, and production guidance

### 10.1 Sensitive data handling

These SDKs may return highly sensitive information (PII and PCI). You should:

- Avoid logging raw results (PAN, MRZ lines, OCR text)
- Treat image file paths as sensitive and temporary
- Never upload scan results unless your compliance/privacy program explicitly allows it

### 10.2 UX and safety

- Always explain why camera permission is needed.
- Provide clear cancel/back paths.
- Consider gating credit-card scanning behind explicit user consent.

---

## 11. Troubleshooting

### 11.1 Scans always return `null`

- Verify camera permission was granted.
- Verify `NSCameraUsageDescription` exists on iOS.
- Test on a real device.

### 11.2 `PlatformException(ALREADY_ACTIVE, ...)`

- Disable the scan button until the `Future` completes.

### 11.3 Android document scanning fails

- Ensure the device has Google Play services and is not missing required components.
- Test on a physical device if possible.

---

## 12. Reference implementation

This repo includes an internal demo app that exercises all SDKs:

- `adaire_sdk_app/`

Even for external integration work, it’s useful as an end-to-end reference for expected behaviors and result shapes.
