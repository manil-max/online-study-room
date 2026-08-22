package com.manilmax.online_study_room.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import com.manilmax.online_study_room.R
import es.antonborri.home_widget.HomeWidgetProvider

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
