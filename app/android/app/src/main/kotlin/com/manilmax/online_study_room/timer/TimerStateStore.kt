package com.manilmax.online_study_room.timer

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.util.UUID

/**
 * WP-135: Sayaç durumu için tek yazıcı (SSOT prefs).
 *
 * Anahtarlar Flutter SharedPreferences ile aynı kalır (`flutter.*`).
 * Tüm yazımlar **senkron [SharedPreferences.Editor.commit]** — stop/start
 * asimetri (apply vs commit) widget/reconcile yarışını kapatır.
 */
object TimerStateStore {
    const val PREFS_NAME = "FlutterSharedPreferences"

    const val KEY_STARTED_AT = "flutter.timer_active_started_at"
    const val KEY_STARTED_AT_MS = "flutter.timer_active_started_at_ms"
    const val KEY_MODE = "flutter.timer_active_mode"
    const val KEY_PHASE = "flutter.timer_active_phase"
    const val KEY_CYCLE = "flutter.timer_active_cycle"
    const val KEY_SUBJECT = "flutter.timer_active_subject"
    const val KEY_FG_MODE = "flutter.timer_fg_mode"
    const val KEY_PENDING_INTERVALS = "flutter.timer_pending_intervals"
    const val KEY_LIVE_RUN_ID = "flutter.timer_active_live_run_id"
    const val KEY_LIVE_RUN_TOKEN = "flutter.timer_active_live_run_token"
    const val KEY_START_ORIGIN = "flutter.timer_active_start_origin"

    fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun isRunning(p: SharedPreferences): Boolean =
        p.contains(KEY_STARTED_AT) || p.getLong(KEY_STARTED_AT_MS, 0L) > 0L

    fun startedAtMs(p: SharedPreferences): Long =
        p.getLong(KEY_STARTED_AT_MS, 0L).takeIf { it > 0L }
            ?: p.getString(KEY_STARTED_AT, null)
                ?.let { runCatching { Instant.parse(it).toEpochMilli() }.getOrNull() }
            ?: 0L

    /** Çalışan sayaç durumunu atomik yazar (commit). */
    fun writeRunning(
        p: SharedPreferences,
        startedAtMs: Long,
        mode: String,
        phase: String,
        cycle: Int,
        subjectId: String,
        liveRunId: String = "",
        liveRunToken: String = "",
        startOrigin: String = "dart_app",
    ): Boolean {
        return p.edit()
            .putString(KEY_STARTED_AT, Instant.ofEpochMilli(startedAtMs).toString())
            .putLong(KEY_STARTED_AT_MS, startedAtMs)
            .putString(KEY_MODE, mode)
            .putString(KEY_PHASE, phase)
            .putInt(KEY_CYCLE, cycle)
            .putString(KEY_SUBJECT, subjectId)
            .putString(KEY_LIVE_RUN_ID, liveRunId)
            .putString(KEY_LIVE_RUN_TOKEN, liveRunToken)
            .putString(KEY_START_ORIGIN, startOrigin)
            .putString(KEY_FG_MODE, "running")
            .commit()
    }

    /**
     * Idle / sıfır: started_at kaldırılır, fg_mode=idle.
     * Chronometer 00:00:00 widget tarafında started_at yokken gösterilir.
     */
    fun writeIdle(p: SharedPreferences): Boolean {
        return p.edit()
            .remove(KEY_STARTED_AT)
            .remove(KEY_STARTED_AT_MS)
            .remove(KEY_LIVE_RUN_ID)
            .remove(KEY_LIVE_RUN_TOKEN)
            .remove(KEY_START_ORIGIN)
            .putString(KEY_FG_MODE, "idle")
            .commit()
    }

    fun appendPendingInterval(
        p: SharedPreferences,
        startMs: Long,
        endMs: Long,
        subject: String,
        origin: String = "native_notification",
    ): Boolean {
        val list = try {
            JSONArray(p.getString(KEY_PENDING_INTERVALS, "[]") ?: "[]")
        } catch (_: Exception) {
            JSONArray()
        }
        list.put(
            JSONObject()
                // WP-251: kalıcı idempotency anahtarı. Dart bunu doğrudan
                // `study_sessions.id` olarak kullanır; kuyruk kısmen başarısız
                // olup tekrar işlense bile upsert AYNI satıra düşer → çift
                // oturum yazılmaz. Aynı anahtar "yalnız işlenenleri kuyruktan
                // sil" için de kullanılır (toptan silme, reconcile sürerken
                // eklenen yeni aralığı kaybettiriyordu).
                // DİKKAT: değer UUID biçiminde OLMAK ZORUNDA — `study_sessions.id`
                // uuid sütunudur; serbest metin insert'i patlatır.
                .put("id", UUID.randomUUID().toString())
                .put("start", Instant.ofEpochMilli(startMs).toString())
                .put("end", Instant.ofEpochMilli(endMs).toString())
                .put("subject", subject)
                .put("origin", origin),
        )
        return p.edit().putString(KEY_PENDING_INTERVALS, list.toString()).commit()
    }

    fun appendPendingVerifiedCommand(
        p: SharedPreferences,
        action: String,
        runToken: String,
        origin: String,
    ): Boolean {
        if (runToken.isBlank()) return false
        val list = try {
            JSONArray(p.getString(KEY_PENDING_INTERVALS, "[]") ?: "[]")
        } catch (_: Exception) {
            JSONArray()
        }
        list.put(
            JSONObject()
                // WP-251: bu kayıt oturum değil (komut); id yalnız kuyruktan
                // güvenli/kısmi silme içindir, DB'ye gitmez.
                .put("id", UUID.randomUUID().toString())
                .put("action", action)
                .put("runToken", runToken)
                .put("origin", origin),
        )
        return p.edit().putString(KEY_PENDING_INTERVALS, list.toString()).commit()
    }
}
