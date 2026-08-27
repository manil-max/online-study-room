package com.manilmax.online_study_room.timer

import com.manilmax.online_study_room.R
import java.nio.file.Files
import java.nio.file.Path
import kotlin.math.pow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * WP-759 — KOSAN sayac bildiriminin panel yuzeyi.
 *
 * Bu dosyanin var olma sebebi: dokuz widget ve bildirim yuzeyi CIHAZDA HIC
 * GORULMEDEN v71'de yayina cikti. O tura kadarki testler "kod dogru mu"
 * olcuyordu; "ekranda iyi mi" olcmuyordu. Asagidaki iddialarin hepsi
 * emulatorde (API 33 + API 36, acik ve koyu golge) once GORULDU, sonra
 * yazildi. Kanit: `.artifacts/wp759-goruntu/`.
 *
 * Kontrast oranlari WCAG 2.1 bagil parlaklik formuluyle
 * (`L = 0.2126R + 0.7152G + 0.0722B`, sRGB dogrusallastirilmis) BURADA
 * yeniden hesaplanir; belgede/yorumda yazan sayi kopyalanmaz.
 *
 * Dort ayri iddia kumesi, dort ayri sabotaj:
 *   A) Hap rengi   — `timer_notification_action_ink`i `#212226` yap, yalniz A duser.
 *   B) Geri sayim  — zengin panel dalinda `countDown = false` yap, yalniz B duser.
 *   C) Faz isareti — zengin panel dalinda `shortCriticalTextRes = 0` yap, yalniz C duser.
 *   D) Teshis      — geri alinan kok neden iddiasini geri yaz, yalniz D duser.
 */
class TimerNotificationPanelWp759Test {

    private val startedAt = 1_700_000_000_000L

    private fun read(relative: String): String =
        String(Files.readAllBytes(Path.of(relative)), Charsets.UTF_8)

    private val colorsFile = "src/main/res/values/timer_notification_colors.xml"
    private val layoutFile = "src/main/res/layout/timer_notification.xml"
    private val pillFile = "src/main/res/drawable/timer_pill_bg.xml"
    private val serviceFile =
        "src/main/kotlin/com/manilmax/online_study_room/timer/StudyTimerService.kt"

    private fun stripXmlComments(xml: String): String =
        Regex("<!--[\\s\\S]*?-->").replace(xml, "")

    /** Once blok, sonra satir yorumu: blok icindeki `//` yanlislikla eslesmesin. */
    private fun stripKotlinComments(source: String): String =
        Regex("//[^\\n]*")
            .replace(Regex("/\\*[\\s\\S]*?\\*/").replace(source, ""), "")

    private fun colorTokens(): Map<String, String> =
        Regex("<color\\s+name=\"([^\"]+)\"\\s*>([^<]+)</color>")
            .findAll(stripXmlComments(read(colorsFile)))
            .associate { it.groupValues[1] to it.groupValues[2].trim() }

    private fun hex(name: String): String {
        val raw = colorTokens()[name] ?: error("$name renk kumesinden dusmus")
        assertTrue(
            "$name OPAK sabit #RRGGBB olmali (alfa / tema niteligi / Material You yok): $raw",
            Regex("^#[0-9A-Fa-f]{6}$").matches(raw),
        )
        return raw
    }

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

    /** Duzendeki elemanlari `android:id` degerine gore nitelik haritasina cevirir. */
    private fun layoutElements(): Map<String, Map<String, String>> {
        val body = stripXmlComments(read(layoutFile))
        return Regex("<([A-Za-z]\\w*)\\b([^>]*)>")
            .findAll(body)
            .mapNotNull { match ->
                val attrs = Regex("(android:\\w+)=\"([^\"]*)\"")
                    .findAll(match.groupValues[2])
                    .associate { it.groupValues[1] to it.groupValues[2] }
                val id = attrs["android:id"] ?: return@mapNotNull null
                id.removePrefix("@+id/").removePrefix("@id/") to attrs
            }
            .toMap()
    }

    private fun element(id: String): Map<String, String> =
        layoutElements()[id] ?: error("`$id` duzenden dusmus: $layoutFile")

