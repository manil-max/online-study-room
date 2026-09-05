package com.manilmax.online_study_room.timer

import android.content.SharedPreferences
import com.manilmax.online_study_room.R
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * WP-753: Android Live Update (promoted ongoing) sözleşmesinin nöbetçisi.
 *
 * Altı denemenin kök nedeni tek cümleydi: **özel `RemoteViews` taşıyan bildirim
 * terfi edemez.** Her turda ikisi aynı bildirimde tutulmaya çalışıldı. Bu test
 * o çelişkiyi cihazsız yakalar — karar `Notification` nesnesinde değil, saf
 * [runningTimerNotificationPlan] içinde verildiği için ölçülebilir.
 *
 * Ölçülemeyen (ve bu testin ölçtüğünü İDDİA ETMEDİĞİ) şeyler: çipin gerçekten
 * çizilmesi, Now Bar, kilit ekranı, AOD. Onlar cihaz kanıtıdır.
 */
class TimerLiveUpdateWp753Test {

    private val startedAt = 1_700_000_000_000L

    @Test
    fun stopwatch_uses_standard_style_and_requests_promotion() {
        val plan = runningTimerNotificationPlan(
            richPanel = false,
            isBreak = false,
            targetSeconds = null,
            startedAtMs = startedAt,
            nowMs = startedAt + 90_000L,
        )

        assertEquals(TimerNotificationStyle.STANDARD, plan.style)
        assertTrue(plan.requestPromotedOngoing)
        // Resmî şart 1: açık uçlu kronometrenin üst sınırı yok, ProgressStyle
        // yanlış olurdu (yüzde diye bir şey yok).
        assertEquals(0, plan.totalSeconds)
        // `when` başlangıç anıdır; kronometre oradan itibaren YUKARI sayar.
        // 🔴 WP-772: çip metni 0. Metin verilirse çip saati gizler (S23'te
        // ölçüldü: "Focus" yazdı, sayaç görünmedi).
        assertEquals(startedAt, plan.whenMs)
        assertFalse(plan.countDown)
        assertEquals(0, plan.shortCriticalTextRes)
    }

    @Test
    fun targeted_mode_uses_progress_style_with_a_real_percentage() {
        val plan = runningTimerNotificationPlan(
            richPanel = false,
            isBreak = false,
            targetSeconds = 1500,
            startedAtMs = startedAt,
            nowMs = startedAt + 300_000L,
        )

        assertEquals(TimerNotificationStyle.PROGRESS, plan.style)
        assertTrue(plan.requestPromotedOngoing)
        assertEquals(1500, plan.totalSeconds)
        assertEquals(300, plan.progressSeconds)
        // `when` bitiş anıdır → GELECEKTEDİR, çipte canlı geri sayım akar.
        assertEquals(startedAt + 1_500_000L, plan.whenMs)
        assertTrue(plan.countDown)
        // Sabit kısa metin canlı geri sayımı gölgelemesin diye yazılmaz.
        // 🔴 IDDIA IKINCI KEZ YON DEGISTIRDI (WP-772). WP-762 metni zorunlu
        // yapmisti; cihazda olculdu: cip metni SAATI GIZLIYOR. Cipin hic
        // cizilmemesinin sebebi Samsung'un onay listesiydi, metin degil.
        assertEquals(
            "Hedefi olan modda cip metni GONDERILMEZ; cip geri sayimi cizer",
            0,
            plan.shortCriticalTextRes,
        )
    }

    /**
     * 🔴 Bu WP'nin bütün anlamı. Resmî şart:
     * *"Must NOT have any customContentView set (no RemoteViews)."*
     * Terfi istenen HİÇBİR yol özel görünüm taşımamalı.
     */
    @Test
    fun promoted_path_never_carries_a_custom_view() {
        val promotedPlans = listOf(
            runningTimerNotificationPlan(false, false, null, startedAt, startedAt),
            runningTimerNotificationPlan(false, true, null, startedAt, startedAt),
            runningTimerNotificationPlan(false, false, 1500, startedAt, startedAt),
            runningTimerNotificationPlan(false, true, 300, startedAt, startedAt),
        )

        for (plan in promotedPlans) {
            assertTrue(
                "Terfi istenmeli: ${plan.style}",
                plan.requestPromotedOngoing,
            )
            assertFalse(
                "Terfi istenen yolda ozel gorunum OLAMAZ: ${plan.style}",
                plan.usesCustomView,
            )
        }
    }

