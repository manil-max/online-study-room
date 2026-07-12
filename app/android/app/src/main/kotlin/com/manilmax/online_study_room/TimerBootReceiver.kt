package com.manilmax.online_study_room

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Android 15'te BOOT_COMPLETED içinden dataSync foreground service başlatmak
 * yasaktır. Bu receiver aktif timer bilgisini korur ve uygulamanın sonraki
 * açılışında Dart state store'unun güvenli biçimde restore etmesini işaretler.
 */
class TimerBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        if (prefs.contains("flutter.timer_active_started_at")) {
            prefs.edit().putBoolean("flutter.timer_restore_pending", true).apply()
        }
    }
}
