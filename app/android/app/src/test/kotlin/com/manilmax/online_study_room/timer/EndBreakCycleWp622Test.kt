package com.manilmax.online_study_room.timer

import android.content.SharedPreferences
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * WP-622: bildirimdeki **"Çalışmaya dön"** düğmesi pomodoro döngüsünü
 * ilerletiyor mu?
 *
 * 🔴 Neden bugün ölçülüyor. WP-613'e kadar faz geçişinde native servise hiçbir
 * komut gitmiyordu; mola bildirimi hiç çıkmıyor, bu düğme üretimde HİÇ
 * görünmüyordu. WP-613 o köprüyü kurdu ve arkasındaki hata kullanıcıya ulaşır
 * hâle geldi: mola bildirimden bitirilince `handleEndBreak` döngüyü prefs'ten
 * okuyup **aynen** geri yazıyordu. Her molayı bildirimden kapatan kullanıcı
 * aynı turda sonsuza kadar kalıyordu.
 *
 * 🔴 Neden bu dosya var. Bu yolu "koruyan" tek kapı
 * (`test/core/verified_timer_bridge_contract_test.dart`) `ACTION_END_BREAK`
 * metnini `.kt` içinde ARIYORDU — metin vardı, davranış yanlıştı. Burada metne
 * bakılmaz: kararın ürettiği **SSOT yazımı** ölçülür.
 *
 * Sınır: `StudyTimerService` bir `Service`'tir, Robolectric'siz kurulamaz. Bu
 * yüzden karar [TimerStateStore.endBreakPlan] içinde saf tutuldu ve servis
 * yalnız uygulayıcı kaldı. Zincirin Dart yakası (native'in yazdığını ekranın
 * benimsemesi) `test/data/timer_end_break_cycle_wp622_test.dart`.
 */
class EndBreakCycleWp622Test {

    /** Servisin `handleEndBreak` gövdesinin birebir karşılığı (SSOT yazımı). */
    private fun tapReturnToWork(prefs: SharedPreferences, nowMs: Long): Boolean {
        val plan = TimerStateStore.endBreakPlan(prefs) ?: return false
        TimerStateStore.writeRunning(
            prefs,
            startedAtMs = nowMs,
            mode = plan.mode,
            phase = "work",
            cycle = plan.cycle,
            targetSeconds = plan.targetSeconds,
            subjectId = plan.subjectId,
            liveRunId = plan.liveRunId,
            liveRunToken = plan.liveRunToken,
            startOrigin = plan.startOrigin,
        )
        return true
    }

    /**
     * Molada duran 4 turluk bir pomodoro. Sayılar Dart'ın yazdığı gibi
     * **Long**'dur (`prefs.setInt` Android'e `putLong` yazar, WP-489).
     */
    private fun restingPomodoro(cycle: Int, totalCycles: Int = 4): Wp622StrictPrefs {
        val prefs = Wp622StrictPrefs()
        prefs.edit()
            .putString(TimerStateStore.KEY_MODE, "pomodoro")
            .putString(TimerStateStore.KEY_PHASE, "rest")
            .putLong(TimerStateStore.KEY_CYCLE, cycle.toLong())
            .putLong(TimerStateStore.KEY_TOTAL_CYCLES, totalCycles.toLong())
            .putLong(TimerStateStore.KEY_WORK_MINUTES, 25L)
            .putString(TimerStateStore.KEY_SUBJECT, "math")
            .putString(TimerStateStore.KEY_START_ORIGIN, "native_notification")
            .commit()
        return prefs
    }

    @Test
    fun calismaya_don_bir_sonraki_dongude_calisma_fazi_baslatir() {
        val prefs = restingPomodoro(cycle = 2)

        assertTrue(tapReturnToWork(prefs, nowMs = 1_700_000_000_000L))

        // ASIL BUG: eskiden burası 2L kalıyordu — bir tur yutuluyordu.
        assertEquals(3L, prefs.getLong(TimerStateStore.KEY_CYCLE, -1L))
        assertEquals("work", prefs.getString(TimerStateStore.KEY_PHASE, null))
        assertEquals("pomodoro", prefs.getString(TimerStateStore.KEY_MODE, null))
        assertEquals("running", prefs.getString(TimerStateStore.KEY_FG_MODE, null))
        assertEquals(
            1_700_000_000_000L,
            prefs.getLong(TimerStateStore.KEY_STARTED_AT_MS, -1L),
        )
        // Ders molada kaybolmaz.
        assertEquals("math", prefs.getString(TimerStateStore.KEY_SUBJECT, null))
    }

