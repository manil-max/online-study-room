package com.manilmax.online_study_room.widgets

import android.content.SharedPreferences
import com.manilmax.online_study_room.timer.TimerStateStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * WP-718 — sayac widget'larinin **native** yarisi.
 *
 * Dort is, dort ayri iddia kumesi. Sabotaj testi (biri geri alinirsa yalniz
 * kendi kumesi kirmizi duser) her kumenin basinda yazilidir.
 *
 * Boyut tarafinda WP-699 ile AYNI aritmetik model kullanilir — karakter
 * genisligi `0.60 x punto`, satir yuksekligi `1.30 x punto`, her kutuda 8dp
 * emniyet payi. Model bir CIHAZ OLCUMU DEGILDIR; isi punto merdivenini kutu
 * sinirlarina baglamaktir: biri buyur digeri buyumezse kirmizi duser.
 */
class TimerWidgetWp718Test {

    // --- olcum modeli ------------------------------------------------------

    private val safetyMarginDp = 8f

    /** Kronometre en uzun halinde "00:00:00" yazar. */
    private val timeChars = 8

    /** "Durdur" / "Baslat" — iki dilde de 6 karakteri gecmez. */
    private val actionChars = 6

    private fun textWidthDp(sp: Float, chars: Int): Float = sp * 0.60f * chars

    private fun lineHeightDp(sp: Float): Float = sp * 1.30f

    private fun usableDp(boxDp: Int, paddingDp: Int): Float =
        boxDp - 2f * paddingDp - safetyMarginDp

    private fun assertFits(label: String, neededDp: Float, availableDp: Float) {
        assertTrue(
            "$label: $neededDp dp gerekiyor, $availableDp dp var -> KIRPILIR",
            neededDp <= availableDp,
        )
    }

    // =======================================================================
    // IS 1 — 1x1 okunabilirlik + 48dp dokunma hedefi
    //
    // SABOTAJ: `WidgetTypography.timerTime`i eski (15/22/30) degerlerine geri
    // al -> yalniz bu bolumdeki `punto_WP718_oncesi_degerlerin_ustunde` ve
    // `sayi_her_sinifta_eskisinden_buyuk` iddialari duser. Ders hafizasi ve
    // ders secimi iddialari YESIL kalir.
    // =======================================================================

    /** WP-718 oncesi yururlukteki merdiven — sabotaj capasi. */
    private val puntoOncesi = SpRamp(15f, 22f, 30f)

    /** WP-718 oncesi Baslat/Durdur hapinin `minHeight` degeri. */
    private val dugmeYuksekligiOncesiDp = 32f

    @Test
    fun dokunma_hedefi_Android_kilavuzunun_asgarisi() {
        // Eski hap 32dp idi: 48dp'nin ucte ikisi.
        assertEquals(48, WIDGET_MIN_TOUCH_TARGET_DP)
        assertTrue(
            "yeni hedef eski 32dp'den buyuk olmali",
            WIDGET_MIN_TOUCH_TARGET_DP > dugmeYuksekligiOncesiDp,
        )
    }

    @Test
    fun sayi_her_sinifta_eskisinden_buyuk() {
        listOf(
            Triple("NARROW", WidgetWidthClass.NARROW, puntoOncesi.narrow),
            Triple("MEDIUM", WidgetWidthClass.MEDIUM, puntoOncesi.medium),
            Triple("WIDE", WidgetWidthClass.WIDE, puntoOncesi.wide),
        ).forEach { (ad, sinif, once) ->
            assertTrue(
                "timer/$ad punto buyumedi: once $once, simdi " +
                    "${WidgetTypography.timerTime.of(sinif)}",
                WidgetTypography.timerTime.of(sinif) > once,
            )
        }
        // Sahibin sikayet ettigi tam nokta: en dar sinif.
        assertEquals(18f, WidgetTypography.timerTime.narrow)
    }

