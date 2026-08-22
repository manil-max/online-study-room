package com.manilmax.online_study_room.widgets

import java.nio.file.Files
import java.nio.file.Path
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * WP-754 — sayac + saat ailesinin yeniden tasarimi.
 *
 * Sozlesme: `docs/tasarim/widget-tasarim-sistemi.md`. Bu dosya o belgenin
 * **bu uc widget'a** dusen kismini olcer:
 *   A) sifir-gorsel kusuru (dokuz duzen, sifir `ImageView`) kapandi mi,
 *   B) K1 cekirdegi gercekten kucuk mu (<= 3 karakter) ve NEDEN glif,
 *   C) punto merdiveni §3.4 genislik tavanini asmiyor mu,
 *   D) `textScaleX` tabanda mi ve duzen ile Kotlin AYNI sayiyi mi soyluyor,
 *   E) kademe dusme sirasi cekirdegi hic dusuruyor mu,
 *   F) duzenler yalniz yeni paleti kullaniyor mu (ham hex / eski alias yok),
 *   G) widget secici beyani (label + kategori) tam mi.
 *
 * 🔴 Iddialarin hepsi ya SAF fonksiyondan ya da KAYNAK dosyanin kendisinden
 * turer; hicbiri elle yazilmis bir sayiyi tekrarlamaz. Bu depoda "kapi dogru
 * seye bakiyor gorunup eksik kumeyi olcuyor" kusuru uc kez pahaliya mal oldu.
 */
class TimerFamilyRedesignWp754Test {

    private fun read(relative: String): String =
        String(Files.readAllBytes(Path.of(relative)), Charsets.UTF_8)

    /** Yorum bloklari elenmis duzen: yorumdaki ornek nitelik olcume girmesin. */
    private fun layout(name: String): String =
        read("src/main/res/layout/$name.xml").replace(Regex("<!--[\\s\\S]*?-->"), "")

    private fun infoXml(name: String): String =
        read("src/main/res/xml/$name.xml").replace(Regex("<!--[\\s\\S]*?-->"), "")

    private val timerLayout get() = layout("odak_timer_widget")
    private val minimalLayout get() = layout("odak_minimal_timer_widget")
    private val clockLayout get() = layout("odak_clock_widget")

    private fun allThree() = mapOf(
        "odak_timer_widget" to timerLayout,
        "odak_minimal_timer_widget" to minimalLayout,
        "odak_clock_widget" to clockLayout,
    )

    // =======================================================================
    // A) Sifir-gorsel kusuru — sahibin sikayetinin olculmus hali
    //
    // SABOTAJ: bir duzenden `<ImageView` blogunu sil -> yalniz bu test duser.
    // =======================================================================

    @Test
    fun uc_duzen_de_artik_GORSEL_tasir() {
        allThree().forEach { (name, source) ->
            assertTrue(
                "$name hala sadece yazi: hicbir ImageView yok (WP-750 §0 teshisi)",
                source.contains("<ImageView"),
            )
        }
    }

    @Test
    fun ikonlar_paylasilan_sozlukten_gelir_yenisi_uretilmedi() {
        // §4.3: sayac ve minimal sayac ORTAK ikonu paylasir (urunun ana
        // simgesi); saat kendi ay+yildizini tasir. Yeni bir ikon uretmek
        // ailenin gorsel dilini catallardi.
        assertTrue(timerLayout.contains("@drawable/widget_ic_timer"))
        assertTrue(minimalLayout.contains("@drawable/widget_ic_timer"))
        assertTrue(clockLayout.contains("@drawable/widget_ic_clock"))
        // §4.4: ayrac duz `View` degil 1dp `ImageView` zeminidir.
        assertTrue(timerLayout.contains("@drawable/widget_divider"))
        assertTrue(
            "ayrac kalinligi paylasilan olcuden gelmeli",
            timerLayout.contains("@dimen/widget_design_divider"),
        )
        listOf(
            "widget_ic_timer",
            "widget_ic_clock",
            "widget_divider",
        ).forEach {
            assertTrue(
                "$it cizimi yok: duzen derlenir ama ekranda hicbir sey cikmaz",
                Files.exists(Path.of("src/main/res/drawable/$it.xml")),
            )
        }
    }

    /** `android:id="@+id/x"` tasiyan tek etiketin nitelik blogu. */
    private fun element(source: String, id: String): String {
        val marker = source.indexOf("android:id=\"@+id/$id\"")
        assertTrue("$id duzende yok", marker >= 0)
        return source.substring(source.lastIndexOf('<', marker), source.indexOf('>', marker))
    }