    /** Resmî şart 3: *"Must have a contentTitle set."* Eski kod `""` yazıyordu. */
    @Test
    fun promoted_path_always_has_a_content_title() {
        for (isBreak in listOf(false, true)) {
            for (target in listOf(null, 1500)) {
                val plan = runningTimerNotificationPlan(
                    richPanel = false,
                    isBreak = isBreak,
                    targetSeconds = target,
                    startedAtMs = startedAt,
                    nowMs = startedAt,
                )
                assertNotEquals(
                    "contentTitle bos birakilamaz (isBreak=$isBreak, target=$target)",
                    0,
                    plan.titleRes,
                )
            }
        }
    }

    @Test
    fun break_phase_and_work_phase_do_not_share_the_same_copy() {
        val work = runningTimerNotificationPlan(false, false, null, startedAt, startedAt)
        val rest = runningTimerNotificationPlan(false, true, null, startedAt, startedAt)

        assertEquals(R.string.timer_focusing_title, work.titleRes)
        assertEquals(R.string.timer_break_title, rest.titleRes)
        // WP-772: terfi eden yolda cip metni yok; ayrim baslik + dugme
        // etiketiyle (ve kartta `promotedCardStatusLine`) yapilir.
        assertEquals(0, work.shortCriticalTextRes)
        assertEquals(0, rest.shortCriticalTextRes)
    }

    /**
     * 🔴 WP-772 -> WP-775 (sahip, cihazda): kart Samsung Saat gibi. Baslik
     * saatin kendisi; bu satir saatin ALTINDAKI durum: ders adi, ders yoksa
     * odak cumlesi, molada mola cumlesi. Her dal dolu doner.
     */
    @Test
    fun promoted_card_status_line_is_the_subject_or_the_phase_sentence_and_never_empty() {
        assertEquals("Matematik", promotedCardStatusLine(false, "Matematik", "Odaklanıyorsun", "Mola sürüyor"))
        assertEquals("Matematik", promotedCardStatusLine(false, "  Matematik ", "Odaklanıyorsun", "Mola sürüyor"))
        assertEquals("Odaklanıyorsun", promotedCardStatusLine(false, null, "Odaklanıyorsun", "Mola sürüyor"))
        assertEquals("Odaklanıyorsun", promotedCardStatusLine(false, "   ", "Odaklanıyorsun", "Mola sürüyor"))
        assertEquals("Mola sürüyor", promotedCardStatusLine(true, "Matematik", "Odaklanıyorsun", "Mola sürüyor"))
    }

    @Test
    fun rich_panel_flag_keeps_the_v43_custom_panel_and_asks_for_no_promotion() {
        val plan = runningTimerNotificationPlan(
            richPanel = true,
            isBreak = false,
            targetSeconds = 1500,
            startedAtMs = startedAt,
            nowMs = startedAt + 60_000L,
        )

        assertEquals(TimerNotificationStyle.CUSTOM_PANEL, plan.style)
        assertTrue(plan.usesCustomView)
        // Karşılıklı dışlama: özel görünüm varken terfi İSTENMEZ.
        assertFalse(plan.requestPromotedOngoing)
    }

