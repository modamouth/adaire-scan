import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_credit_card_scanner/flutter_credit_card_scanner.dart';

class CreditCardScannerService {
  final FlutterCreditCardScanner _scanner;

  CreditCardScannerService({FlutterCreditCardScanner? scanner})
    : _scanner = scanner ?? FlutterCreditCardScanner();

  Future<CreditCardScanResult?> scanCard({
    bool scanExpiry = true,
    bool? debug,
    bool showDetectedQuad = false,
    int consensusRequired = 3,
    int stabilityRequired = 2,
  }) async {
    final effectiveDebug = debug ?? kDebugMode;
    try {
      return await _scanner.scanCard(
        scanExpiry: scanExpiry,
        debug: effectiveDebug,
        showDetectedQuad: showDetectedQuad,
        consensusRequired: consensusRequired,
        stabilityRequired: stabilityRequired,
      );
    } on PlatformException {
      rethrow;
    }
  }
}
