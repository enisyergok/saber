package com.adilhanney.saber

import android.app.Activity
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.PorterDuff
import android.graphics.RectF
import android.graphics.RuntimeShader
import android.hardware.HardwareBuffer
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.SystemClock
import android.view.MotionEvent
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import java.io.File
import androidx.annotation.RequiresApi
import androidx.graphics.lowlatency.LowLatencyCanvasView
import androidx.input.motionprediction.MotionEventPredictor
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicReference
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

/// Draws the line of a pen stroke straight to the screen while it is being
/// written, on a layer of its own above the app.
///
/// The app's own drawing goes through several steps (the input is handed to
/// Dart, the picture is built, drawn on another thread, and shown on the
/// next screen refresh), and the ink is that many frames behind the pen.
/// Here the pen's points are drawn the moment they arrive, on a thread of
/// their own.
///
/// Two ways of drawing, the first one that works is used:
///  1. Front buffer (Android 10+, androidx.graphics LowLatencyCanvasView):
///     the points are drawn into the very buffer the screen is showing, so
///     they skip the queue of buffers waiting to be shown (two or three
///     refreshes). This is what the low latency note apps do.
///  2. A plain surface of its own above the app (the earlier way): one
///     refresh behind at most. Used where the front buffer can't be made or
///     never draws.
///
/// Optionally (on by default) the line is drawn a little ahead of the pen:
/// a Kalman filter (androidx.input motionprediction) guesses where the pen
/// will be when the picture reaches the screen, at most 32 ms ahead, less
/// when the pen turns or slows down. That guessed piece is only shown on
/// this layer: it is wiped and drawn again with every new point, taken away
/// when the pen lifts, and never becomes part of the saved stroke.
///
/// The app draws the finished stroke itself, and then has this layer
/// cleared. Everything is optional: without a layer, or with the option off,
/// nothing here does anything and the app draws as it always did. Input
/// events are only looked at, never consumed or changed.
class InkOverlay(private val activity: Activity) {
    private companion object {
        /// HardwareBuffer.USAGE_COMPOSER_OVERLAY (public from Android 13,
        /// understood long before; androidx.graphics uses it the same way).
        const val usageComposerOverlay = 2048L

        /// The name androidx.graphics gives the front buffer's thread.
        const val frontThreadName = "LowLatencyCanvasThread"

        // Android's RuntimeShader version of the capsule SDF. The Canvas
        // fallback above remains active on Android 9 and earlier.
        const val CAPSULE_SHADER = """
            uniform float2 uStart;
            uniform float2 uEnd;
            uniform float uRadiusStart;
            uniform float uRadiusEnd;
            uniform half4 uColor;

            half4 main(float2 p) {
                float2 ab = uEnd - uStart;
                float denominator = max(dot(ab, ab), 0.0001);
                float t = clamp(dot(p - uStart, ab) / denominator, 0.0, 1.0);
                float radius = mix(uRadiusStart, uRadiusEnd, t);
                float distanceToInk = distance(p, uStart + ab * t) - radius;
                half alpha = 1.0 - smoothstep(-1.0, 1.0, distanceToInk);
                return half4(uColor.rgb, uColor.a * alpha);
            }
        """

        var watching = false
    }

    /// How the next stroke is drawn, as the app has set up the pen.
    class Config(
        val color: Int,
        /// The pen's width in screen pixels (the diameter at half pressure).
        val sizePx: Float,
        val thinning: Float,
        /// How long (in pixels) the start of the stroke tapers; 0 for none.
        val taperPx: Float,
        /// The pressure the line is drawn with for 17 raw pressures, 0..1.
        val pressure: FloatArray,
        /// Where on the screen strokes can begin.
        val left: Float,
        val top: Float,
        val right: Float,
        val bottom: Float,
        /// Whether to draw the guessed piece ahead of the pen.
        val predict: Boolean,
        /// Huawei's stylus wrapper exposes a bounded point budget. Zero keeps
        /// the generic predictor behaviour; positive values bound preview
        /// points only and never alter the saved stroke.
        val predictionPointLimit: Int,
    )

