package com.manilmax.online_study_room.widgets

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * WP-701: gorev widget'inin **native** yarisi.
 *
 * Burada olculen sey kullanicinin dokundugu anda olan seydir: uygulama
 * kapaliyken ayna ters cevrilir, niyet kuyruga yazilir. Robolectric/mockito
 * yok (bkz. `app/build.gradle.kts`), bu yuzden mantik saf fonksiyonlara
 * ayrildi; `SharedPreferences`tan okuma tek satirlik bir `getString`tir.
 *
 * Boyut tarafinda aritmetik bir MODEL kullanilir (WidgetSizeClassWp699Test ile
 * ayni varsayimlar: karakter genisligi 0.60 x punto, satir yuksekligi
 * 1.30 x punto, 8dp emniyet payi). Modelin isi punto/satir merdivenini kutu
 * sinirlarina BAGLAMAKTIR; gercek pikseller cihazda dogrulanir.
 */
class TaskWidgetWp701Test {

    private fun mirror(vararg items: Pair<String, Boolean>): String =
        encodeTaskWidgetMirror(
            TaskWidgetModel(
                title = "Gorevler",
                emptyLabel = "Henuz gorev yok",
                items = items.map { TaskWidgetItem(it.first, "Gorev ${it.first}", it.second) },
            ),
        )

    // --- ayna --------------------------------------------------------------

    @Test
    fun ayna_gorevleri_ve_isaretli_durumu_tasir() {
        val model = parseTaskWidgetMirror(mirror("a" to false, "b" to true))

        assertEquals("Gorevler", model.title)
        assertEquals("Henuz gorev yok", model.emptyLabel)
        assertEquals(listOf("a", "b"), model.items.map { it.id })
        assertFalse(model.items[0].done)
        assertTrue(model.items[1].done)
    }

    @Test
    fun bozuk_kayit_widgeti_bos_duruma_dusurur_uygulamayi_degil() {
        assertEquals(EMPTY_TASK_WIDGET_MODEL, parseTaskWidgetMirror("{bu json degil"))
        assertEquals(EMPTY_TASK_WIDGET_MODEL, parseTaskWidgetMirror(null))
        assertEquals(EMPTY_TASK_WIDGET_MODEL, parseTaskWidgetMirror(""))
        // Gorev listesi metin gelirse de cizim bos duruma duser.
        assertEquals(emptyList<TaskWidgetItem>(), parseTaskWidgetMirror("""{"tasks":"x"}""").items)
    }

    @Test
    fun tanimadigi_alan_widgeti_oldurmez() {
        // Dart tarafi aynaya yeni bir alan ekledigi gun widget sessizce
        // bosalmamali; ayristirici bilmedigi alani yok sayar.
        val model = parseTaskWidgetMirror(
            """{"title":"Gorevler","empty":"yok","updatedAt":"2026-08-11T10:00:00Z",""" +
                """"tasks":[{"id":"a","title":"Matematik","done":false,"dueAt":"yarin"}]}""",
        )
        assertEquals(1, model.items.size)
        assertEquals("Matematik", model.items[0].title)
    }

    @Test
    fun kimliksiz_veya_basliksiz_satir_cizilmez() {
        val model = parseTaskWidgetMirror(
            """{"tasks":[{"id":"","title":"Bos kimlik"},{"id":"b","title":"  "},""" +
                """{"id":"c","title":"Gecerli"}]}""",
        )
        assertEquals(listOf("c"), model.items.map { it.id })
    }

    @Test
    fun satir_sayisi_layout_ile_sinirli() {
        val fazla = (0 until 9).map { "t$it" to false }.toTypedArray()
        assertEquals(TASK_WIDGET_MAX_ROWS, parseTaskWidgetMirror(mirror(*fazla)).items.size)
    }

    @Test
    fun tirnakli_baslik_json_i_bozmaz() {
        val json = encodeTaskWidgetMirror(
            TaskWidgetModel(
                title = "Gorev \"listesi\"",
                emptyLabel = "yok",
                items = listOf(TaskWidgetItem("a", "Ders: \"tekrar\"\n2. bolum", false)),
            ),
        )
        val model = parseTaskWidgetMirror(json)
        assertEquals("Gorev \"listesi\"", model.title)
        assertEquals("Ders: \"tekrar\"\n2. bolum", model.items[0].title)
    }

    // --- iyimser isaretleme ------------------------------------------------

