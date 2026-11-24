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

    fun calisanBildirimi(baglam: Context, baslik: String, metin: String, oturum: String?): Notification =
        NotificationCompat.Builder(baglam, KANAL_CALISAN)
            .setSmallIcon(R.drawable.ic_bildirim)
            .setContentTitle(baslik)
            .setContentText(metin)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setProgress(0, 0, true)
            .setContentIntent(acmaNiyeti(baglam, oturum, 0))
            .build()

    fun goster(baglam: Context, kimlik: Int, baslik: String, metin: String, oturum: String?, onemli: Boolean) {
        val bildirim = NotificationCompat.Builder(baglam, KANAL_OLAYLAR)
            .setSmallIcon(R.drawable.ic_bildirim)
            .setContentTitle(baslik)
            .setContentText(metin)
            .setStyle(NotificationCompat.BigTextStyle().bigText(metin))
            .setAutoCancel(true)
            .setPriority(if (onemli) NotificationCompat.PRIORITY_HIGH else NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(if (onemli) NotificationCompat.CATEGORY_REMINDER else NotificationCompat.CATEGORY_STATUS)
            .setContentIntent(acmaNiyeti(baglam, oturum, kimlik))
            .build()
        try {
            NotificationManagerCompat.from(baglam).notify(kimlik, bildirim)
        } catch (_: SecurityException) {
            // bildirim izni verilmemiş: sessizce geç
        }
    }

    fun iptal(baglam: Context, kimlik: Int) = NotificationManagerCompat.from(baglam).cancel(kimlik)
}

/**
 * Bir ajan çalıştığı sürece açık kalan ön plan servisi. İş yapmaz; yalnızca
 * sürecin önceliğini yüksek tutar ve "çalışıyor" bildirimini taşır.
 */
class AtolyeServisi : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Bildirimler.kanallariKur(this)
        val bildirim = Bildirimler.calisanBildirimi(
            this,
            intent?.getStringExtra("baslik") ?: "Ajan çalışıyor",
            intent?.getStringExtra("metin") ?: "",
            intent?.getStringExtra("oturum"),
        )
        val tur = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
        } else {
            0
        }
        ServiceCompat.startForeground(this, Bildirimler.SERVIS_KIMLIGI, bildirim, tur)
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }
}