    /**
     * Valf UC durumludur ve ucu de ayri anlam tasir.
     *
     * 🔴 IDDIA YON DEGISTIRDI (WP-760) -- zayiflatilmadi, TERSINE CEVRILDI.
     *
     * Eski iddia "anahtar yokken v43 zengin panel kosmali" idi ve dogru
     * gorunuyordu: v71'de Live Update varsayilan yapilmis, cihazda hic
     * dogrulanmamis, sahibin S23'unde bildirim "00:00" gosterip Start/Stop'u
     * hic cizmemisti. Varsayilani geri almak o kanamayi durdurdu.
     *
     * Ama olculdu ki ilac hastaligi gecmisti: `richPanel` cagri yerinde
     *
     *     useV43CustomPanel() || !mayRequestPromotion(...)
     *
     * seklinde yaziliyordu. Sol taraf her zaman `true` oldugundan `||` kisa
     * devre yapiyor, sistemin terfiyi verip vermedigi **hic sorulmuyordu**.
     * Zincirin devami `requestPromotedOngoing = !usesCustomView`, yani
     * `setRequestPromotedOngoing(true)` HICBIR cihazda HIC cagrilmiyordu.
     * Terfiyi destekleyen bir telefon bile dinamik paneli gosteremezdi.
     *
     * Yani "anahtar yokken zengin panel" bir varsayilan degil, TERFININ
     * TAMAMEN KAPATILMASIYDI. Iki soru ayristirildi:
     *   - Kullanici acik tercih yazdi mi?            -> [panelOverride]
     *   - Yazmadiysa cihaz ne yapabiliyor?           -> [useRichPanel]
     *
     * Terfi etmeyen cihazda gorunen sey ayni kalir; degisen tek sey, terfi
     * EDEN cihazin artik sorulmasidir.
     */
    @Test
    fun panel_override_distinguishes_unset_from_explicit_choice() {
        val fresh = Wp753Prefs()
        assertNull("Anahtar yazilmamissa tercih YOKTUR (otomatik)", panelOverride(fresh))

        val optedOut = Wp753Prefs()
        optedOut.edit().putBoolean(KEY_PANEL_EXPANDED, true).commit()
        assertEquals("true = kullanici zengin paneli acikca istedi", true, panelOverride(optedOut))

        val optedIn = Wp753Prefs()
        optedIn.edit().putBoolean(KEY_PANEL_EXPANDED, false).commit()
        assertEquals("false = kullanici Live Update'i acikca istedi", false, panelOverride(optedIn))
    }

    /**
     * Karar tablosu. Sozlesme tek cumle: **acik tercih varsa o kazanir, yoksa
     * cihaz ne yapabiliyorsa o.**
     */
    @Test
    fun rich_panel_decision_asks_the_system_when_the_user_has_not_chosen() {
        // 🔴 IDDIA YON DEGISTIRDI (WP-763) -- olcume dayanarak.
        //
        // WP-760'ta buraya "tercih yokken terfi VEREN cihazda dinamik panel
        // kosmali" yazmistim. Kagitta dogruydu, cihazda YANLISLANDI: sahibin
        // S23'unde sistem terfiyi veriyor (bayrak yaziliyor) ama Samsung
        // ortada hicbir sey cizmiyor. Bedel odeniyor, karsilik alinmiyor.
        //
        // Elimizde "cip gercekten cizilecek mi" sorusunu onceden cevaplayan
        // bir sinyal yok; o yuzden otomatik akilli davranamaz, CALISANI secer.
        assertTrue(
            "Tercih yokken calisan panel kosmali: terfi VERILSE bile cizilmiyor",
            useRichPanel(override = null, mayPromote = true),
        )
        assertTrue(
            "Tercih yokken terfi VERMEYEN cihazda da zengin panel kosmali",
            useRichPanel(override = null, mayPromote = false),
        )

        // Acik tercih her iki yonde de sistemi EZER.
        assertTrue(
            "Kullanici zengin panel dediyse terfi eden cihazda bile zengin panel",
            useRichPanel(override = true, mayPromote = true),
        )
        // 🔴 Bu iddia da yon degistirdi: sistem terfi VERMIYORSA sade karta
        // dusup hicbir sey kazanmamanin anlami yok. Kullanici Live Update
        // dediyse bile, terfi imkansizken zengin panel korunur.
        assertTrue(
            "Terfi IMKANSIZKEN sade karta dusmek net kayiptir",
            useRichPanel(override = false, mayPromote = false),
        )
        assertFalse(
            "Kullanici Live Update dedi ve sistem izin veriyor: DENENIR",
            useRichPanel(override = false, mayPromote = true),
        )
    }

