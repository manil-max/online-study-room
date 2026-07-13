package com.manilmax.online_study_room

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * WP-58: Android 12+ exact alarm izin durumu ve ayar ekranı.
 *
 * Flutter tarafı önce flutter_local_notifications API'sini dener;
 * bu kanal yedek / tutarlı native kaynaktır.
 */
object ExactAlarmHelper {
    const val CHANNEL = "com.manilmax.online_study_room/exact_alarm"

    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "canScheduleExactAlarms" -> {
                result.success(canScheduleExactAlarms(context))
            }
            "requestExactAlarmsPermission" -> {
                openExactAlarmSettings(context)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    fun canScheduleExactAlarms(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return am.canScheduleExactAlarms()
    }

    fun openExactAlarmSettings(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
            data = Uri.parse("package:${context.packageName}")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        runCatching { context.startActivity(intent) }
    }
}
