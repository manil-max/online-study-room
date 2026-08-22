package com.manilmax.online_study_room.widgets

import java.nio.file.Files
import java.nio.file.Path
import kotlin.math.pow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * WP-752 — ana ekran widget'larinin PAYLASILAN tasarim sistemi.
 *
 * Sozlesme: `docs/tasarim/widget-tasarim-sistemi.md`. Bu dosya o belgenin
 * SAYILARINI olcer; belgeye guvenmez. Kontrast oranlari burada WCAG 2.1 bagil
 * parlaklik formuluyle (`L = 0.2126R + 0.7152G + 0.0722B`, sRGB
 * dogrusallastirilmis) YENIDEN HESAPLANIR - belgede yazan sayi kopyalanmaz.
 *
 * Uc iddia kumesi, uc ayri sabotaj:
 *   A) Palet — bir simgeyi degistir, yalniz A duser.
 *   B) Genislik modeli — `WIDGET_TEXT_SCALE_X_MIN`i dusur, yalniz B duser.
 *   C) Ortak gorsel sozluk — bir cizimi sil, yalniz C duser.
 */
class WidgetDesignSystemWp752Test {

    private fun read(relative: String): String =
        String(Files.readAllBytes(Path.of(relative)), Charsets.UTF_8)

    private val paletteFile = "src/main/res/values/widget_design.xml"

    private fun stripComments(xml: String): String =
        Regex("<!--[\\s\\S]*?-->").replace(xml, "")

    private fun colors(xml: String): Map<String, String> =
        Regex("<color\\s+name=\"([^\"]+)\"\\s*>([^<]+)</color>")
            .findAll(stripComments(xml))
            .associate { it.groupValues[1] to it.groupValues[2].trim() }

    /** `@color/x` alias'ini ayni dosyadaki hex degere cozer. */
    private fun resolve(palette: Map<String, String>, value: String): String {
        var current = value
        repeat(4) {
            if (!current.startsWith("@color/")) return current
            current = palette[current.removePrefix("@color/")] ?: return current
        }
        return current
    }

    private fun hex(name: String): String {
        val palette = colors(read(paletteFile))
        val raw = palette[name] ?: error("$name paletten dusmus")
        val resolved = resolve(palette, raw)
        assertTrue("$name sabit #RRGGBB degil: $resolved", Regex("^#[0-9A-Fa-f]{6}$").matches(resolved))
        return resolved
    }

    /** WCAG 2.1 bagil parlaklik. */
    private fun luminance(hexColor: String): Double {
        val value = hexColor.removePrefix("#")
        fun channel(offset: Int): Double {
            val raw = value.substring(offset, offset + 2).toInt(16) / 255.0
            return if (raw <= 0.03928) raw / 12.92 else ((raw + 0.055) / 1.055).pow(2.4)
        }
        return 0.2126 * channel(0) + 0.7152 * channel(2) + 0.0722 * channel(4)
    }

    private fun contrast(a: String, b: String): Double {
        val la = luminance(a)
        val lb = luminance(b)
        return (maxOf(la, lb) + 0.05) / (minOf(la, lb) + 0.05)
    }

    // =======================================================================
    // A) Palet — tek koyu kimlik, alti opak simge (§2.1-2.3)
    //
    // SABOTAJ: `widget_ember_ink`i `#A79483` yap -> yalniz bu kume duser.
    // =======================================================================

    @Test
    fun palet_alti_opak_simgedir_ve_alfa_tasimaz() {
        listOf(
            "widget_ember_night", "widget_ember_ash", "widget_ember_flame",
            "widget_ember_glow", "widget_ember_ink", "widget_ember_ink_dim",
        ).forEach { hex(it) } // #RRGGBB olmayan (yani alfali) deger burada patlar
        assertTrue(
            "widget yigininda Material You referansi var",
            !stripComments(read(paletteFile)).contains("@android:color/"),
        )
    }

