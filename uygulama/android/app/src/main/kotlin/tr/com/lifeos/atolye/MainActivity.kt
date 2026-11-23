package tr.com.lifeos.atolye

import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Termux ile konuşan tek yer. Termux ayrı bir uygulamadır; burada yalnızca
 * kurulu olup olmadığına bakılır, ön plana getirilir ve kullanıcının izin
 * verdiği RUN_COMMAND ile içinde komut çalıştırılır.
 * https://github.com/termux/termux-app/wiki/RUN_COMMAND-Intent
 */
class MainActivity : FlutterActivity() {
    private val termux = "com.termux"
    private val izin = "com.termux.permission.RUN_COMMAND"
    private val izinKodu = 4711
    private var bekleyenIzin: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "atolye/termux")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "kurulu" -> result.success(kurulu())
                    "ac" -> {
                        val niyet = packageManager.getLaunchIntentForPackage(termux)
                        if (niyet == null) {
                            result.error("yok", "Termux kurulu değil", null)
                        } else {
                            startActivity(niyet.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                            result.success(null)
                        }
                    }
                    "izinVar" -> result.success(izinVar())
                    "izinIste" -> {
                        if (izinVar()) {
                            result.success(true)
                        } else if (!kurulu()) {
                            result.success(false)
                        } else {
                            bekleyenIzin?.success(false)
                            bekleyenIzin = result
                            ActivityCompat.requestPermissions(this, arrayOf(izin), izinKodu)
                        }
                    }
                    "calistir" -> {
                        try {
                            calistir(
                                call.argument<String>("yol")!!,
                                call.argument<List<String>>("args") ?: emptyList(),
                                call.argument<Boolean>("arkaPlan") ?: true,
                                call.argument<String>("klasor"),
                            )
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("calistirilamadi", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun kurulu(): Boolean = try {
        packageManager.getPackageInfo(termux, 0)
        true
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }

    private fun izinVar(): Boolean =
        ContextCompat.checkSelfPermission(this, izin) == PackageManager.PERMISSION_GRANTED

    private fun calistir(yol: String, args: List<String>, arkaPlan: Boolean, klasor: String?) {
        val niyet = Intent().apply {
            setClassName(termux, "com.termux.app.RunCommandService")
            action = "com.termux.RUN_COMMAND"
            putExtra("com.termux.RUN_COMMAND_PATH", yol)
            putExtra("com.termux.RUN_COMMAND_ARGUMENTS", args.toTypedArray())
            putExtra("com.termux.RUN_COMMAND_BACKGROUND", arkaPlan)
            if (klasor != null) putExtra("com.termux.RUN_COMMAND_WORKDIR", klasor)
            // ön planda açılan oturuma geç (giriş ekranları için)
            putExtra("com.termux.RUN_COMMAND_SESSION_ACTION", "0")
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(niyet)
        } else {
            startService(niyet)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == izinKodu) {
            bekleyenIzin?.success(
                grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            )
            bekleyenIzin = null
        }
    }
}