    private class Segment(
        val x0: Float, val y0: Float, val r0: Float,
        val x1: Float, val y1: Float, val r1: Float,
        val color: Int,
        /// When the pen was at the end point (uptime, milliseconds).
        val at: Long,
        /// Whether this is the first piece of a new stroke.
        val first: Boolean,
    ) {
        val left = min(x0 - r0, x1 - r1) - 2f
        val top = min(y0 - r0, y1 - r1) - 2f
        val right = max(x0 + r0, x1 + r1) + 2f
        val bottom = max(y0 + r0, y1 + r1) + 2f
    }

    /// The guessed piece ahead of the pen: a polyline starting at the
    /// pen's last real point, drawn at one width.
    private class Prediction(val points: FloatArray, val radius: Float, val color: Int) {
        val count get() = points.size / 2
        fun bounds(into: RectF) {
            into.setEmpty()
            if (count == 0) return
            var l = Float.MAX_VALUE
            var t = Float.MAX_VALUE
            var r = -Float.MAX_VALUE
            var b = -Float.MAX_VALUE
            for (i in 0 until count) {
                l = min(l, points[2 * i])
                t = min(t, points[2 * i + 1])
                r = max(r, points[2 * i])
                b = max(b, points[2 * i + 1])
            }
            val pad = radius + 2f
            into.set(l - pad, t - pad, r + pad, b + pad)
        }
    }

    /// Where the drawing ends up: the front buffer or a plain surface.
    private interface Backend {
        val view: View
        /// Name for the latency report.
        val frontBuffer: Boolean
        /// Asks for the pending points to be drawn (main thread).
        fun requestDraw()
        /// Wipes the layer (main thread).
        fun clear()
        /// Runs [block] on the thread that draws.
        fun onDrawThread(block: () -> Unit)
        fun release()
    }

    @Volatile private var config: Config? = null
    private var backend: Backend? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private val pending = ConcurrentLinkedQueue<Segment>()
    private val noPrediction = Prediction(FloatArray(0), 0f, 0)
    private val prediction = AtomicReference(noPrediction)

    // The stroke being written (touched only from the main thread).
    private var active = false
    private var stroke: Config? = null
    private var penId = -1
    private var lastX = 0f
    private var lastY = 0f
    private var lastRadius = 0f
    private var run = 0f
    private var nextIsFirst = false
    /// Added to the event's coordinates to get the layer's.
    private var shiftX = 0f
    private var shiftY = 0f

    private var predictor: MotionEventPredictor? = null

    // How the front buffer is doing: asked to draw, and how often it did.
    private val frontRequests = AtomicInteger(0)
    private val frontDraws = AtomicInteger(0)
    private var silentStrokes = 0

    // -- drawing state (touched only on the drawing thread) ------------------

