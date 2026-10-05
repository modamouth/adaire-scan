import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_id_scanner_method_channel.dart';

abstract class FlutterIdScannerPlatform extends PlatformInterface {
  /// Constructs a FlutterIdScannerPlatform.
  FlutterIdScannerPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterIdScannerPlatform _instance = MethodChannelFlutterIdScanner();

  /// The default instance of [FlutterIdScannerPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterIdScanner].
  static FlutterIdScannerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterIdScannerPlatform] when
  /// they register themselves.
  static set instance(FlutterIdScannerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  /// Opens a camera-based document scanner with edge detection and returns
  /// local file paths for captured images. Returns `null` if the user cancels.
  ///
  /// Expected keys in [options]:
  /// - `pageLimit` (int)
  /// - `allowGalleryImport` (bool)
  Future<Map<Object?, Object?>?> scanDocument(Map<String, Object?> options) {
    throw UnimplementedError('scanDocument() has not been implemented.');
  }
}
