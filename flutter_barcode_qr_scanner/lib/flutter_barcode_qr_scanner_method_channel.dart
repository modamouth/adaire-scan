import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_barcode_qr_scanner_platform_interface.dart';

/// An implementation of [FlutterBarcodeQrScannerPlatform] that uses method channels.
class MethodChannelFlutterBarcodeQrScanner extends FlutterBarcodeQrScannerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_barcode_qr_scanner');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<Map<String, dynamic>?> scan({List<String>? formats}) async {
    final args = <String, dynamic>{};
    if (formats != null && formats.isNotEmpty) {
      args['formats'] = formats;
    }
    final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>?>('scan', args);
    if (result == null) return null;
    return result.map((key, value) => MapEntry(key.toString(), value));
  }
}
