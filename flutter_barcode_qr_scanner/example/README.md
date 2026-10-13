# Flutter Barcode/QR Scanner Android Example

Demonstrates the private Android candidate for QR, EAN-13, and Code 128.

The example handles typed success, cancellation, permission-denied, unavailable, busy, and failure outcomes. It does not log decoded values. Use synthetic fixtures only.

## Physical-test controls

The example includes bounded controls for the approved Android verification matrix:

- all approved formats or QR-only, EAN-13-only, and Code 128-only profiles;
- a single scan action for format, cancellation, permission, lifecycle, and repeated-scan checks;
- a concurrent invocation action that passes only when exactly one invocation returns `busy`;
- session counters and outcome names that do not include decoded values;
- an explicit result area and a control to clear the displayed payload; and
- on-device guidance for filtering, permission recovery, lifecycle, and evidence hygiene.

For a negative filtering check, select **QR only**, present a synthetic EAN-13 or Code 128 fixture, confirm it is not accepted, and close the scanner. Do not record decoded values in logs, screenshots, or review evidence.

Run on an authorised Android device:

```bash
flutter pub get
flutter run
```

This example is not evidence of iOS support, broad Android compatibility, production readiness, or permission to distribute the package.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