    private fun dp(element: String, attribute: String): Int {
        val match = Regex("android:$attribute=\"(\\d+)dp\"").find(element)
        assertTrue("$attribute dp olarak beyan edilmemis", match != null)
        return match!!.groupValues[1].toInt()
    }

    @Test
    fun gorsel_olculeri_duzen_ile_kotlinde_AYNI_sayidir() {
        // Punto icin zaten bir ayna var (WP-730/718); grafikler icin yoktu ve
        // dikey butce aritmetigi (`timerMarkBlockDp`) tam da bu dp'leri
        // kullaniyor. Ayrisirlarsa test "sigiyor" derken ekran kirpar.
        assertEquals(
            WIDGET_TIMER_GLYPH_DP,
            dp(element(timerLayout, "timer_widget_glyph"), "layout_height"),
        )
        assertEquals(
            WIDGET_TIMER_MARK_DP,
            dp(element(timerLayout, "timer_widget_mark"), "layout_height"),
        )
        assertEquals(
            WIDGET_TIMER_COMPACT_ACTION_DP,
            dp(element(timerLayout, "timer_widget_compact_action"), "layout_height"),
        )
        assertEquals(
            WIDGET_MINIMAL_TIMER_GLYPH_DP,
            dp(element(minimalLayout, "minimal_timer_widget_glyph"), "layout_height"),
        )
        assertEquals(
            WIDGET_CLOCK_GLYPH_DP,
            dp(element(clockLayout, "clock_widget_glyph"), "layout_height"),
        )
        assertEquals(
            WIDGET_CLOCK_MARK_DP,
            dp(element(clockLayout, "clock_widget_mark"), "layout_height"),
        )
    }

    // =======================================================================
    // B) K1 cekirdegi (§1.4) — <= 3 karakter, ve NEDEN glif
    //
    // SABOTAJ: `timerCoreIsGlyph`i `false` dondurecek sekilde boz -> B ve E
    // kumeleri duser.
    // =======================================================================

    @Test
    fun her_widgetin_K1_cekirdegi_en_fazla_uc_karakterdir() {
        val k1 = 40 // 70n-30, n=1
        assertTrue(
            "sayac K1'de ${timerCoreChars(k1)} karakter ciziyor",
            timerCoreChars(k1) <= 3,
        )
        assertTrue(
            "minimal sayac K1'de ${minimalTimerCoreChars(k1)} karakter ciziyor",
            minimalTimerCoreChars(k1) <= 3,
        )
        assertTrue(
            "saat K1'de ${clockCoreChars(k1)} karakter ciziyor",
            clockCoreChars(k1) <= 3,
        )
        // Ust kademede cekirdek TAM metindir; aksi halde yukaridaki iddia
        // "hicbir widget hicbir sey cizmiyor" diye de yesil gecerdi.
        assertEquals(WIDGET_TIMER_TIME_CHARS, timerCoreChars(110))
        assertEquals(WIDGET_TIMER_TIME_CHARS, minimalTimerCoreChars(110))
        assertEquals(WIDGET_CLOCK_TIME_CHARS, clockCoreChars(110))
    }

    @Test
    fun K1_cekirdegi_METIN_olamaz_cunku_11sp_tabani_kirilir() {
        // §3.4 modeli, bu ailenin kendi sikistirmasiyla. Sayilar elle
        // yazilmadi; `widgetMaxSp` yeniden hesaplar.
        val timerCeiling = widgetMaxSp(
            widthDp = 40,
            paddingDp = WIDGET_MINIMAL_TIMER_PADDING_DP,
            chars = WIDGET_TIMER_TIME_CHARS,
            advanceScale = WIDGET_TIMER_TEXT_SCALE_X,
        )
        assertTrue(
            "40dp kutuda 8 karakter ${timerCeiling}sp ile ciziliyor; " +
                "11sp tabaninin altinda degilse cekirdek metin OLABILIRDI",
            timerCeiling < WIDGET_MIN_TEXT_SP,
        )
        val clockCeiling = widgetMaxSp(
            widthDp = 40,
            paddingDp = 4,
            chars = WIDGET_CLOCK_TIME_CHARS,
            advanceScale = WIDGET_TEXT_SCALE_X_MIN,
        )
        assertTrue(
            "40dp kutuda `HH:MM` ${clockCeiling}sp ile ciziliyor; saatin K1'de " +
                "sayisi olabilirdi ve glif kararinin gerekcesi yanlis olurdu",
            clockCeiling < WIDGET_MIN_TEXT_SP,
        )
    }

