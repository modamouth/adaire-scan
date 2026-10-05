import 'package:flutter/services.dart';
import 'package:flutter_passport_scanner/flutter_passport_scanner.dart';

class PassportScannerService {
  final FlutterPassportScanner _scanner;

  PassportScannerService({FlutterPassportScanner? scanner})
    : _scanner = scanner ?? FlutterPassportScanner();

  Future<PassportScanResult?> scanPassport({PassportScanOptions options = const PassportScanOptions()}) async {
    try {
      return await _scanner.scanPassport(options: options);
    } on PlatformException {
      rethrow;
    }
  }
}
