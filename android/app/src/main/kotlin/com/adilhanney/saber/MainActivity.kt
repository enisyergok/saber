package com.adilhanney.saber

import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.Surface
import android.view.SurfaceView
import android.view.View
import android.view.WindowManager
import android.view.ViewGroup
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent.FLAG_ACTIVITY_NEW_TASK

class MainActivity: FlutterActivity() {
    /// What the last refresh rate request did, for the pen latency report.
    private var requestNote = "no request yet"

    /// The window brightness the app asked for (0-1), or
    /// BRIGHTNESS_OVERRIDE_NONE to follow the system.
    private var desiredBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE

    override fun onCreate(savedInstanceState: Bundle?) {
        if (intent.getIntExtra("org.chromium.chrome.extra.TASK_ID", -1) == this.taskId) {
            this.finish()
            intent.addFlags(FLAG_ACTIVITY_NEW_TASK);
            startActivity(intent);
        }
        super.onCreate(savedInstanceState)

        WindowCompat.setDecorFitsSystemWindows(window, false)

        val windowInsetsController = WindowCompat.getInsetsController(window, window.decorView)
        windowInsetsController.isAppearanceLightNavigationBars = true

        requestHighestRefreshRate()
    }

    /// The last raw input signals Android handed to this window (keys,
    /// pen buttons, hovering), newest first, for the "Pen test" screen. They
    /// are only recorded, never changed or consumed.
    private val rawInput = ArrayList<String>()
    private var lastButtons = -1

    private fun recordInput(text: String) {
        synchronized(rawInput) {
            rawInput.add(0, text)
            while (rawInput.size > 60) rawInput.removeAt(rawInput.size - 1)
        }
    }

    private var inputChannel: MethodChannel? = null

