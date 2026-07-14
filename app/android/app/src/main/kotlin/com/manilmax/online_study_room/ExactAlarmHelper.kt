package com.manilmax.online_study_room

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import com.manilmax.online_study_room.alarm.AlarmIds
import com.manilmax.online_study_room.alarm.NativeAlarmScheduler
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

/**
 * Dart ↔ native: exact izin + zamanlama + TZ + mirror + pil/bildirim izinleri.
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
            "getLocalTimezoneId" -> {
                result.success(TimeZone.getDefault().id)
            }
            "getPermissionSnapshot" -> {
                result.success(permissionSnapshot(context))
            }
            "openBatteryOptimizationSettings" -> {
                openBatterySettings(context)
                result.success(true)
            }
            "openBatteryOptimizationManagementSettings" -> {
                openBatteryOptimizationManagementSettings(context)
                result.success(true)
            }
            "openNotificationSettings" -> {
                openNotificationSettings(context)
                result.success(true)
            }
            "openFullScreenIntentSettings" -> {
                openFullScreenSettings(context)
                result.success(true)
            }
            "scheduleAlarm" -> {
                val id = call.argument<String>("id") ?: return result.error("arg", "id", null)
                val triggerAtMs = (call.argument<Number>("triggerAtMs"))?.toLong()
                    ?: return result.error("arg", "triggerAtMs", null)
                NativeAlarmScheduler.scheduleAlarm(
                    context,
                    id = id,
                    triggerAtMs = triggerAtMs,
                    label = call.argument<String>("label") ?: "Alarm",
                    hour = call.argument<Number>("hour")?.toInt() ?: 0,
                    minute = call.argument<Number>("minute")?.toInt() ?: 0,
                    crescendo = call.argument<Boolean>("crescendo") ?: true,
                    vibrate = call.argument<Boolean>("vibrate") ?: true,
                    antiSnooze = call.argument<Boolean>("antiSnooze") ?: false,
                    snoozeMin = call.argument<Number>("snoozeMin")?.toInt() ?: 5,
                )
                result.success(true)
            }
            "scheduleTimer" -> {
                val id = call.argument<String>("id") ?: return result.error("arg", "id", null)
                val triggerAtMs = (call.argument<Number>("triggerAtMs"))?.toLong()
                    ?: return result.error("arg", "triggerAtMs", null)
                NativeAlarmScheduler.scheduleTimer(
                    context,
                    id = id,
                    triggerAtMs = triggerAtMs,
                    label = call.argument<String>("label") ?: "Timer",
                )
                result.success(true)
            }
            "cancel" -> {
                val id = call.argument<String>("id") ?: return result.error("arg", "id", null)
                val kind = call.argument<String>("kind") ?: AlarmIds.KIND_ALARM
                NativeAlarmScheduler.cancel(context, kind, id)
                result.success(true)
            }
            "rescheduleFromMirror" -> {
                NativeAlarmScheduler.rescheduleFromMirror(context)
                result.success(true)
            }
            "cancelAllFromMirror" -> {
                NativeAlarmScheduler.cancelAllFromMirror(context)
                result.success(true)
            }
            "previewRing" -> {
                val intent = Intent(context, com.manilmax.online_study_room.alarm.AlarmRingActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    putExtra(AlarmIds.EXTRA_KIND, AlarmIds.KIND_ALARM)
                    putExtra(AlarmIds.EXTRA_ID, call.argument<String>("id") ?: "preview")
                    putExtra(AlarmIds.EXTRA_LABEL, call.argument<String>("label") ?: "Önizleme")
                    putExtra(AlarmIds.EXTRA_HOUR, call.argument<Number>("hour")?.toInt() ?: 0)
                    putExtra(AlarmIds.EXTRA_MINUTE, call.argument<Number>("minute")?.toInt() ?: 0)
                    putExtra(AlarmIds.EXTRA_CRESCENDO, call.argument<Boolean>("crescendo") ?: true)
                    putExtra(AlarmIds.EXTRA_VIBRATE, call.argument<Boolean>("vibrate") ?: true)
                    putExtra(AlarmIds.EXTRA_ANTI_SNOOZE, call.argument<Boolean>("antiSnooze") ?: false)
                    putExtra(AlarmIds.EXTRA_SNOOZE_MIN, call.argument<Number>("snoozeMin")?.toInt() ?: 5)
                }
                // Önizlemede de notif + activity
                com.manilmax.online_study_room.alarm.AlarmNotificationFallback.show(context, intent)
                context.startActivity(intent)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    fun canScheduleExactAlarms(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return runCatching { am.canScheduleExactAlarms() }.getOrDefault(false)
    }

    fun permissionSnapshot(context: Context): Map<String, Any> {
        val notifications = if (Build.VERSION.SDK_INT >= 33) {
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
        val exact = canScheduleExactAlarms(context)
        val battery = isIgnoringBatteryOptimizations(context)
        val fullScreen = canUseFullScreenIntent(context)
        return mapOf(
            "notifications" to notifications,
            "exactAlarm" to exact,
            "batteryUnrestricted" to battery,
            "fullScreenIntent" to fullScreen,
            "allOk" to (notifications && exact && battery && fullScreen),
        )
    }

    private fun isIgnoringBatteryOptimizations(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(context.packageName)
    }

    private fun canUseFullScreenIntent(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < 34) return true
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return runCatching { nm.canUseFullScreenIntent() }.getOrDefault(true)
    }

    fun openExactAlarmSettings(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
            data = Uri.parse("package:${context.packageName}")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        runCatching { context.startActivity(intent) }
    }

    private fun openBatterySettings(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
            data = Uri.parse("package:${context.packageName}")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        runCatching { context.startActivity(intent) }.onFailure {
            val fallback = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            runCatching { context.startActivity(fallback) }
        }
    }

    /** Kullanıcının optimizasyon istisnasını geri de alabileceği sistem listesi. */
    private fun openBatteryOptimizationManagementSettings(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        runCatching { context.startActivity(intent) }.onFailure {
            openBatterySettings(context)
        }
    }

    private fun openNotificationSettings(context: Context) {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            }
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:${context.packageName}")
            }
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        runCatching { context.startActivity(intent) }
    }

    private fun openFullScreenSettings(context: Context) {
        if (Build.VERSION.SDK_INT >= 34) {
            val intent = Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).apply {
                data = Uri.parse("package:${context.packageName}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            runCatching { context.startActivity(intent) }.onFailure {
                openNotificationSettings(context)
            }
        } else {
            openNotificationSettings(context)
        }
    }
}
