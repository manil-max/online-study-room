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
    const val KEY_TARGET_SECONDS = "flutter.timer_active_target_seconds"
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

    /**
     * WP-489: sayısal sayaç anahtarlarının kanonik tipi **Long**'dur.
     *
     * Flutter'ın `prefs.setInt` çağrısı Android'e `putLong` yazar
     * (`SharedPreferencesPlugin.kt:317`). Aynı anahtarı `getInt` ile okumak
     * `SharedPreferencesImpl` içindeki `(Integer) value` cast'ine düşer ve
     * yakalanmayan bir `ClassCastException` fırlatır; servis/receiver içinde
     * bu, uygulama **sürecini** öldürür.
     *
     * Yardımcı iki yönlü dayanıklıdır: v58 öncesi kurulumlarda aynı anahtar
     * native `putInt` ile yazılmış olabilir, o değer de okunabilir kalır.
     */
    fun readIntCompat(p: SharedPreferences, key: String, fallback: Int): Int {
        if (!p.contains(key)) return fallback
        val asLong = runCatching { p.getLong(key, fallback.toLong()) }.getOrNull()
        if (asLong != null) return asLong.toInt()
        return runCatching { p.getInt(key, fallback) }.getOrDefault(fallback)
    }

    /**
     * Kullanıcının pomodoro ayarları — bu üç anahtarı **Dart yazar**
     * (`StudyTimerNotifier` `timer_cycles` / `timer_work_min`), native taraf
     * yalnız okur. Ayrı bir native kopya tutmak iki gerçek üretirdi.
     */
    const val KEY_TOTAL_CYCLES = "flutter.timer_cycles"
    const val KEY_WORK_MINUTES = "flutter.timer_work_min"

    /**
     * WP-645: kullanicinin SECTIGI sayac modu ve geri sayim suresi.
     *
     * Bu iki anahtar `TimerStateStore` icinde hic yoktu; native taraf
     * kullanicinin ne sectigini **bilmiyordu**. `KEY_MODE` ise secim
     * degil, KOSAN kosunun modudur; kosu yokken bir sey soylemez.
     */
    const val KEY_USER_MODE = "flutter.timer_mode"
    const val KEY_COUNTDOWN_MINUTES = "flutter.timer_countdown_min"

    /**
     * Urunun gercek varsayilanlari (`StudyTimerNotifier` ile ayni sayilar).
     *
     * WP-644 Dart tarafina bu varsayilanlari **diske yazdirdi**, yani yeni
     * kurulumlarda anahtarlar hep var. Buradaki degerler yalniz o yazimdan
     * once kurulmus cihazlar icin geriye donuk emniyettir; `0` fallback
     * kullanmak sessizce YANLIS davranis uretiyordu (asagi bak).
     */
    const val DEFAULT_WORK_MINUTES = 25
    const val DEFAULT_COUNTDOWN_MINUTES = 25

    /**
     * WP-622: bildirimdeki **"Çalışmaya dön"** düğmesinin kararı — mola bitince
     * hangi çalışma fazı başlayacak?
     *
     * 🔴 Kök neden. Eski `handleEndBreak`, döngü numarasını prefs'ten okuyup
     * **aynen** geri yazıyordu. Ürünün kuralı ise `rest → work` geçişinde
     * döngüyü artırmaktır (`study_providers.dart` → `nextPhaseTransition`,
     * `nextCycle: cycle + 1`). Dart, native SSOT'tan gelen koşuyu sorgusuz
     * benimsediği için (`_reconcileBackgroundTimer` → `fgCycle`) bildirimden
     * bitirilen her mola bir döngüyü yutuyordu: 4 turluk pomodoro'yu her turda
     * bildirimden sürdüren kullanıcı 2. turda sonsuza kadar takılı kalıyordu.
     *
     * 🔴 İkinci yüzü. Eski çağrı `targetSeconds` de geçmiyordu; [writeRunning]
     * o anahtarı **siliyor**. Hedefi olmayan bir pomodoro koşusunu widget
     * projeksiyonu (`timerChronometerProjection`) IDLE sayar — yani ana ekran
     * widget'ı "Çalışmaya dön"e basıldıktan sonra sayacı DURMUŞ gösteriyordu.
     *
     * Karar burada **saf** tutulur ki cihazsız JVM testiyle ölçülebilsin;
     * servis yalnız uygular. `rest` fazında değilsek `null` döner ve komut
     * yok sayılır (eski erken `return` ile aynı anlam).
     */
    data class EndBreakPlan(
        val mode: String,
        val cycle: Int,
        val targetSeconds: Int?,
        val subjectId: String,
        val liveRunId: String,
        val liveRunToken: String,
        val startOrigin: String,
    )

    fun endBreakPlan(p: SharedPreferences): EndBreakPlan? {
        if (p.getString(KEY_PHASE, "") != "rest") return null
        val mode = p.getString(KEY_MODE, "stopwatch") ?: "stopwatch"
        val current = readIntCompat(p, KEY_CYCLE, 1).coerceAtLeast(1)
        val totalCycles = readIntCompat(p, KEY_TOTAL_CYCLES, 0)
        // Ürün değişmezi: `rest` yalnız SON döngüden önce doğar (son çalışma
        // fazı molaya değil bitişe gider), yani `current < totalCycles`. Tavan
        // bu değişmez bozuk bir prefs yüzünden ihlal edilse bile sayacın
        // "5/4" gibi imkânsız bir tur göstermesini engeller.
        val next = (current + 1).let {
            if (totalCycles > 0) it.coerceAtMost(totalCycles) else it
        }
        return EndBreakPlan(
            mode = mode,
            cycle = next,
            // Dart'taki `timerPhaseTargetSeconds` ile aynı kural: pomodoro'da
            // çalışma fazının hedefi kullanıcının seçtiği çalışma dakikasıdır.
            // 🔴 WP-644/645 — fallback `0` DEGIL urun varsayilani.
            // Eski `0` fallback'i, pomodoro ayar sayfasini hic acmamis
            // kullanicida (anahtar diskte yok) hedefi `null` uretiyordu;
            // `writeRunning` hedef anahtarini siliyor, widget projeksiyonu
            // hedefsiz pomodoro kosusunu IDLE sayiyordu. Yani sayac gercekten
            // akarken ana ekran widget'i "durmus" gosteriyordu.
            targetSeconds = if (mode == "pomodoro") {
                (readIntCompat(p, KEY_WORK_MINUTES, DEFAULT_WORK_MINUTES) * 60)
                    .takeIf { it > 0 }
            } else {
                null
            },
            subjectId = p.getString(KEY_SUBJECT, "") ?: "",
            liveRunId = p.getString(KEY_LIVE_RUN_ID, "").orEmpty(),
            liveRunToken = p.getString(KEY_LIVE_RUN_TOKEN, "").orEmpty(),
            startOrigin = p.getString(KEY_START_ORIGIN, "native_notification").orEmpty(),
        )
    }

    /**
     * WP-645: widget/bildirim **Baslat**'inin kullanacagi plan.
     *
     * 🔴 Kok neden. `ACTION_TOGGLE` (ana ekran widget'i) `mode = "stopwatch"`
     * degerini SABIT yaziyordu; bildirimdeki Baslat ise moda hic deginmiyor,
     * servis de `?: "stopwatch"` ile ayni yere dusuyordu. Kullanicinin sectigi
     * mod (`flutter.timer_mode`) Kotlin kodunda **hic okunmuyordu**.
     *
     * Sonucu kullanici soyle yasiyor: uygulamada Pomodoro 25/5 secili, widget'tan
     * Baslat'a basiyor, sayac sonsuza kadar YUKARI sayiyor, 25. dakikada mola
     * gelmiyor. Dart native SSOT'u sorgusuz benimsedigi icin uygulamayi actiginda
     * mod secici de **Kronometre**'ye donmus oluyor: secim sessizce silinmis.
     *
     * Karar burada **saf** tutulur ki cihazsiz JVM testiyle olculebilsin.
     */
    data class StartPlan(val mode: String, val targetSeconds: Int?)

    fun nativeStartPlan(p: SharedPreferences): StartPlan {
        val mode = p.getString(KEY_USER_MODE, "stopwatch") ?: "stopwatch"
        val minutes = when (mode) {
            "countdown" -> readIntCompat(p, KEY_COUNTDOWN_MINUTES, DEFAULT_COUNTDOWN_MINUTES)
            "pomodoro" -> readIntCompat(p, KEY_WORK_MINUTES, DEFAULT_WORK_MINUTES)
            // Kronometre acik uclu sayar; hedefi yoktur.
            else -> 0
        }
        return StartPlan(mode, (minutes * 60).takeIf { it > 0 })
    }

    /** Çalışan sayaç durumunu atomik yazar (commit). */
    fun writeRunning(
        p: SharedPreferences,
        startedAtMs: Long,
        mode: String,
        phase: String,
        cycle: Int,
        targetSeconds: Int? = null,
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
            .putLong(KEY_CYCLE, cycle.toLong())
            .also { editor ->
                if (targetSeconds != null && targetSeconds > 0) {
                    editor.putLong(KEY_TARGET_SECONDS, targetSeconds.toLong())
                } else {
                    editor.remove(KEY_TARGET_SECONDS)
                }
            }
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
            .remove(KEY_TARGET_SECONDS)
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
