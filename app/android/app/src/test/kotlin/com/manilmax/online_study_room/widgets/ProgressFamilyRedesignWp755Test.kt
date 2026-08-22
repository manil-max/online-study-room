package com.manilmax.online_study_room.widgets

import java.nio.file.Files
import java.nio.file.Path
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * WP-755 - ILERLEME ailesinin yeniden tasarimi.
 *
 * Aile: gunluk hedef · grup hedefi · sinav geri sayimi. Ucu de "bir hedefe ne
 * kadar kaldi" anlatir; bu dosya o uclunun PAYLASTIGI iddialari olcer.
 *
 * Sozlesme: `docs/tasarim/widget-tasarim-sistemi.md`. Belgeye guvenilmez -
 * sayilar burada yeniden kurulur.
 *
 * Alti iddia kumesi, alti ayri sabotaj:
 *   A) Sifir-gorsel nobetcisi   - bir duzenden `ImageView`i sil, yalniz A duser.
 *   B) Cekirdek sozlesmesi      - `PROGRESS_CORE_MAX_CHARS`i 4 yap, yalniz B duser.
 *   C) Punto merdiveni          - `PROGRESS_K2_CORE_SP`i 40f yap, yalniz C duser.
 *   D) Gosterge geometrisi      - grup hedefinde `arcPercent` -> `barPercent`,
 *                                 yalniz D duser.
 *   E) Palet                    - bir duzene ham hex yaz, yalniz E duser.
 *   F) Kademe dusme sirasi      - cekirdegi bir kademede gizle, yalniz F duser.
 */
class ProgressFamilyRedesignWp755Test {

    private fun read(relative: String): String =
        String(Files.readAllBytes(Path.of(relative)), Charsets.UTF_8)

    private fun stripComments(xml: String): String =
        Regex("<!--[\\s\\S]*?-->").replace(xml, "")

    private val layoutDir = "src/main/res/layout"
    private val kotlinDir = "src/main/kotlin/com/manilmax/online_study_room/widgets"
    private val xmlDir = "src/main/res/xml"

    private val statsLayout = "$layoutDir/odak_stats_widget.xml"
    private val goalLayout = "$layoutDir/odak_group_goal_widget.xml"
    private val countdownLayout = "$layoutDir/odak_countdown_widget.xml"
    private val familyLayouts = listOf(statsLayout, goalLayout, countdownLayout)

    /** Birlesik yatay katsayi (§3.4): textScaleX x yazitipi daralmasi. */
    private val k = WIDGET_TEXT_SCALE_X_MIN * WIDGET_CONDENSED_ADVANCE

    /**
     * Kademe -> temsili kutu. Sayilar `res/xml/odak_*_info.xml` ile ayni
     * dunyadan: hucre formulu `70n - 30`.
     */
    private data class Kutu(val tier: ProgressWidgetTier, val w: Int, val h: Int)

    private val statsKutulari = listOf(
        Kutu(ProgressWidgetTier.K1, 40, 40),
        Kutu(ProgressWidgetTier.K2, 110, 40),
        Kutu(ProgressWidgetTier.K3, 110, 80),
        Kutu(ProgressWidgetTier.K4, 110, 110),
    )
    private val goalKutulari = listOf(
        Kutu(ProgressWidgetTier.K1, 40, 40),
        Kutu(ProgressWidgetTier.K2, 110, 40),
        Kutu(ProgressWidgetTier.K3, 110, 110),
        Kutu(ProgressWidgetTier.K4, 110, 150),
    )
    private val countdownKutulari = listOf(
        Kutu(ProgressWidgetTier.K1, 40, 40),
        Kutu(ProgressWidgetTier.K2, 110, 40),
        Kutu(ProgressWidgetTier.K3, 110, 110),
        Kutu(ProgressWidgetTier.K4, 110, 180),
    )

    private fun sinif(spec: WidgetSizeSpec, kutu: Kutu): WidgetSizeClass =
        widgetSizeClass(spec, kutu.w, kutu.h)

    private fun kademe(spec: WidgetSizeSpec, kutu: Kutu): ProgressWidgetTier =
        progressWidgetTier(sinif(spec, kutu), kutu.w, spec.defaultWidthDp)

    // =======================================================================
    // A) SIFIR-GORSEL NOBETCISI
    //
    // WP-750 §0'in olcumu: dokuz duzende SIFIR `ImageView` vardi, yani butun
    // gorsel yuk `TextView`daydi - sahibin "sadece yazi, guzel degil"
    // sikayetinin olculebilir hali. Bu kume o olcumun geri gelmesini yakalar.
    //
    // SABOTAJ: bir duzenden `<ImageView`leri sil -> yalniz bu kume duser.
    // =======================================================================

    @Test
    fun ailenin_uc_duzeni_de_gorsel_tasir() {
        familyLayouts.forEach { path ->
            val xml = stripComments(read(path))
            assertTrue(
                "$path hala saf metin: hic `ImageView` yok (WP-750 §0 kusuru geri geldi)",
                xml.contains("<ImageView"),
            )
        }
    }

