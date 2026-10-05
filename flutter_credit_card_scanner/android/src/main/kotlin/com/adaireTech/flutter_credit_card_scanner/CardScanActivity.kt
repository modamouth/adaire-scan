package com.adaireTech.flutter_credit_card_scanner

import android.Manifest
import android.content.Intent
import android.content.Context
import android.content.pm.PackageManager
import android.content.pm.ApplicationInfo
import android.graphics.PointF
import android.graphics.Rect
import android.graphics.RectF
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.util.Size
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.TextView
import android.view.Gravity
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CameraCharacteristics
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.core.Camera
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import java.util.concurrent.Executors
import kotlin.math.min
import java.util.Calendar

// OpenCV
// OpenCV removed (fallback uses OCR boxes)

class CardScanActivity : AppCompatActivity() {
    private lateinit var previewView: PreviewView
    private lateinit var overlayView: CardOverlayView
    private lateinit var debugText: TextView
    private lateinit var flashBtn: TextView
    private val executor = Executors.newSingleThreadExecutor()
    private var handler: Handler = Handler(Looper.getMainLooper())
    private var timedOut = false
    private var torchOn = false
    private var camera: Camera? = null

    private var scanExpiry: Boolean = true
    private var scanName: Boolean = false
    private var restrictBrand: String? = null
    private var timeoutMs: Int = 0
    private var debugEnabled: Boolean = false
    private var showQuadOverlay: Boolean = false
    private var lastLoggedSnippet: String? = null
    private var lastLoggedDecision: String? = null
    private var lastDecisionLogMs: Long = 0L
    private var edgeDetector: EdgeDetector = OcrEdgeDetector()
    private val recentCandidates = ArrayDeque<String>()
    private var stableCandidate: String? = null
    private var stableCount: Int = 0
    @Volatile private var ocrInProgress: Boolean = false
    @Volatile private var lastOcrMs: Long = 0L
    private val ocrMinIntervalMs: Long = 220
    private val sixteenBuffer = ArrayDeque<String>()
    private val consensusWindow = 7
    private var cropToGuideEnabled: Boolean = false
    private var consensusRequiredFrames: Int = 3
    private var stabilityRequiredFrames: Int = 2

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // No OpenCV init required when using OCR-based overlay

        scanExpiry = intent.getBooleanExtra(EXTRA_SCAN_EXPIRY, true)
        scanName = intent.getBooleanExtra(EXTRA_SCAN_NAME, false)
        restrictBrand = intent.getStringExtra(EXTRA_RESTRICT_BRAND)?.lowercase()
        timeoutMs = intent.getIntExtra(EXTRA_TIMEOUT_MS, 0)
        debugEnabled = intent.getBooleanExtra(EXTRA_DEBUG, false)
        showQuadOverlay = intent.getBooleanExtra(EXTRA_SHOW_QUAD, false)
        cropToGuideEnabled = intent.getBooleanExtra(EXTRA_CROP_TO_GUIDE, false)
        consensusRequiredFrames = intent.getIntExtra(EXTRA_CONSENSUS_REQUIRED, 3)
        stabilityRequiredFrames = intent.getIntExtra(EXTRA_STABILITY_REQUIRED, 2)

        previewView = PreviewView(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }
        overlayView = CardOverlayView(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }
        debugText = TextView(this).apply {
            text = ""
            setTextColor(0xFFFFFFFF.toInt())
            setBackgroundColor(0x66000000)
            textSize = 12f
            setPadding(16, 12, 16, 12)
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply { gravity = Gravity.BOTTOM }
            visibility = if (debugEnabled) TextView.VISIBLE else TextView.GONE
        }
        val root = FrameLayout(this).apply {
            addView(previewView)
            addView(overlayView)
            addView(debugText)
        }

