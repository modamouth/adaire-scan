import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:collection';

class IdOcr {
  static Future<({String rawText, List<String> lines})> readTextFromImagePath(
    String imagePath,
  ) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognized = await recognizer.processImage(inputImage);

      final ordered = LinkedHashSet<String>();
      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          final t = line.text.trim();
          if (t.isNotEmpty) ordered.add(t);
        }
      }

      // Some label/value text appears in recognized.text but may not be
      // reliably segmented into `block.lines` (varies by document + lighting).
      for (final rawLine in recognized.text.split(RegExp(r'\r?\n'))) {
        final t = rawLine.trim();
        if (t.isNotEmpty) ordered.add(t);
      }

      final lines = ordered.toList(growable: false);

      return (rawText: recognized.text, lines: lines);
    } finally {
      recognizer.close();
    }
  }
}
