package com.adilhanney.saber

import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Surface
import android.view.SurfaceView
import android.view.View
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

    override fun onResume() {
        super.onResume()
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
                if (call.method == "modes") {
                    result.success(describeDisplayModes())
                } else {
                    result.notImplemented()
                }
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
