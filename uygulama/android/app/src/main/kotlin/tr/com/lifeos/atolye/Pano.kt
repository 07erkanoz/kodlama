package tr.com.lifeos.atolye

import android.app.Activity
import android.content.ClipboardManager
import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Panodaki resim (ekran görüntüsü kopyalandığında ya da bir uygulamada
 * "resmi kopyala" denince). Flutter'ın panosu yalnızca metin okur; burada
 * panodaki içerik adresi önbelleğe kopyalanır, yolu Dart'a verilir.
 */
class Pano(private val etkinlik: Activity, haberci: BinaryMessenger) {
    init {
        MethodChannel(haberci, "atolye/pano").setMethodCallHandler { call, result ->
            when (call.method) {
                "resim" -> Thread {
                    val sonuc = try { resim() } catch (_: Exception) { null }
                    etkinlik.runOnUiThread { result.success(sonuc) }
                }.start()
                else -> result.notImplemented()
            }
        }
    }

    private fun resim(): Map<String, Any?>? {
        val pano = etkinlik.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val kesit = pano.primaryClip ?: return null
        for (i in 0 until kesit.itemCount) {
            val adres = kesit.getItemAt(i).uri ?: continue
            val tur = etkinlik.contentResolver.getType(adres) ?: continue
            if (!tur.startsWith("image/")) continue
            val uzanti = tur.substringAfter('/').substringBefore('+').ifBlank { "png" }
            val klasor = File(etkinlik.cacheDir, "pano").apply { mkdirs() }
            val hedef = File(klasor, "pano_${System.currentTimeMillis()}.$uzanti")
            etkinlik.contentResolver.openInputStream(adres)?.use { g ->
                hedef.outputStream().use { g.copyTo(it) }
            } ?: continue
            return mapOf("ad" to hedef.name, "yol" to hedef.absolutePath)
        }
        return null
    }
}
