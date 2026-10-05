import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_id_scanner/flutter_id_scanner.dart';
import 'package:flutter_id_scanner/flutter_id_scanner_platform_interface.dart';
import 'package:flutter_id_scanner/flutter_id_scanner_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterIdScannerPlatform
    with MockPlatformInterfaceMixin
    implements FlutterIdScannerPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<Map<Object?, Object?>?> scanDocument(
    Map<String, Object?> options,
  ) async {
    return <Object?, Object?>{'imagePaths': <String>[], 'pdfPath': null};
  }
}

void main() {
  final FlutterIdScannerPlatform initialPlatform =
      FlutterIdScannerPlatform.instance;

  test('$MethodChannelFlutterIdScanner is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterIdScanner>());
  });

  test('getPlatformVersion', () async {
    FlutterIdScanner flutterIdScannerPlugin = FlutterIdScanner();
    MockFlutterIdScannerPlatform fakePlatform = MockFlutterIdScannerPlatform();
    FlutterIdScannerPlatform.instance = fakePlatform;

    expect(await flutterIdScannerPlugin.getPlatformVersion(), '42');
  });
}
