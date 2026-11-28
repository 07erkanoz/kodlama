package tr.com.lifeos.atolye

import android.app.Activity
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.ColorStateList
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Ana ekran widget'ı. Tek bir sınıf her boyuta uyar: 2×2'de özet, geniş ve
 * ince bırakılınca tek satır şerit, büyütülünce onay kartı, oturum listesi
 * ve kota çubukları. Yükseklik arttıkça listeye satır eklenir.
 *
 * Veriyi Dart gönderir (WidgetYoneticisi → "widget" kanalı) ve burada
 * SharedPreferences'ta saklanır; uygulama kapalıyken widget son bilinen
 * hâli "kapalı" olarak gösterir. İki kayıt var (küçük ve ayrıntılı) ama
 * yalnızca ilk yerleşim boyutları farklı; ikisi de serbestçe boyutlanır.
 */
open class AtolyeWidget : AppWidgetProvider() {
    override fun onUpdate(baglam: Context, yonetici: AppWidgetManager, kimlikler: IntArray) {
        for (k in kimlikler) ciz(baglam, yonetici, k)
    }

    override fun onAppWidgetOptionsChanged(
        baglam: Context, yonetici: AppWidgetManager, kimlik: Int, secenekler: Bundle?,
    ) = ciz(baglam, yonetici, kimlik)

    override fun onReceive(baglam: Context, niyet: Intent) {
        super.onReceive(baglam, niyet)
        if (niyet.action == YENILE) {
            Bildirimler.kanal?.let { k ->
                Handler(Looper.getMainLooper()).post { k.invokeMethod("widgetYenile", null) }
            }
            hepsiniGuncelle(baglam)
        }
    }

