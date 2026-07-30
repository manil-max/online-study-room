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
    const val KEY_V2_ACTIVE_ACCOUNT_ID = "flutter.timer_v2_active_account_id"
    const val KEY_V2_INSTALLATION_ID = "flutter.timer_v2_installation_id"
    /** Çevrimdışı start→stop çiftini tek niyet olarak bağlar. */
    const val KEY_V2_RUN_INTENT_ID = "flutter.timer_v2_run_intent_id"

    /**
     * WP-431: bu cihazın koşu üzerindeki rolü — `source` | `mirror`.
     *
     * 🔴 WP-430 kök nedeni: rol yalnız Dart `state.isGlobalTimerMirror` alanında
     * yaşıyordu. Native taraf (bildirim/widget Durdur'u) onu göremediği için
     * ayna cihazda İKİ ayrı hata üretiyordu:
     *   1. `appendPendingInterval` ile UYDURMA bir yerel oturum yazıyordu —
     *      projeksiyonun asla üretmemesi gereken bir kayıt;
     *   2. koşu kimliği olmadığı için sunucuya durdurma komutu ÜRETEMİYORDU,
     *      dolayısıyla kaynak cihaz çalışmaya devam ediyordu (V56-S01).
     *
     * Rol artık store'da açıktır ve `handleStop` kararını buradan verir.
     */
    const val KEY_CONTROLLER_ROLE = "flutter.timer_v2_controller_role"
    const val ROLE_SOURCE = "source"
    const val ROLE_MIRROR = "mirror"

    /** Store'daki rol; tanınmayan/boş değer güvenli tarafa (`source`) düşer. */
    fun controllerRole(p: SharedPreferences): String =
        if (p.getString(KEY_CONTROLLER_ROLE, ROLE_SOURCE) == ROLE_MIRROR) ROLE_MIRROR
        else ROLE_SOURCE

    fun isMirror(p: SharedPreferences): Boolean = controllerRole(p) == ROLE_MIRROR

    /** Dart'ın `startOrigin`'inden rolü türetir (tek çeviri noktası). */
    fun roleForStartOrigin(startOrigin: String): String =
        if (startOrigin == "global_timer_mirror") ROLE_MIRROR else ROLE_SOURCE

    /**
     * WP-373: sunucunun kabul ettiği V2 koşu kimliği. Dart, `apply_global_timer_command`
     * BAŞARILI döndüğünde yazar; native `stop` zarfını kurarken buradan okur.
     *
     * Değerler **String** tutulur (revision dahil). Flutter `setInt` Android tarafında
     * `putLong` üretir; native `getInt` ile okumak ClassCastException verirdi.
     */
    const val KEY_V2_RUN_ID = "flutter.timer_v2_run_id"
    const val KEY_V2_RUN_REVISION = "flutter.timer_v2_run_revision"

    /**
     * WP-373 (KÖK NEDEN): V2 protokolünün `origin` sözlüğü, native'in yerel
     * `startOrigin` sözlüğünden **farklıdır** ve sunucu allowlist'iyle birebir
     * olmak zorundadır (`0082:277-280` → `app|widget|notification|recovery`).
     *
     * 🔴 Eskiden çeviri hiç yoktu: zarf ham `dart_app` / `native_widget` /
     * `native_notification` taşıyordu, sunucu her `start` komutunu
     * `invalid_global_timer_origin` ile reddediyordu ve hata istemcide
     * yutulduğu için çoklu cihaz senkronu **hiç çalışmadı**.
     *
     * Tanınmayan origin `null` döner ve komut ÜRETİLMEZ (fail-closed). Bu,
     * `global_timer_mirror` başlatmalarını da kendiliğinden dışarıda bırakır:
     * ayna, yeni bir kullanıcı niyeti değil, uzak gerçeğin gösterimidir.
     */
    fun canonicalV2Origin(startOrigin: String): String? = when (startOrigin) {
        "dart_app" -> "app"
        "native_widget" -> "widget"
        "native_notification" -> "notification"
        else -> null
    }

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
        controllerRole: String = ROLE_SOURCE,
    ): Boolean {
        return p.edit()
            .putString(KEY_CONTROLLER_ROLE, controllerRole)
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
            // WP-373: koşu kimliği bu koşuya aitti; kalırsa sonraki durdurma
            // ölü bir run'a `stale` stop gönderir. Zarf zaten kuruldu.
            .remove(KEY_V2_RUN_ID)
            .remove(KEY_V2_RUN_REVISION)
            .remove(KEY_V2_RUN_INTENT_ID)
            // WP-431: rol koşuya aittir. Kalırsa bir sonraki YEREL başlatma
            // kendini ayna sanar ve oturumunu hiç yazmaz.
            .remove(KEY_CONTROLLER_ROLE)
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

    /**
     * V2 global-timer niyeti için tek native producer.
     *
     * Account bağlanmadıysa kayıt yine kalıcı yazılır; Dart flush adapter bu
     * envelope'u karantinada bırakır. Bu, logout/account-switch sonrasında eski
     * komutun yeni hesap adına gönderilmesini engeller.
     */
    fun appendV2Command(
        p: SharedPreferences,
        action: String,
        startOrigin: String,
        runId: String? = null,
        expectedRunRevision: Long? = null,
    ): Boolean {
        if (action != "start" && action != "stop") return false
        // WP-373: protokol sözlüğüne çevrilemeyen origin komut üretmez.
        val origin = canonicalV2Origin(startOrigin) ?: return false
        // WP-415: çevrimdışı başlatılan koşuda sunucu kimliği henüz yoktur.
        // Durdur niyetini kaybetmek yerine Dart'ın start kabulünden sonra
        // run_id + revision ile çözebileceği işaretli bir terminal kayıt yazılır.
        if (action == "stop" &&
            (runId.isNullOrBlank() || expectedRunRevision == null || expectedRunRevision <= 0L)
        ) {
            return appendDeferredV2Stop(p, origin)
        }
        val list = try {
            JSONArray(p.getString(KEY_PENDING_INTERVALS, "[]") ?: "[]")
        } catch (_: Exception) {
            JSONArray()
        }
        val installationId = p.getString(KEY_V2_INSTALLATION_ID, null)
            ?.takeIf { it.isNotBlank() }
            ?: UUID.randomUUID().toString()
        val envelope = JSONObject()
            .put("id", UUID.randomUUID().toString())
            .put("kind", "global_timer_command")
            // WP-373: sözlük değiştiği için şema sürümü 2 → 3. Cihazlarda birikmiş
            // `dart_app` taşıyan v2 zarfları böylece `discard` olur ve kuyruktan
            // düşer; hiçbir zaman uygulanamayacak kayıtlar sonsuza dek denenmez.
            .put("schema_version", 3)
            .put("command_id", UUID.randomUUID().toString())
            .put("account_id", p.getString(KEY_V2_ACTIVE_ACCOUNT_ID, "").orEmpty())
            .put("installation_id", installationId)
            .put("action", action)
            .put("client_occurred_at", Instant.now().toString())
            .put("origin", origin)
            .put("state", "pending")
        if (action == "start") {
            val runIntentId = UUID.randomUUID().toString()
            envelope.put("run_intent_id", runIntentId)
            return p.edit()
                .putString(KEY_V2_INSTALLATION_ID, installationId)
                .putString(KEY_V2_RUN_INTENT_ID, runIntentId)
                .putString(KEY_PENDING_INTERVALS, list.put(envelope).toString())
                .commit()
        }
        if (!runId.isNullOrBlank()) envelope.put("run_id", runId)
        if (expectedRunRevision != null && expectedRunRevision > 0L) {
            envelope.put("expected_run_revision", expectedRunRevision)
        }
        list.put(envelope)
        return p.edit()
            .putString(KEY_V2_INSTALLATION_ID, installationId)
            .putString(KEY_PENDING_INTERVALS, list.toString())
            .commit()
    }

    /**
     * Sunucunun asla doğrudan görmediği yerel terminal niyeti.
     *
     * `deferred_until_run_identity` yalnız Flutter tüketicisinin anlaşmasıdır;
     * flush, aynı [KEY_V2_RUN_INTENT_ID] ile bağlı start kabul edilince bunu
     * gerçek CAS-stop zarfına çevirir. Böylece kapalı koşu çevrimiçi olunca
     * tek başına start olarak yeniden oynatılıp ayna cihazda hayalet koşu
     * doğurmaz.
     */
    private fun appendDeferredV2Stop(p: SharedPreferences, origin: String): Boolean {
        val runIntentId = p.getString(KEY_V2_RUN_INTENT_ID, null)
            ?.takeIf { it.isNotBlank() }
            ?: return false
        val list = try {
            JSONArray(p.getString(KEY_PENDING_INTERVALS, "[]") ?: "[]")
        } catch (_: Exception) {
            JSONArray()
        }
        val installationId = p.getString(KEY_V2_INSTALLATION_ID, null)
            ?.takeIf { it.isNotBlank() }
            ?: UUID.randomUUID().toString()
        list.put(
            JSONObject()
                .put("id", UUID.randomUUID().toString())
                .put("kind", "global_timer_command")
                .put("schema_version", 3)
                .put("command_id", UUID.randomUUID().toString())
                .put("account_id", p.getString(KEY_V2_ACTIVE_ACCOUNT_ID, "").orEmpty())
                .put("installation_id", installationId)
                .put("action", "stop")
                .put("client_occurred_at", Instant.now().toString())
                .put("origin", origin)
                .put("run_intent_id", runIntentId)
                .put("deferred_until_run_identity", true)
                .put("state", "pending"),
        )
        return p.edit()
            .putString(KEY_V2_INSTALLATION_ID, installationId)
            .putString(KEY_PENDING_INTERVALS, list.toString())
            .commit()
    }
}
