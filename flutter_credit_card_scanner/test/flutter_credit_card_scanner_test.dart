import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_credit_card_scanner/flutter_credit_card_scanner.dart';
import 'package:flutter_credit_card_scanner/flutter_credit_card_scanner_platform_interface.dart';
import 'package:flutter_credit_card_scanner/flutter_credit_card_scanner_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterCreditCardScannerPlatform
    with MockPlatformInterfaceMixin
    implements FlutterCreditCardScannerPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<Map<String, dynamic>?> scanCard(Map<String, Object?> options) async {
    return null;
  }
}

void main() {
  final FlutterCreditCardScannerPlatform initialPlatform = FlutterCreditCardScannerPlatform.instance;

  test('$MethodChannelFlutterCreditCardScanner is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterCreditCardScanner>());
  });

  test('getPlatformVersion', () async {
    FlutterCreditCardScanner flutterCreditCardScannerPlugin = FlutterCreditCardScanner();
    MockFlutterCreditCardScannerPlatform fakePlatform = MockFlutterCreditCardScannerPlatform();
    FlutterCreditCardScannerPlatform.instance = fakePlatform;

    expect(await flutterCreditCardScannerPlugin.getPlatformVersion(), '42');
  });
}
