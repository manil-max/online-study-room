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
        assertTrue(layout.contains("android:textScaleX=\"0.55\""))
        assertTrue(layout.contains("android:textSize=\"28sp\""))
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
        val provider = read(
            "src/main/kotlin/com/manilmax/online_study_room/widgets/StudyWidgetProviders.kt",
        )
        val groupGoal = provider.substring(
            provider.indexOf("class GroupGoalWidgetProvider"),
            provider.indexOf("class ClockWidgetProvider"),
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

    @Test
    fun acik_ve_koyu_paleti_ayni_yedi_simgeyi_tasir() {
        fun names(path: String): Set<String> =
            Regex("<color name=\"([^\"]+)\"")
                .findAll(read(path))
                .map { it.groupValues[1] }
                .toSet()
        val light = names("src/main/res/values/widget_design.xml")
        val dark = names("src/main/res/values-night/widget_design.xml")
        assertEquals(light, dark)
        assertTrue(light.contains("widget_design_outline"))
        assertTrue(light.contains("widget_design_accent_soft"))
    }
}
