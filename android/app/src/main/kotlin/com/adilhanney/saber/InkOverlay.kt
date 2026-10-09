package com.adilhanney.saber

import android.app.Activity
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.PorterDuff
import android.graphics.Rect
import android.os.Handler
import android.os.HandlerThread
import android.view.MotionEvent
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.ViewGroup
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

/// Draws the line of a pen stroke straight to the screen while it is being
/// written, on a surface of its own above the app.
///
/// The app's own drawing goes through several steps (the input is handed to
/// Dart, the picture is built, drawn on another thread, and shown on the
/// next screen refresh), and the ink is that many frames behind the pen.
/// Here the pen's points are drawn the moment they arrive, on a thread of
/// their own, so the ink is one refresh behind the pen at most.
///
/// Only the pen's real points are drawn: nothing is predicted or smoothed.
/// The app draws the finished stroke itself, and then has this surface
/// cleared. Everything is optional: without a surface, or with the option
/// off, nothing here does anything and the app draws as it always did.
class InkOverlay(private val activity: Activity) : SurfaceHolder.Callback {
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
    )

    private class Segment(
        val x0: Float, val y0: Float, val r0: Float,
        val x1: Float, val y1: Float, val r1: Float,
        val color: Int,
    )

    private var view: SurfaceView? = null
    @Volatile private var ready = false
    @Volatile private var config: Config? = null

    private val thread = HandlerThread("ink-overlay").apply { start() }
    private val handler = Handler(thread.looper)
    private val mainHandler = Handler(android.os.Looper.getMainLooper())

    private val pending = ConcurrentLinkedQueue<Segment>()
    private val scheduled = AtomicBoolean(false)
    @Volatile private var dirty = false

    // The stroke being written (touched only from the main thread).
    private var active = false
    private var stroke: Config? = null
    private var lastX = 0f
    private var lastY = 0f
    private var lastRadius = 0f
    private var run = 0f
    /// Added to the event's coordinates to get the overlay's.
    private var shiftX = 0f
    private var shiftY = 0f

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val path = Path()

    /// Sets how strokes are drawn, or turns the overlay off (null). Returns
    /// whether it can draw.
    fun setConfig(next: Config?): Boolean {
        config = next
        if (next == null) return view != null && ready
        if (view == null) create()
        return view != null
    }

    private fun create() {
        try {
            val v = SurfaceView(activity)
            v.setZOrderOnTop(true)
            v.holder.setFormat(PixelFormat.TRANSLUCENT)
            v.holder.addCallback(this)
            v.isClickable = false
            v.isFocusable = false
            activity.addContentView(
                v,
                ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                ),
            )
            view = v
        } catch (_: Throwable) {
            view = null
        }
    }

    override fun surfaceCreated(holder: SurfaceHolder) {
        ready = true
        handler.post { clearNow() }
    }

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        ready = true
        handler.post { clearNow() }
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        ready = false
    }

    private fun pressureOf(config: Config, raw: Float): Float {
        val table = config.pressure
        if (table.isEmpty()) return 0.5f
        val at = raw.coerceIn(0f, 1f) * (table.size - 1)
        val i = at.toInt().coerceAtMost(table.size - 2).coerceAtLeast(0)
        if (table.size == 1) return table[0]
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
        val v = view ?: return
        if (!ready) return
        try {
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> begin(event, config, v)
                MotionEvent.ACTION_MOVE -> if (active) addAll(event)
                MotionEvent.ACTION_UP -> if (active) {
                    addAll(event)
                    end()
                }
                MotionEvent.ACTION_CANCEL -> if (active) {
                    active = false
                    pending.clear()
                    clear()
                }
            }
        } catch (_: Throwable) {
            // Drawing aid only: input must never be affected.
            active = false
        }
    }

    private fun begin(event: MotionEvent, config: Config, v: SurfaceView) {
        active = false
        if (event.getToolType(0) != MotionEvent.TOOL_TYPE_STYLUS) return
        // The pen's button does something else than writing.
        if (event.buttonState != 0) return
        val x = event.x
        val y = event.y
        if (x < config.left || x > config.right || y < config.top || y > config.bottom) return

        val location = IntArray(2)
        v.getLocationOnScreen(location)
        shiftX = event.rawX - event.x - location[0]
        shiftY = event.rawY - event.y - location[1]
        mainHandler.removeCallbacks(lateClear)
        stroke = config
        active = true
        run = 0f
        lastX = event.x + shiftX
        lastY = event.y + shiftY
        lastRadius = radiusAt(config, event.pressure, 0f)
        push(lastX, lastY, lastRadius, lastX, lastY, lastRadius, config.color)
    }

    private fun addAll(event: MotionEvent) {
        val config = stroke ?: return
        for (h in 0 until event.historySize) {
            add(
                event.getHistoricalX(h) + shiftX, event.getHistoricalY(h) + shiftY,
                event.getHistoricalPressure(h), config,
            )
        }
        add(event.x + shiftX, event.y + shiftY, event.pressure, config)
    }

    private fun add(x: Float, y: Float, pressure: Float, config: Config) {
        run += hypot(x - lastX, y - lastY)
        val r = radiusAt(config, pressure, run)
        push(lastX, lastY, lastRadius, x, y, r, config.color)
        lastX = x
        lastY = y
        lastRadius = r
    }

    private fun end() {
        active = false
        stroke = null
        // The app clears the overlay once it has drawn the stroke itself;
        // if it never does, this does.
        mainHandler.removeCallbacks(lateClear)
        mainHandler.postDelayed(lateClear, 700)
    }

    private val lateClear = Runnable { if (!active) clear() }

    private fun push(
        x0: Float, y0: Float, r0: Float, x1: Float, y1: Float, r1: Float, color: Int,
    ) {
        pending.add(Segment(x0, y0, r0, x1, y1, r1, color))
        dirty = true
        if (scheduled.compareAndSet(false, true)) handler.post(drawRunnable)
    }

    /// Wipes the overlay (the app has drawn the finished stroke).
    fun clear() {
        if (active) return
        handler.post { clearNow() }
    }

    private fun clearNow() {
        val holder = view?.holder ?: return
        if (!ready) return
        pending.clear()
        val canvas = (try { holder.lockCanvas() } catch (_: Throwable) { null }) ?: return
        try {
            canvas.drawColor(0, PorterDuff.Mode.CLEAR)
        } finally {
            holder.unlockCanvasAndPost(canvas)
        }
        dirty = false
    }

    private val drawRunnable = Runnable {
        scheduled.set(false)
        val holder = view?.holder ?: return@Runnable
        if (!ready) {
            pending.clear()
            return@Runnable
        }
        val segments = ArrayList<Segment>()
        while (true) segments.add(pending.poll() ?: break)
        if (segments.isEmpty()) return@Runnable

        var left = Float.MAX_VALUE
        var top = Float.MAX_VALUE
        var right = -Float.MAX_VALUE
        var bottom = -Float.MAX_VALUE
        for (s in segments) {
            val pad = max(s.r0, s.r1) + 2f
            left = min(left, min(s.x0, s.x1) - pad)
            top = min(top, min(s.y0, s.y1) - pad)
            right = max(right, max(s.x0, s.x1) + pad)
            bottom = max(bottom, max(s.y0, s.y1) + pad)
        }
        val frame = holder.surfaceFrame
        val area = Rect(
            left.toInt().coerceAtLeast(0),
            top.toInt().coerceAtLeast(0),
            right.toInt().coerceAtMost(frame.right) + 1,
            bottom.toInt().coerceAtMost(frame.bottom) + 1,
        )
        if (area.isEmpty) return@Runnable
        val canvas = (try { holder.lockCanvas(area) } catch (_: Throwable) { null })
            ?: return@Runnable
        try {
            for (s in segments) drawSegment(canvas, s)
        } finally {
            holder.unlockCanvasAndPost(canvas)
        }
    }

    private fun drawSegment(canvas: Canvas, s: Segment) {
        paint.color = s.color
        canvas.drawCircle(s.x1, s.y1, s.r1, paint)
        val dx = s.x1 - s.x0
        val dy = s.y1 - s.y0
        val length = hypot(dx, dy)
        if (length < 0.01f) return
        val nx = -dy / length
        val ny = dx / length
        path.rewind()
        path.moveTo(s.x0 + nx * s.r0, s.y0 + ny * s.r0)
        path.lineTo(s.x1 + nx * s.r1, s.y1 + ny * s.r1)
        path.lineTo(s.x1 - nx * s.r1, s.y1 - ny * s.r1)
        path.lineTo(s.x0 - nx * s.r0, s.y0 - ny * s.r0)
        path.close()
        canvas.drawPath(path, paint)
        canvas.drawCircle(s.x0, s.y0, s.r0, paint)
    }
}