    @Test
    fun dugme_metni_de_eskisinden_buyuk() {
        // 11sp'lik "Baslat" 48dp'lik bir hapin icinde kaybolurdu.
        assertTrue(WidgetTypography.timerAction.narrow > 11f)
        assertTrue(WidgetTypography.timerAction.medium > 12f)
        assertTrue(WidgetTypography.timerAction.wide > 14f)
    }

    @Test
    fun en_kucuk_kutuda_kontrol_satiri_yerine_KOK_hedef_olur() {
        // 🔴 Isin ozu. 80dp'lik kutuda 48dp hap + okunur sayi SIGMAZ:
        val kisaDolgu = timerRootPaddingDp(widgetSizeClass(WidgetSizeSpecs.timer, 110, 80))
        val gerekli = lineHeightDp(WidgetTypography.timerTime.narrow) +
            WIDGET_DESIGN_ROW_GAP_DP + WIDGET_MIN_TOUCH_TARGET_DP
        assertTrue(
            "48dp hap 80dp kutuya sigiyorsa bu WP'nin gerekcesi yanlis",
            gerekli > usableDp(80, kisaDolgu),
        )
        // ...bu yuzden o sinifta satir hic cizilmez.
        assertFalse(timerControlsVisible(WidgetHeightClass.SHORT))
        assertTrue(timerControlsVisible(WidgetHeightClass.MEDIUM))
        assertTrue(timerControlsVisible(WidgetHeightClass.TALL))
    }

    @Test
    fun en_kucuk_kutuda_sayi_TEK_BASINA_sigar() {
        val spec = WidgetSizeSpecs.timer
        // minResize kosesi: 110x80dp.
        val size = widgetSizeClass(spec, 110, 80)
        val kisaDolgu = timerRootPaddingDp(size)
        assertEquals(WidgetWidthClass.NARROW, size.width)
        assertEquals(WidgetHeightClass.SHORT, size.height)
        assertFits(
            "timer/SHORT sayi yuksekligi",
            lineHeightDp(timerTimeSp(size)),
            usableDp(80, kisaDolgu),
        )
        assertFits(
            "timer/SHORT sayi genisligi",
            textWidthDp(timerTimeSp(size), timeChars),
            usableDp(110, kisaDolgu),
        )
    }

    @Test
    fun kontrol_satirli_her_kutuda_sayi_ve_48dp_hap_BIRLIKTE_sigar() {
        val spec = WidgetSizeSpecs.timer
        data class Kutu(val ad: String, val w: Int, val h: Int)
        listOf(
            // 2x2 varsayilan, 3x2, 4x2 (genis ama kisa), 2x3, 4x3.
            Kutu("2x2", 110, 110),
            Kutu("3x2", 180, 110),
            Kutu("4x2", 250, 110),
            Kutu("2x3", 110, 180),
            Kutu("4x3", 250, 180),
        ).forEach { kutu ->
            val size = widgetSizeClass(spec, kutu.w, kutu.h)
            assertTrue("${kutu.ad} kontrol satiri gizli", timerControlsVisible(size.height))
            val dolgu = timerRootPaddingDp(size)
            assertFits(
                "timer/${kutu.ad} sayi + 48dp hap",
                lineHeightDp(timerTimeSp(size)) +
                    WIDGET_DESIGN_ROW_GAP_DP +
                    WIDGET_MIN_TOUCH_TARGET_DP,
                usableDp(kutu.h, dolgu),
            )
            assertFits(
                "timer/${kutu.ad} sayi genisligi",
                textWidthDp(timerTimeSp(size), timeChars),
                usableDp(kutu.w, dolgu),
            )
        }
    }

    @Test
    fun genis_ama_KISA_kutuda_punto_tavanlanir() {
        // 🔴 Tavan olmasaydi 4x2'de 40sp'lik satir (52dp) + 4dp + 48dp = 104dp
        // gerekirdi, kutuda 88dp var. Tavan hangi dalin kirpildigini gizlemez,
        // dogru dali secer.
        val genisKisa = widgetSizeClass(WidgetSizeSpecs.timer, 250, 110)
        val genisUzun = widgetSizeClass(WidgetSizeSpecs.timer, 250, 180)
        assertEquals(WidgetWidthClass.WIDE, genisKisa.width)
        assertTrue(
            "kisa kutuda punto tavanlanmiyor",
            timerTimeSp(genisKisa) < WidgetTypography.timerTime.wide,
        )
        assertEquals(
            "uzun kutuda tavan uygulanmamali",
            WidgetTypography.timerTime.wide,
            timerTimeSp(genisUzun),
        )
    }