    /**
     * Her widget'in tasidigi gorsel parcalar ADIYLA olculur; "bir tane
     * ImageView var" iddiasi bir sonraki turda bos bir kabuk birakabilirdi.
     */
    @Test
    fun her_widget_aile_ikonunu_ayraci_ve_cekirdek_glifini_tasir() {
        val beklenen = mapOf(
            statsLayout to listOf(
                "@+id/stats_widget_icon" to "@drawable/widget_ic_stats",
                "@+id/stats_widget_divider" to "@drawable/widget_divider",
                "@+id/stats_widget_core_glyph" to null,
                "@+id/stats_widget_streak_flame" to "@drawable/widget_flame_on",
            ),
            goalLayout to listOf(
                "@+id/group_goal_widget_icon" to "@drawable/widget_ic_group_goal",
                "@+id/group_goal_widget_divider" to "@drawable/widget_divider",
                "@+id/group_goal_widget_core_glyph" to null,
            ),
            countdownLayout to listOf(
                "@+id/countdown_widget_icon" to "@drawable/widget_ic_countdown",
                "@+id/countdown_widget_divider" to "@drawable/widget_divider",
                "@+id/countdown_widget_core_glyph" to null,
            ),
        )
        beklenen.forEach { (path, parcalar) ->
            val xml = stripComments(read(path))
            parcalar.forEach { (id, drawable) ->
                assertTrue("$path: $id yok", xml.contains(id))
                if (drawable != null) {
                    assertTrue("$path: $drawable cizimi bagli degil", xml.contains(drawable))
                }
            }
        }
    }

    /**
     * §4.4: RemoteViews'in izin verdigi gorunum listesinde duz `View` YOKTUR.
     * Ayrac 1dp yukseklikte bir `ImageView`dir ve olcusunu paylasilan dilden
     * alir. `<View` yazan bir duzen cihazda sessizce catlar.
     */
    @Test
    fun ayrac_View_degil_ImageViewdir() {
        familyLayouts.forEach { path ->
            val xml = stripComments(read(path))
            assertFalse(
                "$path: RemoteViews duz `View` desteklemez",
                Regex("<View[\\s/>]").containsMatchIn(xml),
            )
            assertTrue(
                "$path: ayrac olcusu paylasilan dilden gelmiyor",
                xml.contains("@dimen/widget_design_divider"),
            )
        }
    }

    /** §7-9: yalniz izin verilen gorunumler. ConstraintLayout / ozel View yok. */
    @Test
    fun duzenler_yalniz_RemoteViews_gorunumlerini_kullanir() {
        val izinli = setOf(
            "FrameLayout", "LinearLayout", "RelativeLayout", "GridLayout",
            "TextView", "ImageView", "ProgressBar", "Button", "ImageButton",
            "AnalogClock", "Chronometer", "ListView", "GridView", "StackView",
            "ViewFlipper", "ViewStub",
        )
        familyLayouts.forEach { path ->
            Regex("<([A-Za-z][A-Za-z0-9.]*)").findAll(stripComments(read(path)))
                .map { it.groupValues[1] }
                .filter { it.first().isUpperCase() }
                .forEach {
                    assertTrue("$path: `$it` RemoteViews'ta desteklenmiyor", izinli.contains(it))
                }
        }
    }

    // =======================================================================
    // B) CEKIRDEK SOZLESMESI (§1.4)
    //
    // Her widget'in TAM OLARAK BIR cekirdegi vardir ve K1'de tek basina kalir.
    // Sayi cekirdegi EN FAZLA UC KARAKTERDIR; sigmiyorsa cekirdek gliftir.
    //
    // SABOTAJ: `PROGRESS_CORE_MAX_CHARS`i 4 yap -> yalniz bu kume duser.
    // =======================================================================

    @Test
    fun K1_cekirdegi_en_fazla_uc_karakterdir() {
        assertEquals(3, PROGRESS_CORE_MAX_CHARS)
        // 40x40dp kutu, 2dp dolgu: uc karakter 21sp tasir, dordu 15sp'ye duser.
        assertEquals(21f, widgetMaxSp(40, 2, PROGRESS_CORE_MAX_CHARS, k))
        assertTrue(
            "dort karakterlik bir cekirdek K1'de kahraman sayi degil fisiltidir",
            widgetMaxSp(40, 2, PROGRESS_CORE_MAX_CHARS + 1, k) < PROGRESS_K1_CORE_SP,
        )
    }

