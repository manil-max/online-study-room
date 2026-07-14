package com.manilmax.online_study_room.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import com.manilmax.online_study_room.R
import es.antonborri.home_widget.HomeWidgetProvider

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

private fun AppWidgetManager.isCompact(context: Context, widgetId: Int): Boolean {
    val options = getAppWidgetOptions(widgetId)
    val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 110)
    val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 110)
    return width < 150 || height < 110
}

private fun openAppPendingIntent(context: Context, requestCode: Int) =
    android.app.PendingIntent.getActivity(
        context,
        requestCode,
        context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            ?: Intent(),
        android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE,
    )

class TimerWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.odak_timer_widget).apply {
                val compact = appWidgetManager.isCompact(context, widgetId)
                val appPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                // Epoch-millis anahtarı (native servis yazar) string ISO'dan daha
                // güvenilir; yoksa eski string anahtarından geri düş.
                val startMillis = appPrefs.getLong("flutter.timer_active_started_at_ms", 0L)
                    .takeIf { it > 0L }
                    ?: appPrefs.getString("flutter.timer_active_started_at", null)
                        ?.let { runCatching { java.time.Instant.parse(it).toEpochMilli() }.getOrNull() }
                val mode = appPrefs.getString("flutter.timer_active_mode", null)
                val isRunning = startMillis != null
                // Sade tasarım: yalnız akan saat + tek düğme (başlık/durum yazısı yok).
                // Chronometer yalnız kronometre modunda anlamlıdır. Geri sayım
                // ve Pomodoro'da Flutter'ın son olay anında yazdığı süre sabit
                // gösterilir; yanlış yönde akan native sayaç gösterilmez.
                if (isRunning && mode == "stopwatch") {
                    val base = SystemClock.elapsedRealtime() - (System.currentTimeMillis() - startMillis!!)
                    setChronometer(R.id.timer_widget_elapsed, base, null, true)
                } else {
                    setChronometer(R.id.timer_widget_elapsed, SystemClock.elapsedRealtime(), "00:00:00", false)
                }
                // Tek düğme sayacı çalışıyorsa Durdur, duruyorsa Başlat yapar
                // (native servise gider; app kapalıyken de çalışır).
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
                setOnClickPendingIntent(
                    R.id.timer_widget_root,
                    openAppPendingIntent(context, 10 + widgetId),
                )
                setViewVisibility(
                    R.id.timer_widget_elapsed,
                    if (compact) View.GONE else View.VISIBLE,
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

class StudyStatsWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.odak_stats_widget).apply {
                val compact = appWidgetManager.isCompact(context, widgetId)
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
                    openAppPendingIntent(context, 20 + widgetId),
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
                setViewVisibility(R.id.stats_widget_week, if (compact) View.GONE else View.VISIBLE)
                setViewVisibility(R.id.stats_widget_streak, if (compact) View.GONE else View.VISIBLE)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

class GroupLeaderboardWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views =
                RemoteViews(context.packageName, R.layout.odak_leaderboard_widget).apply {
                    val compact = appWidgetManager.isCompact(context, widgetId)
                    setTextViewText(
                        R.id.leaderboard_widget_title,
                        widgetData.text(
                            StudyWidgetKeys.LeaderboardTitle,
                            context.getString(R.string.widget_leaderboard_title),
                        ),
                    )
                    setTextViewText(
                        R.id.leaderboard_widget_row_1,
                        if (compact) {
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
                        openAppPendingIntent(context, 30 + widgetId),
                    )
                    setTextViewText(
                        R.id.leaderboard_widget_row_2,
                        widgetData.text(StudyWidgetKeys.LeaderboardRow2, "-"),
                    )
                    setTextViewText(
                        R.id.leaderboard_widget_row_3,
                        widgetData.text(StudyWidgetKeys.LeaderboardRow3, "-"),
                    )
                    setViewVisibility(R.id.leaderboard_widget_row_2, if (compact) View.GONE else View.VISIBLE)
                    setViewVisibility(R.id.leaderboard_widget_row_3, if (compact) View.GONE else View.VISIBLE)
                }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

class GroupGoalWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.odak_group_goal_widget).apply {
                val compact = appWidgetManager.isCompact(context, widgetId)
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
                    openAppPendingIntent(context, 40 + widgetId),
                )
                setViewVisibility(
                    R.id.group_goal_widget_detail,
                    if (compact) View.GONE else View.VISIBLE,
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

/** Dijital saat — TextClock native akar; Flutter tick yok. */
class ClockWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.odak_clock_widget)
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
