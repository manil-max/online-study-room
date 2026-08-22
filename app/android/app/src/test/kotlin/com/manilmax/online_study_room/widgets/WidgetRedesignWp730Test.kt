package com.manilmax.online_study_room.widgets

import java.nio.file.Files
import java.nio.file.Path
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** WP-730: cihaz gorunumu icin kaynak/boyut sozlesmesi. */
class WidgetRedesignWp730Test {
    private fun read(relative: String): String =
        String(Files.readAllBytes(Path.of(relative)), Charsets.UTF_8)

    private fun attribute(xml: String, name: String): String? =
        Regex("android:$name=\"([^\"]+)\"").find(xml)?.groupValues?.get(1)

    @Test
    fun focus_sayaci_2x1_acilir_ve_1x1_gercekten_ulasilabilir() {
        val info = read("src/main/res/xml/odak_timer_widget_info.xml")
        assertEquals("2", attribute(info, "targetCellWidth"))
        assertEquals("1", attribute(info, "targetCellHeight"))
        assertEquals("110dp", attribute(info, "minWidth"))
        assertEquals("40dp", attribute(info, "minHeight"))
        assertEquals("40dp", attribute(info, "minResizeWidth"))
        assertEquals("40dp", attribute(info, "minResizeHeight"))
    }

    @Test
    fun bir_hucrede_sure_buyuk_eylem_kompakt_ama_kok_hedef_guvenli() {
        val layout = read("src/main/res/layout/odak_timer_widget.xml")
        assertTrue(layout.contains("android:minHeight=\"48dp\""))
        // 🔴 WP-752: sabit sayilar yerine KOTLIN AYNASI olculur.
        //
        // Duzendeki `textScaleX` ve `textSize`, Kotlin tarafindaki yatay
        // katsayi ve punto merdiveniyle AYNI SEYI soylemek zorundadir; onceki
        // hali ikisini birbirinden bagimsiz iki sabit olarak yaziyordu ve biri
        // degisince digeri sessizce bayatlardi.
        //
        // Tasarim sistemi tabani `WIDGET_TEXT_SCALE_X_MIN` = 0.85'tir; duzen
        // bugun hala 0.55 tasiyor ve tabana cikmak ATOMIK bir ustur (duzen +
        // punto merdiveni + K1 karakter butcesi birlikte iner - gerekce
        // `WIDGET_TIMER_TEXT_SCALE_X` KDoc'unda, aritmetigi
        // `WidgetDesignSystemWp752Test`te).
        assertTrue(layout.contains("android:textScaleX=\"$WIDGET_TIMER_TEXT_SCALE_X\""))
        assertTrue(
            layout.contains(
                "android:textSize=\"${WidgetTypography.timerTime.narrow.toInt()}sp\"",
            ),
        )
        assertTrue(layout.contains("timer_widget_compact_action"))
        assertTrue(layout.contains("android:layout_height=\"22dp\""))
        assertTrue(WIDGET_TIMER_ONE_CELL_SP >= 20f)
    }

    @Test
    fun grup_hedefi_yarim_yaydir_ve_yuzde_duzende_tektir() {
        val layout = read("src/main/res/layout/odak_group_goal_widget.xml")
        assertTrue(layout.contains("@drawable/widget_progress_arc"))
        assertTrue(layout.contains("group_goal_widget_gauge"))
        assertEquals(
            1,
            Regex("android:id=\"@\\+id/group_goal_widget_percent\"")
                .findAll(layout)
                .count(),
        )
        // WP-752: her saglayici kendi dosyasinda.
        val groupGoal = read(
            "src/main/kotlin/com/manilmax/online_study_room/widgets/GroupGoalWidget.kt",
        )
        assertTrue(groupGoal.contains("WidgetDesign.arcPercent("))
        assertFalse(groupGoal.contains("R.id.group_goal_widget_percent_copy"))
    }