    /**
     * 🔴 SAHIBIN SORDUGU HAL: `%100`.
     *
     * `72%` uc karakter -> K1'de sayidir. `100%` DORT karakter -> K1'de sayi
     * OLAMAZ. Karar: kirpmak, yalan soylemek (`%99`) veya yuzde isaretini
     * atmak (`100`, saatin dakikasiyla karisir) yerine §1.4'un kendi yazdigi
     * yola gidilir - cekirdek GLIF olur ve o glif `widget_flame_peak`tir
     * (§4.2 "rekor / bugun tamam"). Kayip yok: dolmus bir hedefi anlatan en
     * guclu isaret zaten sayi degildir.
     *
     * Ayni deger K2 ve ustunde SAYI olarak kalir; uc karakter sinirini
     * doguran sey kutu, deger degil.
     */
    @Test
    fun yuzde_yuz_K1de_glife_doner_K2de_sayi_kalir() {
        assertEquals(
            ProgressCoreKind.GLYPH_FULL,
            progressCoreKind(ProgressWidgetTier.K1, hasData = true, coreText = "100%"),
        )
        listOf(ProgressWidgetTier.K2, ProgressWidgetTier.K3, ProgressWidgetTier.K4)
            .forEach {
                assertEquals(
                    "$it kademesinde `100%` sayi olarak kalmali",
                    ProgressCoreKind.NUMBER,
                    progressCoreKind(it, hasData = true, coreText = "100%"),
                )
            }
        assertEquals(
            ProgressCoreKind.NUMBER,
            progressCoreKind(ProgressWidgetTier.K1, hasData = true, coreText = "72%"),
        )
        // Dolu hedefin glifi ALEVdir; saglayici o eslemeyi yapiyor mu?
        assertTrue(
            "dolu hedef glifi duzende/saglayicida `widget_flame_peak` degil",
            read("$kotlinDir/StatsWidget.kt").contains("R.drawable.widget_flame_peak"),
        )
    }

    /**
     * Veri YOKLUGU sifir DEGILDIR. Widget uygulama hic acilmadan da eklenebilir;
     * o halde `0%` cizmek kullaniciya "hedefinin sifirindasin" demektir.
     * Grup hedefinde ayni hal "grubun yok"tur ve cevabi yine glif cekirdektir.
     */
    @Test
    fun veri_yoksa_cekirdek_sifir_degil_gliftir() {
        ProgressWidgetTier.values().forEach { tier ->
            assertEquals(
                "$tier: veri yokken sayi ciziliyor",
                ProgressCoreKind.GLYPH_EMPTY,
                progressCoreKind(tier, hasData = false, coreText = "0%"),
            )
        }
        // Geri sayimda "veri var" yalniz gercek bir geri sayimdir.
        assertTrue(countdownHasData(CountdownState.FUTURE))
        assertTrue(countdownHasData(CountdownState.TODAY))
        assertFalse("bos kayit veri sayiliyor", countdownHasData(CountdownState.EMPTY))
        assertFalse("gecmis tarih veri sayiliyor", countdownHasData(CountdownState.PAST))
    }

    /** Sayi cekirdegi secildiyse metin GERCEKTEN uc karaktere sigar. */
    @Test
    fun K1de_sayi_secildiginde_metin_sinira_uyar() {
        (0..100).forEach { yuzde ->
            val metin = "$yuzde%"
            if (progressCoreKind(ProgressWidgetTier.K1, true, metin) ==
                ProgressCoreKind.NUMBER
            ) {
                assertTrue(
                    "K1 cekirdegi $metin ile ${metin.length} karaktere cikti",
                    metin.length <= PROGRESS_CORE_MAX_CHARS,
                )
            }
        }
        // Geri sayim tarafi: 999 gun sigar, 1000 gun sigmaz.
        assertEquals(
            ProgressCoreKind.NUMBER,
            progressCoreKind(ProgressWidgetTier.K1, true, "999"),
        )
        assertEquals(
            ProgressCoreKind.GLYPH_FULL,
            progressCoreKind(ProgressWidgetTier.K1, true, "1000"),
        )
    }

    /** Bozuk/eksik yuzde metni widget'i catlatmaz, 0 sayilir. */
    @Test
    fun yuzde_ayristirma_bozuk_girdide_catlamaz() {
        assertEquals(0, progressPercentValue(null))
        assertEquals(0, progressPercentValue(""))
        assertEquals(0, progressPercentValue("bozuk"))
        assertEquals(72, progressPercentValue("72%"))
        assertEquals(72, progressPercentValue(" 72 % "))
        assertEquals(100, progressPercentValue("140%"))
    }

    // =======================================================================
    // C) PUNTO MERDIVENI (§3.4)
    //
    // Secilen punto, kutunun tasidigindan buyuk olamaz. Model uretimin kendi
    // fonksiyonudur (`widgetMaxSp`); test bir ikinci kopya tutmaz.
    //
    // SABOTAJ: `PROGRESS_K2_CORE_SP`i 40f yap -> yalniz bu kume duser.
    // =======================================================================

    /**
     * Kademenin kok dolgusu. K1/K2'de 2dp (§1.1 ic alan tablosu); K3/K4 icin
     * ucunun EN BUYUGU (7dp) alinir - model boylece uretimden asla iyimser
     * olmaz.
     */
    private fun dolgu(tier: ProgressWidgetTier): Int =
        if (progressCardIsTight(tier)) 2 else 7

