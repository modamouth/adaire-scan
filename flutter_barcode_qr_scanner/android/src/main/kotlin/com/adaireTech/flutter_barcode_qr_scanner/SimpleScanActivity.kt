package com.adaireTech.flutter_barcode_qr_scanner

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.view.ViewGroup
import android.view.Gravity
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
        const val EXTRA_VALUE = "value"
        const val EXTRA_TYPE = "type"
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

        // Flash toggle button (top-right)
        val flashBtn = TextView(this).apply {
            text = "Flash"
            setTextColor(0xFFFFFFFF.toInt())
            setBackgroundColor(0x66000000)
            textSize = 14f
            setPadding(20, 12, 20, 12)
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply { gravity = Gravity.TOP or Gravity.END; topMargin = 24; rightMargin = 24 }
            setOnClickListener {
                torchOn = !torchOn
                setTorchSafe(torchOn)
                text = if (torchOn) "Flash On" else "Flash"
            }
        }
        container.addView(flashBtn)

        setContentView(container)

        val keys = intent.getStringArrayListExtra(EXTRA_FORMATS)
        val formats = mapKeysToFormats(keys)
        if (formats.isNotEmpty()) {
            barcodeView.decoderFactory = DefaultDecoderFactory(formats)
        }
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
            else finishCanceled()
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
        finishCanceled()
    }

    private fun finishCanceled() {
        setResult(RESULT_CANCELED)
        finish()
    }

    private fun setTorchSafe(on: Boolean) {
        try {
            val m = barcodeView.javaClass.getMethod("setTorch", Boolean::class.javaPrimitiveType)
            m.invoke(barcodeView, on)
        } catch (_: Throwable) {
            try {
                val name = if (on) "setTorchOn" else "setTorchOff"
                val m2 = barcodeView.javaClass.getMethod(name)
                m2.invoke(barcodeView)
            } catch (_: Throwable) {
                // Torch not supported; ignore
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
        "ean8" -> BarcodeFormat.EAN_8
        "code128" -> BarcodeFormat.CODE_128
        "code39" -> BarcodeFormat.CODE_39
        "code93" -> BarcodeFormat.CODE_93
        "upca" -> BarcodeFormat.UPC_A
        "upce" -> BarcodeFormat.UPC_E
        "itf" -> BarcodeFormat.ITF
        "codabar" -> BarcodeFormat.CODABAR
        "datamatrix" -> BarcodeFormat.DATA_MATRIX
        "aztec" -> BarcodeFormat.AZTEC
        "pdf417" -> BarcodeFormat.PDF_417
        else -> null
    }

    private fun formatToKey(format: BarcodeFormat?): String = when (format) {
        BarcodeFormat.QR_CODE -> "qr"
        BarcodeFormat.EAN_13 -> "ean13"
        BarcodeFormat.EAN_8 -> "ean8"
        BarcodeFormat.CODE_128 -> "code128"
        BarcodeFormat.CODE_39 -> "code39"
        BarcodeFormat.CODE_93 -> "code93"
        BarcodeFormat.UPC_A -> "upca"
        BarcodeFormat.UPC_E -> "upce"
        BarcodeFormat.ITF -> "itf"
        BarcodeFormat.CODABAR -> "codabar"
        BarcodeFormat.DATA_MATRIX -> "datamatrix"
        BarcodeFormat.AZTEC -> "aztec"
        BarcodeFormat.PDF_417 -> "pdf417"
        else -> "unknown"
    }
}
