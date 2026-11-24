package tr.com.lifeos.atolye

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File
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
    private val bildirimIzniKodu = 4712
    private var bekleyenBildirimIzni: MethodChannel.Result? = null
    private var bildirimKanali: MethodChannel? = null
    private var paylasim: Paylasim? = null

    /** Bildirime dokunularak açıldıysa hangi oturum (Dart bir kez alır). */
    private var acilisOturumu: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Bildirimler.kanallariKur(this)
        acilisOturumu = intent?.getStringExtra(Bildirimler.EK_OTURUM)
        paylasim = Paylasim(this, flutterEngine.dartExecutor.binaryMessenger).also { it.isle(intent) }
        bildirimKanali = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "atolye/bildirim").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "izinVar" -> result.success(bildirimIzniVar())
                    "izinIste" -> {
                        if (bildirimIzniVar()) {
                            result.success(true)
                        } else {
                            bekleyenBildirimIzni?.success(false)
                            bekleyenBildirimIzni = result
                            ActivityCompat.requestPermissions(
                                this@MainActivity,
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                bildirimIzniKodu,
                            )
                        }
                    }
                    "servis" -> {
                        val niyet = Intent(this@MainActivity, AtolyeServisi::class.java)
                        try {
                            if (call.argument<Boolean>("calisiyor") == true) {
                                niyet.putExtra("baslik", call.argument<String>("baslik"))
                                niyet.putExtra("metin", call.argument<String>("metin"))
                                niyet.putExtra("oturum", call.argument<String>("oturum"))
                                ContextCompat.startForegroundService(this@MainActivity, niyet)
                            } else {
                                stopService(niyet)
                            }
                            result.success(null)
                        } catch (e: Exception) {
                            // ör. Android 12+ arka plandan ön plan servisi başlatmaya izin vermez
                            result.error("servis", e.message, null)
                        }
                    }
                    "goster" -> {
                        Bildirimler.goster(
                            this@MainActivity,
                            call.argument<Int>("kimlik") ?: 100,
                            call.argument<String>("baslik") ?: "Atölye",
                            call.argument<String>("metin") ?: "",
                            call.argument<String>("oturum"),
                            call.argument<Boolean>("onemli") ?: false,
                        )
                        result.success(null)
                    }
                    "iptal" -> {
                        Bildirimler.iptal(this@MainActivity, call.argument<Int>("kimlik") ?: 0)
                        result.success(null)
                    }
                    "acilisOturumu" -> {
                        result.success(acilisOturumu)
                        acilisOturumu = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
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
                    "abiler" -> result.success(Build.SUPPORTED_ABIS.toList())
                    "termuxAyarlari" -> {
                        try {
                            startActivity(
                                Intent(
                                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                    Uri.parse("package:$termux"),
                                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            )
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("acilamadi", e.message, null)
                        }
                    }
                    "kurulumIzniVar" -> result.success(
                        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                            packageManager.canRequestPackageInstalls()
                    )
                    "kurulumIzniAc" -> {
                        startActivity(
                            Intent(
                                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:$packageName"),
                            )
                        )
                        result.success(null)
                    }
                    "apkKur" -> {
                        try {
                            val dosya = File(call.argument<String>("yol")!!)
                            val adres = FileProvider.getUriForFile(this, "$packageName.dosyalar", dosya)
                            startActivity(
                                Intent(Intent.ACTION_VIEW)
                                    .setDataAndType(adres, "application/vnd.android.package-archive")
                                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                            )
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("kurulamadi", e.message, null)
                        }
                    }
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

    private fun bildirimIzniVar(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED

    /** Uygulama açıkken bildirime dokunuldu: oturumu Dart'a bildir. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (paylasim?.isle(intent) == true) return
        val oturum = intent.getStringExtra(Bildirimler.EK_OTURUM) ?: return
        bildirimKanali?.invokeMethod("acildi", oturum)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == bildirimIzniKodu) {
            bekleyenBildirimIzni?.success(
                grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            )
            bekleyenBildirimIzni = null
        }
        if (requestCode == izinKodu) {
            bekleyenIzin?.success(
                grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            )
            bekleyenIzin = null
        }
    }
}
