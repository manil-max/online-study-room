package com.manilmax.online_study_room.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import com.manilmax.online_study_room.R
import es.antonborri.home_widget.HomeWidgetProvider

/** `HH:MM` — saatin cekirdek metninin karakter sayisi. */
internal const val WIDGET_CLOCK_TIME_CHARS = 5

/** K1 cekirdek glifi ve K3/K4 tarih satirindaki kucuk isaret (§4.3). */
internal const val WIDGET_CLOCK_GLYPH_DP = 24
internal const val WIDGET_CLOCK_MARK_DP = 12

// Satır görünürlüğü YÜKSEKLİK sınıfından türer. Saf tutuldu ki JVM testi
// kullanıcının gerçekten gördüğü dalı ölçebilsin.
internal fun clockDateVisible(height: WidgetHeightClass): Boolean =
    height != WidgetHeightClass.SHORT

/**
 * K1 (Kor): saatin cekirdegi SAYI degil GLIFtir - ay + yildiz
 * (`widget_ic_clock`).
 *
 * 🔴 Aritmetik, gorus degil: `HH:MM` bes karakterdir ve 40dp kutuda 4dp
 * dolguyla taban sikistirmadaki tavani
 * `widgetMaxSp(40, 4, 5, 0.85) = 9sp`tir. Anlam tasiyan metnin tabani
 * [WIDGET_MIN_TEXT_SP] = 11sp (§3.3), yani bes karakter o kutuya OKUNUR
 * bicimde girmiyor. §1.4 tam bu durum icin glif cekirdegi tanimlar.
 *
 * Bu bir kayip degil durust bir karardir: 1x1 bir saat widget'i zaten sistem
 * saatinin kopyasidir; oradaki deger MARKAdir, sayi degil. Bu yuzden glif
 * pasif `ink_dim` degil `flame` tonundadir - kartin uzerindeki tek isaret
 * odur ve kimligi o tasir (kart zeminine 8.19:1, AAA).
 *
 * Sayacin cekirdeginden farki: orada glife DUSMEK zorunlulugu canlilik
 * kaygisindan da geliyordu; burada saat `TextClock`tur ve kendi kendine akar,
 * yani K2'den itibaren sayi hem sigar hem canlidir.
 */
internal fun clockCoreIsGlyph(widthDp: Int): Boolean =
    widthDp in 1 until WIDGET_CLOCK_DEFAULT_WIDTH_DP

/** O kutuda cizilen cekirdegin KARAKTER sayisi; glif cekirdek 0 dondurur. */
internal fun clockCoreChars(widthDp: Int): Int =
    if (clockCoreIsGlyph(widthDp)) 0 else WIDGET_CLOCK_TIME_CHARS

internal fun clockTimeSp(size: WidgetSizeClass): Float {
    val base = WidgetTypography.clockTime.of(size.width)
    return when (size.height) {
        WidgetHeightClass.SHORT -> minOf(base, 18f)
        WidgetHeightClass.MEDIUM -> minOf(base, 26f)
        WidgetHeightClass.TALL -> base
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
                val dimensions = appWidgetManager.dimensions(WidgetSizeSpecs.clock, widgetId)
                val size = dimensions.sizeClass
                // WP-754: K1'de saatin YERINE ay+yildiz glifi cizilir; gerekce
                // `clockCoreIsGlyph`. Kart yaricapi da kademeye baglidir (§2.6).
                val coreIsGlyph = clockCoreIsGlyph(dimensions.widthDp)
                val dateVisible = !coreIsGlyph && clockDateVisible(size.height)
                setInt(
                    R.id.clock_widget_root,
                    "setBackgroundResource",
                    widgetCardBackground(size.height),
                )
                setViewVisibility(
                    R.id.clock_widget_glyph,
                    if (coreIsGlyph) View.VISIBLE else View.GONE,
                )
                setViewVisibility(
                    R.id.clock_widget_time,
                    if (coreIsGlyph) View.GONE else View.VISIBLE,
                )
                setViewVisibility(
                    R.id.clock_widget_date_row,
                    if (dateVisible) View.VISIBLE else View.GONE,
                )
                applySp(R.id.clock_widget_time, clockTimeSp(size))
                applySp(R.id.clock_widget_date, WidgetTypography.clockDate.of(size.width))
                // Glif markadir: `flame`. Tarih satirindaki kucuk isaret ise
                // yardimci metnin tonunda (`ink_dim`) durur - orada kimlik degil
                // ritim tasir ve tarihten daha yuksek sesli olmamalidir.
                setInt(
                    R.id.clock_widget_glyph,
                    "setColorFilter",
                    ContextCompat.getColor(context, R.color.widget_ember_flame),
                )
                setInt(
                    R.id.clock_widget_mark,
                    "setColorFilter",
                    ContextCompat.getColor(context, R.color.widget_ember_ink_dim),
                )
                applyRootPadding(
                    context,
                    R.id.clock_widget_root,
                    widgetRootPaddingDp(4, size.height),
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