    @Test
    fun glif_kademesi_gercekten_cizilir_ve_ustunde_sayiya_birakir() {
        // Launcher 1 hucreyi ~70-85dp bildirir; 2 hucre 110dp'dir.
        listOf(40, 70, 85, 109).forEach {
            assertTrue("$it dp'de glif kademesi kapali", timerCoreIsGlyph(it))
            assertTrue("$it dp'de minimal glif kademesi kapali", minimalTimerCoreIsGlyph(it))
            assertTrue("$it dp'de saat glif kademesi kapali", clockCoreIsGlyph(it))
        }
        listOf(110, 150, 220, 250).forEach {
            assertFalse("$it dp'de sayi yerine glif ciziliyor", timerCoreIsGlyph(it))
            assertFalse("$it dp'de sayi yerine glif ciziliyor", minimalTimerCoreIsGlyph(it))
            assertFalse("$it dp'de saat yerine glif ciziliyor", clockCoreIsGlyph(it))
        }
    }

    // =======================================================================
    // C) Genislik tavani (§3.4) — merdiven tavani ASMAZ
    //
    // SABOTAJ: `timerTimeSp`ten `budget` kirpmasini kaldir -> yalniz bu kume
    // duser (110dp kutuda merdivenin 28sp'si secilir, tavan 23sp'dir).
    // =======================================================================

    private data class Kutu(val ad: String, val w: Int, val h: Int)

    private val kutular = listOf(
        Kutu("1x1", 70, 70),
        Kutu("2x1", 110, 40),
        Kutu("2x1 uzun", 110, 80),
        Kutu("2x2", 110, 110),
        Kutu("3x2", 180, 110),
        Kutu("4x2", 250, 110),
        Kutu("2x3", 110, 180),
        Kutu("4x3", 250, 180),
    )

    @Test
    fun sayac_puntosu_hicbir_kutuda_genislik_tavanini_asmaz() {
        kutular.forEach { kutu ->
            val size = widgetSizeClass(WidgetSizeSpecs.timer, kutu.w, kutu.h)
            val sp = timerTimeSp(size, kutu.w)
            val butce = widgetMaxSp(
                widthDp = kutu.w,
                paddingDp = timerRootPaddingDp(size),
                chars = WIDGET_TIMER_TIME_CHARS,
                advanceScale = WIDGET_TIMER_TEXT_SCALE_X,
            )
            assertTrue(
                "${kutu.ad}: ${sp}sp seciliyor, kutu en fazla ${butce}sp tasiyor",
                sp <= butce,
            )
            assertTrue("${kutu.ad}: punto 11sp tabaninin altina dustu", sp >= WIDGET_MIN_TEXT_SP)
        }
    }

    @Test
    fun minimal_puntosu_hicbir_kutuda_genislik_tavanini_asmaz() {
        kutular.forEach { kutu ->
            val sp = minimalTimerTimeSp(kutu.w, kutu.h)
            val butce = widgetMaxSp(
                widthDp = kutu.w,
                paddingDp = WIDGET_MINIMAL_TIMER_PADDING_DP,
                chars = WIDGET_TIMER_TIME_CHARS,
                advanceScale = WIDGET_MINIMAL_TIMER_TEXT_SCALE_X,
            )
            assertTrue(
                "${kutu.ad}: ${sp}sp seciliyor, kutu en fazla ${butce}sp tasiyor",
                sp <= butce,
            )
        }
    }

    @Test
    fun tavan_GERCEKTEN_baglar_yoksa_iddia_bos_kalirdi() {
        // 🔴 Bu depoda "yesil ama hicbir sey olcmeyen kapi" uc kez bedel
        // odetti. Yukaridaki iki iddia, tavan hic devreye girmeseydi de yesil
        // gecerdi. Burada tavanin ISIRDIGI kutu adiyla sabitlenir:
        // 110dp/4dp dolgu/8 karakter/0.85 -> 23sp; merdivenin dar basamagi ise
        // 28sp. Yani secilen sayi merdivenden DEGIL tavandan gelir.
        val size = widgetSizeClass(WidgetSizeSpecs.timer, 110, 110)
        val butce = widgetMaxSp(110, timerRootPaddingDp(size), WIDGET_TIMER_TIME_CHARS, WIDGET_TIMER_TEXT_SCALE_X)
        assertTrue(
            "merdiven zaten tavanin altinda: tavan hicbir sey yapmiyor",
            WidgetTypography.timerTime.narrow > butce,
        )
        assertEquals("secilen punto tavandan gelmiyor", butce, timerTimeSp(size, 110))
    }

