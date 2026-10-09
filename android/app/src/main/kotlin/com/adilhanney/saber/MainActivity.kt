package com.adilhanney.saber

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import androidx.annotation.RequiresApi
import androidx.core.content.FileProvider
import java.io.File
import android.os.Handler
import android.os.Looper
import android.os.PerformanceHintManager
import android.os.Process
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

    /// Draws the pen's line straight to the screen while it is written (see
    /// [InkOverlay]). Only created once the app asks for it.
    private var ink: InkOverlay? = null

    private fun inkConfig(arguments: Any?): InkOverlay.Config? {
        val map = arguments as? Map<*, *> ?: return null
        fun number(key: String): Float =
            (map[key] as? Number)?.toFloat() ?: 0f
        val table = (map["pressure"] as? List<*>)?.map { (it as? Number)?.toFloat() ?: 0.5f }
            ?: listOf(0.5f)
        return InkOverlay.Config(
            color = (map["color"] as? Number)?.toInt() ?: return null,
            sizePx = number("size"),
            thinning = number("thinning"),
            taperPx = number("taper"),
            pressure = table.toFloatArray(),
            left = number("left"),
            top = number("top"),
            right = number("right"),
            bottom = number("bottom"),
        )
    }

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
        askForPenEventsAtOnce(event)
        ink?.onTouch(event)
        return super.dispatchTouchEvent(event)
    }

    /// Android holds touch and pen events back and hands them to the app
    /// once per screen refresh, so a pen that reports every 4 ms is heard
    /// only every 16 ms, and the ink starts that much behind it. Asking for
    /// the events of a pen stroke "unbuffered" has them delivered as they
    /// happen. (This has to be asked for at the pen's first contact, and
    /// holds until it lifts.) Fingers are left as they were: nothing about
    /// scrolling gets better from it.
    private fun askForPenEventsAtOnce(event: MotionEvent) {
        if (event.actionMasked != MotionEvent.ACTION_DOWN) return
        val tool = event.getToolType(0)
        if (tool != MotionEvent.TOOL_TYPE_STYLUS &&
            tool != MotionEvent.TOOL_TYPE_ERASER) return
        try {
            window.decorView.requestUnbufferedDispatch(event)
        } catch (_: Exception) {
            // Only a request: without it the pen works as before.
        }
    }

    /// While a pen stroke is being drawn, tells the system the app's
    /// drawing threads have only a few milliseconds per frame, so it keeps
    /// the processor and graphics chip at a speed that makes it (instead of
    /// letting them idle down between short bursts, which makes some frames
    /// late). Only a hint: the system may ignore it, and without it
    /// everything works as before.
    private var hintSession: PerformanceHintManager.Session? = null

    private fun drawingThreads(): IntArray {
        val ids = mutableListOf(Process.myPid())
        try {
            File("/proc/self/task").listFiles()?.forEach { dir ->
                val name = try {
                    File(dir, "comm").readText().trim()
                } catch (_: Exception) {
                    ""
                }
                if (name.endsWith(".ui") || name.endsWith(".raster")) {
                    dir.name.toIntOrNull()?.let { ids.add(it) }
                }
            }
        } catch (_: Exception) {
        }
        return ids.distinct().toIntArray()
    }

    private fun startPenBoost(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return false
        return try {
            hintSession?.close()
            val manager = getSystemService(PerformanceHintManager::class.java)
            hintSession = manager?.createHintSession(drawingThreads(), 6_000_000L)
            hintSession != null
        } catch (_: Throwable) {
            hintSession = null
            false
        }
    }

    private fun reportPenFrame(micros: Long) {
        try {
            hintSession?.reportActualWorkDuration(micros * 1000L)
        } catch (_: Throwable) {
        }
    }

    private fun stopPenBoost() {
        try {
            hintSession?.close()
        } catch (_: Throwable) {
        }
        hintSession = null
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
                    "refreshInfo" -> result.success(refreshInfo())
                    "openDisplaySettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_DISPLAY_SETTINGS))
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                    "setBrightness" -> {
                        desiredBrightness =
                            (call.argument<Double>("value") ?: -1.0).toFloat()
                        setWindowBrightness(desiredBrightness)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "defter/boost")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> result.success(startPenBoost())
                    "report" -> {
                        reportPenFrame((call.argument<Number>("micros") ?: 0).toLong())
                        result.success(null)
                    }
                    "stop" -> {
                        stopPenBoost()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "defter/ink")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "config" -> {
                            val config = inkConfig(call.arguments)
                            if (ink == null && config != null) ink = InkOverlay(this)
                            result.success(ink?.setConfig(config) ?: false)
                        }
                        "clear" -> {
                            ink?.clear()
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (_: Throwable) {
                    result.success(false)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "defter/camera")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "takePhoto" -> takePhoto(result)
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

    // -- camera ----------------------------------------------------------------

    private val photoRequest = 43127
    private var pendingPhoto: MethodChannel.Result? = null
    private var pendingPhotoFile: File? = null

    /// Opens the device's camera app to take one photo. Answers with the
    /// path of the photo (in the app's cache), or null if none was taken.
    /// The app needs no camera permission for this: the camera app takes
    /// the photo, and only that one photo is handed back.
    private fun takePhoto(result: MethodChannel.Result) {
        if (pendingPhoto != null) {
            result.error("busy", "A photo is already being taken", null)
            return
        }
        try {
            val folder = File(cacheDir, "camera")
            folder.mkdirs()
            // Photos that were left behind are no longer needed.
            folder.listFiles()?.forEach { it.delete() }
            val file = File(folder, "photo_${System.currentTimeMillis()}.jpg")
            val uri = FileProvider.getUriForFile(this, "$packageName.camera", file)
            val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)
                .putExtra(MediaStore.EXTRA_OUTPUT, uri)
                .addFlags(
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                        Intent.FLAG_GRANT_READ_URI_PERMISSION
                )
            // Some camera apps are only let in through the clip data.
            intent.clipData = ClipData.newRawUri("photo", uri)
            pendingPhoto = result
            pendingPhotoFile = file
            startActivityForResult(intent, photoRequest)
        } catch (e: ActivityNotFoundException) {
            pendingPhoto = null
            pendingPhotoFile = null
            result.error("no_camera", "No camera app was found", null)
        } catch (e: Exception) {
            pendingPhoto = null
            pendingPhotoFile = null
            result.error("failed", e.message ?: e.javaClass.simpleName, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != photoRequest) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pendingPhoto
        val file = pendingPhotoFile
        pendingPhoto = null
        pendingPhotoFile = null
        if (resultCode == Activity.RESULT_OK && file != null && file.length() > 0) {
            result?.success(file.absolutePath)
        } else {
            file?.delete()
            result?.success(null)
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

    /// What is known about the screen's refresh rate, for the page in the
    /// settings that says how fast the app is drawn: the fastest rate the
    /// screen has at this resolution ("max"), the rate of the mode in use
    /// ("mode"), and the rate the system lets this app draw at ("app",
    /// which can be lower than the mode's when the system holds the app
    /// back).
    private fun refreshInfo(): Map<String, Any?> {
        val info = HashMap<String, Any?>()
        try {
            val display = currentDisplay()
            if (display != null) {
                val current = display.mode
                val best = display.supportedModes
                    .filter {
                        it.physicalWidth == current.physicalWidth &&
                            it.physicalHeight == current.physicalHeight
                    }
                    .maxByOrNull { it.refreshRate }
                info["max"] = (best?.refreshRate ?: current.refreshRate).toDouble()
                info["mode"] = current.refreshRate.toDouble()
                info["app"] = display.refreshRate.toDouble()
            }
        } catch (_: Exception) {
            // What could not be read is left out.
        }
        info["sdk"] = Build.VERSION.SDK_INT
        info["maker"] = Build.MANUFACTURER
        info["model"] = Build.MODEL
        info["details"] = describeDisplayModes()
        return info
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
            val views = applyViewFrameRate(best.refreshRate)
            requestNote = "asked mode ${best.modeId} (${Math.round(best.refreshRate)} Hz), surface: $surface, views: $views"
        } catch (e: Exception) {
            // Keep the system's choice if this isn't possible.
            requestNote = "request failed: ${e.javaClass.simpleName}"
        }
    }

    /// On Android 15 and later, where the system picks a frame rate for
    /// each window from what its views ask for: asks for [rate] on the
    /// window's views, and for the system not to trade it for battery.
    private fun applyViewFrameRate(rate: Float): String {
        if (Build.VERSION.SDK_INT < 35) return "needs Android 15"
        return try {
            "asked on ${askViewsForFrameRate(rate)}"
        } catch (e: Throwable) {
            "failed: ${e.javaClass.simpleName}"
        }
    }

    @RequiresApi(35)
    private fun askViewsForFrameRate(rate: Float): Int {
        window.isFrameRatePowerSavingsBalanced = false
        return askViewForFrameRate(window.decorView, rate)
    }

    @RequiresApi(35)
    private fun askViewForFrameRate(view: View, rate: Float): Int {
        view.requestedFrameRate = rate
        var count = 1
        if (view is ViewGroup) {
            for (i in 0 until view.childCount) {
                count += askViewForFrameRate(view.getChildAt(i), rate)
            }
        }
        return count
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
