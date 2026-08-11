package com.manilmax.online_study_room.widgets

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * WP-719: gorev widget'i icerigine gore kuculur.
 *
 * Sahip: "bunlar kuculmuyor, boyutlari kocaman ve yazi sadece". Cihazda
 * olculen: "Gorevler / Henuz gorev yok" yazan kart, altinda kocaman bos alanla
 * duruyordu.
 *
 * Iki ayri kusur vardi ve ikisi de burada sayiya baglanir:
 *
 *  1. **Cizilen kart kutuyu dolduruyordu** (`layout_height="match_parent"`).
 *     Duzeltme layout'ta; olcumu [cardHeightDp] modeli uzerinden yapiyoruz.
 *  2. **Satir sayisi kutuya degil kaba bir sinifa** bagliydi ve WP-701'in
 *     aritmetik modeli satir yuksekligini punto x 1.30 (~17dp) sayiyordu.
 *     Layout'ta satir `minHeight="32dp"`; yani 110dp'lik kutuda "3 satir +
 *     baslik" 140dp isterdi ve kart kirpilirdi.
 */
class TaskWidgetSizeWp719Test {

    /** Cizilen kartin yuksekligi: dolgu + baslik + satirlar. */
    private fun cardHeightDp(rows: Int, titleVisible: Boolean, paddingDp: Int): Int =
        2 * paddingDp +
            (if (titleVisible) TASK_TITLE_HEIGHT_DP else 0) +
            rows * TASK_ROW_HEIGHT_DP

    @Test
    fun kart_icerik_arttikca_uzar_bos_durumda_kisadir() {
        val bos = cardHeightDp(0, titleVisible = true, paddingDp = 12)
        val bir = cardHeightDp(1, titleVisible = true, paddingDp = 12)
        val uc = cardHeightDp(3, titleVisible = true, paddingDp = 12)
        val bes = cardHeightDp(5, titleVisible = true, paddingDp = 12)

        assertTrue("bos: $bos, 1 gorev: $bir", bos < bir)
        assertTrue("1 gorev: $bir, 3 gorev: $uc", bir < uc)
        assertTrue("3 gorev: $uc, 5 gorev: $bes", uc < bes)
        // Bos durumda kart en buyuk kutunun (210dp) dortte birinden kisa olmali;
        // "kocaman bos dikdortgen" sikayetinin sayisal karsiligi budur.
        assertTrue("bos kart $bos dp", bos <= 210 / 4)
    }

    @Test
    fun cizilen_kart_her_kutuda_SIGAR() {
        // res/xml/odak_task_widget_info.xml: 56dp (alt sinir) ... 210dp (ust sinir).
        for (box in listOf(56, 80, 110, 180, 210)) {
            for (titleVisible in listOf(false, true)) {
                for (padding in 12..14) {
                    val rows = taskWidgetRowCapacity(box, titleVisible, padding)
                    val drawn = cardHeightDp(rows, titleVisible, padding)
                    assertTrue(
                        "kutu $box dp / baslik $titleVisible / dolgu $padding: " +
                            "$rows satir -> $drawn dp TASIYOR",
                        drawn <= box,
                    )
                }
            }
        }
    }

    @Test
    fun alt_sinirda_en_az_bir_satir_cizilir() {
        // 56dp = 12 + 32 + 12. Kucultme sinirinin karsiligi TEK satirlik karttir;
        // sifir satir cizen bir alt sinir kullaniciya bos kutu vaat ederdi.
        assertEquals(1, taskWidgetRowCapacity(56, titleVisible = false, paddingDp = 12))
    }

    @Test
    fun ust_sinirda_bes_satirin_hepsi_cizilir() {
        assertEquals(
            TASK_WIDGET_MAX_ROWS,
            taskWidgetRowCapacity(210, titleVisible = true, paddingDp = 14),
        )
    }

    @Test
    fun varsayilan_kutuda_baslik_ve_iki_satir_sigar() {
        // Varsayilan 3x2 hucre = 180x110dp; MEDIUM sinifi -> dolgu 13.
        val rows = taskWidgetRowCapacity(
            WIDGET_TASK_DEFAULT_HEIGHT_DP,
            titleVisible = true,
            paddingDp = widgetRootPaddingDp(12, WidgetHeightClass.MEDIUM),
        )
        assertEquals(2, rows)
        assertTrue(
            cardHeightDp(rows, titleVisible = true, paddingDp = 13) <=
                WIDGET_TASK_DEFAULT_HEIGHT_DP,
        )
    }

    @Test
    fun kapasite_hicbir_zaman_negatif_veya_layout_disinda_degil() {
        // Bozuk/aptalca girdi kart cizimini dusurmemeli.
        assertEquals(0, taskWidgetRowCapacity(0, titleVisible = true, paddingDp = 12))
        assertEquals(0, taskWidgetRowCapacity(-40, titleVisible = false, paddingDp = 12))
        assertEquals(
            TASK_WIDGET_MAX_ROWS,
            taskWidgetRowCapacity(10_000, titleVisible = true, paddingDp = 12),
        )
    }
}