    @Test
    fun metin_renkleri_kart_zemininde_WCAG_AA_gecer() {
        val night = hex("widget_ember_night")
        assertTrue(
            "ana metin kartta okunmuyor: ${contrast(hex("widget_ember_ink"), night)}",
            contrast(hex("widget_ember_ink"), night) >= 4.5,
        )
        assertTrue(
            "yardimci metin kartta okunmuyor: ${contrast(hex("widget_ember_ink_dim"), night)}",
            contrast(hex("widget_ember_ink_dim"), night) >= 4.5,
        )
        assertTrue(contrast(hex("widget_ember_flame"), night) >= 4.5)
        assertTrue(contrast(hex("widget_ember_glow"), night) >= 4.5)
    }

    /**
     * 🔴 §2.3, birinci sert kural. Iddia IKI YONLUdur: `ash` grafik esigini
     * (WCAG 1.4.11 -> 3:1) gecer ama metin esigini (1.4.3 -> 4.5:1) GECMEZ.
     * Tek yonlu yazilsaydi biri `ash`i metin rengi yapar ve hicbir test bunu
     * soylemezdi - deponun "kirmizi rozet kirmizi temada kayboluyor" dersi.
     */
    @Test
    fun ash_grafik_rengidir_metin_rengi_DEGILDIR() {
        val ratio = contrast(hex("widget_ember_ash"), hex("widget_ember_night"))
        assertTrue("yay izi / kenar kartta gorunmuyor: $ratio", ratio >= 3.0)
        assertTrue("`ash` metin esigini gecti: §2.3 yeniden okunmali: $ratio", ratio < 4.5)
    }

    /**
     * 🔴 §2.3, ikinci sert kural: `flame`/`glow` UZERINDEKI metin DAIMA
     * `night`tir. `ink` on `flame` 2.06:1'dir - basarisiz.
     */
    @Test
    fun flame_ve_glow_uzerindeki_metin_DAIMA_nighttir() {
        val flame = hex("widget_ember_flame")
        val glow = hex("widget_ember_glow")
        val ink = hex("widget_ember_ink")
        val night = hex("widget_ember_night")

        assertTrue(
            "`ink` on `flame` okunur cikti (${contrast(ink, flame)}): sert kuralin gerekcesi dustu",
            contrast(ink, flame) < 4.5,
        )
        assertTrue(
            "`ink` on `glow` okunur cikti (${contrast(ink, glow)}): sert kuralin gerekcesi dustu",
            contrast(ink, glow) < 4.5,
        )
        assertTrue("eylem hapinin metni okunmuyor", contrast(night, flame) >= 4.5)
        assertTrue("1. sira rozetinin rakami okunmuyor", contrast(night, glow) >= 4.5)
    }

    /**
     * §2.3 sonucu: 2. ve sonraki sira rozetleri `ash` ZEMINLI olamaz.
     * Olculen "once": `widget_rank_other_bg` izi (`ash`) dolgu yapiyordu ve
     * rozetin icindeki rakam 3.24:1'lik bir zemine yaziliyordu.
     */
    @Test
    fun sira_rozetleri_dogru_zemini_kullanir() {
        val first = read("src/main/res/drawable/widget_rank_first_bg.xml")
        assertTrue("1. sira `glow` dolgu degil", first.contains("@color/widget_ember_glow"))

        val other = stripComments(read("src/main/res/drawable/widget_rank_other_bg.xml"))
        assertTrue("2.+ sira `night` dolgu degil", other.contains("@color/widget_ember_night"))
        assertTrue("2.+ sira `ash` halkasi yok", other.contains("@color/widget_ember_ash"))
        assertTrue(
            "iz rengi hala METIN ZEMINI olarak dolgu yapiyor",
            !Regex("<solid[^>]*widget_ember_ash").containsMatchIn(other),
        )
    }

    // =======================================================================
    // B) Genislik modeli (§3.4) — tum kademe aritmetiginin kaynagi
    //
    // SABOTAJ: `WIDGET_TEXT_SCALE_X_MIN`i 0.55'e dusur -> yalniz bu kume duser.
    // =======================================================================

    @Test
    fun sikistirma_tabani_ve_daralma_katsayisi_sabittir() {
        assertEquals(0.85f, WIDGET_TEXT_SCALE_X_MIN)
        assertEquals(0.87f, WIDGET_CONDENSED_ADVANCE)
        assertEquals(0.60f, WIDGET_GLYPH_ADVANCE)
        assertEquals(11f, WIDGET_MIN_TEXT_SP)
    }