    // =======================================================================
    // IS 2 — ders hafizasi
    //
    // SABOTAJ: `rememberedSubjectId` govdesini `""` dondurecek sekilde geri al
    // -> yalniz bu bolum duser. Punto ve minimal widget iddialari YESIL kalir.
    // =======================================================================

    private fun prefsWith(vararg pairs: Pair<String, String>): SharedPreferences {
        val prefs = StrictStringPrefs()
        val editor = prefs.edit()
        pairs.forEach { (key, value) -> editor.putString(key, value) }
        editor.commit()
        return prefs
    }

    private fun subjectsJson(vararg rows: Triple<String, String, String>): String =
        rows.joinToString(prefix = "[", postfix = "]") { (id, userId, name) ->
            """{"id":"$id","user_id":"$userId","name":"$name","color":"#FF0000"}"""
        }

    @Test
    fun DOGRU_anahtar_okunur_kosan_kosunun_anlik_goruntusu_DEGIL() {
        // 🔴 Tuzak: `timer_active_subject` (TimerStateStore.KEY_SUBJECT)
        // KOSAN kosunun snapshot'idir ve kosu bitince silinir. Kalici tercih
        // WP-697'nin `selected_study_subject.<userId>` anahtaridir.
        val yalnizSnapshot = prefsWith(
            TimerStateStore.KEY_V2_ACTIVE_ACCOUNT_ID to "u1",
            TimerStateStore.KEY_SUBJECT to "mat",
        )
        assertEquals(
            "yanlis anahtar okunuyor: durunca silinen bir degere guveniliyor",
            "",
            rememberedSubjectId(yalnizSnapshot),
        )

        val kaliciTercih = prefsWith(
            TimerStateStore.KEY_V2_ACTIVE_ACCOUNT_ID to "u1",
            subjectPreferenceKey("u1") to "mat",
            subjectsCacheKey("u1") to subjectsJson(Triple("mat", "u1", "Matematik")),
        )
        assertEquals("mat", rememberedSubjectId(kaliciTercih))
    }

    @Test
    fun anahtar_adlari_Dart_tarafiyla_birebir() {
        // Dart: `_kSelectedStudySubjectPrefix` + `subjectsCacheKey`, Flutter
        // prefs'in `flutter.` oneki ile. Ayrisirsa native hicbir sey okumaz ve
        // kusur SESSIZ olur.
        assertEquals("flutter.selected_study_subject.u1", subjectPreferenceKey("u1"))
        assertEquals("flutter.subjects_cache.u1", subjectsCacheKey("u1"))
        assertEquals("__general__", WIDGET_SUBJECT_GENERAL)
    }

    @Test
    fun Genel_tercihi_derssiz_baslatir() {
        val prefs = prefsWith(
            TimerStateStore.KEY_V2_ACTIVE_ACCOUNT_ID to "u1",
            subjectPreferenceKey("u1") to WIDGET_SUBJECT_GENERAL,
            subjectsCacheKey("u1") to subjectsJson(Triple("mat", "u1", "Matematik")),
        )
        assertEquals("", rememberedSubjectId(prefs))
    }

    @Test
    fun oturum_yokken_ders_hatirlanmaz() {
        val prefs = prefsWith(subjectPreferenceKey("u1") to "mat")
        assertEquals("", rememberedSubjectId(prefs))
    }

    @Test
    fun silinmis_ders_ile_kosu_baslatilmaz() {
        // Ayna VARSA tercih dogrulanir: silinmis kimlikle kosu baslatmak
        // Dart'in acilista yabanci anahtar ihlali yazmasina yol acardi.
        val prefs = prefsWith(
            TimerStateStore.KEY_V2_ACTIVE_ACCOUNT_ID to "u1",
            subjectPreferenceKey("u1") to "silindi",
            subjectsCacheKey("u1") to subjectsJson(Triple("mat", "u1", "Matematik")),
        )
        assertEquals("", rememberedSubjectId(prefs))
    }

