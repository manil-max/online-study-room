package com.manilmax.online_study_room.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import com.manilmax.online_study_room.R
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * WP-701: gorev ana ekran widget'i — satirlar ANA EKRANDAN isaretlenir.
 *
 * ## Neden ayna + bekleyen kuyruk
 * Kullanici kutucuga dokundugunda Flutter sureci cogu zaman KAPALIDIR; gercek
 * `UserTasksNotifier.toggle` Dart tarafindadir ve Supabase RPC'sine gider. Bu
 * yuzden dokunma dort parcaya bolundu:
 *
 *  1. **Ayna** ([TASK_MIRROR_PREFS_KEY]): Dart gorev listesini JSON olarak
 *     yazar, widget yalniz bunu okur (sunucuya/veritabanina hic bakmaz).
 *  2. **Iyimser cizim**: dokunma aninda ayna guncellenir ve widget hemen
 *     yeniden cizilir. Kullanici dokunup "hicbir sey olmadi" gormez.
 *  3. **Bekleyen kuyruk** ([TASK_PENDING_PREFS_KEY]): Kotlin niyeti kalici
 *     yazar; uygulama acilinca Dart bosaltip gercek `toggle`i uygular.
 *  4. **Cift uygulama koruma**: kuyruk *toggle* degil **ISTENEN MUTLAK DURUM**
 *     tasir (`done: true/false`). Ayni kayit iki kez islense bile sonuc
 *     degismez; toggle tasisaydi ikinci islem isaretlemeyi geri alirdi.
 *
 * ## Native tuzaklar
 * - Prefs'ten **sayi okunmaz/yazilmaz**. Dart `setInt` diske `putLong` yazar;
 *   native `getInt` `ClassCastException` firlatir ve bu bir `BroadcastReceiver`
 *   icinde uygulama **surecini** oldurur (v58 sahasinda geri sayim/pomodoro
 *   cokmesi buydu). Iki tarafin da dokundugu her deger `String`tir; zaman
 *   damgasi bile JSON icinde metindir.
 * - `org.json` kullanilmadi: `android.jar` icindeki saplama JVM biriminde
 *   "not mocked" ile patlar, yani en kirilgan parca (ayristirma) hic test
 *   edilemezdi. `MiniJson` (CountdownWidget.kt) ayristirir, buradaki
 *   [encodeTaskWidgetMirror] yazar.
 * - Kullaniciya gorunen metin (baslik/bos durum) **Dart'tan** gelir: ayna
 *   JSON'unda tasinir. Boylece uygulamada secilen dil ile widget ayni dili
 *   konusur ve native `strings.xml` ikinci bir ceviri kaynagi olmaz. Ayna hic
 *   yazilmamissa (uygulama bir kez bile acilmadi) `R.string.widget_no_records`
 *   yedegi cizilir.
 */
internal const val TASK_PREFS_NAME = "FlutterSharedPreferences"
internal const val TASK_MIRROR_PREFS_KEY = "flutter.tasks.widget_v1"
internal const val TASK_PENDING_PREFS_KEY = "flutter.tasks.widget_pending_v1"

/** Layout'taki satir sayisi. RemoteViews dinamik satir uretemez. */
internal const val TASK_WIDGET_MAX_ROWS = 5

/** Kuyruk sinirsiz buyumez; en yeni [TASK_PENDING_MAX] niyet saklanir. */
internal const val TASK_PENDING_MAX = 50

internal const val TASK_BOX_DONE = "☑"
internal const val TASK_BOX_TODO = "☐"

internal data class TaskWidgetItem(
    val id: String,
    val title: String,
    val done: Boolean,
)

/**
 * Widget'in cizecegi model. [title] ve [emptyLabel] Dart'tan gelir; bos
 * gelirse saglayici native yedegi kullanir.
 */
internal data class TaskWidgetModel(
    val title: String,
    val emptyLabel: String,
    val items: List<TaskWidgetItem>,
)

internal val EMPTY_TASK_WIDGET_MODEL = TaskWidgetModel("", "", emptyList())

