package com.manilmax.online_study_room.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import com.manilmax.online_study_room.R
import com.manilmax.online_study_room.timer.TimerStateStore
import es.antonborri.home_widget.HomeWidgetProvider

internal const val WIDGET_IDLE_TIMER_TEXT = "00:00"

internal enum class TimerChronometerDirection { IDLE, UP, DOWN }

internal data class TimerChronometerProjection(
    val direction: TimerChronometerDirection,
    val baseElapsedRealtimeMs: Long,
    val running: Boolean,
)

/** Pure wall-clock -> Chronometer projection shared by the widget and JVM tests. */
internal fun timerChronometerProjection(
    isRunning: Boolean,
    mode: String?,
    startedAtMs: Long?,
    targetSeconds: Int?,
    nowWallClockMs: Long,
    nowElapsedRealtimeMs: Long,
): TimerChronometerProjection {
    if (!isRunning || startedAtMs == null) {
        return TimerChronometerProjection(
            TimerChronometerDirection.IDLE,
            nowElapsedRealtimeMs,
            false,
        )
    }
    if (mode == "stopwatch") {
        return TimerChronometerProjection(
            TimerChronometerDirection.UP,
            nowElapsedRealtimeMs - (nowWallClockMs - startedAtMs).coerceAtLeast(0L),
            true,
        )
    }
    val target = targetSeconds?.takeIf { it > 0 }
        ?: return TimerChronometerProjection(
            TimerChronometerDirection.IDLE,
            nowElapsedRealtimeMs,
            false,
        )
    val elapsedMs = (nowWallClockMs - startedAtMs).coerceAtLeast(0L)
    val remainingMs = (target * 1_000L - elapsedMs).coerceAtLeast(0L)
    return TimerChronometerProjection(
        TimerChronometerDirection.DOWN,
        nowElapsedRealtimeMs + remainingMs,
        remainingMs > 0L,
    )
}

/**
 * WP-489: sayaç widget'ının prefs okumaları.
 *
 * `onUpdate` bir [android.content.BroadcastReceiver] içinde koşar; oradaki tek
 * yakalanmamış istisna uygulama **sürecini** öldürür (kullanıcının gördüğü
 * "geri sayımı başlatınca uygulama kapanıyor" budur). Okumalar bu yüzden tek
 * noktada toplanır ve hata widget'ı idle'a düşürür — uygulamayı değil.
 */
internal data class TimerWidgetPrefs(
    val startedAtMs: Long?,
    val mode: String?,
    val targetSeconds: Int?,
)

internal fun readTimerWidgetPrefs(prefs: SharedPreferences): TimerWidgetPrefs = runCatching {
    TimerWidgetPrefs(
        // Epoch-millis anahtarı (native servis yazar) string ISO'dan daha
        // güvenilir; yoksa eski string anahtarından geri düşer.
        startedAtMs = TimerStateStore.startedAtMs(prefs).takeIf { it > 0L },
        mode = prefs.getString(TimerStateStore.KEY_MODE, null),
        targetSeconds = TimerStateStore
            .readIntCompat(prefs, TimerStateStore.KEY_TARGET_SECONDS, 0)
            .takeIf { it > 0 },
    )
}.getOrElse { TimerWidgetPrefs(null, null, null) }

private object StudyWidgetKeys {
    const val TimerTitle = "timer_title"
    const val TimerElapsed = "timer_elapsed"
    const val TimerStatus = "timer_status"
    const val TimerAction = "timer_action"
    const val StatsTitle = "stats_title"
    const val StatsToday = "stats_today"
    const val StatsWeek = "stats_week"
    const val StatsStreak = "stats_streak"
    const val DailyGoalPercent = "daily_goal_percent"
    const val DailyGoalDetail = "daily_goal_detail"
    const val GroupGoalPercent = "group_goal_percent"
    const val GroupGoalDetail = "group_goal_detail"
    const val LeaderboardTitle = "leaderboard_title"
    const val LeaderboardRow1 = "leaderboard_row_1"
    const val LeaderboardRow2 = "leaderboard_row_2"
    const val LeaderboardRow3 = "leaderboard_row_3"
    const val LeaderboardMyRank = "leaderboard_my_rank"
}