    // =======================================================================
    // A) HAP RENGI — sahibin "tus gitmis" sikayetinin GERCEK sebebi.
    //
    // Olculen: API36 koyu golgede hap #212226 / yazi #1A1B21 -> 1.08:1;
    // API33 koyu golgede #171819 / #191C1E -> 1.04:1. Ayni ekran goruntusunun
    // kontrasti yukseltilince "Stop"/"Durdur" glifleri cikiyordu, yani dugme
    // CIZILIYOR ama GORUNMUYORDU.
    // Kanit: `.artifacts/wp759-goruntu/50-OZET-dugme-acik-vs-koyu.png`
    //
    // SABOTAJ: `timer_notification_action_ink`i `#212226` yap -> yalniz A duser.
    // =======================================================================

    @Test
    fun hap_renkleri_OPAK_ve_sabittir() {
        val fill = hex("timer_notification_action_fill")
        val ink = hex("timer_notification_action_ink")
        assertNotEquals(fill, ink)
    }

    /**
     * 🔴 Bu WP'nin bir numarali iddiasi. Hapin ZEMINI de bizim oldugu icin bu
     * oran her golgede (acik/koyu, her OEM) AYNIdir — olculebilir olmasinin
     * sebebi tam olarak budur.
     */
    @Test
    fun hap_etiketi_her_golgede_okunur() {
        val ratio = contrast(
            hex("timer_notification_action_ink"),
            hex("timer_notification_action_fill"),
        )
        assertTrue("Baslat/Durdur etiketi hapin uzerinde okunmuyor: $ratio", ratio >= 4.5)
    }

    /**
     * 🔴 WP-753'un tam simetrigi geri gelmesin. WP-205 ham `#FFFFFF` yazdi (acik
     * golgede kayboldu), WP-753 tema niteligi yazdi (koyu golgede kayboldu):
     * ayni hatanin iki yuzu. Panelde tek bir tema niteligi kalmadi.
     */
    @Test
    fun panelde_ve_hapta_TEK_BIR_tema_niteligi_kalmadi() {
        for (file in listOf(layoutFile, pillFile)) {
            val body = stripXmlComments(read(file))
            assertFalse(
                "$file tema niteligi tasiyor: `RemoteViews` uygulamanin " +
                    "ApplicationInfo temasiyla (platformun ACIK varsayilani) sisirilir",
                body.contains("?android:attr/") || body.contains("?attr/"),
            )
            assertFalse(
                "$file `@android:color/system_*` (Material You) tasiyor: " +
                    "rengi duvar kagidi secer, kontrasti kimse olcmez",
                body.contains("@android:color/system_"),
            )
        }
    }

    @Test
    fun hap_metni_rengini_SABIT_kaynaktan_alir() {
        assertEquals(
            "@color/timer_notification_action_ink",
            element("notif_timer_action")["android:textColor"],
        )
    }

    /**
     * 🔴 Kusur 4. `colorControlHighlight` bir DOKUNMA VURGUSU rengidir, dugme
     * dolgusu degil; yari saydam oldugu icin acik golgede duz gri bir blok
     * (#BAB9BF) verip dugmeyi DEVRE DISI gibi gosteriyordu
     * (`.artifacts/wp759-goruntu/20b-api36-calisan-T0-YAKIN.png`).
     */
    @Test
    fun hap_dolu_bir_dugmedir_dokunma_vurgusu_degildir() {
        val body = stripXmlComments(read(pillFile))
        assertFalse(
            "hap dolgusu hala bir dokunma vurgusu rengi",
            body.contains("colorControlHighlight"),
        )
        assertTrue(
            "hap dolgusu OPAK renk kaynagindan gelmeli",
            Regex("<solid\\s+android:color=\"@color/timer_notification_action_fill\"\\s*/>")
                .containsMatchIn(body),
        )
        // Dokunma hedefi korunur.
        val action = element("notif_timer_action")
        assertEquals("44dp", action["android:minHeight"])
        // 🔴 WP-761: `drawablePadding` iddiasi KALDIRILDI. Bir simgenin VARLIGINI
        // sart kosuyordu; simge cihazda olculdu ve kaldirildi. Affordance'i
        // tasiyan sey dolu zemin + 44dp hedef + net etiket; bir leke degil.
        assertEquals("84dp", action["android:minWidth"])
    }

