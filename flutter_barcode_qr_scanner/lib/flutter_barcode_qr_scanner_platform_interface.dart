import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_barcode_qr_scanner_method_channel.dart';

abstract class FlutterBarcodeQrScannerPlatform extends PlatformInterface {
  /// Constructs a FlutterBarcodeQrScannerPlatform.
  FlutterBarcodeQrScannerPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterBarcodeQrScannerPlatform _instance =
      MethodChannelFlutterBarcodeQrScanner();

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
  /// Pass the validated format keys 'qr', 'ean13', and/or 'code128'.
  /// Returns one terminal outcome envelope.
  Future<Map<String, dynamic>> scan({required List<String> formats}) {
    throw UnimplementedError('scan() has not been implemented.');
  }
}
