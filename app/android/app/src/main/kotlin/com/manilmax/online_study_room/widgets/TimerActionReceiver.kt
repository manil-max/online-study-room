package com.manilmax.online_study_room.widgets

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import com.manilmax.online_study_room.timer.StudyTimerService
import com.manilmax.online_study_room.timer.TimerStateStore

/**
 * Widget'taki Baslat/Durdur ve ders hapindan gelen dokunmayi yakalar ve
 * **native** foreground servisine iletir. Flutter motoruna ihtiyac yoktur;
 * uygulama tamamen kapaliyken de calisir.
 *
 * WP-135: idle→start, running→stop+00:00 (TimerStateStore.writeIdle).
 * exported=false (WP-118); PI explicit + IMMUTABLE (widget tarafi).
 * Oturum kaydi Dart tarafinda (app acilisinda) yapilir.
 *
 * 🔴 WP-718 — burasi bir [BroadcastReceiver]. Icerideki tek yakalanmamis
 * istisna uygulama **surecini** oldurur. Prefs okumalari bu yuzden
 * `runCatching` ile sarilir ve hata "ders hatirlanmadi"ya duser, coke degil.
 */
class TimerActionReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_TOGGLE_TIMER = "com.manilmax.online_study_room.ACTION_TOGGLE_TIMER"

        /** WP-718: widget'taki ders hapi — bir sonraki derse gecirir. */
        const val ACTION_CYCLE_SUBJECT =
            "com.manilmax.online_study_room.ACTION_CYCLE_WIDGET_SUBJECT"
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_TOGGLE_TIMER -> handleToggle(context)
            ACTION_CYCLE_SUBJECT -> handleCycleSubject(context)
        }
    }

    /**
     * 🔴 WP-718 KOK NEDEN — widget'tan baslatilan sayacin dersi HEP bostu.
     *
     * Eskiden bu metot tek satirdi: `sendCommand(ACTION_TOGGLE)`. Servisteki
     * `ACTION_TOGGLE` dali ise `subjectId = ""` yaziyor
     * (`StudyTimerService.kt`, idle→start dali). Yani kullanici uygulamada
     * "Matematik"i secmis olsa bile widget'tan baslatilan her kosu derssiz
     * kaydediliyordu; Dart acilista native SSOT'u sorgusuz benimsedigi icin
     * (`study_providers.dart` → `_kActiveSubject` okumasi) secim de siliniyordu.
     *
     * Karar artik BURADA verilir cunku `ACTION_TOGGLE` dali ders extra'sini
     * hic okumuyor; idle halde dogrudan `ACTION_START` gonderilir ve ders
     * [rememberedSubjectId] ile tasinir. Calisirken hala `ACTION_TOGGLE`
     * gonderilir: durdurma karari (ayna rolu, kuyruk, V2 zarfi) servisin
     * isidir ve `commandOrigin = "native_widget"` yalniz o dalda uretilir.
     */
    private fun handleToggle(context: Context) {
        val prefs = runCatching { TimerStateStore.prefs(context) }.getOrNull()
        if (prefs == null || runCatching { TimerStateStore.isRunning(prefs) }.getOrElse { true }) {
            StudyTimerService.sendCommand(
                context,
                StudyTimerService.ACTION_TOGGLE,
                startOrigin = ORIGIN_WIDGET,
            )
            return
        }
        val plan = runCatching { TimerStateStore.nativeStartPlan(prefs) }
            .getOrElse { TimerStateStore.StartPlan("stopwatch", null) }
        StudyTimerService.sendCommand(
            context,
            StudyTimerService.ACTION_START,
            startedAtMs = System.currentTimeMillis(),
            mode = plan.mode,
            phase = "work",
            cycle = 1,
            targetSeconds = plan.targetSeconds,
            subjectId = rememberedSubjectId(prefs),
            startOrigin = ORIGIN_WIDGET,
        )
    }

    /**
     * WP-718 — widget'tan ders secimi.
     *
     * Dart'in kurali aynen uygulanir: ders yalniz sayac DURURKEN degisir
     * (`StudyTimerNotifier.selectSubject` ilk satirinda `if (state.isRunning)
     * return`). Kosarken degistirmeye izin vermek, yazilmakta olan oturumun
     * dersini ortasinda degistirirdi.
     */
    private fun handleCycleSubject(context: Context) {
        runCatching {
            val prefs = TimerStateStore.prefs(context)
            if (TimerStateStore.isRunning(prefs)) return@runCatching
            val userId = widgetAccountId(prefs)
            if (userId.isEmpty()) return@runCatching
            val subjects = widgetSubjectOptions(prefs, userId)
            if (subjects.isEmpty()) return@runCatching
            val next = nextSubjectPreference(
                prefs.getString(subjectPreferenceKey(userId), null),
                subjects,
            )
            // Dart ile AYNI anahtar ve AYNI degerler: `__general__` ya da ders
            // kimligi. Ayri bir native anahtar tutmak iki gercek uretirdi;
            // uygulama acilinca `_restoreSelectedStudySubject` bunu okur.
            prefs.edit().putString(subjectPreferenceKey(userId), next).commit()
        }
        TimerWidgets.updateAll(context)
    }
}