    companion object {
        const val YENILE = "tr.com.lifeos.atolye.WIDGET_YENILE"
        const val YENI = "tr.com.lifeos.atolye.YENI"
        const val ARA = "tr.com.lifeos.atolye.ARA"
        const val AYAR = "tr.com.lifeos.atolye.WIDGET_AYAR"
        private const val DEPO = "atolye_widget"

        /** Dart'tan gelen anlık durum (JSON); kaydedip bütün widget'ları çizer. */
        fun kaydet(baglam: Context, json: String) {
            baglam.getSharedPreferences(DEPO, Context.MODE_PRIVATE).edit().putString("durum", json).apply()
            hepsiniGuncelle(baglam)
        }

        fun hepsiniGuncelle(baglam: Context) {
            val yonetici = AppWidgetManager.getInstance(baglam)
            for (sinif in listOf(AtolyeWidget::class.java, AtolyeWidgetBuyuk::class.java)) {
                for (k in yonetici.getAppWidgetIds(ComponentName(baglam, sinif))) ciz(baglam, yonetici, k)
            }
        }

        fun ekliMi(baglam: Context): Boolean {
            val yonetici = AppWidgetManager.getInstance(baglam)
            return listOf(AtolyeWidget::class.java, AtolyeWidgetBuyuk::class.java).any {
                yonetici.getAppWidgetIds(ComponentName(baglam, it)).isNotEmpty()
            }
        }

        private fun ciz(baglam: Context, yonetici: AppWidgetManager, kimlik: Int) {
            val v = Veri.oku(baglam)
            val sec = yonetici.getAppWidgetOptions(kimlik)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                @Suppress("DEPRECATION")
                val boylar = sec.getParcelableArrayList<SizeF>(AppWidgetManager.OPTION_APPWIDGET_SIZES)
                if (!boylar.isNullOrEmpty()) {
                    // Android 12+: başlatıcı her boy için hazır görünümden uygun olanı seçer.
                    val harita = boylar.distinct().take(16).associateWith { gorunum(baglam, v, it.width, it.height) }
                    yonetici.updateAppWidget(kimlik, RemoteViews(harita))
                    return
                }
            }
            // Eski sürümler: dikeyde genişlik en dar, yükseklik en uzun değerdir.
            val g = sec.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 110).toFloat()
            val y = sec.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 110).toFloat()
            yonetici.updateAppWidget(kimlik, gorunum(baglam, v, g, y))
        }

        // --- veri

        private class Ayar(j: JSONObject?) {
            val saydamlik = j?.optInt("saydamlik", 28) ?: 28
            val kose = j?.optInt("kose", 20) ?: 20
            val tema = j?.optString("tema", "koyu") ?: "koyu"
            val oturum = j?.optInt("oturum", 0) ?: 0
            val onay = j?.optBoolean("onay", true) ?: true
            val kota = j?.optBoolean("kota", true) ?: true
        }

        private class Veri(j: JSONObject, val canli: Boolean) {
            val bagli = canli && j.optBoolean("bagli", false)
            val calisan = if (canli) j.optInt("calisan", 0) else 0
            val onay: JSONObject? = if (canli) j.optJSONObject("onay") else null
            val onaySayisi = if (canli) j.optInt("onaySayisi", 0) else 0
            val oturumlar: JSONArray = j.optJSONArray("oturumlar") ?: JSONArray()
            val kota: JSONObject? = j.optJSONObject("kota")
            val ayar = Ayar(j.optJSONObject("ayar"))

            companion object {
                fun oku(baglam: Context): Veri {
                    val ham = baglam.getSharedPreferences(DEPO, Context.MODE_PRIVATE).getString("durum", null)
                    val j = try { JSONObject(ham ?: "{}") } catch (_: Exception) { JSONObject() }
                    // Flutter motoru yoksa uygulama kapalıdır: son bilinen hâl gösterilir.
                    return Veri(j, Bildirimler.kanal != null)
                }
            }
        }

        // --- renkler

        private class Renk(
            val arka: Int, val yazi: Int, val yazi2: Int, val vurgu: Int, val koyu: Boolean,
        ) {
            val onayYazi = if (koyu) 0xFFFAC775.toInt() else 0xFF854F0B.toInt()
            val yesil = if (koyu) 0xFF5DCAA5.toInt() else 0xFF0F6E56.toInt()
            val kirmizi = if (koyu) 0xFFF09595.toInt() else 0xFFA32D2D.toInt()
        }

        private val KOYU = Renk(0xFF14141C.toInt(), 0xFFECEBFF.toInt(), 0xFFC4C3DE.toInt(), 0xFF8B8CF8.toInt(), true)
        private val ACIK = Renk(0xFFFAFAFC.toInt(), 0xFF1B1B24.toInt(), 0xFF3E3D4C.toInt(), 0xFF534AB7.toInt(), false)
        private const val CLAUDE = 0xFFD97757.toInt()

        private fun renk(baglam: Context, tema: String): Renk {
            val gece = (baglam.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES
            return when (tema) {
                "acik" -> ACIK
                "sistem" -> if (gece) KOYU else ACIK
                "duvar" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    // Material You: duvar kağıdından türeyen sistem renkleri.
                    fun c(id: Int) = baglam.getColor(id)
                    if (gece) Renk(
                        c(android.R.color.system_neutral1_900), c(android.R.color.system_neutral1_50),
                        c(android.R.color.system_neutral2_200), c(android.R.color.system_accent1_200), true,
                    ) else Renk(
                        c(android.R.color.system_neutral1_50), c(android.R.color.system_neutral1_900),
                        c(android.R.color.system_neutral2_700), c(android.R.color.system_accent1_600), false,
                    )
                } else if (gece) KOYU else ACIK
                else -> KOYU
            }
        }

        // --- çizim

        private fun gorunum(baglam: Context, v: Veri, gen: Float, yuk: Float): RemoteViews {
            val r = renk(baglam, v.ayar.tema)
            val duzen = when {
                yuk < 100 && gen >= 180 -> R.layout.widget_serit
                gen < 200 -> R.layout.widget_kucuk
                else -> R.layout.widget_buyuk
            }
            val g = RemoteViews(baglam.packageName, duzen)
            arkaPlan(g, r, v.ayar)
            g.setInt(R.id.simge, "setColorFilter", r.vurgu)
            g.setImageViewResource(R.id.nokta, R.drawable.widget_nokta)
            g.setInt(
                R.id.nokta, "setColorFilter",
                when {
                    !v.canli -> r.yazi2
                    v.onaySayisi > 0 -> r.onayYazi
                    v.bagli -> r.yesil
                    else -> r.kirmizi
                },
            )
            // Widget'a dokununca: onay bekleyen oturum ya da uygulama.
            g.setOnClickPendingIntent(R.id.kok, Bildirimler.acmaNiyeti(baglam, v.onay?.optString("oturum"), 6))
            dugme(baglam, g, r, R.id.konus, R.id.konus_simge, R.id.konus_yazi, Bildirimler.SES, 2)
            dugme(baglam, g, r, R.id.yeni, R.id.yeni_simge, R.id.yeni_yazi, YENI, 3)
            when (duzen) {
                R.layout.widget_serit -> serit(g, r, v)
                R.layout.widget_kucuk -> kucuk(baglam, g, r, v)
                else -> buyuk(baglam, g, r, v, yuk)
            }
            return g
        }

        private fun arkaPlan(g: RemoteViews, r: Renk, a: Ayar) {
            val adim = (a.kose.coerceIn(0, 32) / 4.0).roundToInt() * 4
            val kose = when (adim) {
                0 -> R.drawable.widget_arka_0; 4 -> R.drawable.widget_arka_4
                8 -> R.drawable.widget_arka_8; 12 -> R.drawable.widget_arka_12
                16 -> R.drawable.widget_arka_16; 20 -> R.drawable.widget_arka_20
                24 -> R.drawable.widget_arka_24; 28 -> R.drawable.widget_arka_28
                else -> R.drawable.widget_arka_32
            }
            g.setImageViewResource(R.id.arka, kose)
            g.setInt(R.id.arka, "setColorFilter", r.arka or 0xFF000000.toInt())
            g.setInt(R.id.arka, "setImageAlpha", ((100 - a.saydamlik.coerceIn(0, 100)) * 255 / 100))
        }

        private fun dugme(
            baglam: Context, g: RemoteViews, r: Renk, kap: Int, simge: Int, yazi: Int?, eylem: String, istek: Int,
        ) {
            g.setInt(kap, "setBackgroundResource", if (r.koyu) R.drawable.widget_dugme_koyu else R.drawable.widget_dugme_acik)
            g.setInt(simge, "setColorFilter", r.yazi)
            if (yazi != null) g.setTextColor(yazi, r.yazi)
            val niyet = Intent(baglam, MainActivity::class.java).setAction(eylem)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            g.setOnClickPendingIntent(
                kap,
                PendingIntent.getActivity(baglam, istek, niyet, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE),
            )
        }

        private fun serit(g: RemoteViews, r: Renk, v: Veri) {
            val parca = mutableListOf<String>()
            if (v.calisan > 0) parca += "${v.calisan} çalışıyor"
            if (v.onaySayisi > 0) parca += "${v.onaySayisi} onay"
            g.setTextViewText(
                R.id.ozet,
                when {
                    !v.canli -> "Atölye kapalı"
                    parca.isNotEmpty() -> parca.joinToString(" · ")
                    v.bagli -> "Boşta · köprü bağlı"
                    else -> "Köprüye bağlanıyor…"
                },
            )
            g.setTextColor(R.id.ozet, r.yazi)
        }

        private fun kucuk(baglam: Context, g: RemoteViews, r: Renk, v: Veri) {
            g.setTextColor(R.id.ad, r.yazi)
            g.setTextViewText(R.id.sayi, if (v.canli) "${v.calisan}" else "–")
            g.setTextColor(R.id.sayi, r.yazi)
            g.setTextViewText(
                R.id.sayi_yazi,
                when {
                    !v.canli -> "Atölye kapalı"
                    v.calisan > 0 -> "ajan çalışıyor"
                    v.bagli -> "boşta"
                    else -> "bağlanıyor…"
                },
            )
            g.setTextColor(R.id.sayi_yazi, r.yazi2)
            g.setViewVisibility(R.id.hap, if (v.onaySayisi > 0) View.VISIBLE else View.GONE)
            g.setTextViewText(R.id.hap, "${v.onaySayisi} onay bekliyor")
            g.setTextColor(R.id.hap, r.onayYazi)
            yenile(baglam, g, r)
        }

        private fun yenile(baglam: Context, g: RemoteViews, r: Renk) {
            g.setInt(R.id.yenile, "setColorFilter", r.yazi2)
            val niyet = Intent(baglam, AtolyeWidget::class.java).setAction(YENILE)
            g.setOnClickPendingIntent(
                R.id.yenile,
                PendingIntent.getBroadcast(baglam, 5, niyet, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE),
            )
        }

        private val SATIRLAR = listOf(
            intArrayOf(R.id.satir0, R.id.satir0_nokta, R.id.satir0_ad, R.id.satir0_durum),
            intArrayOf(R.id.satir1, R.id.satir1_nokta, R.id.satir1_ad, R.id.satir1_durum),
            intArrayOf(R.id.satir2, R.id.satir2_nokta, R.id.satir2_ad, R.id.satir2_durum),
            intArrayOf(R.id.satir3, R.id.satir3_nokta, R.id.satir3_ad, R.id.satir3_durum),
            intArrayOf(R.id.satir4, R.id.satir4_nokta, R.id.satir4_ad, R.id.satir4_durum),
            intArrayOf(R.id.satir5, R.id.satir5_nokta, R.id.satir5_ad, R.id.satir5_durum),
            intArrayOf(R.id.satir6, R.id.satir6_nokta, R.id.satir6_ad, R.id.satir6_durum),
            intArrayOf(R.id.satir7, R.id.satir7_nokta, R.id.satir7_ad, R.id.satir7_durum),
        )

        private fun buyuk(baglam: Context, g: RemoteViews, r: Renk, v: Veri, yuk: Float) {
            g.setTextColor(R.id.ad, r.yazi)
            g.setTextColor(R.id.alt_baslik, r.yazi2)
            g.setTextViewText(
                R.id.alt_baslik,
                when {
                    !v.canli -> "· kapalı, açmak için dokun"
                    !v.bagli -> "· köprüye bağlanıyor…"
                    v.calisan > 0 -> "· ${v.calisan} çalışıyor"
                    else -> "· köprü bağlı"
                },
            )
            yenile(baglam, g, r)
            dugme(baglam, g, r, R.id.ara, R.id.ara_simge, R.id.ara_yazi, ARA, 4)

            // Yer hesabı (dp): dolgu 28, başlık 22, düğmeler 42, onay kartı ~100, kota 42, satır 26.
            var kalan = yuk - 28 - 22
            val onay = if (v.ayar.onay) v.onay else null
            var onayGoster = false
            var dugmeler = true
            if (onay != null && kalan >= 100) {
                onayGoster = true
                kalan -= 100
                // Yer darsa onay kartı alttaki düğmelerden önce gelir.
                if (kalan < 42) dugmeler = false
            }
            if (dugmeler) kalan -= 42
            val kota = v.kota
            val kotaVar = v.ayar.kota && kota != null && (kota.has("claude") || kota.has("codex"))
            val kotaGoster = kotaVar && kalan >= 42 + 26 * 2
            if (kotaGoster) kalan -= 42
            val sinir = if (v.ayar.oturum > 0) v.ayar.oturum else SATIRLAR.size
            val satirSayisi = min(min(max(0, ((kalan - 8) / 26).toInt()), sinir), min(v.oturumlar.length(), SATIRLAR.size))

            g.setViewVisibility(R.id.onay, if (onayGoster) View.VISIBLE else View.GONE)
            if (onayGoster && onay != null) onayKarti(baglam, g, r, v, onay)
            g.setViewVisibility(R.id.konus, if (dugmeler) View.VISIBLE else View.GONE)
            g.setViewVisibility(R.id.yeni, if (dugmeler) View.VISIBLE else View.GONE)
            g.setViewVisibility(R.id.ara, if (dugmeler) View.VISIBLE else View.GONE)

            for ((i, s) in SATIRLAR.withIndex()) {
                if (i >= satirSayisi) {
                    g.setViewVisibility(s[0], View.GONE)
                    continue
                }
                val o = v.oturumlar.getJSONObject(i)
                g.setViewVisibility(s[0], View.VISIBLE)
                g.setInt(s[1], "setColorFilter", if (o.optString("ajan") == "claude") CLAUDE else r.vurgu)
                val baslik = o.optString("baslik").ifBlank { o.optString("yer").ifBlank { "Yeni oturum" } }
                g.setTextViewText(s[2], "${o.optString("ajanAdi")} · $baslik")
                g.setTextColor(s[2], r.yazi)
                val (durum, renk) = when {
                    v.canli && o.optBoolean("onay") -> "onay bekliyor" to r.onayYazi
                    v.canli && o.optString("durum") == "calisiyor" -> "çalışıyor" to r.yesil
                    else -> once(o.optDouble("zaman", 0.0)) to r.yazi2
                }
                g.setTextViewText(s[3], durum)
                g.setTextColor(s[3], renk)
                g.setOnClickPendingIntent(s[0], Bildirimler.acmaNiyeti(baglam, o.optString("id"), 50000 + i))
            }
            val bos = v.oturumlar.length() == 0 && satirSayisi == 0 && kalan >= 34
            g.setViewVisibility(R.id.bos, if (bos) View.VISIBLE else View.GONE)
            g.setTextColor(R.id.bos, r.yazi2)
            g.setTextViewText(R.id.bos, if (v.canli) "Henüz oturum yok · + ile başlat" else "Atölye kapalı")

            g.setViewVisibility(R.id.kota, if (kotaGoster) View.VISIBLE else View.GONE)
            if (kotaGoster && kota != null) {
                kotaSatiri(g, r, kota.optJSONObject("claude"), R.id.kota_claude, R.id.kota_claude_ad, R.id.kota_claude_cubuk, R.id.kota_claude_yazi)
                kotaSatiri(g, r, kota.optJSONObject("codex"), R.id.kota_codex, R.id.kota_codex_ad, R.id.kota_codex_cubuk, R.id.kota_codex_yazi)
            }
        }

        private fun onayKarti(baglam: Context, g: RemoteViews, r: Renk, v: Veri, o: JSONObject) {
            val ek = if (v.onaySayisi > 1) " (+${v.onaySayisi - 1})" else ""
            g.setTextViewText(R.id.onay_baslik, "${o.optString("ajanAdi")} · ${o.optString("baslik")}$ek")
            g.setTextColor(R.id.onay_baslik, r.onayYazi)
            g.setTextViewText(R.id.onay_metin, o.optString("metin"))
            g.setTextColor(R.id.onay_metin, r.yazi)
            val kimlik = o.optInt("kimlik", 90)
            val oturum = o.optString("oturum")
            val rid = o.optString("rid")
            for ((kap, yazi, karar) in listOf(
                Triple(R.id.izin, R.id.izin_yazi, "izin"),
                Triple(R.id.hep, R.id.hep_yazi, "hep"),
                Triple(R.id.red, R.id.red_yazi, "red"),
            )) {
                g.setOnClickPendingIntent(kap, Bildirimler.kararNiyeti(baglam, kimlik, oturum, rid, karar))
                if (karar == "izin") {
                    g.setInt(kap, "setBackgroundResource", R.drawable.widget_dugme_vurgu)
                    var yaziRengi = 0xFF14141C.toInt()
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        g.setColorStateList(kap, "setBackgroundTintList", ColorStateList.valueOf(r.vurgu))
                        if (!r.koyu) yaziRengi = 0xFFFFFFFF.toInt()
                    }
                    g.setTextColor(yazi, yaziRengi)
                } else {
                    g.setInt(kap, "setBackgroundResource", if (r.koyu) R.drawable.widget_dugme_koyu else R.drawable.widget_dugme_acik)
                    g.setTextColor(yazi, r.yazi)
                }
            }
        }

        private fun kotaSatiri(g: RemoteViews, r: Renk, p: JSONObject?, kap: Int, ad: Int, cubuk: Int, yazi: Int) {
            if (p == null) {
                g.setViewVisibility(kap, View.GONE)
                return
            }
            g.setViewVisibility(kap, View.VISIBLE)
            val yuzde = p.optInt("yuzde", 0).coerceIn(0, 100)
            g.setProgressBar(cubuk, 100, yuzde, false)
            g.setTextColor(ad, r.yazi2)
            g.setTextColor(yazi, r.yazi2)
            val sifir = p.optDouble("sifirlanma", 0.0)
            val kalan = (sifir - System.currentTimeMillis() / 1000.0).toLong()
            val sure = when {
                sifir <= 0 || kalan <= 0 -> ""
                kalan >= 86400 -> " · ${kalan / 86400} g"
                kalan >= 3600 -> " · ${kalan / 3600} sa"
                else -> " · ${max(1, kalan / 60)} dk"
            }
            g.setTextViewText(yazi, "%$yuzde$sure")
        }

        private fun once(zaman: Double): String {
            if (zaman <= 0) return ""
            val d = (System.currentTimeMillis() / 1000.0 - zaman).toLong()
            return when {
                d < 60 -> "az önce"
                d < 3600 -> "${d / 60} dk önce"
                d < 86400 -> "${d / 3600} sa önce"
                d < 172800 -> "dün"
                else -> "${d / 86400} g önce"
            }
        }
    }
}

/** Widget seçicide ikinci kayıt: ilk yerleşimi 4×3 (ayrıntılı); davranışı aynı. */
class AtolyeWidgetBuyuk : AtolyeWidget()

/**
 * Widget'ın "ayarla" adımı (yerleştirirken ya da uzun basıp yeniden
 * yapılandırırken). Ayarlar uygulamanın içinde, canlı önizlemeyle yapılır:
 * burası yalnızca Atölye'yi o sayfada açıp hemen kapanır.
 */
class WidgetAyarEtkinligi : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val kimlik = intent?.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            ?: AppWidgetManager.INVALID_APPWIDGET_ID
        setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, kimlik))
        startActivity(
            Intent(this, MainActivity::class.java).setAction(AtolyeWidget.AYAR)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
        )
        AtolyeWidget.hepsiniGuncelle(this)
        finish()
    }
}
