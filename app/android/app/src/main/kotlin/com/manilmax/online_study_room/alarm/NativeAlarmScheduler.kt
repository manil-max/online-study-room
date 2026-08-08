package com.manilmax.online_study_room.alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import org.json.JSONArray
import org.json.JSONObject

/**
 * Geçmişte kalmış bir tetik bulunduğunda ne yapılacağı (WP-557, Hata 2).
 */
enum class PastTriggerAction {
    /** Tetik hâlâ gelecekte — normal kur. */
    SCHEDULE,

    /** Gerçekten kaçırılmış (pencere içinde) — hemen çal. */
    FIRE_NOW,

    /** Pencere dışında kalmış "hayalet" — çalma, bir sonrakine kur. */
    RESCHEDULE_SILENTLY,
}

/**
 * Kaçırılmış alarm penceresi: bu süreden daha eski bir tetik artık
 * "kaçırılmış alarm" değildir.
 *
 * WP-557 (Hata 2): pencere yokken mirror'da duran her geçmiş `triggerAtMs`
 * kaçırılmış sayılıyordu. 07:00 alarmı çalıp kapatıldıktan sonra kayıt
 * tazelenmediği için, kullanıcı 14:30'da uygulamayı açtığında tam ekran
 * alarm + siren yeniden geliyordu (odak uygulaması alarm çalıyor).
 */
const val MISSED_TRIGGER_WINDOW_MS: Long = 15 * 60 * 1000L

/**
 * Saf karar fonksiyonu — `AlarmManager`/`Context` gerektirmez, JVM'de sınanır.
 */
fun pastTriggerAction(
    triggerAtMs: Long,
    nowMs: Long,
    windowMs: Long = MISSED_TRIGGER_WINDOW_MS,
): PastTriggerAction = when {
    triggerAtMs > nowMs -> PastTriggerAction.SCHEDULE
    nowMs - triggerAtMs <= windowMs -> PastTriggerAction.FIRE_NOW
    else -> PastTriggerAction.RESCHEDULE_SILENTLY
}

/**
 * Dart `AlarmScheduler.nextFire` kuralının native ikizi (WP-557, Hata 1).
 *
 * Tekrarlayan alarmın uygulama **hiç açılmadan** çalmaya devam edebilmesi
 * için bir sonraki occurrence'ın native tarafta hesaplanabilmesi şart:
 * FIRE anında PendingIntent tükenir ve Dart tarafı çalışmıyordur.
 *
 * Kurallar (Dart ile birebir):
 * - [dateYmd] doluysa yalnız o gün; geçmişse `null` (tekrar yok).
 * - [days] boşsa: bugün saat geçtiyse yarın (günlük yuvarlanma).
 * - [days] doluysa ISO hafta günü (1=Pzt … 7=Paz) eşleşen en yakın gelecek.
 * - [skipNextOnYmd] o takvim günündeki occurrence'ı atlatır.
 *
 * @param afterMs bu andan **kesinlikle sonraki** occurrence aranır.
 * @return epoch ms, ya da bir daha çalmayacaksa `null`.
 */
fun nextOccurrenceMs(
    hour: Int,
    minute: Int,
    days: List<Int> = emptyList(),
    dateYmd: String? = null,
    skipNextOnYmd: String? = null,
    afterMs: Long,
    zoneId: ZoneId = ZoneId.systemDefault(),
): Long? {
    if (hour !in 0..23 || minute !in 0..59) return null
    val today = Instant.ofEpochMilli(afterMs).atZone(zoneId).toLocalDate()

    fun at(date: LocalDate): Long =
        date.atTime(hour, minute).atZone(zoneId).toInstant().toEpochMilli()

    fun skipped(date: LocalDate): Boolean =
        skipNextOnYmd != null && skipNextOnYmd == date.toString()

    // Tek tarihli alarm — tekrar yok.
    if (dateYmd != null) {
        val date = runCatching { LocalDate.parse(dateYmd) }.getOrNull() ?: return null
        if (skipped(date)) return null
        val candidate = at(date)
        return if (candidate > afterMs) candidate else null
    }

    // Gün listesi yok → günlük yuvarlanma (Dart: "tek seferlik" dalı).
    if (days.isEmpty()) {
        var candidate = today
        if (at(candidate) <= afterMs) candidate = candidate.plusDays(1)
        if (skipped(candidate)) candidate = candidate.plusDays(1)
        return at(candidate)
    }

    val wanted = days.toSet()
    for (offset in 0 until 14) {
        val day = today.plusDays(offset.toLong())
        if (day.dayOfWeek.value !in wanted) continue
        val candidate = at(day)
        if (candidate <= afterMs) continue
        if (skipped(day)) continue
        return candidate
    }
    return null
}

