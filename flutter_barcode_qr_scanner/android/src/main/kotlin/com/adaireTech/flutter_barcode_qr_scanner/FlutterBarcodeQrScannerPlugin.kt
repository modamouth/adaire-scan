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
            if (pendingResult == null) return true

            val outcome = data?.getStringExtra(SimpleScanActivity.EXTRA_OUTCOME)
            if (resultCode == Activity.RESULT_OK && outcome == OUTCOME_SUCCESS) {
                val value = data?.getStringExtra(SimpleScanActivity.EXTRA_VALUE)
                val type = data?.getStringExtra(SimpleScanActivity.EXTRA_TYPE)
                if (value.isNullOrEmpty() || type !in SUPPORTED_FORMATS) {
                    complete(outcome(OUTCOME_FAILURE, "malformed_activity_result"))
                } else {
                    complete(hashMapOf(
                        "outcome" to OUTCOME_SUCCESS,
                        "value" to value,
                        "type" to type
                    ))
                }
            } else {
                val terminalOutcome = when (outcome) {
                    OUTCOME_CANCELLED -> OUTCOME_CANCELLED
                    OUTCOME_PERMISSION_DENIED -> OUTCOME_PERMISSION_DENIED
                    OUTCOME_UNAVAILABLE -> OUTCOME_UNAVAILABLE
                    OUTCOME_FAILURE -> OUTCOME_FAILURE
                    else -> OUTCOME_CANCELLED
                }
                complete(outcome(terminalOutcome))
            }
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
                    result.success(outcome(OUTCOME_BUSY))
                    return
                }
                val act = activity
                if (act == null) {
                    result.success(outcome(OUTCOME_UNAVAILABLE, "no_activity"))
                    return
                }

                val formatsArg = call.argument<List<*>>("formats")
                val formats = formatsArg?.filterIsInstance<String>()
                if (formatsArg == null ||
                    formats == null ||
                    formats.size != formatsArg.size ||
                    formats.isEmpty() ||
                    formats.any { it !in SUPPORTED_FORMATS }
                ) {
                    result.success(outcome(OUTCOME_FAILURE, "invalid_formats"))
                    return
                }

                pendingResult = result
                val intent = Intent(act, SimpleScanActivity::class.java)
                intent.putStringArrayListExtra(
                    SimpleScanActivity.EXTRA_FORMATS,
                    ArrayList(formats.distinct())
                )
                try {
                    act.startActivityForResult(intent, REQUEST_CODE)
                } catch (_: Throwable) {
                    complete(outcome(OUTCOME_UNAVAILABLE, "launch_failed"))
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        complete(outcome(OUTCOME_UNAVAILABLE, "engine_detached"))
        channel.setMethodCallHandler(null)
    }

    companion object {
        private const val REQUEST_CODE = 0xB17C // arbitrary
        private const val OUTCOME_SUCCESS = "success"
        private const val OUTCOME_CANCELLED = "cancelled"
        private const val OUTCOME_PERMISSION_DENIED = "permission_denied"
        private const val OUTCOME_UNAVAILABLE = "unavailable"
        private const val OUTCOME_BUSY = "busy"
        private const val OUTCOME_FAILURE = "failure"
        private val SUPPORTED_FORMATS = setOf("qr", "ean13", "code128")
    }

    private fun outcome(value: String, diagnosticCode: String? = null): HashMap<String, String> =
        hashMapOf<String, String>("outcome" to value).apply {
            if (diagnosticCode != null) put("diagnosticCode", diagnosticCode)
        }

    private fun complete(envelope: Map<String, Any?>) {
        val current = pendingResult ?: return
        pendingResult = null
        current.success(envelope)
    }

    // ActivityAware
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(activityResultListener)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        complete(outcome(OUTCOME_UNAVAILABLE, "activity_detached"))
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
        complete(outcome(OUTCOME_UNAVAILABLE, "activity_detached"))
        activityBinding?.removeActivityResultListener(activityResultListener)
        activityBinding = null
        activity = null
    }
}
