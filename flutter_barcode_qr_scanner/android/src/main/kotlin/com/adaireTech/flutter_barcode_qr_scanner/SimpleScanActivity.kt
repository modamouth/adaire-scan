package com.adaireTech.flutter_barcode_qr_scanner

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.view.ViewGroup
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.FrameLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.zxing.BarcodeFormat
import com.journeyapps.barcodescanner.BarcodeCallback
import com.journeyapps.barcodescanner.BarcodeResult
import com.journeyapps.barcodescanner.BarcodeView
import com.journeyapps.barcodescanner.DefaultDecoderFactory

class SimpleScanActivity : AppCompatActivity() {
    companion object {
        private const val REQ_CAMERA = 2001
        const val EXTRA_FORMATS = "formats"
        const val EXTRA_OUTCOME = "outcome"
        const val EXTRA_VALUE = "value"
        const val EXTRA_TYPE = "type"
        private const val OUTCOME_SUCCESS = "success"
        private const val OUTCOME_CANCELLED = "cancelled"
        private const val OUTCOME_PERMISSION_DENIED = "permission_denied"
        private const val OUTCOME_FAILURE = "failure"
    }

    private lateinit var barcodeView: BarcodeView
    private var handled = false
    private var torchOn = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        barcodeView = BarcodeView(this)
        barcodeView.layoutParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )

        val container = FrameLayout(this)
        container.addView(barcodeView)

        val closeButton = Button(this).apply {
            text = "Close"
            contentDescription = "Close scanner"
            minWidth = dp(48)
            minHeight = dp(48)
            setOnClickListener { finishWithOutcome(OUTCOME_CANCELLED) }
        }
        container.addView(
            closeButton,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply {
                gravity = Gravity.TOP or Gravity.START
                topMargin = dp(24)
                leftMargin = dp(16)
            },
        )

        val flashButton = Button(this).apply {
            text = "Torch off"
            contentDescription = "Turn torch on"
            minWidth = dp(48)
            minHeight = dp(48)
            setTextColor(0xFFFFFFFF.toInt())
            setBackgroundColor(0x66000000)
            setOnClickListener {
                val requestedState = !torchOn
                if (setTorchSafe(requestedState)) {
                    torchOn = requestedState
                    text = if (torchOn) "Torch on" else "Torch off"
                    contentDescription = if (torchOn) "Turn torch off" else "Turn torch on"
                } else {
                    text = "Torch unavailable"
                    contentDescription = "Torch unavailable"
                    isEnabled = false
                    announceForAccessibility("Torch unavailable")
                }
            }
        }
        val hasTorch = packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_FLASH)
        flashButton.visibility = if (hasTorch) View.VISIBLE else View.GONE
        container.addView(
            flashButton,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply {
                gravity = Gravity.TOP or Gravity.END
                topMargin = dp(24)
                rightMargin = dp(16)
            },
        )

        val guidance = TextView(this).apply {
            text = "Align a QR code, EAN-13 barcode, or Code 128 barcode in the camera view"
            contentDescription = text
            setTextColor(0xFFFFFFFF.toInt())
            setBackgroundColor(0x99000000.toInt())
            textSize = 16f
            setPadding(dp(16), dp(12), dp(16), dp(12))
            gravity = Gravity.CENTER
        }
        container.addView(
            guidance,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply {
                gravity = Gravity.BOTTOM
                leftMargin = dp(16)
                rightMargin = dp(16)
                bottomMargin = dp(24)
            },
        )

        setContentView(container)

        val keys = intent.getStringArrayListExtra(EXTRA_FORMATS)
        val formats = mapKeysToFormats(keys)
        if (formats.isEmpty()) {
            finishWithOutcome(OUTCOME_FAILURE)
            return
        }
        barcodeView.decoderFactory = DefaultDecoderFactory(formats)
    }

    override fun onResume() {
        super.onResume()
        ensureCameraThenStart()
    }

    override fun onPause() {
        super.onPause()
        barcodeView.pause()
    }

    private fun ensureCameraThenStart() {
        val granted = ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
        if (!granted) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.CAMERA), REQ_CAMERA)
        } else {
            startDecoding()
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_CAMERA) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) startDecoding()
            else finishWithOutcome(OUTCOME_PERMISSION_DENIED)
        }
    }

    private fun startDecoding() {
        if (!handled) {
            // Ensure the decode callback is set before resuming the camera
            // so the first frames are processed and results are delivered.
            barcodeView.decodeContinuous(object : BarcodeCallback {
                override fun barcodeResult(result: BarcodeResult?) {
                    if (handled) return
                    val text = result?.text ?: return
                    handled = true
                    val data = Intent().apply {
                        putExtra(EXTRA_OUTCOME, OUTCOME_SUCCESS)
                        putExtra(EXTRA_VALUE, text)
                        putExtra(EXTRA_TYPE, formatToKey(result.barcodeFormat))
                    }
                    setResult(RESULT_OK, data)
                    finish()
                }

                override fun possibleResultPoints(resultPoints: MutableList<com.google.zxing.ResultPoint>?) {
                    // no-op
                }
            })
            barcodeView.resume()
        }
    }

    override fun onBackPressed() {
        finishWithOutcome(OUTCOME_CANCELLED)
    }

    private fun finishWithOutcome(outcome: String) {
        if (handled) return
        handled = true
        setResult(RESULT_CANCELED, Intent().putExtra(EXTRA_OUTCOME, outcome))
        finish()
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()

    private fun setTorchSafe(on: Boolean): Boolean {
        try {
            val m = barcodeView.javaClass.getMethod("setTorch", Boolean::class.javaPrimitiveType)
            m.invoke(barcodeView, on)
            return true
        } catch (_: Throwable) {
            try {
                val name = if (on) "setTorchOn" else "setTorchOff"
                val m2 = barcodeView.javaClass.getMethod(name)
                m2.invoke(barcodeView)
                return true
            } catch (_: Throwable) {
                return false
            }
        }
    }

    private fun mapKeysToFormats(keys: ArrayList<String>?) : Collection<BarcodeFormat> {
        if (keys == null) return emptyList()
        return keys.mapNotNull { keyToFormat(it) }
    }

    private fun keyToFormat(key: String): BarcodeFormat? = when (key.lowercase()) {
        "qr" -> BarcodeFormat.QR_CODE
        "ean13" -> BarcodeFormat.EAN_13
        "code128" -> BarcodeFormat.CODE_128
        else -> null
    }

    private fun formatToKey(format: BarcodeFormat?): String = when (format) {
        BarcodeFormat.QR_CODE -> "qr"
        BarcodeFormat.EAN_13 -> "ean13"
        BarcodeFormat.CODE_128 -> "code128"
        else -> "unknown"
    }
}
