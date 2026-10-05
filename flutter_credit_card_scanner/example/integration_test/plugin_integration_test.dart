// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_credit_card_scanner/flutter_credit_card_scanner.dart';

void main() {
  // Use the standard test binding instead of integration_test to keep
  // these tests runnable even if the Flutter SDK lacks integration_test.
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('flutter_credit_card_scanner');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      switch (call.method) {
        case 'getPlatformVersion':
          return 'test-os 1.0';
        case 'scanCard':
          return <String, dynamic>{
            'cardNumber': '4111111111111111',
            'expiryMonth': 12,
            'expiryYear': 2030,
            'cardholderName': 'Test User',
            'cardBrand': 'visa',
          };
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('getPlatformVersion test', (WidgetTester tester) async {
    final FlutterCreditCardScanner plugin = FlutterCreditCardScanner();
    final String? version = await plugin.getPlatformVersion();
    expect(version?.isNotEmpty, true);
  });

  testWidgets('scanCard returns data', (WidgetTester tester) async {
    final scanner = FlutterCreditCardScanner();
    final result = await scanner.scanCard();
    expect(result, isNotNull);
    expect(result!.cardNumber, '4111111111111111');
    expect(result.expiryMonth, 12);
    expect(result.expiryYear, 2030);
    expect(result.cardBrand, 'visa');
  });
}
