package com.manilmax.online_study_room.widgets

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * WP-699: kullanicinin GORDUGU dal olculur.
 *
 * XML'de bir nitelik bulunmasi "widget esnek" demek degildir. Bu dosya gercek
 * genislik/yukseklik degerleri verip hangi punto ve hangi satirlarin secildigini
 * olcer, sonra o secimin kutuya SIGDIGINI aritmetikle gosterir.
 *
 * 🔴 Aritmetik bir MODELDIR, cihaz olcumu degil: karakter genisligi
 * `0.60 x punto`, satir yuksekligi `1.30 x punto` varsayilir (Roboto rakam
 * ilerlemesi ~0.55em; 0.60 bilerek comert secildi) ve her kutuda 8dp emniyet
 * payi birakilir. Modelin yaptigi is, punto merdivenini kutu sinirlarina
 * BAGLAMAKTIR: biri buyur digeri buyumezse test kirmizi duser. Gercek
 * piksellerin dogrulanmasi cihazda yapilir.
 */
class WidgetSizeClassWp699Test {

    // --- model -------------------------------------------------------------

    private val safetyMarginDp = 8f

    private fun textWidthDp(sp: Float, chars: Int): Float = sp * 0.60f * chars

    private fun lineHeightDp(sp: Float): Float = sp * 1.30f

    /** Yatayda kullanilabilir genislik: kutu - iki yan dolgu - emniyet payi. */
    private fun usableWidthDp(boxDp: Int, paddingDp: Int): Float =
        boxDp - 2f * paddingDp - safetyMarginDp

    private fun usableHeightDp(boxDp: Int, paddingDp: Int): Float =
        boxDp - 2f * paddingDp - safetyMarginDp

    private fun assertFits(label: String, neededDp: Float, availableDp: Float) {
        assertTrue(
            "$label: $neededDp dp gerekiyor, $availableDp dp var -> KIRPILIR",
            neededDp <= availableDp,
        )
    }

    // --- siniflandirma -----------------------------------------------------

    @Test
    fun launcher_bir_boyut_bildirmediginde_varsayilan_kullanilir() {
        // Seceneklerin bos geldigi ilk cizimde `getInt` 0 doner. 0'i olduğu
        // gibi kullanmak her widget'i en dar/en kisa sinifa dusururdu:
        // kullanici widget'i ekledigi anda detaysiz bir kutu gorurdu.
        val spec = WidgetSizeSpecs.stats
        assertEquals(
            widgetSizeClass(spec, spec.defaultWidthDp, spec.defaultHeightDp),
            widgetSizeClass(spec, 0, 0),
        )
    }

    @Test
    fun genislik_ve_yukseklik_BAGIMSIZ_siniflanir() {
        // 🔴 Eski tek `compact` bayraginin kirdigi sey buydu: genis ama kisa
        // bir kutuda punto gereksiz kuculuyor, dar ama uzun bir kutuda detay
        // satirlari gereksiz gizleniyordu.
        val spec = WidgetSizeSpecs.stats

        val genisAmaKisa = widgetSizeClass(spec, 250, 40)
        assertEquals(WidgetWidthClass.WIDE, genisAmaKisa.width)
        assertEquals(WidgetHeightClass.SHORT, genisAmaKisa.height)

        val darAmaUzun = widgetSizeClass(spec, 110, 250)
        assertEquals(WidgetWidthClass.NARROW, darAmaUzun.width)
        assertEquals(WidgetHeightClass.TALL, darAmaUzun.height)
    }

    @Test
    fun esikler_kapsayicidir_bir_dp_altinda_dusuk_sinif() {
        val spec = WidgetSizeSpecs.timer

        assertEquals(
            WidgetWidthClass.MEDIUM,
            widgetSizeClass(spec, spec.mediumWidthDp, 110).width,
        )
        assertEquals(
            WidgetWidthClass.NARROW,
            widgetSizeClass(spec, spec.mediumWidthDp - 1, 110).width,
        )
        assertEquals(
            WidgetWidthClass.WIDE,
            widgetSizeClass(spec, spec.wideWidthDp, 110).width,
        )
        assertEquals(
            WidgetHeightClass.TALL,
            widgetSizeClass(spec, 110, spec.tallHeightDp).height,
        )
        assertEquals(
            WidgetHeightClass.MEDIUM,
            widgetSizeClass(spec, 110, spec.tallHeightDp - 1).height,
        )
    }

