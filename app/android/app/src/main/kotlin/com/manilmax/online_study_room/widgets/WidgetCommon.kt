package com.manilmax.online_study_room.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import com.manilmax.online_study_room.timer.TimerStateStore

/**
 * WP-752 - dokuz ana ekran widget'inin PAYLASILAN kod zemini.
 *
 * Bu dosya bir saglayici icermez; her saglayici kendi dosyasindadir
 * (`TimerWidget.kt`, `StatsWidget.kt`, `LeaderboardWidget.kt`,
 * `GroupGoalWidget.kt`, `ClockWidget.kt`, `AlarmWidget.kt`, `CountdownWidget.kt`,
 * `TaskWidget.kt`, `MinimalTimerWidget.kt`). Burada yalniz **birden fazla**
 * widget'in kullandigi sey durur: boyut siniflari, punto merdiveni, kok dolgu,
 * prefs okumalari ve `RemoteViews` yardimcilari.
 *
 * 🔴 Neden bolundu: onceki `StudyWidgetProviders.kt` alti saglayiciyi tek
 * dosyada tasiyordu (1000+ satir). Widget tasarimini paralel yuruten ajanlar
 * ayni dosyayi ayni anda yazamaz. Bolme **saf tasimadir**: sinif adlari, paket
 * ve govdeler degismedi - `AndroidManifest.xml` saglayicilara tam nitelikli
 * adla referans verir ve bir ad degisikligi DERLEME HATASI URETMEDEN widget'i
 * oldururdu.
 */

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

