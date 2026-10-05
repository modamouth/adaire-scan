# flutter_barcode_qr_scanner

Native barcode and QR code scanner for Flutter that returns both the decoded value and the barcode type.

Android uses Google Play Services Code Scanner; iOS uses AVFoundation. No custom view setup required â€” a full-screen native UI is presented and the first detected code is returned.

## Install

Add to your `pubspec.yaml`:

```
flutter_barcode_qr_scanner:
  path: ../flutter_barcode_qr_scanner
```

## Platform setup

- Android:
  - Camera permission is declared by the plugin. Ensure your app targets SDK where runtime permissions are handled (the scanner UI requests camera permission as needed).
  - Requires Google Play Services on the device.

- iOS:
  - Add `NSCameraUsageDescription` to your app `Info.plist`:
    - Key: `NSCameraUsageDescription`
    - Value: `Camera access is required to scan barcodes and QR codes.`

## Usage

```
import 'package:flutter_barcode_qr_scanner/flutter_barcode_qr_scanner.dart';

final scanner = FlutterBarcodeQrScanner();
final result = await scanner.scan();
if (result != null) {
  print('Type: ${result.type.name}');
  print('Value: ${result.value}');
}

// Filter by specific formats (optional)
await scanner.scan(formats: [
  BarcodeFormat.qr,
  BarcodeFormat.code128,
]);
```

## Returned types

Types are normalized across platforms: `qr`, `ean13`, `ean8`, `code128`, `code39`, `code93`, `upca`, `upce`, `itf`, `codabar`, `datamatrix`, `aztec`, `pdf417`.

## Example app

See `example/lib/main.dart` for a button-driven demo that displays the scan result.