/** Iyimser isaretlemenin sonucu: yeni ayna + o gorevin ISTENEN durumu. */
internal data class TaskToggleResult(val mirrorJson: String, val done: Boolean)

/** Yalniz `getString` — sayi okunmaz (bkz. sinif yorumu, putLong/getInt tuzagi). */
internal fun readTaskMirrorJson(prefs: SharedPreferences): String? =
    runCatching { prefs.getString(TASK_MIRROR_PREFS_KEY, null) }.getOrNull()

internal fun readTaskPendingJson(prefs: SharedPreferences): String? =
    runCatching { prefs.getString(TASK_PENDING_PREFS_KEY, null) }.getOrNull()

/**
 * Ayna JSON'u -> model. Bozuk/eksik kayit widget'i **bos duruma** dusurur,
 * uygulamayi degil. Tanimadigi alanlar yok sayilir: Dart tarafi aynaya yeni
 * bir alan eklediginde widget sessizce olmemeli.
 */
internal fun parseTaskWidgetMirror(raw: String?): TaskWidgetModel {
    val root = MiniJson.parse(raw) as? Map<*, *> ?: return EMPTY_TASK_WIDGET_MODEL
    val items = (root["tasks"] as? List<*>).orEmpty()
        .mapNotNull { it as? Map<*, *> }
        .mapNotNull { entry ->
            val id = (entry["id"] as? String)?.trim().orEmpty()
            val title = (entry["title"] as? String)?.trim().orEmpty()
            if (id.isEmpty() || title.isEmpty()) {
                null
            } else {
                TaskWidgetItem(id, title, entry["done"] as? Boolean ?: false)
            }
        }
    return TaskWidgetModel(
        title = (root["title"] as? String)?.trim().orEmpty(),
        emptyLabel = (root["empty"] as? String)?.trim().orEmpty(),
        items = items.take(TASK_WIDGET_MAX_ROWS),
    )
}

internal fun encodeTaskWidgetMirror(model: TaskWidgetModel): String {
    val builder = StringBuilder()
    builder.append("{\"title\":").append(jsonString(model.title))
    builder.append(",\"empty\":").append(jsonString(model.emptyLabel))
    builder.append(",\"tasks\":[")
    model.items.forEachIndexed { index, item ->
        if (index > 0) builder.append(',')
        builder.append("{\"id\":").append(jsonString(item.id))
        builder.append(",\"title\":").append(jsonString(item.title))
        builder.append(",\"done\":").append(if (item.done) "true" else "false")
        builder.append('}')
    }
    builder.append("]}")
    return builder.toString()
}

private fun jsonString(value: String): String {
    val builder = StringBuilder(value.length + 2)
    builder.append('"')
    for (char in value) {
        when {
            char == '"' -> builder.append("\\\"")
            char == '\\' -> builder.append("\\\\")
            char == '\n' -> builder.append("\\n")
            char == '\r' -> builder.append("\\r")
            char == '\t' -> builder.append("\\t")
            char < ' ' -> builder.append(String.format("\\u%04x", char.code))
            else -> builder.append(char)
        }
    }
    builder.append('"')
    return builder.toString()
}

/**
 * Aynadaki bir gorevi ters cevirir. Gorev yoksa/JSON bozuksa `null` doner ve
 * cagiran hicbir sey yazmaz — bilinmeyen bir kimlik icin kuyruga niyet
 * yazmak, uygulamada silinmis bir gorevi diriltmeye calismak olurdu.
 */
internal fun toggleTaskInMirror(raw: String?, taskId: String): TaskToggleResult? {
    val model = parseTaskWidgetMirror(raw)
    val target = model.items.firstOrNull { it.id == taskId } ?: return null
    val desired = !target.done
    val updated = model.copy(
        items = model.items.map { if (it.id == taskId) it.copy(done = desired) else it },
    )
    return TaskToggleResult(encodeTaskWidgetMirror(updated), desired)
}

/** Kuyruktaki tek niyet: `taskId` gorevi `done` durumuna gelsin. */
internal data class PendingTaskToggle(
    val opId: String,
    val taskId: String,
    val done: Boolean,
    val atMs: Long,
)

