package com.manilmax.online_study_room.timer

import android.content.SharedPreferences
import com.manilmax.online_study_room.timer.TimerPromotion.Verdict
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * WP-759 (dinamik-panel) nobetcisi — **terfi bir istek degil bir sonuctur.**
 *
 * Olctugu tek cumle:
 *
 *     Izin sorgusu "olur" dedi, sozlesme eksiksizdi, sistem YINE DE terfi
 *     etmedi. Uygulama bunu ogrenebiliyor mu?
 *
 * v71'de cevap hayirdi. Kanit:
 * `.artifacts/wp759-goruntu/32-api36-dumpsys-notification.txt` satir 45
 * (`android.requestPromotedOngoing=Boolean (true)`) ile satir 3
 * (`flags=ONGOING_EVENT|ONLY_ALERT_ONCE|NO_CLEAR|FOREGROUND_SERVICE`).
 *
 * Ve sebep uygulama kodu degildi:
 * `.artifacts/wp759-terfi-olcum/01-api36-TERFI-NEDEN-OLMUYOR.txt` —
 * Android 16 emulator imajinda `POST_PROMOTED_NOTIFICATIONS` izni platformda
 * TANIMLI DEGIL ve terfiyi cizen SystemUI bayraklari yok. Boyle bir cihazda
 * onkosullarin hepsi "evet" diyebilir; terfi yine olmaz.
 *
 * OLCTUGU: gozlemin onkosulu ezmesi, gozlemin kalici olmasi, ve
 * "olcemedim"in "hayir" ile karistirilmamasi.
 * OLCMEDIGI (ve olctugunu IDDIA ETMEDIGI): cipin cizilmesi, Now Bar, kilit
 * ekrani, `canPostPromotedNotifications()` cagrisinin gercek donusu. Onlar
 * cihaz kanitidir.
 */
class TimerPromotionCapabilityWp759Test {

    /** Olculen gercek bayrak kumesi (32-api36-dumpsys-notification.txt:3). */
    private val measuredOnApi36 =
        FLAG_ONGOING_EVENT or FLAG_ONLY_ALERT_ONCE or FLAG_NO_CLEAR or FLAG_FOREGROUND_SERVICE

    // -----------------------------------------------------------------------
    // SON KAPI: gozlenen sonuc.
    // -----------------------------------------------------------------------

    /**
     * 🔴 BU TURUN ANA NOBETCISI.
     *
     * Onkosullar gecti (`preconditionsMet = true`) ama gonderilen bildirimde
     * `FLAG_PROMOTED_ONGOING` hic gorulmedi. Gozlem onkosulu EZMELI; yoksa
     * uygulama sonsuza kadar terfi etmeyecek bir yolda kalir ve kullanici
     * her Baslat'ta bozuk karti gorur. v71'de tam olarak bu oldu.
     */
    @Test
    fun an_observed_denial_outranks_a_permissive_precondition() {
        val observed = TimerPromotion.observedVerdict(sdkInt = 36, postedFlags = measuredOnApi36)
        assertEquals(Verdict.DENIED, observed)

        val effective = TimerPromotion.effectiveVerdict(
            preconditionsMet = true,
            observed = observed,
        )

        assertEquals(
            "Onkosullar 'olur' dese de sistem terfi etmediyse yol KAPALI",
            Verdict.DENIED,
            effective,
        )
        assertFalse(TimerPromotion.mayRequestPromotion(effective))
    }

    /**
     * Olculen emulator durumunun ucdan uca karsiligi: onkosullari gecen bir
     * cihaz, BIR kere dener, terfi alamaz, ve bir daha o yola girmez.
     */
    @Test
    fun the_measured_api36_emulator_closes_the_path_after_one_try() {
        val prefs = Wp759PromotionPrefs()

        // Once: hic olcum yok -> bir deneme hakki.
        val before = TimerPromotion.effectiveVerdict(
            preconditionsMet = true,
            observed = TimerPromotion.readVerdict(prefs),
        )
        assertEquals(Verdict.GRANTED, before)
        assertTrue(
            "Hic denenmemis cihaz bir kere denemeli, yoksa kapi kendini kilitler",
            TimerPromotion.mayRequestPromotion(before),
        )

        // Bildirim gonderildi, geri okundu: PROMOTED_ONGOING yok.
        TimerPromotion.writeVerdict(
            prefs,
            TimerPromotion.observedVerdict(sdkInt = 36, postedFlags = measuredOnApi36),
        )

        // Sonra: olcum yapildi, terfi yok -> yol kalici kapali.
        val after = TimerPromotion.effectiveVerdict(
            preconditionsMet = true,
            observed = TimerPromotion.readVerdict(prefs),
        )
        assertEquals(Verdict.DENIED, after)
        assertFalse(
            "Ikinci Baslat'ta kullanici bozuk karti BIR DAHA gormemeli",
            TimerPromotion.mayRequestPromotion(after),
        )
    }

