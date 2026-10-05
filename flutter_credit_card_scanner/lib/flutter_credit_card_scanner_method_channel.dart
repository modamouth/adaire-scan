import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_credit_card_scanner_platform_interface.dart';

/// An implementation of [FlutterCreditCardScannerPlatform] that uses method channels.
class MethodChannelFlutterCreditCardScanner extends FlutterCreditCardScannerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_credit_card_scanner');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<Map<String, dynamic>?> scanCard(Map<String, Object?> options) async {
    final result = await methodChannel.invokeMapMethod<String, dynamic>('scanCard', options);
    return result;
  }
}