    // =======================================================================
    // D) `textScaleX` (§3.1 / §7-6) — taban 0.85, duzen ve Kotlin ayni sayi
    //
    // SABOTAJ: bir duzende `textScaleX`i 0.55'e dondur -> yalniz bu kume duser.
    // =======================================================================

    @Test
    fun yatay_sikistirma_tabandadir_ve_duzen_ile_kotlin_ayni_sayiyi_soyler() {
        assertTrue(
            "sayac sikistirmasi tabanin altinda: rakam yatay EZILIR",
            WIDGET_TIMER_TEXT_SCALE_X >= WIDGET_TEXT_SCALE_X_MIN,
        )
        assertTrue(
            "minimal sayac sikistirmasi tabanin altinda",
            WIDGET_MINIMAL_TIMER_TEXT_SCALE_X >= WIDGET_TEXT_SCALE_X_MIN,
        )
        assertTrue(
            timerLayout.contains("android:textScaleX=\"$WIDGET_TIMER_TEXT_SCALE_X\""),
        )
        assertTrue(
            minimalLayout.contains(
                "android:textScaleX=\"$WIDGET_MINIMAL_TIMER_TEXT_SCALE_X\"",
            ),
        )
        assertTrue(
            clockLayout.contains("android:textScaleX=\"$WIDGET_TEXT_SCALE_X_MIN\""),
        )
    }

    @Test
    fun daraltmayi_yazi_tipi_yapar_ve_ince_kesim_yasaktir() {
        allThree().forEach { (name, source) ->
            assertTrue(
                "$name daraltmayi hala yalniz `textScaleX` ile yapiyor",
                source.contains("android:fontFamily=\"sans-serif-condensed\""),
            )
            assertFalse(
                "$name `sans-serif-condensed-light` kullaniyor: sac inceligindeki " +
                    "cizgiler duvar kagidi parildisinda kaybolur (§3.1)",
                source.contains("sans-serif-condensed-light"),
            )
        }
    }

    // =======================================================================
    // E) Dusme sirasi (§1.3) — cekirdek ASLA dusmez, sus once duser
    //
    // SABOTAJ: `timerMarkVisible`i sabit `true` yap -> yalniz bu kume duser
    // (3x2 kutusunda isaret + sayi + 48dp hap 100dp'ye sigmaz).
    // =======================================================================

    /** Cekirdek disindaki oge sayisi (sus): isaret, ayrac, hap(lar), chip. */
    private fun timerOrnaments(w: Int, h: Int): Int {
        val size = widgetSizeClass(WidgetSizeSpecs.timer, w, h)
        var n = 0
        if (timerMarkVisible(size, w, h)) n++
        if (timerRuleVisible(size, w, h)) n++
        if (timerCompactActionVisible(size, w, h)) n++
        if (timerControlsVisible(size.height)) n++
        if (timerSubjectVisible(size)) n++
        return n
    }

    @Test
    fun cekirdek_hicbir_kademede_dusmez() {
        kutular.forEach { kutu ->
            val size = widgetSizeClass(WidgetSizeSpecs.timer, kutu.w, kutu.h)
            val core = timerCoreIsGlyph(kutu.w) ||
                timerTimeSp(size, kutu.w) >= WIDGET_MIN_TEXT_SP
            assertTrue("${kutu.ad}: sayac cekirdeksiz kaldi", core)
            assertTrue(
                "${kutu.ad}: minimal sayac cekirdeksiz kaldi",
                minimalTimerCoreIsGlyph(kutu.w) ||
                    minimalTimerTimeSp(kutu.w, kutu.h) >= WIDGET_MIN_TEXT_SP,
            )
            assertTrue(
                "${kutu.ad}: saat cekirdeksiz kaldi",
                clockCoreIsGlyph(kutu.w) ||
                    clockTimeSp(widgetSizeClass(WidgetSizeSpecs.clock, kutu.w, kutu.h)) >=
                    WIDGET_MIN_TEXT_SP,
            )
        }
    }

