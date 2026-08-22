package com.manilmax.online_study_room.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import com.manilmax.online_study_room.R
import es.antonborri.home_widget.HomeWidgetProvider

internal fun statsDetailVisible(height: WidgetHeightClass): Boolean =
    height != WidgetHeightClass.SHORT

internal fun statsStreakVisible(height: WidgetHeightClass): Boolean =
    height == WidgetHeightClass.TALL

/**
 * WP-730: baslik yalniz TALL kutuda cizilir. 2x2'lik (MEDIUM) kutunun dikey
 * butcesi olculdu: yuzde + cubuk + gun ozeti zaten 80dp'nin kullanilabilir
 * 64dp'sini doldurur. Baslik da eklenirse ya satirlar kirpilir ya da yuzde
 * okunmaz puntoya duser -- sahibin sikayet ettigi tam sey. Aritmetik
 * `WidgetSizeClassWp699Test.stats_hicbir_boyutta_kirpilmaz` icinde kurulur.
 */
internal fun statsTitleVisible(height: WidgetHeightClass): Boolean =
    height == WidgetHeightClass.TALL

/** Baslik puntosu: TALL kutuda bile 13sp'yi asmaz (dikey butce). */
internal fun statsTitleSp(size: WidgetSizeClass): Float =
    minOf(WidgetTypography.statsTitle.of(size.width), 13f)

/** Satir puntosu: gun ozeti + seri satiri 12sp tavaninda kalir. */
internal fun statsRowSp(size: WidgetSizeClass): Float =
    minOf(WidgetTypography.statsRow.of(size.width), 12f)

internal fun statsValueSp(size: WidgetSizeClass): Float =
    if (size.height == WidgetHeightClass.SHORT) {
        15f
    } else {
        minOf(WidgetTypography.statsValue.of(size.width), 24f)
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
        val strings = widgetLocalizedContext(context)
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.odak_stats_widget).apply {
                setContentDescription(
                    R.id.stats_widget_root,
                    strings.getString(R.string.cd_stats_widget),
                )
                val size = appWidgetManager.sizeClass(WidgetSizeSpecs.stats, widgetId)
                val percentText = widgetData.text(StudyWidgetKeys.DailyGoalPercent, "0%")
                val progress = percentText.removeSuffix("%").toIntOrNull()?.coerceIn(0, 100) ?: 0
                setTextViewText(
                    R.id.stats_widget_title,
                    strings.getString(R.string.widget_daily_goal),
                )
                setTextViewText(
                    R.id.stats_widget_today,
                    percentText,
                )
                setProgressBar(
                    R.id.stats_goal_progress,
                    WidgetDesign.PROGRESS_MAX,
                    WidgetDesign.barPercent(progress / 100.0),
                    false,
                )
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
                        strings.getString(R.string.widget_goal_detail_zero),
                    ),
                )
                setTextViewText(
                    R.id.stats_widget_streak,
                    widgetData.text(
                        StudyWidgetKeys.StatsStreak,
                        strings.getString(R.string.widget_streak_zero),
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
                setViewVisibility(
                    R.id.stats_widget_title,
                    if (statsTitleVisible(size.height)) View.VISIBLE else View.GONE,
                )
                applySp(R.id.stats_widget_title, statsTitleSp(size))
                applySp(R.id.stats_widget_today, statsValueSp(size))
                applySp(R.id.stats_widget_week, statsRowSp(size))
                applySp(R.id.stats_widget_streak, statsRowSp(size))
                applyRootPadding(
                    context,
                    R.id.stats_widget_root,
                    widgetRootPaddingDp(3, size.height),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
