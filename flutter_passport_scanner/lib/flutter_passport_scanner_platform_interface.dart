import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_passport_scanner_method_channel.dart';

abstract class FlutterPassportScannerPlatform extends PlatformInterface {
  /// Constructs a FlutterPassportScannerPlatform.
  FlutterPassportScannerPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterPassportScannerPlatform _instance = MethodChannelFlutterPassportScanner();

  /// The default instance of [FlutterPassportScannerPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterPassportScanner].
  static FlutterPassportScannerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterPassportScannerPlatform] when
  /// they register themselves.
  static set instance(FlutterPassportScannerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<Map<String, Object?>?> scanPassport(Map<String, Object?> options) {
    throw UnimplementedError('scanPassport() has not been implemented.');
  }
}