    /**
     * 🔴 KURALIN IKINCI YONU — tek yonlu yazilsaydi bir sonraki tur golge
     * zeminindeki metne de sabit renk verir ve WP-205'i aynen tekrarlardi.
     *
     * Golge zemininin rengini BIZ SECMIYORUZ (cihazin/OEM'in karari), o yuzden
     * orada duran metnin rengi de sabit YAZILAMAZ. Bildirim `TextAppearance`i
     * kullanilir: onun rengi yapilandirmaya bagli bir KAYNAKtir
     * (`@color/notification_*_text_color`) ve HOST'un koyu/acik ayarini izler —
     * tema NITELIKLERI izlemez. Olcum bunu dogruluyor: ayni panelde rakamlar
     * koyu golgede 11.13:1 ile okunurken dugme 1.08:1 ile kayboluyordu.
     */
    @Test
    fun golge_zeminindeki_metin_rengini_ASLA_sabit_yazmaz() {
        for (id in listOf("notif_timer_elapsed", "notif_timer_label")) {
            val attrs = element(id)
            assertNull(
                "`$id` golge zemininde duruyor; sabit renk WP-205'i tekrarlar",
                attrs["android:textColor"],
            )
            val appearance = attrs["android:textAppearance"]
            assertTrue(
                "`$id` bildirim TextAppearance'i kullanmali, buldum: $appearance",
                appearance != null &&
                    appearance.startsWith("@style/TextAppearance.Compat.Notification"),
            )
        }
    }

    // =======================================================================
    // B) GERI SAYIM — pomodoro/geri sayim modunda panel YUKARI sayiyordu.
    //
    // Olculen: mode=pomodoro, targetSeconds=300, phase=rest ile baslatildi;
    // uygulamada 5:00'dan geriye sayan mola, bildirimde 00:07'den ILERI saydi.
    // Kanit: `.artifacts/wp759-goruntu/28b-api36-MOLA-YAKIN.png`
    //
    // SABOTAJ: zengin panel dalinda `countDown = false` yap -> yalniz B duser.
    // =======================================================================

    @Test
    fun zengin_panel_hedefli_modda_GERI_sayar() {
        val plan = runningTimerNotificationPlan(
            richPanel = true,
            isBreak = true,
            targetSeconds = 300,
            startedAtMs = startedAt,
            nowMs = startedAt + 7_000L,
        )

        assertEquals(TimerNotificationStyle.CUSTOM_PANEL, plan.style)
        assertTrue("hedefli mod panelde de GERI saymali", plan.countDown)
        assertEquals(300, plan.totalSeconds)
        assertEquals("geri sayimda `when` BITIS anidir", startedAt + 300_000L, plan.whenMs)
    }

    @Test
    fun zengin_panel_hedefsiz_modda_yukari_sayar() {
        for (target in listOf<Int?>(null, 0, -1)) {
            val plan = runningTimerNotificationPlan(
                richPanel = true,
                isBreak = false,
                targetSeconds = target,
                startedAtMs = startedAt,
                nowMs = startedAt + 7_000L,
            )
            assertFalse("acik uclu kronometrenin geri sayacagi bir hedefi yok", plan.countDown)
            assertEquals(0, plan.totalSeconds)
            assertEquals(startedAt, plan.whenMs)
        }
    }

    /**
     * 🔴 Kusurun ikinci yarisi. `Chronometer` iki yonu AYNI alandan cizer ama
     * TERS okur: yukari sayarken `now - base`, geri sayarken `base - now`.
     * Eski kod her iki halde de baslangic anini yaziyordu.
     */
    @Test
    fun panel_kronometre_tabani_geri_sayimda_BITIS_anidir() {
        val nowMs = startedAt + 7_000L
        val nowElapsed = 5_000_000L
        val plan = runningTimerNotificationPlan(true, true, 300, startedAt, nowMs)

        val base = panelChronometerBaseMs(plan, startedAt, nowMs, nowElapsed)

        // `Chronometer` `base - now` cizer: kalan 300 - 7 = 293 sn olmali.
        assertEquals(293_000L, base - nowElapsed)
    }

