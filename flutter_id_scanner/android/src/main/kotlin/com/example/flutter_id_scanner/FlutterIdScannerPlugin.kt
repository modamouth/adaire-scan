package com.example.flutter_id_scanner

import android.app.Activity
import android.content.Intent
import java.io.File
import java.io.FileOutputStream
import java.util.UUID

import com.google.android.gms.tasks.Task
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

/** FlutterIdScannerPlugin */
class FlutterIdScannerPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    PluginRegistry.ActivityResultListener {
    // The MethodChannel that will the communication between Flutter and native Android
    //
    // This local reference serves to register the plugin with the Flutter Engine and unregister it
    // when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var pendingResult: Result? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_id_scanner")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when (call.method) {
            "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")
            "scanDocument" -> {
                if (pendingResult != null) {
                    result.error("ALREADY_ACTIVE", "A scan is already in progress", null)
                    return
                }
                val act = activity
                if (act == null) {
                    result.error("NO_ACTIVITY", "Plugin not attached to an activity", null)
                    return
                }

                val args = call.arguments as? Map<*, *>
                val pageLimit = (args?.get("pageLimit") as? Number)?.toInt() ?: 1
                val allowGalleryImport = (args?.get("allowGalleryImport") as? Boolean) ?: false

                pendingResult = result
                startDocumentScan(act, pageLimit, allowGalleryImport)
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    // ActivityAware
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    // Activity result
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false

        val result = pendingResult ?: return true
        pendingResult = null

        if (resultCode == Activity.RESULT_OK && data != null) {
            val scanResult = GmsDocumentScanningResult.fromActivityResultIntent(data)
            if (scanResult == null) {
                result.error("SCAN_ERROR", "No scan result returned", null)
                return true
            }

            try {
                val imagePaths = mutableListOf<String>()
                val pages = scanResult.pages ?: emptyList()
                for ((idx, page) in pages.withIndex()) {
                    val uri = page.imageUri ?: continue
                    val path = copyContentUriToCache(uri.toString(), idx)
                    if (path != null) imagePaths.add(path)
                }

                val pdfUri = scanResult.pdf?.uri
                val pdfPath = pdfUri?.let { copyContentUriToCache(it.toString(), -1, extension = "pdf") }

                val payload = hashMapOf<String, Any?>(
                    "imagePaths" to imagePaths,
                    "pdfPath" to pdfPath
                )
                result.success(payload)
            } catch (e: Exception) {
                result.error("SCAN_ERROR", e.message ?: "Unknown scan error", null)
            }
        } else {
            // Cancelled
            result.success(null)
        }
        return true
    }

    private fun startDocumentScan(activity: Activity, pageLimit: Int, allowGalleryImport: Boolean) {
        val options = GmsDocumentScannerOptions.Builder()
            .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL)
            .setGalleryImportAllowed(allowGalleryImport)
            .setPageLimit(pageLimit.coerceIn(1, 10))
            .setResultFormats(
                GmsDocumentScannerOptions.RESULT_FORMAT_JPEG,
                GmsDocumentScannerOptions.RESULT_FORMAT_PDF
            )
            .build()

        val scanner = GmsDocumentScanning.getClient(options)
        val task: Task<android.content.IntentSender> = scanner.getStartScanIntent(activity)
        task.addOnSuccessListener { intentSender ->
            try {
                activity.startIntentSenderForResult(intentSender, REQUEST_CODE, null, 0, 0, 0)
            } catch (e: Exception) {
                val res = pendingResult
                pendingResult = null
                res?.error("SCAN_ERROR", e.message ?: "Failed to launch scanner", null)
            }
        }.addOnFailureListener { e ->
            val res = pendingResult
            pendingResult = null
            res?.error("SCAN_ERROR", e.message ?: "Failed to start scanner", null)
        }
    }

    private fun copyContentUriToCache(uriString: String, index: Int, extension: String = "jpg"): String? {
        val act = activity ?: return null
        val uri = android.net.Uri.parse(uriString)
        val dir = File(act.cacheDir, "flutter_id_scanner")
        if (!dir.exists()) dir.mkdirs()

        val namePart = if (index >= 0) "page_$index" else "file"
        val outFile = File(dir, "${namePart}_${UUID.randomUUID()}.$extension")

        act.contentResolver.openInputStream(uri).use { input ->
            if (input == null) return null
            FileOutputStream(outFile).use { output ->
                input.copyTo(output)
            }
        }
        return outFile.absolutePath
    }

    companion object {
        private const val REQUEST_CODE = 0x1D55
    }
}
