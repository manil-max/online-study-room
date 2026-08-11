package com.manilmax.online_study_room.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
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
internal fun countdownWidgetModel(rawJson: String?, nowMs: Long): CountdownWidgetModel {
    val empty = CountdownWidgetModel(CountdownState.EMPTY, "", 0L, COUNTDOWN_DASH)
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
    val chosen = entries.firstOrNull { (it["id"] as? String) == priorityId } ?: entries.first()
    val examDay = parseExamDay(chosen["day"] as? String) ?: return empty
    val name = (chosen["name"] as? String)?.trim().orEmpty()
    val diff = examDay - istanbulEpochDay(nowMs)
    return when {
        diff > 0L -> CountdownWidgetModel(CountdownState.FUTURE, name, diff, diff.toString())
        diff == 0L -> CountdownWidgetModel(CountdownState.TODAY, name, 0L, "0")
        // 🔴 Geçmiş tarih negatif gün YAZMAZ ("-12 gün kaldı" bir hatadır).
        else -> CountdownWidgetModel(CountdownState.PAST, name, diff, COUNTDOWN_DASH)
    }
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
        val model = runCatching {
            countdownWidgetModel(
                readCountdownJson(
                    context.getSharedPreferences(COUNTDOWN_PREFS_NAME, Context.MODE_PRIVATE),
                ),
                System.currentTimeMillis(),
            )
        }.getOrElse {
            CountdownWidgetModel(CountdownState.EMPTY, "", 0L, COUNTDOWN_DASH)
        }

        val label = when (model.state) {
            CountdownState.EMPTY -> context.getString(R.string.widget_countdown_empty)
            CountdownState.FUTURE -> context.getString(R.string.widget_countdown_days_left)
            CountdownState.TODAY -> context.getString(R.string.widget_countdown_today)
            CountdownState.PAST -> context.getString(R.string.widget_countdown_passed)
        }
        val title = when {
            model.state == CountdownState.EMPTY ->
                context.getString(R.string.widget_countdown_title)
            model.name.isNotEmpty() -> model.name
            else -> context.getString(R.string.widget_countdown_default_name)
        }

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.odak_countdown_widget).apply {
                // WP-699: geri sayimin tek duzeni vardi; 30sp gun sayisi
                // `minWidth=110dp` kutuya sigar ama 2 hucreden dar bir kutuda
                // kirpilirdi ve buyutuldugunde ayni puntoda kalirdi.
                val size = countdownWidgetSizeClass(appWidgetManager, widgetId)
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
                    if (countdownNameVisible(size.height)) {
                        android.view.View.VISIBLE
                    } else {
                        android.view.View.GONE
                    },
                )
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
                setOnClickPendingIntent(
                    R.id.countdown_widget_root,
                    android.app.PendingIntent.getActivity(
                        context,
                        60 + widgetId,
                        context.packageManager.getLaunchIntentForPackage(context.packageName)
                            ?.addFlags(
                                Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP,
                            )
                            ?: Intent(),
                        android.app.PendingIntent.FLAG_UPDATE_CURRENT or
                            android.app.PendingIntent.FLAG_IMMUTABLE,
                    ),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

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