    @Test
    fun ayna_HIC_yoksa_tercih_oldugu_gibi_kabul_edilir() {
        // Dart'ta da "ayna yok" (null) ile "liste bos" ([]) bilerek ayri
        // seylerdir; ayna yokken tercihi silmek kullanicinin secimini yerdi.
        val prefs = prefsWith(
            TimerStateStore.KEY_V2_ACTIVE_ACCOUNT_ID to "u1",
            subjectPreferenceKey("u1") to "mat",
        )
        assertEquals("mat", rememberedSubjectId(prefs))
    }

    @Test
    fun baska_hesabin_dersi_sizmaz() {
        val prefs = prefsWith(
            TimerStateStore.KEY_V2_ACTIVE_ACCOUNT_ID to "u1",
            subjectPreferenceKey("u1") to "yabanci",
            subjectsCacheKey("u1") to subjectsJson(Triple("yabanci", "u2", "Fizik")),
        )
        assertEquals("", rememberedSubjectId(prefs))
        assertEquals(
            emptyList<WidgetSubject>(),
            widgetSubjectOptions(prefs, "u1"),
        )
    }

    @Test
    fun bozuk_ayna_sureci_oldurmez() {
        val prefs = prefsWith(
            TimerStateStore.KEY_V2_ACTIVE_ACCOUNT_ID to "u1",
            subjectPreferenceKey("u1") to "mat",
            subjectsCacheKey("u1") to "{bozuk",
        )
        // Ayristirilamayan ayna "liste yok" degil "liste bos" sayilir; tercih
        // dogrulanamadigi icin derssiz baslar. Onemli olan PATLAMAMASIDIR.
        assertEquals("", rememberedSubjectId(prefs))
    }

    // =======================================================================
    // IS 3 — widget'tan ders secimi (halka)
    //
    // SABOTAJ: `nextSubjectPreference`i her zaman `current` dondurecek sekilde
    // sabitle -> yalniz bu bolum duser.
    // =======================================================================

    private val dersler = listOf(
        WidgetSubject("mat", "Matematik"),
        WidgetSubject("fiz", "Fizik"),
    )

    @Test
    fun halka_Genel_ile_baslar_ve_Genele_doner() {
        assertEquals("mat", nextSubjectPreference(WIDGET_SUBJECT_GENERAL, dersler))
        assertEquals("fiz", nextSubjectPreference("mat", dersler))
        assertEquals(WIDGET_SUBJECT_GENERAL, nextSubjectPreference("fiz", dersler))
    }

    @Test
    fun tanimsiz_veya_silinmis_tercih_halkada_takilmaz() {
        // Silinmis bir ders sonsuza kadar secili kalmamali.
        assertEquals("mat", nextSubjectPreference("silindi", dersler))
        assertEquals("mat", nextSubjectPreference(null, dersler))
    }

    @Test
    fun ders_yoksa_halka_Genelde_kalir() {
        assertEquals(
            WIDGET_SUBJECT_GENERAL,
            nextSubjectPreference("mat", emptyList()),
        )
    }

    @Test
    fun hap_metni_ders_adini_gosterir() {
        assertEquals("Matematik", widgetSubjectLabel("mat", dersler))
        assertEquals(WIDGET_SUBJECT_NONE_LABEL, widgetSubjectLabel(WIDGET_SUBJECT_GENERAL, dersler))
        assertEquals(WIDGET_SUBJECT_NONE_LABEL, widgetSubjectLabel(null, dersler))
        // Gomulu Turkce metin yok: isaret bir SIMGE.
        assertEquals("—", WIDGET_SUBJECT_NONE_LABEL)
    }

