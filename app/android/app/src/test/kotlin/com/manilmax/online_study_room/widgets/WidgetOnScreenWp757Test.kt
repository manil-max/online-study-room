package com.manilmax.online_study_room.widgets

import java.nio.file.Files
import java.nio.file.Path
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * WP-757 — EKRANDA olculen kusurlarin nobetcileri.
 *
 * Bu dosyanin oncekilerden farki: iddialar bir tasarim belgesinden degil,
 * **gercek bir ekrandan** geldi. Olcum duzenegi (API 33 emulatoru):
 *   - `AppWidgetHost` tasiyan kucuk bir barindirici APK saglayicilari
 *     GERCEKTEN baglar (`bindAppWidgetIdIfAllowed`), kutuyu tam olarak
 *     40x40 / 110x40 / 110x110 / 180x110dp'ye sabitler ve
 *     `updateAppWidgetOptions` ile kademe mantigini gercekten kosturur;
 *   - sisirilen agac `TextView.getLayout().getEllipsisCount()` ile taranir,
 *     yani "kirpilmis gorunuyor" degil KAC KARAKTER kirpildigi olculur.
 *
 * Olculen "once" tablosu (uygulama Turkce, uc sinav, dolu siralama):
 *
 * | kutu                | kusur                                              |
 * |---------------------|----------------------------------------------------|
 * | geri sayim 40x40    | KART TAMAMEN BOS - tek bir yaprak bile cizilmiyor  |
 * | geri sayim 110x40   | iki mini satir; sinav adlari 3 ve 11 karakter kirp |
 * | geri sayim 110x110  | satir adi 13 karakter kirpildi                     |
 * | geri sayim 180x110  | satir adi 3 karakter kirpildi                      |
 * | siralama 40x40      | kart kutunun %76'si                                |
 * | siralama 110x40     | kart %87; lider satiri 18 karakter kirpildi        |
 * | siralama 110x110    | baslik 5, 1. satir 23, 2. satir 13 karakter kirpik |
 * | siralama 180x110    | 1. satir 9 karakter kirpildi (kirpilan = SURE)     |
 * | gunluk hedef 110x110| seri satiri 13 karakter kirpildi                    |
 * | grup hedefi 110x110 | detay satiri 5 karakter kirpildi                   |
 * | saat 110x110        | 110dp kutuda 24sp - genislik butcesinin %80'i bos  |
 *
 * Iddia kumeleri AYRI sabotajlarla duser:
 *   A) geri sayimin bos kalmasi   -> `countdownHeroVisible` govdesini geri al
 *   B) kirpma butceleri           -> `statsStreakFitsWidth`i `true` yap
 *   C) siralama satiri            -> duzendeki `value` sutununu sil
 *   D) saglayici-fonksiyon baglantisi -> saglayicida cagriyi kaldir
 */
class WidgetOnScreenWp757Test {

    private fun read(relative: String): String =
        String(Files.readAllBytes(Path.of(relative)), Charsets.UTF_8)

    private fun stripComments(xml: String): String =
        Regex("(?s)<!--.*?-->").replace(xml, "")

    private fun layout(name: String): String = read("src/main/res/layout/$name.xml")

    private fun provider(name: String): String =
        read("src/main/kotlin/com/manilmax/online_study_room/widgets/$name.kt")

    /** Yorumlari eler: KDoc'ta ANLATILAN sey KOSAN kod sanilmasin (WP-640). */
    private fun stripKotlinComments(src: String): String =
        Regex("""(?s)/\*.*?\*/""").replace(src, "")
            .lines()
            .filterNot { it.trimStart().startsWith("//") }
            .joinToString("\n")

    /** Yalniz saglayici SINIFININ govdesi - dosyadaki saf fonksiyonlar haric. */
    private fun providerClassBody(file: String, className: String): String {
        val src = stripKotlinComments(provider(file))
        val start = src.indexOf("class $className")
        assertTrue("$className bulunamadi", start >= 0)
        return src.substring(start)
    }