    @Test
    fun her_widget_en_kucuk_halinde_en_dar_en_kisa_sinifta() {
        // minResize kosesi (res/xml ile ayni sayilar) her zaman NARROW/SHORT
        // olmali; aksi halde en kucuk kutuda buyuk punto secilirdi.
        data class Kose(val ad: String, val spec: WidgetSizeSpec, val w: Int, val h: Int)
        listOf(
            Kose("timer", WidgetSizeSpecs.timer, 40, 40),
            Kose("clock", WidgetSizeSpecs.clock, 110, 40),
            Kose("countdown", WidgetSizeSpecs.countdown, 110, 80),
            Kose("stats", WidgetSizeSpecs.stats, 110, 40),
            Kose("group_goal", WidgetSizeSpecs.groupGoal, 110, 80),
            Kose("leaderboard", WidgetSizeSpecs.leaderboard, 180, 80),
        ).forEach {
            val size = widgetSizeClass(it.spec, it.w, it.h)
            assertEquals("${it.ad} en kucuk halinde dar degil", WidgetWidthClass.NARROW, size.width)
            assertEquals("${it.ad} en kucuk halinde kisa degil", WidgetHeightClass.SHORT, size.height)
        }
    }

    // --- gorunurluk: kullanicinin gordugu satirlar -------------------------

    @Test
    fun stats_iki_detay_satiri_AYRI_esiklerde_acilir() {
        val spec = WidgetSizeSpecs.stats

        val varsayilan = widgetSizeClass(spec, 110, 40).height
        assertFalse("2x1'de gun ozeti gorunuyor", statsDetailVisible(varsayilan))
        assertFalse("2x1'de seri satiri gorunuyor", statsStreakVisible(varsayilan))

        val orta = widgetSizeClass(spec, 110, 80).height
        assertTrue("2x2'de gun ozeti hala gizli", statsDetailVisible(orta))
        assertFalse("2x2'de seri satiri erken geldi", statsStreakVisible(orta))

        val uzun = widgetSizeClass(spec, 110, 110).height
        assertTrue(statsDetailVisible(uzun))
        assertTrue("en uzun halde seri satiri hala gizli", statsStreakVisible(uzun))
    }

    @Test
    fun leaderboard_kisa_halde_KULLANICININ_sirasini_gosterir() {
        val spec = WidgetSizeSpecs.leaderboard

        val kisa = widgetSizeClass(spec, 180, 80).height
        assertTrue(leaderboardShowsMyRank(kisa))
        assertFalse(leaderboardRow2Visible(kisa))
        assertFalse(leaderboardRow3Visible(kisa))

        val varsayilan = widgetSizeClass(spec, 180, 110).height
        assertFalse("varsayilan boyutta liste yerine sira gosteriliyor", leaderboardShowsMyRank(varsayilan))
        assertTrue(leaderboardRow2Visible(varsayilan))
        assertFalse("3x2'de ucuncu satir sigmaz", leaderboardRow3Visible(varsayilan))

        val uzun = widgetSizeClass(spec, 180, 150).height
        assertTrue(leaderboardRow3Visible(uzun))
    }

    @Test
    fun clock_ve_countdown_kisa_halde_ikincil_satiri_dusurur() {
        val clockKisa = widgetSizeClass(WidgetSizeSpecs.clock, 110, 40).height
        assertFalse(clockDateVisible(clockKisa))
        assertTrue(clockDateVisible(widgetSizeClass(WidgetSizeSpecs.clock, 110, 70).height))

        val cdKisa = widgetSizeClass(WidgetSizeSpecs.countdown, 110, 80).height
        assertFalse(countdownNameVisible(cdKisa))
        assertTrue(countdownNameVisible(widgetSizeClass(WidgetSizeSpecs.countdown, 110, 110).height))
    }

