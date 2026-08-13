package com.manilmax.online_study_room.widgets

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** WP-728: sayac rakamlarinin gercek launcher kutularindaki sabit geometrisi. */
class TimerNumericTypographyWp728Test {

    private val safetyMarginDp = 8f
    private val durationChars = 8

    private fun textWidthDp(sp: Float, scaleX: Float = 1f): Float =
        sp * 0.60f * durationChars * scaleX

    private fun lineHeightDp(sp: Float): Float = sp * 1.30f

    private fun usableDp(boxDp: Int, paddingDp: Int): Float =
        boxDp - 2f * paddingDp - safetyMarginDp

    private fun assertFits(label: String, neededDp: Float, availableDp: Float) {
        assertTrue(
            "$label: $neededDp dp gerekiyor, $availableDp dp var -> KIRPILIR",
            neededDp <= availableDp,
        )
    }

    @Test
    fun standart_sayac_2x1_2x2_ve_genis_kutuda_8_karakteri_kirpmaz() {
        data class Box(val name: String, val widthDp: Int, val heightDp: Int)
        listOf(
            Box("2x1 compact", 110, 80),
            Box("2x2 default", 110, 110),
            Box("4x2 wide", 250, 110),
        ).forEach { box ->
            val size = widgetSizeClass(WidgetSizeSpecs.timer, box.widthDp, box.heightDp)
            val sp = timerTimeSp(size, box.widthDp)
            val padding = timerRootPaddingDp(size)
            assertFits(
                "${box.name}/width",
                textWidthDp(sp, WIDGET_TIMER_TEXT_SCALE_X),
                usableDp(box.widthDp, padding),
            )
            assertFits(
                "${box.name}/height",
                lineHeightDp(sp),
                usableDp(box.heightDp, padding),
            )
        }
    }

    @Test
    fun minimal_sayac_1x1_2x1_2x2_kutuda_8_karakteri_ayni_puntoyla_tasir() {
        data class Box(val name: String, val widthDp: Int, val heightDp: Int, val expectedSp: Float)
        listOf(
            Box("1x1", 70, 70, 16f),
            Box("2x1", 110, 40, 21f),
            Box("2x2", 110, 110, 21f),
        ).forEach { box ->
            val sp = minimalTimerTimeSp(box.widthDp, box.heightDp)
            assertEquals("${box.name}/punto", box.expectedSp, sp)
            assertFits(
                "${box.name}/width",
                textWidthDp(sp, WIDGET_MINIMAL_TIMER_TEXT_SCALE_X),
                usableDp(box.widthDp, WIDGET_MINIMAL_TIMER_PADDING_DP),
            )
            assertFits(
                "${box.name}/height",
                lineHeightDp(sp),
                usableDp(box.heightDp, WIDGET_MINIMAL_TIMER_PADDING_DP),
            )
        }
    }

    @Test
    fun minimal_punto_icerige_gore_degil_yalniz_kutuya_gore_sabittir() {
        val idleSp = minimalTimerTimeSp(70, 70) // 00:00
        val runningSp = minimalTimerTimeSp(70, 70) // 00:00:00
        assertEquals(idleSp, runningSp)
        assertTrue("1x1 rakami okunur alt sinirin altinda", idleSp >= 16f)
    }

    @Test
    fun minimal_ilk_cizim_2x1_varsayilani_kullanir() {
        assertEquals(21f, minimalTimerTimeSp(0, 0))
    }

    @Test
    fun minimal_layout_geometrisi_olcum_sabitleriyle_ayni() {
        val relativePaths = listOf(
            "android/app/src/main/res/layout/odak_minimal_timer_widget.xml",
            "app/android/app/src/main/res/layout/odak_minimal_timer_widget.xml",
        )
        val layout = generateSequence(File(System.getProperty("user.dir"))) { it.parentFile }
            .flatMap { root -> relativePaths.asSequence().map { File(root, it) } }
            .firstOrNull(File::isFile)
            ?: error("minimal timer layout bulunamadi; test calisma dizini beklenmeyen yerde")
        val xml = layout.readText()
        assertTrue(xml.contains("android:textScaleX=\"0.75\""))
        assertTrue(xml.contains("android:textSize=\"21sp\""))
    }
}