    private fun attr(xml: String, name: String): String? =
        Regex("""android:$name="([^"]*)"""").find(stripComments(xml))?.groupValues?.get(1)

    private fun element(xml: String, id: String): String {
        val clean = stripComments(xml)
        val marker = clean.indexOf("@+id/$id")
        assertTrue("$id duzende yok", marker > 0)
        val start = clean.lastIndexOf('<', marker)
        val end = clean.indexOf('>', marker)
        return clean.substring(start, end)
    }

    /** §3.4 modeli: RAKAM genisligi (Roboto tabular). */
    private fun textWidthDp(sp: Float, chars: Int): Float =
        WIDGET_GLYPH_ADVANCE * sp * chars

    /** Duz metin (Turkce yardimci satirlar) - cihazda olculen ilerleme. */
    private fun proseWidthDp(sp: Float, chars: Int): Float =
        WIDGET_PROSE_ADVANCE * sp * chars

    /** `sans-serif-condensed` + `textScaleX=0.85` ile cizilen metin. */
    private fun condensedWidthDp(sp: Float, chars: Int): Float =
        textWidthDp(sp, chars) * WIDGET_TEXT_SCALE_X_MIN * WIDGET_CONDENSED_ADVANCE

    private fun usableWidthDp(boxDp: Int, paddingDp: Int): Float =
        boxDp - 2f * paddingDp - WIDGET_TEXT_SAFETY_DP

    /** Launcher hucre olculeri: `70n - 30`. */
    private data class Kutu(val ad: String, val w: Int, val h: Int)

    private val kutular = listOf(
        Kutu("1x1", 40, 40),
        Kutu("1x2", 40, 110),
        Kutu("2x1", 110, 40),
        Kutu("2x2", 110, 110),
        Kutu("2x3", 110, 180),
        Kutu("3x2", 180, 110),
        Kutu("4x2", 250, 110),
    )

    // =======================================================================
    // A) HICBIR KUTU BOS KALMAZ
    //
    // Sahibin bildirdigi kusur birebir buydu: "1x1 android widget da
    // bozulmus". Emulatorde olculdu - 40x40dp geri sayim kutusunda kokun
    // altinda GORUNUR tek bir yaprak yoktu. Kok neden iki kuralin birbirini
    // gormemesiydi: `countdownUsesHero` yalniz yukseklige/kayit sayisina
    // bakiyor, kademe kapisi ise K1'de satirlarin TAMAMINI dusuruyordu.
    //
    // SABOTAJ: `countdownHeroVisible` govdesinden `tier == K1` dalini kaldir
    // -> yalniz bu kume duser.
    // =======================================================================

    @Test
    fun geri_sayim_hicbir_kutuda_bos_kalmaz() {
        kutular.forEach { kutu ->
            for (kayit in 0..4) {
                for (oneCikan in listOf(true, false)) {
                    val size = widgetSizeClass(WidgetSizeSpecs.countdown, kutu.w, kutu.h)
                    val tier = progressWidgetTier(
                        size,
                        kutu.w,
                        WIDGET_COUNTDOWN_DEFAULT_WIDTH_DP,
                    )
                    val hero = countdownHeroVisible(
                        tier,
                        size.width,
                        size.height,
                        kayit,
                        oneCikan,
                    )
                    val satir = countdownVisibleRows(
                        tier,
                        size.width,
                        size.height,
                        kayit,
                        oneCikan,
                    )
                    assertTrue(
                        "${kutu.ad} / $kayit kayit / oneCikan=$oneCikan: " +
                            "kahraman da satirlar da gizli -> KART BOS",
                        hero || satir > 0,
                    )
                }
            }
        }
    }

    /**
     * Sahibin cihazindaki tam girdi: uc sinav + one cikarilan kayit.
     * (`CountdownWidget.kt` yorumundaki "76 / 312 / 313 gun" kaydi.)
     */
    @Test
    fun geri_sayim_uc_sinavla_1x1_kutuda_cekirdegi_cizer() {
        val size = widgetSizeClass(WidgetSizeSpecs.countdown, 40, 40)
        val tier = progressWidgetTier(size, 40, WIDGET_COUNTDOWN_DEFAULT_WIDTH_DP)
        assertEquals(ProgressWidgetTier.K1, tier)
        assertTrue(
            "1x1'de kahraman gizli: cekirdek onun ICINDE, yani kutu bos",
            countdownHeroVisible(
                tier,
                size.width,
                size.height,
                rowCount = 3,
                hasPriority = true,
            ),
        )
    }

    // =======================================================================
    // B) KADEME BUTCESI: cizilen her satir SIGAR
    //
    // §1.2/§1.3 zaten "sigmayan yardimci satir DUSER" diyor; olculen sey
    // kuralin bazi eksenlerde hic uygulanmadigiydi (yukseklige bakiliyor,
    // GENISLIGE bakilmiyordu).
    //
    // SABOTAJ: `statsStreakFitsWidth`i `true` dondur -> yalniz B duser.
    // =======================================================================

    /** `Gunluk hedef serisi: 12 gun` - Turkce en uzun makul seri satiri. */
    private val seriKarakter = 26

    @Test
    fun seri_satiri_ancak_sigdigi_kutuda_cizilir() {
        kutular.forEach { kutu ->
            val size = widgetSizeClass(WidgetSizeSpecs.stats, kutu.w, kutu.h)
            val tier = progressWidgetTier(size, kutu.w, WIDGET_STATS_DEFAULT_WIDTH_DP)
            val cizilir = statsStreakVisible(size.height) &&
                statsStreakFitsWidth(size.width) &&
                !progressOnlyCore(tier)
            if (!cizilir) return@forEach
            val dolgu = widgetRootPaddingDp(3, size.height)
            val gerekli = 12f + 3f + proseWidthDp(WIDGET_MIN_TEXT_SP, seriKarakter)
            assertTrue(
                "${kutu.ad}: seri satiri CIZILIYOR ama $gerekli dp gerekiyor, " +
                    "${usableWidthDp(kutu.w, dolgu)} dp var -> uc noktaya iner",
                gerekli <= usableWidthDp(kutu.w, dolgu),
            )
        }
    }

    /** `AYT Deneme Sinavi` - kullanicinin gercek sinav adi uzunlugu. */
    private val sinavAdiKarakter = 17

    @Test
    fun geri_sayim_yardimci_satiri_ancak_sigdigi_kutuda_cizilir() {
        kutular.forEach { kutu ->
            val size = widgetSizeClass(WidgetSizeSpecs.countdown, kutu.w, kutu.h)
            val tier = progressWidgetTier(size, kutu.w, WIDGET_COUNTDOWN_DEFAULT_WIDTH_DP)
            val satir = countdownVisibleRows(tier, size.width, size.height, 3, true)
            if (satir <= 0) return@forEach
            val sp = COUNTDOWN_ROW_SP.of(size.width)
            val dolgu = widgetRootPaddingDp(6, size.height)
            // Deger sutunu KOMPAKTtir: yalniz sayi (`297`). Tam cumle
            // (`297 gun kaldi`) bu widget'in en genis kutusunda (250dp,
            // `maxResizeWidth`) bile 229.6dp isterken 228dp yer vardir.
            val degerKarakter = 3
            val gerekli = condensedWidthDp(sp, degerKarakter) +
                WIDGET_DESIGN_ROW_GAP_DP + 2f +
                proseWidthDp(sp, sinavAdiKarakter)
            assertTrue(
                "${kutu.ad}: $satir yardimci satir CIZILIYOR ama sinav adi " +
                    "sigmiyor ($gerekli dp / ${usableWidthDp(kutu.w, dolgu)} dp)",
                gerekli <= usableWidthDp(kutu.w, dolgu),
            )
        }
    }

    @Test
    fun geri_sayim_dar_kutuda_yalniz_cekirdek_cizer() {
        listOf(Kutu("1x1", 40, 40), Kutu("2x1", 110, 40), Kutu("2x2", 110, 110))
            .forEach { kutu ->
                val size = widgetSizeClass(WidgetSizeSpecs.countdown, kutu.w, kutu.h)
                val tier = progressWidgetTier(
                    size,
                    kutu.w,
                    WIDGET_COUNTDOWN_DEFAULT_WIDTH_DP,
                )
                assertEquals(
                    "${kutu.ad}: dar kutuda yardimci satir cizilmemeli",
                    0,
                    countdownVisibleRows(tier, size.width, size.height, 3, true),
                )
                assertTrue(
                    "${kutu.ad}: satirlar dustu ama kahraman da gizli",
                    countdownHeroVisible(tier, size.width, size.height, 3, true),
                )
            }
    }

    @Test
    fun geri_sayim_satir_degeri_yalniz_sayidir() {
        val row = CountdownRow(CountdownState.FUTURE, "AYT", 19L, "19")
        assertEquals(
            "19",
            countdownRowValueText(row, "gun kaldi", "Bugun", "Gecti", compact = true),
        )
        // Eski bicim silinmedi: kahraman blogu hala tam cumleyi tasir.
        assertEquals(
            "19 gun kaldi",
            countdownRowValueText(row, "gun kaldi", "Bugun", "Gecti", compact = false),
        )
        // Bugun / gecti hallerinde kisaltilacak bir sey yok.
        val bugun = CountdownRow(CountdownState.TODAY, "AYT", 0L, "0")
        assertEquals(
            "Bugun",
            countdownRowValueText(bugun, "gun kaldi", "Bugun", "Gecti", compact = true),
        )
    }

    // =======================================================================
    // C) SIRALAMA SATIRI: kirpilan sey SURE OLMAZ
    //
    // Olculen: `Muhammed Muhlis - 4 sa 12 dk` tek bir `TextView`di; 180x110dp
    // kutuda 9 karakter kirpildi ve kirpilan tam olarak sag uctaki suredir.
    // Bir siralama widget'inda kirpilacak EN SON sey suredir.
    //
    // SABOTAJ: duzenden `leaderboard_widget_value_1`i sil -> yalniz C duser.
    // =======================================================================

    @Test
    fun siralama_karti_kutuyu_doldurur() {
        val el = element(layout("odak_leaderboard_widget"), "leaderboard_widget_card")
        assertEquals(
            "kart `wrap_content` ise kutunun icinde yuzer; olculdu: %76-%87",
            "match_parent",
            attr(el, "layout_height"),
        )
    }

    @Test
    fun siralama_sure_sutunu_asla_kirpilmaz() {
        val lb = layout("odak_leaderboard_widget")
        (1..3).forEach { position ->
            val el = element(lb, "leaderboard_widget_value_$position")
            assertEquals(
                "$position. satirin sure sutunu esneyemez",
                "wrap_content",
                attr(el, "layout_width"),
            )
            assertNull(
                "$position. satirin sure sutunu `ellipsize` tasiyor",
                attr(el, "ellipsize"),
            )
            assertEquals("1", attr(el, "maxLines"))
        }
    }

    @Test
    fun siralama_satiri_ad_ve_sure_olarak_ayrilir() {
        val raw = "Muhammed Muhlis · 4 sa 12 dk"
        assertEquals("Muhammed Muhlis", leaderboardRowName(raw))
        assertEquals("4 sa 12 dk", leaderboardRowValue(raw))
        // Yer tutucu satirlar ayrilmaz.
        assertEquals("Henuz kayit yok", leaderboardRowName("Henuz kayit yok"))
        assertNull(leaderboardRowValue("Henuz kayit yok"))
        assertNull(leaderboardRowValue("-"))
    }

    @Test
    fun siralama_sure_sutunu_sigmadigi_kutuda_hic_cizilmez() {
        kutular.forEach { kutu ->
            val tier = leaderboardTier(kutu.w, kutu.h)
            val size = widgetSizeClass(WidgetSizeSpecs.leaderboard, kutu.w, kutu.h)
            val sp = WidgetTypography.leaderboardRow.of(size.width)
            if (!leaderboardValueVisible(tier, kutu.w, sp)) return@forEach
            val usable = kutu.w - 2f * listCardPaddingDp(tier) -
                LEADERBOARD_RANK_DP - 2f * LEADERBOARD_ROW_GAP_DP
            val gerekli = condensedWidthDp(LEADERBOARD_VALUE_SP, LEADERBOARD_VALUE_MAX_CHARS) +
                proseWidthDp(sp, LEADERBOARD_NAME_MIN_CHARS)
            assertTrue(
                "${kutu.ad}: sure sutunu cizildi ama $gerekli dp gerekiyor, $usable dp var",
                gerekli <= usable,
            )
        }
        // Varsayilan 3x2 kutusunda sure GORUNMELI: siralama widget'inin
        // tasidigi veri suredir.
        assertTrue(
            "3x2 varsayilan kutuda sure sutunu dustu",
            leaderboardValueVisible(
                leaderboardTier(180, 110),
                180,
                WidgetTypography.leaderboardRow.narrow,
            ),
        )
        // 2x2'de sigmaz - orada ad tek basina cizilir.
        assertFalse(
            "2x2 kutuda sure sutunu cizilmemeli",
            leaderboardValueVisible(
                leaderboardTier(110, 110),
                110,
                WidgetTypography.leaderboardRow.narrow,
            ),
        )
    }

    /** `Kamp siralamasi` - 15 karakter. */
    private val siralamaBaslikKarakter = 15

    @Test
    fun siralama_basligi_ancak_sigdigi_kutuda_cizilir() {
        kutular.forEach { kutu ->
            val tier = leaderboardTier(kutu.w, kutu.h)
            if (!leaderboardHeaderVisible(tier, kutu.w)) return@forEach
            val size = widgetSizeClass(WidgetSizeSpecs.leaderboard, kutu.w, kutu.h)
            val usable = kutu.w - 2f * listCardPaddingDp(tier) -
                14f /* ikon */ - LEADERBOARD_ROW_GAP_DP
            val gerekli = proseWidthDp(
                WidgetTypography.leaderboardTitle.of(size.width),
                siralamaBaslikKarakter,
            )
            assertTrue(
                "${kutu.ad}: baslik CIZILIYOR ama $gerekli dp gerekiyor, $usable dp var",
                gerekli <= usable,
            )
        }
    }

    @Test
    fun baslik_dusen_kutuda_yerine_ucuncu_sira_gelir() {
        val tier = leaderboardTier(110, 110)
        val size = widgetSizeClass(WidgetSizeSpecs.leaderboard, 110, 110)
        assertFalse(
            "2x2'de baslik hala cizilyor",
            leaderboardHeaderVisible(tier, 110),
        )
        assertTrue(
            "baslik dustu ama ucuncu sira gelmedi - takas bos kaldi",
            leaderboardRow3Drawn(size.height, headerVisible = false),
        )
        // Baslik varken eski kural degismez.
        assertFalse(
            leaderboardRow3Drawn(size.height, headerVisible = true),
        )
    }

    // =======================================================================
    // D) SAGLAYICI GERCEKTEN BU KARARLARI KULLANIR
    //
    // Bu deponun tekrarlayan kusuru: saf fonksiyon dogru, ekran baska yerden
    // okuyor (`hunter` §3). Asagidaki iddialar saglayici SINIFININ govdesini
    // okur; dosyanin ustundeki saf fonksiyonlar sayilmaz.
    //
    // SABOTAJ: saglayicida `countdownHeroVisible(` cagrisini eski satirla
    // degistir -> yalniz D duser.
    // =======================================================================

    @Test
    fun saglayicilar_kademe_kapilarini_atlamaz() {
        val countdown = providerClassBody("CountdownWidget", "CountdownWidgetProvider")
        assertTrue(
            "geri sayim saglayicisi `countdownHeroVisible` cagirmiyor",
            countdown.contains("countdownHeroVisible("),
        )
        assertTrue(
            "geri sayim saglayicisi `countdownVisibleRows` cagirmiyor",
            countdown.contains("countdownVisibleRows("),
        )
        assertFalse(
            "saglayici kahraman kararini hala kendi icinde veriyor",
            countdown.contains("countdownUsesHero("),
        )
        assertTrue(
            "satir degeri kisaltilmiyor: sag ucta tam cumle sinav adini yiyor",
            countdown.contains("compact = true"),
        )

        val stats = providerClassBody("StatsWidget", "StudyStatsWidgetProvider")
        assertTrue(
            "gunluk hedef saglayicisi seri satirinin GENISLIK kapisini atliyor",
            stats.contains("statsStreakFitsWidth("),
        )

        val board = providerClassBody("LeaderboardWidget", "GroupLeaderboardWidgetProvider")
        assertTrue(
            "siralama saglayicisi ad/sure ayrimini yapmiyor",
            board.contains("leaderboardRowValue(") && board.contains("leaderboardRowName("),
        )
        assertTrue(
            "siralama saglayicisi sure sutunu butcesini sormuyor",
            board.contains("leaderboardValueVisible("),
        )
        assertTrue(
            "siralama saglayicisi baslik kapisini atliyor",
            board.contains("leaderboardHeaderVisible("),
        )
        assertTrue(
            "ucuncu sira takasi saglayiciya baglanmamis",
            board.contains("leaderboardRow3Drawn("),
        )
    }

    // =======================================================================
    // E) BUYUK KUTUDA ICERIK KUCUK KALMAZ
    //
    // Sahibin daha once yazdigi kusur: "buyuk boyutta icerik ortada kucucuk
    // kalmasin". Olculen: 110x110dp saat kutusunda `5:17` 24sp ile ciziliyor,
    // yani genislik butcesinin ancak %80'i. Punto merdiveni yalniz GENISLIK
    // sinifina bakiyor; 110dp hem 2x1 hem 2x2 kutusunda NARROW oldugu icin
    // uzun kutu da kisa kutunun puntosunu aliyordu.
    //
    // SABOTAJ: `WidgetTypography.clockTime.narrow`i 24f'e dondur.
    // =======================================================================

    @Test
    fun saat_2x2_kutusunda_genislik_butcesini_kullanir() {
        val size = widgetSizeClass(WidgetSizeSpecs.clock, 110, 110)
        val dolgu = widgetRootPaddingDp(4, size.height)
        val alan = usableWidthDp(110, dolgu)
        val kullanilan = textWidthDp(clockTimeSp(size), WIDGET_CLOCK_TIME_CHARS)
        assertTrue(
            "saat 110x110dp kutuda $kullanilan dp yer kapliyor, $alan dp var: " +
                "buyuk kutuda kucuk kaliyor",
            kullanilan >= 0.85f * alan,
        )
        assertTrue(
            "saat kirpiliyor: $kullanilan dp / $alan dp",
            kullanilan <= alan,
        )
    }

    // =======================================================================
    // F) 1x1 KUTUDA HER WIDGET BIR SEY CIZER
    //
    // Genel nobetci: dokuz widget'in kademe sistemi K1'de "tek oge" birakir.
    // O tek oge ya bir sayi ya bir gliftir; ucuncu bir secenek (hicbir sey)
    // yoktur. Geri sayim tam olarak o ucuncu secenege dusmustu.
    // =======================================================================

    @Test
    fun kutu_1x1_dokuz_widget_de_bir_cekirdek_cizer() {
        // Sayac / minimal sayac / saat: glif ya da okunabilir sayi.
        assertTrue(timerCoreIsGlyph(40))
        assertTrue(minimalTimerCoreIsGlyph(40))
        assertTrue(clockCoreIsGlyph(40))

        // Ilerleme ailesi: sayi cekirdegi ya da glif - ikisi de "bir sey".
        listOf(
            "gunluk hedef" to WidgetSizeSpecs.stats,
            "grup hedefi" to WidgetSizeSpecs.groupGoal,
            "geri sayim" to WidgetSizeSpecs.countdown,
        ).forEach { (ad, spec) ->
            val size = widgetSizeClass(spec, 40, 40)
            val tier = progressWidgetTier(size, 40, spec.defaultWidthDp)
            assertEquals("$ad: 1x1 K1 degil", ProgressWidgetTier.K1, tier)
            assertTrue("$ad: K1'de cekirdek disinda oge var", progressOnlyCore(tier))
        }

        // Siralama: `#3` ya da kupa glifi.
        assertEquals(ListWidgetTier.K1, leaderboardTier(40, 40))
        assertEquals("#3", leaderboardCoreRank("#3"))
        assertNull(leaderboardCoreRank("Siralama olusunca burada gorunur"))
    }

    // =======================================================================
    // G) GRUP HEDEFI DETAYI - satir DUSMEZ, SARILIR
    // =======================================================================

    @Test
    fun grup_hedefi_detay_satiri_iki_satira_sarilabilir() {
        val el = element(layout("odak_group_goal_widget"), "group_goal_widget_detail")
        assertEquals(
            "detay tek satira kilitliyse 110dp kutuda kirpilir (olculdu: 5 karakter)",
            "2",
            attr(el, "maxLines"),
        )
        // Iki satirin dikey butcesi: yay 48dp + iki satir + dolgu.
        val size = widgetSizeClass(WidgetSizeSpecs.groupGoal, 110, 110)
        val dolgu = widgetRootPaddingDp(6, size.height)
        val gerekli = 48f + 3f + 2f * (12f * 1.3f)
        assertTrue(
            "iki satirlik detay 110dp kutuya sigmiyor: $gerekli dp",
            gerekli <= 110f - 2f * dolgu,
        )
    }
}
