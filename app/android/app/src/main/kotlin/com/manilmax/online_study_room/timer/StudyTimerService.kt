package com.manilmax.online_study_room.timer

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.manilmax.online_study_room.MainActivity
import com.manilmax.online_study_room.R
import com.manilmax.online_study_room.widgets.TimerWidgets
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant

/**
 * Çalışma sayacının **native** foreground servisi (V8-A · WP-42/51 birleşik).
 *
 * Neden native: Kullanıcı uygulamayı tamamen kapatmışken bile widget/bildirim
 * üzerinden **Başlat/Durdur** çalışsın diye. Bir BroadcastReceiver (widget veya
 * bildirim aksiyonu) bu servisi `startForegroundService` ile ayağa kaldırır;
 * Flutter motoruna ihtiyaç yoktur.
 *
 * Sorumluluk sınırı (önemli): Bu servis **oturum KAYDETMEZ**. Durdur'da tamamlanan
 * çalışma aralığını yalnızca `timer_pending_intervals` kuyruğuna yazar; gerçek
 * server-authoritative oturum yazımı, uygulama açılınca Dart tarafındaki
 * `StudyTimerNotifier._reconcileBackgroundTimer` tarafından yapılır. Böylece native
 * taraf "aptal" kalır: bildirim + prefs + widget yönetir, muhasebe Dart'ta.
 *
 * Bildirimde native `Chronometer` (setUsesChronometer + setWhen) kullanılır: saat
 * saniyede bir Flutter/Kotlin güncellemesi olmadan akar.
 */
