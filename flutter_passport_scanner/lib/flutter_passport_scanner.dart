import 'flutter_passport_scanner_platform_interface.dart';

import 'src/mrz.dart';
import 'src/passport_ocr.dart';

export 'src/mrz.dart' show PassportMrz, MrzParser, MrzParseResult, DateParts;

class PassportScanOptions {
  final int pageLimit;
  final bool allowGalleryImport;
  final bool performOcr;

  const PassportScanOptions({
    this.pageLimit = 1,
    this.allowGalleryImport = false,
    this.performOcr = true,
  });

  Map<String, Object?> toMap() => <String, Object?>{
        'pageLimit': pageLimit,
        'allowGalleryImport': allowGalleryImport,
        'performOcr': performOcr,
      };
}

class PassportScanResult {
  final List<String> imagePaths;
  final String? pdfPath;
  final PassportMrz? mrz;
  final String? rawOcrText;

  const PassportScanResult({required this.imagePaths, this.pdfPath, this.mrz, this.rawOcrText});

  static PassportScanResult fromMap(Map<Object?, Object?> map) {
    final rawImages = map['imagePaths'];
    final imagePaths = (rawImages is List)
        ? rawImages.whereType<String>().toList(growable: false)
        : const <String>[];
    final pdfPath = map['pdfPath'] as String?;

    final mrzMap = map['mrz'];
    PassportMrz? mrz;
    if (mrzMap is Map) {
      // If native ever sends this, keep compatibility.
      final m = mrzMap.cast<String, Object?>();
      mrz = PassportMrz(
        documentCode: (m['documentCode'] as String?) ?? '',
        issuingCountry: (m['issuingCountry'] as String?) ?? '',
        surnames: (m['surnames'] as String?) ?? '',
        givenNames: (m['givenNames'] as String?) ?? '',
        passportNumber: (m['passportNumber'] as String?) ?? '',
        nationality: (m['nationality'] as String?) ?? '',
        dateOfBirth: null,
        sex: (m['sex'] as String?) ?? '',
        dateOfExpiry: null,
        personalNumber: (m['personalNumber'] as String?) ?? '',
        mrzLine1: (m['mrzLine1'] as String?) ?? '',
        mrzLine2: (m['mrzLine2'] as String?) ?? '',
        isValid: (m['isValid'] as bool?) ?? false,
        errors: (m['errors'] as List?)?.whereType<String>().toList(growable: false) ?? const <String>[],
      );
    }

    final rawOcrText = map['rawOcrText'] as String?;
    return PassportScanResult(imagePaths: imagePaths, pdfPath: pdfPath, mrz: mrz, rawOcrText: rawOcrText);
  }
}

class FlutterPassportScanner {
  Future<String?> getPlatformVersion() {
    return FlutterPassportScannerPlatform.instance.getPlatformVersion();
  }

  /// Opens a camera-based document scanner with edge detection and returns
  /// local file paths for captured images. Returns `null` if the user cancels.
  Future<PassportScanResult?> scanPassport({PassportScanOptions options = const PassportScanOptions()}) async {
    final payload = await FlutterPassportScannerPlatform.instance.scanPassport(options.toMap());
    if (payload == null) return null;

    final base = PassportScanResult.fromMap(payload);
    if (!options.performOcr || base.imagePaths.isEmpty) return base;

    final ocr = await PassportOcr.readMrzFromImagePath(base.imagePaths.first);
    return PassportScanResult(
      imagePaths: base.imagePaths,
      pdfPath: base.pdfPath,
      mrz: ocr.mrz,
      rawOcrText: ocr.rawText,
    );
  }
}
