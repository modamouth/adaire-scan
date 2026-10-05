package com.adaireTech.flutter_credit_card_scanner

import android.content.Context
import android.graphics.*
import android.util.AttributeSet
import android.view.View

class CardOverlayView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    private val maskPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#99000000") // semi-transparent mask
    }

    private val framePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 5f
        color = Color.WHITE
    }

    private val cornerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 8f
        color = Color.parseColor("#4CAF50")
        strokeCap = Paint.Cap.ROUND
    }

    private val detectedPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 6f
        color = Color.parseColor("#FF9800")
    }

    private val path = Path()
    private val guideRect = RectF()

    // Detected quadrilateral corners in view coordinates (clockwise)
    private var quad: List<PointF>? = null

    // 85.6mm x 53.98mm aspect ratio ≈ 1.586
    private val cardAspect = 85.6f / 53.98f

    fun setDetectedQuad(points: List<PointF>?) {
        quad = points
        invalidate()
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        computeGuideRect(w, h)
    }

    private fun computeGuideRect(w: Int, h: Int) {
        if (w == 0 || h == 0) return
        // Take up ~80% of the min dimension respecting card aspect ratio
        val padding = (minOf(w, h) * 0.1f)
        val availW = w - padding * 2
        val availH = h - padding * 2

        var frameW = availW
        var frameH = frameW / cardAspect
        if (frameH > availH) {
            frameH = availH
            frameW = frameH * cardAspect
        }
        val left = (w - frameW) / 2f
        val top = (h - frameH) / 2f
        guideRect.set(left, top, left + frameW, top + frameH)
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        // Mask outside of guide rect
        path.reset()
        path.addRect(0f, 0f, width.toFloat(), height.toFloat(), Path.Direction.CW)
        path.addRoundRect(guideRect, 24f, 24f, Path.Direction.CCW)
        canvas.drawPath(path, maskPaint)

        // Draw guide frame
        canvas.drawRoundRect(guideRect, 24f, 24f, framePaint)
        drawCorners(canvas)

        // Draw detected quad if available
        quad?.let { pts ->
            if (pts.size == 4) {
                val p0 = pts[0]; val p1 = pts[1]; val p2 = pts[2]; val p3 = pts[3]
                canvas.drawLine(p0.x, p0.y, p1.x, p1.y, detectedPaint)
                canvas.drawLine(p1.x, p1.y, p2.x, p2.y, detectedPaint)
                canvas.drawLine(p2.x, p2.y, p3.x, p3.y, detectedPaint)
                canvas.drawLine(p3.x, p3.y, p0.x, p0.y, detectedPaint)
            }
        }
    }

    private fun drawCorners(canvas: Canvas) {
        val cornerLen = minOf(guideRect.width(), guideRect.height()) * 0.06f
        // Top-left
        canvas.drawLine(guideRect.left, guideRect.top, guideRect.left + cornerLen, guideRect.top, cornerPaint)
        canvas.drawLine(guideRect.left, guideRect.top, guideRect.left, guideRect.top + cornerLen, cornerPaint)
        // Top-right
        canvas.drawLine(guideRect.right, guideRect.top, guideRect.right - cornerLen, guideRect.top, cornerPaint)
        canvas.drawLine(guideRect.right, guideRect.top, guideRect.right, guideRect.top + cornerLen, cornerPaint)
        // Bottom-left
        canvas.drawLine(guideRect.left, guideRect.bottom, guideRect.left + cornerLen, guideRect.bottom, cornerPaint)
        canvas.drawLine(guideRect.left, guideRect.bottom, guideRect.left, guideRect.bottom - cornerLen, cornerPaint)
        // Bottom-right
        canvas.drawLine(guideRect.right, guideRect.bottom, guideRect.right - cornerLen, guideRect.bottom, cornerPaint)
        canvas.drawLine(guideRect.right, guideRect.bottom, guideRect.right, guideRect.bottom - cornerLen, cornerPaint)
    }
}