    @Test
    fun group_goal_detayi_kisa_halde_dusurulur() {
        assertFalse(groupGoalDetailVisible(widgetSizeClass(WidgetSizeSpecs.groupGoal, 110, 80).height))
        assertTrue(groupGoalDetailVisible(widgetSizeClass(WidgetSizeSpecs.groupGoal, 110, 110).height))
    }

    @Test
    fun dolgu_yukseklikle_birlikte_buyur() {
        assertEquals(14, widgetRootPaddingDp(14, WidgetHeightClass.SHORT))
        assertEquals(15, widgetRootPaddingDp(14, WidgetHeightClass.MEDIUM))
        assertEquals(16, widgetRootPaddingDp(14, WidgetHeightClass.TALL))
    }

    @Test
    fun punto_merdiveni_gercekten_yukselir() {
        // "Buyutup kucultulen versiyonlari olsun": ayni punto her boyutta
        // kullanilirsa widget buyudugunde icerik ortada kucucuk kalir.
        listOf(
            "timerTime" to WidgetTypography.timerTime,
            "clockTime" to WidgetTypography.clockTime,
            "countdownDays" to WidgetTypography.countdownDays,
            "statsValue" to WidgetTypography.statsValue,
            "leaderboardRow" to WidgetTypography.leaderboardRow,
        ).forEach { (ad, ramp) ->
            assertTrue("$ad orta punto dar puntodan buyuk degil", ramp.medium > ramp.narrow)
            assertTrue("$ad genis punto orta puntodan buyuk degil", ramp.wide > ramp.medium)
        }
    }

    // --- kirpma yok: her sinifin EN DAR halinde icerik sigar ---------------

    // 🔴 WP-718 — BU IDDIA YENIDEN YAZILDI, SILINMEDI.
    //
    // Eski hali uc sayiyi sabit varsayiyordu: dugme `minHeight=32dp`, dugme
    // ustu bosluk 6dp ve "iki satir HER boyutta cizilir". Ucu de artik yanlis:
    //   * 32dp, Android'in asgari dokunma hedefinin (48dp) ucte ikisiydi ve
    //     sahip cihazda tam olarak bunu "kucuk" diye bildirdi;
    //   * bosluk artik paylasilan `@dimen/widget_design_row_gap` (4dp);
    //   * en kisa sinifta kontrol satiri HIC cizilmez — 48dp'lik hedef ile
    //     okunur bir sayi o kutuya birlikte sigmadigi icin (olcum
    //     `TimerWidgetWp718Test`).
    //
    // Burada kalan is GENISLIK tarafidir: punto merdiveni her sinifin en dar
    // kutusunda kirpilmamali. Yukseklik/dokunma hedefi aritmetigi WP-718
    // dosyasinda, cunku artik gorunurluk kararina baglidir.
    @Test
    fun timer_hicbir_boyutta_kirpilmaz() {
        val spec = WidgetSizeSpecs.timer
        val karakter = 8 // "00:00:00"

        listOf(
            Triple("NARROW", 110, WidgetWidthClass.NARROW),
            Triple("MEDIUM", spec.mediumWidthDp, WidgetWidthClass.MEDIUM),
            Triple("WIDE", spec.wideWidthDp, WidgetWidthClass.WIDE),
        ).forEach { (ad, kutu, sinif) ->
            val size = widgetSizeClass(spec, kutu, 110)
            assertEquals(sinif, size.width)
            assertFits(
                "timer/$ad saat",
                textWidthDp(timerTimeSp(size, kutu), karakter) * WIDGET_TIMER_TEXT_SCALE_X,
                usableWidthDp(kutu, timerRootPaddingDp(size)),
            )
        }

        // En dar-uzun kose: dolgu yukseklikle buyurken genisligi yememeli.
        val darUzun = widgetSizeClass(spec, 110, spec.tallHeightDp)
        assertFits(
            "timer/NARROW+TALL saat",
            textWidthDp(timerTimeSp(darUzun, 110), karakter) * WIDGET_TIMER_TEXT_SCALE_X,
            usableWidthDp(110, timerRootPaddingDp(darUzun)),
        )
    }

