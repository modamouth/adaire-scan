import 'flutter_id_scanner_platform_interface.dart';

import 'src/id_ocr.dart';
import 'src/id_scan.dart';
import 'src/id_text_parser.dart';

export 'src/id_scan.dart'
    show
        IdCaptureSide,
        IdScanOptions,
        IdScanProgressCallback,
        IdCardData,
        IdScanResult,
        ParsedDate;

class FlutterIdScanner {
  Future<String?> getPlatformVersion() {
    return FlutterIdScannerPlatform.instance.getPlatformVersion();
  }

  /// Two-step ID scan: capture front, then capture back.
  ///
  /// Returns `null` if the user cancels at any step (unless
  /// [IdScanOptions.returnPartialOnCancel] is true).
  Future<IdScanResult?> scanIdCard({
    IdScanOptions options = const IdScanOptions(),
    IdScanProgressCallback? onProgress,
  }) async {
    // Step 1: front
    onProgress?.call(IdCaptureSide.front);
    final frontPayload = await FlutterIdScannerPlatform.instance.scanDocument(
      <String, Object?>{
        'pageLimit': 1,
        'allowGalleryImport': options.allowGalleryImport,
      },
    );
    if (frontPayload == null) return null;

    final frontPathsRaw = frontPayload['imagePaths'];
    final frontPaths = (frontPathsRaw is List)
        ? frontPathsRaw.whereType<String>().toList(growable: false)
        : const <String>[];
    if (frontPaths.isEmpty) return null;
    final frontImagePath = frontPaths.first;

    final frontOcr = options.performOcr
        ? await IdOcr.readTextFromImagePath(frontImagePath)
        : null;

    // Step 2: back
    onProgress?.call(IdCaptureSide.back);
    final backPayload = await FlutterIdScannerPlatform.instance.scanDocument(
      <String, Object?>{
        'pageLimit': 1,
        'allowGalleryImport': options.allowGalleryImport,
      },
    );

    if (backPayload == null) {
      if (!options.returnPartialOnCancel) return null;
      final combinedLines = <String>[...?(frontOcr?.lines)];
      final parsed = options.performOcr
          ? IdTextParser.parse(combinedLines)
          : const IdCardData();
      return IdScanResult(
        frontImagePath: frontImagePath,
        backImagePath: null,
        frontRawOcrText: frontOcr?.rawText,
        backRawOcrText: null,
        data: parsed,
      );
    }

    final backPathsRaw = backPayload['imagePaths'];
    final backPaths = (backPathsRaw is List)
        ? backPathsRaw.whereType<String>().toList(growable: false)
        : const <String>[];
    if (backPaths.isEmpty) {
      if (!options.returnPartialOnCancel) return null;
      final combinedLines = <String>[...?(frontOcr?.lines)];
      final parsed = options.performOcr
          ? IdTextParser.parse(combinedLines)
          : const IdCardData();
      return IdScanResult(
        frontImagePath: frontImagePath,
        backImagePath: null,
        frontRawOcrText: frontOcr?.rawText,
        backRawOcrText: null,
        data: parsed,
      );
    }
    final backImagePath = backPaths.first;
    final backOcr = options.performOcr
        ? await IdOcr.readTextFromImagePath(backImagePath)
        : null;

    final combinedLines = <String>[...?(frontOcr?.lines), ...?(backOcr?.lines)];
    final parsed = options.performOcr
        ? IdTextParser.parse(combinedLines)
        : const IdCardData();

    return IdScanResult(
      frontImagePath: frontImagePath,
      backImagePath: backImagePath,
      frontRawOcrText: frontOcr?.rawText,
      backRawOcrText: backOcr?.rawText,
      data: parsed,
    );
  }
}