/**
 * Kişisel alarm + multi-timer için tek native zamanlayıcı.
 *
 * - Exact when allowed; aksi halde setAndAllowWhileIdle (API 23+)
 * - Boot/timezone sonrası [rescheduleFromMirror] tüm aktif kayıtları yeniden kurar
 * - FIRE anında [advanceAfterFire] bir sonraki occurrence'ı kurar (WP-557)
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
        setExactWithContext(
            context, am, triggerAtMs, pi,
            kind = AlarmIds.KIND_ALARM,
            id = id,
            label = label,
            hour = hour,
            minute = minute,
        )
        Log.i(TAG, "scheduleAlarm id=$id at=$triggerAtMs")
    }

    private fun scheduleAlarm(context: Context, a: MirrorAlarm, triggerAtMs: Long) {
        scheduleAlarm(
            context,
            id = a.id,
            triggerAtMs = triggerAtMs,
            label = a.label,
            hour = a.hour,
            minute = a.minute,
            crescendo = a.crescendo,
            vibrate = a.vibrate,
            antiSnooze = a.antiSnooze,
            snoozeMin = a.snoozeMin,
        )
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
        setExactWithContext(
            context, am, triggerAtMs, pi,
            kind = AlarmIds.KIND_TIMER,
            id = id,
            label = label,
            hour = 0,
            minute = 0,
        )
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
     * WP-557 (Hata 1): tetik anında **bir sonraki** occurrence'ı kur.
     *
     * Öncesi: FIRE dalı yalnız çalıp bırakıyordu. PendingIntent tüketilir,
     * "Kapat" da onu iptal ederdi; Pzt-Cum 07:00 alarmı bir kez çalıp bir
     * daha asla kurulmuyordu (kullanıcı alarmı kapatıp açana kadar).
     *
     * Mirror kaydı da burada tüketilir: `triggerAtMs` ileri alınır, böylece
     * aynı geçmiş tetik [rescheduleFromMirror] tarafından ikinci kez
     * "kaçırılmış alarm" sanılmaz.
     *
     * @return kurulan yeni tetik, ya da bir daha çalmayacaksa `null`.
     */
    fun advanceAfterFire(context: Context, kind: String, id: String): Long? {
        val prefs = context.getSharedPreferences(AlarmIds.PREFS, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()

        if (kind == AlarmIds.KIND_TIMER) {
            val timers = parseTimers(prefs.getString(AlarmIds.MIRROR_TIMERS, null))
            writeTimers(context, timers.filterNot { it.id == id })
            return null
        }

        val all = parseAlarms(prefs.getString(AlarmIds.MIRROR_ALARMS, null))
        val current = all.firstOrNull { it.id == id }
        if (current == null) {
            Log.w(TAG, "advanceAfterFire: mirror kaydı yok id=$id")
            return null
        }
        val next = nextOccurrenceMs(
            hour = current.hour,
            minute = current.minute,
            days = current.days,
            dateYmd = current.dateYmd,
            skipNextOnYmd = current.skipNextOnYmd,
            afterMs = now,
        )
        if (next == null) {
            writeAlarms(context, all.filterNot { it.id == id })
            cancel(context, AlarmIds.KIND_ALARM, id)
            Log.i(TAG, "advanceAfterFire: sonraki occurrence yok id=$id")
            return null
        }
        writeAlarms(context, all.map { if (it.id == id) it.copy(triggerAtMs = next) else it })
        scheduleAlarm(context, current, next)
        Log.i(TAG, "advanceAfterFire id=$id next=$next")
        return next
    }

    /**
     * WP-557 (Hata 1): "Kapat" yalnız çalan alarmı susturur.
     *
     * Öncesi: [cancel] PendingIntent'i tamamen iptal ediyordu — FIRE anında
     * kurulan **bir sonraki** occurrence da onunla birlikte siliniyordu
     * (aynı (kind,id) tek PendingIntent kullanır).
     */
    fun dismiss(context: Context, kind: String, id: String) {
        cancel(context, kind, id)
        if (kind != AlarmIds.KIND_ALARM) return
        val prefs = context.getSharedPreferences(AlarmIds.PREFS, Context.MODE_PRIVATE)
        val entry = parseAlarms(prefs.getString(AlarmIds.MIRROR_ALARMS, null))
            .firstOrNull { it.id == id } ?: return
        if (!entry.active) return
        if (entry.triggerAtMs <= System.currentTimeMillis()) return
        scheduleAlarm(context, entry, entry.triggerAtMs)
        Log.i(TAG, "dismiss: sonraki occurrence korundu id=$id at=${entry.triggerAtMs}")
    }

    /**
     * Boot / timezone / TIME_CHANGED: mirror JSON'dan gelecek tetikleri yeniden kur.
     *
     * WP-557: geçmiş tetik artık körlemesine çaldırılmaz — yalnız
     * [MISSED_TRIGGER_WINDOW_MS] içindeki gerçek kaçırma çalar, daha eskisi
     * sessizce bir sonraki occurrence'a kurulur ([pastTriggerAction]).
     *
     * @param markPending yalnız boot/timezone yayınından çağrıldığında `true`.
     *   Dart `rescheduleFromMirror` kanalından gelen çağrı bayrağı **basmaz**;
     *   basarsa bayrak her açılışta yeniden doğar ve döngüye girer.
     */
    fun rescheduleFromMirror(context: Context, markPending: Boolean = false) {
        val prefs = context.getSharedPreferences(AlarmIds.PREFS, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()

        val keptAlarms = mutableListOf<MirrorAlarm>()
        parseAlarms(prefs.getString(AlarmIds.MIRROR_ALARMS, null)).forEach { a ->
            if (!a.active) {
                cancel(context, AlarmIds.KIND_ALARM, a.id)
                keptAlarms.add(a)
                return@forEach
            }
            val action = pastTriggerAction(a.triggerAtMs, now)
            if (action == PastTriggerAction.FIRE_NOW) {
                // Kaçırılmış alarm: kullanıcı kaçırmasın.
                fireNow(context, a)
            }
            if (action == PastTriggerAction.SCHEDULE) {
                scheduleAlarm(context, a, a.triggerAtMs)
                keptAlarms.add(a)
                return@forEach
            }
            // FIRE_NOW ve RESCHEDULE_SILENTLY: kaydı tüket, bir sonrakine kur.
            val next = nextOccurrenceMs(
                hour = a.hour,
                minute = a.minute,
                days = a.days,
                dateYmd = a.dateYmd,
                skipNextOnYmd = a.skipNextOnYmd,
                afterMs = now,
            )
            if (next == null) {
                cancel(context, AlarmIds.KIND_ALARM, a.id)
            } else {
                scheduleAlarm(context, a, next)
                keptAlarms.add(a.copy(triggerAtMs = next))
            }
        }
        writeAlarms(context, keptAlarms)

        val keptTimers = mutableListOf<MirrorTimer>()
        parseTimers(prefs.getString(AlarmIds.MIRROR_TIMERS, null)).forEach { t ->
            when (pastTriggerAction(t.endsAtMs, now)) {
                PastTriggerAction.SCHEDULE -> {
                    scheduleTimer(context, t.id, t.endsAtMs, t.label)
                    keptTimers.add(t)
                }
                // Süre az önce dolmuş — bitiş UI'ı; kayıt tüketilir.
                PastTriggerAction.FIRE_NOW -> fireTimerNow(context, t)
                // Saatler önce dolmuş: uygulamayı açmak bitiş ekranı açmasın.
                PastTriggerAction.RESCHEDULE_SILENTLY ->
                    cancel(context, AlarmIds.KIND_TIMER, t.id)
            }
        }
        writeTimers(context, keptTimers)

        if (markPending) {
            prefs.edit().putBoolean(AlarmIds.RESCHEDULE_PENDING, true).apply()
        }
        Log.i(TAG, "rescheduleFromMirror done markPending=$markPending")
    }

    private fun fireNow(context: Context, a: MirrorAlarm) {
        val ring = Intent(context, AlarmRingActivity::class.java).apply {
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
        // App kapalıyken Activity tek başına yetmez: her zaman fullScreen notif.
        AlarmNotificationFallback.show(context, ring)
        runCatching { context.startActivity(ring) }
    }

    private fun fireTimerNow(context: Context, t: MirrorTimer) {
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
        runCatching { context.startActivity(intent) }
    }

    /**
     * Saat uygulaması kalitesi: [AlarmManager.setAlarmClock] Doze'da
     * ertelenmez; status bar'da yaklaşan alarm gösterir.
     * Exact izni yoksa bile setAndAllowWhileIdle dener (asla sessiz yutma).
     */
    private fun setExactWithContext(
        context: Context,
        am: AlarmManager,
        triggerAtMs: Long,
        pi: PendingIntent,
        kind: String,
        id: String,
        label: String,
        hour: Int,
        minute: Int,
    ) {
        val showIntent = Intent(context, AlarmRingActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            putExtra(AlarmIds.EXTRA_KIND, kind)
            putExtra(AlarmIds.EXTRA_ID, id)
            putExtra(AlarmIds.EXTRA_LABEL, label)
            putExtra(AlarmIds.EXTRA_HOUR, hour)
            putExtra(AlarmIds.EXTRA_MINUTE, minute)
        }
        val showPi = PendingIntent.getActivity(
            context,
            AlarmIds.requestCode(kind, id) + 9000,
            showIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val canExact = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            runCatching { am.canScheduleExactAlarms() }.getOrDefault(false)
        } else {
            true
        }

        // 1) setAlarmClock — en güvenilir (saat uygulaması API'si)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                am.setAlarmClock(AlarmManager.AlarmClockInfo(triggerAtMs, showPi), pi)
                Log.i(TAG, "setAlarmClock ok id=$id at=$triggerAtMs")
                return
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "setAlarmClock SecurityException, fallback", e)
        } catch (e: Exception) {
            Log.w(TAG, "setAlarmClock failed, fallback", e)
        }

        // 2) exact while idle
        try {
            if (canExact && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
                Log.i(TAG, "setExactAndAllowWhileIdle ok id=$id")
                return
            }
            if (canExact) {
                @Suppress("DEPRECATION")
                am.setExact(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
                return
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "exact denied, inexact fallback", e)
        } catch (e: Exception) {
            Log.w(TAG, "exact failed", e)
        }

        // 3) inexact — en azından bir şey kurulsun (sessiz yutma YOK)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
            } else {
                am.set(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
            }
            Log.i(TAG, "inexact schedule id=$id")
        } catch (e: Exception) {
            Log.e(TAG, "ALL schedule paths failed id=$id", e)
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
        /** WP-557: ISO hafta günleri (1=Pzt … 7=Paz). Boş = günlük yuvarlanma. */
        val days: List<Int> = emptyList(),
        /** WP-557: yalnız bu takvim gününde çalan alarm (`yyyy-MM-dd`). */
        val dateYmd: String? = null,
        /** WP-557: bu takvim günündeki occurrence atlanır (`yyyy-MM-dd`). */
        val skipNextOnYmd: String? = null,
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
                            days = parseDays(o.optJSONArray("days")),
                            dateYmd = parseYmd(o, "date"),
                            skipNextOnYmd = parseYmd(o, "skipNextOn"),
                        ),
                    )
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "parseAlarms failed", e)
            emptyList()
        }
    }

    private fun parseDays(arr: JSONArray?): List<Int> {
        if (arr == null) return emptyList()
        return (0 until arr.length()).mapNotNull { i ->
            arr.optInt(i, 0).takeIf { it in 1..7 }
        }
    }

    /** Dart ISO8601 gönderir (`2026-08-12T00:00:00.000`); takvim günü yeterli. */
    private fun parseYmd(o: JSONObject, key: String): String? {
        if (o.isNull(key)) return null
        val raw = o.optString(key, "")
        if (raw.length < 10) return null
        return raw.substring(0, 10)
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

    /** Native tarafın mirror'ı ilerletmesi (WP-557). Dart açıldığında üzerine yazar. */
    private fun writeAlarms(context: Context, list: List<MirrorAlarm>) {
        val arr = JSONArray()
        list.forEach { a ->
            arr.put(
                JSONObject()
                    .put("id", a.id)
                    .put("active", a.active)
                    .put("triggerAtMs", a.triggerAtMs)
                    .put("label", a.label)
                    .put("hour", a.hour)
                    .put("minute", a.minute)
                    .put("crescendo", a.crescendo)
                    .put("vibrate", a.vibrate)
                    .put("antiSnooze", a.antiSnooze)
                    .put("snoozeMin", a.snoozeMin)
                    .put("days", JSONArray(a.days))
                    .put("date", a.dateYmd ?: JSONObject.NULL)
                    .put("skipNextOn", a.skipNextOnYmd ?: JSONObject.NULL),
            )
        }
        context.getSharedPreferences(AlarmIds.PREFS, Context.MODE_PRIVATE)
            .edit().putString(AlarmIds.MIRROR_ALARMS, arr.toString()).apply()
    }

    private fun writeTimers(context: Context, list: List<MirrorTimer>) {
        val arr = JSONArray()
        list.forEach { t ->
            arr.put(
                JSONObject()
                    .put("id", t.id)
                    .put("label", t.label)
                    .put("endsAtMs", t.endsAtMs),
            )
        }
        context.getSharedPreferences(AlarmIds.PREFS, Context.MODE_PRIVATE)
            .edit().putString(AlarmIds.MIRROR_TIMERS, arr.toString()).apply()
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
