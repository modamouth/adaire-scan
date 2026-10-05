import 'package:flutter/services.dart';
import 'package:flutter_barcode_qr_scanner/flutter_barcode_qr_scanner.dart';

class BarcodeScannerService {
  final FlutterBarcodeQrScanner _scanner;

  BarcodeScannerService({FlutterBarcodeQrScanner? scanner})
    : _scanner = scanner ?? FlutterBarcodeQrScanner();

  Future<ScanResult?> scan() async {
    try {
      return await _scanner.scan();
    } on PlatformException {
      rethrow;
    }
  }
}
