package tr.com.lifeos.atolye

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.ServiceCompat

/**
 * Atölye'nin bildirimleri.
 *
 * - "calisan": bir ajan çalışırken görünen, sessiz, kalıcı bildirim. Ön plan
 *   servisine (AtolyeServisi) bağlıdır; uygulama arka plandayken Android'in
 *   süreci öldürmesini önler, böylece köprüden gelen olaylar kaçmaz.
 * - "olaylar": onay gerektiğinde, iş bittiğinde ya da hata olduğunda; sesli,
 *   önemli. Dokununca ilgili oturum açılır.
 */
object Bildirimler {
    const val KANAL_CALISAN = "calisan"
    const val KANAL_OLAYLAR = "olaylar"
    const val SERVIS_KIMLIGI = 1
    const val EK_OTURUM = "tr.com.lifeos.atolye.OTURUM"

    /** Sesli konuşmayı aç/kapat (kısayol, bildirim düğmesi). */
    const val SES = "tr.com.lifeos.atolye.SES"

    fun kanallariKur(baglam: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val yonetici = baglam.getSystemService(NotificationManager::class.java)
        yonetici.createNotificationChannel(
            NotificationChannel(KANAL_CALISAN, "Çalışan ajan", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Bir ajan çalışırken görünür; uygulamanın arka planda kapanmasını önler."
                setShowBadge(false)
            }
        )
        yonetici.createNotificationChannel(
            NotificationChannel(KANAL_OLAYLAR, "Onay ve sonuçlar", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Ajan onay beklediğinde ya da işi bittiğinde."
            }
        )
    }

