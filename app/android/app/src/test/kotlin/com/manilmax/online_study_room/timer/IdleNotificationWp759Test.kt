package com.manilmax.online_study_room.timer

import com.manilmax.online_study_room.R
import java.nio.file.Files
import java.nio.file.Path
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * WP-759 — BOSTA sayac bildiriminin nobetcileri.
 *
 * Bu dosyanin iddialari bir tasarim belgesinden degil, **emulatorde cekilmis
 * ekran goruntulerinden** gelir (`.artifacts/wp759-goruntu/`). v71 dokuz
 * bildirim/widget yuzeyini CIHAZDA HIC GORULMEDEN yayina cikardi; birim testi,
 * APK dex'i ve derlenmis layout "kod dogru mu" olcuyordu, "ekranda iyi mi"
 * degil. Olculen uc kusur ve uc AYRI sabotaj:
 *
 * | # | ekranda gorulen                                   | sabotaj                                     |
 * |---|---------------------------------------------------|---------------------------------------------|
 * | A | kartin TUM icerigi kalin "00:00"                  | `frozenClockText`e "00:00" yaz              |
 * | B | her Durdur'dan sonra kart golgede KALIYOR         | `handleStop`taki kaldirma cagrisini sil     |
 * | C | koyu temada Baslat dugmesi gorunmuyor (1.08:1)    | `usesCustomView = true` yap / ikonu 0 yap   |
 *
 * Ne OLCMEDIGI (ve olctugunu IDDIA ETMEDIGI): kartin gercekten cizilmesi,
 * gercek kontrast orani, OEM golgesi. Onlar cihaz kanitidir — bu turun kabul
 * kriteri ekran goruntusuydu ve goruntuler yukaridaki klasordedir.
 */
class IdleNotificationWp759Test {

    private fun read(relative: String): String =
        String(Files.readAllBytes(Path.of(relative)), Charsets.UTF_8)

    private val servicePath =
        "src/main/kotlin/com/manilmax/online_study_room/timer/StudyTimerService.kt"

    /**
     * Yorumlari eler. Zorunlu: bu dosyada kusurun HIKAYESI yorumlarda anlatilir
     * ("00:00", `STOP_FOREGROUND_DETACH`), ve anlatilan seyin kosan kod
     * sanilmasi bu depoda daha once oldu (WP-640).
     */
    private fun code(src: String): String =
        Regex("""(?s)/\*.*?\*/""").replace(src, "")
            .lines()
            .filterNot { it.trimStart().startsWith("//") }
            .joinToString("\n")

    private val serviceCode: String by lazy { code(read(servicePath)) }

    // ------------------------------------------------------------------
    // Kotlin govde ayiklama: kaynak taramasi "satir 438" gibi bir yere degil,
    // FONKSIYONUN kendisine baglansin diye. Suslu parantezler eslesir; string
    // ve karakter sabitlerinin icindekiler sayilmaz.
    // ------------------------------------------------------------------

    private data class KotlinFunction(val name: String, val body: String)

    private fun matchClose(src: String, openIndex: Int, open: Char, close: Char): Int {
        var depth = 0
        var i = openIndex
        while (i < src.length) {
            when (src[i]) {
                '"' -> {
                    i++
                    while (i < src.length && src[i] != '"') {
                        if (src[i] == '\\') i++
                        i++
                    }
                }
                '\'' -> {
                    i++
                    while (i < src.length && src[i] != '\'') {
                        if (src[i] == '\\') i++
                        i++
                    }
                }
                open -> depth++
                close -> {
                    depth--
                    if (depth == 0) return i
                }
            }
            i++
        }
        return -1
    }

    /** Yalniz **govdesi suslu parantezli** fonksiyonlar (ifade govdeleri haric). */
    private fun blockFunctions(src: String): List<KotlinFunction> =
        Regex("""\bfun\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(""")
            .findAll(src)
            .mapNotNull { m ->
                val parenOpen = src.indexOf('(', m.range.first)
                val parenClose = matchClose(src, parenOpen, '(', ')')
                if (parenClose < 0) return@mapNotNull null
                val after = src.substring(parenClose + 1, minOf(parenClose + 400, src.length))
                val brace = after.indexOf('{')
                val assign = after.indexOf('=')
                if (brace < 0 || (assign in 0 until brace)) return@mapNotNull null
                val bodyOpen = parenClose + 1 + brace
                val bodyClose = matchClose(src, bodyOpen, '{', '}')
                if (bodyClose < 0) return@mapNotNull null
                KotlinFunction(m.groupValues[1], src.substring(bodyOpen, bodyClose + 1))
            }
            .toList()

