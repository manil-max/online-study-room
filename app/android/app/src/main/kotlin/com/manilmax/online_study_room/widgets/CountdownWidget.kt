package com.manilmax.online_study_room.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import com.manilmax.online_study_room.R
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * WP-695: sınav geri sayımı ana ekran widget'ı.
 *
 * ## Veri kaynağı
 * Widget, uygulamanın **kendi** yazdığı `SharedPreferences` kaydından okur:
 * `FlutterSharedPreferences` / [COUNTDOWN_PREFS_KEY]. Bu, `dday_prefs.dart`
 * içindeki `kExamListKey`in `flutter.` önekli hâlidir; Flutter
 * `shared_preferences` anahtarları diske hep bu önekle yazar.
 *
 * `home_widget`in `widgetData` sözlüğü **bilinçli olarak kullanılmadı**:
 * WP-558 yayında `widgetData` okuyan sağlayıcı kalmadığı için her anlık
 * görüntüde giden 17 platform kanalı turunu kapattı. Geri sayımı oraya bağlamak
 * o turu geri açardı ve widget yalnız uygulama en az bir kez çalıştıktan sonra
 * dolardı. Prefs'ten okumak, alarm widget'ının (`AlarmWidgetProvider`) zaten
 * kullandığı desendir.
 *
 * WP-694 aynı veriyi sunucuya taşıyor. Sunucu **kaynak** olsa bile cihazdaki bu
 * kayıt yerel ayna olarak kalır; ayrışırsa Dart↔Kotlin sözleşme testi
 * (`countdown_widget_wp695_test.dart`) kırmızı düşer.
 *
 * ## Native tuzaklar
 * - Prefs'ten **sayı okunmaz**. Dart `setInt` diske `putLong` yazar; native
 *   `getInt` `ClassCastException` fırlatır ve bu bir `BroadcastReceiver`
 *   içinde uygulama **sürecini** öldürür (v58 sahasında geri sayım/pomodoro
 *   çökmesi buydu). Buradaki tek okuma `getString`tir; gün sayısı metinden
 *   hesaplanır. `CountdownPrefsTypeContractTest` bunu ölçer.
 * - `onUpdate` gövdesi baştan sona `runCatching` içindedir: bozuk kayıt
 *   widget'ı boş duruma düşürür, uygulamayı değil.
 */
internal const val COUNTDOWN_PREFS_NAME = "FlutterSharedPreferences"
internal const val COUNTDOWN_PREFS_KEY = "flutter.dday.exams_v2"

/** Ürünün tek takvim sınırı Europe/Istanbul; 2016'dan beri sabit UTC+03:00. */
internal const val ISTANBUL_OFFSET_MS = 3L * 60L * 60L * 1000L
private const val MS_PER_DAY = 86_400_000L

/** Boş/geçmiş durumda büyük alanda çizilen işaret — asla negatif sayı değil. */
internal const val COUNTDOWN_DASH = "—"

internal enum class CountdownState { EMPTY, FUTURE, TODAY, PAST }

/**
 * Widget'ın **çizeceği** değerler. [daysText] doğrudan büyük `TextView`e
 * gider; testin ölçtüğü şey kullanıcının gördüğü metindir.
 */
internal data class CountdownWidgetModel(
    val state: CountdownState,
    val name: String,
    val days: Long,
    val daysText: String,
)

/** Gün anahtarı (`y-m-d`) → epoch günü. `java.time` gerektirmez. */
internal fun epochDayFromCivil(year: Int, month: Int, day: Int): Long {
    val y = if (month <= 2) year - 1L else year.toLong()
    val era = (if (y >= 0) y else y - 399) / 400
    val yoe = y - era * 400
    val mp = if (month > 2) month - 3 else month + 9
    val doy = (153 * mp + 2) / 5 + day - 1
    val doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
    return era * 146_097L + doe - 719_468L
}

internal fun istanbulEpochDay(nowMs: Long): Long =
    Math.floorDiv(nowMs + ISTANBUL_OFFSET_MS, MS_PER_DAY)

/** `2026-09-01` → epoch günü; biçim bozuksa `null`. */
internal fun parseExamDay(raw: String?): Long? {
    val value = raw?.trim() ?: return null
    if (value.length < 10) return null
    if (value[4] != '-' || value[7] != '-') return null
    val year = value.substring(0, 4).toIntOrNull() ?: return null
    val month = value.substring(5, 7).toIntOrNull() ?: return null
    val day = value.substring(8, 10).toIntOrNull() ?: return null
    if (month !in 1..12 || day !in 1..31) return null
    return epochDayFromCivil(year, month, day)
}

