package com.adaireTech.flutter_credit_card_scanner

import android.content.Context
import android.graphics.PointF
import androidx.camera.core.ImageProxy

interface EdgeDetector {
    fun init(context: Context) {}
    fun onFrame(imageProxy: ImageProxy, updateOverlay: (List<PointF>?) -> Unit)
}

// Default no-op edge detector (we still rely on OCR bounding boxes for overlay)
class OcrEdgeDetector : EdgeDetector {
    override fun onFrame(imageProxy: ImageProxy, updateOverlay: (List<PointF>?) -> Unit) {
        // No-op; overlay is updated after OCR in CardScanActivity
    }
}