    /** Bayrak gercekten yazilmissa terfi VERILMIS demektir. */
    @Test
    fun the_promoted_flag_is_what_grants_promotion() {
        assertEquals(
            Verdict.GRANTED,
            TimerPromotion.observedVerdict(
                sdkInt = 36,
                postedFlags = measuredOnApi36 or TimerPromotion.FLAG_PROMOTED_ONGOING,
            ),
        )
    }

    /**
     * 🔴 "Olcemedim" ile "hayir" ayni sey DEGILDIR.
     *
     * Bildirimi henuz goremiyorsak bu bir red degildir; aksi halde gonderim
     * ile okuma arasindaki tek bir yaris cihazi kalici olarak damgalardi.
     */
    @Test
    fun a_notification_we_cannot_see_yet_is_not_a_denial() {
        assertNull(TimerPromotion.observedVerdict(sdkInt = 36, postedFlags = null))

        // Ve olcum yokken onkosul ne diyorsa o gecerlidir.
        assertEquals(
            Verdict.GRANTED,
            TimerPromotion.effectiveVerdict(preconditionsMet = true, observed = null),
        )
    }

    /**
     * API 36'nin altinda terfi diye bir sey YOKTUR.
     *
     * Bagli emulator `emulator-5554` tam olarak budur (API 33). Alti turdur
     * bu ozelligin calismamasinin bir sebebi de onu calisabilecegi bir
     * ortamda hic gorulmemis olmasidir.
     */
    @Test
    fun there_is_nothing_to_observe_below_api_36() {
        for (sdk in listOf(24, 29, 33, 34, 35)) {
            assertNull(
                "API $sdk terfiyi bilmiyor",
                TimerPromotion.observedVerdict(
                    sdkInt = sdk,
                    postedFlags = measuredOnApi36 or TimerPromotion.FLAG_PROMOTED_ONGOING,
                ),
            )
        }
    }

    /**
     * Onkosul gecmiyorsa diskteki gozlem yolu ACAMAZ.
     *
     * Ornek: kullanici Android 16 cihazdan yedek alip API 33 cihaza geri
     * yukledi; `GRANTED` verdict'i onunla birlikte tasindi.
     */
    @Test
    fun a_stored_grant_cannot_talk_an_incapable_device_into_promoting() {
        assertEquals(
            Verdict.UNSUPPORTED,
            TimerPromotion.effectiveVerdict(
                preconditionsMet = false,
                observed = Verdict.GRANTED,
            ),
        )
        assertFalse(
            TimerPromotion.mayRequestPromotion(
                TimerPromotion.effectiveVerdict(false, Verdict.GRANTED),
            ),
        )
    }

    /** Onkosul sorulamiyorsa (API yok / cagri dustu) bu bir 'evet' degildir. */
    @Test
    fun an_unanswerable_precondition_is_not_a_yes() {
        assertEquals(
            Verdict.UNSUPPORTED,
            TimerPromotion.effectiveVerdict(preconditionsMet = false, observed = null),
        )
    }

    // -----------------------------------------------------------------------
    // Kalicilik.
    // -----------------------------------------------------------------------

    /** Yalniz KESIN verdictler yazilir; "bilmiyoruz" diske gecmez. */
    @Test
    fun only_a_decisive_verdict_is_persisted() {
        val prefs = Wp759PromotionPrefs()

        TimerPromotion.writeVerdict(prefs, null)
        assertNull(
            "'olcemedim' yazilirsa bir sonraki gercek olcum bloke olurdu",
            TimerPromotion.readVerdict(prefs),
        )

        TimerPromotion.writeVerdict(prefs, Verdict.UNSUPPORTED)
        assertNull(TimerPromotion.readVerdict(prefs))

        TimerPromotion.writeVerdict(prefs, Verdict.DENIED)
        assertEquals(Verdict.DENIED, TimerPromotion.readVerdict(prefs))

        TimerPromotion.writeVerdict(prefs, Verdict.GRANTED)
        assertEquals(Verdict.GRANTED, TimerPromotion.readVerdict(prefs))
    }

    /** Taninmayan/bozuk deger sessizce "hic olculmedi" sayilir. */
    @Test
    fun a_corrupt_stored_verdict_degrades_to_unmeasured() {
        val prefs = Wp759PromotionPrefs()
        prefs.edit().putString(TimerPromotion.KEY_VERDICT, "MAYBE").commit()
        assertNull(TimerPromotion.readVerdict(prefs))
    }

    /** Kopyalanan platform sabiti sessizce kaymamali. */
    @Test
    fun the_copied_platform_flag_still_matches_the_platform() {
        // javap -constants -classpath <sdk>/platforms/android-36/android.jar \
        //     android.app.Notification
        //   public static final int FLAG_PROMOTED_ONGOING = 262144;
        assertEquals(262144, TimerPromotion.FLAG_PROMOTED_ONGOING)
        assertEquals(36, TimerPromotion.MIN_SDK)
    }