    /**
     * 🔴 ASIL NOBETCI: iki parcanin BILESIMI.
     *
     * Yukaridaki iki test tek baslarina kusuru KACIRIR ve bu bilerek yaziliyor:
     * [useRichPanel] saf tabloyla dogru cevabi verir, [panelOverride] uc durumu
     * dogru ayirir -- ama v72'ye kadar kusur ikisinde de DEGILDI. Kusur
     * ikisinin nasil BAGLANDIGINDAYDI: taze prefs "tercih yok" demeli iken
     * "zengin panel istiyorum" diyordu ve terfi sorusu hic sorulmuyordu.
     *
     * Bu deponun tekrar eden kusuru tam olarak budur: parcalar yesil, dikis
     * yok. Bu yuzden iddia parcalari degil, TAZE BIR KULLANICININ ILK
     * BASLAT'INI olcer.
     */
    @Test
    fun a_fresh_install_gets_the_panel_that_actually_draws() {
        val fresh = Wp753Prefs()

        // 🔴 WP-763: iddia YON DEGISTIRDI. WP-760'ta "taze kurulum + terfi
        // veren cihaz = dinamik panel" diyordu. Cihazda olculdu: terfi
        // VERILIYOR, panel yine CIKMIYOR. Taze kurulum artik calisan paneli
        // gorur.
        assertTrue(
            "Taze kurulum calisan paneli gormeli",
            useRichPanel(panelOverride(fresh), mayPromote = true),
        )
        assertTrue(
            "Terfi vermeyen cihazda da ayni",
            useRichPanel(panelOverride(fresh), mayPromote = false),
        )

        // 🔴 DIKIS HALA OLCULUR: acik tercih sisteme ULASMALI. WP-760'in kok
        // nedeni kisa devre yuzunden sistemin HIC sorulmamasiydi; burasi o
        // kisa devre geri gelirse duser.
        val optedIn = Wp753Prefs()
        optedIn.edit().putBoolean(KEY_PANEL_EXPANDED, false).commit()
        assertFalse(
            "Live Update secen kullanici + izin veren sistem = terfi ISTENIR",
            useRichPanel(panelOverride(optedIn), mayPromote = true),
        )
    }

    /**
     * Karsilikli dislama zincirinin SONU: terfi yolunda ozel gorunum olamaz.
     *
     * `richPanel` yanlis hesaplanirsa plan `CUSTOM_PANEL` uretir ve
     * `requestPromotedOngoing` sessizce `false` olur -- yani terfi
     * ISTENMEDEN kaybedilir. Kusurun gorunur tek izi buydu.
     */
    @Test
    fun the_decision_actually_reaches_the_promotion_request() {
        // 🔴 WP-763: ACIK tercihle olculur. Otomatik artik zengin paneli
        // sectigi icin, terfi isteginin sisteme ULASTIGINI ancak kullanici
        // Live Update dediginde olcebiliriz -- ve olculmesi gereken sey de
        // budur: secim ile gonderilen bildirim ayrismamali.
        val fresh = Wp753Prefs()
        fresh.edit().putBoolean(KEY_PANEL_EXPANDED, false).commit()
        val plan = runningTimerNotificationPlan(
            richPanel = useRichPanel(panelOverride(fresh), mayPromote = true),
            isBreak = false,
            targetSeconds = null,
            startedAtMs = startedAt,
            nowMs = startedAt,
        )
        assertTrue(
            "Live Update secimi `setRequestPromotedOngoing(true)`e ULASMALI",
            plan.requestPromotedOngoing,
        )
    }