    @Test
    fun kutu_buyudukce_sus_artar_kucuduce_once_sus_duser() {
        // Kucukten buyuge. Sus sayisi hicbir adimda AZALMAZ; yani kademe
        // butcesi (§1.2) tek yonlu genisler.
        val artan = listOf(
            Kutu("1x1", 70, 70),
            Kutu("2x1", 110, 40),
            Kutu("2x1 uzun", 110, 80),
            Kutu("2x2", 110, 110),
            Kutu("3x2", 180, 110),
            Kutu("3x3", 180, 180),
            Kutu("4x3", 250, 180),
        )
        var onceki = -1
        artan.forEach { kutu ->
            val simdi = timerOrnaments(kutu.w, kutu.h)
            assertTrue(
                "${kutu.ad}: sus sayisi $onceki -> $simdi (kucuk kutuda daha cok " +
                    "oge var: dusme sirasi ters isliyor)",
                simdi >= onceki,
            )
            onceki = simdi
        }
        // K1 ve K2 TEK ogelidir: ikinci bir tiklanabilir alan yasaktir (§1.5).
        assertEquals("K1'de ikinci bir oge var", 0, timerOrnaments(70, 70))
        assertEquals("K2'de ikinci bir oge var", 0, timerOrnaments(110, 40))
        // Minimal sayac HER kademede tek ogelidir - "akraba ama ikiz degil".
        kutular.forEach { kutu ->
            assertFalse(
                "${kutu.ad}: minimal sayac artik minimal degil",
                minimalLayout.contains("@drawable/widget_action_bg") ||
                    minimalLayout.contains("@drawable/widget_chip_bg") ||
                    minimalLayout.contains("@drawable/widget_progress_arc"),
            )
        }
    }

    @Test
    fun varsayilan_2x1_kutusunda_kompakt_hap_TASMAZ() {
        // 🔴 Olculen "once": `!controlsVisible` tek kosuldu; 110x40dp'lik
        // varsayilan kutuda sayi + 2dp + 22dp hap, 32dp'lik ic yukseklige
        // sigmiyordu.
        val varsayilan = widgetSizeClass(WidgetSizeSpecs.timer, 110, 40)
        assertFalse(timerCompactActionVisible(varsayilan, 110, 40))
        // Ipucu bir OLU ANAHTAR degil: sigdigi kutuda gercekten cizilir.
        val genis = widgetSizeClass(WidgetSizeSpecs.timer, 110, 80)
        assertTrue(timerCompactActionVisible(genis, 110, 80))
    }

    @Test
    fun isaret_sigmadigi_kutuda_duser_sigdigi_kutuda_cizilir() {
        val ikiKareye = widgetSizeClass(WidgetSizeSpecs.timer, 110, 110)
        assertTrue("2x2'de ocak isareti sigiyor ama cizilmiyor", timerMarkVisible(ikiKareye, 110, 110))
        val genisKisa = widgetSizeClass(WidgetSizeSpecs.timer, 180, 110)
        assertFalse(
            "3x2'de isaret + sayi + 48dp hap 100dp'ye sigmiyor ama yine de ciziliyor",
            timerMarkVisible(genisKisa, 180, 110),
        )
        assertTrue(
            "3x2 aritmetigi degismis: gerekce bayat",
            timerMarkBlockDp(genisKisa, 180) > 110 - 2f * timerRootPaddingDp(genisKisa),
        )
        // Ayrac tek basina bir sey ayirmaz: isaret yoksa ayrac da yoktur.
        kutular.forEach { kutu ->
            val size = widgetSizeClass(WidgetSizeSpecs.timer, kutu.w, kutu.h)
            if (timerRuleVisible(size, kutu.w, kutu.h)) {
                assertTrue("${kutu.ad}: ayrac isaretsiz cizildi", timerMarkVisible(size, kutu.w, kutu.h))
            }
        }
    }

    // =======================================================================
    // F) Palet (§2.2) — yalniz alti opak simge; ham hex ve eski alias yok
    //
    // SABOTAJ: bir duzende `@color/widget_ember_ink`i `#F6EFE6` yap -> yalniz
    // bu test duser.
    // =======================================================================

    @Test
    fun duzenler_yalniz_yeni_palet_simgelerini_kullanir() {
        allThree().forEach { (name, source) ->
            assertFalse(
                "$name gomulu hex renk tasiyor: ikinci bir gorsel dil",
                Regex("android:(textColor|background|src|tint)=\"#").containsMatchIn(source),
            )
            val renkler = Regex("@color/(\\w+)").findAll(source).map { it.groupValues[1] }.toSet()
            assertTrue("$name hic renk simgesi kullanmiyor", renkler.isNotEmpty())
            renkler.forEach {
                assertTrue(
                    "$name eski/alias simge kullaniyor: $it (yeni palet " +
                        "`widget_ember_*`)",
                    it.startsWith("widget_ember_"),
                )
            }
        }
    }

