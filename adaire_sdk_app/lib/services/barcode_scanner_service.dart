import 'package:flutter_barcode_qr_scanner/flutter_barcode_qr_scanner.dart';

class BarcodeScannerService {
  final FlutterBarcodeQrScanner _scanner;

  BarcodeScannerService({FlutterBarcodeQrScanner? scanner})
    : _scanner = scanner ?? FlutterBarcodeQrScanner();

  Future<ScanOutcome> scan() => _scanner.scan();
}