private fun SharedPreferences.text(key: String, fallback: String): String =
    getString(key, fallback) ?: fallback

// ---------------------------------------------------------------------------
// WP-699: boyut sınıfları
//
// Model **iki eksenlidir** ve bu bilerek böyledir:
//   • GENİŞLİK punto merdivenini seçer (dar bir kutuda büyük punto kırpılır),
//   • YÜKSEKLİK kaç satırın görüneceğini seçer (kısa bir kutuda alt satırlar
//     taşar).
// Tek bir `compact` bayrağı bu ikisini birbirine bağlıyordu: 4×1 gibi geniş
// ama kısa bir widget'ta punto küçülüyor, 2×3 gibi dar ama uzun bir widget'ta
// detay satırları gizleniyordu — ikisi de yanlış taraftı.
//
// Eşikler widget başına ayrıdır çünkü içerik ayrıdır: sıralama widget'ı üç
// isim satırı taşır, saat widget'ı tek sayı. Eşiği içerikten türetmek yerine
// tek bir global merdiven kullanmak, ya sıralamayı kırpar ya saati küçültürdü.
// ---------------------------------------------------------------------------

internal enum class WidgetWidthClass { NARROW, MEDIUM, WIDE }

internal enum class WidgetHeightClass { SHORT, MEDIUM, TALL }

internal data class WidgetSizeClass(
    val width: WidgetWidthClass,
    val height: WidgetHeightClass,
)

/**
 * Bir widget'ın boyut eşikleri. [defaultWidthDp]/[defaultHeightDp] `res/xml`
 * içindeki `minWidth`/`minHeight` ile birebir aynıdır; launcher henüz bir
 * boyut bildirmediğinde (seçenek paketi boş gelir, `getInt` 0 döner) sınıf
 * **varsayılan boyuttan** hesaplanır. 0'ı olduğu gibi kullanmak, ilk çizimde
 * her widget'ı en dar/en kısa sınıfa düşürür ve kullanıcı widget'ı ekleyince
 * bir anlığına detaysız bir kutu görürdü.
 */
internal data class WidgetSizeSpec(
    val defaultWidthDp: Int,
    val defaultHeightDp: Int,
    val mediumWidthDp: Int,
    val wideWidthDp: Int,
    val mediumHeightDp: Int,
    val tallHeightDp: Int,
)

// Eşikler `res/xml/odak_*_widget_info.xml` içindeki minResize/maxResize
// sınırlarıyla birlikte anlam taşır; ikisinin ayrışmadığını
// `test/features/android_widgets/widget_sizing_wp699_test.dart` ölçer.
internal const val WIDGET_TIMER_DEFAULT_WIDTH_DP = 110
internal const val WIDGET_TIMER_DEFAULT_HEIGHT_DP = 110
internal const val WIDGET_TIMER_MEDIUM_WIDTH_DP = 150
internal const val WIDGET_TIMER_WIDE_WIDTH_DP = 220
internal const val WIDGET_TIMER_MEDIUM_HEIGHT_DP = 110
internal const val WIDGET_TIMER_TALL_HEIGHT_DP = 180

internal const val WIDGET_CLOCK_DEFAULT_WIDTH_DP = 110
internal const val WIDGET_CLOCK_DEFAULT_HEIGHT_DP = 110
internal const val WIDGET_CLOCK_MEDIUM_WIDTH_DP = 150
internal const val WIDGET_CLOCK_WIDE_WIDTH_DP = 220
internal const val WIDGET_CLOCK_MEDIUM_HEIGHT_DP = 110
internal const val WIDGET_CLOCK_TALL_HEIGHT_DP = 180

internal const val WIDGET_COUNTDOWN_DEFAULT_WIDTH_DP = 110
internal const val WIDGET_COUNTDOWN_DEFAULT_HEIGHT_DP = 110
internal const val WIDGET_COUNTDOWN_MEDIUM_WIDTH_DP = 150
internal const val WIDGET_COUNTDOWN_WIDE_WIDTH_DP = 220
internal const val WIDGET_COUNTDOWN_MEDIUM_HEIGHT_DP = 110
internal const val WIDGET_COUNTDOWN_TALL_HEIGHT_DP = 180

