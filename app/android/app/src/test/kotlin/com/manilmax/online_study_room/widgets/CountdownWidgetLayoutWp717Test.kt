package com.manilmax.online_study_room.widgets

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * WP-717: geri sayim widget'inin **tasidigi bilgi** ve **yayin degeri**.
 *
 * Sahip cihazda "widgetlar cok cirkin, boyutlari kocaman ve yazi sadece" dedi;
 * beta testcisi "sadece 1 sinavin geri sayimi gorunuyor, uygulamadaki gibi
 * 3'u de gorunse" dedi. Ikisi de bir izlenim; burada sayiya cevriliyor:
 * hangi boyut sinifinda KAC KAYIT ciziliyor ve yayin dolulugu ne.
 *
 * Gorsel iddianin JVM'de olculebilen kismi budur. `RemoteViews`, `Canvas` ve
 * `Bitmap` bu projede test edilemez (`android.jar` saplamalari "not mocked"
 * atar; Robolectric bagimliligi yok). Bu yuzden gorsel dilin kirilgan parcasi
 * — yuzde aritmetigi ve satir gorunurlugu — saf fonksiyonlara alindi ve
 * kaynak/duzen tarafi Dart sozlesme testinde olculuyor
 * (`test/features/android_widgets/countdown_widget_wp717_test.dart`).
 */
class CountdownWidgetLayoutWp717Test {

    private companion object {
        /** 2026-08-11 12:00 UTC → Istanbul 15:00. */
        const val NOW = 1_786_449_600_000L

        /** Sahibin cihazindaki uc kayit: 76 / 312 / 313 gun kalan sinavlar. */
        val THREE_EXAMS = """{"entries":[""" +
            """{"id":"a","name":"AYT","day":"2026-10-26"},""" +
            """{"id":"b","name":"TYT","day":"2027-06-19"},""" +
            """{"id":"c","name":"LGS","day":"2027-06-20"}""" +
            """],"priority":null,"synced":[],"deleted":[]}"""
    }

    // -----------------------------------------------------------------------
    // 1) Uc sinav birden
    // -----------------------------------------------------------------------

    @Test
    fun `three exams are parsed as three rows in the app order`() {
        val list = countdownWidgetList(THREE_EXAMS, NOW)

        assertEquals(3, list.rows.size)
        assertEquals(listOf("AYT", "TYT", "LGS"), list.rows.map { it.name })
        assertEquals(listOf(76L, 312L, 313L), list.rows.map { it.days })
        assertEquals(listOf("76", "312", "313"), list.rows.map { it.daysText })
        assertFalse(list.hasPriority)
    }

    /**
     * 🔴 Asil iddia: kullanicinin GORDUGU kayit sayisi. Eskiden her boyutta
     * 1'di; buyutmek yalniz boslugu buyutuyordu.
     */
    @Test
    fun `every size class draws more than one exam when three exist`() {
        val rows = countdownWidgetList(THREE_EXAMS, NOW).rows

        // One cikarilan yok -> uygulamadaki kart gibi hepsi esit satir.
        val visible = WidgetHeightClass.values().associateWith {
            countdownVisibleRowCount(it, rows.size, hasPriority = false)
        }

        assertEquals(2, visible[WidgetHeightClass.SHORT])
        assertEquals(3, visible[WidgetHeightClass.MEDIUM])
        assertEquals(3, visible[WidgetHeightClass.TALL])
        // Hicbir boyutta eski "tek kayit" davranisi kalmadi.
        assertTrue(visible.values.all { it >= 2 })
    }

    @Test
    fun `default 2x2 box shows all three exams`() {
        // Varsayilan boyut `odak_countdown_widget_info.xml`: 110x110dp.
        // Hucre formulu 70n-30 -> 2 hucre = 110dp (1 hucre 40dp DEGIL).
        val size = widgetSizeClass(WidgetSizeSpecs.countdown, 110, 110)
        assertEquals(WidgetHeightClass.MEDIUM, size.height)

        val rows = countdownWidgetList(THREE_EXAMS, NOW).rows
        assertEquals(3, countdownVisibleRowCount(size.height, rows.size, false))
    }

