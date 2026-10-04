package com.adilhanney.saber

import android.os.Build
import android.os.Bundle
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import android.content.Intent.FLAG_ACTIVITY_NEW_TASK

class MainActivity: FlutterActivity() {
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

    /// Flutter apps are often drawn at 60 Hz even on 120 Hz screens, which
    /// makes the pen trail further behind. Ask for the screen's fastest mode.
    private fun requestHighestRefreshRate() {
        try {
            val display: android.view.Display? =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    this.display
                } else {
                    @Suppress("DEPRECATION")
                    windowManager.defaultDisplay
                }
            if (display == null) return
            val best = display.supportedModes.maxByOrNull { it.refreshRate }
            if (best == null) return
            val params = window.attributes
            params.preferredDisplayModeId = best.modeId
            window.attributes = params
        } catch (_: Exception) {
            // Keep the system's choice if this isn't possible.
        }
    }
}