    @Test
    fun panel_kronometre_tabani_yukari_sayimda_BASLANGIC_anidir() {
        val nowMs = startedAt + 7_000L
        val nowElapsed = 5_000_000L
        val plan = runningTimerNotificationPlan(true, false, null, startedAt, nowMs)

        val base = panelChronometerBaseMs(plan, startedAt, nowMs, nowElapsed)

        // `Chronometer` `now - base` cizer: gecen 7 sn olmali.
        assertEquals(7_000L, nowElapsed - base)
    }

    /**
     * SystemUI ayni sisirilmis gorunumu yeniden kullanir; yazilmayan alan
     * ONCEKI degeriyle kalir. Bir geri sayimdan sonra bayrak yazilmazsa acik
     * uclu kronometre de geri sayardi — bu yuzden HER cagrida yazilir.
     */
    @Test
    fun countDown_bayragi_panele_HER_cagrida_yazilir() {
        val code = stripKotlinComments(read(serviceFile))
        assertTrue(
            "`setChronometerCountDown` panel yolunda hic cagrilmiyor",
            code.contains("setChronometerCountDown(R.id.notif_timer_elapsed"),
        )
        assertTrue(
            "panel tabani saf `panelChronometerBaseMs` uzerinden gelmeli",
            code.contains("panelChronometerBaseMs("),
        )
    }

    // =======================================================================
    // C) FAZ ISARETI — mola ile odak bildirimde ayirt edilemiyordu.
    //
    // Olculen: mola panelinin ekran goruntusu ile odak panelininki, rakam
    // disinda BIREBIR ayni. Tek ayirt edici isaret dugme etiketiydi, o da koyu
    // golgede gorunmuyordu.
    // Kanit: `28b-api36-MOLA-YAKIN.png` ile `24b-api36-KOYU-YAKIN.png`
    //
    // SABOTAJ: zengin panel dalinda `shortCriticalTextRes = 0` yap -> yalniz C duser.
    // =======================================================================

    @Test
    fun mola_ile_odak_panelde_AYIRT_EDILIR() {
        val work = runningTimerNotificationPlan(true, false, 1500, startedAt, startedAt)
        val rest = runningTimerNotificationPlan(true, true, 300, startedAt, startedAt)

        for (plan in listOf(work, rest)) {
            assertNotEquals("panelin GORUNEN faz isareti bos", 0, plan.shortCriticalTextRes)
            assertNotEquals("ozel panel yolunda da baslik gerekir", 0, plan.titleRes)
            assertNotEquals(0, plan.bodyRes)
        }
        assertEquals(R.string.timer_subtext_focus, work.shortCriticalTextRes)
        assertEquals(R.string.timer_subtext_break, rest.shortCriticalTextRes)
        assertNotEquals(work.titleRes, rest.titleRes)
        assertNotEquals(work.bodyRes, rest.bodyRes)
    }

    /**
     * 🔴 WP-761 — faz isareti yalniz ISTISNA durumu isaretler.
     *
     * Sahip cihazda gordu: odak panelinde 26sp sayacin yaninda "FOCUS"
     * yaziyordu ve hicbir sey soylemiyordu -- panel zaten yalniz calisirken
     * var. Tekrar bilgi degildir; gurultudur.
     *
     * Ayirt etme KAYBOLMAZ ve olculen sey budur: molada etiket yazar, odakta
     * bosluk kalir. Iki panel hala farkli gorunur.
     */
    @Test
    fun faz_etiketi_yalniz_MOLADA_yazar() {
        assertEquals(
            "Odakta etiket bos kalmali: 'FOCUS' tekrardi",
            0,
            panelPhaseLabelRes(isBreak = false, shortCriticalTextRes = R.string.timer_subtext_focus),
        )
        assertEquals(
            "Molada etiket YAZMALI: ayirt edici tek gorsel isaret o",
            R.string.timer_subtext_break,
            panelPhaseLabelRes(isBreak = true, shortCriticalTextRes = R.string.timer_subtext_break),
        )
    }

