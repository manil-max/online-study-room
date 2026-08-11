package com.manilmax.online_study_room.widgets

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent

/**
 * Native taraftan (foreground servis / widget receiver) sayac widget'larini
 * tazelemek icin yardimci.
 *
 * 🔴 WP-718: liste **iki** saglayici tasir. `updatePeriodMillis=0` oldugu icin
 * bu yayin bir widget'in tek tazeleme yoludur; minimal sayac buraya
 * eklenmeseydi baslat/durdur sonrasi etiketi ve rengi sonsuza kadar bayat
 * kalirdi — ve hicbir derleme hatasi bunu soylemezdi.
 */
object TimerWidgets {
    private val providers = listOf(
        TimerWidgetProvider::class.java,
        MinimalTimerWidgetProvider::class.java,
    )

    fun updateAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context) ?: return
        providers.forEach { provider ->
            val ids = runCatching {
                manager.getAppWidgetIds(ComponentName(context, provider))
            }.getOrNull() ?: return@forEach
            if (ids.isEmpty()) return@forEach
            val intent = Intent(context, provider).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            context.sendBroadcast(intent)
        }
    }
}
