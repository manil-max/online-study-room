package com.manilmax.online_study_room.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.widget.RemoteViews
import com.manilmax.online_study_room.R
import com.manilmax.online_study_room.timer.TimerStateStore

/**
 * WP-718 — "minimal sayac" ana ekran widget'i (sahip istegi: *"normal yeni
 * ekleyecegimiz minimal sayaci ek olarak android ana ekran widget'i olarak
 * eklemek guzel olur"*).
 *
 * ## Neden ayri bir saglayici
 * Ayni saglayicinin ikinci bir gorunumu olsaydi kullanici ikisini AYNI ANDA
 * ana ekranina koyamazdi: `AppWidgetProvider` basina tek bir
 * `res/xml/<ad>_widget_info.xml` (yani tek varsayilan boyut ve tek onizleme)
 * vardir.
 *
 * ## Neden ayri dugme yok
 * Tek gorunur oge sayidir; **tum yuzey** baslat/durdur'dur. 48dp'lik ayri bir
 * hap 1-2 hucrelik bir kutuda geriye okunur bir sayi icin yer birakmiyor
 * (olcum: `TimerWidgetWp718Test`). Hedefi kucultmek yerine yuzeyin tamamini
 * hedef yapmak, launcher'in gercek hucresi kadar (~70-85dp) buyuk bir dokunma
 * alani verir. Ayni karar sayac widget'inin en kucuk sinifinda da gecerlidir
 * (`timerControlsVisible`).
 *
 * ## Neden `AppWidgetProvider`, `HomeWidgetProvider` degil
 * Bu widget `widgetData`ya hic bakmaz — durumu `TimerStateStore` prefs'inden
 * ve kendi kendine tiklayan `Chronometer`dan alir. `HomeWidgetProvider`
 * turemek WP-708'in anahtar sahipligi sozlesmesine okuyucusu olmayan bir uye
 * eklerdi. Tazeleme `TimerWidgets.updateAll` ile dogrudan
 * `ACTION_APPWIDGET_UPDATE` yayinindan gelir; bu duz `AppWidgetProvider` ile
 * de calisir.
 *
 * ## `onAppWidgetOptionsChanged` (WP-699 dersi)
 * `AppWidgetProvider.onAppWidgetOptionsChanged` govdesi BOSTUR. Gecersiz
 * kilinmazsa yeniden boyutlandirma `onUpdate` tetiklemez ve
 * `updatePeriodMillis=0` olan bu widget bir daha ASLA yeniden cizilmez: punto
 * merdiveni beyanda kalir, ekranda hic degismez.
 */