    @Test
    fun her_molayi_bildirimden_kapatan_kullanicinin_pomodorosu_BITER() {
        // Kullanıcının gerçek şikâyeti buydu: 4 turluk pomodoro'yu her molada
        // bildirimden sürdürünce tur sayacı hiç ilerlemiyordu.
        val prefs = restingPomodoro(cycle = 1, totalCycles = 4)
        val gorulenTurlar = mutableListOf<Long>()

        repeat(3) { tur ->
            assertTrue(tapReturnToWork(prefs, nowMs = 1_700_000_000_000L + tur))
            gorulenTurlar += prefs.getLong(TimerStateStore.KEY_CYCLE, -1L)
            // Yeni çalışma fazı da hedefine varıp molaya geçti.
            prefs.edit().putString(TimerStateStore.KEY_PHASE, "rest").commit()
        }

        assertEquals(listOf(2L, 3L, 4L), gorulenTurlar)
    }

    @Test
    fun calisma_fazinda_gelen_komut_YOK_SAYILIR() {
        // Ters iddia: "her komutta turu artır" sabotajı buradan düşer. `rest`
        // fazında olmayan bir koşuda bu düğme zaten çizilmez; gecikmiş bir
        // PendingIntent turu kendiliğinden ilerletmemeli.
        val prefs = restingPomodoro(cycle = 2)
        prefs.edit().putString(TimerStateStore.KEY_PHASE, "work").commit()

        assertNull(TimerStateStore.endBreakPlan(prefs))
        assertFalse(tapReturnToWork(prefs, nowMs = 1_700_000_000_000L))
        assertEquals(2L, prefs.getLong(TimerStateStore.KEY_CYCLE, -1L))
    }

    @Test
    fun yeni_calisma_fazinin_HEDEFI_de_yazilir_yoksa_widget_durmus_gorunur() {
        // `timerChronometerProjection` hedefi olmayan pomodoro koşusunu IDLE
        // sayar; eski çağrı targetSeconds geçmediği için `writeRunning` o
        // anahtarı SİLİYORDU — ana ekran widget'ı sayacı durmuş gösteriyordu.
        val prefs = restingPomodoro(cycle = 2)

        tapReturnToWork(prefs, nowMs = 1_700_000_000_000L)

        assertEquals(25 * 60L, prefs.getLong(TimerStateStore.KEY_TARGET_SECONDS, -1L))
    }

    @Test
    fun ayari_hic_acmamis_kullanicida_hedef_URUN_VARSAYILANINA_duser() {
        // 🔴 WP-645 — BU TEST ESKIDEN BOZUK DAVRANISI KILITLIYORDU.
        //
        // Eski hali `assertNull(...targetSeconds)` ve
        // `assertFalse(prefs.contains(KEY_TARGET_SECONDS))` diyordu; gerekcesi
        // "hedef yoksa 0 sn'lik SAHTE hedef uydurma" idi. Gerekce dogru, ikilem
        // yanlisti: ucuncu bir secenek var ve dogrusu o — urunun GERCEK
        // varsayilani (25 dk, `StudyTimerNotifier` `?? 25`).
        //
        // Bu anahtar diskte olmayabiliyordu cunku Dart onu YALNIZ kullanici
        // pomodoro ayarini elle degistirince yaziyordu (WP-644 bunu duzeltti).
        // Yani pomodoro ayar sayfasini hic acmamis kullanici, bildirimden
        // "Calismaya don"e bastiginda ana ekran widget'inda sayaci DURMUS
        // goruyordu — sayac gercekten akarken. Kapi yesildi, urun kirikti.
        val prefs = restingPomodoro(cycle = 2)
        prefs.edit().remove(TimerStateStore.KEY_WORK_MINUTES).commit()

        assertEquals(
            25 * 60,
            TimerStateStore.endBreakPlan(prefs)?.targetSeconds,
        )

        tapReturnToWork(prefs, nowMs = 1_700_000_000_000L)
        assertEquals(
            25 * 60L,
            prefs.getLong(TimerStateStore.KEY_TARGET_SECONDS, -1L),
        )
    }

