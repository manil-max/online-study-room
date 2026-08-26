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
import com.manilmax.online_study_room.widgets.rememberedSubjectId

internal const val IDLE_NOTIFICATION_TIMER_TEXT = "00:00"

/**
 * WP-753: Zengin özel panelin prefs anahtarı.
 *
 * 🔴 v71 SAHA GERI BILDIRIMI (2026-08-26) ILE VARSAYILAN `true`'YA DONDU.
 *
 * WP-753 varsayilani `false` (Live Update) yapmisti ve o karar CIHAZDA HIC
 * DOGRULANMADAN yayina cikti. Sahibin Galaxy S23'unde sonuc: bildirimde sayac
 * `00:00` gorunuyor ve Start/Stop dugmesi hic cizilmiyor -- yani uygulamanin
 * cekirdek islevi bildirimden kullanilamaz hale geldi.
 *
 * Iki ayri kusur birlestiler:
 *  - Bosta duran bildirimin basligi sabit `IDLE_NOTIFICATION_TIMER_TEXT`
 *    ("00:00") -- kullanici bunu "sayac sifirlanmis" diye okuyor.
 *  - Eylem `addAction(0, ...)` ile, yani IKONSUZ ekleniyor. Eski panelde dugme
 *    cizilen gorunumun icinde bir metin kutusuydu ve her zaman gorunurdu;
 *    standart bildirim eyleminde ikonsuz eylem modern Android'de cizilmeyebilir.
 *
 * Bu yuzden varsayilan, sahibin v43'te KABUL ETTIGI zengin panele geri alindi.
 * Live Update yolu silinmedi: `timer_panel_expanded=false` yazilirsa kosar.
 * Once gercek cihazda dogrulanacak, sonra varsayilan olmayi tekrar hak edecek.
 */
internal const val KEY_PANEL_EXPANDED = "flutter.timer_panel_expanded"

/** Valf: `false` YAZILMISSA Live Update, aksi halde (varsayilan) v43 zengin panel. */
internal fun useV43CustomPanel(prefs: SharedPreferences): Boolean =
    prefs.getBoolean(KEY_PANEL_EXPANDED, true)

/**
 * WP-753: durum çubuğu / Live Update çipi ikonu.
 *
 * Monokrom vektör olmak **zorunda**; renkli adaptif launcher ikonu
 * (`R.mipmap.ic_launcher`) yanlış türdür. Sabit olarak durur ki cihazsız JVM
 * testi türü ölçebilsin — `baseBuilder()` bir `Context` istediği için o yol
 * cihazsız ölçülemez.
 */
internal val TIMER_NOTIFICATION_SMALL_ICON: Int = R.drawable.ic_stat_focus_timer

/** Koşan sayaç bildiriminin sunum yolu. */
internal enum class TimerNotificationStyle {
    /**
     * v43 zengin özel panel. `RemoteViews` taşır, bu yüzden Android **terfi
     * ettiremez**: *"Must NOT have any customContentView set (no RemoteViews)"*.
     * Geri dönüş valfi olarak durur, terfi istemez.
     */
    CUSTOM_PANEL,

    /** Açık uçlu kronometre (stopwatch): standart stil, terfi edilebilir. */
    STANDARD,

    /** Hedefi olan mod (pomodoro/geri sayım): `ProgressStyle`, terfi edilebilir. */
    PROGRESS,
}

/**
 * Koşan bildirimin **saf** sunum kararı — cihazsız JVM'de ölçülebilsin diye
 * `Context`/`Notification` dokunmadan hesaplanır (WP-622'deki `endBreakPlan`
 * deseni). Bu kararın nöbetçisi `TimerLiveUpdateWp753Test`tir.
 */
internal data class TimerNotificationPlan(
    val style: TimerNotificationStyle,
    /** 0 = başlık yok (yalnız özel panel yolunda). */
    val titleRes: Int,
    val bodyRes: Int,
    /** 0 = kısa kritik metin yazılmaz; çip metnini `when` kronometresi taşır. */
    val shortCriticalTextRes: Int,
    val whenMs: Long,
    val countDown: Boolean,
    val progressSeconds: Int,
    val totalSeconds: Int,
) {
    val usesCustomView: Boolean get() = style == TimerNotificationStyle.CUSTOM_PANEL

    /**
     * Terfi yalnız özel görünüm **taşımayan** yolda istenir. Altı denemenin
     * kök nedeni tam olarak buydu: zengin panel ile Live Update birbirini
     * dışlar, ikisi aynı bildirimde tutulamaz.
     */
    val requestPromotedOngoing: Boolean get() = !usesCustomView
}