/**
 * `dday_prefs.dart` `examDateProvider` ile **aynı** seçim: öne çıkarılan kayıt
 * varsa o, yoksa listenin ilki. Farklı seçmek, kullanıcının uygulamada gördüğü
 * sınavla widget'ta gördüğünü ayrıştırırdı.
 */
internal fun countdownWidgetModel(rawJson: String?, nowMs: Long): CountdownWidgetModel =
    countdownWidgetList(rawJson, nowMs).head

/**
 * WP-717: widget'in cizecegi **tum** kayitlar.
 *
 * Beta testcisi: "sadece 1 sinavin geri sayimi gorunuyor; uygulamadaki gibi
 * 3'u de gorunse." Model o yuzden tek kayit degil, kartla ayni siradaki liste
 * uretir. [head] geriye donuk uyumu tasir: WP-695'in olctugu buyuk sayi hala
 * listenin ilk kaydidir.
 */
internal data class CountdownRow(
    val state: CountdownState,
    val name: String,
    val days: Long,
    val daysText: String,
)

internal data class CountdownWidgetList(
    val rows: List<CountdownRow>,
    /** One cikarilan kayit GERCEKTEN var mi (silinmis kimlik sayilmaz). */
    val hasPriority: Boolean,
) {
    val head: CountdownWidgetModel
        get() = rows.firstOrNull()?.let {
            CountdownWidgetModel(it.state, it.name, it.days, it.daysText)
        } ?: CountdownWidgetModel(CountdownState.EMPTY, "", 0L, COUNTDOWN_DASH)
}

internal fun countdownWidgetList(rawJson: String?, nowMs: Long): CountdownWidgetList {
    val empty = CountdownWidgetList(emptyList(), false)
    val root = MiniJson.parse(rawJson) as? Map<*, *> ?: return empty
    // WP-694 kaydin ustune `synced` / `deleted` listelerini ve her girdiye
    // `updatedAt` alanini ekledi. Ayristirici **tanimadigi alani yok sayar**;
    // ilerideki eklemeler widget'i sessizce oldurmesin diye bu bir iddiaya
    // baglidir (`unknown_fields_do_not_break_the_widget`).
    //
    // `deleted` silinmeyi bekleyen KIMLIKLERIN listesidir. Sunucuya gidene
    // kadar ayni kimlik `entries` icinde de durabilir; widget o kaydi
    // gostermemeli — kullanici uygulamada sildigi sinavi ana ekranda
    // gormeye devam ederdi.
    val deleted = (root["deleted"] as? List<*>).orEmpty()
        .mapNotNull { it as? String }
        .filter { it.isNotEmpty() }
        .toSet()
    val entries = (root["entries"] as? List<*>).orEmpty()
        .mapNotNull { it as? Map<*, *> }
        .filter { parseExamDay(it["day"] as? String) != null }
        .filterNot { (it["id"] as? String) in deleted }
    if (entries.isEmpty()) return empty
    val priorityId = (root["priority"] as? String)?.takeIf { it.isNotEmpty() }
    val featured = entries.firstOrNull { (it["id"] as? String) == priorityId }
    // Siralama `dday_card.dart` ile birebir: one cikarilan basa alinir,
    // digerleri kullanicinin kendi sirasinda kalir.
    val ordered =
        if (featured == null) entries else listOf(featured) + entries.filter { it !== featured }
    val today = istanbulEpochDay(nowMs)
    val rows = ordered.mapNotNull { entry ->
        val examDay = parseExamDay(entry["day"] as? String) ?: return@mapNotNull null
        val name = (entry["name"] as? String)?.trim().orEmpty()
        val diff = examDay - today
        when {
            diff > 0L -> CountdownRow(CountdownState.FUTURE, name, diff, diff.toString())
            diff == 0L -> CountdownRow(CountdownState.TODAY, name, 0L, "0")
            // 🔴 Geçmiş tarih negatif gün YAZMAZ ("-12 gün kaldı" bir hatadır).
            else -> CountdownRow(CountdownState.PAST, name, diff, COUNTDOWN_DASH)
        }
    }
    if (rows.isEmpty()) return empty
    return CountdownWidgetList(rows, featured != null)
}

