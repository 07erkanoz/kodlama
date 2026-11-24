package tr.com.lifeos.atolye

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Android'in paylaş menüsünden Atölye'ye gelenler (metin, bağlantı, resim,
 * dosya). Dosyalar uygulamanın önbelleğine kopyalanır (içerik adresleri
 * paylaşan uygulamanın izniyle kısa süre okunabilir), Dart'a yolları verilir;
 * Dart onları seçilen oturuma ek olarak yükler.
 */
class Paylasim(private val etkinlik: Activity, haberci: BinaryMessenger) {
    private val kanal = MethodChannel(haberci, "atolye/paylas")
    private var hazir: Map<String, Any?>? = null
    private var isleniyor = false
    private var bekleyen: MethodChannel.Result? = null
    private var dartHazir = false

    init {
        kanal.setMethodCallHandler { call, result ->
            when (call.method) {
                "acilisPaylasimi" -> {
                    dartHazir = true
                    when {
                        hazir != null -> {
                            result.success(hazir)
                            hazir = null
                        }
                        isleniyor -> {
                            bekleyen?.success(null)
                            bekleyen = result
                        }
                        else -> result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Paylaşım niyetiyse işler ve true döner. */
    fun isle(niyet: Intent?): Boolean {
        if (niyet == null) return false
        if (niyet.action != Intent.ACTION_SEND && niyet.action != Intent.ACTION_SEND_MULTIPLE) return false
        val metin = listOfNotNull(
            niyet.getStringExtra(Intent.EXTRA_SUBJECT),
            niyet.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString(),
        ).filter { it.isNotBlank() }.distinct().joinToString("\n\n")
        val adresler = akislar(niyet)
        isleniyor = true
        Thread {
            val dosyalar = kopyala(adresler)
            val sonuc = mapOf("metin" to metin, "dosyalar" to dosyalar)
            etkinlik.runOnUiThread { teslim(sonuc) }
        }.start()
        return true
    }

    private fun teslim(sonuc: Map<String, Any?>) {
        isleniyor = false
        val b = bekleyen
        when {
            b != null -> {
                bekleyen = null
                b.success(sonuc)
            }
            dartHazir -> kanal.invokeMethod("paylasildi", sonuc)
            else -> hazir = sonuc
        }
    }

    @Suppress("DEPRECATION")
    private fun akislar(niyet: Intent): List<Uri> {
        if (niyet.action == Intent.ACTION_SEND_MULTIPLE) {
            val liste = if (Build.VERSION.SDK_INT >= 33) {
                niyet.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                niyet.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
            }
            return liste?.filterNotNull() ?: emptyList()
        }
        val tek = if (Build.VERSION.SDK_INT >= 33) {
            niyet.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            niyet.getParcelableExtra(Intent.EXTRA_STREAM)
        }
        return listOfNotNull(tek)
    }

    private fun kopyala(adresler: List<Uri>): List<Map<String, Any?>> {
        val klasor = File(etkinlik.cacheDir, "paylasim/${System.currentTimeMillis()}")
        klasor.mkdirs()
        val cikti = mutableListOf<Map<String, Any?>>()
        for ((i, adres) in adresler.withIndex()) {
            try {
                val ad = (adiBul(adres) ?: "dosya$i").replace(Regex("[^\\w.\\-]"), "_")
                val hedef = File(klasor, ad)
                var boyut = 0L
                etkinlik.contentResolver.openInputStream(adres)?.use { girdi ->
                    hedef.outputStream().use { boyut = girdi.copyTo(it) }
                } ?: continue
                cikti.add(mapOf("ad" to ad, "yol" to hedef.absolutePath, "boyut" to boyut))
            } catch (_: Exception) {
                // okunamayan dosya atlanır
            }
        }
        return cikti
    }

    private fun adiBul(adres: Uri): String? {
        if (adres.scheme == "file") return adres.lastPathSegment
        return try {
            etkinlik.contentResolver.query(adres, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { if (it.moveToFirst()) it.getString(0) else null }
        } catch (_: Exception) {
            null
        }
    }
}