    private fun function(name: String): String =
        blockFunctions(serviceCode).firstOrNull { it.name == name }?.body
            ?: error("`$name` fonksiyonu StudyTimerService icinde yok")

    // ------------------------------------------------------------------
    // A) Kusur 1 — bosta kartin TUM icerigi sabit "00:00" idi.
    //    12b-api36-KOYU-BOSTA-YAKIN.png · 10b-api36-bildirim-bosta-YAKIN.png
    // ------------------------------------------------------------------

    @Test
    fun idle_card_never_shows_a_frozen_clock() {
        val plan = idleTimerNotificationPlan()

        // 🔴 Kusurun ta kendisi: sifirlanmis bir saat "hicbir sey kosmuyor"un
        // degil, "sayac dondu/bozuldu"nun gorsel karsiligidir.
        assertNull(
            "Bosta karta SABIT saat metni yazilamaz: ${plan.frozenClockText}",
            plan.frozenClockText,
        )
    }

    @Test
    fun idle_card_says_what_the_app_state_is() {
        val plan = idleTimerNotificationPlan()

        assertNotEquals("Bosta kartin basligi olmak ZORUNDA", 0, plan.titleRes)
        assertNotEquals("Baslik tek basina ne yapilacagini soylemiyor", 0, plan.bodyRes)
        assertNotEquals("Baslik ve govde ayni metin olamaz", plan.titleRes, plan.bodyRes)
        assertEquals(R.string.timer_ready, plan.titleRes)
        assertEquals(R.string.timer_idle_body, plan.bodyRes)
        assertEquals(R.string.action_start, plan.actionLabelRes)
    }

    /**
     * Yukaridaki test `R` tamsayilarini olcer; bu test o tamsayilarin ARDINDAKI
     * METNI olcer. Ikisi ayri: bir gun `timer_ready` degeri "00:00" yapilirsa
     * ustteki test yesil kalirdi.
     */
    @Test
    fun the_idle_strings_are_real_sentences_in_both_locales() {
        val clockShaped = Regex("""^\d{1,2}(:\d{2}){1,2}$""")
        for (dir in listOf("values", "values-tr")) {
            val xml = read("src/main/res/$dir/strings.xml")
            for (key in listOf("timer_ready", "timer_idle_body")) {
                val value = Regex("""<string name="$key">(.*?)</string>""")
                    .find(xml)?.groupValues?.get(1)
                assertTrue("$dir/strings.xml icinde $key yok", value != null)
                assertTrue("$dir/$key bos", value!!.isNotBlank())
                assertFalse(
                    "$dir/$key bir SAAT gibi gorunuyor: $value",
                    clockShaped.matches(value.trim()),
                )
            }
        }
    }

