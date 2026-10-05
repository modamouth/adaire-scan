import 'dart:io';
import 'package:image/image.dart' as img;

/// Pads Logo2.png with transparent margins (~15%) and writes Logo2_foreground.png.
/// This helps Android adaptive icons avoid looking expanded.
void main() {
  final projectDir = Directory.current.path;
  final sourcePath = Platform.pathSeparator == '/'
      ? '$projectDir/Logo2.png'
      : '$projectDir\\Logo2.png';
  final destPath = Platform.pathSeparator == '/'
      ? '$projectDir/Logo2_foreground.png'
      : '$projectDir\\Logo2_foreground.png';

  final sourceFile = File(sourcePath);
  if (!sourceFile.existsSync()) {
    stderr.writeln('Source file not found: $sourcePath');
    exit(1);
  }

  final bytes = sourceFile.readAsBytesSync();
  final original = img.decodeImage(bytes);
  if (original == null) {
    stderr.writeln('Failed to decode image: $sourcePath');
    exit(2);
  }

  // Compute padded canvas size: add ~15% transparent margin around content.
  const paddingFraction = 0.15; // 15%
  final padX = (original.width * paddingFraction).round();
  final padY = (original.height * paddingFraction).round();
  final canvasW = original.width + padX * 2;
  final canvasH = original.height + padY * 2;

  // Create transparent canvas. Image defaults to transparent RGBA.
  final canvas = img.Image(width: canvasW, height: canvasH);

  // Draw original centered on canvas.
  final offsetX = ((canvasW - original.width) / 2).round();
  final offsetY = ((canvasH - original.height) / 2).round();
  img.compositeImage(canvas, original, dstX: offsetX, dstY: offsetY);

  // Write PNG output.
  final outBytes = img.encodePng(canvas);
  File(destPath).writeAsBytesSync(outBytes);
  stdout.writeln('Wrote padded foreground: $destPath');
}