    @Test
    fun flame_zeminli_metin_daima_night_tonundadir() {
        // §2.3 sert kurali: `ink` on `flame` = 2.06:1 (basarisiz).
        // `widget_action_bg` dolgusu `flame`dir; ustundeki iki metin de
        // `night` olmak zorunda.
        val haplar = Regex("<TextView\\b[^>]*/>")
            .findAll(timerLayout)
            .map { it.value }
            .filter { it.contains("@drawable/widget_action_bg") }
            .toList()
        assertEquals("eylem hapi bulunamadi", 2, haplar.size)
        haplar.forEach {
            assertTrue(
                "eylem hapinin metni `night` degil: kart zeminine 2.06:1 duser",
                it.contains("android:textColor=\"@color/widget_ember_night\""),
            )
        }
        // `ash` bir METIN rengi degildir (karta 3.24:1) - hicbir duzende metin
        // rengi olarak kullanilamaz.
        allThree().forEach { (name, source) ->
            assertFalse(
                "$name `ash` tonunu metin rengi olarak kullaniyor (§2.3)",
                source.contains("android:textColor=\"@color/widget_ember_ash\""),
            )
        }
    }

    @Test
    fun kart_yaricapi_kademeye_baglidir() {
        // §2.6: K1/K2'de 12dp, K3/K4'te 20dp. 40x40dp kutuda 20dp yaricap
        // koselerin TAMAMINI yer.
        assertTrue(
            "K1/K2 ile K3/K4 ayni zemini kullaniyor: yaricap kademeye bagli degil",
            widgetCardBackground(WidgetHeightClass.SHORT) !=
                widgetCardBackground(WidgetHeightClass.MEDIUM),
        )
        assertEquals(
            widgetCardBackground(WidgetHeightClass.MEDIUM),
            widgetCardBackground(WidgetHeightClass.TALL),
        )
        allThree().forEach { (name, source) ->
            assertTrue(
                "$name dar kutuda genis yaricapla aciliyor (onizleme 2x1'dir)",
                source.contains("@drawable/widget_card_bg_tight"),
            )
        }
    }

    // =======================================================================
    // G) Widget secici beyani — label + kategori
    //
    // SABOTAJ: manifestten bir `android:label` satirini sil -> yalniz bu kume
    // duser.
    // =======================================================================

    @Test
    fun dokuz_saglayicinin_hepsi_secicide_kendi_adiyla_gorunur() {
        // 🔴 Olculen "once": bes saglayicinin `android:label`i YOKTU; Android
        // widget secicisinde besi de uygulama adiyla ("Focus Camp") gorunuyor
        // ve birbirinden ayirt edilemiyordu. Hicbir derleme hatasi bunu
        // soylemez.
        val manifest = read("src/main/AndroidManifest.xml")
            .replace(Regex("<!--[\\s\\S]*?-->"), "")
        val en = read("src/main/res/values/strings.xml")
        val tr = read("src/main/res/values-tr/strings.xml")
        val basliklar = Regex("<receiver[^>]*>")
            .findAll(manifest)
            .map { it.value }
            .filter { it.contains("WidgetProvider\"") }
            .toList()
        assertEquals("manifest ayristirilamadi: dokuz saglayici bekleniyor", 9, basliklar.size)
        val eksik = basliklar.filterNot { it.contains("android:label=\"@string/") }
        assertTrue("etiketsiz widget saglayicisi kaldi: $eksik", eksik.isEmpty())

        listOf(
            "widget_label_timer",
            "widget_label_minimal_timer",
            "widget_label_task",
            "widget_label_stats",
            "widget_label_leaderboard",
        ).forEach {
            assertTrue("$it manifestte kullanilmiyor", manifest.contains("@string/$it"))
            assertTrue("EN $it yok", en.contains("name=\"$it\""))
            assertTrue("TR $it yok", tr.contains("name=\"$it\""))
        }
    }

    @Test
    fun uc_widget_de_ana_ekran_kategorisini_beyan_eder() {
        listOf(
            "odak_timer_widget_info",
            "odak_minimal_timer_widget_info",
            "odak_clock_widget_info",
        ).forEach {
            assertTrue(
                "$it `widgetCategory` beyan etmiyor: bazi OEM launcher'lari " +
                    "widget'i kilit ekrani kategorisinde de listeler",
                infoXml(it).contains("android:widgetCategory=\"home_screen\""),
            )
        }
    }
}