    /// The key code HONOR/HUAWEI pens send for their double tap. Flutter has
    /// no name for it, so it is handed to the app by hand.
    private val penDoubleTapKeyCode = 718

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.keyCode == penDoubleTapKeyCode) {
            recordInput("PEN KEY ${event.keyCode} action=${event.action}")
            if (event.action == KeyEvent.ACTION_DOWN) {
                inputChannel?.invokeMethod("stylusKey", null)
            }
            return inputChannel != null
        }
        recordInput(
            "KEY ${KeyEvent.keyCodeToString(event.keyCode)} (${event.keyCode}) " +
                "action=${event.action} source=0x${Integer.toHexString(event.source)} " +
                "device=${event.deviceId}"
        )
        return super.dispatchKeyEvent(event)
    }

    private fun recordMotion(kind: String, event: MotionEvent) {
        val tool = event.getToolType(0)
        val action = event.actionMasked
        val plain = action == MotionEvent.ACTION_HOVER_MOVE ||
            action == MotionEvent.ACTION_MOVE
        val buttonsChanged = event.buttonState != lastButtons
        if (plain && !buttonsChanged) return
        lastButtons = event.buttonState
        recordInput(
            "$kind ${MotionEvent.actionToString(action)} tool=$tool " +
                "buttons=${event.buttonState} device=${event.deviceId}"
        )
    }

    override fun dispatchGenericMotionEvent(event: MotionEvent): Boolean {
        recordMotion("HOVER", event)
        return super.dispatchGenericMotionEvent(event)
    }

    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        recordMotion("TOUCH", event)
        return super.dispatchTouchEvent(event)
    }

    /// Names and kinds of the input devices, to see whether the pen shows
    /// up as a device of its own.
    private fun describeInputDevices(): String {
        return try {
            InputDevice.getDeviceIds().joinToString("\n") { id ->
                val d = InputDevice.getDevice(id)
                "#$id ${d?.name} src=0x${Integer.toHexString(d?.sources ?: 0)}"
            }
        } catch (_: Exception) {
            ""
        }
    }

    override fun onPause() {
        // Leave the screen as the user set it for every other app.
        setWindowBrightness(WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE)
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        setWindowBrightness(desiredBrightness)
        // Some devices drop back to a slower mode when the app comes back.
        requestHighestRefreshRate()
        // The drawing surface may not exist yet right after starting.
        Handler(Looper.getMainLooper()).postDelayed({ requestHighestRefreshRate() }, 800)
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) requestHighestRefreshRate()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "defter/display")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "modes" -> result.success(describeDisplayModes())
                    "setBrightness" -> {
                        desiredBrightness =
                            (call.argument<Double>("value") ?: -1.0).toFloat()
                        setWindowBrightness(desiredBrightness)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        inputChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "defter/input")
        inputChannel!!.setMethodCallHandler { call, result ->
                when (call.method) {
                    "events" -> synchronized(rawInput) { result.success(ArrayList(rawInput)) }
                    "devices" -> result.success(describeInputDevices())
                    "clear" -> {
                        synchronized(rawInput) { rawInput.clear() }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /// Sets this window's brightness only (never the system setting). It
    /// can only dim: a value above the system brightness is capped to it,
    /// so the app is never brighter than the person chose.
    private fun setWindowBrightness(value: Float) {
        try {
            val params = window.attributes
            params.screenBrightness = if (value < 0f) {
                WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
            } else {
                val system = Settings.System.getInt(
                    contentResolver, Settings.System.SCREEN_BRIGHTNESS, 255
                ) / 255f
                minOf(value, system).coerceAtLeast(0.02f)
            }
            window.attributes = params
        } catch (e: Exception) {
            // Keep the system's brightness if it can't be set.
        }
    }

    private fun currentDisplay(): android.view.Display? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            this.display
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay
        }

    /// The modes the screen offers and the one in use, for the pen
    /// latency report.
    private fun describeDisplayModes(): String {
        return try {
            val display = currentDisplay() ?: return ""
            val current = display.mode
            val modes = display.supportedModes.joinToString(", ") {
                "${it.modeId}: ${it.physicalWidth}x${it.physicalHeight} @ " +
                    "${Math.round(it.refreshRate)} Hz"
            }
            "$modes (in use: ${current.modeId}, ${Math.round(current.refreshRate)} Hz; " +
                "window prefers mode ${window.attributes.preferredDisplayModeId}; $requestNote)"
        } catch (_: Exception) {
            ""
        }
    }

    /// Flutter apps are often drawn at 60 Hz even on 120 Hz screens, which
    /// makes the pen trail further behind. Ask for the fastest mode that
    /// keeps the screen's current resolution, both through the window and
    /// through the drawing surface.
    private fun requestHighestRefreshRate() {
        try {
            val display = currentDisplay() ?: return
            val current = display.mode
            val best = display.supportedModes
                .filter {
                    it.physicalWidth == current.physicalWidth &&
                        it.physicalHeight == current.physicalHeight
                }
                .maxByOrNull { it.refreshRate } ?: return
            val params = window.attributes
            params.preferredDisplayModeId = best.modeId
            params.preferredRefreshRate = best.refreshRate
            window.attributes = params

            val surface = applySurfaceFrameRate(best.refreshRate)
            requestNote = "asked mode ${best.modeId} (${Math.round(best.refreshRate)} Hz), surface: $surface"
        } catch (e: Exception) {
            // Keep the system's choice if this isn't possible.
            requestNote = "request failed: ${e.javaClass.simpleName}"
        }
    }

    /// Tells the system the drawing surface wants [rate] frames per second.
    private fun applySurfaceFrameRate(rate: Float): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return "needs Android 11"
        val surfaces = ArrayList<Surface>()
        collectSurfaces(window.decorView, surfaces)
        if (surfaces.isEmpty()) return "none found"
        for (surface in surfaces) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                surface.setFrameRate(
                    rate,
                    Surface.FRAME_RATE_COMPATIBILITY_DEFAULT,
                    Surface.CHANGE_FRAME_RATE_ALWAYS
                )
            } else {
                surface.setFrameRate(rate, Surface.FRAME_RATE_COMPATIBILITY_DEFAULT)
            }
        }
        return "set on ${surfaces.size}"
    }

    private fun collectSurfaces(view: View, into: MutableList<Surface>) {
        if (view is SurfaceView && view.holder.surface.isValid) {
            into.add(view.holder.surface)
        }
        if (view is ViewGroup) {
            for (i in 0 until view.childCount) collectSurfaces(view.getChildAt(i), into)
        }
    }
}