    // ---------------------------------------------------------------
    // WP-645 — widget/bildirim "Baslat"i kullanicinin SECTIGI modu baslatir
    // ---------------------------------------------------------------

    /** Kosmayan bir cihaz: yalniz kullanici tercihleri diskte. */
    private fun idleWithUserChoice(
        mode: String,
        workMinutes: Long? = null,
        countdownMinutes: Long? = null,
    ): Wp622StrictPrefs {
        val prefs = Wp622StrictPrefs()
        val editor = prefs.edit().putString(TimerStateStore.KEY_USER_MODE, mode)
        if (workMinutes != null) {
            editor.putLong(TimerStateStore.KEY_WORK_MINUTES, workMinutes)
        }
        if (countdownMinutes != null) {
            editor.putLong(TimerStateStore.KEY_COUNTDOWN_MINUTES, countdownMinutes)
        }
        editor.commit()
        return prefs
    }

    @Test
    fun widget_baslat_POMODORO_secimini_baslatir() {
        // 🔴 Kok neden: `ACTION_TOGGLE` `mode = "stopwatch"` SABIT yaziyordu
        // ve kullanicinin `flutter.timer_mode` secimi Kotlin kodunda HIC
        // okunmuyordu. Kullanici Pomodoro secili widget'tan Baslat'a basinca
        // sayac sonsuza kadar YUKARI sayiyor, mola hic gelmiyordu.
        val prefs = idleWithUserChoice("pomodoro", workMinutes = 50L)

        val plan = TimerStateStore.nativeStartPlan(prefs)

        assertEquals("pomodoro", plan.mode)
        assertEquals(50 * 60, plan.targetSeconds)
    }

    @Test
    fun widget_baslat_GERI_SAYIM_secimini_baslatir() {
        val prefs = idleWithUserChoice("countdown", countdownMinutes = 45L)

        val plan = TimerStateStore.nativeStartPlan(prefs)

        assertEquals("countdown", plan.mode)
        assertEquals(45 * 60, plan.targetSeconds)
    }

    @Test
    fun ayari_hic_acmamis_kullanicida_da_secilen_mod_hedefli_baslar() {
        // Sure anahtari diskte yok (WP-644 oncesi kurulum): mod korunur ve
        // hedef urun varsayilanina duser — hedefsiz pomodoro dogmaz.
        val prefs = idleWithUserChoice("pomodoro")

        val plan = TimerStateStore.nativeStartPlan(prefs)

        assertEquals("pomodoro", plan.mode)
        assertEquals(25 * 60, plan.targetSeconds)
    }

    @Test
    fun ters_iddia_KRONOMETRE_secili_kullanicida_hedef_UYDURULMAZ() {
        // Sabotaj kapisi: testler "her mod hedeflidir" demiyor. Kronometre
        // acik uclu sayar; ona hedef yazmak kosuyu dogdugu anda bitirirdi.
        val prefs = idleWithUserChoice("stopwatch", workMinutes = 25L)

        val plan = TimerStateStore.nativeStartPlan(prefs)

        assertEquals("stopwatch", plan.mode)
        assertNull(plan.targetSeconds)
    }

    @Test
    fun secim_hic_yoksa_kronometreye_duser() {
        val plan = TimerStateStore.nativeStartPlan(Wp622StrictPrefs())

        assertEquals("stopwatch", plan.mode)
        assertNull(plan.targetSeconds)
    }

    @Test
    fun bozuk_prefs_te_bile_tur_toplami_asmaz() {
        // Ürün değişmezi: `rest` son turda doğmaz. İhlal edilse bile kullanıcı
        // "Tur 5/4" görmemeli.
        val prefs = restingPomodoro(cycle = 4, totalCycles = 4)

        tapReturnToWork(prefs, nowMs = 1_700_000_000_000L)

        assertEquals(4L, prefs.getLong(TimerStateStore.KEY_CYCLE, -1L))
    }