    @Test
    fun dokunma_yalniz_o_gorevi_cevirir() {
        val result = toggleTaskInMirror(mirror("a" to false, "b" to true), "a")

        assertTrue(result!!.done)
        val model = parseTaskWidgetMirror(result.mirrorJson)
        assertTrue(model.items[0].done)
        assertTrue("komsu satir degismemeli", model.items[1].done)
        assertEquals("Gorevler", model.title)
        assertEquals("Henuz gorev yok", model.emptyLabel)
    }

    @Test
    fun isaretli_gorev_geri_alinabilir() {
        val result = toggleTaskInMirror(mirror("a" to true), "a")
        assertFalse(result!!.done)
        assertFalse(parseTaskWidgetMirror(result.mirrorJson).items[0].done)
    }

    @Test
    fun bilinmeyen_kimlik_hicbir_sey_yazdirmaz() {
        // Uygulamada silinmis bir gorev icin kuyruga niyet yazmak, olmeyen bir
        // kaydi diriltmeye calismak olurdu.
        assertNull(toggleTaskInMirror(mirror("a" to false), "yok"))
        assertNull(toggleTaskInMirror(null, "a"))
        assertNull(toggleTaskInMirror("bozuk", "a"))
    }

    // --- bekleyen kuyruk ---------------------------------------------------

    @Test
    fun kuyruk_toggle_degil_ISTENEN_DURUM_tasir() {
        // Cift uygulama korumasi bicimdedir: "true olsun" iki kez islense de
        // sonuc ayni; "tersine cevir" olsaydi ikincisi isareti geri alirdi.
        val queue = appendPendingTaskToggle(null, "a", done = true, opId = "o1", atMs = 5L)
        val ops = parsePendingTaskToggles(queue)

        assertEquals(1, ops.size)
        assertEquals("a", ops[0].taskId)
        assertTrue(ops[0].done)
        assertEquals(5L, ops[0].atMs)
    }

    @Test
    fun ayni_gorevin_eski_niyeti_dusurulur() {
        var queue = appendPendingTaskToggle(null, "a", true, "o1", 1L)
        queue = appendPendingTaskToggle(queue, "b", true, "o2", 2L)
        queue = appendPendingTaskToggle(queue, "a", false, "o3", 3L)

        val ops = parsePendingTaskToggles(queue)
        assertEquals(listOf("b", "a"), ops.map { it.taskId })
        assertFalse("son karar uygulanmali", ops.first { it.taskId == "a" }.done)
    }

    @Test
    fun kuyruk_sinirsiz_buyumez() {
        var queue: String? = null
        for (index in 0 until TASK_PENDING_MAX + 20) {
            queue = appendPendingTaskToggle(queue, "t$index", true, "o$index", index.toLong())
        }
        val ops = parsePendingTaskToggles(queue)
        assertEquals(TASK_PENDING_MAX, ops.size)
        assertEquals("t${TASK_PENDING_MAX + 19}", ops.last().taskId)
    }

    @Test
    fun zaman_damgasi_METIN_olarak_gider() {
        // JSON sayisi Double'a coker; milisaniye hassasiyeti kaybolurdu.
        // (Prefs tarafinda da sayi yazilmaz: Dart setInt -> putLong, native
        // getInt -> ClassCastException -> surec olur. v58 dersi.)
        val now = 1_754_913_000_123L
        val queue = appendPendingTaskToggle(null, "a", true, "o1", now)
        assertTrue(queue.contains("\"at\":\"$now\""))
        assertEquals(now, parsePendingTaskToggles(queue)[0].atMs)
    }

    @Test
    fun bozuk_kuyruk_yeni_niyeti_engellemez() {
        val queue = appendPendingTaskToggle("bu json degil", "a", true, "o1", 1L)
        assertEquals(listOf("a"), parsePendingTaskToggles(queue).map { it.taskId })
    }

    // --- boyut -------------------------------------------------------------

    @Test
    fun launcher_boyut_bildirmediginde_varsayilan_kullanilir() {
        val spec = TASK_WIDGET_SIZE_SPEC
        assertEquals(
            widgetSizeClass(spec, spec.defaultWidthDp, spec.defaultHeightDp),
            widgetSizeClass(spec, 0, 0),
        )
    }