internal object StudyWidgetKeys {
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

internal fun SharedPreferences.text(key: String, fallback: String): String =
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
internal const val WIDGET_TIMER_DEFAULT_HEIGHT_DP = 40
internal const val WIDGET_TIMER_MEDIUM_WIDTH_DP = 150
internal const val WIDGET_TIMER_WIDE_WIDTH_DP = 220
internal const val WIDGET_TIMER_MEDIUM_HEIGHT_DP = 110
internal const val WIDGET_TIMER_TALL_HEIGHT_DP = 180

internal const val WIDGET_CLOCK_DEFAULT_WIDTH_DP = 110
internal const val WIDGET_CLOCK_DEFAULT_HEIGHT_DP = 40
internal const val WIDGET_CLOCK_MEDIUM_WIDTH_DP = 150
internal const val WIDGET_CLOCK_WIDE_WIDTH_DP = 220
internal const val WIDGET_CLOCK_MEDIUM_HEIGHT_DP = 70
internal const val WIDGET_CLOCK_TALL_HEIGHT_DP = 110

internal const val WIDGET_COUNTDOWN_DEFAULT_WIDTH_DP = 110
internal const val WIDGET_COUNTDOWN_DEFAULT_HEIGHT_DP = 110
internal const val WIDGET_COUNTDOWN_MEDIUM_WIDTH_DP = 150
internal const val WIDGET_COUNTDOWN_WIDE_WIDTH_DP = 220
internal const val WIDGET_COUNTDOWN_MEDIUM_HEIGHT_DP = 110
internal const val WIDGET_COUNTDOWN_TALL_HEIGHT_DP = 180

internal const val WIDGET_STATS_DEFAULT_WIDTH_DP = 110
internal const val WIDGET_STATS_DEFAULT_HEIGHT_DP = 40
internal const val WIDGET_STATS_MEDIUM_WIDTH_DP = 150
internal const val WIDGET_STATS_WIDE_WIDTH_DP = 220
internal const val WIDGET_STATS_MEDIUM_HEIGHT_DP = 80
internal const val WIDGET_STATS_TALL_HEIGHT_DP = 110

internal const val WIDGET_GROUP_GOAL_DEFAULT_WIDTH_DP = 110
internal const val WIDGET_GROUP_GOAL_DEFAULT_HEIGHT_DP = 110
internal const val WIDGET_GROUP_GOAL_MEDIUM_WIDTH_DP = 150
internal const val WIDGET_GROUP_GOAL_WIDE_WIDTH_DP = 220
internal const val WIDGET_GROUP_GOAL_MEDIUM_HEIGHT_DP = 110
internal const val WIDGET_GROUP_GOAL_TALL_HEIGHT_DP = 150

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

// ---------------------------------------------------------------------------
// WP-752 · §3.4 genislik modeli — tum kademe aritmetiginin kaynagi
//
// Sozlesme: `docs/tasarim/widget-tasarim-sistemi.md` §3.1/§3.4/§7-6.
//
//     sp_max = (W_dp - 2*dolgu - emniyet) / (0.60 * k * karakter_sayisi)
//
//   0.60 : Roboto'nun ortalama rakam ilerlemesi / punto. DUSURULMEZ —
//          `sans-serif-condensed`in dar olusu butceye degil EMNIYET PAYINA
//          yazilir, boylece hicbir kutu cihazda olculmeden once iyimser
//          hesaplanmis olmaz.
//   k    : birlesik yatay katsayi = textScaleX x yazitipi daralmasi.
//
// 🔴 `autoSizeTextType` KULLANILMAZ: `TextView`in auto-size metotlari
// `@RemotableViewMethod` degildir, RemoteViews'ta calismaz. Punto buradaki
// SAF merdivenden gelir ve JVM biriminde olculur.
// ---------------------------------------------------------------------------

/** Roboto rakam ilerlemesi / punto. Bilerek comert; asagi cekilmez. */
internal const val WIDGET_GLYPH_ADVANCE = 0.60f

/** Her kutuda birakilan yatay emniyet payi (dp). */
internal const val WIDGET_TEXT_SAFETY_DP = 8f

/**
 * §7 madde 6: yatay sikistirmanin sistem TABANI.
 *
 * `textScaleX` bunun altina inmez. 0.55 bir daraltma degil DEFORMASYONdur:
 * gliflerin dikey cizgileri kalin, yatay cizgileri ince kalir ve rakam
 * "hastalikli" gorunur — sahibin cihazda gordugu bozuk rakamlar budur.
 * Daraltma `sans-serif-condensed` ile yapilir, `textScaleX` ile degil.
 */
internal const val WIDGET_TEXT_SCALE_X_MIN = 0.85f

/**
 * `sans-serif-condensed` (Roboto Condensed) kendi ilerleme genisligi.
 * Taban ile birleske: `0.85 * 0.87 ~= 0.74` — bugunku 0.55'in cok ustunde,
 * yani ayni kutuda gozle gorulur bir kalite kazanci.
 *
 * `sans-serif-condensed-light` YASAKTIR: sac inceligindeki cizgiler duvar
 * kagidi parildisinda kaybolur.
 */
internal const val WIDGET_CONDENSED_ADVANCE = 0.87f

/** Anlam tasiyan hicbir metin bunun altina inmez (§3.3). */
internal const val WIDGET_MIN_TEXT_SP = 11f

/**
 * Verilen kutuya [chars] karakterin sigdigi EN BUYUK punto.
 *
 * [advanceScale] birlesik yatay katsayidir (textScaleX x yazitipi daralmasi),
 * `k`. Sonuc tam sp'ye ASAGI yuvarlanir: yarim punto diye bir sey yok ve
 * yukari yuvarlamak tam da kirpilan hali secerdi.
 */
internal fun widgetMaxSp(
    widthDp: Int,
    paddingDp: Int,
    chars: Int,
    advanceScale: Float,
): Float {
    val usable = widthDp - 2f * paddingDp - WIDGET_TEXT_SAFETY_DP
    if (usable <= 0f || chars <= 0 || advanceScale <= 0f) return 0f
    val exact = usable / (WIDGET_GLYPH_ADVANCE * advanceScale * chars)
    return kotlin.math.floor(exact.toDouble()).toFloat()
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
    // 🔴 WP-718 (sahibin cihazda gordugu kusur): eski merdiven (15/22/30) en
    // dar sinifta 15sp'lik bir "00:00" ciziyordu. Yeni sayilar ayni kirpma
    // modelinin (0.60 x punto x karakter + 8dp emniyet) izin verdigi EN BUYUK
    // degerlerdir; daha buyugu gercekten kirpar.
    //   NARROW 110dp: (110 - 2*7 - 8) / (0.60 * 8) = 18.3 -> 18sp
    //   MEDIUM 150dp: (150 - 2*7 - 8) / (0.60 * 8) = 26.6 -> 26sp
    //   WIDE   220dp: (220 - 2*7 - 8) / (0.60 * 8) = 41.2 -> 40sp
    val timerTime = SpRamp(28f, 34f, 44f)
    val timerAction = SpRamp(13f, 14f, 16f)

    /** WP-718: ders hapi. Yalniz genislik >= MEDIUM iken cizilir. */
    val timerSubject = SpRamp(11f, 11f, 13f)
    val clockTime = SpRamp(24f, 36f, 52f)
    val clockDate = SpRamp(11f, 12f, 14f)
    val countdownDays = SpRamp(24f, 30f, 46f)
    val countdownName = SpRamp(12f, 12f, 15f)
    val countdownLabel = SpRamp(11f, 12f, 14f)
    val statsValue = SpRamp(20f, 26f, 32f)
    val statsTitle = SpRamp(11f, 13f, 15f)
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

// ---------------------------------------------------------------------------
// WP-718 · sayac widget'inin dokunma hedefi ve satir gorunurlugu
// ---------------------------------------------------------------------------

/**
 * Android widget kilavuzunun asgari dokunma hedefi. Eski Baslat/Durdur hapi
 * `minHeight=32dp` idi — bunun ucte ikisi.
 */
internal const val WIDGET_MIN_TOUCH_TARGET_DP = 48

/** `@dimen/widget_design_row_gap` (WP-717) — layout ile testin ortak sayisi. */
internal const val WIDGET_DESIGN_ROW_GAP_DP = 4

internal fun countdownNameVisible(height: WidgetHeightClass): Boolean =
    height != WidgetHeightClass.SHORT

/**
 * Launcher'ın bildirdiği boyut. `OPTION_APPWIDGET_MIN_*` **bilerek** seçildi:
 * `MAX_*` diğer ekran yönündeki ölçüdür; ona göre çizmek, cihaz döndüğünde
 * dar kalan yönde metni kırpardı.
 */
internal data class WidgetDimensions(
    val widthDp: Int,
    val heightDp: Int,
    val sizeClass: WidgetSizeClass,
)

internal fun AppWidgetManager.dimensions(spec: WidgetSizeSpec, widgetId: Int): WidgetDimensions {
    val options = runCatching { getAppWidgetOptions(widgetId) }.getOrNull()
    val reportedWidth = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0) ?: 0
    val reportedHeight = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0) ?: 0
    val width = reportedWidth.takeIf { it > 0 } ?: spec.defaultWidthDp
    val height = reportedHeight.takeIf { it > 0 } ?: spec.defaultHeightDp
    return WidgetDimensions(width, height, widgetSizeClass(spec, width, height))
}

