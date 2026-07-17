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
import android.os.SystemClock
import android.widget.RemoteViews
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
 * Yaşam döngüsü / çökme güvenliği (beta-v13):
 * - `START_NOT_STICKY`: Süreç öldürülürse Android servisi **null intent ile
 *   yeniden başlatmasın**. START_STICKY yeniden başlatması `startForeground`
 *   çağrılmadan gelir ve Android 12+'da `ForegroundServiceDidNotStartInTimeException`
 *   ile açılışta çökme döngüsü yaratıyordu. Durum zaten prefs'te; otomatik
 *   yeniden başlatmaya gerek yok.
 * - Her komut yolu (Başlat **ve** Durdur) 5 sn içinde `startForeground` çağırır;
 *   arka plandan getForegroundService ile ayağa kalkan servis kuralı bozmaz.
 * - Bildirim aksiyonları `getForegroundService` kullanır; uygulama kapalıyken
 *   arka plan servis başlatma yasağına (`BackgroundServiceStartNotAllowed`) takılmaz.
 */
class StudyTimerService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Hiçbir komut yolu uygulamayı çökertmesin: FGS bildirimleri/OEM kısıtları
        // beklenmedik istisna atabilir; servis sessizce toparlanmalı.
        try {
            when (intent?.action) {
                ACTION_START -> {
                    val startedAtMs =
                        intent.getLongExtra(EXTRA_STARTED_AT_MS, System.currentTimeMillis())
                    val mode = intent.getStringExtra(EXTRA_MODE) ?: "stopwatch"
                    val phase = intent.getStringExtra(EXTRA_PHASE) ?: "work"
                    val cycle = intent.getIntExtra(EXTRA_CYCLE, 1).coerceAtLeast(1)
                    val subjectId = intent.getStringExtra(EXTRA_SUBJECT_ID).orEmpty()
                    handleStart(startedAtMs, mode, phase, cycle, subjectId)
                }
                ACTION_STOP -> handleStop(recordInterval = true)
                ACTION_STOP_SILENT -> handleStop(recordInterval = false)
                ACTION_START_BREAK -> handleStartBreak()
                ACTION_END_BREAK -> handleEndBreak()
                ACTION_TOGGLE -> {
                    if (prefs().contains(KEY_STARTED_AT)) {
                        handleStop(recordInterval = true)
                    } else {
                        handleStart(
                            startedAtMs = System.currentTimeMillis(),
                            mode = "stopwatch",
                            phase = "work",
                            cycle = 1,
                            subjectId = "",
                        )
                    }
                }
                else -> {
                    // START_NOT_STICKY ile normalde null-intent yeniden başlatma
                    // gelmez; yine de gelirse güvenle kendini kapat. FGS bekleyen
                    // bir başlatma varsa 5 sn kuralını bozmamak için önce kısa bir
                    // foreground'a geç, sonra bırak.
                    safeStopEverything()
                }
            }
        } catch (t: Throwable) {
            // Çökme yerine sessiz toparlanma: FGS'i düşür, servisi kapat.
            runCatching { safeStopEverything() }
        }
        return START_NOT_STICKY
    }

    private fun handleStart(
        startedAtMs: Long,
        mode: String,
        phase: String,
        cycle: Int,
        subjectId: String,
    ) {
        // Eski Flutter bildirimi 7001, uygulama kapalıyken yalnız Preferences'a
        // komut yazıyordu. Native panel tek otoritedir; eski eylemi temizle.
        notificationManager().cancel(LEGACY_FLUTTER_NOTIFICATION_ID)
        val editor = prefs().edit()
        editor.putString(KEY_STARTED_AT, Instant.ofEpochMilli(startedAtMs).toString())
        editor.putLong(KEY_STARTED_AT_MS, startedAtMs)
        editor.putString(KEY_MODE, mode)
        editor.putString(KEY_PHASE, phase)
        editor.putInt(KEY_CYCLE, cycle)
        editor.putString(KEY_SUBJECT, subjectId)
        editor.putString(KEY_FG_MODE, "running")
        // commit: broadcast/reconcile apply() gecikmesi yüzünden hâlâ "idle"
        // okuyup uygulamadan başlatmayı geri almasın (beta-v15 in-app start bug).
        editor.commit()

        startForegroundCompat(buildRunningNotification(startedAtMs))
        // DETACH sonrası idle bildirim kalmış olabilir; running'i ayrıca da bas.
        notificationManager().notify(
            NOTIFICATION_ID,
            buildRunningNotification(startedAtMs),
        )
        TimerWidgets.updateAll(this)
        notifyStateChanged()
    }

    /** Çalışan iş aralığını kapatır ve uygulama kapalıyken de gerçek mola fazına
     *  geçer. Mola süresi oturuma yazılmaz; Dart açıldığında `rest` fazını
     *  SharedPreferences'tan uzlaştırır. */
    private fun handleStartBreak() {
        val p = prefs()
        val currentStart = p.getLong(KEY_STARTED_AT_MS, 0L)
        if (currentStart <= 0L) return

        // getForegroundService ile uyanmış olabileceğimiz için bookkeeping'ten
        // önce 5 sn içinde foreground olma sözleşmesini yerine getir.
        val nowMs = System.currentTimeMillis()
        startForegroundCompat(buildRunningNotification(nowMs))

        if (p.getString(KEY_PHASE, "work") == "work" && currentStart < nowMs) {
            appendPendingInterval(
                p,
                startMs = currentStart,
                endMs = nowMs,
                subject = p.getString(KEY_SUBJECT, "") ?: "",
            )
        }

        p.edit()
            .putString(KEY_STARTED_AT, Instant.ofEpochMilli(nowMs).toString())
            .putLong(KEY_STARTED_AT_MS, nowMs)
            .putString(KEY_PHASE, "rest")
            .putString(KEY_FG_MODE, "running")
            .commit()

        notificationManager().notify(
            NOTIFICATION_ID,
            buildRunningNotification(nowMs),
        )
        TimerWidgets.updateAll(this)
        notifyStateChanged()
    }

    /** Molayı bitirip mevcut timer modu/döngüsüyle yeni bir çalışma epoch'u
     *  başlatır. Mola aralığı oturum değildir; bu nedenle kuyruk yazılmaz. */
    private fun handleEndBreak() {
        val p = prefs()
        if (p.getString(KEY_PHASE, "") != "rest") return
        handleStart(
            startedAtMs = System.currentTimeMillis(),
            mode = p.getString(KEY_MODE, "stopwatch") ?: "stopwatch",
            phase = "work",
            cycle = p.getInt(KEY_CYCLE, 1).coerceAtLeast(1),
            subjectId = p.getString(KEY_SUBJECT, "") ?: "",
        )
    }

    private fun handleStop(recordInterval: Boolean) {
        // ÖNEMLİ: Servis arka plandan `startForegroundService` ile ayağa kalkmış
        // olabilir (bildirim/widget Durdur). Android 12+ kuralı: 5 sn içinde
        // `startForeground` çağrılmalı. Bu yüzden bookkeeping'ten ÖNCE idle
        // bildirimini foreground olarak yayınla, sonra foreground'u bırak
        // (DETACH — bildirim kalsın ki app açmadan tekrar Başlat'a basılabilsin).
        startForegroundCompat(buildIdleNotification())

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

        // Foreground durumunu bırak ama idle bildirimi (00:00:00 + Başlat) —
        // kaydırılıp atılabilir — kalsın ki app açmadan tekrar başlatılabilsin.
        detachForegroundKeepNotification()
        TimerWidgets.updateAll(this)
        notifyStateChanged()
        stopSelf()
    }

    /** Beklenmedik/boş komutta güvenli kapanış: kısa foreground + tam kaldırma. */
    private fun safeStopEverything() {
        // Foreground borcu olabilir; kısa bir bildirimle kapat ve tamamen kaldır.
        runCatching { startForegroundCompat(buildIdleNotification()) }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            runCatching { stopForeground(Service.STOP_FOREGROUND_REMOVE) }
        } else {
            @Suppress("DEPRECATION")
            runCatching { stopForeground(true) }
        }
        runCatching { notificationManager().cancel(NOTIFICATION_ID) }
        stopSelf()
    }

    private fun detachForegroundKeepNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            // DETACH: bildirimi bırakma, yalnız foreground bağını kopar.
            runCatching { stopForeground(Service.STOP_FOREGROUND_DETACH) }
        } else {
            @Suppress("DEPRECATION")
            runCatching { stopForeground(false) }
        }
    }

    /**
     * WP-103: Runtime tip, manifest `dataSync|specialUse` alt kümesi olmalı.
     * - API 34+ (UPSIDE_DOWN_CAKE): SPECIAL_USE (Android 15 dataSync 6s cap'ten muaf)
     * - API 29–33: DATA_SYNC (önceki yalnız-specialUse manifest ile uyumsuzdu → çökme)
     * - API ≤28: tip parametresiz
     */
    private fun startForegroundCompat(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // dataSync Android 15'te toplam 6 saat ile sınırlı. Kullanıcı açıkça
            // başlatmış görünür sayaç, manifestte beyan edilen specialUse türüyle
            // çalışır; bu tür için runtime önkoşulu yoktur.
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
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
        val builder = baseBuilder()
            .setOngoing(true)
            .setContentIntent(openAppPending())
            // One UI already supplies the app/channel header. Keep the foreground
            // surface to the chronometer and its Stop action.
            .setContentTitle("")
            .setContentText("")
        // One UI'nin standard görünümü ilk saatte MM:SS üretip aksiyonu alt
        // satıra ayırır. Ürün tercihi bu OEM terfisinden önce tek satırlık,
        // her zaman HH:MM:SS olan kontrol yüzeyidir.
        val custom = buildRunningRemoteViews(startedAtMs)
        builder.setUsesChronometer(false)
            .setShowWhen(false)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setCustomContentView(custom)
            .setCustomBigContentView(custom)
        return builder.build()
    }

    private fun buildIdleNotification(): Notification {
        ensureChannel()
        val builder = baseBuilder()
            .setOngoing(false)
            .setContentIntent(openAppPending())
            .setUsesChronometer(false)
            .setShowWhen(false)
            .setContentTitle("00:00:00")
            .setContentText("")
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setCustomContentView(buildIdleRemoteViews())
            .setCustomBigContentView(buildIdleRemoteViews())
        return builder.build()
    }

    /** Dil paketi öncesinde kullanılan kanıtlı One UI satırı: solda akan sayaç,
     *  sağda doğrudan foreground servise giden tek eylem. */
    private fun buildRunningRemoteViews(startedAtMs: Long): RemoteViews {
        val views = RemoteViews(packageName, R.layout.timer_notification)
        val base = SystemClock.elapsedRealtime() - (System.currentTimeMillis() - startedAtMs)
        views.setChronometer(R.id.notif_timer_elapsed, base, null, true)
        views.setTextViewText(R.id.notif_timer_action, getString(R.string.action_stop))
        views.setOnClickPendingIntent(R.id.notif_timer_action, stopActionPending())
        return views
    }

    private fun buildIdleRemoteViews(): RemoteViews {
        val views = RemoteViews(packageName, R.layout.timer_notification)
        views.setChronometer(
            R.id.notif_timer_elapsed,
            SystemClock.elapsedRealtime(),
            "00:00:00",
            false,
        )
        views.setTextViewText(R.id.notif_timer_elapsed, "00:00:00")
        views.setTextViewText(R.id.notif_timer_action, getString(R.string.action_start))
        views.setOnClickPendingIntent(R.id.notif_timer_action, startActionPending())
        return views
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

    private fun stopActionPending(): PendingIntent = actionPending(ACTION_STOP, 1)

    private fun startActionPending(): PendingIntent = actionPending(ACTION_START, 2)

    private fun breakActionPending(): PendingIntent = actionPending(ACTION_START_BREAK, 3)

    private fun endBreakActionPending(): PendingIntent = actionPending(ACTION_END_BREAK, 4)

    /** Bildirim aksiyonu: uygulama kapalıyken de FGS başlatabilmek için
     *  `getForegroundService` (API 26+) — düz `getService` arka plan yasağına
     *  takılıp çökertiyordu. */
    private fun actionPending(action: String, requestCode: Int): PendingIntent {
        val intent = Intent(this, StudyTimerService::class.java).apply { this.action = action }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            PendingIntent.getForegroundService(this, requestCode, intent, flags)
        } else {
            PendingIntent.getService(this, requestCode, intent, flags)
        }
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
            getString(R.string.timer_channel_name),
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = getString(R.string.timer_channel_desc)
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
        const val ACTION_START_BREAK = "com.manilmax.online_study_room.timer.START_BREAK"
        const val ACTION_END_BREAK = "com.manilmax.online_study_room.timer.END_BREAK"

        const val EXTRA_STARTED_AT_MS = "startedAtMs"
        const val EXTRA_MODE = "mode"
        const val EXTRA_PHASE = "phase"
        const val EXTRA_CYCLE = "cycle"
        const val EXTRA_SUBJECT_ID = "subjectId"

        const val BROADCAST_STATE_CHANGED = "com.manilmax.online_study_room.timer.STATE_CHANGED"

        private const val CHANNEL_ID = "study_timer_live_fg"
        private const val NOTIFICATION_ID = 7040
        private const val LEGACY_FLUTTER_NOTIFICATION_ID = 7001

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
            phase: String? = null,
            cycle: Int? = null,
            subjectId: String? = null,
        ) {
            val intent = Intent(context, StudyTimerService::class.java).apply {
                this.action = action
                startedAtMs?.let { putExtra(EXTRA_STARTED_AT_MS, it) }
                mode?.let { putExtra(EXTRA_MODE, it) }
                phase?.let { putExtra(EXTRA_PHASE, it) }
                cycle?.let { putExtra(EXTRA_CYCLE, it) }
                subjectId?.let { putExtra(EXTRA_SUBJECT_ID, it) }
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }
}
