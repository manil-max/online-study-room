package com.manilmax.online_study_room.overlay

import android.content.SharedPreferences
import android.os.Build
import android.view.WindowManager
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * WP-764 — yuzen sayac seridinin **saf** kararlari.
 *
 * Bu dosya pencerenin gercekten cizildigini OLCMEZ ve olctugunu iddia ETMEZ;
 * o cihaz kanitidir. Olculen sey, cizim kararina giden mantiktir.
 *
 * 🔴 Bu ayrim bu turda pahaliya mal oldu. WP-762 "muhtemelen boyle olmali"
 * diyip cihazsiz yayina cikti ve calisan bildirimi bozdu. Buradaki her iddia
 * cihazsiz DOGRULANABILIR bir seyi olcer; cihazda olculecek seyler acikca
 * disarida birakildi.
 */
class TimerOverlayWp764Test {

    // -----------------------------------------------------------------------
    // A) SERIT KAPALI DOGAR.
    // -----------------------------------------------------------------------

    /**
     * 🔴 BU DOSYANIN EN ONEMLI IDDIASI.
     *
     * Bu turda UC KEZ deneysel bir yol VARSAYILAN yapildi ve calisan bildirim
     * bozuldu: WP-753 v71'de, WP-762 v74'te. Sahip kurali kendi cumlesiyle
     * koydu: "test ederken sadece biz gorelim, surumlerde digerlerinde normal
     * olsun; biz yapana kadar bozulmasin."
     *
     * Serit, anahtar hic yazilmamisken KAPALIDIR. Bu bir uslup tercihi degil,
     * ucuncu kez ihlal edilmis bir kuralin kod karsiligidir.
     */
    @Test
    fun the_overlay_is_off_until_someone_deliberately_turns_it_on() {
        val fresh = Wp764Prefs()
        assertFalse(
            "Anahtar yazilmamisken serit KAPALI olmali",
            TimerOverlay.isEnabled(fresh),
        )

        val on = Wp764Prefs()
        on.edit().putBoolean(TimerOverlay.KEY_ENABLED, true).commit()
        assertTrue(TimerOverlay.isEnabled(on))

        val off = Wp764Prefs()
        off.edit().putBoolean(TimerOverlay.KEY_ENABLED, false).commit()
        assertFalse(TimerOverlay.isEnabled(off))
    }

    /**
     * Uc kosulun UCU de sart ve ucu de AYRI seyler.
     *
     * 🔴 "Izin var" ile "kullanici istedi" ayni sey DEGILDIR. Izni gecmiste
     * vermis ama seridi kapatmis bir kullaniciya serit gostermek, ayarinin
     * hicbir seye yaramadigi anlamina gelir.
     */
    @Test
    fun nothing_is_drawn_unless_all_three_conditions_hold() {
        assertTrue(TimerOverlay.shouldShow(enabled = true, permitted = true, running = true))

        assertFalse(
            "Kullanici acmadiysa izin VARSA BILE cizilmez",
            TimerOverlay.shouldShow(enabled = false, permitted = true, running = true),
        )
        assertFalse(
            "Izin yoksa cizilemez",
            TimerOverlay.shouldShow(enabled = true, permitted = false, running = true),
        )
        assertFalse(
            "Sayac kosmuyorsa gosterecek bir sey yok",
            TimerOverlay.shouldShow(enabled = true, permitted = true, running = false),
        )
    }

    /**
     * Kullanici seridi actiysa ama izin yoksa, ona yalniz "calismiyor" demek
     * yetmez -- izni verecegi yeri de gostermek gerekir.
     *
     * 🔴 `SYSTEM_ALERT_WINDOW` normal bir calisma-zamani izni DEGILDIR: bir
     * izin penceresiyle istenemez, kullanici Ayarlar'da elle acar. Yolu
     * gostermeyen bir anahtar, sessizce calismayan bir anahtardir.
     */
    @Test
    fun an_enabled_overlay_without_permission_must_point_at_the_settings_screen() {
        assertTrue(
            TimerOverlay.permissionSettingsIntentNeeded(enabled = true, permitted = false),
        )
        assertFalse(
            "Izin zaten varsa kullaniciyi Ayarlar'a gondermek gurultudur",
            TimerOverlay.permissionSettingsIntentNeeded(enabled = true, permitted = true),
        )
        assertFalse(
            "Kullanici seridi istemiyorsa izin de istemiyoruz",
            TimerOverlay.permissionSettingsIntentNeeded(enabled = false, permitted = false),
        )
    }

    // -----------------------------------------------------------------------
    // B) PENCERE TURU.
    // -----------------------------------------------------------------------

    /**
     * `TYPE_APPLICATION_OVERLAY` API 26'da geldi; bu uygulamanin minSdk'si daha
     * dusuk oldugu icin eski cihazlarda `TYPE_PHONE` gerekir.
     *
     * 🔴 Yanlis tur `BadTokenException` ile CIHAZDA coker, derlemede degil --
     * yani ancak eski bir telefonda fark edilirdi.
     */
    @Test
    fun the_window_type_matches_the_platform() {
        assertEquals(
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            TimerOverlay.windowType(Build.VERSION_CODES.O),
        )
        assertEquals(
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            TimerOverlay.windowType(36),
        )
        @Suppress("DEPRECATION")
        assertEquals(
            "API 26 ONCESI overlay turu yok; TYPE_PHONE kullanilir",
            WindowManager.LayoutParams.TYPE_PHONE,
            TimerOverlay.windowType(Build.VERSION_CODES.N),
        )
    }