    /**
     * §1.4 / §3.4: K1 cekirdegi neden EN FAZLA 3 karakterdir.
     *
     * 40x40dp kutu, 2dp dolgu, taban sikistirma (k = 0.85 x 0.87 = 0.74):
     *   3 karakter -> 21sp  (kahraman sayi)
     *   5 karakter -> 12sp  (11sp tabaninin hemen ustunde bir fisilti)
     * Bu yuzden `08:30` gosteren bir saat widget'inin K1'de SAYISI olamaz;
     * cekirdegi gliftir.
     */
    @Test
    fun K1_cekirdegi_en_fazla_uc_karakterdir() {
        val k = WIDGET_TEXT_SCALE_X_MIN * WIDGET_CONDENSED_ADVANCE
        assertEquals(21f, widgetMaxSp(40, 2, 3, k))
        assertEquals(12f, widgetMaxSp(40, 2, 5, k))
        assertTrue(
            "5 karakterlik bir K1 cekirdegi kahraman sayi sayilamaz",
            widgetMaxSp(40, 2, 5, k) < WIDGET_TIMER_ONE_CELL_SP,
        )
        // WP-718'de bagimsiz olarak olculup koda yazilan 20sp, modelin verdigi
        // 21sp'nin altindadir: sistem var olan olcumu YENIDEN URETIYOR.
        assertTrue(WIDGET_TIMER_ONE_CELL_SP <= widgetMaxSp(40, 2, 3, k))
    }

    /** §6 K2/K3: 110dp kutu, taban sikistirmada 8 karaktere en fazla 26sp. */
    @Test
    fun K2_kutusu_tabanda_en_fazla_26sp_tasir() {
        val k = WIDGET_TEXT_SCALE_X_MIN * WIDGET_CONDENSED_ADVANCE
        assertEquals(27f, widgetMaxSp(110, 2, WIDGET_TIMER_TIME_CHARS, k))
        assertEquals(26f, widgetMaxSp(110, 4, WIDGET_TIMER_TIME_CHARS, k))
    }

    /**
     * 🔴 ATOMIK KAPI — WP-753 borcunun kilidi.
     *
     * `odak_timer_widget.xml` bugun `textScaleX="0.55"` tasiyor; tasarim
     * sistemi tabani 0.85'tir. Tabana cikmak TEK BASINA yapilamaz: ayni turda
     * punto merdiveni de inmek zorundadir (110dp kutuda 0.74 katsayisiyla 8
     * karaktere 26sp sigar, bugunku 28sp SIGMAZ).
     *
     * Bu test bugun YESILdir (0.55'te butce 35sp, merdivenin en buyugu 28sp)
     * ve yalniz yatay sikistirma yukseltilip punto merdiveni indirilmediginde
     * kirmizi duser. Yani yarim birakilan bir gecisi yakalar.
     */
    @Test
    fun sayac_puntosu_kendi_sikistirmasinda_kutuya_sigar() {
        data class Kutu(val ad: String, val w: Int, val h: Int)
        listOf(
            Kutu("2x1", 110, 80),
            Kutu("2x2", 110, 110),
            Kutu("3x2", 180, 110),
            Kutu("4x2", 250, 110),
            Kutu("2x3", 110, 180),
            Kutu("4x3", 250, 180),
        ).forEach { kutu ->
            val size = widgetSizeClass(WidgetSizeSpecs.timer, kutu.w, kutu.h)
            val sp = timerTimeSp(size, kutu.w)
            val butce = widgetMaxSp(
                widthDp = kutu.w,
                paddingDp = timerRootPaddingDp(size),
                chars = WIDGET_TIMER_TIME_CHARS,
                advanceScale = WIDGET_TIMER_TEXT_SCALE_X,
            )
            assertTrue(
                "${kutu.ad}: $sp sp seciliyor ama kutu en fazla $butce sp tasiyor " +
                    "(k = $WIDGET_TIMER_TEXT_SCALE_X). Yatay sikistirma tabana " +
                    "cikarildiysa punto merdiveni de inmeli.",
                sp <= butce,
            )
            assertTrue("${kutu.ad}: punto 11sp tabaninin altina dustu", sp >= WIDGET_MIN_TEXT_SP)
        }
    }