    /**
     * One cikarilan kayit varsa uygulamadaki kartla ayni: o kayit BUYUK,
     * digerleri altinda satir. Kural `dday_card.dart` `useHero` ile birebir,
     * tek fark tek kayitta kahramanin her zaman kullanilmasi.
     */
    @Test
    fun `hero rule mirrors the in-app card`() {
        val prioritized = THREE_EXAMS.replace(""""priority":null""", """"priority":"b"""")
        val list = countdownWidgetList(prioritized, NOW)

        assertTrue(list.hasPriority)
        // One cikarilan basa alinir; digerleri kendi sirasinda kalir.
        assertEquals(listOf("TYT", "AYT", "LGS"), list.rows.map { it.name })

        // Kisa kutu + 3 kayit -> kahraman sigmaz, hepsi esit satir olur.
        assertFalse(countdownUsesHero(WidgetHeightClass.SHORT, 3, true))
        assertEquals(2, countdownVisibleRowCount(WidgetHeightClass.SHORT, 3, true))
        // Uzun kutuda kahraman + iki yardimci satir = uc kaydin hepsi.
        assertTrue(countdownUsesHero(WidgetHeightClass.TALL, 3, true))
        assertEquals(2, countdownVisibleRowCount(WidgetHeightClass.TALL, 3, true))
        // Kisa kutu + 2 kayit -> kahraman hala sigar (kartla ayni esik).
        assertTrue(countdownUsesHero(WidgetHeightClass.SHORT, 2, true))

        // Tek kayitta kahraman her zaman kullanilir ve yardimci satir yoktur.
        for (height in WidgetHeightClass.values()) {
            assertTrue(countdownUsesHero(height, 1, false))
            assertEquals(0, countdownVisibleRowCount(height, 1, false))
        }
        // Kayit yoksa kahraman "yok" der; satir da cizilmez.
        assertFalse(countdownUsesHero(WidgetHeightClass.TALL, 0, false))
        assertEquals(0, countdownVisibleRowCount(WidgetHeightClass.TALL, 0, false))
    }

    @Test
    fun `visible row count never exceeds the static slots in the layout`() {
        for (height in WidgetHeightClass.values()) {
            for (count in 0..12) {
                for (priority in listOf(false, true)) {
                    val visible = countdownVisibleRowCount(height, count, priority)
                    assertTrue("h=$height n=$count", visible in 0..COUNTDOWN_ROW_SLOTS)
                    // Var olmayan kayda satir ayrilmaz.
                    assertTrue("h=$height n=$count", visible <= count)
                }
            }
        }
    }

    @Test
    fun `row text uses the same words as the in-app card`() {
        val rows = countdownWidgetList(THREE_EXAMS, NOW).rows

        assertEquals(
            "312 gun kaldi",
            countdownRowValueText(rows[1], "gun kaldi", "bugun", "gecti"),
        )
        // Sinav gunu ve gecmis kayit SAYI yazmaz - "-1 gun kaldi" bir hatadir.
        val today = countdownWidgetList(
            """{"entries":[{"id":"a","name":"X","day":"2026-08-11"}],"priority":null}""",
            NOW,
        ).rows.single()
        assertEquals("bugun", countdownRowValueText(today, "gun kaldi", "bugun", "gecti"))
        val past = countdownWidgetList(
            """{"entries":[{"id":"a","name":"X","day":"2020-01-01"}],"priority":null}""",
            NOW,
        ).rows.single()
        assertEquals("gecti", countdownRowValueText(past, "gun kaldi", "bugun", "gecti"))
        assertFalse(
            countdownRowValueText(past, "gun kaldi", "bugun", "gecti").startsWith("-"),
        )
    }

    // -----------------------------------------------------------------------
    // 2) "Ters U" yay - gorsel iddianin olculebilir kismi
    // -----------------------------------------------------------------------

    /**
     * 🔴 `ProgressBar` seviyeyi YATAY bir `<clip>`e verir; yarim daire uzerinde
     * yatay konum ile aci arasindaki bagintiysa `x = R·cos θ`dir. Duzeltme
     * olmadan gosterge uclarda kimildamaz, tepede firlar.
     * [WidgetDesign.arcPercent] bunu tersine cevirir: gorunen YAY UZUNLUGU
     * ilerlemeyle dogru orantilidir.
     */
    @Test
    fun `arc percent maps arc length linearly not horizontal position`() {
        assertEquals(0, WidgetDesign.arcPercent(0.0))
        assertEquals(50, WidgetDesign.arcPercent(0.5))
        assertEquals(100, WidgetDesign.arcPercent(1.0))
        // Ceyrek yay: duzeltilmemis olsaydi 25 olurdu.
        assertEquals(15, WidgetDesign.arcPercent(0.25))
        assertEquals(85, WidgetDesign.arcPercent(0.75))
        assertTrue(WidgetDesign.arcPercent(0.25) < 25)

        // Monotondur ve sinirlar disina tasmaz.
        var previous = -1
        for (step in 0..100) {
            val percent = WidgetDesign.arcPercent(step / 100.0)
            assertTrue("step=$step", percent in 0..WidgetDesign.PROGRESS_MAX)
            assertTrue("step=$step", percent >= previous)
            previous = percent
        }
        // Kirpma: bozuk girdi yayi patlatmaz.
        assertEquals(0, WidgetDesign.arcPercent(-3.0))
        assertEquals(100, WidgetDesign.arcPercent(9.0))
        assertEquals(0, WidgetDesign.arcPercent(Double.NaN))
    }

    /** Duz cubukta acisal duzeltme YOKTUR; iki cizim karistirilmamali. */
    @Test
    fun `bar percent stays linear`() {
        assertEquals(25, WidgetDesign.barPercent(0.25))
        assertEquals(50, WidgetDesign.barPercent(0.5))
        assertEquals(0, WidgetDesign.barPercent(-1.0))
        assertEquals(100, WidgetDesign.barPercent(2.0))
        assertEquals(0, WidgetDesign.barPercent(Double.NaN))
    }

    @Test
    fun `arc fills as the exam approaches`() {
        val list = countdownWidgetList(THREE_EXAMS, NOW)
        val fractions = list.rows.map {
            countdownArcFraction(CountdownWidgetModel(it.state, it.name, it.days, it.daysText))
        }
        // 76 gun kalan sinav, 312 gun kalandan DAHA DOLU bir yay cizer.
        assertTrue(fractions[0] > fractions[1])
        assertTrue(fractions[1] > fractions[2])
        // Ufuk bir yil: 76 gun kalan ~%79.
        assertEquals(0.79, fractions[0], 0.01)

        // Sinav gunu tam dolu.
        val today = countdownWidgetList(
            """{"entries":[{"id":"a","name":"X","day":"2026-08-11"}],"priority":null}""",
            NOW,
        ).head
        assertEquals(1.0, countdownArcFraction(today), 0.0)
        assertEquals(100, WidgetDesign.arcPercent(countdownArcFraction(today)))

        // Bir yildan uzak sinav bos yay; negatife dusmez.
        val far = countdownWidgetList(
            """{"entries":[{"id":"a","name":"X","day":"2035-01-01"}],"priority":null}""",
            NOW,
        ).head
        assertEquals(0.0, countdownArcFraction(far), 0.0)
        assertEquals(0, WidgetDesign.arcPercent(countdownArcFraction(far)))
    }

    /**
     * Yay bos/gecmis durumda GIZLENIR. Bos bir iz cizmek "veri var ama sifir"
     * gibi okunurdu; ayrica kisa kutuda yaya yer yok.
     */
    @Test
    fun `arc is hidden when it would say nothing`() {
        val future = countdownWidgetList(THREE_EXAMS, NOW).head
        assertTrue(countdownArcVisible(WidgetHeightClass.MEDIUM, future.state))
        assertTrue(countdownArcVisible(WidgetHeightClass.TALL, future.state))
        assertFalse(countdownArcVisible(WidgetHeightClass.SHORT, future.state))

        for (height in WidgetHeightClass.values()) {
            assertFalse(countdownArcVisible(height, CountdownState.EMPTY))
            assertFalse(countdownArcVisible(height, CountdownState.PAST))
        }
        assertEquals(
            0.0,
            countdownArcFraction(CountdownWidgetModel(CountdownState.EMPTY, "", 0L, COUNTDOWN_DASH)),
            0.0,
        )
    }

    // -----------------------------------------------------------------------
    // 3) WP-695 sozlesmesi bozulmadi
    // -----------------------------------------------------------------------

    @Test
    fun `head still equals the single-record model WP-695 measured`() {
        val prioritized = THREE_EXAMS.replace(""""priority":null""", """"priority":"c"""")
        val head = countdownWidgetModel(prioritized, NOW)

        assertEquals(CountdownState.FUTURE, head.state)
        assertEquals("LGS", head.name)
        assertEquals("313", head.daysText)
        assertEquals(countdownWidgetList(prioritized, NOW).head, head)

        // Bozuk kayit hala bos duruma duser, listeye cop girmez.
        assertTrue(countdownWidgetList("bozuk", NOW).rows.isEmpty())
        assertEquals(CountdownState.EMPTY, countdownWidgetList("bozuk", NOW).head.state)
    }
}
