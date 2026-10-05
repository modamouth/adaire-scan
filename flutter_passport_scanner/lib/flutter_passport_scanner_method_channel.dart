import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_passport_scanner_platform_interface.dart';

/// An implementation of [FlutterPassportScannerPlatform] that uses method channels.
class MethodChannelFlutterPassportScanner extends FlutterPassportScannerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_passport_scanner');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<Map<String, Object?>?> scanPassport(Map<String, Object?> options) async {
    final payload = await methodChannel.invokeMapMethod<String, Object?>('scanPassport', options);
    return payload;
  }
}
