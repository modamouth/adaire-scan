import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_barcode_qr_scanner/flutter_barcode_qr_scanner.dart';
import 'package:flutter_barcode_qr_scanner/flutter_barcode_qr_scanner_platform_interface.dart';
import 'package:flutter_barcode_qr_scanner/flutter_barcode_qr_scanner_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterBarcodeQrScannerPlatform
    with MockPlatformInterfaceMixin
    implements FlutterBarcodeQrScannerPlatform {
  MockFlutterBarcodeQrScannerPlatform({
    this.response = const <String, dynamic>{'outcome': 'cancelled'},
  });

  final Map<String, dynamic> response;
  List<String>? receivedFormats;
  int scanCount = 0;

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<Map<String, dynamic>> scan({required List<String> formats}) async {
    scanCount += 1;
    receivedFormats = formats;
    return response;
  }
}

void main() {
  final FlutterBarcodeQrScannerPlatform initialPlatform =
      FlutterBarcodeQrScannerPlatform.instance;

  tearDown(() {
    FlutterBarcodeQrScannerPlatform.instance = initialPlatform;
  });

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
    final fakePlatform = MockFlutterBarcodeQrScannerPlatform();
    FlutterBarcodeQrScannerPlatform.instance = fakePlatform;

    final outcome = await flutterBarcodeQrScannerPlugin.scan();

    expect(outcome.type, ScanOutcomeType.cancelled);
    expect(fakePlatform.receivedFormats, <String>['qr', 'ean13', 'code128']);
  });

  test('scan maps a strict successful native envelope', () async {
    final fakePlatform = MockFlutterBarcodeQrScannerPlatform(
      response: const <String, dynamic>{
        'outcome': 'success',
        'value': 'synthetic-fixture-01',
        'type': 'qr',
      },
    );
    FlutterBarcodeQrScannerPlatform.instance = fakePlatform;

    final outcome = await FlutterBarcodeQrScanner().scan(
      formats: <BarcodeFormat>[BarcodeFormat.qr, BarcodeFormat.qr],
    );

    expect(outcome.type, ScanOutcomeType.success);
    expect(outcome.result?.value, 'synthetic-fixture-01');
    expect(outcome.result?.type, BarcodeFormat.qr);
    expect(fakePlatform.receivedFormats, <String>['qr']);
  });

  test('scan maps every non-success terminal outcome', () {
    expect(
      ScanOutcome.fromMap(const <String, dynamic>{'outcome': 'cancelled'}).type,
      ScanOutcomeType.cancelled,
    );
    expect(
      ScanOutcome.fromMap(const <String, dynamic>{
        'outcome': 'permission_denied',
      }).type,
      ScanOutcomeType.permissionDenied,
    );
    expect(
      ScanOutcome.fromMap(const <String, dynamic>{
        'outcome': 'unavailable',
      }).type,
      ScanOutcomeType.unavailable,
    );
    expect(
      ScanOutcome.fromMap(const <String, dynamic>{'outcome': 'busy'}).type,
      ScanOutcomeType.busy,
    );
    expect(
      ScanOutcome.fromMap(const <String, dynamic>{'outcome': 'failure'}).type,
      ScanOutcomeType.failure,
    );
  });

  test('malformed success becomes a payload-free failure', () {
    final outcome = ScanOutcome.fromMap(const <String, dynamic>{
      'outcome': 'success',
      'value': 'synthetic-fixture-01',
      'type': 'unknown',
    });

    expect(outcome.type, ScanOutcomeType.failure);
    expect(outcome.result, isNull);
    expect(outcome.diagnosticCode, 'malformed_native_result');
  });

  test('unrecognised native diagnostic content is not retained', () {
    const payload = 'do-not-retain-this-value';
    final outcome = ScanOutcome.fromMap(const <String, dynamic>{
      'outcome': 'failure',
      'diagnosticCode': payload,
    });

    expect(outcome.diagnosticCode, 'native_failure');
    expect(outcome.toString(), isNot(contains(payload)));
  });

  test('empty and unsupported format requests do not launch', () async {
    final fakePlatform = MockFlutterBarcodeQrScannerPlatform();
    FlutterBarcodeQrScannerPlatform.instance = fakePlatform;

    final empty = await FlutterBarcodeQrScanner().scan(formats: const []);
    final unsupported = await FlutterBarcodeQrScanner().scan(
      formats: const <BarcodeFormat>[BarcodeFormat.pdf417],
    );

    expect(empty.diagnosticCode, 'invalid_formats');
    expect(unsupported.diagnosticCode, 'unsupported_format');
    expect(fakePlatform.scanCount, 0);
  });

  test('default stringification redacts decoded content', () {
    const payload = 'do-not-retain-this-value';
    const result = ScanResult(value: payload, type: BarcodeFormat.qr);
    const outcome = ScanOutcome.success(result);

    expect(result.toString(), isNot(contains(payload)));
    expect(outcome.toString(), isNot(contains(payload)));
  });
}