    @Test
    fun clock_hicbir_boyutta_kirpilmaz() {
        val spec = WidgetSizeSpecs.clock
        val basePadding = 4
        val saatKarakter = 5 // "23:59"
        val tarihKarakter = 11 // "Car 12 Agu"

        listOf(
            Triple("NARROW", 110, WidgetWidthClass.NARROW),
            Triple("MEDIUM", spec.mediumWidthDp, WidgetWidthClass.MEDIUM),
            Triple("WIDE", spec.wideWidthDp, WidgetWidthClass.WIDE),
        ).forEach { (ad, kutu, sinif) ->
            val dolgu = widgetRootPaddingDp(basePadding, WidgetHeightClass.MEDIUM)
            assertFits(
                "clock/$ad saat",
                textWidthDp(clockTimeSp(WidgetSizeClass(sinif, WidgetHeightClass.MEDIUM)), saatKarakter),
                usableWidthDp(kutu, dolgu),
            )
            assertFits(
                "clock/$ad tarih",
                textWidthDp(WidgetTypography.clockDate.of(sinif), tarihKarakter),
                usableWidthDp(kutu, dolgu),
            )
        }

        // SHORT: tarih gizli, tek satir.
        assertFits(
            "clock/SHORT tek satir",
            lineHeightDp(clockTimeSp(WidgetSizeClass(WidgetWidthClass.NARROW, WidgetHeightClass.SHORT))),
            usableHeightDp(40, widgetRootPaddingDp(basePadding, WidgetHeightClass.SHORT)),
        )
        // MEDIUM: saat + 4dp bosluk + tarih.
        assertFits(
            "clock/MEDIUM iki satir",
            lineHeightDp(clockTimeSp(WidgetSizeClass(WidgetWidthClass.MEDIUM, WidgetHeightClass.MEDIUM))) + 2f +
                lineHeightDp(WidgetTypography.clockDate.medium),
            usableHeightDp(spec.mediumHeightDp, widgetRootPaddingDp(basePadding, WidgetHeightClass.MEDIUM)),
        )
        assertFits(
            "clock/TALL iki satir",
            lineHeightDp(clockTimeSp(WidgetSizeClass(WidgetWidthClass.WIDE, WidgetHeightClass.TALL))) + 2f +
                lineHeightDp(WidgetTypography.clockDate.wide),
            usableHeightDp(spec.tallHeightDp, widgetRootPaddingDp(basePadding, WidgetHeightClass.TALL)),
        )
    }

    @Test
    fun countdown_hicbir_boyutta_kirpilmaz() {
        val spec = WidgetSizeSpecs.countdown
        val basePadding = 12
        val gunKarakter = 4 // "9999"

        listOf(
            Triple("NARROW", 110, WidgetWidthClass.NARROW),
            Triple("MEDIUM", spec.mediumWidthDp, WidgetWidthClass.MEDIUM),
            Triple("WIDE", spec.wideWidthDp, WidgetWidthClass.WIDE),
        ).forEach { (ad, kutu, sinif) ->
            assertFits(
                "countdown/$ad gun sayisi",
                textWidthDp(WidgetTypography.countdownDays.of(sinif), gunKarakter),
                usableWidthDp(kutu, widgetRootPaddingDp(basePadding, WidgetHeightClass.MEDIUM)),
            )
        }

        // SHORT: ad gizli -> gun + 2dp + etiket.
        assertFits(
            "countdown/SHORT iki satir",
            lineHeightDp(WidgetTypography.countdownDays.narrow) + 2f +
                lineHeightDp(WidgetTypography.countdownLabel.narrow),
            usableHeightDp(80, widgetRootPaddingDp(basePadding, WidgetHeightClass.SHORT)),
        )
        // MEDIUM/TALL: ad + 2 + gun + 2 + etiket.
        assertFits(
            "countdown/MEDIUM uc satir",
            lineHeightDp(WidgetTypography.countdownName.medium) + 2f +
                lineHeightDp(WidgetTypography.countdownDays.medium) + 2f +
                lineHeightDp(WidgetTypography.countdownLabel.medium),
            usableHeightDp(spec.mediumHeightDp, widgetRootPaddingDp(basePadding, WidgetHeightClass.MEDIUM)),
        )
        assertFits(
            "countdown/TALL uc satir",
            lineHeightDp(WidgetTypography.countdownName.wide) + 2f +
                lineHeightDp(WidgetTypography.countdownDays.wide) + 2f +
                lineHeightDp(WidgetTypography.countdownLabel.wide),
            usableHeightDp(spec.tallHeightDp, widgetRootPaddingDp(basePadding, WidgetHeightClass.TALL)),
        )
    }