internal fun parsePendingTaskToggles(raw: String?): List<PendingTaskToggle> {
    val root = MiniJson.parse(raw) as? Map<*, *> ?: return emptyList()
    return (root["ops"] as? List<*>).orEmpty()
        .mapNotNull { it as? Map<*, *> }
        .mapNotNull { entry ->
            val taskId = (entry["taskId"] as? String)?.trim().orEmpty()
            if (taskId.isEmpty()) return@mapNotNull null
            PendingTaskToggle(
                opId = (entry["id"] as? String)?.trim().orEmpty(),
                taskId = taskId,
                done = entry["done"] as? Boolean ?: false,
                // Zaman damgasi METINdir: JSON sayisi Double'a coker ve
                // milisaniye hassasiyeti kaybolurdu.
                atMs = (entry["at"] as? String)?.toLongOrNull() ?: 0L,
            )
        }
}

internal fun encodePendingTaskToggles(ops: List<PendingTaskToggle>): String {
    val builder = StringBuilder("{\"ops\":[")
    ops.forEachIndexed { index, op ->
        if (index > 0) builder.append(',')
        builder.append("{\"id\":").append(jsonString(op.opId))
        builder.append(",\"taskId\":").append(jsonString(op.taskId))
        builder.append(",\"done\":").append(if (op.done) "true" else "false")
        builder.append(",\"at\":").append(jsonString(op.atMs.toString()))
        builder.append('}')
    }
    builder.append("]}")
    return builder.toString()
}

/**
 * Kuyruga yeni niyet ekler. **Ayni gorevin eski niyeti dusurulur**: kullanici
 * uygulama kapaliyken bir gorevi isaretleyip geri aldiysa Dart'in yapmasi
 * gereken tek is son durumdur. Kuyruk [TASK_PENDING_MAX] ile sinirlidir.
 */
internal fun appendPendingTaskToggle(
    rawPending: String?,
    taskId: String,
    done: Boolean,
    opId: String,
    atMs: Long,
): String {
    val kept = parsePendingTaskToggles(rawPending).filterNot { it.taskId == taskId }
    val ops = (kept + PendingTaskToggle(opId, taskId, done, atMs))
        .takeLast(TASK_PENDING_MAX)
    return encodePendingTaskToggles(ops)
}

// ---------------------------------------------------------------------------
// Boyut: GENISLIK punto merdivenini, YUKSEKLIK satir sayisini secer.
//
// Hucre -> dp donusumu Android'in formuludur: `70 * n - 30` (1=40, 2=110,
// 3=180, 4=250, 5=320). Varsayilan 3x2 hucre = 180x110dp; iceriginin en az
// uc satiri oldugu icin geri sayimin 2x2'sinden genis acilir.
// Esikler `res/xml/odak_task_widget_info.xml` sinirlariyla birlikte anlam
// tasir; ayrisma `task_widget_wp701_test.dart` icinde kirmizi duser.
// ---------------------------------------------------------------------------

internal const val WIDGET_TASK_DEFAULT_WIDTH_DP = 180
internal const val WIDGET_TASK_DEFAULT_HEIGHT_DP = 110
internal const val WIDGET_TASK_MEDIUM_WIDTH_DP = 180
internal const val WIDGET_TASK_WIDE_WIDTH_DP = 250
internal const val WIDGET_TASK_MEDIUM_HEIGHT_DP = 110
internal const val WIDGET_TASK_TALL_HEIGHT_DP = 180

internal val TASK_WIDGET_SIZE_SPEC = WidgetSizeSpec(
    WIDGET_TASK_DEFAULT_WIDTH_DP,
    WIDGET_TASK_DEFAULT_HEIGHT_DP,
    WIDGET_TASK_MEDIUM_WIDTH_DP,
    WIDGET_TASK_WIDE_WIDTH_DP,
    WIDGET_TASK_MEDIUM_HEIGHT_DP,
    WIDGET_TASK_TALL_HEIGHT_DP,
)

internal val TASK_TITLE_SP = SpRamp(12f, 13f, 15f)
internal val TASK_ROW_SP = SpRamp(11f, 13f, 14f)

