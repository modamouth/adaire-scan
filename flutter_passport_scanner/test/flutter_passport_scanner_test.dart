import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_passport_scanner/flutter_passport_scanner.dart';
import 'package:flutter_passport_scanner/flutter_passport_scanner_platform_interface.dart';
import 'package:flutter_passport_scanner/flutter_passport_scanner_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterPassportScannerPlatform
    with MockPlatformInterfaceMixin
    implements FlutterPassportScannerPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlutterPassportScannerPlatform initialPlatform = FlutterPassportScannerPlatform.instance;

  test('$MethodChannelFlutterPassportScanner is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterPassportScanner>());
  });

  test('getPlatformVersion', () async {
    FlutterPassportScanner flutterPassportScannerPlugin = FlutterPassportScanner();
    MockFlutterPassportScannerPlatform fakePlatform = MockFlutterPassportScannerPlatform();
    FlutterPassportScannerPlatform.instance = fakePlatform;

    expect(await flutterPassportScannerPlugin.getPlatformVersion(), '42');
  });
}