// ---------------------------------------------------------------------------
// WP-717 — yerlesim kurallari (saf; JVM testi bunlari dogrudan olcer)
//
// Kural kaynagi uygulamadaki kart: `lib/features/home/widgets/dday_card.dart`
// `useHero = featured != null && (density != tight || others.length <= 1)`.
// Tek fark widget'a ozel: kayit TEK ise kahraman her zaman kullanilir — 2x2
// bir kutuyu tek satirlik kucuk yaziyla doldurmak alani ziyan ederdi.
// ---------------------------------------------------------------------------

/** Duzendeki statik satir sayisi; RemoteViews dinamik satir uretemez. */
internal const val COUNTDOWN_ROW_SLOTS = 3

/** Liste (kahramansiz) halde kac satir cizilir. */
internal fun countdownRowCapacity(height: WidgetHeightClass): Int = when (height) {
    WidgetHeightClass.SHORT -> 2
    WidgetHeightClass.MEDIUM -> COUNTDOWN_ROW_SLOTS
    WidgetHeightClass.TALL -> COUNTDOWN_ROW_SLOTS
}

/** Kahraman blogunun ALTINDA kac yardimci satira yer kalir. */
internal fun countdownHeroRowCapacity(height: WidgetHeightClass): Int = when (height) {
    WidgetHeightClass.SHORT -> 0
    WidgetHeightClass.MEDIUM -> 1
    WidgetHeightClass.TALL -> 2
}

internal fun countdownUsesHero(
    height: WidgetHeightClass,
    rowCount: Int,
    hasPriority: Boolean,
): Boolean = when {
    rowCount <= 0 -> false
    rowCount == 1 -> true
    !hasPriority -> false
    else -> height != WidgetHeightClass.SHORT || rowCount <= 2
}

internal fun countdownVisibleRowCount(
    height: WidgetHeightClass,
    rowCount: Int,
    hasPriority: Boolean,
): Int = if (countdownUsesHero(height, rowCount, hasPriority)) {
    minOf(rowCount - 1, countdownHeroRowCapacity(height), COUNTDOWN_ROW_SLOTS)
} else {
    minOf(rowCount, countdownRowCapacity(height), COUNTDOWN_ROW_SLOTS)
}

/**
 * Yayin doluluk kesiri. Kayitta baslangic tarihi YOKTUR, o yuzden olcek bir
 * ufuktur: bir yil. 365 gun ve otesi bos yay, sinav gunu tam dolu yay.
 * (Sahibin cihazindaki uc sinav — 76 / 312 / 313 gun — bu olcekte
 * %79 / %15 / %14 verir; ayni ufuk uc kaydi da ayirt edilebilir kilar.)
 */
internal const val COUNTDOWN_ARC_HORIZON_DAYS = 365L

internal fun countdownArcFraction(model: CountdownWidgetModel): Double = when (model.state) {
    CountdownState.TODAY -> 1.0
    CountdownState.FUTURE -> {
        val remaining = model.days.coerceIn(0L, COUNTDOWN_ARC_HORIZON_DAYS)
        (COUNTDOWN_ARC_HORIZON_DAYS - remaining).toDouble() / COUNTDOWN_ARC_HORIZON_DAYS
    }
    // Bos ya da gecmis kayitta gosterilecek ilerleme yoktur; yay 0 degil,
    // GIZLIdir (bkz. countdownArcVisible) — bos bir iz "veri var ama sifir"
    // gibi okunurdu.
    CountdownState.EMPTY, CountdownState.PAST -> 0.0
}

/** Kisa kutuda yaya yer yok; bos/gecmis durumda anlami yok. */
internal fun countdownArcVisible(height: WidgetHeightClass, state: CountdownState): Boolean =
    height != WidgetHeightClass.SHORT &&
        (state == CountdownState.FUTURE || state == CountdownState.TODAY)

/** Satirin sag ucundaki metin; uygulamadaki kartla ayni sozcukler. */
internal fun countdownRowValueText(
    row: CountdownRow,
    daysLeftLabel: String,
    todayLabel: String,
    passedLabel: String,
): String = when (row.state) {
    CountdownState.FUTURE -> "${row.daysText} $daysLeftLabel"
    CountdownState.TODAY -> todayLabel
    CountdownState.PAST -> passedLabel
    CountdownState.EMPTY -> COUNTDOWN_DASH
}

