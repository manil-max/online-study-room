package com.manilmax.online_study_room.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * AlarmManager tetikleyicisi + boot/timezone yeniden planlama.
 *
 * FIRE → [AlarmRingActivity] (full-screen, USAGE_ALARM ses).
 * BOOT/TIMEZONE → mirror'dan reschedule.
 */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        Log.i(TAG, "onReceive action=$action")

        when (action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_TIME_CHANGED -> {
                // goAsync: boot'ta biraz daha zaman
                val pending = goAsync()
                try {
                    NativeAlarmScheduler.rescheduleFromMirror(context)
                } finally {
                    pending.finish()
                }
            }

            AlarmIds.ACTION_FIRE_ALARM,
            AlarmIds.ACTION_FIRE_TIMER -> {
                val kind = intent.getStringExtra(AlarmIds.EXTRA_KIND)
                    ?: if (action == AlarmIds.ACTION_FIRE_TIMER) {
                        AlarmIds.KIND_TIMER
                    } else {
                        AlarmIds.KIND_ALARM
                    }
                val id = intent.getStringExtra(AlarmIds.EXTRA_ID) ?: return
                val label = intent.getStringExtra(AlarmIds.EXTRA_LABEL)
                    ?: context.getString(com.manilmax.online_study_room.R.string.alarm_default_label)
                NativeAlarmScheduler.writePendingRing(context, kind, id, label)
                launchRing(context, intent, kind, id)
            }

            AlarmIds.ACTION_DISMISS -> {
                val kind = intent.getStringExtra(AlarmIds.EXTRA_KIND) ?: AlarmIds.KIND_ALARM
                val id = intent.getStringExtra(AlarmIds.EXTRA_ID) ?: return
                NativeAlarmScheduler.cancel(context, kind, id)
                context.sendBroadcast(
                    Intent(AlarmIds.ACTION_STOP_SOUND).setPackage(context.packageName),
                )
            }

            AlarmIds.ACTION_SNOOZE -> {
                val id = intent.getStringExtra(AlarmIds.EXTRA_ID) ?: return
                val label = intent.getStringExtra(AlarmIds.EXTRA_LABEL)
                    ?: context.getString(com.manilmax.online_study_room.R.string.alarm_default_label)
                val snoozeMin = intent.getIntExtra(AlarmIds.EXTRA_SNOOZE_MIN, 5).coerceIn(1, 60)
                val trigger = System.currentTimeMillis() + snoozeMin * 60_000L
                NativeAlarmScheduler.scheduleAlarm(
                    context,
                    id = id,
                    triggerAtMs = trigger,
                    label = label,
                    hour = intent.getIntExtra(AlarmIds.EXTRA_HOUR, 0),
                    minute = intent.getIntExtra(AlarmIds.EXTRA_MINUTE, 0),
                    crescendo = intent.getBooleanExtra(AlarmIds.EXTRA_CRESCENDO, true),
                    vibrate = intent.getBooleanExtra(AlarmIds.EXTRA_VIBRATE, true),
                    antiSnooze = intent.getBooleanExtra(AlarmIds.EXTRA_ANTI_SNOOZE, false),
                    snoozeMin = snoozeMin,
                )
                context.sendBroadcast(
                    Intent(AlarmIds.ACTION_STOP_SOUND).setPackage(context.packageName),
                )
            }
        }
    }

    private fun launchRing(context: Context, src: Intent, kind: String, id: String) {
        val ring = Intent(context, AlarmRingActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP,
            )
            putExtra(AlarmIds.EXTRA_KIND, kind)
            putExtra(AlarmIds.EXTRA_ID, id)
            putExtra(
                AlarmIds.EXTRA_LABEL,
                src.getStringExtra(AlarmIds.EXTRA_LABEL)
                    ?: context.getString(com.manilmax.online_study_room.R.string.alarm_default_label),
            )
            putExtra(AlarmIds.EXTRA_HOUR, src.getIntExtra(AlarmIds.EXTRA_HOUR, 0))
            putExtra(AlarmIds.EXTRA_MINUTE, src.getIntExtra(AlarmIds.EXTRA_MINUTE, 0))
            putExtra(
                AlarmIds.EXTRA_CRESCENDO,
                src.getBooleanExtra(AlarmIds.EXTRA_CRESCENDO, true),
            )
            putExtra(
                AlarmIds.EXTRA_VIBRATE,
                src.getBooleanExtra(AlarmIds.EXTRA_VIBRATE, true),
            )
            putExtra(
                AlarmIds.EXTRA_ANTI_SNOOZE,
                src.getBooleanExtra(AlarmIds.EXTRA_ANTI_SNOOZE, false),
            )
            putExtra(
                AlarmIds.EXTRA_SNOOZE_MIN,
                src.getIntExtra(AlarmIds.EXTRA_SNOOZE_MIN, 5),
            )
        }
        // KRİTİK: App kapalıyken startActivity çoğu OEM'de sessizce başarısız.
        // Her zaman fullScreenIntent bildirim + mümkünse Activity.
        AlarmNotificationFallback.show(context, ring)
        try {
            context.startActivity(ring)
        } catch (e: Exception) {
            Log.e(TAG, "startActivity ring failed (notif already shown)", e)
        }
    }

    companion object {
        private const val TAG = "AlarmReceiver"
    }
}
