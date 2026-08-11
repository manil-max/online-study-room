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

        val genisAmaKisa = widgetSizeClass(spec, 250, 110)
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
            Kose("timer", WidgetSizeSpecs.timer, 110, 80),
            Kose("clock", WidgetSizeSpecs.clock, 110, 70),
            Kose("countdown", WidgetSizeSpecs.countdown, 110, 80),
            Kose("stats", WidgetSizeSpecs.stats, 110, 110),
            Kose("group_goal", WidgetSizeSpecs.groupGoal, 110, 110),
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

        val varsayilan = widgetSizeClass(spec, 110, 110).height
        assertFalse("2x2'de gun ozeti gorunuyor", statsDetailVisible(varsayilan))
        assertFalse("2x2'de seri satiri gorunuyor", statsStreakVisible(varsayilan))

        val orta = widgetSizeClass(spec, 110, 150).height
        assertTrue("2x3'te gun ozeti hala gizli", statsDetailVisible(orta))
        assertFalse("2x3'te seri satiri erken geldi", statsStreakVisible(orta))

        val uzun = widgetSizeClass(spec, 110, 180).height
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
        val clockKisa = widgetSizeClass(WidgetSizeSpecs.clock, 110, 70).height
        assertFalse(clockDateVisible(clockKisa))
        assertTrue(clockDateVisible(widgetSizeClass(WidgetSizeSpecs.clock, 110, 110).height))

        val cdKisa = widgetSizeClass(WidgetSizeSpecs.countdown, 110, 80).height
        assertFalse(countdownNameVisible(cdKisa))
        assertTrue(countdownNameVisible(widgetSizeClass(WidgetSizeSpecs.countdown, 110, 110).height))
    }

    @Test
    fun group_goal_detayi_kisa_halde_dusurulur() {
        assertFalse(groupGoalDetailVisible(widgetSizeClass(WidgetSizeSpecs.groupGoal, 110, 110).height))
        assertTrue(groupGoalDetailVisible(widgetSizeClass(WidgetSizeSpecs.groupGoal, 110, 150).height))
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

    @Test
    fun timer_hicbir_boyutta_kirpilmaz() {
        val spec = WidgetSizeSpecs.timer
        val basePadding = 6
        val karakter = 8 // "00:00:00"
        val dugmeYuksekligiDp = 32f // layout'taki minHeight
        val dugmeUstBosluguDp = 6f

        // Genislik: her sinifin en dar kutusu.
        listOf(
            Triple("NARROW", 110, WidgetWidthClass.NARROW),
            Triple("MEDIUM", spec.mediumWidthDp, WidgetWidthClass.MEDIUM),
            Triple("WIDE", spec.wideWidthDp, WidgetWidthClass.WIDE),
        ).forEach { (ad, kutu, sinif) ->
            assertEquals(sinif, widgetSizeClass(spec, kutu, 110).width)
            assertFits(
                "timer/$ad saat",
                textWidthDp(WidgetTypography.timerTime.of(sinif), karakter),
                usableWidthDp(kutu, widgetRootPaddingDp(basePadding, WidgetHeightClass.MEDIUM)),
            )
        }

        // Yukseklik: en kisa kutu (minResizeHeight) en kucuk puntoyla.
        val kisaDolgu = widgetRootPaddingDp(basePadding, WidgetHeightClass.SHORT)
        assertFits(
            "timer/SHORT iki satir",
            lineHeightDp(WidgetTypography.timerTime.narrow) + dugmeUstBosluguDp + dugmeYuksekligiDp,
            usableHeightDp(80, kisaDolgu),
        )
        val uzunDolgu = widgetRootPaddingDp(basePadding, WidgetHeightClass.TALL)
        assertFits(
            "timer/TALL iki satir",
            lineHeightDp(WidgetTypography.timerTime.wide) + dugmeUstBosluguDp + dugmeYuksekligiDp,
            usableHeightDp(spec.tallHeightDp, uzunDolgu),
        )
    }

    @Test
    fun clock_hicbir_boyutta_kirpilmaz() {
        val spec = WidgetSizeSpecs.clock
        val basePadding = 12
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
                textWidthDp(WidgetTypography.clockTime.of(sinif), saatKarakter),
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
            lineHeightDp(WidgetTypography.clockTime.narrow),
            usableHeightDp(70, widgetRootPaddingDp(basePadding, WidgetHeightClass.SHORT)),
        )
        // MEDIUM: saat + 4dp bosluk + tarih.
        assertFits(
            "clock/MEDIUM iki satir",
            lineHeightDp(WidgetTypography.clockTime.medium) + 4f +
                lineHeightDp(WidgetTypography.clockDate.medium),
            usableHeightDp(spec.mediumHeightDp, widgetRootPaddingDp(basePadding, WidgetHeightClass.MEDIUM)),
        )
        assertFits(
            "clock/TALL iki satir",
            lineHeightDp(WidgetTypography.clockTime.wide) + 4f +
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
        val basePadding = 14
        val cubukDp = 6f // ProgressBar layout_height

        listOf(
            Triple("NARROW", 110, WidgetWidthClass.NARROW),
            Triple("MEDIUM", spec.mediumWidthDp, WidgetWidthClass.MEDIUM),
            Triple("WIDE", spec.wideWidthDp, WidgetWidthClass.WIDE),
        ).forEach { (ad, kutu, sinif) ->
            assertFits(
                "stats/$ad yuzde",
                textWidthDp(WidgetTypography.statsValue.of(sinif), 4), // "100%"
                usableWidthDp(kutu, widgetRootPaddingDp(basePadding, WidgetHeightClass.MEDIUM)),
            )
        }

        // SHORT: baslik + 8 + yuzde + 6 + cubuk.
        assertFits(
            "stats/SHORT",
            lineHeightDp(WidgetTypography.statsTitle.narrow) + 8f +
                lineHeightDp(WidgetTypography.statsValue.narrow) + 6f + cubukDp,
            usableHeightDp(110, widgetRootPaddingDp(basePadding, WidgetHeightClass.SHORT)),
        )
        // MEDIUM: + 6 + gun ozeti.
        assertFits(
            "stats/MEDIUM",
            lineHeightDp(WidgetTypography.statsTitle.medium) + 8f +
                lineHeightDp(WidgetTypography.statsValue.medium) + 6f + cubukDp +
                6f + lineHeightDp(WidgetTypography.statsRow.medium),
            usableHeightDp(spec.mediumHeightDp, widgetRootPaddingDp(basePadding, WidgetHeightClass.MEDIUM)),
        )
        // TALL: + 3 + seri.
        assertFits(
            "stats/TALL",
            lineHeightDp(WidgetTypography.statsTitle.wide) + 8f +
                lineHeightDp(WidgetTypography.statsValue.wide) + 6f + cubukDp +
                6f + lineHeightDp(WidgetTypography.statsRow.wide) +
                3f + lineHeightDp(WidgetTypography.statsRow.wide),
            usableHeightDp(spec.tallHeightDp, widgetRootPaddingDp(basePadding, WidgetHeightClass.TALL)),
        )
    }

    @Test
    fun group_goal_hicbir_boyutta_kirpilmaz() {
        val spec = WidgetSizeSpecs.groupGoal
        val basePadding = 14
        val cubukDp = 6f

        assertFits(
            "group_goal/SHORT",
            lineHeightDp(WidgetTypography.statsTitle.narrow) + 7f +
                lineHeightDp(WidgetTypography.statsValue.narrow) + 6f + cubukDp,
            usableHeightDp(110, widgetRootPaddingDp(basePadding, WidgetHeightClass.SHORT)),
        )
        assertFits(
            "group_goal/MEDIUM",
            lineHeightDp(WidgetTypography.statsTitle.medium) + 7f +
                lineHeightDp(WidgetTypography.statsValue.medium) + 6f + cubukDp +
                7f + lineHeightDp(WidgetTypography.statsRow.medium),
            usableHeightDp(spec.mediumHeightDp, widgetRootPaddingDp(basePadding, WidgetHeightClass.MEDIUM)),
        )
        assertFits(
            "group_goal/TALL",
            lineHeightDp(WidgetTypography.statsTitle.wide) + 7f +
                lineHeightDp(WidgetTypography.statsValue.wide) + 6f + cubukDp +
                7f + lineHeightDp(WidgetTypography.statsRow.wide),
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