    /**
     * Cekirdegin karakter butcesi: K1'de sozlesme geregi UC (dordu glife
     * doner), ustunde dort (`100%` / `9999`).
     */
    private fun karakter(tier: ProgressWidgetTier): Int =
        if (tier == ProgressWidgetTier.K1) PROGRESS_CORE_MAX_CHARS else 4

    private fun merdiven(): List<Triple<String, Kutu, Float>> =
        statsKutulari.map {
            Triple("stats/${it.tier}", it, statsValueSp(sinif(WidgetSizeSpecs.stats, it), it.w))
        } + goalKutulari.map {
            Triple(
                "group_goal/${it.tier}",
                it,
                groupGoalPercentSp(sinif(WidgetSizeSpecs.groupGoal, it), it.w),
            )
        } + countdownKutulari.map {
            Triple(
                "countdown/${it.tier}",
                it,
                countdownDaysSp(sinif(WidgetSizeSpecs.countdown, it), it.w),
            )
        }

    @Test
    fun cekirdek_puntosu_genislik_tavanini_asmaz() {
        merdiven().forEach { (ad, kutu, sp) ->
            val tavan = widgetMaxSp(kutu.w, dolgu(kutu.tier), karakter(kutu.tier), k)
            assertTrue(
                "$ad: $sp sp seciliyor ama ${kutu.w}dp kutu " +
                    "${karakter(kutu.tier)} karakterde en fazla $tavan sp tasiyor " +
                    "(dolgu ${dolgu(kutu.tier)}dp, k = $k)",
                sp <= tavan,
            )
            assertTrue("$ad: punto 11sp tabaninin altina dustu ($sp)", sp >= WIDGET_MIN_TEXT_SP)
        }
    }

    /**
     * Cekirdek `wrap_content`tur ve yaninda `layout_weight` tasiyan yardimci
     * metin durur; yani dar bir kutuda KIRPILAN sey cekirdek degil YARDIMCI
     * METINdir. §1.3 zaten bunu soyluyor (yardimci etiket, dusme sirasinda
     * cekirdekten once gelir). Bu ancak kirpma NAZIKse dogrudur: her yardimci
     * metin tek satir + `ellipsize=end` olmak zorunda, yoksa metin cihazda
     * yarim glifle kesilir.
     */
    @Test
    fun her_metin_nazik_kirpilir() {
        familyLayouts.forEach { path ->
            val xml = stripComments(read(path))
            val metinler = Regex("<TextView[\\s\\S]*?/>").findAll(xml).toList()
            assertTrue("$path: hic TextView yok", metinler.isNotEmpty())
            metinler.forEach {
                val govde = it.value
                val id = Regex("@\\+id/([A-Za-z0-9_]+)").find(govde)?.groupValues?.get(1)
                assertTrue("$path/$id: ellipsize yok", govde.contains("android:ellipsize=\"end\""))
                assertTrue("$path/$id: maxLines yok", govde.contains("android:maxLines=\"1\""))
            }
        }
    }

    /**
     * Kademe buyurken cekirdek KUCULEMEZ. 2x1'den 2x2'ye buyuten kullanici
     * sayinin kuculdugunu gorurse buyutmenin anlami kalmaz - K3 tavani bu
     * yuzden K2'nin altina inmez.
     */
    @Test
    fun cekirdek_puntosu_kademe_boyunca_kuculmez() {
        assertTrue(PROGRESS_K1_CORE_SP <= PROGRESS_K2_CORE_SP)
        assertTrue(PROGRESS_K2_CORE_SP <= PROGRESS_K3_CORE_SP)
        listOf(
            "stats" to statsKutulari.map {
                statsValueSp(sinif(WidgetSizeSpecs.stats, it), it.w)
            },
            "group_goal" to goalKutulari.map {
                groupGoalPercentSp(sinif(WidgetSizeSpecs.groupGoal, it), it.w)
            },
            "countdown" to countdownKutulari.map {
                countdownDaysSp(sinif(WidgetSizeSpecs.countdown, it), it.w)
            },
        ).forEach { (ad, merdiven) ->
            merdiven.zipWithNext().forEach { (kucuk, buyuk) ->
                assertTrue(
                    "$ad: kademe buyurken punto kuculuyor ($kucuk -> $buyuk)",
                    buyuk >= kucuk,
                )
            }
        }
    }