    @Test
    fun ders_hapi_yalniz_yeri_oldugunda_cizilir() {
        // Iki eksenli kural: satirin yarisina dusen genislik MEDIUM altinda
        // "Durdur" bile sigmaz, SHORT yukseklikte satir zaten yok.
        val spec = WidgetSizeSpecs.timer
        assertFalse(timerSubjectVisible(widgetSizeClass(spec, 110, 110))) // 2x2
        assertFalse(timerSubjectVisible(widgetSizeClass(spec, 250, 80)))  // 4x1
        assertTrue(timerSubjectVisible(widgetSizeClass(spec, 180, 110)))  // 3x2
        assertTrue(timerSubjectVisible(widgetSizeClass(spec, 250, 180)))  // 4x3
    }

    @Test
    fun ders_hapi_gorunurken_iki_kontrol_de_satira_sigar() {
        val spec = WidgetSizeSpecs.timer
        listOf(150 to "MEDIUM sinir", 180 to "3x2", 250 to "4x2").forEach { (kutu, ad) ->
            val size = widgetSizeClass(spec, kutu, 110)
            assertTrue("$ad: hap gizli", timerSubjectVisible(size))
            val dolgu = timerRootPaddingDp(size)
            // Satir esit iki paya bolunur (`layout_weight=1` + `0dp`).
            val yarim = (usableDp(kutu, dolgu) - WIDGET_DESIGN_ROW_GAP_DP) / 2f
            assertFits(
                "$ad: Baslat/Durdur",
                textWidthDp(WidgetTypography.timerAction.of(size.width), actionChars) +
                    2f * WIDGET_TIMER_PILL_H_PADDING_DP,
                yarim,
            )
            // Ders adi kirpilabilir (ellipsize) ama en az dort karakter
            // gorunmeli; yoksa hap hicbir sey soylemez.
            assertFits(
                "$ad: ders adi (4 karakter)",
                textWidthDp(WidgetTypography.timerSubject.of(size.width), 4) +
                    2f * WIDGET_TIMER_PILL_H_PADDING_DP,
                yarim,
            )
        }
    }

    // =======================================================================
    // IS 4 — minimal sayac widget'i
    //
    // SABOTAJ: `minimalTimerHeightCapSp` tavanini kaldir -> yalniz bu bolum
    // duser (40dp'lik satirda 38sp kirpilir).
    // =======================================================================

    @Test
    fun minimal_widget_beyani_hucre_formuluyle_tutarli() {
        // `70n - 30`: 2 hucre = 110dp, 1 hucre = 40dp.
        assertEquals(110, WIDGET_MINIMAL_TIMER_DEFAULT_WIDTH_DP)
        assertEquals(40, WIDGET_MINIMAL_TIMER_DEFAULT_HEIGHT_DP)
        assertEquals(70 * 2 - 30, WIDGET_MINIMAL_TIMER_DEFAULT_WIDTH_DP)
        assertEquals(70 * 1 - 30, WIDGET_MINIMAL_TIMER_DEFAULT_HEIGHT_DP)
    }

    @Test
    fun minimal_widget_hicbir_boyutta_kirpilmaz() {
        val dolgu = WIDGET_MINIMAL_TIMER_PADDING_DP
        data class Kutu(val ad: String, val w: Int, val h: Int)
        listOf(
            // 🔴 "1x1" kutusu 40dp DEGIL 70dp: beyandaki 40dp yalniz
            // yerlestirme olcusudur; launcher widget'i gercek hucresine cizer
            // ve `getAppWidgetOptions` o olcuyu bildirir (yaygin telefonlarda
            // ~70-85dp). Modeli 40dp ile kurmak, kullanicinin hic gormedigi
            // bir kutuyu olcmek olurdu.
            Kutu("1x1 (gercek hucre)", 70, 70),
            Kutu("2x1 (varsayilan)", 110, 40),
            Kutu("3x1", 180, 40),
            Kutu("4x1", 250, 40),
            Kutu("2x2", 110, 110),
            Kutu("4x2", 250, 110),
        ).forEach { kutu ->
            val sp = minimalTimerTimeSp(kutu.w, kutu.h)
            assertFits(
                "minimal/${kutu.ad} yukseklik",
                lineHeightDp(sp),
                usableDp(kutu.h, dolgu),
            )
            // WP-728: idle 5 karakterle yetinmek saatin dolmasindan sonraki
            // kirpmayi gizliyordu. Her kutu calisan en kotu 8 karakterle olculur.
            val karakter = timeChars
            assertFits(
                "minimal/${kutu.ad} genislik",
                textWidthDp(sp, karakter) * WIDGET_MINIMAL_TIMER_TEXT_SCALE_X,
                usableDp(kutu.w, dolgu),
            )
        }
    }

