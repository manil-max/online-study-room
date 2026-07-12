package com.manilmax.online_study_room.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent

/** Native, uygulamayı açmayan widget yenileme eylemi.
 *
 * Son Flutter olayında kaydedilen snapshot'ı hemen tekrar çizer. Uygulama
 * açıksa akış sağlayıcıları ayrıca yeni oturum/senkron/grup verisini yazar.
 */
class WidgetRefreshReceiver : BroadcastReceiver() {
    companion object {
        private const val ACTION_REFRESH =
            "com.manilmax.online_study_room.ACTION_REFRESH_WIDGETS"

        fun pendingIntent(context: Context, requestCode: Int): PendingIntent {
            val intent = Intent(context, WidgetRefreshReceiver::class.java).apply {
                action = ACTION_REFRESH
            }
            return PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_REFRESH) return

        val manager = AppWidgetManager.getInstance(context)
        listOf(StudyStatsWidgetProvider::class.java, GroupLeaderboardWidgetProvider::class.java)
            .forEach { provider ->
                val component = ComponentName(context, provider)
                val ids = manager.getAppWidgetIds(component)
                if (ids.isNotEmpty()) {
                    context.sendBroadcast(Intent(context, provider).apply {
                        action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                    })
                }
            }
    }
}