internal const val WIDGET_STATS_DEFAULT_WIDTH_DP = 110
internal const val WIDGET_STATS_DEFAULT_HEIGHT_DP = 110
internal const val WIDGET_STATS_MEDIUM_WIDTH_DP = 150
internal const val WIDGET_STATS_WIDE_WIDTH_DP = 220
internal const val WIDGET_STATS_MEDIUM_HEIGHT_DP = 150
internal const val WIDGET_STATS_TALL_HEIGHT_DP = 180

internal const val WIDGET_GROUP_GOAL_DEFAULT_WIDTH_DP = 110
internal const val WIDGET_GROUP_GOAL_DEFAULT_HEIGHT_DP = 110
internal const val WIDGET_GROUP_GOAL_MEDIUM_WIDTH_DP = 150
internal const val WIDGET_GROUP_GOAL_WIDE_WIDTH_DP = 220
internal const val WIDGET_GROUP_GOAL_MEDIUM_HEIGHT_DP = 150
internal const val WIDGET_GROUP_GOAL_TALL_HEIGHT_DP = 180

internal const val WIDGET_LEADERBOARD_DEFAULT_WIDTH_DP = 180
internal const val WIDGET_LEADERBOARD_DEFAULT_HEIGHT_DP = 110
internal const val WIDGET_LEADERBOARD_MEDIUM_WIDTH_DP = 220
internal const val WIDGET_LEADERBOARD_WIDE_WIDTH_DP = 280
internal const val WIDGET_LEADERBOARD_MEDIUM_HEIGHT_DP = 110
internal const val WIDGET_LEADERBOARD_TALL_HEIGHT_DP = 150

internal object WidgetSizeSpecs {
    val timer = WidgetSizeSpec(
        WIDGET_TIMER_DEFAULT_WIDTH_DP,
        WIDGET_TIMER_DEFAULT_HEIGHT_DP,
        WIDGET_TIMER_MEDIUM_WIDTH_DP,
        WIDGET_TIMER_WIDE_WIDTH_DP,
        WIDGET_TIMER_MEDIUM_HEIGHT_DP,
        WIDGET_TIMER_TALL_HEIGHT_DP,
    )
    val clock = WidgetSizeSpec(
        WIDGET_CLOCK_DEFAULT_WIDTH_DP,
        WIDGET_CLOCK_DEFAULT_HEIGHT_DP,
        WIDGET_CLOCK_MEDIUM_WIDTH_DP,
        WIDGET_CLOCK_WIDE_WIDTH_DP,
        WIDGET_CLOCK_MEDIUM_HEIGHT_DP,
        WIDGET_CLOCK_TALL_HEIGHT_DP,
    )
    val countdown = WidgetSizeSpec(
        WIDGET_COUNTDOWN_DEFAULT_WIDTH_DP,
        WIDGET_COUNTDOWN_DEFAULT_HEIGHT_DP,
        WIDGET_COUNTDOWN_MEDIUM_WIDTH_DP,
        WIDGET_COUNTDOWN_WIDE_WIDTH_DP,
        WIDGET_COUNTDOWN_MEDIUM_HEIGHT_DP,
        WIDGET_COUNTDOWN_TALL_HEIGHT_DP,
    )
    val stats = WidgetSizeSpec(
        WIDGET_STATS_DEFAULT_WIDTH_DP,
        WIDGET_STATS_DEFAULT_HEIGHT_DP,
        WIDGET_STATS_MEDIUM_WIDTH_DP,
        WIDGET_STATS_WIDE_WIDTH_DP,
        WIDGET_STATS_MEDIUM_HEIGHT_DP,
        WIDGET_STATS_TALL_HEIGHT_DP,
    )
    val groupGoal = WidgetSizeSpec(
        WIDGET_GROUP_GOAL_DEFAULT_WIDTH_DP,
        WIDGET_GROUP_GOAL_DEFAULT_HEIGHT_DP,
        WIDGET_GROUP_GOAL_MEDIUM_WIDTH_DP,
        WIDGET_GROUP_GOAL_WIDE_WIDTH_DP,
        WIDGET_GROUP_GOAL_MEDIUM_HEIGHT_DP,
        WIDGET_GROUP_GOAL_TALL_HEIGHT_DP,
    )
    val leaderboard = WidgetSizeSpec(
        WIDGET_LEADERBOARD_DEFAULT_WIDTH_DP,
        WIDGET_LEADERBOARD_DEFAULT_HEIGHT_DP,
        WIDGET_LEADERBOARD_MEDIUM_WIDTH_DP,
        WIDGET_LEADERBOARD_WIDE_WIDTH_DP,
        WIDGET_LEADERBOARD_MEDIUM_HEIGHT_DP,
        WIDGET_LEADERBOARD_TALL_HEIGHT_DP,
    )
}