    /**
     * §7-6: daraltma `sans-serif-condensed` ile yapilir, `textScaleX`
     * 0.85'in ALTINA inmez. Duzendeki deger ile puntonun hesaplandigi katsayi
     * ayni seyi soylemek zorundadir; ayrisirsa merdiven iyimser hesaplanmis
     * olur ve cihazda kirpar.
     */
    @Test
    fun duzenler_sistem_sikistirma_tabanini_kullanir() {
        familyLayouts.forEach { path ->
            val xml = stripComments(read(path))
            Regex("android:textScaleX=\"([0-9.]+)\"").findAll(xml).forEach {
                assertTrue(
                    "$path: textScaleX ${it.groupValues[1]} tabanin altinda",
                    it.groupValues[1].toFloat() >= WIDGET_TEXT_SCALE_X_MIN,
                )
            }
            assertTrue(
                "$path: kahraman sayi `sans-serif-condensed` kullanmiyor",
                xml.contains("android:fontFamily=\"sans-serif-condensed\""),
            )
            assertFalse(
                "$path: `sans-serif-condensed-light` yasak (§3.1)",
                xml.contains("sans-serif-condensed-light"),
            )
            assertFalse(
                "$path: `autoSizeTextType` RemoteViews'ta CALISMAZ (§3.2)",
                xml.contains("autoSizeTextType"),
            )
        }
    }

    /** 1x1'e gercekten sikisabiliyor mu? `minResize*` K1'i ULASILABILIR kilmali. */
    @Test
    fun uc_widget_de_1x1e_kucultulebilir() {
        listOf(
            "odak_stats_widget_info.xml",
            "odak_group_goal_widget_info.xml",
            "odak_countdown_widget_info.xml",
        ).forEach { ad ->
            val info = stripComments(read("$xmlDir/$ad"))
            listOf("minResizeWidth", "minResizeHeight").forEach { nitelik ->
                val deger = Regex("android:$nitelik=\"(\\d+)dp\"")
                    .find(info)?.groupValues?.get(1)?.toInt()
                assertEquals("$ad: $nitelik 1 hucreye (40dp) inmiyor", 40, deger)
            }
        }
    }

    /**
     * 🔴 Sahibin acikca istedigi 1x2 kutusu (40x110dp).
     *
     * Yukseklige ONCE bakan bir siniflandirma orayi K4 sanardi: 36dp'lik ic
     * genislige baslik satiri da yatay yardimci metin de girmez, hepsi uc
     * noktaya inerdi. Dar kutuda tasinabilen tek sey cekirdektir.
     */
    @Test
    fun dar_ama_uzun_kutu_K1_kalir() {
        listOf(
            "stats" to WidgetSizeSpecs.stats,
            "group_goal" to WidgetSizeSpecs.groupGoal,
            "countdown" to WidgetSizeSpecs.countdown,
        ).forEach { (ad, spec) ->
            listOf(40 to 110, 40 to 180, 40 to 250).forEach { (w, h) ->
                assertEquals(
                    "$ad ${w}x$h: dar kutuda kademe yukselmis",
                    ProgressWidgetTier.K1,
                    progressWidgetTier(widgetSizeClass(spec, w, h), w, spec.defaultWidthDp),
                )
            }
        }
        // Ayni yukseklik VARSAYILAN genislikte gercekten yukselir; yukaridaki
        // iddia "kademe hic yukselmiyor" demek DEGIL.
        assertEquals(
            ProgressWidgetTier.K4,
            progressWidgetTier(
                widgetSizeClass(WidgetSizeSpecs.stats, 110, 110),
                110,
                WIDGET_STATS_DEFAULT_WIDTH_DP,
            ),
        )
    }

    /** Kutu -> kademe eslemesi; `res/xml` ile Kotlin ayni seyi soylemeli. */
    @Test
    fun kutu_kademe_eslemesi_beklenen_dallara_duser() {
        statsKutulari.forEach {
            assertEquals("stats ${it.w}x${it.h}", it.tier, kademe(WidgetSizeSpecs.stats, it))
        }
        goalKutulari.forEach {
            assertEquals(
                "group_goal ${it.w}x${it.h}",
                it.tier,
                kademe(WidgetSizeSpecs.groupGoal, it),
            )
        }
        countdownKutulari.forEach {
            assertEquals(
                "countdown ${it.w}x${it.h}",
                it.tier,
                kademe(WidgetSizeSpecs.countdown, it),
            )
        }
    }

    // =======================================================================
    // D) GOSTERGE GEOMETRISI (§4.1)
    //
    // Iki cizim vardir ve KARISTIRILMAZ: ters U yay `arcPercent` ile, duz pill
    // `barPercent` ile surulur. Yanlis eslesme SESSIZdir - yay ortada
    // hizlanir, uclarda takilir; hicbir sey catlamaz.
    //
    // SABOTAJ: `GroupGoalWidget.kt`te `arcPercent` -> `barPercent` -> yalniz
    // bu kume duser.
    // =======================================================================

