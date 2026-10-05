import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_id_scanner_platform_interface.dart';

/// An implementation of [FlutterIdScannerPlatform] that uses method channels.
class MethodChannelFlutterIdScanner extends FlutterIdScannerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_id_scanner');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<Map<Object?, Object?>?> scanDocument(
    Map<String, Object?> options,
  ) async {
    final payload = await methodChannel.invokeMethod<Map<Object?, Object?>>(
      'scanDocument',
      options,
    );
    return payload;
  }
}