/** Saf sınıflandırma — JVM testi bunu doğrudan ölçer (`WidgetSizeClassWp699Test`). */
internal fun widgetSizeClass(
    spec: WidgetSizeSpec,
    widthDp: Int,
    heightDp: Int,
): WidgetSizeClass {
    val width = if (widthDp > 0) widthDp else spec.defaultWidthDp
    val height = if (heightDp > 0) heightDp else spec.defaultHeightDp
    return WidgetSizeClass(
        width = when {
            width >= spec.wideWidthDp -> WidgetWidthClass.WIDE
            width >= spec.mediumWidthDp -> WidgetWidthClass.MEDIUM
            else -> WidgetWidthClass.NARROW
        },
        height = when {
            height >= spec.tallHeightDp -> WidgetHeightClass.TALL
            height >= spec.mediumHeightDp -> WidgetHeightClass.MEDIUM
            else -> WidgetHeightClass.SHORT
        },
    )
}

/** Punto merdiveni; genişlik sınıfına göre seçilir. */
internal data class SpRamp(val narrow: Float, val medium: Float, val wide: Float) {
    fun of(widthClass: WidgetWidthClass): Float = when (widthClass) {
        WidgetWidthClass.NARROW -> narrow
        WidgetWidthClass.MEDIUM -> medium
        WidgetWidthClass.WIDE -> wide
    }
}

/**
 * Punto tablosu. Sayılar içerikten türedi: her sınıfın **en dar** halinde
 * satırın tahmini genişliği kutuya sığmalı. Aritmetiği
 * `WidgetSizeClassWp699Test.kt` yeniden kurar; punto büyütülürse test kırmızı
 * düşer.
 */
internal object WidgetTypography {
    val timerTime = SpRamp(15f, 22f, 30f)
    val timerAction = SpRamp(11f, 12f, 14f)
    val clockTime = SpRamp(24f, 36f, 52f)
    val clockDate = SpRamp(11f, 12f, 14f)
    val countdownDays = SpRamp(24f, 30f, 46f)
    val countdownName = SpRamp(12f, 12f, 15f)
    val countdownLabel = SpRamp(11f, 12f, 14f)
    val statsValue = SpRamp(22f, 28f, 34f)
    val statsTitle = SpRamp(12f, 14f, 16f)
    val statsRow = SpRamp(11f, 12f, 14f)
    val leaderboardTitle = SpRamp(13f, 14f, 16f)
    val leaderboardRow = SpRamp(12f, 13f, 15f)
}

/**
 * Kök dolgu yükseklik sınıfıyla birlikte büyür: uzun bir kutuda aynı dolguyla
 * çizmek, sahibin "büyük boyutta içerik ortada kucucuk kalmasın" itirazının
 * diğer yarısıdır — içerik büyür, çerçeve de nefes alır.
 */
internal fun widgetRootPaddingDp(basePaddingDp: Int, heightClass: WidgetHeightClass): Int =
    when (heightClass) {
        WidgetHeightClass.SHORT -> basePaddingDp
        WidgetHeightClass.MEDIUM -> basePaddingDp + 1
        WidgetHeightClass.TALL -> basePaddingDp + 2
    }

