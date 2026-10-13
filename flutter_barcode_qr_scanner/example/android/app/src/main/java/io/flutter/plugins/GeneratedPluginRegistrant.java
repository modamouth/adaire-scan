package io.flutter.plugins;

import androidx.annotation.Keep;
import androidx.annotation.NonNull;
import io.flutter.Log;
import io.flutter.embedding.engine.FlutterEngine;

/** Generated plugin registration for the private Android evaluation build. */
@Keep
public final class GeneratedPluginRegistrant {
  private static final String TAG = "GeneratedPluginRegistrant";

  private GeneratedPluginRegistrant() {}

  public static void registerWith(@NonNull FlutterEngine flutterEngine) {
    try {
      flutterEngine.getPlugins().add(
          new com.adaireTech.flutter_barcode_qr_scanner.FlutterBarcodeQrScannerPlugin());
    } catch (Exception exception) {
      Log.e(TAG, "Error registering flutter_barcode_qr_scanner", exception);
    }
  }
}
