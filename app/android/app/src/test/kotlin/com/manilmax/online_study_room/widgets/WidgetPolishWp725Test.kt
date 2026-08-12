package com.manilmax.online_study_room.widgets

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class WidgetPolishWp725Test {
    @Test
    fun kayitli_uygulama_dili_cihaz_dilinden_once_gelir() {
        assertEquals("tr", widgetLanguageCode("turkish", "en"))
        assertEquals("en", widgetLanguageCode("english", "tr"))
        assertEquals("tr", widgetLanguageCode("system", "tr"))
        assertEquals("en", widgetLanguageCode("system", "de"))
        assertEquals("en", widgetLanguageCode("german", "tr"))
        assertEquals("en", widgetLanguageCode("arabic", "tr"))
    }

    @Test
    fun bozuk_veya_eksik_tercih_sistem_diline_guvenle_duser() {
        assertEquals("tr", widgetLanguageCode(null, "TR"))
        assertEquals("en", widgetLanguageCode(null, null))
        assertEquals("en", widgetLanguageCode("bilinmeyen", "fr"))
    }

    @Test
    fun siralama_placeholder_satirlari_gercek_kisi_gibi_cizilmez() {
        assertFalse(leaderboardRowHasContent(""))
        assertFalse(leaderboardRowHasContent("  -  "))
        assertFalse(leaderboardRowHasContent("\u2014"))
        assertTrue(leaderboardRowHasContent("Ayse  9 sa 34 dk"))
    }

    @Test
    fun ilk_uc_icindeki_kisisel_sira_vurgulanabilir() {
        assertEquals(1, leaderboardHighlightedPosition("#1"))
        assertEquals(2, leaderboardHighlightedPosition("#2 \u00B7 9 sa"))
        assertEquals(3, leaderboardHighlightedPosition("#3  4 h"))
        assertNull(leaderboardHighlightedPosition("#4"))
        assertNull(leaderboardHighlightedPosition("Siralama yok"))
    }

    @Test
    fun renkli_ilerleme_yuzdesi_kirpilir_ve_yuvarlanir() {
        assertEquals(0, WidgetDesign.barPercent(Double.NaN))
        assertEquals(0, WidgetDesign.barPercent(-0.3))
        assertEquals(25, WidgetDesign.barPercent(0.25))
        assertEquals(100, WidgetDesign.barPercent(1.7))
    }
}