    @Test
    fun yay_arcPercent_cubuk_barPercent_ile_surulur() {
        data class Gosterge(
            val ad: String,
            val saglayici: String,
            val duzen: String,
            val cizim: String,
            val dogru: String,
            val yanlis: String,
        )
        listOf(
            Gosterge(
                "gunluk hedef (duz pill)",
                "$kotlinDir/StatsWidget.kt",
                statsLayout,
                "@drawable/widget_progress_bar",
                "WidgetDesign.barPercent(",
                "WidgetDesign.arcPercent(",
            ),
            Gosterge(
                "grup hedefi (ters U yay)",
                "$kotlinDir/GroupGoalWidget.kt",
                goalLayout,
                "@drawable/widget_progress_arc",
                "WidgetDesign.arcPercent(",
                "WidgetDesign.barPercent(",
            ),
            Gosterge(
                "geri sayim (ters U yay)",
                "$kotlinDir/CountdownWidget.kt",
                countdownLayout,
                "@drawable/widget_progress_arc",
                "WidgetDesign.arcPercent(",
                "WidgetDesign.barPercent(",
            ),
        ).forEach { g ->
            val saglayici = read(g.saglayici)
            assertTrue(
                "${g.ad}: gosterge ${g.dogru} ile surulmuyor",
                saglayici.contains(g.dogru),
            )
            assertFalse(
                "${g.ad}: yanlis geometri fonksiyonu (${g.yanlis}) kullaniliyor - " +
                    "bu hata SESSIZdir, hicbir sey catlamaz",
                saglayici.contains(g.yanlis),
            )
            assertTrue(
                "${g.ad}: duzen ${g.cizim} cizimini baglamiyor",
                stripComments(read(g.duzen)).contains(g.cizim),
            )
        }
    }

    /**
     * §4.1 / §7-8: yeni geometri uretilmez. Yay bu turda DEGISMEDI, yani
     * WP-752'nin olctugu dolgu/iz ayrisma orani (2.53:1) hala gecerlidir;
     * geometri degistirilirse o oran yeniden olculmelidir.
     */
    @Test
    fun yay_geometrisi_paylasilan_cizimden_gelir_yenisi_uretilmedi() {
        val iz = read("src/main/res/drawable/widget_arc_track_shape.xml")
        val dolgu = read("src/main/res/drawable/widget_arc_fill_shape.xml")
        val yol = Regex("android:pathData=\"([^\"]+)\"")
        assertEquals(
            "yayin izi ile dolgusu ayni geometriyi tasimiyor",
            yol.find(iz)?.groupValues?.get(1),
            yol.find(dolgu)?.groupValues?.get(1),
        )
        assertEquals("M6,50 A44,44 0 0 1 94,50", yol.find(iz)?.groupValues?.get(1))
        // §5: bitmap hicbir kademede yok. 4x2 kartin ARGB_8888 bitmap'i
        // yogunluk 3.5'te ~1.29 MB'dir ve RemoteViews islemini dusurur.
        listOf("StatsWidget.kt", "GroupGoalWidget.kt", "CountdownWidget.kt").forEach { ad ->
            val kaynak = read("$kotlinDir/$ad")
            assertFalse("$ad: `setImageViewBitmap` yasak (§5)", kaynak.contains("setImageViewBitmap"))
            assertFalse("$ad: `Canvas` yasak (§5)", kaynak.contains("android.graphics.Canvas"))
        }
    }

    // =======================================================================
    // E) PALET (§2.2 / §2.3)
    //
    // Alti opak simge. Duzenler ham hex tasimaz, Material You referansi
    // tasimaz, emoji tasimaz.
    //
    // SABOTAJ: bir duzendeki `@color/widget_ember_ink`i `#FFFFFF` yap ->
    // yalniz bu kume duser.
    // =======================================================================

    @Test
    fun duzenler_yalniz_yeni_palet_simgelerini_kullanir() {
        val simgeler = setOf(
            "widget_ember_night", "widget_ember_ash", "widget_ember_flame",
            "widget_ember_glow", "widget_ember_ink", "widget_ember_ink_dim",
        )
        familyLayouts.forEach { path ->
            val xml = stripComments(read(path))
            Regex("@color/([A-Za-z0-9_]+)").findAll(xml).forEach {
                assertTrue(
                    "$path: `${it.groupValues[1]}` yeni palet simgesi degil " +
                        "(WP-717 alias'lari yeniden tasarimda birakildi)",
                    simgeler.contains(it.groupValues[1]),
                )
            }
            assertFalse(
                "$path: ham hex renk var - ikinci bir gorsel dil",
                Regex("=\"#[0-9A-Fa-f]{3,8}\"").containsMatchIn(xml),
            )
            assertFalse(
                "$path: Material You referansi (rengi duvar kagidi secer, " +
                    "kontrasti kimse olcmez)",
                xml.contains("@android:color/system_"),
            )
        }
    }

    /** Palet GERCEKTEN opak mi? Alfa bir kez girerse kontrast iddiasi duser. */
    @Test
    fun palet_opaktir() {
        val palet = read("src/main/res/values/widget_design.xml")
        Regex("<color name=\"(widget_ember_[a-z_]+)\"\\s*>([^<]+)</color>")
            .findAll(palet)
            .forEach {
                assertTrue(
                    "${it.groupValues[1]} opak #RRGGBB degil: ${it.groupValues[2]}",
                    Regex("^#[0-9A-Fa-f]{6}$").matches(it.groupValues[2].trim()),
                )
            }
    }