        // Flash toggle button (top-right)
        flashBtn = TextView(this).apply {
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
                setTorch(torchOn)
                text = if (torchOn) "Flash On" else "Flash"
            }
        }
        root.addView(flashBtn)
        setContentView(root)

        if (hasCameraPermission()) {
            startCamera()
        } else {
            requestPermissionLauncher.launch(Manifest.permission.CAMERA)
        }

        if (timeoutMs > 0) {
            handler.postDelayed({
                timedOut = true
                setResult(RESULT_TIMEOUT)
                finish()
            }, timeoutMs.toLong())
        }

        // Try to enable OpenCV-based edge detection if present
        try {
            val cls = Class.forName("com.adaireTech.flutter_credit_card_scanner.OpenCvEdgeDetector")
            val inst = cls.getConstructor().newInstance() as EdgeDetector
            inst.init(this)
            edgeDetector = inst
            if (debugEnabled) Log.d("CardScan", "Using OpenCV edge detector")
        } catch (_: Throwable) {
            if (debugEnabled) Log.d("CardScan", "Using OCR-based overlay edge detector")
        }
    }

    private fun logDecisionThrottled(message: String) {
        if (!debugEnabled) return
        val now = System.currentTimeMillis()
        val tooSoon = (now - lastDecisionLogMs) < 450
        if (tooSoon && lastLoggedDecision == message) return
        lastDecisionLogMs = now
        lastLoggedDecision = message
        Log.d("CardScan", message)
    }

    private fun hasCameraPermission(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED

    private val requestPermissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            if (granted) startCamera() else {
                setResult(RESULT_CANCELED)
                finish()
            }
        }

    private fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)
        cameraProviderFuture.addListener({
            val cameraProvider = cameraProviderFuture.get()
            val preview = Preview.Builder().build().also {
                it.setSurfaceProvider(previewView.surfaceProvider)
            }

            val analysis = ImageAnalysis.Builder()
                .setTargetResolution(Size(1920, 1080))
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build()

            val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
            analysis.setAnalyzer(executor) { imageProxy ->
                // Optional OpenCV edge detection only when overlay is requested
                if (showQuadOverlay) {
                    try {
                        edgeDetector.onFrame(imageProxy) { quad ->
                            if (quad == null) {
                                handler.post { overlayView.setDetectedQuad(null) }
                            } else {
                                val rot = imageProxy.imageInfo.rotationDegrees
                                val srcW = if (rot % 180 == 0) imageProxy.width.toFloat() else imageProxy.height.toFloat()
                                val srcH = if (rot % 180 == 0) imageProxy.height.toFloat() else imageProxy.width.toFloat()
                                val dstW = overlayView.width.toFloat().coerceAtLeast(1f)
                                val dstH = overlayView.height.toFloat().coerceAtLeast(1f)
                                val sx = dstW / srcW
                                val sy = dstH / srcH
                                val mapped = quad.map { p -> PointF(p.x * sx, p.y * sy) }
                                handler.post { overlayView.setDetectedQuad(mapped) }
                            }
                        }
                    } catch (_: Throwable) { /* ignore */ }
                }

                // Throttle OCR: drop frame if OCR running or interval not elapsed
                val now = System.currentTimeMillis()
                if (ocrInProgress || (now - lastOcrMs) < ocrMinIntervalMs) {
                    imageProxy.close()
                    return@setAnalyzer
                }
                ocrInProgress = true
                processImageProxy(recognizer, imageProxy, now)
            }

            val selector = CameraSelector.DEFAULT_BACK_CAMERA
            try {
                cameraProvider.unbindAll()
            } catch (_: Exception) {}
            try {
                camera = cameraProvider.bindToLifecycle(this, selector, preview, analysis)
            } catch (_: Exception) {
                setResult(RESULT_ERROR, intentWithError("Failed to bind camera"))
                finish()
            }
        }, ContextCompat.getMainExecutor(this))
    }

    private fun processImageProxy(
        recognizer: com.google.mlkit.vision.text.TextRecognizer,
        imageProxy: ImageProxy,
        startedAtMs: Long
    ) {
        val mediaImage = imageProxy.image
        if (mediaImage == null) {
            imageProxy.close(); return
        }
        val image = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)
        if (cropToGuideEnabled) {
            computeCropRect(imageProxy)?.let { rect ->
                if (rect.width() > 10 && rect.height() > 10) {
                    try {
                        val m = image.javaClass.getMethod("setCropRect", android.graphics.Rect::class.java)
                        m.invoke(image, rect)
                    } catch (_: Throwable) {
                        if (debugEnabled) Log.d("CardScan", "InputImage.setCropRect unavailable; skipping crop")
                    }
                }
            }
        }
        recognizer.process(image)
            .addOnSuccessListener { visionText ->
                // Build raw text only from blocks intersecting the guide rect
                val filteredRaw = buildFilteredRawText(visionText, imageProxy)
                val raw = filteredRaw ?: ""
                if (debugEnabled) {
                    if (raw.isNotBlank() && shouldLogRaw(raw)) {
                        val snippet = buildLogSnippet(raw)
                        if (snippet.isNotEmpty() && snippet != lastLoggedSnippet) {
                            Log.d("CardScan", "MLKit raw text: $snippet")
                            lastLoggedSnippet = snippet
                        }
                        val preview = raw.lines().filter { it.isNotBlank() }.take(3).joinToString(" | ")
                        handler.post { debugText.text = preview }
                    } else {
                        handler.post { debugText.text = "" }
                    }
                }
                val cleaned = normalizeDigits(raw).replace(" ", "").replace("-", "")
                if (debugEnabled) {
                    val rawDigitsLen = raw.count { it.isDigit() }
                    logDecisionThrottled(
                        "OCR ok: blocks=${visionText.textBlocks.size} rawLen=${raw.length} rawDigits=$rawDigitsLen cleanedDigits=${cleaned.count { it.isDigit() }} buf16=${sixteenBuffer.size}"
                    )
                }
                // Update overlay using OCR bounding boxes
                updateOverlayFromOcr(visionText, imageProxy)
                val preferredPrefix = if (raw.contains("visa", ignoreCase = true)) "4" else null
                // Add a raw 16-digit candidate (even if not Luhn) for consensus
                extractBestSixteenDigits(visionText, preferredPrefix)?.let {
                    addToSixteenBuffer(it)
                    if (debugEnabled) logDecisionThrottled("buf16 += $it (size=${sixteenBuffer.size})")
                }

                // Try consensus first; fallback to immediate Luhn candidate
                val consensus = consensusFromBuffer()
                val immediate = bestValidCardNumberFromVision(visionText, preferredPrefix)
                    ?: bestValidCardNumber(cleaned, preferredPrefix)
                val candidate = consensus ?: immediate
                if (debugEnabled) {
                    logDecisionThrottled(
                        "candidates: consensus=${consensus ?: "-"} immediate=${immediate ?: "-"} chosen=${candidate ?: "-"}"
                    )
                }
                if (candidate != null) {
                    val brand = detectBrand(candidate)
                    // If brand detection fails, still allow completion for a Luhn-valid PAN
                    // (unless the caller restricted the brand).
                    if (restrictBrand != null && brand != restrictBrand) {
                        logDecisionThrottled("reject: restrictBrand=$restrictBrand brand=$brand")
                        imageProxy.close()
                        return@addOnSuccessListener
                    }
                    val lengthOk = if (brand != null) {
                        lengthPlausibleForBrand(brand, candidate)
                    } else {
                        candidate.length in 12..19
                    }
                    if (lengthOk) {
                        val requireStable = (consensus == null)
                        if (requireStable && !updateStability(candidate, requiredCount = stabilityRequiredFrames)) {
                            // wait for stability
                            if (debugEnabled) {
                                logDecisionThrottled(
                                    "wait stability: candidate=$candidate stable=$stableCandidate stableCount=$stableCount required=$stabilityRequiredFrames"
                                )
                            }
                            imageProxy.close()
                            return@addOnSuccessListener
                        }
                        val exp = if (scanExpiry) parseExpirySmart(visionText, raw) else null
                        val name = if (scanName) extractLikelyName(raw) else null
                        if (debugEnabled) {
                            Log.d("CardScan", "Detected card: $candidate brand=$brand exp=$exp name=${name ?: "-"}")
                        }
                        val data = Intent().apply {
                            putExtra(EXTRA_RES_CARD_NUMBER, candidate)
                            if (exp != null) {
                                putExtra(EXTRA_RES_EXP_MONTH, exp.first)
                                putExtra(EXTRA_RES_EXP_YEAR, exp.second)
                            }
                            if (!name.isNullOrBlank()) putExtra(EXTRA_RES_NAME, name)
                            putExtra(EXTRA_RES_BRAND, brand)
                        }
                        setResult(RESULT_OK, data)
                        imageProxy.close()
                        finish()
                        return@addOnSuccessListener
                    } else if (debugEnabled) {
                        logDecisionThrottled("reject: length brand=$brand len=${candidate.length}")
                    }
                } else if (debugEnabled) {
                    // Useful when OCR succeeds but we never derive a plausible PAN.
                    logDecisionThrottled("no candidate derived (buf16=${sixteenBuffer.size})")
                }
                imageProxy.close()
            }
            .addOnFailureListener {
                lastOcrMs = startedAtMs
                ocrInProgress = false
                imageProxy.close()
            }
            .addOnSuccessListener {
                // ensure flags reset when success path returns
                lastOcrMs = startedAtMs
                ocrInProgress = false
            }
    }

    override fun onDestroy() {
        super.onDestroy()
        // Ensure torch is off when leaving
        setTorch(false)
    }

    private fun setTorch(on: Boolean) {
        // Try CameraX first if available
        camera?.cameraControl?.enableTorch(on)
        // Also attempt via CameraManager for broader device support
        try {
            val cm = getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val cameraId = cm.cameraIdList.firstOrNull { id ->
                cm.getCameraCharacteristics(id).get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_BACK
            }
            if (cameraId != null) {
                cm.setTorchMode(cameraId, on)
            }
        } catch (_: Exception) {
            // Ignore failures
        }
    }

    private fun buildFilteredRawText(visionText: com.google.mlkit.vision.text.Text, imageProxy: ImageProxy): String? {
        val blocks = visionText.textBlocks
        if (blocks.isEmpty()) return null
        val guide = guideRectInView()
        if (guide.width() <= 0 || guide.height() <= 0 || overlayView.width == 0 || overlayView.height == 0) {
            return visionText.text
        }
        val rot = imageProxy.imageInfo.rotationDegrees
        val srcW = if (rot % 180 == 0) imageProxy.width.toFloat() else imageProxy.height.toFloat()
        val srcH = if (rot % 180 == 0) imageProxy.height.toFloat() else imageProxy.width.toFloat()
        val dstW = overlayView.width.toFloat()
        val dstH = overlayView.height.toFloat()
        val sx = dstW / srcW
        val sy = dstH / srcH
        val imgRect = RectF(guide.left / sx, guide.top / sy, guide.right / sx, guide.bottom / sy)
        val sb = StringBuilder()
        for (b in blocks) {
            val r = b.boundingBox ?: continue
            val rf = RectF(r)
            if (RectF.intersects(imgRect, rf)) {
                sb.appendLine(b.text)
            }
        }
        val out = sb.toString().trim()
        return if (out.isEmpty()) visionText.text else out
    }

    private fun guideRectInView(): RectF {
        val w = overlayView.width.toFloat()
        val h = overlayView.height.toFloat()
        if (w <= 0f || h <= 0f) return RectF(0f, 0f, 0f, 0f)
        val padding = (minOf(w, h) * 0.1f)
        val availW = w - padding * 2
        val availH = h - padding * 2
        val cardAspect = 85.6f / 53.98f
        var frameW = availW
        var frameH = frameW / cardAspect
        if (frameH > availH) {
            frameH = availH
            frameW = frameH * cardAspect
        }
        val left = (w - frameW) / 2f
        val top = (h - frameH) / 2f
        return RectF(left, top, left + frameW, top + frameH)
    }

    private fun normalizeDigits(text: String): String {
        // Heuristic replacements for common OCR confusions
        return buildString(text.length) {
            for (ch in text) {
                append(
                    when (ch) {
                        'O', 'o', 'D' -> '0'
                        'I', 'l', '|' -> '1'
                        'Z' -> '2'
                        'S' -> '5'
                        'B' -> '8'
                        'G' -> '6'
                        'q' -> '9'
                        else -> ch
                    }
                )
            }
        }
    }

    private fun parseExpirySmart(
        visionText: com.google.mlkit.vision.text.Text,
        rawText: String
    ): Pair<Int, Int>? {
        val now = Calendar.getInstance()
        val currentYear = now.get(Calendar.YEAR)
        val maxYear = currentYear + 15

        fun valid(month: Int, year: Int): Boolean {
            if (month !in 1..12) return false
            if (year !in 2000..2099) return false
            if (year < currentYear - 1) return false
            if (year > maxYear) return false
            return true
        }

        val candidates = mutableListOf<Triple<Int, Int, Int>>()
        val keywords = listOf("exp", "expires", "valid", "thru", "until")
        val mmYY = Regex("(0[1-9]|1[0-2])\\s*[\\/\\-]?\\s*(2\\d{3}|\\d{2})")

        for (block in visionText.textBlocks) {
            for (line in block.lines) {
                val t = normalizeDigits(line.text)
                val hasKeyword = keywords.any { t.contains(it, ignoreCase = true) }
                for (m in mmYY.findAll(t)) {
                    val month = m.groupValues[1].toInt()
                    val yraw = m.groupValues[2]
                    val year = if (yraw.length == 2) 2000 + yraw.toInt() else yraw.toInt()
                    if (!valid(month, year)) continue
                    var score = 10
                    if (hasKeyword) score += 10
                    if (yraw.length == 2) score += 2
                    candidates.add(Triple(month, year, score))
                }
            }
        }

        if (candidates.isEmpty()) {
            val t = normalizeDigits(rawText)
            for (m in mmYY.findAll(t)) {
                val month = m.groupValues[1].toInt()
                val yraw = m.groupValues[2]
                val year = if (yraw.length == 2) 2000 + yraw.toInt() else yraw.toInt()
                if (!valid(month, year)) continue
                candidates.add(Triple(month, year, 5))
            }
        }

        val best = candidates.maxByOrNull { it.third } ?: return null
        return Pair(best.first, best.second)
    }

    private fun bestValidCardNumber(text: String, preferredPrefix: String? = null): String? {
        // Prefer 16-digit candidates; fallback to any Luhn-valid 12..19
        val regex = Regex("\\d{12,19}")
        val matches = regex.findAll(text).map { it.value }.toList()
        var best: String? = null
        var bestScore = -1
        for (m in matches) {
            if (!luhnIsValid(m)) continue
            val len = m.length
            var score = if (len == 16) 100 else (100 - kotlin.math.abs(16 - len) * 10)
            if (preferredPrefix != null && m.startsWith(preferredPrefix)) score += 5
            if (score > bestScore) { bestScore = score; best = m }
        }
        return best
    }

    private fun bestValidCardNumberFromVision(
        visionText: com.google.mlkit.vision.text.Text,
        preferredPrefix: String?
    ): String? {
        val candidates = mutableListOf<String>()
        val mmYY = Regex("(0[1-9]|1[0-2])\\s*[\\/\\-]?\\s*(\\d{2})$")
        for (block in visionText.textBlocks) {
            for (line in block.lines) {
                val tNorm = normalizeDigits(line.text)
                // Extract digits in reading order
                val digits = tNorm.filter { it.isDigit() }
                var d = digits
                // If line ends with something that looks like MMYY, trim it (likely expiry)
                if (digits.length >= 18) {
                    val tail4 = digits.takeLast(4)
                    val mo = tail4.substring(0,2).toIntOrNull()
                    val yr = tail4.substring(2,4).toIntOrNull()
                    if (mo != null && yr != null && mo in 1..12) {
                        d = digits.dropLast(4)
                    }
                }
                if (d.length in 13..19) {
                    candidates.add(d)
                }
                // Also look for spaced groups of 4
                val group4 = Regex("(?:\\d{4}[\\s\\-]?){3}\\d{4}")
                val g = group4.find(tNorm)
                if (g != null) {
                    candidates.add(g.value.filter { it.isDigit() })
                }
            }
        }
        // Score and select
        var best: String? = null
        var bestScore = -1
        for (c in candidates) {
            if (!luhnIsValid(c)) continue
            var score = if (c.length == 16) 120 else (90 - kotlin.math.abs(16 - c.length) * 10)
            if (preferredPrefix != null && c.startsWith(preferredPrefix)) score += 10
            if (score > bestScore) { bestScore = score; best = c }
        }
        return best
    }

    private fun extractBestSixteenDigits(
        visionText: com.google.mlkit.vision.text.Text,
        preferredPrefix: String?
    ): String? {
        val cands = mutableListOf<String>()
        for (block in visionText.textBlocks) {
            for (line in block.lines) {
                val tNorm = normalizeDigits(line.text)
                val digits = tNorm.filter { it.isDigit() }
                var d = digits
                if (digits.length >= 20) {
                    // Trim likely MMYY tail
                    val tail4 = digits.takeLast(4)
                    val mo = tail4.substring(0,2).toIntOrNull()
                    val yr = tail4.substring(2,4).toIntOrNull()
                    if (mo != null && yr != null && mo in 1..12) {
                        d = digits.dropLast(4)
                    }
                }
                // Gather sliding windows of length 16
                if (d.length >= 16) {
                    for (i in 0..(d.length - 16)) {
                        cands.add(d.substring(i, i+16))
                    }
                }
                // Grouped pattern 4-4-4-4
                val group4 = Regex("(?:\\d{4}[\\s\\-]?){3}\\d{4}")
                group4.findAll(tNorm).forEach { m -> cands.add(m.value.filter { it.isDigit() }) }
            }
        }
        if (cands.isEmpty()) return null
        var best: String? = null
        var bestScore = -1
        for (c in cands) {
            if (c.length != 16) continue
            var score = 10
            if (preferredPrefix != null && c.startsWith(preferredPrefix)) score += 5
            // Favor having 4-4-4-4 grouping in original (approx by checking non-digit separators every 4, not available here) -> skip
            // Use simple heuristic: more unique digits suggest less repetition noise
            score += c.toSet().size
            if (score > bestScore) { bestScore = score; best = c }
        }
        return best
    }

    private fun addToSixteenBuffer(s: String) {
        if (s.length != 16) return
        sixteenBuffer.addLast(s)
        while (sixteenBuffer.size > consensusWindow) sixteenBuffer.removeFirst()
    }

    private fun consensusFromBuffer(): String? {
        if (sixteenBuffer.size < consensusRequiredFrames) return null
        val positions = Array(16) { IntArray(10) }
        for (c in sixteenBuffer) {
            if (c.length != 16) continue
            for (i in 0 until 16) {
                val d = c[i]
                if (d in '0'..'9') positions[i][d - '0']++
            }
        }
        val sb = StringBuilder(16)
        for (i in 0 until 15) { // first 15 digits determine check digit
            val counts = positions[i]
            var maxIdx = 0
            var maxVal = -1
            for (k in 0..9) { if (counts[k] > maxVal) { maxVal = counts[k]; maxIdx = k } }
            sb.append(('0'.code + maxIdx).toChar())
        }
        // Compute Luhn check for last digit
        val check = luhnCheckDigit(sb.toString())
        sb.append(check)
        val consensus = sb.toString()
        return if (luhnIsValid(consensus)) consensus else null
    }

    private fun luhnCheckDigit(first15: String): Char {
        var sum = 0
        var alt = true // since we're computing check for 16th digit, start alternation as if appending last
        for (i in (first15.length - 1) downTo 0) {
            var n = first15[i] - '0'
            if (alt) { n *= 2; if (n > 9) n -= 9 }
            sum += n
            alt = !alt
        }
        val mod = sum % 10
        val check = if (mod == 0) 0 else 10 - mod
        return ('0'.code + check).toChar()
    }

    private fun lengthPlausibleForBrand(brand: String, pan: String): Boolean {
        val len = pan.length
        return when (brand) {
            "visa" -> len == 16 || len == 19
            "mastercard" -> len == 16
            "amex" -> len == 15
            "discover" -> len == 16 || len == 19
            "diners" -> len == 14 || len == 16
            "jcb" -> len in 16..19
            "unionpay" -> len in 16..19
            else -> len in 15..19
        }
    }

    private fun updateStability(candidate: String, requiredCount: Int = 2): Boolean {
        // Require N consecutive matches for acceptance
        if (stableCandidate == candidate) {
            stableCount += 1
        } else {
            stableCandidate = candidate
            stableCount = 1
        }
        recentCandidates.addLast(candidate)
        while (recentCandidates.size > 5) recentCandidates.removeFirst()
        return stableCount >= requiredCount
    }

    private fun updateOverlayFromOcr(visionText: com.google.mlkit.vision.text.Text, imageProxy: ImageProxy) {
        val boxes = visionText.textBlocks.mapNotNull { it.boundingBox }
        if (boxes.isEmpty()) {
            handler.post { overlayView.setDetectedQuad(null) }
            return
        }
        var left = Int.MAX_VALUE
        var top = Int.MAX_VALUE
        var right = Int.MIN_VALUE
        var bottom = Int.MIN_VALUE
        for (r in boxes) {
            if (r.left < left) left = r.left
            if (r.top < top) top = r.top
            if (r.right > right) right = r.right
            if (r.bottom > bottom) bottom = r.bottom
        }
        val rot = imageProxy.imageInfo.rotationDegrees
        val srcW = if (rot % 180 == 0) imageProxy.width.toFloat() else imageProxy.height.toFloat()
        val srcH = if (rot % 180 == 0) imageProxy.height.toFloat() else imageProxy.width.toFloat()
        val dstW = overlayView.width.toFloat().coerceAtLeast(1f)
        val dstH = overlayView.height.toFloat().coerceAtLeast(1f)
        val sx = dstW / srcW
        val sy = dstH / srcH

        val tl = PointF(left * sx, top * sy)
        val tr = PointF(right * sx, top * sy)
        val br = PointF(right * sx, bottom * sy)
        val bl = PointF(left * sx, bottom * sy)
        handler.post {
            if (showQuadOverlay) overlayView.setDetectedQuad(listOf(tl, tr, br, bl)) else overlayView.setDetectedQuad(null)
        }
    }

    private fun computeCropRect(imageProxy: ImageProxy): Rect? {
        val guide = guideRectInView()
        if (guide.width() <= 0 || guide.height() <= 0 || overlayView.width == 0 || overlayView.height == 0) return null
        val rot = imageProxy.imageInfo.rotationDegrees
        val srcW = if (rot % 180 == 0) imageProxy.width.toFloat() else imageProxy.height.toFloat()
        val srcH = if (rot % 180 == 0) imageProxy.height.toFloat() else imageProxy.width.toFloat()
        val dstW = overlayView.width.toFloat()
        val dstH = overlayView.height.toFloat()
        val sx = dstW / srcW
        val sy = dstH / srcH
        val left = (guide.left / sx).toInt().coerceIn(0, srcW.toInt())
        val top = (guide.top / sy).toInt().coerceIn(0, srcH.toInt())
        val right = (guide.right / sx).toInt().coerceIn(0, srcW.toInt())
        val bottom = (guide.bottom / sy).toInt().coerceIn(0, srcH.toInt())
        val r = Rect(left, top, right, bottom)
        return if (r.width() > 0 && r.height() > 0) r else null
    }

    private fun shouldLogRaw(raw: String): Boolean {
        val compact = raw.replace(" ", "")
        val hasDigits = Regex("\\d{6,}").containsMatchIn(compact)
        val keywords = listOf("visa", "mastercard", "amex", "discover", "expires", "valid", "card")
        val hasKeyword = keywords.any { raw.contains(it, ignoreCase = true) }
        return hasDigits || hasKeyword
    }

    private fun buildLogSnippet(raw: String): String {
        val digitsOnly = raw.filter { it.isDigit() }
        if (digitsOnly.length >= 12) return digitsOnly.take(32)
        val lines = raw.lines().filter { it.isNotBlank() }
        return lines.joinToString(" | ").take(80)
    }

    // No-op: runtime debug controlled by EXTRA_DEBUG

    // Keep overlay driven by OCR boxes when OpenCV is unavailable

    private fun firstValidCardNumber(text: String): String? {
        val regex = Regex("\\d{12,19}")
        val matches = regex.findAll(text)
        for (m in matches) {
            val candidate = m.value
            if (luhnIsValid(candidate)) return candidate
        }
        return null
    }

    private fun luhnIsValid(number: String): Boolean {
        var sum = 0
        var alt = false
        for (i in number.length - 1 downTo 0) {
            var n = number[i] - '0'
            if (alt) {
                n *= 2
                if (n > 9) n -= 9
            }
            sum += n
            alt = !alt
        }
        return sum % 10 == 0
    }

    private fun detectBrand(number: String): String? {
        return when {
            number.startsWith("4") -> "visa"
            number.startsWith("34") || number.startsWith("37") -> "amex"
            number.startsWith("6011") || number.startsWith("65") || (number.length >= 3 && number.substring(0,3).toIntOrNull() in 640..649) -> "discover"
            number.startsWith("35") -> "jcb"
            number.startsWith("62") -> "unionpay"
            number.length >= 2 && number.substring(0,2).toIntOrNull() in 51..55 -> "mastercard"
            number.length >= 4 && number.substring(0,4).toIntOrNull() in 2221..2720 -> "mastercard"
            number.startsWith("36") || number.startsWith("38") || number.startsWith("39") || number.startsWith("300") || number.startsWith("301") || number.startsWith("302") || number.startsWith("303") || number.startsWith("304") || number.startsWith("305") -> "diners"
            else -> null
        }
    }

    private fun parseExpiry(text: String): Pair<Int, Int>? {
        val regex = Regex("(?:0[1-9]|1[0-2])[\\/\\- ]?(?:2[0-9]{3}|[0-9]{2})")
        val match = regex.find(text)
        val raw = match?.value ?: return null
        val cleaned = raw.replace(" ", "").replace("-", "/")
        val parts = cleaned.split('/')
        if (parts.size != 2) return null
        val month = parts[0].toIntOrNull() ?: return null
        var yearStr = parts[1]
        if (yearStr.length == 2) yearStr = "20$yearStr"
        val year = yearStr.toIntOrNull() ?: return null
        return Pair(month, year)
    }

    private fun extractLikelyName(text: String): String? {
        val words = text.split(' ', '\n').filter { it.isNotBlank() }
        val caps = words.filter { it.length in 2..26 && it.uppercase() == it && it.any { ch -> ch.isLetter() } }
        return if (caps.size >= 2) caps[0] + " " + caps[1] else null
    }

    private fun intentWithError(message: String) = Intent().apply { putExtra(EXTRA_RES_ERROR, message) }

    companion object {
        // Inputs
        const val EXTRA_SCAN_EXPIRY = "scanExpiry"
        const val EXTRA_SCAN_NAME = "scanName"
        const val EXTRA_RESTRICT_BRAND = "restrictBrand"
        const val EXTRA_TIMEOUT_MS = "timeoutMs"
        const val EXTRA_DEBUG = "debug"
        const val EXTRA_SHOW_QUAD = "showDetectedQuad"
        const val EXTRA_CROP_TO_GUIDE = "cropToGuide"
        const val EXTRA_CONSENSUS_REQUIRED = "consensusRequired"
        const val EXTRA_STABILITY_REQUIRED = "stabilityRequired"
        // Outputs
        const val EXTRA_RES_CARD_NUMBER = "cardNumber"
        const val EXTRA_RES_EXP_MONTH = "expiryMonth"
        const val EXTRA_RES_EXP_YEAR = "expiryYear"
        const val EXTRA_RES_NAME = "cardholderName"
        const val EXTRA_RES_BRAND = "cardBrand"
        const val EXTRA_RES_ERROR = "error"

        const val RESULT_TIMEOUT = 7001
        const val RESULT_ERROR = 7002
    }
}