// Satır görünürlüğü YÜKSEKLİK sınıfından türer. Saf tutuldu ki JVM testi
// kullanıcının gerçekten gördüğü dalı ölçebilsin.
internal fun clockDateVisible(height: WidgetHeightClass): Boolean =
    height != WidgetHeightClass.SHORT

internal fun countdownNameVisible(height: WidgetHeightClass): Boolean =
    height != WidgetHeightClass.SHORT

internal fun statsDetailVisible(height: WidgetHeightClass): Boolean =
    height != WidgetHeightClass.SHORT

internal fun statsStreakVisible(height: WidgetHeightClass): Boolean =
    height == WidgetHeightClass.TALL

internal fun groupGoalDetailVisible(height: WidgetHeightClass): Boolean =
    height != WidgetHeightClass.SHORT

/** Kısa halde tek satır kalır; o satır listenin başı değil KULLANICININ sırasıdır. */
internal fun leaderboardShowsMyRank(height: WidgetHeightClass): Boolean =
    height == WidgetHeightClass.SHORT

internal fun leaderboardRow2Visible(height: WidgetHeightClass): Boolean =
    height != WidgetHeightClass.SHORT

internal fun leaderboardRow3Visible(height: WidgetHeightClass): Boolean =
    height == WidgetHeightClass.TALL

/**
 * Launcher'ın bildirdiği boyut. `OPTION_APPWIDGET_MIN_*` **bilerek** seçildi:
 * `MAX_*` diğer ekran yönündeki ölçüdür; ona göre çizmek, cihaz döndüğünde
 * dar kalan yönde metni kırpardı.
 */
private fun AppWidgetManager.sizeClass(spec: WidgetSizeSpec, widgetId: Int): WidgetSizeClass {
    val options = runCatching { getAppWidgetOptions(widgetId) }.getOrNull()
    val width = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0) ?: 0
    val height = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0) ?: 0
    return widgetSizeClass(spec, width, height)
}

private fun RemoteViews.applySp(viewId: Int, sp: Float) =
    setTextViewTextSize(viewId, android.util.TypedValue.COMPLEX_UNIT_SP, sp)

private fun RemoteViews.applyRootPadding(context: Context, viewId: Int, dp: Int) {
    val px = (dp * context.resources.displayMetrics.density).toInt()
    setViewPadding(viewId, px, px, px, px)
}