    // =======================================================================
    // C) Ortak gorsel sozluk (§4) — uc tasarim ajaninin cagiracagi parcalar
    //
    // SABOTAJ: `widget_divider.xml`i sil -> yalniz bu kume duser.
    // =======================================================================

    @Test
    fun paylasilan_cizimler_var_ve_paleti_kullanir() {
        val expected = mapOf(
            "widget_card_bg" to "widget_design_surface",
            "widget_card_bg_tight" to "widget_ember_night",
            "widget_progress_arc" to null,
            "widget_progress_bar" to null,
            "widget_arc_track_shape" to "widget_design_track",
            "widget_arc_fill_shape" to "widget_design_accent",
            "widget_action_bg" to "widget_design_accent",
            "widget_chip_bg" to "widget_design_accent_soft",
            "widget_rank_first_bg" to "widget_ember_glow",
            "widget_rank_other_bg" to "widget_ember_night",
            "widget_divider" to "widget_ember_ash",
            "widget_flame_off" to "widget_ember_ash",
            "widget_flame_on" to "widget_ember_flame",
            "widget_flame_peak" to "widget_ember_glow",
        )
        expected.forEach { (name, token) ->
            val path = Path.of("src/main/res/drawable/$name.xml")
            assertTrue("drawable/$name.xml yok", Files.exists(path))
            if (token != null) {
                assertTrue(
                    "$name paleti kullanmiyor ($token bekleniyordu)",
                    read("src/main/res/drawable/$name.xml").contains("@color/$token"),
                )
            }
        }
    }

    /**
     * §0'in olcumu: dokuz duzende SIFIR `ImageView` vardi, yani butun gorsel
     * yuk `TextView`daydi. Ikon ailesi o bosluğu kapatan parcadir; sekiz
     * vektor dokuz widget'i kapsar (sayac ve minimal sayac ayni ocak ikonunu
     * paylasir, §4.3).
     */
    @Test
    fun ikon_ailesi_tam_ve_kural_uyumlu() {
        listOf(
            "widget_ic_timer", "widget_ic_stats", "widget_ic_countdown",
            "widget_ic_task", "widget_ic_group_goal", "widget_ic_leaderboard",
            "widget_ic_clock", "widget_ic_alarm",
        ).forEach { name ->
            val xml = read("src/main/res/drawable/$name.xml")
            assertTrue("$name vektor degil", xml.contains("<vector"))
            assertTrue("$name 24dp izgarada degil", xml.contains("android:viewportWidth=\"24\""))
            assertTrue("$name 24dp izgarada degil", xml.contains("android:viewportHeight=\"24\""))
            // Cizgisel: 2dp kalinlik + yuvarlak uc (yayla ayni dil).
            assertTrue("$name 2dp cizgi tasimiyor", xml.contains("android:strokeWidth=\"2\""))
            assertTrue("$name yuvarlak uc kullanmiyor", xml.contains("android:strokeLineCap=\"round\""))
            // Tek renk ve o renk PALETTEN gelir.
            assertTrue("$name paletten renk almiyor", xml.contains("@color/widget_ember_ink_dim"))
            assertTrue(
                "$name gomulu hex renk tasiyor: ikinci bir gorsel dil",
                !Regex("android:(strokeColor|fillColor)=\"#(?!00000000)").containsMatchIn(
                    stripComments(xml),
                ),
            )
        }
    }

    /**
     * §4.4: RemoteViews'in izin verdigi gorunum listesinde duz `View` YOKTUR.
     * Ayrac bu yuzden 1dp yukseklikte bir `ImageView`in ZEMINIDIR ve olcusu
     * paylasilan dilde durur.
     */
    @Test
    fun ayrac_olcusu_paylasilan_dilde() {
        val dimens = read(paletteFile)
        assertTrue(dimens.contains("<dimen name=\"widget_design_divider\">1dp</dimen>"))
    }
}