    /**
     * Kaynak tarafi: `buildIdleRemoteViews` "00:00"i hem `Chronometer`in
     * `format`ina hem de metnine yaziyordu. Karti plan disindan besleyen
     * hicbir sabit metin kalmamali.
     */
    @Test
    fun the_idle_builder_reads_every_word_from_the_plan() {
        val builder = function("buildIdleNotification")

        assertTrue("Bosta kart plani kullanmiyor", builder.contains("idleTimerNotificationPlan()"))
        assertTrue(builder.contains("getString(plan.titleRes)"))
        assertTrue(builder.contains("getString(plan.bodyRes)"))
        assertTrue(builder.contains("getString(plan.actionLabelRes)"))

        val literal = Regex(""""[^"]*"""").find(builder)
        assertNull(
            "Bosta kart govdesinde sabit metin var: ${literal?.value}",
            literal?.value,
        )

        assertFalse(
            "`buildIdleRemoteViews` geri geldi: bosta kart yine ozel gorunum tasiyor",
            serviceCode.contains("buildIdleRemoteViews"),
        )
        assertFalse(
            "Servis kodunda sifirlanmis saat sabiti var",
            Regex(""""\d{1,2}:\d{2}(:\d{2})?"""").containsMatchIn(serviceCode),
        )
    }

    // ------------------------------------------------------------------
    // B) Kusur 2 — kart her Durdur'dan sonra golgede kaliyordu.
    //    11-api36-KOYU-HIC-BASLATILMADAN.png (hic yok) vs
    //    12-api36-KOYU-BOSTA-v43panel.png (durdurma sonrasi kalan kart)
    // ------------------------------------------------------------------

    @Test
    fun every_path_that_posts_the_idle_card_also_takes_it_away() {
        val posters = blockFunctions(serviceCode)
            .filter { it.name != "buildIdleNotification" }
            .filter { it.body.contains("buildIdleNotification()") }

        assertTrue(
            "Bosta karti posta eden hicbir yol bulunamadi: tarayici bozulmus olabilir",
            posters.isNotEmpty(),
        )
        for (fn in posters) {
            assertTrue(
                "`${fn.name}` bosta karti POSTALIYOR ama KALDIRMIYOR -- " +
                    "kart golgede kalir (WP-759 kusur 2)",
                fn.body.contains("exitForegroundRemovingNotification()"),
            )
        }
        // Olculen kusur bire bir buydu: handleStop postaliyor, birakip cikiyordu.
        assertTrue(
            "Durdur yolu bosta karti postalamiyor: FGS borcu odenmiyor olabilir",
            posters.any { it.name == "handleStop" },
        )
    }

    @Test
    fun no_stop_path_may_detach_and_keep_the_notification() {
        assertFalse(
            "`STOP_FOREGROUND_DETACH` geri geldi: bildirim BILEREK birakiliyor",
            serviceCode.contains("STOP_FOREGROUND_DETACH"),
        )
        assertFalse(
            "`detachForegroundKeepNotification` geri geldi",
            serviceCode.contains("detachForegroundKeepNotification"),
        )

        val exit = function("exitForegroundRemovingNotification")
        assertTrue(
            "Foreground bagi kopariliyor ama bildirim kaldirilmiyor",
            exit.contains("STOP_FOREGROUND_REMOVE"),
        )
        assertTrue(
            "Bildirim iptal edilmiyor: DETACH edilmis bir kart `stopForeground` ile gitmez",
            exit.contains("cancel(NOTIFICATION_ID)"),
        )
    }

    // ------------------------------------------------------------------
    // C) Kusur 3 — koyu temada Baslat dugmesi gorunmuyordu (olculen 1.08:1).
    //    12b-api36-KOYU-BOSTA-YAKIN.png · 42b-api33-KOYU-BOSTA-YAKIN.png
    // ------------------------------------------------------------------

    /**
     * Kok neden: ozel `RemoteViews`, uygulamanin `ApplicationInfo` temasiyla
     * (= platformun ACIK varsayilani) sisirilir; `?android:attr/...` bu yuzden
     * golgenin temasini degil HER ZAMAN acik temayi izler. Bosta kart bu
     * tuzaktan tek bir yolla cikar: ozel gorunum TASIMAZ, dugmeyi SystemUI
     * cizer ve rengi golgenin GERCEK temasindan gelir.
     */
    @Test
    fun the_idle_start_button_is_drawn_by_the_system_not_by_us() {
        val plan = idleTimerNotificationPlan()

        assertFalse(
            "Bosta kart ozel gorunum tasiyorsa dugme yine uygulama temasindan " +
                "renk alir ve koyu golgede kaybolur",
            plan.usesCustomView,
        )
        // v71'de eylem `addAction(0, ...)` idi: IKONSUZ eylem cizilmeyebilir.
        assertNotEquals(
            "Bosta kartin eylemi IKONSUZ: modern Android cizmeyebilir",
            0,
            plan.actionIconRes,
        )

        val builder = function("buildIdleNotification")
        assertTrue(builder.contains("addAction("))
        assertTrue(
            "Eylem ikonu plandan gelmiyor",
            builder.contains("plan.actionIconRes"),
        )
        for (forbidden in listOf(
            "setCustomContentView",
            "setCustomBigContentView",
            "DecoratedCustomViewStyle",
        )) {
            assertFalse(
                "Bosta kart yine ozel gorunum tasiyor: $forbidden",
                builder.contains(forbidden),
            )
        }
    }

    /**
     * LANE DISI NOBETCI (kasitli). Kosan panelin hapi baska bir lane'in
     * yuzeyidir; burada yalniz KOK NEDEN olculur, tasarim degil: hapin dolgusu
     * bir tema NITELIGI olamaz. WP-753 tam olarak bunu yaparak dugmeyi koyu
     * temada 1.08:1'e dusurdu; ayni satirin ucuncu kez donmemesi icin duruyor.
     */
    @Test
    fun the_action_pill_fill_is_never_a_theme_attribute() {
        val drawable = read("src/main/res/drawable/timer_pill_bg.xml")
        val solid = Regex("""<solid\s+android:color="([^"]+)"""")
            .find(Regex("(?s)<!--.*?-->").replace(drawable, ""))
            ?.groupValues?.get(1)

        assertTrue("timer_pill_bg.xml icinde <solid> yok", solid != null)
        assertFalse(
            "Hap dolgusu tema niteligi ($solid): `RemoteViews` uygulamanin " +
                "acik temasiyla sisirilir, golgenin temasiyla DEGIL",
            solid!!.startsWith("?"),
        )
    }
}