// ---------------------------------------------------------------------------
// WP-718 · ders hafizasi — saf taraf
//
// Dart ↔ native sozlesmesi (`study_providers.dart` + `subject_providers.dart`):
//
//   flutter.selected_study_subject.<userId>  KALICI TERCIH   (String)
//   flutter.subjects_cache.<userId>          ders listesi aynasi (JSON metin)
//   flutter.timer_active_subject             KOSAN kosunun anlik goruntusu
//   flutter.timer_v2_active_account_id       aktif hesap kimligi (String)
//
// 🔴 Dogru anahtari secmek isin YARISI. `timer_active_subject`
// (`TimerStateStore.KEY_SUBJECT`) kalici tercih DEGILDIR: `writeRunning` onu
// yazar, `writeIdle`... yazmaz ama Dart tarafinda `stop` sonrasi
// `prefs.remove(_kActiveSubject)` cagrilir. Yani sayac durunca o anahtar
// SILINIR ve "en son ne kullanmistim" sorusuna cevap veremez. Kalici cevap
// WP-697'nin ekledigi `selected_study_subject.<userId>` anahtarindadir.
//
// 🔴 Tip tuzagi: her iki anahtar da **String**. Flutter `setInt` diske
// `putLong` yazar; ayni anahtari native `getInt` ile okumak
// `ClassCastException` firlatir ve receiver icinde bu, uygulama SURECINI
// oldurur (v58 sahasindaki geri sayim/pomodoro cokmesi). Burada hicbir sayisal
// anahtar okunmaz.
// ---------------------------------------------------------------------------

internal const val ORIGIN_WIDGET = "native_widget"

/** Dart: `_kGeneralStudySubject` — "ders yok" isareti; bos metinden farklidir. */
internal const val WIDGET_SUBJECT_GENERAL = "__general__"

/** Dart: `_kSelectedStudySubjectPrefix` + Flutter prefs'in `flutter.` oneki. */
internal const val WIDGET_SUBJECT_PREF_PREFIX = "flutter.selected_study_subject."

/** Dart: `subjectsCacheKey(userId)` + `flutter.` oneki (WP-697 cevrimdisi ayna). */
internal const val WIDGET_SUBJECTS_CACHE_PREFIX = "flutter.subjects_cache."

/**
 * Ders secili degilken hapta yazan isaret. Bilerek bir SIMGE: `strings.xml`
 * bu WP'nin SAHIP yolu degil ve koda gomulu Turkce metin yasak; tire her dilde
 * ayni anlami tasir ve ceviri kaynagi acmaz.
 */
internal const val WIDGET_SUBJECT_NONE_LABEL = "—"

internal data class WidgetSubject(val id: String, val name: String)

internal fun subjectPreferenceKey(userId: String): String =
    WIDGET_SUBJECT_PREF_PREFIX + userId

internal fun subjectsCacheKey(userId: String): String =
    WIDGET_SUBJECTS_CACHE_PREFIX + userId

internal fun widgetAccountId(prefs: SharedPreferences): String =
    runCatching {
        prefs.getString(TimerStateStore.KEY_V2_ACTIVE_ACCOUNT_ID, null).orEmpty().trim()
    }.getOrElse { "" }