    private val strokeSegments = ArrayList<Segment>()
    private var drawnPrediction = noPrediction
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val capsuleShader: RuntimeShader? by lazy {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            RuntimeShader(CAPSULE_SHADER)
        } else {
            null
        }
    }
    private val path = Path()
    private val dirty = RectF()
    private val scratch = RectF()

    /// Sets how strokes are drawn, or turns the overlay off (null). Returns
    /// whether it can draw.
    fun setConfig(next: Config?): Boolean {
        config = next
        if (next == null) return backend != null
        if (backend == null) create()
        return backend != null
    }

    private fun create() {
        backend = (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) makeFrontBackend() else null)
            ?: makeSurfaceBackend()
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun makeFrontBackend(): Backend? {
        if (frontCrashed()) {
            frontUnsupported = true
            return null
        }
        return try {
            // The buffer kind the front buffer is drawn into (as
            // androidx.graphics asks for it): if the device can't make it,
            // the front buffer can't work here.
            @Suppress("WrongConstant")
            val usage = HardwareBuffer.USAGE_GPU_SAMPLED_IMAGE or
                HardwareBuffer.USAGE_GPU_COLOR_OUTPUT or
                usageComposerOverlay
            if (!HardwareBuffer.isSupported(1, 1, HardwareBuffer.RGBA_8888, 1, usage)) {
                frontUnsupported = true
                return null
            }
            watchFrontThread()
            FrontBackend().also { attach(it.view) }
        } catch (_: Throwable) {
            frontUnsupported = true
            null
        }
    }

    /// Marks the front buffer as broken on this device if its drawing
    /// thread ever crashes the app, so that from the next start on the
    /// plain surface is used (the crash itself is still recorded by
    /// [CrashLog]).
    private fun watchFrontThread() {
        if (watching) return
        watching = true
        val marker = frontCrashFile()
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            if (thread.name.startsWith(frontThreadName)) {
                try {
                    marker.writeText(error.javaClass.name)
                } catch (_: Throwable) {
                }
            }
            previous?.uncaughtException(thread, error)
        }
    }

    private fun frontCrashFile() = File(activity.filesDir, "ink_front_buffer_crashed")

    private fun frontCrashed(): Boolean = try {
        frontCrashFile().exists()
    } catch (_: Throwable) {
        false
    }

    private fun makeSurfaceBackend(): Backend? = try {
        SurfaceBackend().also { attach(it.view) }
    } catch (_: Throwable) {
        null
    }

    private fun attach(view: View) {
        view.isClickable = false
        view.isFocusable = false
        view.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        activity.addContentView(
            view,
            ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )
    }

    /// The front buffer was asked to draw over two whole strokes and never
    /// did (the device doesn't support it): use the plain surface instead.
    private fun fallBackToSurface() {
        val old = backend ?: return
        if (!old.frontBuffer) return
        try {
            old.release()
            (old.view.parent as? ViewGroup)?.removeView(old.view)
        } catch (_: Throwable) {
        }
        frontUnsupported = true
        backend = makeSurfaceBackend()
    }

    @Volatile private var frontUnsupported = false

    private fun pressureOf(config: Config, raw: Float): Float {
        val table = config.pressure
        if (table.isEmpty()) return 0.5f
        if (table.size == 1) return table[0]
        val at = raw.coerceIn(0f, 1f) * (table.size - 1)
        val i = at.toInt().coerceAtMost(table.size - 2).coerceAtLeast(0)
        val f = at - i
        return table[i] * (1 - f) + table[i + 1] * f
    }

    private fun radiusAt(config: Config, rawPressure: Float, run: Float): Float {
        val p = pressureOf(config, rawPressure)
        var r = if (config.thinning != 0f) {
            config.sizePx * (0.5f - config.thinning * (0.5f - p))
        } else {
            config.sizePx / 2f
        }
        if (config.taperPx > 0f && run < config.taperPx) r *= run / config.taperPx
        return max(0.5f, r)
    }

    /// Looks at a touch event on its way to the app. Never consumes it.
    fun onTouch(event: MotionEvent) {
        val config = config ?: return
        val b = backend ?: return
        try {
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> begin(event, config, b)
                MotionEvent.ACTION_MOVE -> if (active) {
                    record(event)
                    if (addAll(event)) {
                        updatePrediction()
                        b.requestDraw()
                    }
                }
                MotionEvent.ACTION_UP -> if (active) {
                    record(event)
                    addAll(event)
                    end(b)
                }
                MotionEvent.ACTION_POINTER_DOWN -> if (active) record(event)
                MotionEvent.ACTION_POINTER_UP -> if (active) {
                    if (event.getPointerId(event.actionIndex) == penId) {
                        end(b)
                    } else {
                        record(event)
                    }
                }
                MotionEvent.ACTION_CANCEL -> if (active) {
                    active = false
                    stroke = null
                    pending.clear()
                    prediction.set(noPrediction)
                    clear()
                }
            }
        } catch (_: Throwable) {
            // Drawing aid only: input must never be affected.
            active = false
        }
    }

    private fun begin(event: MotionEvent, config: Config, b: Backend) {
        active = false
        if (event.getToolType(0) != MotionEvent.TOOL_TYPE_STYLUS) return
        // The pen's button does something else than writing.
        if (event.buttonState != 0) return
        val x = event.x
        val y = event.y
        if (x < config.left || x > config.right || y < config.top || y > config.bottom) return

        val location = IntArray(2)
        b.view.getLocationOnScreen(location)
        shiftX = event.rawX - event.x - location[0]
        shiftY = event.rawY - event.y - location[1]
        mainHandler.removeCallbacks(lateClear)
        stroke = config
        active = true
        penId = event.getPointerId(0)
        run = 0f
        nextIsFirst = true
        if (b.frontBuffer) {
            frontRequests.set(0)
            frontDraws.set(0)
        }
        prediction.set(noPrediction)
        startPredictor(event, b.view)
        lastX = x + shiftX
        lastY = y + shiftY
        lastRadius = radiusAt(config, event.pressure, 0f)
        push(lastX, lastY, lastRadius, lastX, lastY, lastRadius, config.color, event.eventTime)
        b.requestDraw()
    }

    private fun startPredictor(event: MotionEvent, view: View) {
        if (stroke?.predict != true) return
        try {
            if (predictor == null) predictor = MotionEventPredictor.newInstance(view)
            predictor?.record(event)
        } catch (_: Throwable) {
            predictor = null
        }
    }

    private fun record(event: MotionEvent) {
        if (stroke?.predict != true) return
        try {
            predictor?.record(event)
        } catch (_: Throwable) {
            // An event the predictor doesn't accept: start it afresh with
            // the next stroke.
            predictor = null
        }
    }

    /// Adds the pen's points of [event]; false if the pen isn't in it.
    private fun addAll(event: MotionEvent): Boolean {
        val config = stroke ?: return false
        val i = event.findPointerIndex(penId)
        if (i < 0) return false
        for (h in 0 until event.historySize) {
            add(
                event.getHistoricalX(i, h) + shiftX, event.getHistoricalY(i, h) + shiftY,
                event.getHistoricalPressure(i, h), config, event.getHistoricalEventTime(h),
            )
        }
        add(event.getX(i) + shiftX, event.getY(i) + shiftY, event.getPressure(i), config, event.eventTime)
        return true
    }

    private fun add(x: Float, y: Float, pressure: Float, config: Config, at: Long) {
        run += hypot(x - lastX, y - lastY)
        val r = radiusAt(config, pressure, run)
        push(lastX, lastY, lastRadius, x, y, r, config.color, at)
        lastX = x
        lastY = y
        lastRadius = r
    }

    /// Asks the predictor where the pen is heading and keeps that as the
    /// piece to draw ahead of it (or none).
    private fun updatePrediction() {
        val config = stroke ?: return
        if (!config.predict) return
        val p = predictor ?: return
        val predicted = try {
            p.predict()
        } catch (_: Throwable) {
            null
        }
        if (predicted == null) {
            prediction.set(noPrediction)
            return
        }
        try {
            val i = predicted.findPointerIndex(penId).let { if (it < 0) 0 else it }
            val rawCount = predicted.historySize + 1
            val count = if (config.predictionPointLimit > 0) {
                min(rawCount, config.predictionPointLimit)
            } else {
                rawCount
            }
            val points = FloatArray(2 * (count + 1))
            points[0] = lastX
            points[1] = lastY
            var n = 1
            var length = 0f
            // Never further ahead than a few pen widths: a guess that runs
            // far is the one that is most often wrong.
            val maxLength = max(config.sizePx * 4f, 48f)
            for (h in 0 until count) {
                val x = (if (h < count - 1) predicted.getHistoricalX(i, h) else predicted.getX(i)) + shiftX
                val y = (if (h < count - 1) predicted.getHistoricalY(i, h) else predicted.getY(i)) + shiftY
                val px = points[2 * (n - 1)]
                val py = points[2 * (n - 1) + 1]
                val step = hypot(x - px, y - py)
                if (step < 0.01f) continue
                if (length + step > maxLength) {
                    val f = (maxLength - length) / step
                    points[2 * n] = px + (x - px) * f
                    points[2 * n + 1] = py + (y - py) * f
                    n++
                    break
                }
                length += step
                points[2 * n] = x
                points[2 * n + 1] = y
                n++
            }
            prediction.set(
                if (n < 2) noPrediction
                else Prediction(points.copyOf(2 * n), lastRadius, config.color)
            )
        } finally {
            predicted.recycle()
        }
    }

    private fun end(b: Backend) {
        active = false
        stroke = null
        // The last picture has the pen's real line only.
        prediction.set(noPrediction)
        b.requestDraw()
        if (b.frontBuffer) {
            mainHandler.postDelayed({ checkFront() }, 250)
        }
        // The app clears the overlay once it has drawn the stroke itself;
        // if it never does, this does.
        mainHandler.removeCallbacks(lateClear)
        mainHandler.postDelayed(lateClear, 700)
    }

    private fun checkFront() {
        if (frontRequests.get() > 0 && frontDraws.get() == 0) {
            silentStrokes++
            if (silentStrokes >= 2) fallBackToSurface()
        } else if (frontDraws.get() > 0) {
            silentStrokes = 0
        }
    }

    private val lateClear = Runnable { if (!active) clear() }

    private fun push(
        x0: Float, y0: Float, r0: Float, x1: Float, y1: Float, r1: Float, color: Int,
        at: Long,
    ) {
        // Nothing drawing it (no surface yet): don't let it pile up.
        if (pending.size > 20000) pending.clear()
        pending.add(Segment(x0, y0, r0, x1, y1, r1, color, at, nextIsFirst))
        nextIsFirst = false
    }

    /// Wipes the overlay (the app has drawn the finished stroke).
    fun clear() {
        if (active) return
        val b = backend ?: return
        b.onDrawThread {
            strokeSegments.clear()
            drawnPrediction = noPrediction
        }
        b.clear()
    }

    // -- drawing (on the drawing thread) --------------------------------------

    /// Takes the points that arrived since the last picture and draws them,
    /// with the guessed piece ahead of the pen. The area that changes is
    /// wiped and everything of the stroke in it drawn again, so a guessed
    /// piece from before never stays behind. [whole] wipes everything first
    /// (the layer's contents were lost).
    private fun paintFrame(canvas: Canvas, whole: Boolean): Int {
        val fresh = ArrayList<Segment>()
        while (true) fresh.add(pending.poll() ?: break)
        for (s in fresh) {
            if (s.first) strokeSegments.clear()
            strokeSegments.add(s)
        }
        val ahead = prediction.get()

        if (whole) {
            canvas.drawColor(0, PorterDuff.Mode.CLEAR)
            for (s in strokeSegments) drawSegment(canvas, s)
        } else {
            dirty.setEmpty()
            for (s in fresh) dirty.union(s.left, s.top, s.right, s.bottom)
            if (ahead !== drawnPrediction) {
                drawnPrediction.bounds(scratch)
                if (!scratch.isEmpty) dirty.union(scratch)
                ahead.bounds(scratch)
                if (!scratch.isEmpty) dirty.union(scratch)
            }
            if (dirty.isEmpty) return 0
            canvas.save()
            canvas.clipRect(dirty)
            canvas.drawColor(0, PorterDuff.Mode.CLEAR)
            for (s in strokeSegments) {
                if (s.right < dirty.left || s.left > dirty.right ||
                    s.bottom < dirty.top || s.top > dirty.bottom
                ) continue
                drawSegment(canvas, s)
            }
            canvas.restore()
        }
        drawPrediction(canvas, ahead)
        drawnPrediction = ahead

        val posted = SystemClock.uptimeMillis()
        synchronized(delays) {
            for (s in fresh) {
                if (delays.size >= 20000) break
                delays.add((posted - s.at).coerceAtLeast(0))
            }
            if (ahead.count > 1) predictedFrames++
        }
        return fresh.size
    }

    private fun drawPrediction(canvas: Canvas, p: Prediction) {
        if (p.count < 2) return
        val pts = p.points
        for (k in 1 until p.count) {
            drawSegment(
                canvas,
                pts[2 * k - 2], pts[2 * k - 1], p.radius,
                pts[2 * k], pts[2 * k + 1], p.radius,
                p.color,
            )
        }
    }

    private fun drawSegment(canvas: Canvas, s: Segment) =
        drawSegment(canvas, s.x0, s.y0, s.r0, s.x1, s.y1, s.r1, s.color)

    private fun drawSegment(
        canvas: Canvas,
        x0: Float, y0: Float, r0: Float,
        x1: Float, y1: Float, r1: Float,
        color: Int,
    ) {
        if (capsuleShader != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            drawShaderCapsule(canvas, x0, y0, r0, x1, y1, r1, color)
            return
        }
        paint.color = color
        canvas.drawCircle(x1, y1, r1, paint)
        val dx = x1 - x0
        val dy = y1 - y0
        val length = hypot(dx, dy)
        if (length < 0.01f) return
        val nx = -dy / length
        val ny = dx / length
        path.rewind()
        path.moveTo(x0 + nx * r0, y0 + ny * r0)
        path.lineTo(x1 + nx * r1, y1 + ny * r1)
        path.lineTo(x1 - nx * r1, y1 - ny * r1)
        path.lineTo(x0 - nx * r0, y0 - ny * r0)
        path.close()
        canvas.drawPath(path, paint)
        canvas.drawCircle(x0, y0, r0, paint)
    }

    @RequiresApi(Build.VERSION_CODES.S)
    private fun drawShaderCapsule(
        canvas: Canvas,
        x0: Float,
        y0: Float,
        r0: Float,
        x1: Float,
        y1: Float,
        r1: Float,
        color: Int,
    ) {
        val shader = capsuleShader ?: return
        shader.setFloatUniform("uStart", x0, y0)
        shader.setFloatUniform("uEnd", x1, y1)
        shader.setFloatUniform("uRadiusStart", r0)
        shader.setFloatUniform("uRadiusEnd", r1)
        shader.setFloatUniform(
            "uColor",
            ((color shr 16) and 0xff) / 255f,
            ((color shr 8) and 0xff) / 255f,
            (color and 0xff) / 255f,
            ((color ushr 24) and 0xff) / 255f,
        )
        paint.shader = shader
        val pad = max(r0, r1) + 1f
        canvas.drawRect(
            min(x0, x1) - pad,
            min(y0, y1) - pad,
            max(x0, x1) + pad,
            max(y0, y1) + pad,
            paint,
        )
        paint.shader = null
    }

    // -- front buffer ---------------------------------------------------------

    @RequiresApi(Build.VERSION_CODES.Q)
    private inner class FrontBackend : Backend, LowLatencyCanvasView.Callback {
        private val canvasView = LowLatencyCanvasView(activity).also { it.setRenderCallback(this) }
        override val view: View get() = canvasView
        override val frontBuffer = true

        override fun onRedrawRequested(canvas: Canvas, width: Int, height: Int) {
            paintFrame(canvas, whole = true)
        }

        override fun onDrawFrontBufferedLayer(canvas: Canvas, width: Int, height: Int) {
            frontDraws.incrementAndGet()
            paintFrame(canvas, whole = false)
        }

        override fun requestDraw() {
            frontRequests.incrementAndGet()
            canvasView.renderFrontBufferedLayer()
        }

        override fun clear() = canvasView.clear()

        override fun onDrawThread(block: () -> Unit) = canvasView.execute { block() }

        override fun release() {
            canvasView.setRenderCallback(null)
            canvasView.cancel()
        }
    }

    // -- plain surface ----------------------------------------------------------

    private inner class SurfaceBackend : Backend, SurfaceHolder.Callback {
        private val surfaceView = SurfaceView(activity)
        override val view: View get() = surfaceView
        override val frontBuffer = false

        @Volatile private var ready = false
        private val thread = HandlerThread("ink-overlay").apply { start() }
        private val handler = Handler(thread.looper)
        @Volatile private var scheduled = false

        init {
            surfaceView.setZOrderOnTop(true)
            surfaceView.holder.setFormat(PixelFormat.TRANSLUCENT)
            surfaceView.holder.addCallback(this)
        }

        override fun surfaceCreated(holder: SurfaceHolder) {
            ready = true
            handler.post { wipe() }
        }

        override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
            ready = true
            handler.post { wipe() }
        }

        override fun surfaceDestroyed(holder: SurfaceHolder) {
            ready = false
        }

        override fun requestDraw() {
            if (scheduled) return
            scheduled = true
            handler.post(drawRunnable)
        }

        override fun clear() {
            handler.post { wipe() }
        }

        override fun onDrawThread(block: () -> Unit) {
            handler.post { block() }
        }

        override fun release() {
            ready = false
            thread.quitSafely()
        }

        private fun wipe() {
            if (!ready) return
            val holder = surfaceView.holder
            val canvas = (try { holder.lockCanvas() } catch (_: Throwable) { null }) ?: return
            try {
                canvas.drawColor(0, PorterDuff.Mode.CLEAR)
                // Whatever of the stroke is still being written.
                for (s in strokeSegments) drawSegment(canvas, s)
            } finally {
                holder.unlockCanvasAndPost(canvas)
            }
        }

        private val drawRunnable = Runnable {
            scheduled = false
            if (!ready) {
                pending.clear()
                return@Runnable
            }
            val holder = surfaceView.holder
            // The whole layer is drawn each time: only the changed part is
            // wiped and redrawn (see paintFrame), but a surface hands out
            // buffers whose contents may be a few pictures old, so the
            // picture has to be complete in every one of them.
            val canvas = (try { holder.lockCanvas() } catch (_: Throwable) { null })
                ?: return@Runnable
            try {
                paintFrame(canvas, whole = true)
            } finally {
                holder.unlockCanvasAndPost(canvas)
            }
        }
    }

    // -- latency report ---------------------------------------------------------

    /// How long each drawn point took from the pen's event to the picture
    /// being handed to the screen (milliseconds), for the latency report.
    private val delays = ArrayList<Long>()
    private var predictedFrames = 0

    fun resetStats() {
        synchronized(delays) {
            delays.clear()
            predictedFrames = 0
        }
    }

    /// Count, median, 95th percentile and worst of those delays, how it was
    /// drawn (frontBuffer 1 or 0) and how many pictures had a guessed piece,
    /// or null if nothing was drawn since the last reset.
    fun stats(): Map<String, Any>? {
        val sorted: List<Long>
        val predicted: Int
        synchronized(delays) {
            sorted = delays.sorted()
            predicted = predictedFrames
        }
        if (sorted.isEmpty()) return null
        fun at(p: Int) = sorted[((sorted.size - 1) * p / 100)].toDouble()
        return mapOf(
            "count" to sorted.size,
            "p50" to at(50),
            "p95" to at(95),
            "max" to sorted.last().toDouble(),
            "frontBuffer" to if (backend?.frontBuffer == true) 1.0 else 0.0,
            "frontUnsupported" to if (frontUnsupported) 1.0 else 0.0,
            "predictedFrames" to predicted.toDouble(),
        )
    }
}