/** Yalnız `getString` — sayı okunmaz (bkz. sınıf yorumu, putLong/getInt tuzağı). */
internal fun readCountdownJson(prefs: SharedPreferences): String? =
    runCatching { prefs.getString(COUNTDOWN_PREFS_KEY, null) }.getOrNull()

/**
 * Launcher'in bildirdigi kutu -> boyut sinifi. Siniflandirmanin kendisi saf
 * [widgetSizeClass] fonksiyonudur (JVM testi onu olcer); buradaki tek is
 * `Bundle`i okumaktir. `OPTION_APPWIDGET_MIN_*` bilerek secildi: `MAX_*`
 * diger ekran yonundeki olcudur, ona gore cizmek cihaz dondugunde metni
 * kirpardi.
 */
internal fun countdownWidgetSizeClass(
    appWidgetManager: AppWidgetManager,
    widgetId: Int,
): WidgetSizeClass {
    val options = runCatching { appWidgetManager.getAppWidgetOptions(widgetId) }.getOrNull()
    val width = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0) ?: 0
    val height = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0) ?: 0
    return widgetSizeClass(WidgetSizeSpecs.countdown, width, height)
}

class CountdownWidgetProvider : HomeWidgetProvider() {
    /**
     * WP-699: yeniden boyutlandirma `onUpdate` tetiklemez.
     * `AppWidgetProvider.onAppWidgetOptionsChanged` govdesi bostur ve
     * `HomeWidgetProvider` (home_widget 0.9.3) onu gecersiz kilmaz. Bu metot
     * yazilmadan, kullanici widget'i buyutunce dar/genis dali degismiyor,
     * yalniz bir sonraki periyodik guncellemede (burada 30 dk) yakalaniyordu.
     */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId))
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val strings = widgetLocalizedContext(context)
        val list = runCatching {
            countdownWidgetList(
                readCountdownJson(
                    context.getSharedPreferences(COUNTDOWN_PREFS_NAME, Context.MODE_PRIVATE),
                ),
                System.currentTimeMillis(),
            )
        }.getOrElse { CountdownWidgetList(emptyList(), false) }

        val model = list.head
        val daysLeftLabel = strings.getString(R.string.widget_countdown_days_left)
        val todayLabel = strings.getString(R.string.widget_countdown_today)
        val passedLabel = strings.getString(R.string.widget_countdown_passed)
        val defaultName = strings.getString(R.string.widget_countdown_default_name)
        val label = when (model.state) {
            CountdownState.EMPTY -> strings.getString(R.string.widget_countdown_empty)
            CountdownState.FUTURE -> daysLeftLabel
            CountdownState.TODAY -> todayLabel
            CountdownState.PAST -> passedLabel
        }
        val title = when {
            model.state == CountdownState.EMPTY ->
                strings.getString(R.string.widget_countdown_title)
            model.name.isNotEmpty() -> model.name
            else -> defaultName
        }

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.odak_countdown_widget).apply {
                setContentDescription(
                    R.id.countdown_widget_root,
                    strings.getString(R.string.cd_countdown_widget),
                )
                // WP-699: geri sayimin tek duzeni vardi; 30sp gun sayisi
                // `minWidth=110dp` kutuya sigar ama 2 hucreden dar bir kutuda
                // kirpilirdi ve buyutuldugunde ayni puntoda kalirdi.
                val size = countdownWidgetSizeClass(appWidgetManager, widgetId)
                // WP-717: kahraman mi liste mi? Kural uygulamadaki kartla ayni
                // (`dday_card.dart` -> `useHero`). Bos durumda kahraman blogu
                // yine gorunur, cunku "henuz geri sayim eklenmedi" satirini o
                // tasir.
                val hero = countdownUsesHero(size.height, list.rows.size, list.hasPriority)
                val heroVisible = hero || list.rows.isEmpty()
                setViewVisibility(
                    R.id.countdown_widget_hero,
                    if (heroVisible) android.view.View.VISIBLE else android.view.View.GONE,
                )
                setTextViewText(R.id.countdown_widget_name, title)
                setTextViewText(R.id.countdown_widget_days, model.daysText)
                setTextViewText(R.id.countdown_widget_label, label)
                setTextViewTextSize(
                    R.id.countdown_widget_name,
                    android.util.TypedValue.COMPLEX_UNIT_SP,
                    WidgetTypography.countdownName.of(size.width),
                )
                setTextViewTextSize(
                    R.id.countdown_widget_days,
                    android.util.TypedValue.COMPLEX_UNIT_SP,
                    WidgetTypography.countdownDays.of(size.width),
                )
                setTextViewTextSize(
                    R.id.countdown_widget_label,
                    android.util.TypedValue.COMPLEX_UNIT_SP,
                    WidgetTypography.countdownLabel.of(size.width),
                )
                // Kisa kutuda sinav ADI dusulur, gun sayisi ile "gun kaldi"
                // satiri kalir: widget'in tasidigi bilgi budur.
                setViewVisibility(
                    R.id.countdown_widget_name,
                    if (heroVisible && countdownNameVisible(size.height)) {
                        android.view.View.VISIBLE
                    } else {
                        android.view.View.GONE
                    },
                )

                // WP-717 — "ters U" yay. Gorunurluk ve deger AYRI surulur:
                // duzende durup hicbir zaman deger almayan bir gosterge, bu
                // depoda `resizeMode`un dustugu olu-bayrak tuzagidir.
                setViewVisibility(
                    R.id.countdown_widget_arc,
                    if (countdownArcVisible(size.height, model.state)) {
                        android.view.View.VISIBLE
                    } else {
                        android.view.View.GONE
                    },
                )
                setProgressBar(
                    R.id.countdown_widget_arc,
                    WidgetDesign.PROGRESS_MAX,
                    WidgetDesign.arcPercent(countdownArcFraction(model)),
                    false,
                )

                // WP-717 — diger sinavlar. Kahraman varsa listenin GERISI,
                // yoksa listenin TAMAMI cizilir (uygulamadaki kartla ayni).
                val rowSp = COUNTDOWN_ROW_SP.of(size.width)
                val drawn = if (hero) list.rows.drop(1) else list.rows
                val visibleRows =
                    countdownVisibleRowCount(size.height, list.rows.size, list.hasPriority)
                for (slot in 0 until COUNTDOWN_ROW_SLOTS) {
                    val row = drawn.getOrNull(slot).takeIf { slot < visibleRows }
                    setViewVisibility(
                        COUNTDOWN_ROW_CONTAINER_IDS[slot],
                        if (row == null) android.view.View.GONE else android.view.View.VISIBLE,
                    )
                    if (row == null) continue
                    setTextViewText(
                        COUNTDOWN_ROW_NAME_IDS[slot],
                        row.name.ifEmpty { defaultName },
                    )
                    setTextViewText(
                        COUNTDOWN_ROW_DAYS_IDS[slot],
                        countdownRowValueText(row, daysLeftLabel, todayLabel, passedLabel),
                    )
                    setTextViewTextSize(
                        COUNTDOWN_ROW_NAME_IDS[slot],
                        android.util.TypedValue.COMPLEX_UNIT_SP,
                        rowSp,
                    )
                    setTextViewTextSize(
                        COUNTDOWN_ROW_DAYS_IDS[slot],
                        android.util.TypedValue.COMPLEX_UNIT_SP,
                        rowSp,
                    )
                }

                val paddingPx = (
                    widgetRootPaddingDp(12, size.height) *
                        context.resources.displayMetrics.density
                    ).toInt()
                setViewPadding(
                    R.id.countdown_widget_root,
                    paddingPx,
                    paddingPx,
                    paddingPx,
                    paddingPx,
                )
                // WP-700: rota tasimayan kopya cagri kaldirildi; tek kaynak
                // `WidgetDeepLink`. Eskisi paketin launcher intent'ini
                // kullaniyordu ve uygulamayi "en son nerede kaldiysa" oraya
                // aciyordu.
                setOnClickPendingIntent(
                    R.id.countdown_widget_root,
                    WidgetDeepLink.pendingIntent(
                        context,
                        WidgetDeepLink.ROUTE_COUNTDOWN,
                        widgetId,
                    ),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

/** Satir puntosu; kahraman sayisindan kucuk kalmali ki hiyerarsi bozulmasin. */
private val COUNTDOWN_ROW_SP = SpRamp(11f, 12f, 14f)

private val COUNTDOWN_ROW_CONTAINER_IDS = intArrayOf(
    R.id.countdown_widget_row_1,
    R.id.countdown_widget_row_2,
    R.id.countdown_widget_row_3,
)

private val COUNTDOWN_ROW_NAME_IDS = intArrayOf(
    R.id.countdown_widget_row_name_1,
    R.id.countdown_widget_row_name_2,
    R.id.countdown_widget_row_name_3,
)

private val COUNTDOWN_ROW_DAYS_IDS = intArrayOf(
    R.id.countdown_widget_row_days_1,
    R.id.countdown_widget_row_days_2,
    R.id.countdown_widget_row_days_3,
)

/**
 * JSON'un yalnız bu kaydın kullandığı alt kümesini çözen küçük ayrıştırıcı.
 *
 * `org.json` **bilinçli olarak** kullanılmadı: o sınıflar `android.jar`
 * içinde saplamadır ve JVM birim testinde her çağrı "not mocked" ile patlar.
 * Yani `org.json` ile yazılsaydı ayrıştırma — bu widget'ın en kırılgan
 * parçası — hiç test edilemezdi ve yalnız cihazda ortaya çıkardı.
 */
internal object MiniJson {
    fun parse(raw: String?): Any? {
        if (raw.isNullOrEmpty()) return null
        return runCatching {
            val cursor = Cursor(raw)
            val value = cursor.value()
            cursor.skipWhitespace()
            if (!cursor.done) null else value
        }.getOrNull()
    }

    private class Cursor(val text: String) {
        var index = 0

        val done: Boolean get() = index >= text.length

        fun skipWhitespace() {
            while (index < text.length && text[index].isWhitespace()) index++
        }

        fun value(): Any? {
            skipWhitespace()
            if (done) throw IllegalStateException("bos")
            return when (text[index]) {
                '{' -> obj()
                '[' -> array()
                '"' -> string()
                't' -> literal("true", true)
                'f' -> literal("false", false)
                'n' -> literal("null", null)
                else -> number()
            }
        }

        private fun literal(token: String, value: Any?): Any? {
            if (!text.startsWith(token, index)) throw IllegalStateException("literal")
            index += token.length
            return value
        }

        private fun number(): Double {
            val start = index
            while (index < text.length && text[index] !in ",}] \t\r\n") index++
            return text.substring(start, index).toDouble()
        }

        private fun expect(char: Char) {
            skipWhitespace()
            if (done || text[index] != char) throw IllegalStateException("beklenen $char")
            index++
        }

        private fun obj(): Map<String, Any?> {
            expect('{')
            val result = LinkedHashMap<String, Any?>()
            skipWhitespace()
            if (!done && text[index] == '}') {
                index++
                return result
            }
            while (true) {
                skipWhitespace()
                val key = string()
                expect(':')
                result[key] = value()
                skipWhitespace()
                if (done) throw IllegalStateException("kapanmamis nesne")
                when (text[index]) {
                    ',' -> index++
                    '}' -> {
                        index++
                        return result
                    }
                    else -> throw IllegalStateException("bozuk nesne")
                }
            }
        }

        private fun array(): List<Any?> {
            expect('[')
            val result = ArrayList<Any?>()
            skipWhitespace()
            if (!done && text[index] == ']') {
                index++
                return result
            }
            while (true) {
                result.add(value())
                skipWhitespace()
                if (done) throw IllegalStateException("kapanmamis dizi")
                when (text[index]) {
                    ',' -> index++
                    ']' -> {
                        index++
                        return result
                    }
                    else -> throw IllegalStateException("bozuk dizi")
                }
            }
        }

        private fun string(): String {
            expect('"')
            val builder = StringBuilder()
            while (true) {
                if (done) throw IllegalStateException("kapanmamis metin")
                when (val char = text[index++]) {
                    '"' -> return builder.toString()
                    '\\' -> {
                        if (done) throw IllegalStateException("yarim kacis")
                        when (val escaped = text[index++]) {
                            '"' -> builder.append('"')
                            '\\' -> builder.append('\\')
                            '/' -> builder.append('/')
                            'b' -> builder.append('\b')
                            'f' -> builder.append('')
                            'n' -> builder.append('\n')
                            'r' -> builder.append('\r')
                            't' -> builder.append('\t')
                            'u' -> {
                                val hex = text.substring(index, index + 4)
                                index += 4
                                builder.append(hex.toInt(16).toChar())
                            }
                            else -> throw IllegalStateException("bilinmeyen kacis $escaped")
                        }
                    }
                    else -> builder.append(char)
                }
            }
        }
    }
}
