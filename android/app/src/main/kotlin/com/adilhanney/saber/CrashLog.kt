package com.adilhanney.saber

import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.content.Context
import android.os.Build
import androidx.annotation.RequiresApi
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/// Keeps what is needed to find out why the app closed: the last uncaught
/// exception, a few notes the app writes before risky steps ("marks"), and
/// what Android recorded about how the last runs of the app ended. Read
/// from Settings; nothing leaves the device.
object CrashLog {
    private var installed = false

    private fun crashFile(context: Context) = File(context.filesDir, "last_crash.txt")
    private fun marksFile(context: Context) = File(context.filesDir, "crash_marks.txt")

    private fun now(): String =
        SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date())

    fun install(context: Context) {
        if (installed) return
        installed = true
        val app = context.applicationContext
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            try {
                val writer = StringWriter()
                error.printStackTrace(PrintWriter(writer))
                crashFile(app).writeText(
                    "${now()} thread=${thread.name}\n${writer.toString().take(6000)}"
                )
            } catch (_: Throwable) {
            }
            previous?.uncaughtException(thread, error)
        }
    }

    fun mark(context: Context, text: String) {
        try {
            val file = marksFile(context)
            val lines = if (file.exists()) file.readLines().takeLast(19) else emptyList()
            file.writeText((lines + "${now()} $text").joinToString("\n"))
        } catch (_: Throwable) {
        }
    }

    fun clear(context: Context) {
        try {
            crashFile(context).delete()
            marksFile(context).delete()
        } catch (_: Throwable) {
        }
    }

    fun read(context: Context): String {
        val out = StringBuilder()
        try {
            val crash = crashFile(context)
            if (crash.exists()) {
                out.append("Son yakalanmamis hata:\n").append(crash.readText()).append("\n\n")
            }
            val marks = marksFile(context)
            if (marks.exists()) {
                out.append("Notlar:\n").append(marks.readText()).append("\n\n")
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                val exits = manager.getHistoricalProcessExitReasons(context.packageName, 0, 4)
                if (exits.isNotEmpty()) {
                    out.append("Android'in kaydettigi son kapanislar:\n")
                    for (info in exits) {
                        out.append("- ")
                            .append(SimpleDateFormat("MM-dd HH:mm:ss", Locale.US).format(Date(info.timestamp)))
                            .append(" neden=").append(reasonName(info.reason))
                            .append(" durum=").append(info.status)
                            .append(" aciklama=").append(info.description ?: "-")
                            .append("\n")
                    }
                }
            }
        } catch (e: Throwable) {
            out.append("Kayit okunamadi: ").append(e)
        }
        return out.toString().trim()
    }

    @RequiresApi(Build.VERSION_CODES.R)
    private fun reasonName(reason: Int): String {
        return when (reason) {
            ApplicationExitInfo.REASON_CRASH -> "CRASH (Java hatasi)"
            ApplicationExitInfo.REASON_CRASH_NATIVE -> "CRASH_NATIVE (yerel kutuphane cokmesi)"
            ApplicationExitInfo.REASON_ANR -> "ANR (yanit vermedi)"
            ApplicationExitInfo.REASON_LOW_MEMORY -> "LOW_MEMORY (bellek bitti)"
            ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE -> "EXCESSIVE_RESOURCE_USAGE"
            ApplicationExitInfo.REASON_USER_REQUESTED -> "USER_REQUESTED"
            ApplicationExitInfo.REASON_USER_STOPPED -> "USER_STOPPED"
            ApplicationExitInfo.REASON_SIGNALED -> "SIGNALED"
            ApplicationExitInfo.REASON_EXIT_SELF -> "EXIT_SELF"
            ApplicationExitInfo.REASON_DEPENDENCY_DIED -> "DEPENDENCY_DIED"
            ApplicationExitInfo.REASON_PERMISSION_CHANGE -> "PERMISSION_CHANGE"
            ApplicationExitInfo.REASON_INITIALIZATION_FAILURE -> "INITIALIZATION_FAILURE"
            else -> "UNKNOWN($reason)"
        }
    }
}
