package com.manilmax.online_study_room

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * WP-58: Kişisel alarm / timer planlama receiver iskeleti.
 *
 * Asıl zamanlama flutter_local_notifications + AlarmManager ile yapılır.
 * Bu receiver:
 *  - BOOT_COMPLETED / TIMEZONE_CHANGED sonrası Flutter'ın yeniden planlama
 *    tetiklemesi için log + opsiyonel broadcast bırakır.
 *  - Gelecekte native full-screen alarm Activity'ye köprü olur.
 */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        Log.i(TAG, "AlarmReceiver action=$action")
        when (action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_TIME_CHANGED -> {
                // flutter_local_notifications kendi boot receiver'ı ile
                // scheduled notification'ları yeniden kurar.
                // Ek yerel state gerekirse burada SharedPreferences okunur.
            }
            ACTION_ALARM_FIRE -> {
                val alarmId = intent.getStringExtra(EXTRA_ALARM_ID)
                Log.i(TAG, "Alarm fire id=$alarmId")
            }
        }
    }

    companion object {
        private const val TAG = "AlarmReceiver"
        const val ACTION_ALARM_FIRE = "com.manilmax.online_study_room.ACTION_ALARM_FIRE"
        const val EXTRA_ALARM_ID = "alarm_id"
    }
}
