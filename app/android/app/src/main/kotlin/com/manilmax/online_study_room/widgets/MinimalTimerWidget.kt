package com.manilmax.online_study_room.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import android.view.View
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
 * Tek gorunur oge cekirdektir; **tum yuzey** baslat/durdur'dur. 48dp'lik ayri
 * bir hap 1-2 hucrelik bir kutuda geriye okunur bir sayi icin yer birakmiyor
 * (olcum: `TimerWidgetWp718Test`). Hedefi kucultmek yerine yuzeyin tamamini
 * hedef yapmak, launcher'in gercek hucresi kadar (~70-85dp) buyuk bir dokunma
 * alani verir. Ayni karar sayac widget'inin en kucuk sinifinda da gecerlidir
 * (`timerControlsVisible`).
 *
 * ## WP-754 — akraba, ikiz degil
 * Sayac widget'iyla PAYLASILAN sey kimliktir: ayni ocak glifi
 * (`widget_ic_timer`), ayni `sans-serif-condensed` + `textScaleX` 0.85
 * tipografisi, ayni flame/ink_dim durum rengi. AYRISAN sey susmasidir: burada
 * hicbir kademede isaret, ayrac, hap, ders chip'i ya da yuzde yoktur - her
 * boyutta TAM OLARAK BIR oge cizilir (§1.2 kademe butcesinin en saf hali).
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
            val coreIsGlyph = minimalTimerCoreIsGlyph(widthDp)
            val size = widgetSizeClass(minimalTimerSizeSpec, widthDp, heightDp)
            val accent = ContextCompat.getColor(context, R.color.widget_ember_flame)
            val muted = ContextCompat.getColor(context, R.color.widget_ember_ink_dim)
            val ink = ContextCompat.getColor(context, R.color.widget_ember_ink)

            val views = RemoteViews(context.packageName, R.layout.odak_minimal_timer_widget).apply {
                setInt(
                    R.id.minimal_timer_widget_root,
                    "setBackgroundResource",
                    widgetCardBackground(size.height),
                )
                // WP-754: K1'de sayinin YERINE ocak glifi cizilir. Gerekce
                // `minimalTimerCoreIsGlyph` - ozeti: 40dp kutuda sekiz karakter
                // 11sp tabaninin altina duser, uc karaktere inmek ise canli
                // sayaci oldururdu (`Chronometer`in en kisa bicimi `MM:SS`).
                setViewVisibility(
                    R.id.minimal_timer_widget_glyph,
                    if (coreIsGlyph) View.VISIBLE else View.GONE,
                )
                setViewVisibility(
                    R.id.minimal_timer_widget_elapsed,
                    if (coreIsGlyph) View.GONE else View.VISIBLE,
                )
                setTextViewTextSize(
                    R.id.minimal_timer_widget_elapsed,
                    android.util.TypedValue.COMPLEX_UNIT_SP,
                    minimalTimerTimeSp(widthDp, heightDp),
                )
                // Calisiyor/duruyor ayrimi RENKLE yapilir: ikinci bir satir
                // eklemek widget'i "minimal" olmaktan cikarirdi. Cekirdek
                // hangi kademede olursa olsun ayni iki tonu kullanir; renk her
                // turda ACIKCA yazilir, yoksa onceki cizimden sizar.
                setTextColor(
                    R.id.minimal_timer_widget_elapsed,
                    if (isRunning) accent else ink,
                )
                setInt(
                    R.id.minimal_timer_widget_glyph,
                    "setColorFilter",
                    if (isRunning) accent else muted,
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
                // duyurur — glif kademesinde ekranda okunacak metin YOKTUR.
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

/**
 * Rakamlarin `textScaleX` degeri.
 *
 * 🔴 WP-754: 0.75 -> 0.85. Sayac widget'iyla AYNI kural (gerekce
 * [WIDGET_TIMER_TEXT_SCALE_X] KDoc'unda): 0.85 tasarim sisteminin tabanidir
 * (§7 madde 6) ve daraltmayi `sans-serif-condensed`in kendi glif formu yapar.
 * Bu sabit `odak_minimal_timer_widget.xml`deki `android:textScaleX` ile AYNI
 * SEYI soyler.
 */
internal const val WIDGET_MINIMAL_TIMER_TEXT_SCALE_X = 0.85f

/** K1 cekirdek glifi - sayac widget'iyla AYNI ocak (`widget_ic_timer`). */
internal const val WIDGET_MINIMAL_TIMER_GLYPH_DP = 24

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
 * `0.60 x punto`, 8dp emniyet payi, sonra §3.4 genislik butcesi.
 *
 * `NARROW` sinifi 40dp'den 149dp'ye uzandigi icin merdiven tek basina yeterli
 * degildir; kutu genisligi butce uzerinden ikinci bir kelime soyler
 * ([minimalTimerTimeSp]).
 */
internal val minimalTimerTypography = SpRamp(21f, 28f, 38f)

/**
 * K1 (Kor): cekirdek SAYI degil GLIFtir - sayac widget'iyla ayni karar ve ayni
 * gerekce ([timerCoreIsGlyph]). Ozeti: 40dp kutuda 2dp dolguyla sekiz
 * karakterin tavani `widgetMaxSp(40, 2, 8, 0.85) = 6sp` ve [WIDGET_MIN_TEXT_SP]
 * 11sp'dir; uc karaktere inmek ise genisligi cozup CANLILIGI oldururdu, cunku
 * RemoteViews'ta kendi kendine tiklayan tek gorunum `Chronometer`dir ve onun en
 * kisa bicimi `MM:SS`tir (`updatePeriodMillis=0`).
 */
internal fun minimalTimerCoreIsGlyph(widthDp: Int): Boolean =
    widthDp in 1 until WIDGET_MINIMAL_TIMER_DEFAULT_WIDTH_DP

/** O kutuda cizilen cekirdegin KARAKTER sayisi; glif cekirdek 0 dondurur. */
internal fun minimalTimerCoreChars(widthDp: Int): Int =
    if (minimalTimerCoreIsGlyph(widthDp)) 0 else WIDGET_TIMER_TIME_CHARS

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
 * Boyuta bagli ama ICERIKTEN bagimsiz punto: sure 00:00'dan 00:00:00'a gecince
 * punto degismez (WP-728 kurali korunuyor).
 *
 * 🔴 WP-754: merdiven ve yukseklik tavaninin yanina §3.4 GENISLIK butcesi
 * geldi. Yatay sikistirma tabana (0.85) cikinca eski sabit basamaklar bazi
 * kutularda kutuyu asiyordu; butce hangi kutuda neyin sigdigini tek yerden
 * soyler. Taban [WIDGET_MIN_TEXT_SP]'dir - K1'de sayi zaten cizilmez
 * ([minimalTimerCoreIsGlyph]) ama fonksiyon "cizilseydi ne olurdu" sorusuna
 * durust cevap verir.
 */
internal fun minimalTimerTimeSp(widthDp: Int, heightDp: Int): Float {
    val box = if (widthDp > 0) widthDp else WIDGET_MINIMAL_TIMER_DEFAULT_WIDTH_DP
    val size = widgetSizeClass(minimalTimerSizeSpec, widthDp, heightDp)
    val budget = widgetMaxSp(
        widthDp = box,
        paddingDp = WIDGET_MINIMAL_TIMER_PADDING_DP,
        chars = WIDGET_TIMER_TIME_CHARS,
        advanceScale = WIDGET_MINIMAL_TIMER_TEXT_SCALE_X,
    )
    val capped = minOf(
        minimalTimerTypography.of(size.width),
        minimalTimerHeightCapSp(size.height),
        budget,
    )
    return maxOf(capped, WIDGET_MIN_TEXT_SP)
}