/**
 * Bir gorev satirinin yuksekligi. `odak_task_widget.xml` icindeki
 * `android:minHeight="32dp"` ile AYNI sayidir (dokunma hedefi oradan gelir);
 * ayrisirsa `task_widget_wp719_test.dart` kirmizi duser.
 */
internal const val TASK_ROW_HEIGHT_DP = 32

/** Baslik satirinin kapladigi dikey blok (13sp metin + satir araligi). */
internal const val TASK_TITLE_HEIGHT_DP = 20

/** Kisa kutuda baslik dusurulur; widget'in tasidigi bilgi GOREV SATIRLARIDIR. */
internal fun taskWidgetTitleVisible(height: WidgetHeightClass): Boolean =
    height != WidgetHeightClass.SHORT

/**
 * Kutuya GERCEKTEN sigan satir sayisi.
 *
 * 🔴 WP-719: bu sayi eskiden kaba yukseklik SINIFINDAN turuyordu
 * (SHORT=2, MEDIUM=3, TALL=5) ve sinifin dogrulugu bir aritmetik modelle
 * sinaniyordu; ama o model satir yuksekligini "punto x 1.30" (~17dp) sayiyordu,
 * layout'ta satir ise `minHeight="32dp"`. Gercek: 110dp'lik kutuda baslik + 3
 * satir 140dp ister — kart kutuyu 30dp asiyor ve kirpiliyordu. Kapasite artik
 * kutunun bildirdigi yukseklikten cikar, yani sayilar tek yerde ve olculebilir.
 */
internal fun taskWidgetRowCapacity(
    boxHeightDp: Int,
    titleVisible: Boolean,
    paddingDp: Int,
): Int {
    val titleDp = if (titleVisible) TASK_TITLE_HEIGHT_DP else 0
    val usable = boxHeightDp - 2 * paddingDp - titleDp
    if (usable <= 0) return 0
    return (usable / TASK_ROW_HEIGHT_DP).coerceIn(0, TASK_WIDGET_MAX_ROWS)
}

internal fun taskWidgetVisibleItems(
    model: TaskWidgetModel,
    boxHeightDp: Int,
    titleVisible: Boolean,
    paddingDp: Int,
): List<TaskWidgetItem> =
    model.items.take(taskWidgetRowCapacity(boxHeightDp, titleVisible, paddingDp))

internal fun taskWidgetSizeClass(
    appWidgetManager: AppWidgetManager,
    widgetId: Int,
): WidgetSizeClass {
    val options = runCatching { appWidgetManager.getAppWidgetOptions(widgetId) }.getOrNull()
    val width = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0) ?: 0
    val height = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0) ?: 0
    return widgetSizeClass(TASK_WIDGET_SIZE_SPEC, width, height)
}

/**
 * Launcher'in bildirdigi kutu yuksekligi (dp).
 *
 * Bundle bos gelirse (`getInt` 0) varsayilan kullanilir: 0'i oldugu gibi
 * kullanmak ilk cizimde kapasiteyi sifirlar ve kullanici widget'i ekler eklemez
 * bos bir kart gorurdu. `getInt` burada guvenlidir — `AppWidgetManager`
 * seceneklerini SISTEM yazar, Dart'in `putLong` tuzagi yalniz
 * `FlutterSharedPreferences` dosyasi icin gecerlidir.
 */
internal fun taskWidgetBoxHeightDp(
    appWidgetManager: AppWidgetManager,
    widgetId: Int,
): Int {
    val options = runCatching { appWidgetManager.getAppWidgetOptions(widgetId) }.getOrNull()
    val height = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0) ?: 0
    return if (height <= 0) WIDGET_TASK_DEFAULT_HEIGHT_DP else height
}

private val ROW_IDS = intArrayOf(
    R.id.task_widget_row_0,
    R.id.task_widget_row_1,
    R.id.task_widget_row_2,
    R.id.task_widget_row_3,
    R.id.task_widget_row_4,
)