class StudyTimerService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val startedAtMs = intent.getLongExtra(EXTRA_STARTED_AT_MS, System.currentTimeMillis())
                val mode = intent.getStringExtra(EXTRA_MODE) ?: "stopwatch"
                handleStart(startedAtMs, mode)
            }
            ACTION_STOP -> handleStop(recordInterval = true)
            ACTION_STOP_SILENT -> handleStop(recordInterval = false)
            ACTION_TOGGLE -> {
                if (prefs().contains(KEY_STARTED_AT)) {
                    handleStop(recordInterval = true)
                } else {
                    handleStart(System.currentTimeMillis(), "stopwatch")
                }
            }
            else -> {
                // Bilinmeyen komut: servis boşuna ayakta kalmasın.
                if (!prefs().contains(KEY_STARTED_AT)) stopSelf()
            }
        }
        return START_STICKY
    }

    private fun handleStart(startedAtMs: Long, mode: String) {
        val editor = prefs().edit()
        editor.putString(KEY_STARTED_AT, Instant.ofEpochMilli(startedAtMs).toString())
        editor.putLong(KEY_STARTED_AT_MS, startedAtMs)
        editor.putString(KEY_MODE, mode)
        editor.putString(KEY_FG_MODE, "running")
        // Cold-start (widget'tan) faz/döngü yoksa güvenli varsayılan yaz ki Dart
        // restore tutarlı olsun.
        if (!prefs().contains(KEY_PHASE)) editor.putString(KEY_PHASE, "work")
        if (!prefs().contains(KEY_CYCLE)) editor.putInt(KEY_CYCLE, 1)
        editor.apply()

        startForegroundCompat(buildRunningNotification(startedAtMs))
        TimerWidgets.updateAll(this)
        notifyStateChanged()
    }

    private fun handleStop(recordInterval: Boolean) {
        val p = prefs()
        if (recordInterval) {
            val startedAtMs = p.getLong(KEY_STARTED_AT_MS, 0L)
            val phase = p.getString(KEY_PHASE, "work") ?: "work"
            val nowMs = System.currentTimeMillis()
            // Yalnız çalışma fazı kaydedilir (mola sayılmaz); kronometrede faz hep work.
            if (startedAtMs in 1 until nowMs && phase == "work") {
                appendPendingInterval(
                    p,
                    startMs = startedAtMs,
                    endMs = nowMs,
                    subject = p.getString(KEY_SUBJECT, "") ?: "",
                )
            }
        }

        // Aktif oturum bitti (idle): started_at kalksın, mod idle.
        p.edit()
            .remove(KEY_STARTED_AT)
            .remove(KEY_STARTED_AT_MS)
            .putString(KEY_FG_MODE, "idle")
            .apply()

        // FGS'i kaldır ama idle bildirimi (00:00:00 + Başlat) — kaydırılıp
        // atılabilir (ongoing değil) — kalsın ki app açmadan tekrar başlatılabilsin.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(Service.STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        notificationManager().notify(NOTIFICATION_ID, buildIdleNotification())
        TimerWidgets.updateAll(this)
        notifyStateChanged()
        stopSelf()
    }

    private fun startForegroundCompat(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildRunningNotification(startedAtMs: Long): Notification {
        ensureChannel()
        return baseBuilder()
            .setOngoing(true)
            .setUsesChronometer(true)
            .setWhen(startedAtMs)
            .setContentTitle(null)
            .addAction(0, "Durdur", actionPending(ACTION_STOP, 1))
            .setContentIntent(openAppPending())
            .build()
    }

    private fun buildIdleNotification(): Notification {
        ensureChannel()
        return baseBuilder()
            .setOngoing(false)
            .setUsesChronometer(false)
            .setContentTitle("00:00:00")
            .addAction(0, "Başlat", actionPending(ACTION_START, 2))
            .setContentIntent(openAppPending())
            .build()
    }

    private fun baseBuilder(): NotificationCompat.Builder =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentText("")
            .setOnlyAlertOnce(true)
            .setSound(null)
            .setVibrate(null)
            .setCategory(NotificationCompat.CATEGORY_STOPWATCH)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)

    private fun actionPending(action: String, requestCode: Int): PendingIntent {
        val intent = Intent(this, StudyTimerService::class.java).apply { this.action = action }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getService(this, requestCode, intent, flags)
    }

    private fun openAppPending(): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getActivity(this, 0, intent, flags)
    }

    private fun appendPendingInterval(
        p: SharedPreferences,
        startMs: Long,
        endMs: Long,
        subject: String,
    ) {
        val list = try {
            JSONArray(p.getString(KEY_PENDING_INTERVALS, "[]") ?: "[]")
        } catch (_: Exception) {
            JSONArray()
        }
        list.put(
            JSONObject()
                .put("start", Instant.ofEpochMilli(startMs).toString())
                .put("end", Instant.ofEpochMilli(endMs).toString())
                .put("subject", subject),
        )
        p.edit().putString(KEY_PENDING_INTERVALS, list.toString()).apply()
    }

    /** Uygulama önplandaysa Dart'ın hemen uzlaşması için (yalnız kendi paketimize)
     *  yayın gönder. MainActivity çalışırken bir runtime receiver bunu dinler. */
    private fun notifyStateChanged() {
        sendBroadcast(
            Intent(BROADCAST_STATE_CHANGED).setPackage(packageName),
        )
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val existing = notificationManager().getNotificationChannel(CHANNEL_ID)
        if (existing != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Çalışma sayacı",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Sayaç çalışırken canlı süreyi gösteren bildirim"
            setSound(null, null)
            enableVibration(false)
            setShowBadge(false)
        }
        notificationManager().createNotificationChannel(channel)
    }

    private fun notificationManager(): NotificationManager =
        getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun prefs(): SharedPreferences =
        getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

    companion object {
        const val ACTION_START = "com.manilmax.online_study_room.timer.START"
        const val ACTION_STOP = "com.manilmax.online_study_room.timer.STOP"
        const val ACTION_STOP_SILENT = "com.manilmax.online_study_room.timer.STOP_SILENT"
        const val ACTION_TOGGLE = "com.manilmax.online_study_room.timer.TOGGLE"

        const val EXTRA_STARTED_AT_MS = "startedAtMs"
        const val EXTRA_MODE = "mode"

        const val BROADCAST_STATE_CHANGED = "com.manilmax.online_study_room.timer.STATE_CHANGED"

        private const val CHANNEL_ID = "study_timer_live_fg"
        private const val NOTIFICATION_ID = 7040

        // FlutterSharedPreferences anahtarları "flutter." önekiyle saklanır.
        private const val KEY_STARTED_AT = "flutter.timer_active_started_at"
        private const val KEY_STARTED_AT_MS = "flutter.timer_active_started_at_ms"
        private const val KEY_MODE = "flutter.timer_active_mode"
        private const val KEY_PHASE = "flutter.timer_active_phase"
        private const val KEY_CYCLE = "flutter.timer_active_cycle"
        private const val KEY_SUBJECT = "flutter.timer_active_subject"
        private const val KEY_FG_MODE = "flutter.timer_fg_mode"
        private const val KEY_PENDING_INTERVALS = "flutter.timer_pending_intervals"

        /** Servisi belirli bir komutla ayağa kaldırır (receiver/notification/Dart). */
        fun sendCommand(
            context: Context,
            action: String,
            startedAtMs: Long? = null,
            mode: String? = null,
        ) {
            val intent = Intent(context, StudyTimerService::class.java).apply {
                this.action = action
                startedAtMs?.let { putExtra(EXTRA_STARTED_AT_MS, it) }
                mode?.let { putExtra(EXTRA_MODE, it) }
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }
}
