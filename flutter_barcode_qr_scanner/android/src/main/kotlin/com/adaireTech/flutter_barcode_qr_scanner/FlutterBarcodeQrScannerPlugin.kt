package com.adaireTech.flutter_barcode_qr_scanner

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener

/** FlutterBarcodeQrScannerPlugin */
class FlutterBarcodeQrScannerPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodCallHandler {
    // The MethodChannel that will the communication between Flutter and native Android
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingResult: Result? = null

    private val activityResultListener = object : ActivityResultListener {
        override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
            if (requestCode != REQUEST_CODE) return false
            val current = pendingResult ?: return true
            if (resultCode == Activity.RESULT_OK && data != null) {
                val value = data.getStringExtra(SimpleScanActivity.EXTRA_VALUE)
                val type = data.getStringExtra(SimpleScanActivity.EXTRA_TYPE)
                current.success(hashMapOf(
                    "value" to value,
                    "type" to type
                ))
            } else {
                current.success(null)
            }
            pendingResult = null
            return true
        }
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_barcode_qr_scanner")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")
            "scan" -> {
                if (pendingResult != null) {
                    result.error("ALREADY_ACTIVE", "A scan is already in progress", null)
                    return
                }
                val act = activity
                if (act == null) {
                    result.error("NO_ACTIVITY", "No foreground activity to start scanner", null)
                    return
                }
                pendingResult = result
                val formatsArg = call.argument<List<String>>("formats")
                val intent = Intent(act, SimpleScanActivity::class.java)
                if (!formatsArg.isNullOrEmpty()) {
                    intent.putStringArrayListExtra(SimpleScanActivity.EXTRA_FORMATS, ArrayList(formatsArg))
                }
                act.startActivityForResult(intent, REQUEST_CODE)
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    companion object {
        private const val REQUEST_CODE = 0xB17C // arbitrary
    }

    // ActivityAware
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(activityResultListener)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeActivityResultListener(activityResultListener)
        activityBinding = null
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(activityResultListener)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeActivityResultListener(activityResultListener)
        activityBinding = null
        activity = null
    }
}