    @Test
    fun YUKSEKLIK_satir_sayisini_GENISLIK_puntoyu_secer() {
        val spec = TASK_WIDGET_SIZE_SPEC

        val genisAmaKisa = widgetSizeClass(spec, 250, 80)
        assertEquals(WidgetWidthClass.WIDE, genisAmaKisa.width)
        assertEquals(2, taskWidgetRowCount(genisAmaKisa.height))
        assertFalse("kisa kutuda baslik yer kaplamamali", taskWidgetTitleVisible(genisAmaKisa.height))

        val darAmaUzun = widgetSizeClass(spec, 110, 250)
        assertEquals(WidgetWidthClass.NARROW, darAmaUzun.width)
        assertEquals(TASK_WIDGET_MAX_ROWS, taskWidgetRowCount(darAmaUzun.height))
        assertTrue(taskWidgetTitleVisible(darAmaUzun.height))
    }

    @Test
    fun buyudukce_daha_cok_gorev_gorunur() {
        val model = parseTaskWidgetMirror(
            mirror("a" to false, "b" to false, "c" to false, "d" to false, "e" to false),
        )
        assertEquals(2, taskWidgetVisibleItems(model, WidgetHeightClass.SHORT).size)
        assertEquals(3, taskWidgetVisibleItems(model, WidgetHeightClass.MEDIUM).size)
        assertEquals(5, taskWidgetVisibleItems(model, WidgetHeightClass.TALL).size)
        // Kirpma listenin BASINDAN alir: kullanicinin sirasi korunur.
        assertEquals(
            listOf("a", "b"),
            taskWidgetVisibleItems(model, WidgetHeightClass.SHORT).map { it.id },
        )
    }

    @Test
    fun gorunen_satirlar_kutuya_SIGAR() {
        // Her yukseklik sinifinin EN KUCUK kutusunda baslik + satirlar sigmali.
        assertHeightFits(WidgetHeightClass.SHORT, boxDp = 80, widthClass = WidgetWidthClass.NARROW)
        assertHeightFits(WidgetHeightClass.MEDIUM, boxDp = 110, widthClass = WidgetWidthClass.MEDIUM)
        assertHeightFits(WidgetHeightClass.TALL, boxDp = 180, widthClass = WidgetWidthClass.WIDE)
    }

    @Test
    fun genisledikce_daha_uzun_baslik_okunur() {
        // Punto merdiveni kutuya bagli: genis kutuda hem punto hem gorunen
        // karakter sayisi artmali, yoksa "esnek" iddiasi kagit uzerinde kalir.
        val narrowChars = labelCharsThatFit(110, WidgetWidthClass.NARROW)
        val mediumChars = labelCharsThatFit(180, WidgetWidthClass.MEDIUM)
        val wideChars = labelCharsThatFit(250, WidgetWidthClass.WIDE)

        assertTrue("dar kutuda en az 8 karakter okunmali ($narrowChars)", narrowChars >= 8)
        assertTrue("orta kutu dardan genis olmali", mediumChars > narrowChars)
        assertTrue("genis kutu ortadan genis olmali", wideChars > mediumChars)
        assertTrue("genis kutuda en az 20 karakter okunmali ($wideChars)", wideChars >= 20)
    }

    // --- aritmetik model ---------------------------------------------------

    private val safetyMarginDp = 8f

    private fun lineHeightDp(sp: Float): Float = sp * 1.30f

    private fun assertHeightFits(
        height: WidgetHeightClass,
        boxDp: Int,
        widthClass: WidgetWidthClass,
    ) {
        val paddingDp = widgetRootPaddingDp(12, height)
        val available = boxDp - 2f * paddingDp - safetyMarginDp
        var needed = taskWidgetRowCount(height) * lineHeightDp(TASK_ROW_SP.of(widthClass))
        if (taskWidgetTitleVisible(height)) {
            needed += lineHeightDp(TASK_TITLE_SP.of(widthClass))
        }
        assertTrue(
            "$height: $needed dp gerekiyor, $available dp var -> TASAR",
            needed <= available,
        )
    }

    /** Kutuya sigan etiket karakteri (kutucuk + bosluk ~2 karakter dusulur). */
    private fun labelCharsThatFit(boxDp: Int, widthClass: WidgetWidthClass): Int {
        val paddingDp = 12
        val usable = boxDp - 2f * paddingDp - safetyMarginDp
        val charWidth = TASK_ROW_SP.of(widthClass) * 0.60f
        return (usable / charWidth).toInt() - 2
    }
}
