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
import android.os.Bundle
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import com.manilmax.online_study_room.MainActivity
import com.manilmax.online_study_room.R
import com.manilmax.online_study_room.widgets.TimerWidgets

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
                    val liveRunId = intent.getStringExtra(EXTRA_LIVE_RUN_ID).orEmpty()
                    val liveRunToken = intent.getStringExtra(EXTRA_LIVE_RUN_TOKEN).orEmpty()
                    val startOrigin = intent.getStringExtra(EXTRA_START_ORIGIN)
                        ?: "native_notification"
                    handleStart(
                        startedAtMs, mode, phase, cycle, subjectId,
                        liveRunId, liveRunToken, startOrigin,
                    )
                }
                ACTION_STOP -> handleStop(recordInterval = true)
                ACTION_STOP_SILENT -> handleStop(recordInterval = false)
                ACTION_START_BREAK -> handleStartBreak()
                ACTION_END_BREAK -> handleEndBreak()
                ACTION_TOGGLE -> {
                    // WP-135: idle→start; running→stop + 00:00:00 (writeIdle).
                    if (TimerStateStore.isRunning(prefs())) {
                        handleStop(recordInterval = true)
                    } else {
                        handleStart(
                            startedAtMs = System.currentTimeMillis(),
                            mode = "stopwatch",
                            phase = "work",
                            cycle = 1,
                            subjectId = "",
                            startOrigin = "native_widget",
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
        liveRunId: String = "",
        liveRunToken: String = "",
        startOrigin: String = "dart_app",
    ) {
        // Eski Flutter bildirimi 7001; native panel tek otoritedir.
        notificationManager().cancel(LEGACY_FLUTTER_NOTIFICATION_ID)
        // WP-135: store yazımı senkron commit (beta-v15 idle race koruması).
        TimerStateStore.writeRunning(
            prefs(),
            startedAtMs = startedAtMs,
            mode = mode,
            phase = phase,
            cycle = cycle,
            subjectId = subjectId,
            liveRunId = liveRunId,
            liveRunToken = liveRunToken,
            startOrigin = startOrigin,
        )

        startForegroundCompat(buildRunningNotification(startedAtMs))
        notificationManager().notify(
            NOTIFICATION_ID,
            buildRunningNotification(startedAtMs),
        )
        // Deterministik sıra: store → UI yüzeyler → Dart broadcast.
        TimerWidgets.updateAll(this)
        notifyStateChanged()
    }

    /** Çalışan iş aralığını kapatır ve uygulama kapalıyken de gerçek mola fazına
     *  geçer. Mola süresi oturuma yazılmaz; Dart açıldığında `rest` fazını
     *  SharedPreferences'tan uzlaştırır. */
    private fun handleStartBreak() {
        val p = prefs()
        val currentStart = TimerStateStore.startedAtMs(p)
        if (currentStart <= 0L) return

        val nowMs = System.currentTimeMillis()
        val liveRunToken = p.getString(TimerStateStore.KEY_LIVE_RUN_TOKEN, "").orEmpty()
        val startOrigin = p.getString(
            TimerStateStore.KEY_START_ORIGIN,
            "native_notification",
        ).orEmpty()
        startForegroundCompat(buildRunningNotification(nowMs))

        if (liveRunToken.isNotBlank()) {
            TimerStateStore.appendPendingVerifiedCommand(
                p, "pause", liveRunToken, startOrigin,
            )
        } else if (p.getString(TimerStateStore.KEY_PHASE, "work") == "work" && currentStart < nowMs) {
            TimerStateStore.appendPendingInterval(
                p,
                startMs = currentStart,
                endMs = nowMs,
                subject = p.getString(TimerStateStore.KEY_SUBJECT, "") ?: "",
                origin = startOrigin,
            )
        }

        TimerStateStore.writeRunning(
            p,
            startedAtMs = nowMs,
            mode = p.getString(TimerStateStore.KEY_MODE, "stopwatch") ?: "stopwatch",
            phase = "rest",
            cycle = p.getInt(TimerStateStore.KEY_CYCLE, 1).coerceAtLeast(1),
            subjectId = p.getString(TimerStateStore.KEY_SUBJECT, "") ?: "",
            liveRunId = p.getString(TimerStateStore.KEY_LIVE_RUN_ID, "").orEmpty(),
            liveRunToken = liveRunToken,
            startOrigin = startOrigin,
        )

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
        if (p.getString(TimerStateStore.KEY_PHASE, "") != "rest") return
        val liveRunToken = p.getString(TimerStateStore.KEY_LIVE_RUN_TOKEN, "").orEmpty()
        val startOrigin = p.getString(
            TimerStateStore.KEY_START_ORIGIN,
            "native_notification",
        ).orEmpty()
        if (liveRunToken.isNotBlank()) {
            TimerStateStore.appendPendingVerifiedCommand(
                p, "resume", liveRunToken, startOrigin,
            )
        }
        handleStart(
            startedAtMs = System.currentTimeMillis(),
            mode = p.getString(TimerStateStore.KEY_MODE, "stopwatch") ?: "stopwatch",
            phase = "work",
            cycle = p.getInt(TimerStateStore.KEY_CYCLE, 1).coerceAtLeast(1),
            subjectId = p.getString(TimerStateStore.KEY_SUBJECT, "") ?: "",
            liveRunId = p.getString(TimerStateStore.KEY_LIVE_RUN_ID, "").orEmpty(),
            liveRunToken = liveRunToken,
            startOrigin = startOrigin,
        )
    }

    private fun handleStop(recordInterval: Boolean) {
        // ÖNEMLİ: 5 sn içinde startForeground (Android 12+ FGS borcu).
        startForegroundCompat(buildIdleNotification())

        val p = prefs()
        if (recordInterval) {
            val startedAtMs = TimerStateStore.startedAtMs(p)
            val phase = p.getString(TimerStateStore.KEY_PHASE, "work") ?: "work"
            val nowMs = System.currentTimeMillis()
            val liveRunToken = p.getString(TimerStateStore.KEY_LIVE_RUN_TOKEN, "").orEmpty()
            val startOrigin = p.getString(
                TimerStateStore.KEY_START_ORIGIN,
                "native_notification",
            ).orEmpty()
            // Yalnız çalışma fazı kaydedilir (mola sayılmaz).
            if (liveRunToken.isNotBlank()) {
                TimerStateStore.appendPendingVerifiedCommand(
                    p, "finalize", liveRunToken, startOrigin,
                )
            } else if (startedAtMs in 1 until nowMs && phase == "work") {
                TimerStateStore.appendPendingInterval(
                    p,
                    startMs = startedAtMs,
                    endMs = nowMs,
                    subject = p.getString(TimerStateStore.KEY_SUBJECT, "") ?: "",
                    origin = startOrigin,
                )
            }
        }

        // WP-135: idle + sıfır — senkron commit (apply asimetri kapatıldı).
        TimerStateStore.writeIdle(p)

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

    /**
     * v43 ürün kontratı: One UI'da tek satır HH:MM:SS ve doğrudan eylem.
     * `timer_panel_expanded` yalnız OEM/custom-layout sorunu için kaçış valfidir;
     * varsayılanı değiştirmez ve timer durum motoruna dokunmaz.
     */
    private fun buildRunningNotification(startedAtMs: Long): Notification {
        ensureChannel()
        val p = prefs()
        val isBreak = p.getString(TimerStateStore.KEY_PHASE, "work") == "rest"
        val builder = baseBuilder()
            .setOngoing(true)
            .setContentIntent(openAppPending())
            .setCategory(NotificationCompat.CATEGORY_STOPWATCH)
        val presentation = if (useV43CustomPanel()) {
            val custom = buildRunningRemoteViews(startedAtMs, isBreak)
            builder
                .setContentTitle("")
                .setContentText("")
                .setUsesChronometer(false)
                .setShowWhen(false)
                .setStyle(NotificationCompat.DecoratedCustomViewStyle())
                .setCustomContentView(custom)
                .setCustomBigContentView(custom)
            PRESENTATION_V43_CUSTOM
        } else {
            // v43 fallback: custom layout desteklenmeyen OEM'de sayaç ve eylem kaybolmaz.
            builder
                .setContentTitle(
                    if (isBreak) getString(R.string.timer_break_title)
                    else getString(R.string.timer_focusing_title),
                )
                .setContentText(
                    if (isBreak) getString(R.string.timer_break_body)
                    else getString(R.string.timer_focusing_body),
                )
                .setUsesChronometer(true)
                .setWhen(startedAtMs)
                .setShowWhen(true)
                .setChronometerCountDown(false)
                .addAction(
                    0,
                    if (isBreak) getString(R.string.action_return_to_work)
                    else getString(R.string.action_stop),
                    if (isBreak) endBreakActionPending() else stopActionPending(),
                )
            PRESENTATION_STANDARD_FALLBACK
        }
        return addPresentationDiagnostic(builder, presentation).build()
    }

    private fun buildIdleNotification(): Notification {
        ensureChannel()
        val builder = baseBuilder()
            .setOngoing(false)
            .setContentIntent(openAppPending())
            .setCategory(NotificationCompat.CATEGORY_STOPWATCH)
        val presentation = if (useV43CustomPanel()) {
            val custom = buildIdleRemoteViews()
            builder
                .setUsesChronometer(false)
                .setShowWhen(false)
                .setContentTitle("")
                .setContentText("")
                .setStyle(NotificationCompat.DecoratedCustomViewStyle())
                .setCustomContentView(custom)
                .setCustomBigContentView(custom)
            PRESENTATION_V43_CUSTOM
        } else {
            builder
                .setUsesChronometer(false)
                .setShowWhen(false)
                .setContentTitle("00:00:00")
                .setContentText(getString(R.string.timer_ready))
                .addAction(0, getString(R.string.action_start), startActionPending())
            PRESENTATION_STANDARD_FALLBACK
        }
        return addPresentationDiagnostic(builder, presentation).build()
    }

    /** v43'teki kaçış valfi: true ana ürün paneli, false işlevsel standart bildirim. */
    private fun useV43CustomPanel(): Boolean =
        prefs().getBoolean(KEY_PANEL_EXPANDED, true)

    /**
     * Now Bar/promoted ongoing, custom panel ile aynı bildirimde etkinleştirilmez.
     * Bu ekstra yalnız tanı içindir: OEM sonucu bir ürün vaadi veya stable davranış
     * değişikliği değildir. Ayrı bir deney bu değeri okuyabilir; burada promoted API
     * çağrısı yapılmaz.
     */
    private fun addPresentationDiagnostic(
        builder: NotificationCompat.Builder,
        presentation: String,
    ): NotificationCompat.Builder = builder.addExtras(
        Bundle().apply {
            putString(EXTRA_TIMER_PRESENTATION, presentation)
            putString(EXTRA_PROMOTED_NOW_BAR, PROMOTED_NOW_BAR_NOT_REQUESTED)
        },
    )

    private fun buildRunningRemoteViews(startedAtMs: Long, isBreak: Boolean): RemoteViews {
        val views = RemoteViews(packageName, R.layout.timer_notification)
        val base = SystemClock.elapsedRealtime() - (System.currentTimeMillis() - startedAtMs)
        views.setChronometer(
            R.id.notif_timer_elapsed,
            base,
            null,
            true,
        )
        views.setTextViewText(
            R.id.notif_timer_action,
            if (isBreak) getString(R.string.action_return_to_work)
            else getString(R.string.action_stop),
        )
        views.setOnClickPendingIntent(
            R.id.notif_timer_action,
            if (isBreak) endBreakActionPending() else stopActionPending(),
        )
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
        val intent = Intent(this, StudyTimerService::class.java).apply {
            this.action = action
            if (action == ACTION_START) putExtra(EXTRA_START_ORIGIN, "native_notification")
        }
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

    private fun prefs(): SharedPreferences = TimerStateStore.prefs(this)

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
        const val EXTRA_LIVE_RUN_ID = "liveRunId"
        const val EXTRA_LIVE_RUN_TOKEN = "liveRunToken"
        const val EXTRA_START_ORIGIN = "startOrigin"

        const val BROADCAST_STATE_CHANGED = "com.manilmax.online_study_room.timer.STATE_CHANGED"

        private const val CHANNEL_ID = "study_timer_live_fg"
        private const val NOTIFICATION_ID = 7040
        private const val LEGACY_FLUTTER_NOTIFICATION_ID = 7001
        /** v43 custom panel varsayılandır; false yalnız cihaz sorununda fallback'tir. */
        private const val KEY_PANEL_EXPANDED = "flutter.timer_panel_expanded"
        private const val EXTRA_TIMER_PRESENTATION = "timer.presentation"
        private const val EXTRA_PROMOTED_NOW_BAR = "timer.promoted_now_bar"
        private const val PRESENTATION_V43_CUSTOM = "v43_custom_panel"
        private const val PRESENTATION_STANDARD_FALLBACK = "standard_fallback"
        private const val PROMOTED_NOW_BAR_NOT_REQUESTED = "not_requested"
        /** Servisi belirli bir komutla ayağa kaldırır (receiver/notification/Dart). */
        fun sendCommand(
            context: Context,
            action: String,
            startedAtMs: Long? = null,
            mode: String? = null,
            phase: String? = null,
            cycle: Int? = null,
            subjectId: String? = null,
            liveRunId: String? = null,
            liveRunToken: String? = null,
            startOrigin: String? = null,
        ) {
            val intent = Intent(context, StudyTimerService::class.java).apply {
                this.action = action
                startedAtMs?.let { putExtra(EXTRA_STARTED_AT_MS, it) }
                mode?.let { putExtra(EXTRA_MODE, it) }
                phase?.let { putExtra(EXTRA_PHASE, it) }
                cycle?.let { putExtra(EXTRA_CYCLE, it) }
                subjectId?.let { putExtra(EXTRA_SUBJECT_ID, it) }
                liveRunId?.let { putExtra(EXTRA_LIVE_RUN_ID, it) }
                liveRunToken?.let { putExtra(EXTRA_LIVE_RUN_TOKEN, it) }
                startOrigin?.let { putExtra(EXTRA_START_ORIGIN, it) }
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }
}
