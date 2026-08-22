package com.manilmax.online_study_room.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import com.manilmax.online_study_room.R
import es.antonborri.home_widget.HomeWidgetProvider

// Satır görünürlüğü YÜKSEKLİK sınıfından türer. Saf tutuldu ki JVM testi
// kullanıcının gerçekten gördüğü dalı ölçebilsin.
internal fun clockDateVisible(height: WidgetHeightClass): Boolean =
    height != WidgetHeightClass.SHORT

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
                val size = appWidgetManager.sizeClass(WidgetSizeSpecs.clock, widgetId)
                applySp(R.id.clock_widget_time, clockTimeSp(size))
                applySp(R.id.clock_widget_date, WidgetTypography.clockDate.of(size.width))
                setViewVisibility(
                    R.id.clock_widget_date,
                    if (clockDateVisible(size.height)) View.VISIBLE else View.GONE,
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
