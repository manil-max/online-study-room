package com.manilmax.online_study_room.widgets

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import es.antonborri.home_widget.HomeWidgetBackgroundReceiver

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
            val backgroundIntent = Intent(context, HomeWidgetBackgroundReceiver::class.java).apply {
                data = android.net.Uri.parse("homeWidget://timer/toggle")
                action = HomeWidgetBackgroundReceiver.ACTION_BACKGROUND
            }
            context.sendBroadcast(backgroundIntent)
        }
    }
}
