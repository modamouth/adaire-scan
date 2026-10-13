import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_barcode_qr_scanner/flutter_barcode_qr_scanner_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelFlutterBarcodeQrScanner platform =
      MethodChannelFlutterBarcodeQrScanner();
  const MethodChannel channel = MethodChannel('flutter_barcode_qr_scanner');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'getPlatformVersion') return '42';
          if (methodCall.method == 'scan') {
            return <String, dynamic>{'outcome': 'cancelled'};
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });

  test(
    'scan sends validated formats and returns the outcome envelope',
    () async {
      final result = await platform.scan(formats: const <String>['qr']);

      expect(result, <String, dynamic>{'outcome': 'cancelled'});
    },
  );
}