    /**
     * §4.3: emoji YASAK - cihaz yazi tipine baglidir, OEM'e gore degisir,
     * rengi paletten bagimsizdir. Ayrica kullaniciya donen her metin string
     * kaynagindan gelir (l10n_android_audit ile ayni kural).
     */
    @Test
    fun duzenlerde_gomulu_metin_ve_emoji_yok() {
        familyLayouts.forEach { path ->
            val xml = stripComments(read(path))
            assertFalse(
                "$path: gomulu metin var",
                Regex("android:text=\"(?!@string/)").containsMatchIn(xml),
            )
            assertFalse(
                "$path: emoji / BMP disi karakter var",
                xml.any { Character.isSurrogate(it) },
            )
        }
    }

    // =======================================================================
    // F) KADEME DUSME SIRASI (§1.3)
    //
    // Sira SABITTIR: baslik -> yardimci etiket -> ikincil satirlar -> ayri
    // dokunma hedefi -> grafik. CEKIRDEK ASLA DUSMEZ.
    //
    // Bunun olculebilir hali: kucuk kademede gorunen oge kumesi, buyuk
    // kademede gorunenlerin ALT KUMESIdir ve cekirdek her kumede vardir.
    //
    // SABOTAJ: `progressHeaderVisible`i `tier != K1` yap -> yalniz bu kume duser.
    // =======================================================================

    private fun statsOgeleri(kutu: Kutu): Set<String> {
        val size = sinif(WidgetSizeSpecs.stats, kutu)
        val tier = kademe(WidgetSizeSpecs.stats, kutu)
        return buildSet {
            add("cekirdek")
            if (progressGaugeVisible(tier)) add("cubuk")
            if (statsDetailVisible(size.height) && !progressOnlyCore(tier)) add("gun_ozeti")
            if (statsStreakVisible(size.height) && !progressOnlyCore(tier)) add("seri")
            if (statsTitleVisible(size.height) && progressHeaderVisible(tier)) add("baslik")
            if (progressHeaderVisible(tier)) add("ayrac")
        }
    }

    private fun goalOgeleri(kutu: Kutu): Set<String> {
        val size = sinif(WidgetSizeSpecs.groupGoal, kutu)
        val tier = kademe(WidgetSizeSpecs.groupGoal, kutu)
        return buildSet {
            add("cekirdek")
            if (groupGoalArcVisible(tier, hasData = true)) add("yay")
            if (groupGoalDetailVisible(size.height) && !progressOnlyCore(tier)) add("detay")
            if (groupGoalHeaderVisible(tier)) add("baslik")
        }
    }

    private fun countdownOgeleri(kutu: Kutu): Set<String> {
        val size = sinif(WidgetSizeSpecs.countdown, kutu)
        val tier = kademe(WidgetSizeSpecs.countdown, kutu)
        return buildSet {
            add("cekirdek")
            if (countdownLabelVisible(tier)) add("etiket")
            if (countdownNameVisible(size.height) && !progressOnlyCore(tier)) add("sinav_adi")
            if (countdownArcVisible(size.height, CountdownState.FUTURE) &&
                !progressOnlyCore(tier)
            ) {
                add("yay")
            }
            if (countdownHeaderVisible(tier)) add("baslik")
        }
    }

    @Test
    fun kademe_kuculurken_cekirdek_asla_dusmez() {
        listOf(
            "stats" to statsKutulari.map(::statsOgeleri),
            "group_goal" to goalKutulari.map(::goalOgeleri),
            "countdown" to countdownKutulari.map(::countdownOgeleri),
        ).forEach { (ad, kumeler) ->
            kumeler.forEachIndexed { index, kume ->
                assertTrue("$ad: ${index + 1}. kademede cekirdek yok", kume.contains("cekirdek"))
            }
            // K1 en fazla 1 oge, K2 en fazla 2 (§1.2 kademe butcesi).
            assertEquals("$ad: K1 butcesi asildi -> ${kumeler[0]}", 1, kumeler[0].size)
            assertTrue("$ad: K2 butcesi asildi -> ${kumeler[1]}", kumeler[1].size <= 2)
        }
    }

    @Test
    fun kucuk_kademenin_ogeleri_buyugun_ALT_KUMESIDIR() {
        listOf(
            "stats" to statsKutulari.map(::statsOgeleri),
            "group_goal" to goalKutulari.map(::goalOgeleri),
            "countdown" to countdownKutulari.map(::countdownOgeleri),
        ).forEach { (ad, kumeler) ->
            kumeler.zipWithNext().forEach { (kucuk, buyuk) ->
                assertTrue(
                    "$ad: kademe buyurken oge KAYBOLUYOR (dusme sirasi tersine dondu). " +
                        "kucuk=$kucuk buyuk=$buyuk",
                    buyuk.containsAll(kucuk),
                )
            }
        }
    }

