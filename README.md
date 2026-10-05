# Adaire SDK Suite (Flutter) — Overview

This repository contains the **Adaire SDK suite** (four Flutter plugins) plus an **internal demo app** that serves as a QA harness and showcase.

## What’s in this repo

- Demo app: [adaire_sdk_app/](adaire_sdk_app/)
- SDK plugins:
  - Barcode/QR: [flutter_barcode_qr_scanner/](flutter_barcode_qr_scanner/)
  - Credit card: [flutter_credit_card_scanner/](flutter_credit_card_scanner/)
  - ID card: [flutter_id_scanner/](flutter_id_scanner/)
  - Passport: [flutter_passport_scanner/](flutter_passport_scanner/)

## Documentation index

Repo-level docs:

- Requirements: [REQUIREMENTS.md](REQUIREMENTS.md)
- System architecture: [SYSTEM_ARCHITECTURE.md](SYSTEM_ARCHITECTURE.md)
- Developer onboarding (internal): [DEVELOPER_ONBOARDING.md](DEVELOPER_ONBOARDING.md)
- External integration guide: [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md)

Per-SDK deep dives (recommended when developing the SDKs themselves):

- Barcode/QR SDK README: [flutter_barcode_qr_scanner/README.md](flutter_barcode_qr_scanner/README.md)
- Credit card SDK README: [flutter_credit_card_scanner/README.md](flutter_credit_card_scanner/README.md)
- ID card SDK README: [flutter_id_scanner/README.md](flutter_id_scanner/README.md)
- Passport SDK README: [flutter_passport_scanner/README.md](flutter_passport_scanner/README.md)

## Quickstart (run the demo app)

Prereqs:

- Flutter SDK (see each package’s `pubspec.yaml` for constraints)
- Android Studio (for Android) and/or Xcode (for iOS)

Run:

```bash
cd adaire_sdk_app
flutter pub get
flutter run
```

Notes:

- Camera-based SDKs are best validated on **real devices**.
- iOS requires `NSCameraUsageDescription` in the host app’s `Info.plist`.

## Quickstart (run a plugin in isolation)

Each plugin includes an `example/` app.

Example:

```bash
cd flutter_barcode_qr_scanner/example
flutter pub get
flutter run
```

## Testing

Dart tests per package:

```bash
cd <package>
flutter test
```

Android native unit tests (when present):

Some plugins do not include a Gradle wrapper in their own `android/` folder; use the plugin’s `example/android` wrapper instead.

```bat
cd <plugin>\example\android
gradlew.bat testDebugUnitTest
```

## Development principles (high level)

- Keep **method-channel contracts stable** (channel name, method names, argument keys, return shapes, error codes).
- Treat scan outputs as **sensitive** by default (avoid logging OCR text, PANs, MRZ).
- Prefer pushing fast-iterating logic to **Dart** where it makes sense (e.g., parsing), and keep native focused on capture/UI.

## Where to start

- New to the repo: read [DEVELOPER_ONBOARDING.md](DEVELOPER_ONBOARDING.md)
- Want system-level context: read [SYSTEM_ARCHITECTURE.md](SYSTEM_ARCHITECTURE.md)
- Working on a specific SDK: start with that plugin’s README (linked above)
