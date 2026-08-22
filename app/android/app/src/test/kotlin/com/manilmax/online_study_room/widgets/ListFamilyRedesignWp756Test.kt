package com.manilmax.online_study_room.widgets

import com.manilmax.online_study_room.R
import java.nio.file.Files
import java.nio.file.Path
import kotlin.math.ceil
import kotlin.math.pow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * WP-756 — LISTE ailesi (kamp siralamasi · gorev listesi · siradaki alarm).
 *
 * Sozlesme: `docs/tasarim/widget-tasarim-sistemi.md`. Bu dosya o belgenin
 * SAYILARINI olcer, belgeye guvenmez: kontrast oranlari burada WCAG 2.1 bagil
 * parlaklik formuluyle YENIDEN hesaplanir, kademe aritmetigi `widgetMaxSp` ve
 * `taskWidgetRowCapacity` uzerinden YENIDEN kurulur.
 *
 * Iddia kumeleri bilerek ayrildi; her biri AYRI bir sabotajla duser:
 *   A) Sifir-gorsel kusurunun nobetcisi — bir `ImageView`i sil, yalniz A duser.
 *   B) K1 cekirdegi — `leaderboardCoreRank`i kirp, yalniz B duser.
 *   C) Alarm widget'inin uc kusuru — kok id'yi sil, yalniz C duser.
 *   D) Kademe aritmetigi — `TASK_DIVIDER_BLOCK_DP`yi buyut, yalniz D duser.
 *   E) Dokunma hedefleri.
 *   F) Rozet kontrasti — layout rengini `accent`e dondur, yalniz F duser.
 */
class ListFamilyRedesignWp756Test {

    private fun read(relative: String): String =
        String(Files.readAllBytes(Path.of(relative)), Charsets.UTF_8)

    private fun stripComments(xml: String): String =
        Regex("(?s)<!--.*?-->").replace(xml, "")

    private fun layout(name: String): String = read("src/main/res/layout/$name.xml")

    private fun info(name: String): String = read("src/main/res/xml/${name}_info.xml")

    private fun provider(name: String): String =
        read("src/main/kotlin/com/manilmax/online_study_room/widgets/$name.kt")

    /** Yorumlari eler: KDoc'ta ANLATILAN bir sey KOSAN kod sanilmasin (WP-640). */
    private fun stripKotlinComments(src: String): String =
        Regex("""(?s)/\*.*?\*/""").replace(src, "")
            .lines()
            .filterNot { it.trimStart().startsWith("//") }
            .joinToString("\n")

    private val layoutNames = listOf(
        "odak_leaderboard_widget",
        "odak_task_widget",
        "odak_alarm_widget",
    )

