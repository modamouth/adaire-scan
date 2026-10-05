import 'package:flutter/services.dart';
import 'package:flutter_id_scanner/flutter_id_scanner.dart';

class IdScannerService {
  final FlutterIdScanner _scanner;

  IdScannerService({FlutterIdScanner? scanner})
      : _scanner = scanner ?? FlutterIdScanner();

  Future<IdScanResult?> scanId({
    IdScanOptions options = const IdScanOptions(),
    IdScanProgressCallback? onProgress,
  }) async {
    try {
      return await _scanner.scanIdCard(options: options, onProgress: onProgress);
    } on PlatformException {
      rethrow;
    }
  }
}