    // -----------------------------------------------------------------------
    // C) DOKUNMA: surukleme mi tiklama mi.
    // -----------------------------------------------------------------------

    /**
     * 🔴 Esik olmadan serit TIKLANAMAZ hale gelir: parmak birkac piksel kayar,
     * `ACTION_UP` surukleme sayilir ve dokunma hicbir sey yapmaz. Kullanici
     * "serit bozuk, basinca acilmiyor" der ve hakli olur.
     */
    @Test
    fun a_few_pixels_of_finger_wobble_is_still_a_tap() {
        val slop = 16

        assertFalse("2 piksel kayma tiklamadir", TimerOverlay.isDrag(2f, -1f, slop))
        assertFalse("esigin tam altinda hala tiklama", TimerOverlay.isDrag(15f, 15f, slop))

        assertTrue("esikte surukleme baslar", TimerOverlay.isDrag(16f, 0f, slop))
        assertTrue("dikey surukleme de sayilir", TimerOverlay.isDrag(0f, -40f, slop))
        assertTrue("tek eksende asmak yeter", TimerOverlay.isDrag(-30f, 3f, slop))
    }

    // -----------------------------------------------------------------------
    // D) SERIT EKRANDAN KACAMAZ.
    // -----------------------------------------------------------------------

    /**
     * 🔴 Konum KALICI yazilir. Serit bir kez ekran disina suruklenirse bir daha
     * yakalanamaz ve her acilista oraya geri dondugu icin SONSUZA KADAR
     * gorunmez kalirdi. Kullanicinin elinde kalan tek care uygulama verisini
     * silmek olurdu.
     */
    @Test
    fun the_pill_can_never_be_dragged_off_the_screen() {
        val screenW = 1080
        val screenH = 2400
        val pillW = 300
        val pillH = 120

        assertEquals(0, TimerOverlay.clampX(-500, pillW, screenW))
        assertEquals(0, TimerOverlay.clampY(-500, pillH, screenH))
        assertEquals(screenW - pillW, TimerOverlay.clampX(9999, pillW, screenW))
        assertEquals(screenH - pillH, TimerOverlay.clampY(9999, pillH, screenH))

        // Ekran icindeki konum oldugu gibi korunur.
        assertEquals(120, TimerOverlay.clampX(120, pillW, screenW))
        assertEquals(640, TimerOverlay.clampY(640, pillH, screenH))
    }

    /**
     * Serit ekrandan GENISSE (kucuk ekran / buyuk yazi olcegi) sinir negatife
     * duser ve `coerceIn` cokerdi (`IllegalArgumentException: minimum > maximum`).
     */
    @Test
    fun a_pill_wider_than_the_screen_does_not_crash_the_clamp() {
        assertEquals(0, TimerOverlay.clampX(50, 1200, 1080))
        assertEquals(0, TimerOverlay.clampY(50, 3000, 2400))
    }
}

/** Yalniz bu testin ihtiyaci kadar `SharedPreferences`. */
private class Wp764Prefs : SharedPreferences {
    private val values = mutableMapOf<String, Any?>()

    override fun getBoolean(key: String, defValue: Boolean): Boolean =
        values[key] as? Boolean ?: defValue

    override fun getInt(key: String, defValue: Int): Int = values[key] as? Int ?: defValue

    override fun getString(key: String, defValue: String?): String? =
        values[key] as? String ?: defValue

    override fun getAll(): MutableMap<String, *> = values
    override fun getStringSet(key: String, defValues: MutableSet<String>?) = defValues
    override fun getLong(key: String, defValue: Long): Long = values[key] as? Long ?: defValue
    override fun getFloat(key: String, defValue: Float): Float = values[key] as? Float ?: defValue
    override fun contains(key: String): Boolean = values.containsKey(key)
    override fun registerOnSharedPreferenceChangeListener(
        listener: SharedPreferences.OnSharedPreferenceChangeListener?,
    ) = Unit
    override fun unregisterOnSharedPreferenceChangeListener(
        listener: SharedPreferences.OnSharedPreferenceChangeListener?,
    ) = Unit

    override fun edit(): SharedPreferences.Editor = Wp764Editor(values)
}

private class Wp764Editor(
    private val target: MutableMap<String, Any?>,
) : SharedPreferences.Editor {
    private val staged = mutableMapOf<String, Any?>()

    override fun putBoolean(key: String, value: Boolean) = apply { staged[key] = value }
    override fun putInt(key: String, value: Int) = apply { staged[key] = value }
    override fun putString(key: String, value: String?) = apply { staged[key] = value }
    override fun putStringSet(key: String, values: MutableSet<String>?) = apply {
        staged[key] = values
    }
    override fun putLong(key: String, value: Long) = apply { staged[key] = value }
    override fun putFloat(key: String, value: Float) = apply { staged[key] = value }
    override fun remove(key: String) = apply { staged[key] = REMOVE }
    override fun clear() = apply { staged.clear(); target.clear() }

    override fun commit(): Boolean {
        staged.forEach { (k, v) -> if (v === REMOVE) target.remove(k) else target[k] = v }
        staged.clear()
        return true
    }

    override fun apply() {
        commit()
    }

    private companion object {
        val REMOVE = Any()
    }
}