    @Test
    fun uzun_metinler_guvenli_ve_bos_kartlar_icerik_yuksekliginde() {
        val layouts = listOf(
            "odak_countdown_widget.xml",
            "odak_task_widget.xml",
            "odak_leaderboard_widget.xml",
        ).associateWith { read("src/main/res/layout/$it") }
        layouts.values.forEach { xml ->
            assertTrue(xml.contains("@drawable/widget_card_bg"))
            assertTrue(xml.contains("android:ellipsize=\"end\""))
            assertTrue(xml.contains("android:maxLines="))
        }
        assertTrue(
            layouts.getValue("odak_task_widget.xml")
                .contains("android:id=\"@+id/task_widget_frame\""),
        )
        assertTrue(
            layouts.getValue("odak_task_widget.xml")
                .contains("android:layout_height=\"wrap_content\""),
        )
        assertTrue(
            layouts.getValue("odak_leaderboard_widget.xml")
                .contains("android:id=\"@+id/leaderboard_widget_card\""),
        )
    }

    /**
     * 🔴 WP-752 - SOZLESME DEGISTI: palet TEKtir ve koyudur.
     *
     * Eski iddia `values` ile `values-night` ad kumelerini karsilastiriyordu.
     * O iddia artik KONUSUZ: `values-night/widget_design.xml` KALDIRILDI ve
     * widget her sistem temasinda koyu cizilir (gerekce: uygulamanin kendi
     * varsayilan temasi `campfire_night`; ayrica iki palet her kontrast
     * iddiasini iki kez kanitlamayi gerektiriyordu).
     *
     * Yerine gecen iddia AYNI SINIF regresyonu (bir simgenin bir temada eksik
     * kalmasi) daha ucuza yakalar: ikinci bir palet dosyasi ACILAMAZ.
     */
    @Test
    fun palet_TEKtir_ve_ikinci_bir_tema_dosyasi_yoktur() {
        fun names(path: String): Set<String> =
            Regex("<color name=\"([^\"]+)\"")
                .findAll(read(path))
                .map { it.groupValues[1] }
                .toSet()
        val palette = names("src/main/res/values/widget_design.xml")
        listOf("widget_ember_night", "widget_ember_ash", "widget_ember_flame",
            "widget_ember_glow", "widget_ember_ink", "widget_ember_ink_dim")
            .forEach { assertTrue("$it paletten dusmus", palette.contains(it)) }
        // WP-717 adlari korunur; dokuz duzen ve mevcut cizimler onlari kullanir.
        assertTrue(palette.contains("widget_design_outline"))
        assertTrue(palette.contains("widget_design_accent_soft"))

        listOf(
            "src/main/res/values-night/widget_design.xml",
            "src/main/res/values-v31/widget_design.xml",
            "src/main/res/values-night/widget_colors.xml",
            "src/main/res/values-v31/widget_colors.xml",
            "src/main/res/values/widget_colors.xml",
        ).forEach {
            assertFalse(
                "$it geri geldi: tek koyu kimlik sozlesmesi kirildi",
                Files.exists(Path.of(it)),
            )
        }
    }

    /**
     * WP-752 (§2.6): kart yaricapi KADEMEYE bagli. K1'de kart 40x40dp'dir;
     * eski tek deger (22dp) koselerin tamamini yiyordu.
     */
    @Test
    fun kart_yaricapi_kademeye_gore_iki_degerdir() {
        val dimens = read("src/main/res/values/widget_design.xml")
        assertTrue(dimens.contains("<dimen name=\"widget_design_corner\">20dp</dimen>"))
        assertTrue(
            dimens.contains("<dimen name=\"widget_design_corner_tight\">12dp</dimen>"),
        )
        assertTrue(Files.exists(Path.of("src/main/res/drawable/widget_card_bg_tight.xml")))
        assertTrue(
            read("src/main/res/drawable/widget_card_bg_tight.xml")
                .contains("@dimen/widget_design_corner_tight"),
        )
    }
}