internal fun AppWidgetManager.sizeClass(spec: WidgetSizeSpec, widgetId: Int): WidgetSizeClass =
    dimensions(spec, widgetId).sizeClass

internal fun RemoteViews.applySp(viewId: Int, sp: Float) =
    setTextViewTextSize(viewId, android.util.TypedValue.COMPLEX_UNIT_SP, sp)

internal fun RemoteViews.applyRootPadding(context: Context, viewId: Int, dp: Int) {
    val px = (dp * context.resources.displayMetrics.density).toInt()
    setViewPadding(viewId, px, px, px, px)
}

/**
 * WP-718: widget → [TimerActionReceiver] yayini.
 *
 * Acik (explicit) intent + `FLAG_IMMUTABLE` (WP-118). `requestCode` aksiyon
 * basina AYRI olmak zorundadir: `PendingIntent` esitligi `Intent.filterEquals`
 * ile olculur ve extra'lar o karsilastirmaya GIRMEZ — iki aksiyon ayni
 * requestCode'u paylassaydi ikincisi birincisini ezerdi. (Aksiyon burada
 * `Intent.action` alaninda tasindigi icin `filterEquals` zaten ayirir; ayri
 * requestCode ikinci emniyettir.)
 */
internal fun widgetBroadcast(
    context: Context,
    action: String,
    requestCode: Int,
): android.app.PendingIntent = android.app.PendingIntent.getBroadcast(
    context,
    requestCode,
    android.content.Intent(context, TimerActionReceiver::class.java).setAction(action),
    android.app.PendingIntent.FLAG_UPDATE_CURRENT or
        android.app.PendingIntent.FLAG_IMMUTABLE,
)