    @Test
    fun panel_faz_isaretini_GERCEKTEN_cizer() {
        assertTrue(
            "faz etiketi duzende yok: kullanicinin GORDUGU satir bu",
            read(layoutFile).contains("@+id/notif_timer_label"),
        )
        val code = stripKotlinComments(read(serviceFile))
        assertTrue(
            "faz etiketi duzende var ama koddan hic yazilmiyor (bos kalir)",
            code.contains("R.id.notif_timer_label"),
        )
        assertFalse(
            "ozel panel yolunda baslik yine bos yaziliyor",
            code.contains("setContentTitle(\"\")"),
        )
    }

    // =======================================================================
    // D) GERI ALINAN TESHIS — yanlis kok neden dosyada OLGU gibi durmamali.
    //
    // Olculen: API36 GENISLETILMIS bildirimde ikonsuz `addAction(0, ...)` mavi
    // metin dugmesi olarak SORUNSUZ cizildi; dugmenin gorunmedigi hal DARALMIS
    // bildirimdir ve Android orada eylemleri zaten gostermez.
    // Kanit: `36c-api36-LIVEUPDATE-BOSTA-TAMKART.png` (Start GORUNUYOR) ve
    //        `37b-api36-LIVEUPDATE-BOSTA-DARALMIS-YAKIN.png` (dugme YOK)
    //
    // SABOTAJ: iddiayi retraksiyon isareti olmadan geri yaz -> yalniz D duser.
    // =======================================================================

    @Test
    fun bildirim_eylemleri_GERCEK_ikon_tasir() {
        val code = stripKotlinComments(read(serviceFile))
        assertFalse(
            "ikonsuz `addAction(0, ...)` geri geldi: ikon, golge DISINDAKI " +
                "yuzeylerde (Wear/Auto/eski surum/terfi cipi) eylemin tek karsiligidir",
            Regex("addAction\\(\\s*0\\s*,").containsMatchIn(code),
        )
        assertNotEquals(0, R.drawable.ic_notif_action_stop)
        assertNotEquals(0, R.drawable.ic_notif_action_start)
        // 🔴 WP-761: `ic_notif_pill_*` iddialari KALDIRILDI, zayiflatilmadi.
        // Onlar SISTEM eylem ikonlari degil, kendi cizdigimiz hapin ICINDEKI
        // simgelerdi. Sahip cihazda gordu ve "butondaki kare isaret ne alaka"
        // dedi: dolu kare, kalin "Durdur" yazisinin yaninda bir durdurma
        // simgesi olarak degil rastgele bir leke olarak okunuyordu. Cizimler
        // silindi. Bu testin konusu olan iddia -- SISTEM eylemleri ikonsuz
        // eklenmesin -- oldugu gibi duruyor ve o iki kaynak hala olculuyor.
    }

    /**
     * 🔴 Sebebi: bir sonraki tur bu dosyayi okuyup YANLIS yere bakacak. Iddia
     * silinmedi — ALINTILANIP geri alindi. Test, iddianin her gecisinin bir
     * retraksiyon isaretinin ardindan geldigini olcer.
     */
    @Test
    fun geri_alinan_teshis_OLGU_gibi_durmuyor() {
        val source = read(serviceFile)
        val claim = "cizilmeyebilir"
        var index = source.indexOf(claim)
        var seen = 0
        while (index >= 0) {
            // Retraksiyon isareti iddianin oncesinde de sonrasinda da olabilir
            // (alinti once gelir, "YANLISLANDI" hemen ardindan) — iki yon de sayilir.
            val window = source.substring(
                maxOf(0, index - 600),
                minOf(source.length, index + claim.length + 600),
            )
            assertTrue(
                "\"$claim\" iddiasi $index. karakterde retraksiyon isareti olmadan " +
                    "duruyor: emulatorde YANLISLANDI, olgu gibi yazilamaz",
                window.contains("YANLISLANDI") ||
                    window.contains("DEGILDIR") ||
                    window.contains("GERI ALINAN"),
            )
            seen++
            index = source.indexOf(claim, index + claim.length)
        }
        assertTrue("retraksiyonun kendisi de silinmis", seen >= 1)
        assertTrue(
            "kanit yolu kayboldu: bir sonraki tur olcumu yeniden uretemez",
            source.contains("wp759-goruntu"),
        )
    }
}