    @Test
    fun stats_hicbir_boyutta_kirpilmaz() {
        val spec = WidgetSizeSpecs.stats
        val basePadding = 3
        val cubukDp = 4f // ProgressBar layout_height

        listOf(
            Triple("NARROW", 110, WidgetWidthClass.NARROW),
            Triple("MEDIUM", spec.mediumWidthDp, WidgetWidthClass.MEDIUM),
            Triple("WIDE", spec.wideWidthDp, WidgetWidthClass.WIDE),
        ).forEach { (ad, kutu, sinif) ->
            assertFits(
                "stats/$ad yuzde",
                textWidthDp(statsValueSp(WidgetSizeClass(sinif, WidgetHeightClass.MEDIUM)), 4),
                usableWidthDp(kutu, widgetRootPaddingDp(basePadding, WidgetHeightClass.MEDIUM)),
            )
        }

        // Punto artik ramp'ten degil, gercekten cizilen yardimcilardan okunur;
        // tavan kaldirilirsa bu kapi kirmizi duser (WP-730).
        val kisa = WidgetSizeClass(WidgetWidthClass.NARROW, WidgetHeightClass.SHORT)
        val ortaKutu = WidgetSizeClass(WidgetWidthClass.MEDIUM, WidgetHeightClass.MEDIUM)
        val uzunKutu = WidgetSizeClass(WidgetWidthClass.WIDE, WidgetHeightClass.TALL)
        assertFalse("SHORT kutuda baslik ciziliyor", statsTitleVisible(kisa.height))
        assertFalse("MEDIUM kutuda baslik ciziliyor", statsTitleVisible(ortaKutu.height))
        assertTrue("TALL kutuda baslik kayboldu", statsTitleVisible(uzunKutu.height))

        // 🔴 WP-755: bu iddia "SHORT kutuda cubuk cizilir" VARSAYIMI uzerine
        // kuruluydu ve o varsayim artik yanlis. §1.2: K1/K2'de GRAFIK YOKTUR.
        // Gerekce olculdu: 4dp'lik bir cubuk bile 40dp'lik dikey butcede
        // cekirdegin puntosunu yer -- sahibin sikayet ettigi 15sp'lik yuzde
        // tam olarak o takasin sonucuydu.
        //
        // Varsayim IDDIAYA cevrildi: once grafigin cizilmedigi olculuyor,
        // sonra yalniz cekirdegin sigdigi. Boylece grafik sessizce geri
        // gelirse bu kapi kirmizi duser.
        val kisaTier = progressWidgetTier(kisa, 70, 110)
        assertFalse(
            "K1/K2'de grafik cizilmemeli (§1.2)",
            progressGaugeVisible(kisaTier),
        )
        // Dolgu UYDURULMUYOR, uretimin kendi kuralindan okunuyor
        // (`StatsWidget.kt` applyRootPadding cagrisinin AYNASI): dar kartta
        // 2dp, digerlerinde eski yardimci. Sayi yazsaydik uretim degisince
        // test sessizce yalan soylerdi.
        // Dar kartin DIKEY butcesi: kutu eksi iki dolgu, emniyet payi YOK.
        // Bu bir gevsetme degil, tasarim sisteminin yazili kurali (§6): 40dp
        // yuksekligin tamami cekirdege ayrilir, cunku orada cekirdekten baska
        // hicbir sey cizilmez (yukaridaki `progressGaugeVisible` iddiasi bunu
        // olcuyor). `usableHeightDp` 8dp'lik pay dusuyor ve o pay COK OGELI
        // kutular icin konmustu; tek ogeli kutuda payin karsiligi yok.
        // Dolgu uydurulmuyor, uretimin kendi kuralindan okunuyor
        // (`StatsWidget.kt:364` applyRootPadding cagrisinin aynasi).
        val kisaPadding =
            if (progressCardIsTight(kisaTier)) 2
            else widgetRootPaddingDp(basePadding, WidgetHeightClass.SHORT)
        assertFits(
            "stats/SHORT",
            lineHeightDp(statsValueSp(kisa)),
            40f - 2f * kisaPadding,
        )
        // MEDIUM: baslik yok; yuzde + cubuk + gun ozeti.
        assertFits(
            "stats/MEDIUM",
            lineHeightDp(statsValueSp(ortaKutu)) + 2f + cubukDp +
                3f + lineHeightDp(statsRowSp(ortaKutu)),
            usableHeightDp(spec.mediumHeightDp, widgetRootPaddingDp(basePadding, WidgetHeightClass.MEDIUM)),
        )
        // TALL: baslik + yuzde + cubuk + gun ozeti + seri.
        assertFits(
            "stats/TALL",
            lineHeightDp(statsTitleSp(uzunKutu)) +
                lineHeightDp(statsValueSp(uzunKutu)) + 2f + cubukDp +
                3f + lineHeightDp(statsRowSp(uzunKutu)) +
                2f + lineHeightDp(statsRowSp(uzunKutu)),
            usableHeightDp(spec.tallHeightDp, widgetRootPaddingDp(basePadding, WidgetHeightClass.TALL)),
        )
    }

