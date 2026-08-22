package com.manilmax.online_study_room.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import com.manilmax.online_study_room.R
import es.antonborri.home_widget.HomeWidgetProvider

internal fun groupGoalDetailVisible(height: WidgetHeightClass): Boolean =
    height != WidgetHeightClass.SHORT

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
        val strings = widgetLocalizedContext(context)
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.odak_group_goal_widget).apply {
                setContentDescription(
                    R.id.group_goal_widget_root,
                    strings.getString(R.string.cd_group_goal_widget),
                )
                val size = appWidgetManager.sizeClass(WidgetSizeSpecs.groupGoal, widgetId)
                val percentText = widgetData.text(StudyWidgetKeys.GroupGoalPercent, "0%")
                val progress = percentText.removeSuffix("%").toIntOrNull()?.coerceIn(0, 100) ?: 0
                setTextViewText(
                    R.id.group_goal_widget_title,
                    strings.getString(R.string.widget_group_goal),
                )
                setTextViewText(R.id.group_goal_widget_percent, percentText)
                val normalizedProgress = WidgetDesign.barPercent(progress / 100.0)
                setProgressBar(
                    R.id.group_goal_widget_progress,
                    WidgetDesign.PROGRESS_MAX,
                    WidgetDesign.arcPercent(normalizedProgress / 100.0),
                    false,
                )
                setTextViewText(
                    R.id.group_goal_widget_detail,
                    widgetData.text(
                        StudyWidgetKeys.GroupGoalDetail,
                        strings.getString(R.string.widget_join_group),
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
                    widgetRootPaddingDp(6, size.height),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