class MinimalTimerWidgetProvider : AppWidgetProvider() {

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId))
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { widgetId ->
            val options = runCatching { appWidgetManager.getAppWidgetOptions(widgetId) }.getOrNull()
            val reportedWidthDp =
                options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0) ?: 0
            val reportedHeightDp =
                options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0) ?: 0
            val widthDp = reportedWidthDp.takeIf { it > 0 }
                ?: WIDGET_MINIMAL_TIMER_DEFAULT_WIDTH_DP
            val heightDp = reportedHeightDp.takeIf { it > 0 }
                ?: WIDGET_MINIMAL_TIMER_DEFAULT_HEIGHT_DP
            val prefs = context.getSharedPreferences(
                TimerStateStore.PREFS_NAME,
                Context.MODE_PRIVATE,
            )
            val timerPrefs = readTimerWidgetPrefs(prefs)
            val isRunning = timerPrefs.startedAtMs != null
            val projection = timerChronometerProjection(
                isRunning = isRunning,
                mode = timerPrefs.mode,
                startedAtMs = timerPrefs.startedAtMs,
                targetSeconds = timerPrefs.targetSeconds,
                nowWallClockMs = System.currentTimeMillis(),
                nowElapsedRealtimeMs = SystemClock.elapsedRealtime(),
            )

            val views = RemoteViews(context.packageName, R.layout.odak_minimal_timer_widget).apply {
                setTextViewTextSize(
                    R.id.minimal_timer_widget_elapsed,
                    android.util.TypedValue.COMPLEX_UNIT_SP,
                    minimalTimerTimeSp(widthDp, heightDp),
                )
                // Calisiyor/duruyor ayrimi RENKLE yapilir: ikinci bir satir
                // eklemek widget'i "minimal" olmaktan cikarirdi. Simgeler
                // WP-717'nin paylasilan dilinden gelir ve gece/gunduz karsiligi
                // `values-night` icindedir.
                setTextColor(
                    R.id.minimal_timer_widget_elapsed,
                    androidx.core.content.ContextCompat.getColor(
                        context,
                        if (isRunning) R.color.widget_design_accent else R.color.widget_design_ink,
                    ),
                )
                if (projection.direction != TimerChronometerDirection.IDLE) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        setChronometerCountDown(
                            R.id.minimal_timer_widget_elapsed,
                            projection.direction == TimerChronometerDirection.DOWN,
                        )
                    }
                    setChronometer(
                        R.id.minimal_timer_widget_elapsed,
                        projection.baseElapsedRealtimeMs,
                        null,
                        projection.running,
                    )
                } else {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        setChronometerCountDown(R.id.minimal_timer_widget_elapsed, false)
                    }
                    setChronometer(
                        R.id.minimal_timer_widget_elapsed,
                        SystemClock.elapsedRealtime(),
                        WIDGET_IDLE_TIMER_TEXT,
                        false,
                    )
                    setTextViewText(R.id.minimal_timer_widget_elapsed, WIDGET_IDLE_TIMER_TEXT)
                }
                // Tum yuzey tek hedef. Metin `strings.xml`den okunur (bu WP
                // yeni dize eklemez); erisilebilirlik icin ekran okuyucu bunu
                // duyurur.
                setContentDescription(
                    R.id.minimal_timer_widget_root,
                    context.getString(
                        if (isRunning) R.string.action_stop else R.string.action_start,
                    ),
                )
                setOnClickPendingIntent(
                    R.id.minimal_timer_widget_root,
                    android.app.PendingIntent.getBroadcast(
                        context,
                        0,
                        android.content.Intent(context, TimerActionReceiver::class.java)
                            .setAction(TimerActionReceiver.ACTION_TOGGLE_TIMER),
                        android.app.PendingIntent.FLAG_UPDATE_CURRENT or
                            android.app.PendingIntent.FLAG_IMMUTABLE,
                    ),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

// ---------------------------------------------------------------------------
// WP-718 · minimal sayacin boyut/punto modeli (saf — JVM testi bunu olcer)
//
// Esikler `res/xml/odak_minimal_timer_widget_info.xml` ile birlikte anlam
// tasir: varsayilan 2x1 (110x40dp), alt sinir 1x1 (40x40dp), ust sinir 4x2
// (250x110dp). Hucre -> dp donusumu `70n - 30`.
// ---------------------------------------------------------------------------

internal const val WIDGET_MINIMAL_TIMER_DEFAULT_WIDTH_DP = 110
internal const val WIDGET_MINIMAL_TIMER_DEFAULT_HEIGHT_DP = 40
internal const val WIDGET_MINIMAL_TIMER_MEDIUM_WIDTH_DP = 150
internal const val WIDGET_MINIMAL_TIMER_WIDE_WIDTH_DP = 220
internal const val WIDGET_MINIMAL_TIMER_MEDIUM_HEIGHT_DP = 80
internal const val WIDGET_MINIMAL_TIMER_TALL_HEIGHT_DP = 110

/** Kok dolgu 2dp: 40dp'lik varsayilan yukseklikte her dp puntodan duser. */
internal const val WIDGET_MINIMAL_TIMER_PADDING_DP = 2

/** Sabit yatay glif olcegi; sure uzayinca punto/olcek degismez. */
internal const val WIDGET_MINIMAL_TIMER_TEXT_SCALE_X = 0.75f

internal val minimalTimerSizeSpec = WidgetSizeSpec(
    WIDGET_MINIMAL_TIMER_DEFAULT_WIDTH_DP,
    WIDGET_MINIMAL_TIMER_DEFAULT_HEIGHT_DP,
    WIDGET_MINIMAL_TIMER_MEDIUM_WIDTH_DP,
    WIDGET_MINIMAL_TIMER_WIDE_WIDTH_DP,
    WIDGET_MINIMAL_TIMER_MEDIUM_HEIGHT_DP,
    WIDGET_MINIMAL_TIMER_TALL_HEIGHT_DP,
)

/**
 * Genislik merdiveni. Kirpma modeli WP-699 ile ayni: karakter genisligi
 * `0.60 x punto`, 8dp emniyet payi.
 *
 * `NARROW` sinifi 40dp'den 149dp'ye uzandigi icin tek basina yeterli degildir:
 * 1x1 ve 2x1 ayni puntoyu alir. WP-728 bu araligi gercek kutu genisligiyle
 * iki sabit basamaga ayirir. Minimal layout'un 0.75 yatay glif olcegiyle:
 *   1x1  70dp / 8 karakter: 16sp -> 57.6dp (kullanilabilir 58dp)
 *   2x1 110dp / 8 karakter: 21sp -> 75.6dp (kullanilabilir 98dp)
 *   3x2 150dp / 8 karakter: 28sp -> 100.8dp (kullanilabilir 138dp)
 *   4x2 220dp / 8 karakter: 38sp -> 136.8dp (kullanilabilir 208dp)
 */
internal val minimalTimerTypography = SpRamp(21f, 28f, 38f)

/** Gercek 1x1 genisligi icin ayri ve okunur alt basamak. */
internal const val WIDGET_MINIMAL_TIMER_ONE_CELL_SP = 16f

/**
 * Yukseklik tavani. Genislik merdiveni tek basina yetmez: 4x1 gibi genis ama
 * 40dp yuksek bir kutuda 38sp'lik satir 49dp yer ister, kutuda 28dp vardir.
 *   SHORT  40dp:  40 - 2*2 - 8 = 28dp -> 28 / 1.30 = 21.5 -> 21sp
 *   MEDIUM 80dp:  80 - 2*2 - 8 = 68dp -> 52.3 -> 40sp (estetik tavan)
 *   TALL  110dp: 110 - 2*2 - 8 = 98dp -> 75.4 -> 60sp (estetik tavan)
 */
internal fun minimalTimerHeightCapSp(height: WidgetHeightClass): Float = when (height) {
    WidgetHeightClass.SHORT -> 21f
    WidgetHeightClass.MEDIUM -> 40f
    WidgetHeightClass.TALL -> 60f
}

/**
 * Boyuta bagli ama icerikten bagimsiz punto merdiveni.
 *
 * Onceki merdiven 40..149dp araligini tek sinif sayiyordu: 1x1 ve 2x1 ayni
 * 19sp'yi aliyordu. Ustelik 1x1 testi yalniz 5 karakteri olcuyor, calisan
 * sayacin 8 karakterlik `00:00:00` halini disarida birakiyordu. Sabit 0.75
 * yatay geometriyle 1x1'de 16sp'nin sekiz karakteri 57.6dp yer kaplar; yaygin
 * 70dp hucrede 2dp dolgu ve 8dp emniyet sonrasi kalan alan 58dp'dir.
 */
internal fun minimalTimerTimeSp(widthDp: Int, heightDp: Int): Float {
    val size = widgetSizeClass(minimalTimerSizeSpec, widthDp, heightDp)
    val widthSp = if (widthDp in 1 until WIDGET_MINIMAL_TIMER_DEFAULT_WIDTH_DP) {
        WIDGET_MINIMAL_TIMER_ONE_CELL_SP
    } else {
        minimalTimerTypography.of(size.width)
    }
    return minOf(widthSp, minimalTimerHeightCapSp(size.height))
}