    private companion object {
        const val FLAG_ONGOING_EVENT = 0x2
        const val FLAG_ONLY_ALERT_ONCE = 0x8
        const val FLAG_NO_CLEAR = 0x20
        const val FLAG_FOREGROUND_SERVICE = 0x40
    }

    // 🔴 WP-759 DIKISI — YAPI DAMGASI NOBETCISI
    //
    // Bu turda `odak_api36` imajinda terfinin IMKANSIZ oldugu olculdu:
    // POST_PROMOTED_NOTIFICATIONS izni platformda tanimli degil ve cizen
    // arayuz bayragi imajda yok. Yani o cihaz DENIED yazacak -- dogrusu da bu.
    //
    // Ama damgasiz bir DENIED KALICI BIR TAVANDIR: kullanici ilerde terfiyi
    // acan bir guncelleme alsa bile uygulama bir daha ASLA denemez. Tek bir
    // olcum, ozelligi sonsuza kadar kapatirdi. Damga bunu kirar.
    @Test
    fun a_verdict_measured_on_another_build_is_not_trusted() {
        val prefs = Wp759PromotionPrefs()

        TimerPromotion.writeVerdict(prefs, Verdict.DENIED, fingerprint = "eski/yapi:16/AAA")
        assertEquals(
            "ayni yapida okunan verdict gecerlidir",
            Verdict.DENIED,
            TimerPromotion.readVerdict(prefs, fingerprint = "eski/yapi:16/AAA"),
        )
        assertNull(
            "yapi degistiyse eski olcum GECERSIZDIR; yoksa DENIED kalici tavan olur",
            TimerPromotion.readVerdict(prefs, fingerprint = "yeni/yapi:16/BBB"),
        )
    }

    @Test
    fun a_stamped_denial_reopens_the_path_after_a_system_update() {
        val prefs = Wp759PromotionPrefs()
        TimerPromotion.writeVerdict(prefs, Verdict.DENIED, fingerprint = "eski/yapi:16/AAA")

        // Ayni yapida: yol kapali kalir, gereksiz deneme yapilmaz.
        assertFalse(
            TimerPromotion.mayRequestPromotion(
                TimerPromotion.effectiveVerdict(
                    preconditionsMet = true,
                    observed = TimerPromotion.readVerdict(prefs, fingerprint = "eski/yapi:16/AAA"),
                ),
            ),
        )

        // Guncellemeden sonra: bir deneme hakki GERI GELIR.
        assertTrue(
            "sistem guncellendiyse uygulama terfiyi bir kez daha denemeli",
            TimerPromotion.mayRequestPromotion(
                TimerPromotion.effectiveVerdict(
                    preconditionsMet = true,
                    observed = TimerPromotion.readVerdict(prefs, fingerprint = "yeni/yapi:16/BBB"),
                ),
            ),
        )
    }

    @Test
    fun the_stamp_never_breaks_device_free_measurement() {
        // `Build.FINGERPRINT` unmocked android.jar uzerinde NULL'dur ve damgayi
        // dogrudan varsayilan yapmak butun JVM testlerini NPE ile dusurmustu.
        // Bu dosyanin acik tasarim hedefi cihazsiz olculebilir olmak.
        val prefs = Wp759PromotionPrefs()
        TimerPromotion.writeVerdict(prefs, Verdict.GRANTED)
        assertEquals(Verdict.GRANTED, TimerPromotion.readVerdict(prefs))
    }
}

/** Yalniz bu testin ihtiyaci kadar `SharedPreferences`. */
private class Wp759PromotionPrefs : SharedPreferences {
    private val values = LinkedHashMap<String, Any?>()

    override fun getAll(): MutableMap<String, *> = values

    override fun getString(key: String?, defValue: String?): String? =
        values[key] as? String ?: defValue

    override fun getStringSet(
        key: String?,
        defValues: MutableSet<String>?,
    ): MutableSet<String>? {
        @Suppress("UNCHECKED_CAST")
        return values[key] as? MutableSet<String> ?: defValues
    }

    override fun getInt(key: String?, defValue: Int): Int = values[key] as? Int ?: defValue

    override fun getLong(key: String?, defValue: Long): Long = values[key] as? Long ?: defValue

    override fun getFloat(key: String?, defValue: Float): Float =
        values[key] as? Float ?: defValue

    override fun getBoolean(key: String?, defValue: Boolean): Boolean =
        values[key] as? Boolean ?: defValue

    override fun contains(key: String?): Boolean = values.containsKey(key)

    override fun edit(): SharedPreferences.Editor = Wp759PromotionEditor(values)

    override fun registerOnSharedPreferenceChangeListener(
        listener: SharedPreferences.OnSharedPreferenceChangeListener?,
    ) = Unit

    override fun unregisterOnSharedPreferenceChangeListener(
        listener: SharedPreferences.OnSharedPreferenceChangeListener?,
    ) = Unit
}

private class Wp759PromotionEditor(
    private val target: LinkedHashMap<String, Any?>,
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
