package com.manilmax.online_study_room.alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/**
 * Kişisel alarm + multi-timer için tek native zamanlayıcı.
 *
 * - Exact when allowed; aksi halde setAndAllowWhileIdle (API 23+)
 * - Boot/timezone sonrası [rescheduleFromMirror] tüm aktif kayıtları yeniden kurar
 * - Çift çalma: aynı (kind,id) için tek PendingIntent (FLAG_UPDATE)
 */
object NativeAlarmScheduler {
    private const val TAG = "NativeAlarmScheduler"

    fun scheduleAlarm(
        context: Context,
        id: String,
        triggerAtMs: Long,
        label: String,
        hour: Int,
        minute: Int,
        crescendo: Boolean,
        vibrate: Boolean,
        antiSnooze: Boolean,
        snoozeMin: Int,
    ) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = pendingFire(
            context,
            kind = AlarmIds.KIND_ALARM,
            id = id,
            label = label,
            hour = hour,
            minute = minute,
            crescendo = crescendo,
            vibrate = vibrate,
            antiSnooze = antiSnooze,
            snoozeMin = snoozeMin,
        )
        setExact(am, triggerAtMs, pi)
        Log.i(TAG, "scheduleAlarm id=$id at=$triggerAtMs")
    }

    fun scheduleTimer(
        context: Context,
        id: String,
        triggerAtMs: Long,
        label: String,
    ) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = pendingFire(
            context,
            kind = AlarmIds.KIND_TIMER,
            id = id,
            label = label,
            hour = 0,
            minute = 0,
            crescendo = true,
            vibrate = true,
            antiSnooze = false,
            snoozeMin = 5,
        )
        setExact(am, triggerAtMs, pi)
        Log.i(TAG, "scheduleTimer id=$id at=$triggerAtMs")
    }

    fun cancel(context: Context, kind: String, id: String) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = pendingFire(
            context,
            kind = kind,
            id = id,
            label = "",
            hour = 0,
            minute = 0,
            crescendo = false,
            vibrate = false,
            antiSnooze = false,
            snoozeMin = 5,
        )
        am.cancel(pi)
        pi.cancel()
        Log.i(TAG, "cancel kind=$kind id=$id")
    }

    fun cancelAllFromMirror(context: Context) {
        val prefs = context.getSharedPreferences(AlarmIds.PREFS, Context.MODE_PRIVATE)
        parseAlarms(prefs.getString(AlarmIds.MIRROR_ALARMS, null)).forEach {
            cancel(context, AlarmIds.KIND_ALARM, it.id)
        }
        parseTimers(prefs.getString(AlarmIds.MIRROR_TIMERS, null)).forEach {
            cancel(context, AlarmIds.KIND_TIMER, it.id)
        }
    }

    /**
     * Boot / timezone / TIME_CHANGED: mirror JSON'dan gelecek tetikleri yeniden kur.
     * Geçmişte kalmış timer'lar hemen çalmaz; Dart reconcile bayrağı basılır.
     */
    fun rescheduleFromMirror(context: Context) {
        val prefs = context.getSharedPreferences(AlarmIds.PREFS, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()

        parseAlarms(prefs.getString(AlarmIds.MIRROR_ALARMS, null)).forEach { a ->
            if (!a.active) {
                cancel(context, AlarmIds.KIND_ALARM, a.id)
                return@forEach
            }
            val trigger = a.triggerAtMs
            if (trigger <= now) {
                // Kaçırılmış alarm: hemen çal (kullanıcı kaçırmasın)
                fireNow(context, a)
            } else {
                scheduleAlarm(
                    context,
                    id = a.id,
                    triggerAtMs = trigger,
                    label = a.label,
                    hour = a.hour,
                    minute = a.minute,
                    crescendo = a.crescendo,
                    vibrate = a.vibrate,
                    antiSnooze = a.antiSnooze,
                    snoozeMin = a.snoozeMin,
                )
            }
        }

        parseTimers(prefs.getString(AlarmIds.MIRROR_TIMERS, null)).forEach { t ->
            if (t.endsAtMs <= now) {
                // Süre dolmuş — hemen bitiş UI
                val intent = Intent(context, AlarmRingActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    putExtra(AlarmIds.EXTRA_KIND, AlarmIds.KIND_TIMER)
                    putExtra(AlarmIds.EXTRA_ID, t.id)
                    putExtra(AlarmIds.EXTRA_LABEL, t.label)
                    putExtra(AlarmIds.EXTRA_CRESCENDO, true)
                    putExtra(AlarmIds.EXTRA_VIBRATE, true)
                    putExtra(AlarmIds.EXTRA_ANTI_SNOOZE, false)
                    putExtra(AlarmIds.EXTRA_SNOOZE_MIN, 0)
                }
                context.startActivity(intent)
            } else {
                scheduleTimer(context, t.id, t.endsAtMs, t.label)
            }
        }

        prefs.edit().putBoolean(AlarmIds.RESCHEDULE_PENDING, true).apply()
        Log.i(TAG, "rescheduleFromMirror done")
    }

    private fun fireNow(context: Context, a: MirrorAlarm) {
        val intent = Intent(context, AlarmRingActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra(AlarmIds.EXTRA_KIND, AlarmIds.KIND_ALARM)
            putExtra(AlarmIds.EXTRA_ID, a.id)
            putExtra(AlarmIds.EXTRA_LABEL, a.label)
            putExtra(AlarmIds.EXTRA_HOUR, a.hour)
            putExtra(AlarmIds.EXTRA_MINUTE, a.minute)
            putExtra(AlarmIds.EXTRA_CRESCENDO, a.crescendo)
            putExtra(AlarmIds.EXTRA_VIBRATE, a.vibrate)
            putExtra(AlarmIds.EXTRA_ANTI_SNOOZE, a.antiSnooze)
            putExtra(AlarmIds.EXTRA_SNOOZE_MIN, a.snoozeMin)
        }
        context.startActivity(intent)
    }

    private fun setExact(am: AlarmManager, triggerAtMs: Long, pi: PendingIntent) {
        val canExact = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            am.canScheduleExactAlarms()
        } else {
            true
        }
        when {
            canExact && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
            }
            canExact -> {
                @Suppress("DEPRECATION")
                am.setExact(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
            }
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
            }
            else -> {
                am.set(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
            }
        }
    }

    private fun pendingFire(
        context: Context,
        kind: String,
        id: String,
        label: String,
        hour: Int,
        minute: Int,
        crescendo: Boolean,
        vibrate: Boolean,
        antiSnooze: Boolean,
        snoozeMin: Int,
    ): PendingIntent {
        val action = if (kind == AlarmIds.KIND_TIMER) {
            AlarmIds.ACTION_FIRE_TIMER
        } else {
            AlarmIds.ACTION_FIRE_ALARM
        }
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            this.action = action
            putExtra(AlarmIds.EXTRA_KIND, kind)
            putExtra(AlarmIds.EXTRA_ID, id)
            putExtra(AlarmIds.EXTRA_LABEL, label)
            putExtra(AlarmIds.EXTRA_HOUR, hour)
            putExtra(AlarmIds.EXTRA_MINUTE, minute)
            putExtra(AlarmIds.EXTRA_CRESCENDO, crescendo)
            putExtra(AlarmIds.EXTRA_VIBRATE, vibrate)
            putExtra(AlarmIds.EXTRA_ANTI_SNOOZE, antiSnooze)
            putExtra(AlarmIds.EXTRA_SNOOZE_MIN, snoozeMin)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getBroadcast(
            context,
            AlarmIds.requestCode(kind, id),
            intent,
            flags,
        )
    }

    data class MirrorAlarm(
        val id: String,
        val active: Boolean,
        val triggerAtMs: Long,
        val label: String,
        val hour: Int,
        val minute: Int,
        val crescendo: Boolean,
        val vibrate: Boolean,
        val antiSnooze: Boolean,
        val snoozeMin: Int,
    )

    data class MirrorTimer(
        val id: String,
        val label: String,
        val endsAtMs: Long,
    )

    fun parseAlarms(raw: String?): List<MirrorAlarm> {
        if (raw.isNullOrBlank()) return emptyList()
        return try {
            val arr = JSONArray(raw)
            buildList {
                for (i in 0 until arr.length()) {
                    val o = arr.getJSONObject(i)
                    add(
                        MirrorAlarm(
                            id = o.getString("id"),
                            active = o.optBoolean("active", true),
                            triggerAtMs = o.getLong("triggerAtMs"),
                            label = o.optString("label", "Alarm"),
                            hour = o.optInt("hour", 0),
                            minute = o.optInt("minute", 0),
                            crescendo = o.optBoolean("crescendo", true),
                            vibrate = o.optBoolean("vibrate", true),
                            antiSnooze = o.optBoolean("antiSnooze", false),
                            snoozeMin = o.optInt("snoozeMin", 5),
                        ),
                    )
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "parseAlarms failed", e)
            emptyList()
        }
    }

    fun parseTimers(raw: String?): List<MirrorTimer> {
        if (raw.isNullOrBlank()) return emptyList()
        return try {
            val arr = JSONArray(raw)
            buildList {
                for (i in 0 until arr.length()) {
                    val o = arr.getJSONObject(i)
                    add(
                        MirrorTimer(
                            id = o.getString("id"),
                            label = o.optString("label", "Timer"),
                            endsAtMs = o.getLong("endsAtMs"),
                        ),
                    )
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "parseTimers failed", e)
            emptyList()
        }
    }

    fun writePendingRing(context: Context, kind: String, id: String, label: String) {
        val prefs = context.getSharedPreferences(AlarmIds.PREFS, Context.MODE_PRIVATE)
        val o = JSONObject()
            .put("kind", kind)
            .put("id", id)
            .put("label", label)
            .put("at", System.currentTimeMillis())
        prefs.edit().putString(AlarmIds.PENDING_RING, o.toString()).apply()
    }
}