/**
 * Ders listesi aynasini ayristirir.
 *
 * `org.json` DEGIL [MiniJson]: JVM birim testinde `android.*` saplamalari
 * cagrilamaz, yani `org.json` ile yazilan ayristirma hic olculemezdi
 * (`CountdownWidget.kt` ayni gerekceyle bu yardimciyi tanimladi).
 *
 * `user_id` her satirda dogrulanir: cihaz tek, hesap birden cok olabilir;
 * yabanci bir satir widget'a sizarsa kullanici baska hesabin dersini secip
 * o dersle oturum yazardi (sunucuda yabanci anahtar ihlali).
 */
internal fun parseWidgetSubjects(raw: String?, userId: String): List<WidgetSubject> {
    val root = MiniJson.parse(raw) as? List<*> ?: return emptyList()
    return root.mapNotNull { it as? Map<*, *> }
        .mapNotNull { entry ->
            if ((entry["user_id"] as? String) != userId) return@mapNotNull null
            val id = (entry["id"] as? String)?.trim().orEmpty()
            val name = (entry["name"] as? String)?.trim().orEmpty()
            if (id.isEmpty() || name.isEmpty()) null else WidgetSubject(id, name)
        }
}

internal fun widgetSubjectOptions(
    prefs: SharedPreferences,
    userId: String,
): List<WidgetSubject> = runCatching {
    parseWidgetSubjects(prefs.getString(subjectsCacheKey(userId), null), userId)
}.getOrElse { emptyList() }

/**
 * Bir sonraki tercih: `[__general__, ders1, ders2, …]` halkasinda bir adim.
 *
 * Tanimadigi/silinmis bir tercih halkanin BASINA doner ("Genel"den sonraki
 * ilk ders). Boylece sunucudan silinmis bir ders widget'ta sonsuza kadar
 * takili kalmaz.
 */
internal fun nextSubjectPreference(
    current: String?,
    subjects: List<WidgetSubject>,
): String {
    if (subjects.isEmpty()) return WIDGET_SUBJECT_GENERAL
    val ring = listOf(WIDGET_SUBJECT_GENERAL) + subjects.map { it.id }
    val index = ring.indexOf(current?.trim().orEmpty())
    return if (index < 0) ring[1] else ring[(index + 1) % ring.size]
}

/** Hapta yazan metin: ders adi ya da [WIDGET_SUBJECT_NONE_LABEL]. */
internal fun widgetSubjectLabel(
    current: String?,
    subjects: List<WidgetSubject>,
): String = subjects.firstOrNull { it.id == current?.trim() }?.name
    ?: WIDGET_SUBJECT_NONE_LABEL

/**
 * Widget'tan baslatilacak kosunun dersi. Bos metin "ders yok" demektir ve
 * `TimerStateStore.writeRunning` icin de aynen budur.
 *
 * Silinmis bir ders kimligi ile kosu baslatmak, Dart'in acilista o kimlikle
 * oturum yazmasina ve sunucuda yabanci anahtar ihlaline yol acardi. Bu yuzden
 * ayna VARSA tercih ona karsi dogrulanir. Ayna HIC yazilmamissa (kullanici
 * ders listesini bir kez bile yuklememis) tercih oldugu gibi kabul edilir:
 * Dart tarafinda da "ayna yok" ile "liste bos" bilerek ayri seylerdir
 * (`readCachedSubjects` null vs `[]`).
 */
internal fun rememberedSubjectId(prefs: SharedPreferences): String = runCatching {
    val userId = widgetAccountId(prefs)
    if (userId.isEmpty()) return@runCatching ""
    val preference = prefs.getString(subjectPreferenceKey(userId), null)?.trim().orEmpty()
    if (preference.isEmpty() || preference == WIDGET_SUBJECT_GENERAL) return@runCatching ""
    val raw = prefs.getString(subjectsCacheKey(userId), null)
    if (raw == null) return@runCatching preference
    val subjects = parseWidgetSubjects(raw, userId)
    if (subjects.any { it.id == preference }) preference else ""
}.getOrElse { "" }
