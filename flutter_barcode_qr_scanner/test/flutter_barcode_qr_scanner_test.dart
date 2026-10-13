import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_barcode_qr_scanner/flutter_barcode_qr_scanner.dart';
import 'package:flutter_barcode_qr_scanner/flutter_barcode_qr_scanner_platform_interface.dart';
import 'package:flutter_barcode_qr_scanner/flutter_barcode_qr_scanner_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterBarcodeQrScannerPlatform
    with MockPlatformInterfaceMixin
    implements FlutterBarcodeQrScannerPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<Map<String, dynamic>?> scan({List<String>? formats}) =>
      Future.value(null);
}

void main() {
  final FlutterBarcodeQrScannerPlatform initialPlatform =
      FlutterBarcodeQrScannerPlatform.instance;

  test('$MethodChannelFlutterBarcodeQrScanner is the default instance', () {
    expect(
      initialPlatform,
      isInstanceOf<MethodChannelFlutterBarcodeQrScanner>(),
    );
  });

  test('getPlatformVersion', () async {
    FlutterBarcodeQrScanner flutterBarcodeQrScannerPlugin =
        FlutterBarcodeQrScanner();
    MockFlutterBarcodeQrScannerPlatform fakePlatform =
        MockFlutterBarcodeQrScannerPlatform();
    FlutterBarcodeQrScannerPlatform.instance = fakePlatform;

    expect(await flutterBarcodeQrScannerPlugin.getPlatformVersion(), '42');
  });

  test('scan delegates to the platform implementation', () async {
    final flutterBarcodeQrScannerPlugin = FlutterBarcodeQrScanner();
    FlutterBarcodeQrScannerPlatform.instance =
        MockFlutterBarcodeQrScannerPlatform();

    expect(await flutterBarcodeQrScannerPlugin.scan(), isNull);
  });
}