    /**
     * Gecikmeli yoklamanin geri cagrisi UC kosulu birden aramali.
     *
     * 🔴 Yoklama neden gecikmeli: `notify()` bildirimi sisteme KUYRUKLAR,
     * `activeNotifications` ise GONDERILMIS listeyi okur. Hemen bakinca
     * bildirim cogu zaman henuz orada degildir; `postedFlags` null doner ve
     * verdict HIC yazilmaz. Terfi etmeyen cihaz o zaman her Baslat'ta yeniden
     * denenir ve kullanici surekli duz kartta kalir.
     *
     * Gecikme kendi riskini getirir: 400 ms icinde Durdur'a ya da
     * Durdur+Baslat'a basilabilir. Geri cagri kor davranirsa durmus sayaci
     * dirilten ya da sayaci geriye atlatan bir kart gonderir.
     */
    @Test
    fun the_delayed_probe_never_reposts_over_a_stopped_or_restarted_run() {
        val started = 1_700_000_000_000L

        assertTrue(
            "Kosan ayni kosuda RED olcumu dogru karti yeniden gondermeli",
            shouldRepostAfterProbe(
                verdict = TimerPromotion.Verdict.DENIED,
                isRunning = true,
                probedStartedAtMs = started,
                currentStartedAtMs = started,
            ),
        )

        assertFalse(
            "Olculemedi RED DEGILDIR; kart degistirilmez, sonra yeniden denenir",
            shouldRepostAfterProbe(
                verdict = null,
                isRunning = true,
                probedStartedAtMs = started,
                currentStartedAtMs = started,
            ),
        )
        assertFalse(
            "Terfi VERILDIYSE duz kart dogrudur, uzerine yazilmaz",
            shouldRepostAfterProbe(
                verdict = TimerPromotion.Verdict.GRANTED,
                isRunning = true,
                probedStartedAtMs = started,
                currentStartedAtMs = started,
            ),
        )
        assertFalse(
            "Sayac gecikme icinde DURDURULDUYSA kosan kart gonderilmez",
            shouldRepostAfterProbe(
                verdict = TimerPromotion.Verdict.DENIED,
                isRunning = false,
                probedStartedAtMs = started,
                currentStartedAtMs = 0L,
            ),
        )
        assertFalse(
            "Gecikme icinde YENIDEN baslatildiysa eski baslangic geri yazilmaz",
            shouldRepostAfterProbe(
                verdict = TimerPromotion.Verdict.DENIED,
                isRunning = true,
                probedStartedAtMs = started,
                currentStartedAtMs = started + 5_000L,
            ),
        )
    }

