package com.manilmax.online_study_room.timer

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * WP-793 (sahip, cihazda, v80): *"bildirim panelindeki bildirimde kronometre
 * MM:SS kucuk kalmis, buyutmek lazim."*
 *
 * Daraltilmis satirda sayacin tavani dugmenin 44dp yuksekligidir; buyuk saat
 * ancak genisletilmis gorunumun KENDI duzeniyle mumkun. Bu dosya o duzeni ve
 * servisin onu gercekten kullandigini olcer.
 *
 * Kaynak metni olcer, cizimi degil: `RemoteViews` JVM'de sisirilemez. Cizim
 * kaniti cihazdir (sahip v81'de bakacak).
 *
 * SABOTAJ (her biri tek iddiayi dusurur):
 *   A) `setCustomBigContentView(big)` -> `(custom)`      : servis iddiasi
 *   B) buyuk duzende `textSize="56sp"` -> `"26sp"`       : boyut iddiasi
 *   C) buyuk duzende sayaca `android:textColor="#FFF"`   : renk kurali 1
 *   D) buyuk duzenden `notif_timer_action` kimligini sil : ortak kimlik
 */
class TimerNotificationBigPanelWp793Test {
    private val layoutFile = "src/main/res/layout/timer_notification.xml"
    private val bigLayoutFile = "src/main/res/layout/timer_notification_big.xml"
    private val serviceFile =
        "src/main/kotlin/com/manilmax/online_study_room/timer/StudyTimerService.kt"

    private fun read(path: String): String = File(path).readText()

    private fun stripXmlComments(xml: String): String =
        Regex("<!--[\\s\\S]*?-->").replace(xml, "")

    private fun stripKotlinComments(source: String): String =
        Regex("//[^\\n]*")
            .replace(Regex("/\\*[\\s\\S]*?\\*/").replace(source, ""), "")

    private fun elements(file: String): Map<String, Map<String, String>> =
        Regex("<([A-Za-z]\\w*)\\b([^>]*)>")
            .findAll(stripXmlComments(read(file)))
            .mapNotNull { match ->
                val attrs = Regex("(android:\\w+)=\"([^\"]*)\"")
                    .findAll(match.groupValues[2])
                    .associate { it.groupValues[1] to it.groupValues[2] }
                val id = attrs["android:id"] ?: return@mapNotNull null
                id.removePrefix("@+id/").removePrefix("@id/") to attrs
            }
            .toMap()

    private fun sp(value: String?): Int =
        value?.removeSuffix("sp")?.toIntOrNull() ?: error("sp bekleniyordu: $value")

    // -----------------------------------------------------------------------
    // 1) Genisletilmis gorunum daraltilmisin kopyasi DEGIL.
    // -----------------------------------------------------------------------

    @Test
    fun servis_genisletilmis_gorunume_KENDI_duzenini_verir() {
        val code = stripKotlinComments(read(serviceFile))
        assertTrue(
            "daraltilmis gorunum `custom` ile kurulmali",
            code.contains(".setCustomContentView(custom)"),
        )
        assertTrue(
            "genisletilmis gorunum `big` ile kurulmali; `custom` kopyasi buyuk saati yok eder",
            code.contains(".setCustomBigContentView(big)"),
        )
        assertFalse(
            "eski kopya geri gelmis",
            code.contains(".setCustomBigContentView(custom)"),
        )
        assertTrue(
            "`big`, buyuk duzenle kurulmali",
            code.contains("layout = R.layout.timer_notification_big"),
        )
        // Tek baglama kodu: iki duzen ayni fonksiyondan gecer.
        assertTrue(code.contains("val views = RemoteViews(packageName, layout)"))
    }

    // -----------------------------------------------------------------------
    // 2) Sayac gercekten BUYUK ve daraltilmis olan da buyudu.
    // -----------------------------------------------------------------------

