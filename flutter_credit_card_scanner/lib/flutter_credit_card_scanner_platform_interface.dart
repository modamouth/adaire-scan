import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_credit_card_scanner_method_channel.dart';

/// Platform interface for flutter_credit_card_scanner.
abstract class FlutterCreditCardScannerPlatform extends PlatformInterface {
  /// Constructs a FlutterCreditCardScannerPlatform.
  FlutterCreditCardScannerPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterCreditCardScannerPlatform _instance =
      MethodChannelFlutterCreditCardScanner();

  /// The default instance of [FlutterCreditCardScannerPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterCreditCardScanner].
  static FlutterCreditCardScannerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterCreditCardScannerPlatform]
  /// when they register themselves.
  static set instance(FlutterCreditCardScannerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  /// Launches a native credit card scanner UI and returns the extracted data.
  ///
  /// Implementations should present a camera-based scanner where possible.
  /// Returned map keys should include:
  /// - 'cardNumber' (String)
  /// - 'expiryMonth' (int)
  /// - 'expiryYear' (int)
  /// - 'cardholderName' (String)
  /// - 'cardBrand' (String)
  ///
  /// Implementations should perform Luhn validation and only return a number
  /// that passes Luhn. If no valid card is detected, return null.
  Future<Map<String, dynamic>?> scanCard(Map<String, Object?> options) {
    throw UnimplementedError('scanCard() has not been implemented.');
  }
}