    /**
     * 🔴 WP-762 — TERFI EDILEBILIR HER DAL `ProgressStyle` TASIR.
     *
     * Sahibin Galaxy S23'unde olculdu: verdict GRANTED, yani sistem
     * `FLAG_PROMOTED_ONGOING` bayragini GERCEKTEN yazdi -- ama durum
     * cubugunda cip, Now Bar'da satir CIKMADI.
     *
     * En olasi sebep: Android 16'nin Live Update yuzeyleri `ProgressStyle`
     * etrafinda kuruludur. `setRequestPromotedOngoing(true)` tek basina yalniz
     * bayragi aldirir; cizilecek bir Live Update ogesi vermez. Acik uclu
     * kronometre STANDARD stille terfi istiyordu, yani sistemin elinde
     * cizecek bir sey yoktu.
     *
     * 🔴 BU BIR HIPOTEZDIR, olcum DEGIL. Cihazda dogrulanmadi. Ama sozlesme
     * her iki yonde de dogru: terfi isteyen bir bildirim, terfi yuzeyinin
     * bekledigi stille gelmelidir.
     */
    @Test
    fun every_promotable_path_sends_no_chip_text_so_the_chip_draws_the_clock() {
        val openEnded = runningTimerNotificationPlan(
            richPanel = false,
            isBreak = false,
            targetSeconds = null,
            startedAtMs = startedAt,
            nowMs = startedAt,
        )
        val targeted = runningTimerNotificationPlan(
            richPanel = false,
            isBreak = false,
            targetSeconds = 1500,
            startedAtMs = startedAt,
            nowMs = startedAt,
        )

        for (plan in listOf(openEnded, targeted)) {
            assertTrue(
                "terfi isteyen dal terfi yuzeyinin bekledigi stille gelmeli",
                plan.requestPromotedOngoing,
            )
            // 🔴 WP-772 (S23 / One UI 8.5, cihazda): cip metni SAATI GIZLER.
            // Bizim cipte "Focus", Samsung Saat'in cipinde "00:05" vardi;
            // tek fark buydu. Metin gonderilmez, cip kronometreyi cizer.
            assertEquals(
                "terfi edilen bildirime cip metni GONDERILMEZ",
                0,
                plan.shortCriticalTextRes,
            )
        }

        // Acik uclu kosunun toplami YOKTUR: uydurma bir toplam yazilmaz.
        assertEquals(
            "acik uclu kosuya sahte bir toplam verilmemeli",
            0,
            openEnded.totalSeconds,
        )
        assertTrue("hedefi olan mod gercek toplamini tasir", targeted.totalSeconds > 0)

        // 🔴 WP-763: acik uclu dal `ProgressStyle` TASIMAZ ve bu bilerek boyle.
        // WP-762 ona `setProgressIndeterminate(true)` vermisti; cihazda
        // olculdu ve BOZDU (soldan saga suzulen cubuk, sayac 00:00, dugme
        // kayboldu) -- ustelik cip yine cikmadi. Stil, hedefi olan modda
        // gercek bir ilerleme oldugu icin durur.
        assertEquals(TimerNotificationStyle.STANDARD, openEnded.style)
        assertEquals(TimerNotificationStyle.PROGRESS, targeted.style)
    }

    /**
     * Durum çubuğu/çip ikonu monokrom olmalı. Bugüne kadar renkli adaptif
     * launcher ikonuydu (`setSmallIcon(R.mipmap.ic_launcher)`) — yanlış tür.
     *
     * WP-772: jenerik saat kadranı (`ic_stat_focus_timer`) gitti; sahip çipte
     * uygulamanın logosunu istedi. Kamp ateşi silueti, beş yoğunlukta alfa PNG.
     */
    @Test
    fun status_bar_icon_is_the_app_logo_silhouette_not_the_colored_launcher_icon() {
        assertEquals(R.drawable.ic_stat_focus_camp, TIMER_NOTIFICATION_SMALL_ICON)
        assertNotEquals(R.mipmap.ic_launcher, TIMER_NOTIFICATION_SMALL_ICON)
    }

    @Test
    fun progress_never_leaves_the_segment_it_is_drawn_on() {
        val overrun = runningTimerNotificationPlan(
            false, false, 1500, startedAt, startedAt + 9_000_000L,
        )
        assertEquals(1500, overrun.progressSeconds)

        // Saat geri alınırsa `now < startedAt` olabilir; negatif ilerleme
        // ProgressStyle'ı bozar.
        val clockSkew = runningTimerNotificationPlan(
            false, false, 1500, startedAt, startedAt - 5_000L,
        )
        assertEquals(0, clockSkew.progressSeconds)
    }

    @Test
    fun a_non_positive_target_degrades_to_the_open_ended_stopwatch() {
        val plan = runningTimerNotificationPlan(
            false, false, 0, startedAt, startedAt,
        )
        assertEquals(TimerNotificationStyle.STANDARD, plan.style)
        assertTrue(plan.requestPromotedOngoing)
    }
}

/** Yalnız bu testin ihtiyacı kadar `SharedPreferences`. */
private class Wp753Prefs : SharedPreferences {
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

    override fun edit(): SharedPreferences.Editor = Wp753PrefsEditor(values)

    override fun registerOnSharedPreferenceChangeListener(
        listener: SharedPreferences.OnSharedPreferenceChangeListener?,
    ) = Unit

    override fun unregisterOnSharedPreferenceChangeListener(
        listener: SharedPreferences.OnSharedPreferenceChangeListener?,
    ) = Unit
}

private class Wp753PrefsEditor(
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
