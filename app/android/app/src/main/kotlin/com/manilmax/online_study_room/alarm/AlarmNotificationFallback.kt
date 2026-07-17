package com.manilmax.online_study_room.alarm

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Activity başlatılamazsa (arka plan kısıtı) fullScreenIntent bildirim.
 * androidx bağımlılığı olmadan framework Notification API.
 */
object AlarmNotificationFallback {
    private const val CHANNEL = "odak_alarm_critical"
    private const val NOTIF_BASE = 71000

    fun show(context: Context, ringIntent: Intent) {
        ensureChannel(context)
        val id = ringIntent.getStringExtra(AlarmIds.EXTRA_ID) ?: "x"
        val label = ringIntent.getStringExtra(AlarmIds.EXTRA_LABEL)
            ?: context.getString(com.manilmax.online_study_room.R.string.alarm_default_label)
        val kind = ringIntent.getStringExtra(AlarmIds.EXTRA_KIND) ?: AlarmIds.KIND_ALARM
        val code = AlarmIds.requestCode(kind, id)

        val fullPi = PendingIntent.getActivity(
            context,
            code,
            ringIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val dismiss = Intent(context, AlarmReceiver::class.java).apply {
            action = AlarmIds.ACTION_DISMISS
            putExtras(ringIntent)
        }
        val dismissPi = PendingIntent.getBroadcast(
            context,
            code + 1,
            dismiss,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val snooze = Intent(context, AlarmReceiver::class.java).apply {
            action = AlarmIds.ACTION_SNOOZE
            putExtras(ringIntent)
        }
        val snoozePi = PendingIntent.getBroadcast(
            context,
            code + 2,
            snooze,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val title = if (kind == AlarmIds.KIND_TIMER) {
            context.getString(com.manilmax.online_study_room.R.string.timer_finished_title)
        } else {
            label
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

        @Suppress("DEPRECATION")
        val notif = builder
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(context.getString(com.manilmax.online_study_room.R.string.brand_name))
            .setCategory(Notification.CATEGORY_ALARM)
            .setOngoing(true)
            .setAutoCancel(false)
            .setFullScreenIntent(fullPi, true)
            .setContentIntent(fullPi)
            .addAction(
                Notification.Action.Builder(
                    null,
                    context.getString(com.manilmax.online_study_room.R.string.action_dismiss),
                    dismissPi,
                ).build(),
            )
            .addAction(
                Notification.Action.Builder(
                    null,
                    context.getString(com.manilmax.online_study_room.R.string.action_snooze),
                    snoozePi,
                ).build(),
            )
            .setPriority(Notification.PRIORITY_MAX)
            .build()

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        runCatching { nm.notify(NOTIF_BASE + (code % 10000), notif) }
    }

    fun cancel(context: Context, kind: String, id: String) {
        val code = AlarmIds.requestCode(kind, id)
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(NOTIF_BASE + (code % 10000))
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val ch = NotificationChannel(
            CHANNEL,
            context.getString(com.manilmax.online_study_room.R.string.alarm_channel_name),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = context.getString(com.manilmax.online_study_room.R.string.alarm_channel_desc)
            setBypassDnd(true)
            enableVibration(true)
        }
        nm.createNotificationChannel(ch)
    }
}
