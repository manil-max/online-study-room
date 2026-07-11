package com.manilmax.online_study_room.widgets

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import es.antonborri.home_widget.HomeWidgetBackgroundIntent

/**
 * Widget veya bildirim üzerinden gelen zamanlayıcı (sayaç) başlatma/durdurma
 * eylemlerini yakalayan BroadcastReceiver.
 *
 * Flutter'ın uyandırılması ve Dart kodunun arka planda çalıştırılabilmesi için
 * home_widget paketinin HomeWidgetBackgroundReceiver'ına delege eder.
 */
class TimerActionReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_TOGGLE_TIMER = "com.manilmax.online_study_room.ACTION_TOGGLE_TIMER"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_TOGGLE_TIMER) {
            // home_widget 0.9.3: arka plan Dart callback'ini tetiklemenin resmi
            // yolu HomeWidgetBackgroundIntent.getBroadcast(...). Bu, dogru action
            // ("...action.BACKGROUND") ve hedef (HomeWidgetBackgroundReceiver) ile
            // hazir bir PendingIntent dondurur; biz sadece send() ederiz.
            HomeWidgetBackgroundIntent
                .getBroadcast(context, Uri.parse("homeWidget://timer/toggle"))
                .send()
        }
    }
}
