package com.manilmax.online_study_room.alarm

/**
 * SharedPreferences + Intent anahtarları (Flutter `shared_preferences` → `flutter.*`).
 */
object AlarmIds {
    const val PREFS = "FlutterSharedPreferences"

    /** Dart mirror: aktif alarm JSON dizisi. */
    const val MIRROR_ALARMS = "flutter.native_alarm_mirror_v1"

    /** Dart mirror: çalışan timer JSON dizisi. */
    const val MIRROR_TIMERS = "flutter.native_timer_mirror_v1"

    /** Boot sonrası Dart'ın reschedule etmesi için bayrak. */
    const val RESCHEDULE_PENDING = "flutter.clock_reschedule_pending"

    /** Son tetiklenen olay (Flutter cold-start okur). */
    const val PENDING_RING = "flutter.clock_pending_ring_v1"

    const val ACTION_FIRE_ALARM = "com.manilmax.online_study_room.ACTION_FIRE_ALARM"
    const val ACTION_FIRE_TIMER = "com.manilmax.online_study_room.ACTION_FIRE_TIMER"
    const val ACTION_DISMISS = "com.manilmax.online_study_room.ACTION_ALARM_DISMISS"
    const val ACTION_SNOOZE = "com.manilmax.online_study_room.ACTION_ALARM_SNOOZE"
    const val ACTION_STOP_SOUND = "com.manilmax.online_study_room.ACTION_ALARM_STOP_SOUND"

    const val EXTRA_ID = "id"
    const val EXTRA_KIND = "kind" // alarm | timer
    const val EXTRA_LABEL = "label"
    const val EXTRA_CRESCENDO = "crescendo"
    const val EXTRA_VIBRATE = "vibrate"
    const val EXTRA_ANTI_SNOOZE = "antiSnooze"
    const val EXTRA_SNOOZE_MIN = "snoozeMin"
    const val EXTRA_HOUR = "hour"
    const val EXTRA_MINUTE = "minute"

    const val KIND_ALARM = "alarm"
    const val KIND_TIMER = "timer"

    /** Request code alanını id hash ile üret (çakışmayı azalt). */
    fun requestCode(kind: String, id: String): Int {
        var h = 17
        h = 31 * h + kind.hashCode()
        h = 31 * h + id.hashCode()
        return h and 0x7fffffff
    }
}