    /** Uygulamayı (verilirse o oturumla) açan niyet. */
    fun acmaNiyeti(baglam: Context, oturum: String?, istek: Int): PendingIntent {
        val niyet = Intent(baglam, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            if (oturum != null) putExtra(EK_OTURUM, oturum)
        }
        return PendingIntent.getActivity(
            baglam, istek, niyet,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    fun calisanBildirimi(
        baglam: Context, baslik: String, metin: String, oturum: String?, ilerleme: Boolean,
        ses: Boolean = false,
    ): Notification {
        // "Konuş" / "Konuşmayı bitir": uygulamayı öne getirip sesi açar ya da kapatır
        val konus = PendingIntent.getActivity(
            baglam, 2,
            Intent(baglam, MainActivity::class.java).setAction(SES)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val cik = PendingIntent.getService(
            baglam, 1,
            Intent(baglam, AtolyeServisi::class.java).setAction(AtolyeServisi.CIK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val b = NotificationCompat.Builder(baglam, KANAL_CALISAN)
            .setSmallIcon(R.drawable.ic_bildirim)
            .setContentTitle(baslik)
            .setContentText(metin)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setShowWhen(false)
            .setCategory(if (ilerleme) NotificationCompat.CATEGORY_PROGRESS else NotificationCompat.CATEGORY_SERVICE)
            .setContentIntent(acmaNiyeti(baglam, oturum, 0))
            .addAction(0, if (ses) "Konuşmayı bitir" else "Konuş", konus)
            .addAction(0, "Atölye'den çık", cik)
        if (ilerleme) b.setProgress(0, 0, true)
        return b.build()
    }

    /** Onay bildirimindeki düğmenin niyeti: kararı OnayAlici üzerinden Dart'a iletir. */
    private fun kararNiyeti(baglam: Context, kimlik: Int, oturum: String, rid: String, karar: String): PendingIntent {
        val niyet = Intent(baglam, OnayAlici::class.java).apply {
            action = "tr.com.lifeos.atolye.KARAR.$karar"
            putExtra("kimlik", kimlik)
            putExtra("oturum", oturum)
            putExtra("rid", rid)
            putExtra("karar", karar)
        }
        // istek kodu karar başına ayrı: aynı bildirimin üç düğmesi birbirini ezmesin
        val istek = kimlik * 4 + listOf("izin", "hep", "red").indexOf(karar).coerceAtLeast(0)
        return PendingIntent.getBroadcast(
            baglam, istek, niyet,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    fun goster(
        baglam: Context, kimlik: Int, baslik: String, metin: String, oturum: String?, onemli: Boolean,
        rid: String? = null,
    ) {
        val b = NotificationCompat.Builder(baglam, KANAL_OLAYLAR)
            .setSmallIcon(R.drawable.ic_bildirim)
            .setContentTitle(baslik)
            .setContentText(metin)
            .setStyle(NotificationCompat.BigTextStyle().bigText(metin))
            .setAutoCancel(true)
            .setPriority(if (onemli) NotificationCompat.PRIORITY_HIGH else NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(if (onemli) NotificationCompat.CATEGORY_REMINDER else NotificationCompat.CATEGORY_STATUS)
            .setContentIntent(acmaNiyeti(baglam, oturum, kimlik))
        if (rid != null && oturum != null) {
            b.addAction(0, "İzin ver", kararNiyeti(baglam, kimlik, oturum, rid, "izin"))
            b.addAction(0, "Bu oturumda hep", kararNiyeti(baglam, kimlik, oturum, rid, "hep"))
            b.addAction(0, "Reddet", kararNiyeti(baglam, kimlik, oturum, rid, "red"))
        }
        val bildirim = b.build()
        try {
            NotificationManagerCompat.from(baglam).notify(kimlik, bildirim)
        } catch (_: SecurityException) {
            // bildirim izni verilmemiş: sessizce geç
        }
    }

    fun iptal(baglam: Context, kimlik: Int) = NotificationManagerCompat.from(baglam).cancel(kimlik)

    /** Dart tarafına giden kanal (uygulama açıkken; motor yoksa null). */
    @Volatile var kanal: io.flutter.plugin.common.MethodChannel? = null
}

/**
 * Onay bildirimindeki "İzin ver / Bu oturumda hep / Reddet" düğmeleri. Karar
 * uygulamanın açık bağlantısıyla köprüye gider; uygulama yoksa kullanıcıdan
 * Atölye'yi açması istenir.
 */
class OnayAlici : android.content.BroadcastReceiver() {
    override fun onReceive(baglam: Context, niyet: Intent) {
        val kimlik = niyet.getIntExtra("kimlik", 0)
        val oturum = niyet.getStringExtra("oturum") ?: return
        val rid = niyet.getStringExtra("rid") ?: return
        val karar = niyet.getStringExtra("karar") ?: return
        Bildirimler.iptal(baglam, kimlik)
        val kanal = Bildirimler.kanal
        if (kanal == null) {
            Bildirimler.goster(baglam, kimlik, "Onay iletilemedi", "Atölye kapalı; onaylamak için dokun.", oturum, true)
            return
        }
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            kanal.invokeMethod("karar", mapOf("oturum" to oturum, "rid" to rid, "karar" to karar))
        }
    }
}

/**
 * Atölye açıkken bildirim alanında duran ön plan servisi. İş yapmaz; sürecin
 * önceliğini yüksek tutar ki Android arka plandaki uygulamayı öldürmesin ve
 * köprüden gelen olaylar kaçmasın. Ajan çalışırken "çalışıyor", sesli
 * konuşmada mikrofon türüyle çalışır. "Atölye'den çık" süreci kapatır.
 */
class AtolyeServisi : Service() {
    companion object {
        const val CIK = "tr.com.lifeos.atolye.CIK"

        /** Servis ön planda mı, mikrofon türüyle mi. */
        @Volatile var calisiyor = false
        @Volatile var mikrofonla = false
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == CIK) {
            calisiyor = false
            ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
            stopSelf()
            // Kullanıcı Atölye'yi bilerek kapattı: ekran ve süreç de kapansın.
            android.os.Process.killProcess(android.os.Process.myPid())
            return START_NOT_STICKY
        }
        Bildirimler.kanallariKur(this)
        val ses = intent?.getBooleanExtra("ses", false) == true
        val bildirim = Bildirimler.calisanBildirimi(
            this,
            intent?.getStringExtra("baslik") ?: "Atölye açık",
            intent?.getStringExtra("metin") ?: "",
            intent?.getStringExtra("oturum"),
            intent?.getBooleanExtra("ilerleme", true) ?: true,
            ses,
        )
        var tur = 0
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            tur = ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
        }
        if (ses && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            tur = tur or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
        }
        try {
            ServiceCompat.startForeground(this, Bildirimler.SERVIS_KIMLIGI, bildirim, tur)
            mikrofonla = ses
        } catch (e: Exception) {
            // Mikrofon türü reddedildiyse (izin yok) mikrofonsuz sürdür.
            ServiceCompat.startForeground(
                this, Bildirimler.SERVIS_KIMLIGI, bildirim,
                tur and ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE.inv(),
            )
            mikrofonla = false
        }
        calisiyor = true
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        calisiyor = false
        mikrofonla = false
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }
}
