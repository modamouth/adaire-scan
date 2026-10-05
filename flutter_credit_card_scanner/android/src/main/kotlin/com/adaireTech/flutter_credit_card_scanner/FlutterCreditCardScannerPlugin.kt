package com.adaireTech.flutter_credit_card_scanner

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

/** FlutterCreditCardScannerPlugin */
class FlutterCreditCardScannerPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    PluginRegistry.ActivityResultListener {
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var pendingResult: Result? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_credit_card_scanner")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")
            "scanCard" -> {
                if (pendingResult != null) {
                    result.error("ALREADY_ACTIVE", "A scan is already in progress", null)
                    return
                }
                val act = activity
                if (act == null) {
                    result.error("NO_ACTIVITY", "Plugin not attached to an activity", null)
                    return
                }
                pendingResult = result
                val args = call.arguments as? Map<*, *>
                val scanExpiry = (args?.get("scanExpiry") as? Boolean) ?: true
                val scanCardholderName = (args?.get("scanCardholderName") as? Boolean) ?: false
                val restrictBrand = args?.get("restrictBrand") as? String
                val timeoutMs = (args?.get("timeoutMs") as? Number)?.toInt()
                val debug = (args?.get("debug") as? Boolean) ?: false
                val showDetectedQuad = (args?.get("showDetectedQuad") as? Boolean) ?: false
                val cropToGuide = (args?.get("cropToGuide") as? Boolean) ?: false
                val consensusRequired = (args?.get("consensusRequired") as? Number)?.toInt() ?: 3
                val stabilityRequired = (args?.get("stabilityRequired") as? Number)?.toInt() ?: 2

                val intent = Intent(act, CardScanActivity::class.java).apply {
                    putExtra(CardScanActivity.EXTRA_SCAN_EXPIRY, scanExpiry)
                    putExtra(CardScanActivity.EXTRA_SCAN_NAME, scanCardholderName)
                    putExtra(CardScanActivity.EXTRA_RESTRICT_BRAND, restrictBrand)
                    if (timeoutMs != null && timeoutMs > 0) putExtra(CardScanActivity.EXTRA_TIMEOUT_MS, timeoutMs)
                    putExtra(CardScanActivity.EXTRA_DEBUG, debug)
                    putExtra(CardScanActivity.EXTRA_SHOW_QUAD, showDetectedQuad)
                    putExtra(CardScanActivity.EXTRA_CROP_TO_GUIDE, cropToGuide)
                    putExtra(CardScanActivity.EXTRA_CONSENSUS_REQUIRED, consensusRequired)
                    putExtra(CardScanActivity.EXTRA_STABILITY_REQUIRED, stabilityRequired)
                }
                act.startActivityForResult(intent, REQUEST_CODE)
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
            val payload = hashMapOf<String, Any?>(
                "cardNumber" to data.getStringExtra(CardScanActivity.EXTRA_RES_CARD_NUMBER),
                "expiryMonth" to data.getIntExtra(CardScanActivity.EXTRA_RES_EXP_MONTH, 0).takeIf { it > 0 },
                "expiryYear" to data.getIntExtra(CardScanActivity.EXTRA_RES_EXP_YEAR, 0).takeIf { it > 0 },
                "cardholderName" to data.getStringExtra(CardScanActivity.EXTRA_RES_NAME),
                "cardBrand" to data.getStringExtra(CardScanActivity.EXTRA_RES_BRAND)
            )
            result.success(payload)
        } else if (resultCode == CardScanActivity.RESULT_TIMEOUT) {
            result.error("TIMEOUT", "Scan timed out", null)
        } else if (resultCode == CardScanActivity.RESULT_ERROR) {
            val message = data?.getStringExtra(CardScanActivity.EXTRA_RES_ERROR) ?: "Unknown error"
            result.error("SCAN_ERROR", message, null)
        } else {
            result.success(null)
        }
        return true
    }

    companion object {
        private const val REQUEST_CODE = 0xCC55
    }
}
