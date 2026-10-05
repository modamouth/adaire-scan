import 'flutter_credit_card_scanner_platform_interface.dart';

class CreditCardScanResult {
  final String cardNumber;
  final int? expiryMonth;
  final int? expiryYear;
  final String? cardholderName;
  final String? cardBrand;

  CreditCardScanResult({
    required this.cardNumber,
    this.expiryMonth,
    this.expiryYear,
    this.cardholderName,
    this.cardBrand,
  });

  factory CreditCardScanResult.fromMap(Map<String, dynamic> map) {
    return CreditCardScanResult(
      cardNumber: map['cardNumber'] as String,
      expiryMonth: (map['expiryMonth'] is int)
          ? map['expiryMonth'] as int
          : (map['expiryMonth'] as num?)?.toInt(),
      expiryYear: (map['expiryYear'] is int)
          ? map['expiryYear'] as int
          : (map['expiryYear'] as num?)?.toInt(),
      cardholderName: map['cardholderName'] as String?,
      cardBrand: map['cardBrand'] as String?,
    );
  }

  Map<String, Object?> toMap() => {
        'cardNumber': cardNumber,
        'expiryMonth': expiryMonth,
        'expiryYear': expiryYear,
        'cardholderName': cardholderName,
        'cardBrand': cardBrand,
      };
}

class FlutterCreditCardScanner {
  Future<String?> getPlatformVersion() {
    return FlutterCreditCardScannerPlatform.instance.getPlatformVersion();
  }

  /// Launch the platform scanner.
  ///
  /// Options:
  /// - scanExpiry (bool, default true)
  /// - scanCardholderName (bool, default false)
  /// - restrictBrand (String? one of: 'visa','mastercard','amex','discover','diners','jcb','unionpay')
  /// - timeoutMs (int?, default null for no timeout)
  Future<CreditCardScanResult?> scanCard({
    bool scanExpiry = true,
    bool scanCardholderName = false,
    String? restrictBrand,
    int? timeoutMs,
    bool debug = false,
    bool showDetectedQuad = false,
    bool cropToGuide = false,
    int consensusRequired = 3,
    int stabilityRequired = 2,
  }) async {
    final options = <String, Object?>{
      'scanExpiry': scanExpiry,
      'scanCardholderName': scanCardholderName,
      'restrictBrand': restrictBrand,
      'timeoutMs': timeoutMs,
      'debug': debug,
      'showDetectedQuad': showDetectedQuad,
      'cropToGuide': cropToGuide,
      'consensusRequired': consensusRequired,
      'stabilityRequired': stabilityRequired,
    };
    final map =
        await FlutterCreditCardScannerPlatform.instance.scanCard(options);
    if (map == null) return null;
    return CreditCardScanResult.fromMap(map);
  }
}