    @Test
    fun buyuk_duzende_sayac_56sp_daraltilmista_32sp() {
        val big = elements(bigLayoutFile)["notif_timer_elapsed"]
            ?: error("buyuk duzende `notif_timer_elapsed` yok")
        val small = elements(layoutFile)["notif_timer_elapsed"]
            ?: error("daraltilmis duzende `notif_timer_elapsed` yok")

        // Secilen sayilar; degistirmek bir karar, kayma degil.
        assertEquals(56, sp(big["android:textSize"]))
        assertEquals(32, sp(small["android:textSize"]))
        assertTrue(
            "genisletilmis sayac daraltilmistan BUYUK olmali; aksi halde ikinci duzenin anlami yok",
            sp(big["android:textSize"]) > sp(small["android:textSize"]),
        )
        // 32sp, 44dp dugmenin icinde kalir; daraltilmis satir buyumez.
        // Daha buyugu satiri uzatir ve daraltilmis butceyi asma riski tasir.
        assertTrue(sp(small["android:textSize"]) <= 34)
    }

    /**
     * Buyuk saat TEK BASINA satirda durur. Yatayda 56sp "1:23:45" (~220dp)
     * ile 84dp hap 320dp ekranda SIGMAZ ve `RemoteViews` icinde
     * `autoSizeTextType` yok: rakamlar sagdan kirpilirdi.
     */
    @Test
    fun buyuk_saat_tam_genislikte_tek_basina_durur() {
        val big = elements(bigLayoutFile)["notif_timer_elapsed"]!!
        assertEquals("match_parent", big["android:layout_width"])
        assertEquals("1", big["android:maxLines"])
        val body = stripXmlComments(read(bigLayoutFile))
        assertTrue(
            "kok duzen dikey olmali; saat ve hap ayri satirlarda",
            Regex("<LinearLayout[^>]*android:orientation=\"vertical\"").containsMatchIn(body),
        )
    }

    // -----------------------------------------------------------------------
    // 3) Kimlikler ORTAK: tek baglama kodu iki duzeni de doldurur.
    // -----------------------------------------------------------------------

    @Test
    fun iki_duzen_ayni_kimlikleri_tasir() {
        val ids = setOf("notif_timer_elapsed", "notif_timer_label", "notif_timer_action")
        assertEquals(ids, elements(layoutFile).keys)
        assertEquals(
            "buyuk duzende kimlik eksik/fazla: baglama kodu onu doldurmaz ya da coker",
            ids,
            elements(bigLayoutFile).keys,
        )
        // Hap dokunma hedefi korunur.
        val action = elements(bigLayoutFile)["notif_timer_action"]!!
        assertEquals("44dp", action["android:minHeight"])
        assertEquals("84dp", action["android:minWidth"])
    }

    // -----------------------------------------------------------------------
    // 4) RENK KURALI IKI YONLU — WP-759 ile birebir, yeni duzende de.
    // -----------------------------------------------------------------------

    @Test
    fun buyuk_duzende_golge_metni_sabit_renk_yazmaz_hap_metni_yazar() {
        val els = elements(bigLayoutFile)
        for (id in listOf("notif_timer_elapsed", "notif_timer_label")) {
            val attrs = els[id]!!
            assertNull("`$id` golge zemininde; sabit renk WP-205'i tekrarlar", attrs["android:textColor"])
            val appearance = attrs["android:textAppearance"]
            assertTrue(
                "`$id` bildirim TextAppearance'i kullanmali, buldum: $appearance",
                appearance != null &&
                    appearance.startsWith("@style/TextAppearance.Compat.Notification"),
            )
        }
        assertEquals(
            "@color/timer_notification_action_ink",
            els["notif_timer_action"]!!["android:textColor"],
        )
        val body = stripXmlComments(read(bigLayoutFile))
        assertFalse(body.contains("?android:attr/") || body.contains("?attr/"))
        assertFalse(body.contains("@android:color/system_"))
        assertFalse(Regex("android:(textColor|color)=\"#").containsMatchIn(body))
    }

    @Test
    fun buyuk_duzen_metinleri_kaynaktan_alir() {
        val body = stripXmlComments(read(bigLayoutFile))
        assertTrue(body.contains("android:text=\"@string/action_stop\""))
        assertFalse(body.contains("android:text=\"Durdur\""))
    }
}