class TimerWidgetProvider : HomeWidgetProvider() {
    // WP-699: yeniden boyutlandırma tek başına `onUpdate` tetiklemez —
    // `AppWidgetProvider.onAppWidgetOptionsChanged` gövdesi boştur ve
    // `HomeWidgetProvider` onu geçersiz kılmaz. Bu metot yazılmadan boyut
    // sınıfı ekranda hiç değişmezdi; `updatePeriodMillis=0` olan bu widget'ta
    // ise bir daha ASLA yeniden çizilmezdi.
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId))
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.odak_timer_widget).apply {
                val size = appWidgetManager.sizeClass(WidgetSizeSpecs.timer, widgetId)
                val timerPrefs = readTimerWidgetPrefs(
                    context.getSharedPreferences(TimerStateStore.PREFS_NAME, Context.MODE_PRIVATE),
                )
                val isRunning = timerPrefs.startedAtMs != null
                val projection = timerChronometerProjection(
                    isRunning = isRunning,
                    mode = timerPrefs.mode,
                    startedAtMs = timerPrefs.startedAtMs,
                    targetSeconds = timerPrefs.targetSeconds,
                    nowWallClockMs = System.currentTimeMillis(),
                    nowElapsedRealtimeMs = SystemClock.elapsedRealtime(),
                )
                // WP-134: Chronometer HER boyutta VISIBLE (compact GONE kaldırıldı).
                // WP-699: iki satırın ikisi de her boyutta durur — sayaçta
                // gizlenebilecek "detay" yoktur; düğme gizlenirse widget işlevini
                // kaybeder. Esneklik punto ve dolguyla sağlanır.
                setViewVisibility(R.id.timer_widget_elapsed, View.VISIBLE)
                setViewVisibility(R.id.timer_widget_action, View.VISIBLE)
                applySp(R.id.timer_widget_elapsed, WidgetTypography.timerTime.of(size.width))
                applySp(R.id.timer_widget_action, WidgetTypography.timerAction.of(size.width))
                applyRootPadding(
                    context,
                    R.id.timer_widget_root,
                    widgetRootPaddingDp(6, size.height),
                )
                if (projection.direction != TimerChronometerDirection.IDLE) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        setChronometerCountDown(
                            R.id.timer_widget_elapsed,
                            projection.direction == TimerChronometerDirection.DOWN,
                        )
                    }
                    setChronometer(
                        R.id.timer_widget_elapsed,
                        projection.baseElapsedRealtimeMs,
                        null,
                        projection.running,
                    )
                } else {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        setChronometerCountDown(R.id.timer_widget_elapsed, false)
                    }
                    // Idle / sıfır: native Chronometer'ın MM:SS biçimiyle hizalı.
                    setChronometer(
                        R.id.timer_widget_elapsed,
                        SystemClock.elapsedRealtime(),
                        WIDGET_IDLE_TIMER_TEXT,
                        false,
                    )
                    setTextViewText(R.id.timer_widget_elapsed, WIDGET_IDLE_TIMER_TEXT)
                }
                // Tek düğme: çalışıyorsa Durdur, duruyorsa Başlat (native servis).
                setTextViewText(
                    R.id.timer_widget_action,
                    if (isRunning) {
                        context.getString(R.string.action_stop)
                    } else {
                        context.getString(R.string.action_start)
                    },
                )

                val actionIntent = android.content.Intent(context, TimerActionReceiver::class.java).apply {
                    action = TimerActionReceiver.ACTION_TOGGLE_TIMER
                }
                val pendingIntent = android.app.PendingIntent.getBroadcast(
                    context,
                    0,
                    actionIntent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.timer_widget_action, pendingIntent)
                // WP-700: KOK artik sayac bolumunu ACAR, toggle etmez.
                // Baslat/Durdur yalniz kendi hapinda kalir (`minHeight=32dp`,
                // 48dp'lik dokunma hedefine yakin); kok de toggle olsaydi
                // "uzerine dokununca o bolum acilsin" istegi karsilanamazdi.
                setOnClickPendingIntent(
                    R.id.timer_widget_root,
                    WidgetDeepLink.pendingIntent(
                        context,
                        WidgetDeepLink.ROUTE_TIMER,
                        widgetId,
                    ),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

class StudyStatsWidgetProvider : HomeWidgetProvider() {
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId))
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.odak_stats_widget).apply {
                val size = appWidgetManager.sizeClass(WidgetSizeSpecs.stats, widgetId)
                val percentText = widgetData.text(StudyWidgetKeys.DailyGoalPercent, "0%")
                val progress = percentText.removeSuffix("%").toIntOrNull()?.coerceIn(0, 100) ?: 0
                setTextViewText(
                    R.id.stats_widget_title,
                    context.getString(R.string.widget_daily_goal),
                )
                setTextViewText(
                    R.id.stats_widget_today,
                    percentText,
                )
                setProgressBar(R.id.stats_goal_progress, 100, progress, false)
                setOnClickPendingIntent(
                    R.id.stats_widget_root,
                    WidgetDeepLink.pendingIntent(
                        context,
                        WidgetDeepLink.ROUTE_STATS,
                        widgetId,
                    ),
                )
                setTextViewText(
                    R.id.stats_widget_week,
                    widgetData.text(
                        StudyWidgetKeys.DailyGoalDetail,
                        context.getString(R.string.widget_goal_detail_zero),
                    ),
                )
                setTextViewText(
                    R.id.stats_widget_streak,
                    widgetData.text(
                        StudyWidgetKeys.StatsStreak,
                        context.getString(R.string.widget_streak_zero),
                    ),
                )
                // WP-699: iki satır artık AYRI eşiklerde açılır. Eskiden ikisi
                // birden tek `compact` bayrağına bağlıydı; 2×2'de ikisi de
                // taşıyor, 2×3'te ikisi birden gelip sıkışıyordu.
                setViewVisibility(
                    R.id.stats_widget_week,
                    if (statsDetailVisible(size.height)) View.VISIBLE else View.GONE,
                )
                setViewVisibility(
                    R.id.stats_widget_streak,
                    if (statsStreakVisible(size.height)) View.VISIBLE else View.GONE,
                )
                applySp(R.id.stats_widget_title, WidgetTypography.statsTitle.of(size.width))
                applySp(R.id.stats_widget_today, WidgetTypography.statsValue.of(size.width))
                applySp(R.id.stats_widget_week, WidgetTypography.statsRow.of(size.width))
                applySp(R.id.stats_widget_streak, WidgetTypography.statsRow.of(size.width))
                applyRootPadding(
                    context,
                    R.id.stats_widget_root,
                    widgetRootPaddingDp(14, size.height),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

class GroupLeaderboardWidgetProvider : HomeWidgetProvider() {
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId))
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views =
                RemoteViews(context.packageName, R.layout.odak_leaderboard_widget).apply {
                    val size = appWidgetManager.sizeClass(WidgetSizeSpecs.leaderboard, widgetId)
                    setTextViewText(
                        R.id.leaderboard_widget_title,
                        widgetData.text(
                            StudyWidgetKeys.LeaderboardTitle,
                            context.getString(R.string.widget_leaderboard_title),
                        ),
                    )
                    setTextViewText(
                        R.id.leaderboard_widget_row_1,
                        if (leaderboardShowsMyRank(size.height)) {
                            widgetData.text(
                                StudyWidgetKeys.LeaderboardMyRank,
                                context.getString(R.string.widget_no_rank),
                            )
                        } else {
                            widgetData.text(
                                StudyWidgetKeys.LeaderboardRow1,
                                context.getString(R.string.widget_no_records),
                            )
                        },
                    )
                    setOnClickPendingIntent(
                        R.id.leaderboard_widget_root,
                        WidgetDeepLink.pendingIntent(
                            context,
                            WidgetDeepLink.ROUTE_GROUP,
                            widgetId,
                        ),
                    )
                    setTextViewText(
                        R.id.leaderboard_widget_row_2,
                        widgetData.text(StudyWidgetKeys.LeaderboardRow2, "-"),
                    )
                    setTextViewText(
                        R.id.leaderboard_widget_row_3,
                        widgetData.text(StudyWidgetKeys.LeaderboardRow3, "-"),
                    )
                    // WP-699: üçüncü satır ancak gerçekten uzun kutuda gelir.
                    // Eskiden 2. ve 3. satır birlikte açılıyordu; 3×2'de üç
                    // satır + başlık 110dp'ye sığmıyordu.
                    setViewVisibility(
                        R.id.leaderboard_widget_row_2,
                        if (leaderboardRow2Visible(size.height)) View.VISIBLE else View.GONE,
                    )
                    setViewVisibility(
                        R.id.leaderboard_widget_row_3,
                        if (leaderboardRow3Visible(size.height)) View.VISIBLE else View.GONE,
                    )
                    applySp(
                        R.id.leaderboard_widget_title,
                        WidgetTypography.leaderboardTitle.of(size.width),
                    )
                    val rowSp = WidgetTypography.leaderboardRow.of(size.width)
                    applySp(R.id.leaderboard_widget_row_1, rowSp)
                    applySp(R.id.leaderboard_widget_row_2, rowSp)
                    applySp(R.id.leaderboard_widget_row_3, rowSp)
                    applyRootPadding(
                        context,
                        R.id.leaderboard_widget_root,
                        widgetRootPaddingDp(14, size.height),
                    )
                }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

class GroupGoalWidgetProvider : HomeWidgetProvider() {
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId))
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.odak_group_goal_widget).apply {
                val size = appWidgetManager.sizeClass(WidgetSizeSpecs.groupGoal, widgetId)
                val percentText = widgetData.text(StudyWidgetKeys.GroupGoalPercent, "0%")
                val progress = percentText.removeSuffix("%").toIntOrNull()?.coerceIn(0, 100) ?: 0
                setTextViewText(
                    R.id.group_goal_widget_title,
                    context.getString(R.string.widget_group_goal),
                )
                setTextViewText(R.id.group_goal_widget_percent, percentText)
                setProgressBar(R.id.group_goal_widget_progress, 100, progress, false)
                setTextViewText(
                    R.id.group_goal_widget_detail,
                    widgetData.text(
                        StudyWidgetKeys.GroupGoalDetail,
                        context.getString(R.string.widget_join_group),
                    ),
                )
                setOnClickPendingIntent(
                    R.id.group_goal_widget_root,
                    WidgetDeepLink.pendingIntent(
                        context,
                        WidgetDeepLink.ROUTE_GROUP,
                        widgetId,
                    ),
                )
                setViewVisibility(
                    R.id.group_goal_widget_detail,
                    if (groupGoalDetailVisible(size.height)) View.VISIBLE else View.GONE,
                )
                applySp(R.id.group_goal_widget_title, WidgetTypography.statsTitle.of(size.width))
                applySp(R.id.group_goal_widget_percent, WidgetTypography.statsValue.of(size.width))
                applySp(R.id.group_goal_widget_detail, WidgetTypography.statsRow.of(size.width))
                applyRootPadding(
                    context,
                    R.id.group_goal_widget_root,
                    widgetRootPaddingDp(14, size.height),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

/** Dijital saat — TextClock native akar; Flutter tick yok. */
class ClockWidgetProvider : HomeWidgetProvider() {
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId))
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.odak_clock_widget).apply {
                // WP-699: saatin tek boyutu vardı — 36sp saat + tarih, ne
                // küçülüyor ne büyüyordu. `minHeight=40dp` ile eklenen bir saat
                // 12dp dolgu + 36sp satırı taşırıyordu.
                val size = appWidgetManager.sizeClass(WidgetSizeSpecs.clock, widgetId)
                applySp(R.id.clock_widget_time, WidgetTypography.clockTime.of(size.width))
                applySp(R.id.clock_widget_date, WidgetTypography.clockDate.of(size.width))
                setViewVisibility(
                    R.id.clock_widget_date,
                    if (clockDateVisible(size.height)) View.VISIBLE else View.GONE,
                )
                applyRootPadding(
                    context,
                    R.id.clock_widget_root,
                    widgetRootPaddingDp(12, size.height),
                )
                // WP-700: bu widget'in daha once HIC tiklama intent'i yoktu.
                setOnClickPendingIntent(
                    R.id.clock_widget_root,
                    WidgetDeepLink.pendingIntent(
                        context,
                        WidgetDeepLink.ROUTE_CLOCK,
                        widgetId,
                    ),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

/** Sıradaki alarm — native_alarm_mirror_v1 JSON'dan okur. */
class AlarmWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val raw = prefs.getString("flutter.native_alarm_mirror_v1", null)
        var timeText = context.getString(R.string.widget_em_dash)
        var labelText = context.getString(R.string.widget_no_alarm)
        val defaultAlarm = context.getString(R.string.alarm_default_label)
        if (!raw.isNullOrBlank()) {
            try {
                val arr = org.json.JSONArray(raw)
                var bestAt = Long.MAX_VALUE
                for (i in 0 until arr.length()) {
                    val o = arr.getJSONObject(i)
                    val at = o.optLong("triggerAtMs", Long.MAX_VALUE)
                    if (at < bestAt && at > System.currentTimeMillis()) {
                        bestAt = at
                        val h = o.optInt("hour", 0)
                        val m = o.optInt("minute", 0)
                        timeText = String.format("%02d:%02d", h, m)
                        labelText = o.optString("label", defaultAlarm)
                    }
                }
            } catch (_: Exception) {
                /* mirror bozuk */
            }
        }
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.odak_alarm_widget).apply {
                setTextViewText(R.id.alarm_widget_time, timeText)
                setTextViewText(R.id.alarm_widget_label, labelText)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
