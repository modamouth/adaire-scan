import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

import 'dart:io';

import 'mrz.dart';

class PassportOcr {
  /// Runs OCR on the given image and attempts to extract + parse a TD3 passport MRZ.
  static Future<({PassportMrz? mrz, String rawText, List<String> lines})> readMrzFromImagePath(
    String imagePath,
  ) async {
    final first = await _ocrOnce(imagePath);
    if (first.mrz != null) return first;

    // Second pass: crop bottom portion where MRZ usually is.
    final croppedPath = await _tryCreateBottomCrop(imagePath);
    if (croppedPath == null) return first;
    final second = await _ocrOnce(croppedPath);
    // Prefer the result that actually found MRZ; otherwise keep first.
    return (second.mrz != null) ? second : first;
  }

  static Future<({PassportMrz? mrz, String rawText, List<String> lines})> _ocrOnce(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognized = await recognizer.processImage(inputImage);

      final lines = <String>[];
      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          lines.add(line.text);
        }
      }

      final extracted = MrzParser.extractTd3Lines(lines);
      if (extracted == null) {
        return (mrz: null, rawText: recognized.text, lines: lines);
      }

      final parsed = MrzParser.parseTd3(extracted.line1, extracted.line2);
      return (mrz: parsed.mrz, rawText: recognized.text, lines: lines);
    } finally {
      recognizer.close();
    }
  }

  static Future<String?> _tryCreateBottomCrop(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      // Crop bottom 40% (MRZ is usually near the bottom of the data page).
      final cropTop = (decoded.height * 0.60).round().clamp(0, decoded.height - 1);
      final cropHeight = (decoded.height - cropTop).clamp(1, decoded.height);
      final cropped = img.copyCrop(decoded, x: 0, y: cropTop, width: decoded.width, height: cropHeight);

      final outDir = Directory.systemTemp.createTempSync('flutter_passport_scanner_');
      final outFile = File('${outDir.path}/mrz_crop_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await outFile.writeAsBytes(img.encodeJpg(cropped, quality: 92));
      return outFile.path;
    } catch (_) {
      return null;
    }
  }
}