/**
 * WP-753: sunum yolunu seçer.
 *
 * Çip metni kararı resmî belgeden çıkar
 * (<https://developer.android.com/develop/ui/views/notifications/live-update>):
 * *"The when time is in the past: The text isn't shown"* ve *"The Chronometer
 * timer is shown in the chip as long as it is positive"*.
 * - **Açık uçlu kronometre**: `when` başlangıç anıdır, yani GEÇMİŞTE kalır →
 *   çip süreyi çizemez; kısa kritik metin (Odak/Mola) şart.
 * - **Hedefli mod**: `when` bitiş anıdır, yani GELECEKTEDİR → çipte canlı geri
 *   sayım akar; sabit kısa metin o canlı sayıyı gölgelemesin diye yazılmaz.
 */
internal fun runningTimerNotificationPlan(
    richPanel: Boolean,
    isBreak: Boolean,
    targetSeconds: Int?,
    startedAtMs: Long,
    nowMs: Long,
): TimerNotificationPlan {
    if (richPanel) {
        return TimerNotificationPlan(
            style = TimerNotificationStyle.CUSTOM_PANEL,
            titleRes = 0,
            bodyRes = 0,
            shortCriticalTextRes = 0,
            whenMs = startedAtMs,
            countDown = false,
            progressSeconds = 0,
            totalSeconds = 0,
        )
    }
    val titleRes = if (isBreak) R.string.timer_break_title else R.string.timer_focusing_title
    val bodyRes = if (isBreak) R.string.timer_break_body else R.string.timer_focusing_body
    val total = targetSeconds?.takeIf { it > 0 }
        ?: return TimerNotificationPlan(
            style = TimerNotificationStyle.STANDARD,
            titleRes = titleRes,
            bodyRes = bodyRes,
            shortCriticalTextRes = if (isBreak) {
                R.string.timer_subtext_break
            } else {
                R.string.timer_subtext_focus
            },
            whenMs = startedAtMs,
            countDown = false,
            progressSeconds = 0,
            totalSeconds = 0,
        )
    return TimerNotificationPlan(
        style = TimerNotificationStyle.PROGRESS,
        titleRes = titleRes,
        bodyRes = bodyRes,
        shortCriticalTextRes = 0,
        whenMs = startedAtMs + total * 1000L,
        countDown = true,
        progressSeconds = ((nowMs - startedAtMs) / 1000L)
            .coerceIn(0L, total.toLong())
            .toInt(),
        totalSeconds = total,
    )
}

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
                    // 🔴 WP-645: EXTRA_MODE yoksa "stopwatch" DEGIL, kullanicinin
                    // sectigi mod. Bildirimin Baslat PendingIntent'i (actionPending)
                    // moda hic deginmiyor; eski `?: "stopwatch"` o yolu sessizce
                    // kronometreye ceviriyordu.
                    val startPlan = TimerStateStore.nativeStartPlan(prefs())
                    val mode = intent.getStringExtra(EXTRA_MODE) ?: startPlan.mode
                    val phase = intent.getStringExtra(EXTRA_PHASE) ?: "work"
                    val cycle = intent.getIntExtra(EXTRA_CYCLE, 1).coerceAtLeast(1)
                    // Intent hedefi tasimiyorsa (bildirimin Baslat'i tasimaz) ve
                    // baslatilan mod kullanicinin sectigi modsa, hedef plandan gelir.
                    val targetSeconds = intent.getIntExtra(EXTRA_TARGET_SECONDS, 0)
                        .takeIf { it > 0 }
                        ?: startPlan.targetSeconds.takeIf { mode == startPlan.mode }
                    // Bildirimdeki Başlat intent'i ders extra'sı taşımaz. Boş
                    // yazmak son seçimi her seferinde Genel'e düşürüyordu;
                    // widget ile aynı hesap-kapsamlı kalıcı tercih kullanılır.
                    val subjectId = if (intent.hasExtra(EXTRA_SUBJECT_ID)) {
                        intent.getStringExtra(EXTRA_SUBJECT_ID).orEmpty()
                    } else {
                        rememberedSubjectId(prefs())
                    }
                    val liveRunId = intent.getStringExtra(EXTRA_LIVE_RUN_ID).orEmpty()
                    val liveRunToken = intent.getStringExtra(EXTRA_LIVE_RUN_TOKEN).orEmpty()
                    val startOrigin = intent.getStringExtra(EXTRA_START_ORIGIN)
                        ?: "native_notification"
                    handleStart(
                        startedAtMs, mode, phase, cycle, targetSeconds, subjectId,
                        liveRunId, liveRunToken, startOrigin,
                    )
                }
                ACTION_STOP -> handleStop(
                    recordInterval = true,
                    commandOrigin = "native_notification",
                )
                ACTION_STOP_SILENT -> handleStop(
                    recordInterval = false,
                    commandOrigin = "dart_app",
                )
                ACTION_DISCARD_PROJECTION -> handleDiscardProjection()
                ACTION_END_BREAK -> handleEndBreak()
                ACTION_TOGGLE -> {
                    // WP-135: idle→start; running→stop + 00:00 (writeIdle).
                    if (TimerStateStore.isRunning(prefs())) {
                        handleStop(
                            recordInterval = true,
                            commandOrigin = "native_widget",
                        )
                    } else {
                        // 🔴 WP-645: burasi `mode = "stopwatch"` SABIT yaziyordu.
                        // Pomodoro/geri sayim secmis kullanicinin widget Baslat'i
                        // acik uclu bir kronometre baslatiyor, sonra Dart bu modu
                        // benimseyip kullanicinin SECIMINI diske de yaziyordu.
                        val plan = TimerStateStore.nativeStartPlan(prefs())
                        handleStart(
                            startedAtMs = System.currentTimeMillis(),
                            mode = plan.mode,
                            phase = "work",
                            cycle = 1,
                            targetSeconds = plan.targetSeconds,
                            subjectId = rememberedSubjectId(prefs()),
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
        // WP-645: varsayilani KALDIRILDI. `= null`, hedefi gecirmeyi unutan
        // her cagirani sessizce hedefsiz kosuya dusuruyordu; bu soruyu
        // derleyici sormali, kullanici degil.
        targetSeconds: Int?,
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
            targetSeconds = targetSeconds,
            subjectId = subjectId,
            liveRunId = liveRunId,
            liveRunToken = liveRunToken,
            startOrigin = startOrigin,
            // WP-431: rol store'da acik tutulur; handleStop kararini buradan verir.
            controllerRole = TimerStateStore.roleForStartOrigin(startOrigin),
        )
        // V1 global coordination yalnız stopwatch work start/stop'u kapsar.
        // Countdown/Pomodoro için global phase komutu üretmeyiz; mevcut local
        // davranış ve legacy verified queue değişmeden kalır.
        // WP-343 remote mirror, doğrulanmış sunucu snapshot'ını yalnız yerel
        // yüzeylere uygular. Onu yeni bir native producer gibi kuyruğa yazmak
        // echo/tekrar start üretirdi; normal local start yolları değişmez.
        if (mode == "stopwatch" && phase == "work" && startOrigin != "global_timer_mirror") {
            TimerStateStore.appendV2Command(prefs(), "start", startOrigin)
        }

        startForegroundCompat(buildRunningNotification(startedAtMs))
        notificationManager().notify(
            NOTIFICATION_ID,
            buildRunningNotification(startedAtMs),
        )
        // Deterministik sıra: store → UI yüzeyler → Dart broadcast.
        TimerWidgets.updateAll(this)
        notifyStateChanged()
    }

    /**
     * Molayı bitirip pomodoro'nun **BİR SONRAKİ** çalışma döngüsünü başlatır
     * (bildirimdeki "Çalışmaya dön" düğmesi). Mola aralığı oturum değildir; bu
     * nedenle kuyruk yazılmaz.
     *
     * WP-622: hangi döngüyle/hedefle başlanacağı kararı burada DEĞİL,
     * [TimerStateStore.endBreakPlan] içinde saf olarak verilir — cihazsız JVM
     * testiyle ölçülebilsin diye. Eskiden karar burada gömülüydü ve döngüyü
     * aynen yeniden yazıyordu.
     */
    private fun handleEndBreak() {
        val p = prefs()
        val plan = TimerStateStore.endBreakPlan(p) ?: return
        val liveRunToken = plan.liveRunToken
        val startOrigin = plan.startOrigin
        if (liveRunToken.isNotBlank()) {
            TimerStateStore.appendPendingVerifiedCommand(
                p, "resume", liveRunToken, startOrigin,
            )
        }
        handleStart(
            startedAtMs = System.currentTimeMillis(),
            mode = plan.mode,
            phase = "work",
            cycle = plan.cycle,
            targetSeconds = plan.targetSeconds,
            subjectId = plan.subjectId,
            liveRunId = plan.liveRunId,
            liveRunToken = liveRunToken,
            startOrigin = startOrigin,
        )
    }

    private fun handleStop(
        recordInterval: Boolean,
        commandOrigin: String = "native_notification",
    ) {
        // ÖNEMLİ: 5 sn içinde startForeground (Android 12+ FGS borcu).
        startForegroundCompat(buildIdleNotification())

        val p = prefs()
        val phase = p.getString(TimerStateStore.KEY_PHASE, "work") ?: "work"
        val mode = p.getString(TimerStateStore.KEY_MODE, "stopwatch") ?: "stopwatch"
        val startOrigin = p.getString(
            TimerStateStore.KEY_START_ORIGIN,
            "native_notification",
        ).orEmpty()

        // WP-431 (V56-S01, ikinci yuz): AYNA cihaz projeksiyondur — asla yerel
        // oturum uretmez. Eskiden bildirim/widget Durdur'u `recordInterval=true`
        // ile geliyordu ve ayna cihazda UYDURMA bir calisma araligi yaziliyordu;
        // Dart onu acilista gercek oturum olarak kaydediyordu.
        val isMirror = TimerStateStore.isMirror(p)

        if (recordInterval && !isMirror) {
            val startedAtMs = TimerStateStore.startedAtMs(p)
            val nowMs = System.currentTimeMillis()
            val liveRunToken = p.getString(TimerStateStore.KEY_LIVE_RUN_TOKEN, "").orEmpty()
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

        // WP-373 (KÖK NEDEN 2): V2 senkron zarfı oturum muhasebesinden BAĞIMSIZDIR.
        //
        // 🔴 Eskiden bu blok `recordInterval` koşulunun İÇİNDEYDİ. Uygulama içi
        // Durdur `ACTION_STOP_SILENT` → `handleStop(recordInterval = false)`
        // yolunu kullanır (oturumu Dart yazar, çift kayıt olmasın diye), yani
        // **en sık kullanılan durdurma** hiçbir zaman durdurma sinyali
        // üretmiyordu; diğer cihazda aynalanan sayaç koşmaya devam ediyordu.
        //
        // `recordInterval` "oturumu kim yazacak" sorusunun cevabıdır; "kullanıcı
        // sayacı durdurdu mu" sorusunun değil. İkisi ayrıldı.
        //
        // Ayna cihazında zarf üretilmez: `startOrigin == "global_timer_mirror"`
        // için `canonicalV2Origin` null döner (koşunun sahibi karşı cihazdır).
        // WP-431: AYNA cihazda yerel mod/faz onemsizdir — koşu tanimi geregi
        // global bir stopwatch kosusudur. Eski `mode == "stopwatch"` kosulu,
        // yerel modu countdown olan bir ayna cihazda durdurma komutunu sessizce
        // dusuruyordu (V56-S01'in ucuncu yuzu).
        if (isMirror || (mode == "stopwatch" && phase == "work")) {
            TimerStateStore.appendV2Command(
                p,
                action = "stop",
                startOrigin = commandOrigin,
                runId = p.getString(TimerStateStore.KEY_V2_RUN_ID, null),
                expectedRunRevision = p.getString(TimerStateStore.KEY_V2_RUN_REVISION, null)
                    ?.toLongOrNull(),
            )
        }

        // WP-135: idle + sıfır — senkron commit (apply asimetri kapatıldı).
        TimerStateStore.writeIdle(p)

        detachForegroundKeepNotification()
        TimerWidgets.updateAll(this)
        notifyStateChanged()
        stopSelf()
    }

    /**
     * WP-431: yalnız YEREL projeksiyonu düşürür — sunucuya hiçbir sey gitmez.
     *
     * Sogumus acilista ayna durumu server dogrulanmadan diriltilmemelidir
     * (V56-S04: sabah gorunen sekiz saatlik hayalet). Ama bu bir DURDURMA
     * degildir: kosunun sahibi baska cihazdir ve orada calismaya devam
     * ediyor olabilir. Bu yuzden `handleStop`tan farkli olarak ne V2 stop
     * zarfi ne de bekleyen aralik yazilir.
     */
    private fun handleDiscardProjection() {
        startForegroundCompat(buildIdleNotification())
        TimerStateStore.writeIdle(prefs())
        detachForegroundKeepNotification()
        notificationManager().cancel(NOTIFICATION_ID)
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
     * WP-753: varsayılan yol artık **Android Live Update sözleşmesi**dir —
     * özel görünüm yok, dolu `contentTitle`, standart/`ProgressStyle` stil,
     * `setRequestPromotedOngoing(true)`. Terfi eden bildirim durum çubuğunda
     * çip, kilit ekranında ve (Samsung'da) Now Bar'da çizilir.
     *
     * v43 zengin özel panel yalnız `timer_panel_expanded=true` yazılmışsa
     * koşar ve terfi **istemez** (özel görünüm ile terfi birbirini dışlar).
     */
    private fun buildRunningNotification(startedAtMs: Long): Notification {
        ensureChannel()
        val p = prefs()
        val isBreak = p.getString(TimerStateStore.KEY_PHASE, "work") == "rest"
        val plan = runningTimerNotificationPlan(
            richPanel = useV43CustomPanel(),
            isBreak = isBreak,
            targetSeconds = TimerStateStore
                .readIntCompat(p, TimerStateStore.KEY_TARGET_SECONDS, 0)
                .takeIf { it > 0 },
            startedAtMs = startedAtMs,
            nowMs = System.currentTimeMillis(),
        )
        val builder = baseBuilder()
            .setOngoing(true)
            .setContentIntent(openAppPending())
            .setCategory(NotificationCompat.CATEGORY_STOPWATCH)
        if (plan.usesCustomView) {
            val custom = buildRunningRemoteViews(startedAtMs, isBreak)
            builder
                .setContentTitle("")
                .setContentText("")
                .setUsesChronometer(false)
                .setShowWhen(false)
                .setStyle(NotificationCompat.DecoratedCustomViewStyle())
                .setCustomContentView(custom)
                .setCustomBigContentView(custom)
            return builder.build()
        }
        builder
            .setContentTitle(getString(plan.titleRes))
            .setContentText(getString(plan.bodyRes))
            .setUsesChronometer(true)
            .setWhen(plan.whenMs)
            .setShowWhen(true)
            .setChronometerCountDown(plan.countDown)
            .setRequestPromotedOngoing(plan.requestPromotedOngoing)
            .addAction(
                0,
                if (isBreak) getString(R.string.action_return_to_work)
                else getString(R.string.action_stop),
                if (isBreak) endBreakActionPending() else stopActionPending(),
            )
        if (plan.shortCriticalTextRes != 0) {
            builder.setShortCriticalText(getString(plan.shortCriticalTextRes))
        }
        if (plan.style == TimerNotificationStyle.PROGRESS) {
            builder.setStyle(
                NotificationCompat.ProgressStyle()
                    .addProgressSegment(
                        NotificationCompat.ProgressStyle.Segment(plan.totalSeconds),
                    )
                    .setProgress(plan.progressSeconds),
            )
        }
        return builder.build()
    }

    private fun buildIdleNotification(): Notification {
        ensureChannel()
        val builder = baseBuilder()
            .setOngoing(false)
            .setContentIntent(openAppPending())
            .setCategory(NotificationCompat.CATEGORY_STOPWATCH)
        if (useV43CustomPanel()) {
            val custom = buildIdleRemoteViews()
            builder
                .setUsesChronometer(false)
                .setShowWhen(false)
                .setContentTitle("")
                .setContentText("")
                .setStyle(NotificationCompat.DecoratedCustomViewStyle())
                .setCustomContentView(custom)
                .setCustomBigContentView(custom)
        } else {
            builder
                .setUsesChronometer(false)
                .setShowWhen(false)
                .setContentTitle(IDLE_NOTIFICATION_TIMER_TEXT)
                .setContentText(getString(R.string.timer_ready))
                .addAction(0, getString(R.string.action_start), startActionPending())
        }
        return builder.build()
    }

    /**
     * WP-753 geri dönüş valfi: `true` = v43 zengin özel panel, yazılmamış/`false`
     * = Live Update yolu. Varsayılan artık **Live Update**; sahip beğenmezse tek
     * bayrakla eski panele dönülür. (Ayarlar arayüzü ayrı WP — Dart l10n
     * katalogları bu turda başka bir lane'de.)
     *
     * Karar dosya düzeyindeki saf [useV43CustomPanel] içindedir; cihazsız JVM
     * testi anahtarın yokluğunu da ölçebilsin diye.
     */
    private fun useV43CustomPanel(): Boolean = useV43CustomPanel(prefs())

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
            IDLE_NOTIFICATION_TIMER_TEXT,
            false,
        )
        views.setTextViewText(R.id.notif_timer_elapsed, IDLE_NOTIFICATION_TIMER_TEXT)
        views.setTextViewText(R.id.notif_timer_action, getString(R.string.action_start))
        views.setOnClickPendingIntent(R.id.notif_timer_action, startActionPending())
        return views
    }

    private fun baseBuilder(): NotificationCompat.Builder =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(TIMER_NOTIFICATION_SMALL_ICON)
            .setContentText("")
            .setOnlyAlertOnce(true)
            .setSound(null)
            .setVibrate(null)
            .setCategory(NotificationCompat.CATEGORY_STOPWATCH)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)

    private fun stopActionPending(): PendingIntent = actionPending(ACTION_STOP, 1)

    private fun startActionPending(): PendingIntent = actionPending(ACTION_START, 2)

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

    /**
     * WP-558: kanal her serviste KOŞULSUZ yeniden yaratılır.
     *
     * `createNotificationChannel` var olan bir kanalın **adını ve
     * açıklamasını günceller** (importance ve kullanıcının kendi ayarları
     * korunur). Eski erken `return` yüzünden kanal adı ilk kurulumdaki dile
     * çakılıyor, kullanıcı dili değiştirince "Sayaç" başlığı eski dilde
     * kalıyordu. Dart tarafı (`app_push_notification_service.dart`) ve
     * `AlarmNotificationFallback.ensureChannel` zaten koşulsuz çağırır;
     * asimetri tek nokta buydu.
     */
    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
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
        const val ACTION_DISCARD_PROJECTION =
            "com.manilmax.online_study_room.timer.DISCARD_PROJECTION"
        const val ACTION_END_BREAK = "com.manilmax.online_study_room.timer.END_BREAK"

        const val EXTRA_STARTED_AT_MS = "startedAtMs"
        const val EXTRA_MODE = "mode"
        const val EXTRA_PHASE = "phase"
        const val EXTRA_CYCLE = "cycle"
        const val EXTRA_TARGET_SECONDS = "targetSeconds"
        const val EXTRA_SUBJECT_ID = "subjectId"
        const val EXTRA_LIVE_RUN_ID = "liveRunId"
        const val EXTRA_LIVE_RUN_TOKEN = "liveRunToken"
        const val EXTRA_START_ORIGIN = "startOrigin"

        const val BROADCAST_STATE_CHANGED = "com.manilmax.online_study_room.timer.STATE_CHANGED"

        private const val CHANNEL_ID = "study_timer_live_fg"
        private const val NOTIFICATION_ID = 7040
        private const val LEGACY_FLUTTER_NOTIFICATION_ID = 7001

        /** Servisi belirli bir komutla ayağa kaldırır (receiver/notification/Dart). */
        fun sendCommand(
            context: Context,
            action: String,
            startedAtMs: Long? = null,
            mode: String? = null,
            phase: String? = null,
            cycle: Int? = null,
            targetSeconds: Int? = null,
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
                targetSeconds?.takeIf { it > 0 }?.let { putExtra(EXTRA_TARGET_SECONDS, it) }
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