    /** `android:ad="deger"` -> `deger`. Yorumlar elenir (WP-640 tuzagi). */
    private fun attr(xml: String, name: String): String? =
        Regex("""android:$name="([^"]*)"""").find(stripComments(xml))?.groupValues?.get(1)

    private fun dp(xml: String, name: String): Int =
        attr(xml, name)!!.removeSuffix("dp").toInt()

    /** `android:id="@+id/<id>"` tasiyan elemanin acilis etiketi. */
    private fun element(xml: String, id: String): String {
        val clean = stripComments(xml)
        val marker = clean.indexOf("@+id/$id")
        assertTrue("$id duzende yok", marker > 0)
        val start = clean.lastIndexOf('<', marker)
        val end = clean.indexOf('>', marker)
        return clean.substring(start, end)
    }

    /** Birlesik yatay katsayi `k` = textScaleX x yazitipi daralmasi (§3.4). */
    private val k = WIDGET_TEXT_SCALE_X_MIN * WIDGET_CONDENSED_ADVANCE

    // =======================================================================
    // A) Sifir-gorsel kusurunun nobetcisi (§0)
    //
    // Olculen "once": dokuz duzende SIFIR `ImageView` vardi; butun gorsel yuk
    // `TextView`daydi. Sahibin "sadece yazi, guzel degil" cumlesinin sayisal
    // karsiligi budur.
    //
    // SABOTAJ: bir duzenden `<ImageView`i sil -> yalniz bu kume duser.
    // =======================================================================

    @Test
    fun uc_duzen_de_gercek_bir_gorsel_tasir() {
        layoutNames.forEach { name ->
            val xml = stripComments(layout(name))
            val count = Regex("<ImageView").findAll(xml).count()
            assertTrue("$name hala sifir ImageView tasiyor", count >= 1)
            // Ayrac duz `View` OLAMAZ: RemoteViews'in izin listesinde yok.
            assertTrue(
                "$name duz `View` kullaniyor - RemoteViews bunu cizmez",
                !Regex("""<View[\s/>]""").containsMatchIn(xml),
            )
        }
    }

    @Test
    fun duzenler_yalniz_yeni_paleti_kullanir_ham_hex_YOK() {
        layoutNames.forEach { name ->
            val xml = stripComments(layout(name))
            assertTrue(
                "$name ham hex renk tasiyor: ikinci bir gorsel dil",
                !Regex("#[0-9A-Fa-f]{6}").containsMatchIn(xml),
            )
            val tokens = Regex("""@color/(\w+)""").findAll(xml).map { it.groupValues[1] }.toSet()
            assertTrue("$name hicbir renk simgesi kullanmiyor", tokens.isNotEmpty())
            tokens.forEach { token ->
                assertTrue(
                    "$name eski/olu simge kullaniyor: $token (yeni palet `widget_ember_*`)",
                    token.startsWith("widget_ember_"),
                )
            }
        }
    }

    @Test
    fun ayrac_paylasilan_cizimdir_ve_uc_duzende_de_var() {
        listOf(
            "odak_leaderboard_widget" to "leaderboard_widget_divider",
            "odak_task_widget" to "task_widget_divider",
            "odak_alarm_widget" to "alarm_widget_divider",
        ).forEach { (name, id) ->
            val el = element(layout(name), id)
            assertTrue("$id `ImageView` degil", el.startsWith("<ImageView"))
            assertTrue("$id ortak ayrac cizimini kullanmiyor", el.contains("@drawable/widget_divider"))
            assertEquals(
                "$id kalinligi paylasilan dilden gelmiyor",
                "@dimen/widget_design_divider",
                Regex("""android:layout_height="([^"]*)"""").find(el)?.groupValues?.get(1),
            )
        }
    }

    // =======================================================================
    // B) K1 cekirdegi — her widget'in TAM OLARAK bir cekirdegi vardir ve
    //    K1'de tek basina kalir. Sayi cekirdegi EN FAZLA 3 karakter (§1.4).
    //
    // SABOTAJ: `leaderboardCoreRank`in `99+` dalini kaldir -> yalniz B duser.
    // =======================================================================

    /** Once modelin kendisi: 3 karakter neden sinir, 5 karakter neden degil. */
    @Test
    fun uc_karakter_siniri_modelden_gelir() {
        assertEquals(21f, widgetMaxSp(40, 2, WIDGET_LIST_CORE_MAX_CHARS, k))
        assertTrue(
            "3 karakterlik cekirdek 40dp kutuya sigmiyor",
            WIDGET_LIST_CORE_SP <= widgetMaxSp(40, 2, WIDGET_LIST_CORE_MAX_CHARS, k),
        )
        assertTrue(
            "5 karakterlik bir cekirdek kahraman sayi sayilamaz",
            widgetMaxSp(40, 2, WIDGET_ALARM_TIME_CHARS, k) < WIDGET_LIST_CORE_SP,
        )
        assertTrue(WIDGET_LIST_CORE_SP >= WIDGET_MIN_TEXT_SP)
        assertTrue(WIDGET_LIST_CORE_HINT_SP >= WIDGET_MIN_TEXT_SP)
    }

    @Test
    fun siralama_cekirdegi_kullanicinin_sirasidir_ve_UC_karakteri_asmaz() {
        listOf("#1", "#3", "#9", "#12", "#99", "#100", "#4213", "#7 · 2sa 45dk")
            .forEach { raw ->
                val core = leaderboardCoreRank(raw)
                assertTrue("$raw cozulemedi", core != null)
                assertTrue(
                    "cekirdek 3 karakteri asti: $raw -> $core",
                    core!!.length <= WIDGET_LIST_CORE_MAX_CHARS,
                )
            }
        assertEquals("#3", leaderboardCoreRank("#3"))
        assertEquals("#99", leaderboardCoreRank("#99"))
        assertEquals("99+", leaderboardCoreRank("#100"))
        // Sirasi yoksa cekirdek GLIFe duser; `0` ya da bos metin cizilmez.
        assertNull(leaderboardCoreRank("Siralama olusunca burada gorunur"))
        assertNull(leaderboardCoreRank(""))
        assertNull(leaderboardCoreRank("#0"))
    }

    @Test
    fun gorev_cekirdegi_kalan_sayisidir_ve_UC_karakteri_asmaz() {
        fun model(vararg done: Boolean) = TaskWidgetModel(
            "",
            "",
            done.mapIndexed { i, d -> TaskWidgetItem("t$i", "gorev $i", d) },
        )
        assertNull("hic gorev yokken sayi degil GLIF cizilir", taskCoreCount(model()))
        assertEquals("3", taskCoreCount(model(false, false, false)))
        assertEquals("1", taskCoreCount(model(true, true, false)))
        // Hepsi bittiyse `0` bir BASARIdir ve gosterilir; "hic yok"tan ayridir.
        assertEquals("0", taskCoreCount(model(true, true)))
        val many = TaskWidgetModel(
            "",
            "",
            (0 until 150).map { TaskWidgetItem("t$it", "gorev", false) },
        )
        assertEquals("99+", taskCoreCount(many))
        assertTrue(taskCoreCount(many)!!.length <= WIDGET_LIST_CORE_MAX_CHARS)
    }

    @Test
    fun alarm_cekirdegi_GLIFtir_cunku_saat_bes_karakterdir() {
        assertEquals(WIDGET_ALARM_TIME_CHARS, "07:30".length)
        assertTrue(
            "5 karakterlik saat 40dp kutuda 11sp tabaninin hemen ustune duser",
            widgetMaxSp(40, 2, WIDGET_ALARM_TIME_CHARS, k) < WIDGET_LIST_CORE_SP,
        )
        assertTrue("K1'de saat cizilmemeli", !alarmTimeVisible(ListWidgetTier.K1))
        assertTrue("K1'de can glifi cizilmeli", alarmIconVisible(ListWidgetTier.K1))
        // K2 butcesi 0 grafiktir: orada glif duser, sayi kalir.
        assertTrue(alarmTimeVisible(ListWidgetTier.K2))
        assertTrue(!alarmIconVisible(ListWidgetTier.K2))
    }

    // =======================================================================
    // C) Alarm widget'inin UC KUSURU (bugunku halin nobetcisi)
    //
    // SABOTAJ: layout'tan `alarm_widget_root` id'sini sil -> yalniz C duser.
    // =======================================================================

    @Test
    fun alarm_kokunun_id_si_VARDIR_ve_derin_baglanti_ona_baglidir() {
        val xml = stripComments(layout("odak_alarm_widget"))
        assertTrue(
            "alarm kokunun id'si yok: RemoteViews'ta id'siz kokun tiklama hedefi OLAMAZ",
            xml.contains("@+id/alarm_widget_root"),
        )
        // Kok GERCEKTEN kok mu: dosyadaki ilk elemanin id'si olmali.
        val firstTagEnd = xml.indexOf('>', xml.indexOf("<LinearLayout"))
        assertTrue(
            "id kokte degil, ic bir elemanda",
            xml.substring(0, firstTagEnd).contains("@+id/alarm_widget_root"),
        )
        val src = provider("AlarmWidget")
        assertTrue(
            "alarm hicbir yere acilmiyor",
            src.contains("WidgetDeepLink.ROUTE_CLOCK"),
        )
        assertTrue(
            "derin baglanti koke bagli degil",
            Regex("""setOnClickPendingIntent\(\s*R\.id\.alarm_widget_root""")
                .containsMatchIn(src),
        )
    }

    @Test
    fun alarm_saglayicisi_onAppWidgetOptionsChanged_i_gecersiz_kilar() {
        val src = provider("AlarmWidget")
        val start = src.indexOf("class AlarmWidgetProvider ")
        assertTrue("AlarmWidgetProvider bulunamadi", start > -1)
        val body = src.substring(start)
        assertTrue(
            "kullanici alarm widget'ini boyutlandirdiginda ekranda hicbir sey degismiyor",
            body.contains("override fun onAppWidgetOptionsChanged("),
        )
        assertTrue("boyut bilgisi hicbir gorunume donusmuyor", body.contains("alarmTier("))
    }

    @Test
    fun alarm_WidgetSizeSpec_girdisi_var_ve_gercekten_siniflandiriyor() {
        // Beyan degil DAVRANIS olculur: spec gercek olculeri sinifa cevirmeli.
        assertEquals(
            WidgetSizeClass(WidgetWidthClass.NARROW, WidgetHeightClass.SHORT),
            widgetSizeClass(ALARM_WIDGET_SIZE_SPEC, 110, 40),
        )
        assertEquals(
            WidgetSizeClass(WidgetWidthClass.MEDIUM, WidgetHeightClass.MEDIUM),
            widgetSizeClass(ALARM_WIDGET_SIZE_SPEC, 180, 110),
        )
        assertEquals(
            WidgetSizeClass(WidgetWidthClass.WIDE, WidgetHeightClass.TALL),
            widgetSizeClass(ALARM_WIDGET_SIZE_SPEC, 250, 180),
        )
        // Launcher bos secenek paketi gonderdiginde varsayilana duser (0 degil).
        assertEquals(
            widgetSizeClass(ALARM_WIDGET_SIZE_SPEC, 110, 40),
            widgetSizeClass(ALARM_WIDGET_SIZE_SPEC, 0, 0),
        )
    }

    @Test
    fun alarm_info_xml_i_boyut_sozlesmesi_tasir_ve_Kotlin_ile_ayni_sayilari_soyler() {
        val xml = info("odak_alarm_widget")
        listOf("targetCellWidth", "targetCellHeight", "minResizeWidth", "minResizeHeight",
            "maxResizeWidth", "maxResizeHeight").forEach {
            assertTrue("alarm $it beyan etmiyor", attr(xml, it) != null)
        }
        // Android 12 oncesi/sonrasi ayni varsayilani soylemeli: 70n - 30.
        assertEquals(dp(xml, "minWidth"), 70 * attr(xml, "targetCellWidth")!!.toInt() - 30)
        assertEquals(dp(xml, "minHeight"), 70 * attr(xml, "targetCellHeight")!!.toInt() - 30)
        assertEquals(WIDGET_ALARM_DEFAULT_WIDTH_DP, dp(xml, "minWidth"))
        assertEquals(WIDGET_ALARM_DEFAULT_HEIGHT_DP, dp(xml, "minHeight"))
        assertTrue(WIDGET_ALARM_MEDIUM_WIDTH_DP > dp(xml, "minResizeWidth"))
        assertTrue(WIDGET_ALARM_WIDE_WIDTH_DP > WIDGET_ALARM_MEDIUM_WIDTH_DP)
        assertTrue(WIDGET_ALARM_WIDE_WIDTH_DP <= dp(xml, "maxResizeWidth"))
        assertTrue(WIDGET_ALARM_MEDIUM_HEIGHT_DP > dp(xml, "minResizeHeight"))
        assertTrue(WIDGET_ALARM_TALL_HEIGHT_DP > WIDGET_ALARM_MEDIUM_HEIGHT_DP)
        assertTrue(WIDGET_ALARM_TALL_HEIGHT_DP <= dp(xml, "maxResizeHeight"))
        // Alt sinir 1x1'e inmeli: cekirdek orada tek basina kalabiliyor.
        assertEquals(40, dp(xml, "minResizeWidth"))
        assertEquals(40, dp(xml, "minResizeHeight"))
    }

    @Test
    fun alarm_ayristirmasi_MiniJson_ile_yapilir_ve_JVM_de_olculebilir() {
        val src = stripKotlinComments(provider("AlarmWidget"))
        assertTrue(
            "org.json JVM biriminde `not mocked` ile patlar; ayristirma test edilemez kalirdi",
            !src.contains("org.json"),
        )
        assertTrue(src.contains("MiniJson.parse("))

        val now = 1_000_000L
        val raw = """[
          {"triggerAtMs": 900000, "hour": 6, "minute": 5, "label": "gecmis"},
          {"triggerAtMs": 3000000, "hour": 9, "minute": 0, "label": "gec"},
          {"triggerAtMs": 2000000, "hour": 7, "minute": 30, "label": "Sabah"}
        ]"""
        val next = parseNextAlarm(raw, now, "Alarm")
        assertEquals("07:30", next?.timeText)
        assertEquals("Sabah", next?.label)
        // Etiketi bos olan kayit yedek etikete duser.
        assertEquals(
            "Alarm",
            parseNextAlarm("""[{"triggerAtMs": 2000000, "hour": 8, "minute": 0, "label": ""}]""", now, "Alarm")?.label,
        )
        // Bozuk/bos/gecmis ayna widget'i BOS duruma dusurur, uygulamayi degil.
        assertNull(parseNextAlarm("{bozuk", now, "Alarm"))
        assertNull(parseNextAlarm(null, now, "Alarm"))
        assertNull(parseNextAlarm("[]", now, "Alarm"))
        assertNull(parseNextAlarm("""[{"triggerAtMs": 900000, "hour": 6, "minute": 5}]""", now, "Alarm"))
        assertNull(parseNextAlarm("""[{"triggerAtMs": 2000000, "hour": 44, "minute": 5}]""", now, "Alarm"))
    }

    // =======================================================================
    // D) Kademe aritmetigi — satir gorunurlugu KUTUDAN turer, kapasite asiminda
    //    satir CIZILMEZ.
    //
    // SABOTAJ: `TASK_DIVIDER_BLOCK_DP`yi 3'ten 12'ye cikar (kapasite hesabina
    // girmeseydi de fark etmezdi) -> yalniz bu kume duser.
    // =======================================================================

    /** Launcher hucre olcusu `70n - 30`: pratikte yalniz bu degerler olusur. */
    private val cellDps = listOf(40, 110, 180, 250)

    @Test
    fun kademe_merdiveni_gercek_hucre_olcularini_kapsar() {
        assertEquals(ListWidgetTier.K1, leaderboardTier(40, 40))
        assertEquals(ListWidgetTier.K1, leaderboardTier(40, 250))
        assertEquals(ListWidgetTier.K2, leaderboardTier(180, 40))
        assertEquals(ListWidgetTier.K3, leaderboardTier(180, 110))
        assertEquals(ListWidgetTier.K4, leaderboardTier(180, 180))

        assertEquals(ListWidgetTier.K1, taskTier(40, 110))
        assertEquals(ListWidgetTier.K2, taskTier(180, 40))
        assertEquals(ListWidgetTier.K3, taskTier(180, 110))
        assertEquals(ListWidgetTier.K4, taskTier(180, 180))

        assertEquals(ListWidgetTier.K1, alarmTier(40, 40))
        assertEquals(ListWidgetTier.K2, alarmTier(110, 40))
        assertEquals(ListWidgetTier.K3, alarmTier(180, 110))
        assertEquals(ListWidgetTier.K4, alarmTier(180, 180))

        // §2.6: K1/K2 dar yaricapli zemini kullanir; 20dp yaricap 40dp'lik bir
        // kutuda koselerin TAMAMINI yer ve kart hapa doner.
        listOf(ListWidgetTier.K1, ListWidgetTier.K2).forEach {
            assertEquals(R.drawable.widget_card_bg_tight, listCardBackground(it))
        }
        listOf(ListWidgetTier.K3, ListWidgetTier.K4).forEach {
            assertEquals(R.drawable.widget_card_bg, listCardBackground(it))
        }
    }

    @Test
    fun gorev_satirlari_KUTUYA_gore_cizilir_ayrac_dahil() {
        val rowHeight = dp(element(layout("odak_task_widget"), "task_widget_row_0"), "minHeight")
        assertEquals("Kotlin satir yuksekligi layout ile ayristi", rowHeight, TASK_ROW_HEIGHT_DP)

        for (box in cellDps) {
            val tier = taskTier(180, box)
            val listVisible = taskListVisible(tier)
            val heightClass = widgetSizeClass(TASK_WIDGET_SIZE_SPEC, 180, box).height
            val titleVisible = listVisible && taskWidgetTitleVisible(heightClass)
            val divider = if (tier == ListWidgetTier.K4) TASK_DIVIDER_BLOCK_DP else 0
            val padding =
                if (listVisible) widgetRootPaddingDp(12, heightClass) else listCardPaddingDp(tier)
            val capacity =
                if (listVisible) taskWidgetRowCapacity(box, titleVisible, padding, divider) else 0
            val drawn = 2 * padding +
                (if (titleVisible) TASK_TITLE_HEIGHT_DP else 0) +
                divider +
                capacity * TASK_ROW_HEIGHT_DP
            assertTrue(
                "$box dp kutuda cizilen kart $drawn dp - TASIYOR (kademe $tier)",
                drawn <= box,
            )
            if (!listVisible) {
                assertEquals("K1/K2'de satir cizilmemeli", 0, capacity)
            }
        }
    }

    @Test
    fun kapasiteyi_asan_satir_CIZILMEZ() {
        val model = TaskWidgetModel(
            "Bugun",
            "",
            (0 until TASK_WIDGET_MAX_ROWS).map { TaskWidgetItem("t$it", "gorev $it", false) },
        )
        // 110dp kutu / baslik acik / dolgu 13 -> (110 - 26 - 20) / 32 = 2 satir.
        assertEquals(2, taskWidgetVisibleItems(model, 110, true, 13).size)
        // Ayni kutu, K4 ayraci eklenirse bir satir DUSER (2 -> 1): ayrac
        // kapasiteye GIRER. Girmeseydi kart 3dp tasar ve son satir kirpilirdi;
        // WP-719'un tam olarak duzelttigi kusurun geri gelmesi olurdu.
        assertEquals(1, taskWidgetVisibleItems(model, 110, true, 13, TASK_DIVIDER_BLOCK_DP).size)
        assertEquals(4, taskWidgetVisibleItems(model, 180, true, 14, TASK_DIVIDER_BLOCK_DP).size)
        // 🔴 K2: ham kapasite formulu 40dp kutuda "1 satir sigar" der, ama
        // saglayici o kademede liste yerine CEKIRDEK seridini cizer -
        // §1.5: K1/K2'de ikinci bir tiklanabilir alan yasaktir, yani
        // isaretlenebilir satir orada olamaz. Iki sayi bilerek ayri.
        assertEquals(1, taskWidgetRowCapacity(40, false, 4))
        assertTrue(
            "K2'de satir cizilirse kok disinda ikinci bir hedef acilir",
            !taskListVisible(taskTier(180, 40)),
        )
    }

    @Test
    fun siralama_karti_her_kademede_kutuya_SIGAR() {
        val lb = layout("odak_leaderboard_widget")
        val rowHeight = dp(element(lb, "leaderboard_widget_row_container_1"), "minHeight")
        val firstGap = dp(element(lb, "leaderboard_widget_row_container_1"), "layout_marginTop")
        val nextGap = dp(element(lb, "leaderboard_widget_row_container_2"), "layout_marginTop")
        val dividerGap = dp(element(lb, "leaderboard_widget_divider"), "layout_marginTop")
        val iconDp = dp(element(lb, "leaderboard_widget_icon"), "layout_width")
        val coreDp = dp(element(lb, "leaderboard_widget_core"), "minHeight")

        listOf(40 to 40, 40 to 250, 180 to 40, 180 to 110, 250 to 110, 180 to 150, 320 to 150)
            .forEach { (w, h) ->
                val tier = leaderboardTier(w, h)
                val padding = listCardPaddingDp(tier)
                val widthClass = widgetSizeClass(WidgetSizeSpecs.leaderboard, w, h).width
                val required = if (leaderboardListVisible(tier)) {
                    val titleSp = WidgetTypography.leaderboardTitle.of(widthClass)
                    val header = maxOf(ceil(titleSp * 1.30).toInt(), iconDp)
                    val divider = if (tier == ListWidgetTier.K4) dividerGap + 1 else 0
                    val rows = if (tier == ListWidgetTier.K4) 3 else 2
                    2 * padding + header + divider + firstGap +
                        rows * rowHeight + (rows - 1) * nextGap
                } else {
                    2 * padding + coreDp
                }
                assertTrue(
                    "${w}x${h} ($tier): kart $required dp ister, kutu $h dp",
                    required <= h,
                )
            }
    }

    // =======================================================================
    // E) Dokunma hedefleri (§1.5)
    //
    // 🔴 OLCULEN ACIK: gorev SATIRI 32dp'dir (`TASK_ROW_HEIGHT_DP`), Material
    // asgarisi 48dp'dir. Bu WP'de yukseltilemedi: satir yuksekligi kapasite
    // modelinin birimidir ve `TaskWidgetSizeWp719Test` +
    // `task_widget_wp719_test.dart` onu 32'ye civiliyor (56dp kutuda "en az bir
    // satir" iddiasi 48dp satirla SIFIR verir). Ayri bir WP'nin isi; LIDERE
    // BILDIRILDI. Buradaki test o sayiyi DONDURMAZ - yukseltilirse yesil kalir.
    // =======================================================================

    @Test
    fun dokunma_hedefleri_kok_kuraline_uyar() {
        assertEquals(48, WIDGET_MIN_TOUCH_TARGET_DP)
        // (a) Uc widgetin de en dis katmani kutunun TAMAMIDIR; K1/K2'de tek
        //     hedef odur ve launcher hucreyi ~70-85dp cizer.
        listOf(
            "odak_leaderboard_widget" to "leaderboard_widget_root",
            "odak_task_widget" to "task_widget_frame",
            "odak_alarm_widget" to "alarm_widget_root",
        ).forEach { (name, id) ->
            val el = element(layout(name), id)
            assertEquals("$id kutunun tamamini kaplamiyor", "match_parent", attr(el, "layout_width"))
            assertEquals("$id kutunun tamamini kaplamiyor", "match_parent", attr(el, "layout_height"))
        }
        // (b) Siralama ve alarmda TEK eylem vardir: butun hedefler koktur.
        //     Ikinci bir tiklanabilir alan K1/K2'de yasaktir (§1.5) ve bu iki
        //     widgetta hicbir kademede acilmaz.
        mapOf(
            "LeaderboardWidget" to "leaderboard_widget_root",
            "AlarmWidget" to "alarm_widget_root",
        ).forEach { (file, rootId) ->
            val targets = Regex("""setOnClickPendingIntent\(\s*R\.id\.(\w+)""")
                .findAll(provider(file))
                .map { it.groupValues[1] }
                .toSet()
            assertEquals("$file kok disinda bir hedef bagliyor", setOf(rootId), targets)
        }
        // (c) Gorev widgetinda IKI eylem var (ac / isaretle). Gezinme hedefleri
        //     ayni eyleme baglidir, yani bitisik TEK alan olustururlar.
        val taskSrc = provider("TaskWidget")
        val openTargets = Regex("""setOnClickPendingIntent\(R\.id\.(\w+), openTasks\)""")
            .findAll(taskSrc)
            .map { it.groupValues[1] }
            .toSet()
        assertEquals(
            setOf(
                "task_widget_title",
                "task_widget_empty",
                "task_widget_root",
                "task_widget_frame",
            ),
            openTargets,
        )
        assertTrue("ana ekrandan isaretleme yolu koptu", taskSrc.contains("togglePendingIntent("))
        // Isaretleme hedefi SATIRDIR ve iki tarafta ayni sayidir.
        assertEquals(
            TASK_ROW_HEIGHT_DP,
            dp(element(layout("odak_task_widget"), "task_widget_row_0"), "minHeight"),
        )
    }

    // =======================================================================
    // F) Rozet kontrasti — KENDI hesabimla, belgeye guvenerek degil.
    //
    // WCAG 2.1 bagil parlaklik: L = 0.2126R + 0.7152G + 0.0722B (sRGB
    // dogrusallastirilmis). Oranlar burada YENIDEN hesaplanir.
    //
    // SABOTAJ: `leaderboard_widget_rank_2`nin rengini `widget_ember_flame`e
    // dondur -> yalniz bu kume duser.
    // =======================================================================

    private val paletteFile = "src/main/res/values/widget_design.xml"

    private fun palette(): Map<String, String> =
        Regex("""<color name="([^"]+)">([^<]+)</color>""")
            .findAll(stripComments(read(paletteFile)))
            .associate { it.groupValues[1] to it.groupValues[2].trim() }

    private fun hex(name: String): String {
        val map = palette()
        var value = map[name] ?: error("$name paletten dusmus")
        repeat(4) { if (value.startsWith("@color/")) value = map[value.removePrefix("@color/")]!! }
        assertTrue("$name sabit #RRGGBB degil: $value", Regex("^#[0-9A-Fa-f]{6}$").matches(value))
        return value
    }

    private fun luminance(color: String): Double {
        val v = color.removePrefix("#")
        fun channel(offset: Int): Double {
            val raw = v.substring(offset, offset + 2).toInt(16) / 255.0
            return if (raw <= 0.03928) raw / 12.92 else ((raw + 0.055) / 1.055).pow(2.4)
        }
        return 0.2126 * channel(0) + 0.7152 * channel(2) + 0.0722 * channel(4)
    }

    private fun contrast(a: String, b: String): Double {
        val la = luminance(a)
        val lb = luminance(b)
        return (maxOf(la, lb) + 0.05) / (minOf(la, lb) + 0.05)
    }

    /** Bir sekil ciziminin `<solid>` / `<stroke>` renk simgesi. */
    private fun shapeColor(drawable: String, tag: String): String {
        val xml = stripComments(read("src/main/res/drawable/$drawable.xml"))
        val block = Regex("""(?s)<$tag[^>]*>""").find(xml)?.value ?: error("$drawable: $tag yok")
        return Regex("""@color/(\w+)""").find(block)!!.groupValues[1]
    }

    @Test
    fun ikinci_ve_ucuncu_sira_rozet_metni_ink_dim_dir_ve_AA_gecer() {
        val lb = layout("odak_leaderboard_widget")
        listOf(2, 3).forEach { position ->
            val el = element(lb, "leaderboard_widget_rank_$position")
            assertEquals(
                "$position. sira rozet metni `ink_dim` degil",
                "@color/widget_ember_ink_dim",
                attr(el, "textColor"),
            )
            assertEquals(
                "$position. sira rozet zemini yanlis",
                "@drawable/widget_rank_other_bg",
                attr(el, "background"),
            )
        }
        val night = hex("widget_ember_night")
        val inkDim = hex("widget_ember_ink_dim")
        val flame = hex("widget_ember_flame")
        assertEquals("rozet zemini `night` dolgu degil", "widget_ember_night", shapeColor("widget_rank_other_bg", "solid"))

        val chosen = contrast(inkDim, night)
        assertTrue("2./3. sira rakami okunmuyor: $chosen", chosen >= 4.5)
        // 🔴 Karar KONTRAST degil HIYERARSI: `flame` daha yuksek oran verirdi
        // ($alternatif) ama bu ailede `flame` "SEN" demek. Ikinci/ucuncu siranin
        // rakamlari da flame olsaydi kisisel vurgu bir sinyal olmaktan cikardi.
        val alternatif = contrast(flame, night)
        assertTrue(
            "secilen ton alternatiften parlak: hiyerarsi gerekcesi dustu " +
                "(ink_dim $chosen vs flame $alternatif)",
            chosen < alternatif,
        )
        // `ash` hicbir duzende METIN rengi olamaz (§2.3).
        layoutNames.forEach { name ->
            assertTrue(
                "$name `ash`i metin rengi yapiyor (karta 3.24:1 - metin esigi degil)",
                !Regex("""android:textColor="@color/widget_ember_ash"""")
                    .containsMatchIn(stripComments(layout(name))),
            )
        }
    }

    @Test
    fun birinci_sira_ve_SEN_rozetleri_dogru_zemin_metin_ciftini_kullanir() {
        val night = hex("widget_ember_night")
        val glow = hex("widget_ember_glow")
        val flame = hex("widget_ember_flame")

        // 1. sira: `glow` dolgu + `night` metin. `ink` on `glow` 1.38:1 olurdu.
        assertEquals("widget_ember_glow", shapeColor("widget_rank_first_bg", "solid"))
        assertEquals(
            "@color/widget_ember_night",
            attr(element(layout("odak_leaderboard_widget"), "leaderboard_widget_rank_1"), "textColor"),
        )
        assertTrue(
            "1. sira rakami okunmuyor: ${contrast(night, glow)}",
            contrast(night, glow) >= 4.5,
        )

        // "SEN" rozeti: `night` dolgu + `flame` halka; metin `flame`.
        assertEquals("widget_ember_night", shapeColor("widget_rank_self_bg", "solid"))
        assertEquals("widget_ember_flame", shapeColor("widget_rank_self_bg", "stroke"))
        assertTrue(
            "SEN halkasi grafik esigini (3:1) gecmiyor: ${contrast(flame, night)}",
            contrast(flame, night) >= 3.0,
        )
        assertTrue(
            "SEN rakami okunmuyor: ${contrast(flame, night)}",
            contrast(flame, night) >= 4.5,
        )
        // Saglayici uc zemini de kullanmali; biri baglanmazsa rozet dili olur.
        val src = provider("LeaderboardWidget")
        listOf("widget_rank_first_bg", "widget_rank_self_bg", "widget_rank_other_bg").forEach {
            assertTrue("$it hicbir yerde surulmuyor", src.contains("R.drawable.$it"))
        }
        assertTrue("kendi satirin isaretlenmiyor", src.contains("R.string.widget_you"))
    }
}