    /**
     * §1.5: K1/K2'de ikinci bir tiklanabilir alan YASAKTIR - iki hedef bir
     * hucreye sigmaz. Ailenin ucu de tek hedeflidir (kokun kendisi), yani
     * saglayicilarda tek bir `setOnClickPendingIntent` bulunur.
     */
    @Test
    fun K1_K2de_tek_dokunma_hedefi_vardir() {
        listOf("StatsWidget.kt", "GroupGoalWidget.kt", "CountdownWidget.kt").forEach { ad ->
            val kaynak = read("$kotlinDir/$ad")
            assertEquals(
                "$ad: birden fazla dokunma hedefi var (§1.5)",
                1,
                Regex("setOnClickPendingIntent\\(").findAll(kaynak).count(),
            )
        }
    }

    /**
     * §2.6: kart yaricapi kademeye baglidir ve secim KODDA yapilir. Duzende
     * tek bir zemin durur; K1/K2'de saglayici onu dar yaricapliyla degistirir.
     * Bu iddia olmadan `widget_card_bg_tight` olu bir dosya olurdu.
     */
    @Test
    fun kart_yaricapi_kademeye_gore_kodda_secilir() {
        assertTrue(progressCardIsTight(ProgressWidgetTier.K1))
        assertTrue(progressCardIsTight(ProgressWidgetTier.K2))
        assertFalse(progressCardIsTight(ProgressWidgetTier.K3))
        assertFalse(progressCardIsTight(ProgressWidgetTier.K4))
        listOf("StatsWidget.kt", "GroupGoalWidget.kt", "CountdownWidget.kt").forEach { ad ->
            val kaynak = read("$kotlinDir/$ad")
            assertTrue(
                "$ad: kademeye gore kart zemini secilmiyor",
                kaynak.contains("\"setBackgroundResource\""),
            )
            assertTrue(
                "$ad: dar yaricapli kart hic kullanilmiyor",
                kaynak.contains("R.drawable.widget_card_bg_tight"),
            )
        }
    }

    /** §4.2: seri alevi uc AYRI dosyadir; secim saf ve olculebilir. */
    @Test
    fun seri_alevi_durumu_yuzdeden_turer() {
        assertEquals(ProgressFlame.OFF, progressFlame(0))
        assertEquals(ProgressFlame.ON, progressFlame(1))
        assertEquals(ProgressFlame.ON, progressFlame(99))
        assertEquals(ProgressFlame.PEAK, progressFlame(100))
        val stats = read("$kotlinDir/StatsWidget.kt")
        listOf("widget_flame_off", "widget_flame_on", "widget_flame_peak").forEach {
            assertTrue("$it hic kullanilmiyor", stats.contains("R.drawable.$it"))
            assertTrue(
                "drawable/$it.xml yok",
                Files.exists(Path.of("src/main/res/drawable/$it.xml")),
            )
        }
    }

    /**
     * WP-730 gerekcesinin kademeye tasinmis hali: yay varken vurgu YAYIN
     * dolgusundadir, yuzde okunur tona alinir. Yayin dustugu kademede vurguyu
     * tasiyacak baska bir sey kalmaz; orada sayi kahramandir.
     */
    @Test
    fun grup_hedefinde_her_kademede_TEK_turuncu_odak_vardir() {
        goalKutulari.forEach { kutu ->
            val tier = kademe(WidgetSizeSpecs.groupGoal, kutu)
            assertEquals(
                "group_goal/$tier: yay ile yuzde ayni anda vurgu tasiyor ya da " +
                    "hicbiri tasimiyor",
                groupGoalArcVisible(tier, hasData = true),
                !groupGoalPercentIsHero(tier),
            )
        }
    }

    /**
     * 🔴 BAYAT YORUM NOBETCISI. `odak_stats_widget_info.xml` uzun sure
     * gercek olmayan esikler yaziyordu ("gun ozeti 150dp'de, seri satiri
     * 180dp'de acilir") ve artik var olmayan bir dosyayi
     * (`StudyWidgetProviders.kt`, WP-752'de bolundu) kaynak gosteriyordu.
     * Yorum kod degildir ama bir sonraki ajanin OKUDUGU seydir.
     */
    @Test
    fun boyut_tanimlarindaki_yorumlar_gercegi_anlatir() {
        val info = read("$xmlDir/odak_stats_widget_info.xml")
        listOf(
            "StudyWidgetProviders.kt",
            "Gun ozeti 150dp'de",
            "seri satiri 180dp'de acilir",
            "kucultme siniri 110x110dp",
        ).forEach {
            assertFalse("odak_stats_widget_info.xml hala bayat iddia tasiyor: `$it`", info.contains(it))
        }
        // Gercek esikler `WidgetCommon.kt` sabitleridir; yorum onlari soylemeli.
        assertTrue(
            "yorum gercek yukseklik esiklerini yazmiyor",
            info.contains("${WIDGET_STATS_MEDIUM_HEIGHT_DP}dp") &&
                info.contains("${WIDGET_STATS_TALL_HEIGHT_DP}dp"),
        )
    }
}
