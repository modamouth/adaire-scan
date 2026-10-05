import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_barcode_qr_scanner_method_channel.dart';

abstract class FlutterBarcodeQrScannerPlatform extends PlatformInterface {
  /// Constructs a FlutterBarcodeQrScannerPlatform.
  FlutterBarcodeQrScannerPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterBarcodeQrScannerPlatform _instance = MethodChannelFlutterBarcodeQrScanner();

  /// The default instance of [FlutterBarcodeQrScannerPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterBarcodeQrScanner].
  static FlutterBarcodeQrScannerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterBarcodeQrScannerPlatform] when
  /// they register themselves.
  static set instance(FlutterBarcodeQrScannerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  /// Launch a native barcode/QR scanner UI.
  ///
  /// Optionally filter by formats. Pass format keys like 'qr', 'ean13', 'code128'.
  /// Returns a map with 'value' and 'type' (format key) or null if canceled.
  Future<Map<String, dynamic>?> scan({List<String>? formats}) {
    throw UnimplementedError('scan() has not been implemented.');
  }
}