private val BOX_IDS = intArrayOf(
    R.id.task_widget_box_0,
    R.id.task_widget_box_1,
    R.id.task_widget_box_2,
    R.id.task_widget_box_3,
    R.id.task_widget_box_4,
)

private val LABEL_IDS = intArrayOf(
    R.id.task_widget_label_0,
    R.id.task_widget_label_1,
    R.id.task_widget_label_2,
    R.id.task_widget_label_3,
    R.id.task_widget_label_4,
)

class TaskWidgetProvider : HomeWidgetProvider() {
    /**
     * WP-699 dersi: yeniden boyutlandirma `onUpdate` tetiklemez.
     * `AppWidgetProvider.onAppWidgetOptionsChanged` govdesi bostur ve
     * `HomeWidgetProvider` (home_widget 0.9.3) onu gecersiz kilmaz. Bu metot
     * olmadan kullanici widget'i uzatinca satir sayisi degismezdi;
     * `updatePeriodMillis=0` oldugu icin ASLA degismezdi.
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
            parseTaskWidgetMirror(
                readTaskMirrorJson(
                    context.getSharedPreferences(TASK_PREFS_NAME, Context.MODE_PRIVATE),
                ),
            )
        }.getOrElse { EMPTY_TASK_WIDGET_MODEL }

        val heading = model.title.ifEmpty { context.getString(R.string.widget_today) }
        val emptyLabel = model.emptyLabel.ifEmpty {
            context.getString(R.string.widget_no_records)
        }
        val doneColor = ContextCompat.getColor(context, R.color.widget_secondary_text)
        val todoColor = ContextCompat.getColor(context, R.color.widget_primary_text)

        appWidgetIds.forEach { widgetId ->
            val size = taskWidgetSizeClass(appWidgetManager, widgetId)
            val titleVisible = taskWidgetTitleVisible(size.height)
            val paddingDp = widgetRootPaddingDp(12, size.height)
            val visible = taskWidgetVisibleItems(
                model,
                taskWidgetBoxHeightDp(appWidgetManager, widgetId),
                titleVisible,
                paddingDp,
            )
            val views = RemoteViews(context.packageName, R.layout.odak_task_widget).apply {
                setTextViewText(R.id.task_widget_title, heading)
                setTextViewTextSize(
                    R.id.task_widget_title,
                    TypedValue.COMPLEX_UNIT_SP,
                    TASK_TITLE_SP.of(size.width),
                )
                setViewVisibility(
                    R.id.task_widget_title,
                    if (titleVisible) View.VISIBLE else View.GONE,
                )

                setTextViewText(R.id.task_widget_empty, emptyLabel)
                setTextViewTextSize(
                    R.id.task_widget_empty,
                    TypedValue.COMPLEX_UNIT_SP,
                    TASK_ROW_SP.of(size.width),
                )
                setViewVisibility(
                    R.id.task_widget_empty,
                    if (visible.isEmpty()) View.VISIBLE else View.GONE,
                )

                for (index in 0 until TASK_WIDGET_MAX_ROWS) {
                    val item = visible.getOrNull(index)
                    if (item == null) {
                        setViewVisibility(ROW_IDS[index], View.GONE)
                        continue
                    }
                    setViewVisibility(ROW_IDS[index], View.VISIBLE)
                    setTextViewText(
                        BOX_IDS[index],
                        if (item.done) TASK_BOX_DONE else TASK_BOX_TODO,
                    )
                    setTextViewText(LABEL_IDS[index], item.title)
                    // Bitmis satir renkten de anlasilir; kutucuk ISARETI tek
                    // sinyal olsaydi kucuk puntoda gozden kacardi.
                    setTextColor(
                        LABEL_IDS[index],
                        if (item.done) doneColor else todoColor,
                    )
                    setTextColor(BOX_IDS[index], if (item.done) doneColor else todoColor)
                    for (viewId in intArrayOf(BOX_IDS[index], LABEL_IDS[index])) {
                        setTextViewTextSize(
                            viewId,
                            TypedValue.COMPLEX_UNIT_SP,
                            TASK_ROW_SP.of(size.width),
                        )
                    }
                    setOnClickPendingIntent(
                        ROW_IDS[index],
                        togglePendingIntent(context, widgetId, index, item.id),
                    )
                }

                val paddingPx = (
                    paddingDp * context.resources.displayMetrics.density
                    ).toInt()
                setViewPadding(
                    R.id.task_widget_root,
                    paddingPx,
                    paddingPx,
                    paddingPx,
                    paddingPx,
                )
                // 🔴 WP-706 — BU DIKISTE BOSLUK VARDI.
                //
                // WP-701 buraya "derin baglanti WP-700'un isi" yazip
                // `getLaunchIntentForPackage`i birakti; WP-700 ise bu dosyayi
                // "WP-701'in SAHIP yolu" diye elleme kararı aldi. Ikisi de
                // kurala uydu ve is ORTADA kaldi: `ROUTE_TASKS` sabiti
                // tanimliydi ama Kotlin'de HIC KULLANILMIYORDU. Yani sahibin
                // "uzerine tiklayinca o bolum acilsa, oradan duzenlerler"
                // istegi tam da gorev widgetinda karsilanmiyordu.
                //
                // Satirlarin KENDISI toggle olarak kalir (sahibin birincil
                // istegi: "yaptiklarini oradan isaretleseler"). Gezinme
                // satirlarin DISINDA kalan her yere baglanir: baslik, bos
                // durum metni ve kok dolgu alani. RemoteViews'ta cocuk
                // tiklamasi koke gore oncelikli oldugu icin ikisi carpismaz.
                val openTasks =
                    WidgetDeepLink.pendingIntent(
                        context,
                        WidgetDeepLink.ROUTE_TASKS,
                        widgetId,
                    )
                setOnClickPendingIntent(R.id.task_widget_title, openTasks)
                // Bos durum ozellikle onemli: gorevi olmayan kullanicinin
                // widgettan yapabilecegi TEK sey uygulamaya gecip gorev
                // eklemektir.
                setOnClickPendingIntent(R.id.task_widget_empty, openTasks)
                // Baslik kisa yukseklikte GONE oluyor (`taskWidgetTitleVisible`);
                // kok baglanmazsa o boyutta hicbir gezinme hedefi kalmazdi.
                setOnClickPendingIntent(R.id.task_widget_root, openTasks)
                // WP-719: kart artik kutuyu doldurmuyor (`wrap_content`).
                // Kartin disinda kalan seffaf alan baglanmazsa kullanicinin
                // dokunusu launcher'a gider ve widget "olu" hissettirir.
                setOnClickPendingIntent(R.id.task_widget_frame, openTasks)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

/**
 * Satir basina AYRI `PendingIntent`. Iki tuzak birden kapatilir: istek kodu
 * benzersizdir **ve** `data` URI'si farklidir — `PendingIntent` esitligi
 * extras'a BAKMAZ, yalniz data/action/component'e bakar; hepsi ayni olsaydi
 * bes satir tek intent'e cokerdi ve her dokunus ilk gorevi isaretlerdi.
 */
private fun togglePendingIntent(
    context: Context,
    widgetId: Int,
    index: Int,
    taskId: String,
): PendingIntent {
    val intent = Intent(context, TaskActionReceiver::class.java).apply {
        action = TaskActionReceiver.ACTION_TOGGLE_TASK
        data = Uri.parse("odaktask://toggle/$widgetId/$index/$taskId")
        putExtra(TaskActionReceiver.EXTRA_TASK_ID, taskId)
    }
    return PendingIntent.getBroadcast(
        context,
        7010 + widgetId * TASK_WIDGET_MAX_ROWS + index,
        intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}

/** Widget'lari hemen yeniden cizdirir (iyimser gorunum icin). */
internal fun requestTaskWidgetRedraw(context: Context) {
    runCatching {
        val manager = AppWidgetManager.getInstance(context) ?: return
        val ids = manager.getAppWidgetIds(
            ComponentName(context, TaskWidgetProvider::class.java),
        )
        if (ids == null || ids.isEmpty()) return
        context.sendBroadcast(
            Intent(context, TaskWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            },
        )
    }
}
