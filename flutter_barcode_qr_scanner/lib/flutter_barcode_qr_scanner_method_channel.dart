import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_barcode_qr_scanner_platform_interface.dart';

/// An implementation of [FlutterBarcodeQrScannerPlatform] that uses method channels.
class MethodChannelFlutterBarcodeQrScanner
    extends FlutterBarcodeQrScannerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_barcode_qr_scanner');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<Map<String, dynamic>> scan({required List<String> formats}) async {
    final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'scan',
      <String, dynamic>{'formats': formats},
    );
    if (result == null) {
      return const <String, dynamic>{
        'outcome': 'failure',
        'diagnosticCode': 'malformed_native_result',
      };
    }
    return result.map((key, value) => MapEntry(key.toString(), value));
  }
}