    @Test
    fun eski_kurulumun_int_yazimi_da_ilerler() {
        // WP-489: v58 öncesi build'ler aynı anahtarı `putInt` ile yazmıştı.
        val prefs = restingPomodoro(cycle = 2)
        prefs.edit().remove(TimerStateStore.KEY_CYCLE).commit()
        prefs.edit().putInt(TimerStateStore.KEY_CYCLE, 2).commit()

        assertEquals(3, TimerStateStore.endBreakPlan(prefs)?.cycle)
    }

    @Test
    fun toplam_tur_ayari_bozuksa_tur_yine_de_ilerler() {
        // Tavan bir kolaylıktır, ön koşul değil: ayar okunamazsa bile
        // kullanıcının molası bir sonraki tura geçmelidir.
        val prefs = restingPomodoro(cycle = 2)
        prefs.edit().remove(TimerStateStore.KEY_TOTAL_CYCLES).commit()
        prefs.edit().putString(TimerStateStore.KEY_TOTAL_CYCLES, "bozuk").commit()

        assertEquals(3, TimerStateStore.endBreakPlan(prefs)?.cycle)
    }
}

/**
 * `SharedPreferencesImpl` ile aynı tip sertliği: yanlış tip cast'te patlar.
 * Gevşek bir sahte prefs, WP-489 sınıfı hataları hiç göremezdi.
 */
private class Wp622StrictPrefs : SharedPreferences {
    private val values = LinkedHashMap<String, Any>()

    private fun raw(key: String?): Any? = if (key == null) null else values[key]

    override fun getAll(): MutableMap<String, *> = values

    override fun getString(key: String?, defValue: String?): String? =
        raw(key)?.let { it as String } ?: defValue

    @Suppress("UNCHECKED_CAST")
    override fun getStringSet(
        key: String?,
        defValues: MutableSet<String>?,
    ): MutableSet<String>? = raw(key)?.let { it as MutableSet<String> } ?: defValues

    override fun getInt(key: String?, defValue: Int): Int = raw(key)?.let { it as Int } ?: defValue

    override fun getLong(key: String?, defValue: Long): Long =
        raw(key)?.let { it as Long } ?: defValue

    override fun getFloat(key: String?, defValue: Float): Float =
        raw(key)?.let { it as Float } ?: defValue

    override fun getBoolean(key: String?, defValue: Boolean): Boolean =
        raw(key)?.let { it as Boolean } ?: defValue

    override fun contains(key: String?): Boolean = key != null && values.containsKey(key)

    override fun edit(): SharedPreferences.Editor = Wp622FakeEditor(values)

    override fun registerOnSharedPreferenceChangeListener(
        listener: SharedPreferences.OnSharedPreferenceChangeListener?,
    ) = Unit

    override fun unregisterOnSharedPreferenceChangeListener(
        listener: SharedPreferences.OnSharedPreferenceChangeListener?,
    ) = Unit
}

private class Wp622FakeEditor(
    private val target: LinkedHashMap<String, Any>,
) : SharedPreferences.Editor {
    private val staged = LinkedHashMap<String, Any?>()
    private var clearAll = false

    private fun stage(key: String?, value: Any?): SharedPreferences.Editor {
        if (key != null) staged[key] = value
        return this
    }

    override fun putString(key: String?, value: String?) = stage(key, value)

    override fun putStringSet(key: String?, values: MutableSet<String>?) = stage(key, values)

    override fun putInt(key: String?, value: Int) = stage(key, value)

    override fun putLong(key: String?, value: Long) = stage(key, value)

    override fun putFloat(key: String?, value: Float) = stage(key, value)

    override fun putBoolean(key: String?, value: Boolean) = stage(key, value)

    override fun remove(key: String?) = stage(key, null)

    override fun clear(): SharedPreferences.Editor {
        clearAll = true
        return this
    }

    override fun commit(): Boolean {
        if (clearAll) target.clear()
        staged.forEach { (key, value) ->
            if (value == null) target.remove(key) else target[key] = value
        }
        staged.clear()
        clearAll = false
        return true
    }

    override fun apply() {
        commit()
    }
}