    @Test
    fun minimal_widget_varsayilan_boyutta_sayacin_en_kucuk_halinden_BUYUK_yazar() {
        // Widget'in varlik sebebi: 1-2 hucrede okunur bir sayi. Eski sayac
        // widget'i o boyutta 15sp yaziyordu.
        assertTrue(minimalTimerTimeSp(110, 40) > puntoOncesi.narrow)
        assertEquals(21f, minimalTimerTimeSp(110, 40))
    }

    @Test
    fun minimal_widget_punto_merdiveni_gercekten_yukselir() {
        assertTrue(minimalTimerTypography.medium > minimalTimerTypography.narrow)
        assertTrue(minimalTimerTypography.wide > minimalTimerTypography.medium)
        // Tavan gercekten TAVAN: 4x1'de genislik 38sp'ye izin verse de
        // 40dp'lik satir 21sp'de keser.
        val genisKisa = widgetSizeClass(minimalTimerSizeSpec, 250, 40)
        assertEquals(WidgetWidthClass.WIDE, genisKisa.width)
        assertNotEquals(minimalTimerTypography.wide, minimalTimerTimeSp(250, 40))
        assertEquals(21f, minimalTimerTimeSp(250, 40))
    }
}

/**
 * `SharedPreferencesImpl` ile ayni tip sertligi (yalniz String yolu).
 *
 * Gevsek bir sahte prefs, yanlis tiple okunan bir anahtari hic gostermezdi —
 * v58'de sureci olduren kusur tam olarak buydu (`TimerPrefsTypeContractTest`).
 */
private class StrictStringPrefs : SharedPreferences {
    private val values = LinkedHashMap<String, Any>()

    override fun getAll(): MutableMap<String, *> = values

    override fun getString(key: String?, defValue: String?): String? =
        values[key]?.let { it as String } ?: defValue

    @Suppress("UNCHECKED_CAST")
    override fun getStringSet(key: String?, defValues: MutableSet<String>?): MutableSet<String>? =
        values[key]?.let { it as MutableSet<String> } ?: defValues

    override fun getInt(key: String?, defValue: Int): Int =
        values[key]?.let { it as Int } ?: defValue

    override fun getLong(key: String?, defValue: Long): Long =
        values[key]?.let { it as Long } ?: defValue

    override fun getFloat(key: String?, defValue: Float): Float =
        values[key]?.let { it as Float } ?: defValue

    override fun getBoolean(key: String?, defValue: Boolean): Boolean =
        values[key]?.let { it as Boolean } ?: defValue

    override fun contains(key: String?): Boolean = key != null && values.containsKey(key)

    override fun edit(): SharedPreferences.Editor = Editor(values)

    override fun registerOnSharedPreferenceChangeListener(
        listener: SharedPreferences.OnSharedPreferenceChangeListener?,
    ) = Unit

    override fun unregisterOnSharedPreferenceChangeListener(
        listener: SharedPreferences.OnSharedPreferenceChangeListener?,
    ) = Unit

    private class Editor(
        private val target: LinkedHashMap<String, Any>,
    ) : SharedPreferences.Editor {
        private val staged = LinkedHashMap<String, Any?>()

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
            target.clear()
            return this
        }

        override fun commit(): Boolean {
            staged.forEach { (key, value) ->
                if (value == null) target.remove(key) else target[key] = value
            }
            staged.clear()
            return true
        }

        override fun apply() {
            commit()
        }
    }
}