    @Test
    fun group_goal_hicbir_boyutta_kirpilmaz() {
        val spec = WidgetSizeSpecs.groupGoal
        val basePadding = 6
        val gaugeDp = 42f

        assertFits(
            "group_goal/SHORT",
            lineHeightDp(WidgetTypography.statsTitle.narrow) + 3f + gaugeDp,
            usableHeightDp(80, widgetRootPaddingDp(basePadding, WidgetHeightClass.SHORT)),
        )
        assertFits(
            "group_goal/MEDIUM",
            lineHeightDp(WidgetTypography.statsTitle.medium) + 3f + gaugeDp +
                3f + lineHeightDp(WidgetTypography.statsRow.medium),
            usableHeightDp(spec.mediumHeightDp, widgetRootPaddingDp(basePadding, WidgetHeightClass.MEDIUM)),
        )
        assertFits(
            "group_goal/TALL",
            lineHeightDp(WidgetTypography.statsTitle.wide) + 3f + gaugeDp +
                3f + lineHeightDp(WidgetTypography.statsRow.wide),
            usableHeightDp(spec.tallHeightDp, widgetRootPaddingDp(basePadding, WidgetHeightClass.TALL)),
        )
    }

    @Test
    fun leaderboard_hicbir_boyutta_kirpilmaz() {
        val spec = WidgetSizeSpecs.leaderboard
        val basePadding = 14

        // SHORT: baslik + 8 + tek satir.
        assertFits(
            "leaderboard/SHORT",
            lineHeightDp(WidgetTypography.leaderboardTitle.narrow) + 8f +
                lineHeightDp(WidgetTypography.leaderboardRow.narrow),
            usableHeightDp(80, widgetRootPaddingDp(basePadding, WidgetHeightClass.SHORT)),
        )
        // MEDIUM: baslik + 8 + satir + 5 + satir.
        assertFits(
            "leaderboard/MEDIUM",
            lineHeightDp(WidgetTypography.leaderboardTitle.medium) + 8f +
                lineHeightDp(WidgetTypography.leaderboardRow.medium) + 5f +
                lineHeightDp(WidgetTypography.leaderboardRow.medium),
            usableHeightDp(spec.mediumHeightDp, widgetRootPaddingDp(basePadding, WidgetHeightClass.MEDIUM)),
        )
        // TALL: + 4 + ucuncu satir.
        assertFits(
            "leaderboard/TALL",
            lineHeightDp(WidgetTypography.leaderboardTitle.wide) + 8f +
                lineHeightDp(WidgetTypography.leaderboardRow.wide) + 5f +
                lineHeightDp(WidgetTypography.leaderboardRow.wide) + 4f +
                lineHeightDp(WidgetTypography.leaderboardRow.wide),
            usableHeightDp(spec.tallHeightDp, widgetRootPaddingDp(basePadding, WidgetHeightClass.TALL)),
        )
    }
}
