package com.manilmax.online_study_room.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import com.manilmax.online_study_room.R
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.Locale

/**
 * WP-756 - Siradaki alarm. Verisini `flutter.native_alarm_mirror_v1` JSON'undan
 * okur (`NativeAlarmBridge.writeAlarmMirror` yazar).
 *
 * ## Kapatilan uc kusur (olculdu, iddia degil)
 *
 * 1. **Kokun `android:id`si YOKTU.** `odak_alarm_widget.xml`in kok
 *    `LinearLayout`u id tasimiyordu; RemoteViews'ta id'siz bir gorunume
 *    `setOnClickPendingIntent` baglanamaz. Yani widget'in HICBIR yerine
 *    dokunulamiyordu - derin baglanti dokuz widget icinde yalniz burada yoktu.
 *    Artik `alarm_widget_root` var ve [WidgetDeepLink.ROUTE_CLOCK] bagli
 *    (Dart tarafi o rotayi `ClockTab.alarm`a cozer, `clock_screen.dart:23`).
 *
 * 2. **Boyut sozlesmesi yoktu.** `res/xml/odak_alarm_widget_info.xml` dokuz
 *    dosya icinde `targetCell*` / `minResize*` / `maxResize*` beyani HIC
 *    olmayan tek dosyaydi ve saglayicinin bir [WidgetSizeSpec] girdisi de
 *    yoktu. Simdi ikisi de var ve ayni sayilari soyluyor.
 *
 * 3. **`onAppWidgetOptionsChanged` gecersiz kilinmamisti.**
 *    `AppWidgetProvider`daki govdesi bostur ve `HomeWidgetProvider`
 *    (home_widget 0.9.3) onu gecersiz kilmaz; yani kullanici widget'i
 *    boyutlandirdiginda `onUpdate` HIC cagrilmiyordu. Sekiz widget'ta WP-699
 *    bunu kapatmisti, alarm disarida kalmisti.
 *
 * ## Ayristirma neden `MiniJson`
 * Eski hali `org.json.JSONArray` kullaniyordu. `android.jar` icindeki
 * `org.json` saplamasi JVM biriminde "not mocked" ile patlar; yani en kirilgan
 * parca (ayristirma) HIC test edilemezdi. [MiniJson] saf Kotlin'dir ve
 * [parseNextAlarm] JVM testinde dogrudan olculur.
 *
 * 🔴 Widget hala YAYIN DISIdir (`AndroidManifest.xml` -> `enabled=false`).
 * Bu WP tasarimi ve kademe mantigini hazirlar; yayin karari ayridir.
 */
internal const val ALARM_MIRROR_PREFS_NAME = "FlutterSharedPreferences"
internal const val ALARM_MIRROR_PREFS_KEY = "flutter.native_alarm_mirror_v1"

// --- Boyut sozlesmesi (kusur 2) --------------------------------------------
// Hucre -> dp: `70n - 30`. Varsayilan 2x1 = 110x40dp; alarm tek satirlik bir
// olgudur. Sayilar `res/xml/odak_alarm_widget_info.xml` ile AYNIdir.
internal const val WIDGET_ALARM_DEFAULT_WIDTH_DP = 110
internal const val WIDGET_ALARM_DEFAULT_HEIGHT_DP = 40
internal const val WIDGET_ALARM_MEDIUM_WIDTH_DP = 180
internal const val WIDGET_ALARM_WIDE_WIDTH_DP = 250
internal const val WIDGET_ALARM_MEDIUM_HEIGHT_DP = 110
internal const val WIDGET_ALARM_TALL_HEIGHT_DP = 180

/**
 * 🔴 `WidgetSizeSpecs` (WidgetCommon.kt) bu turda baska bir ajanin kilidinde;
 * girdi bu yuzden - `TASK_WIDGET_SIZE_SPEC` orneginde oldugu gibi - widget'in
 * kendi dosyasinda duruyor. Tur bitince paylasilan zemine tasinmali.
 */
internal val ALARM_WIDGET_SIZE_SPEC = WidgetSizeSpec(
    WIDGET_ALARM_DEFAULT_WIDTH_DP,
    WIDGET_ALARM_DEFAULT_HEIGHT_DP,
    WIDGET_ALARM_MEDIUM_WIDTH_DP,
    WIDGET_ALARM_WIDE_WIDTH_DP,
    WIDGET_ALARM_MEDIUM_HEIGHT_DP,
    WIDGET_ALARM_TALL_HEIGHT_DP,
)

/** Ayrac blogu: 1dp cizgi + 3dp ust bosluk (`odak_alarm_widget.xml`). */
internal const val ALARM_DIVIDER_BLOCK_DP = 4

/** `07:30` bes karakterdir - K1 cekirdegi bu yuzden GLIFtir (§1.4/§3.4). */
internal const val WIDGET_ALARM_TIME_CHARS = 5

internal data class AlarmWidgetModel(val timeText: String, val label: String)

/**
 * Aynadaki EN YAKIN gelecek alarm. Saf: `nowMs` disaridan gelir ki JVM testi
 * duvar saatine bagimli olmasin.
 *
 * Bozuk/eksik kayit widget'i BOS duruma dusurur, uygulamayi degil: bu kod bir
 * `BroadcastReceiver` icinde kosar ve oradaki yakalanmamis tek istisna
 * uygulama SURECINI oldurur.
 *
 * Sayilar `Double` gelir ([MiniJson] JSON sayisini Double okur); epoch-ms
 * (~1.8e12) 2^53'un cok altinda oldugu icin tam sayi hassasiyeti korunur.
 */
internal fun parseNextAlarm(
    raw: String?,
    nowMs: Long,
    fallbackLabel: String,
): AlarmWidgetModel? {
    val entries = MiniJson.parse(raw) as? List<*> ?: return null
    var bestAt = Long.MAX_VALUE
    var best: AlarmWidgetModel? = null
    for (entry in entries) {
        val map = entry as? Map<*, *> ?: continue
        val at = (map["triggerAtMs"] as? Double)?.toLong() ?: continue
        if (at <= nowMs || at >= bestAt) continue
        val hour = (map["hour"] as? Double)?.toInt() ?: 0
        val minute = (map["minute"] as? Double)?.toInt() ?: 0
        if (hour !in 0..23 || minute !in 0..59) continue
        val label = (map["label"] as? String)?.trim().orEmpty()
        bestAt = at
        best = AlarmWidgetModel(
            String.format(Locale.US, "%02d:%02d", hour, minute),
            label.ifEmpty { fallbackLabel },
        )
    }
    return best
}

/**
 * Kademe. K1 GENISLIKten (bir hucre), K2/K3/K4 yukseklikten cikar.
 *
 *   K1  can glifi (24dp)              - `07:30` 40dp kutuda 12sp'ye duserdi
 *   K2  yalniz saat, 20sp
 *   K3  can (20dp) + saat (26sp) + alarm adi
 *   K4  baslik + AYRAC + can + saat (30sp) + alarm adi
 */
internal fun alarmTier(widthDp: Int, heightDp: Int): ListWidgetTier = when {
    widthDp in 1 until WIDGET_LIST_ONE_CELL_MAX_WIDTH_DP -> ListWidgetTier.K1
    heightDp < WIDGET_ALARM_MEDIUM_HEIGHT_DP -> ListWidgetTier.K2
    heightDp >= WIDGET_ALARM_TALL_HEIGHT_DP -> ListWidgetTier.K4
    else -> ListWidgetTier.K3
}

/**
 * Saat puntosu. K1'de saat CIZILMEZ (cekirdek gliftir); deger K2 ile ayni
 * tutuldu ki merdivende kismi bir bosluk kalmasin.
 */
internal fun alarmTimeSp(tier: ListWidgetTier): Float = when (tier) {
    ListWidgetTier.K1, ListWidgetTier.K2 -> 20f
    ListWidgetTier.K3 -> 26f
    ListWidgetTier.K4 -> 30f
}

/** Alarm adi: yardimci satir, K2'de duser (§1.3). */
internal fun alarmLabelSp(tier: ListWidgetTier): Float =
    if (tier == ListWidgetTier.K4) 13f else 12f

/** Can ikonu K2'de duser: K2 butcesi 0 grafiktir (§1.2). */
internal fun alarmIconVisible(tier: ListWidgetTier): Boolean =
    tier != ListWidgetTier.K2

/** Saat K1'de duser: cekirdek gliftir. */
internal fun alarmTimeVisible(tier: ListWidgetTier): Boolean =
    tier != ListWidgetTier.K1

/** Alarm adi yalniz K3/K4'te; K1/K2 butcesi buna yetmez. */
internal fun alarmLabelVisible(tier: ListWidgetTier): Boolean =
    tier == ListWidgetTier.K3 || tier == ListWidgetTier.K4

/** Baslik yalniz K4'te doner - dusme sirasinda ILK dusen odur (§1.3). */
internal fun alarmCaptionVisible(tier: ListWidgetTier): Boolean =
    tier == ListWidgetTier.K4

class AlarmWidgetProvider : HomeWidgetProvider() {
    /**
     * Kusur 3: bu metot olmadan yeniden boyutlandirma `onUpdate` tetiklemez ve
     * ekranda hicbir sey degismez.
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
        val raw = runCatching {
            context
                .getSharedPreferences(ALARM_MIRROR_PREFS_NAME, Context.MODE_PRIVATE)
                .getString(ALARM_MIRROR_PREFS_KEY, null)
        }.getOrNull()
        val next = parseNextAlarm(
            raw,
            System.currentTimeMillis(),
            strings.getString(R.string.alarm_default_label),
        )
        val timeText = next?.timeText ?: strings.getString(R.string.widget_em_dash)
        val labelText = next?.label ?: strings.getString(R.string.widget_no_alarm)
        // Durum ikinci bir ogeyle degil RENKle anlatilir (§6): kurulu alarm
        // varsa `flame`, yoksa `ink_dim`.
        val armedColor = ContextCompat.getColor(context, R.color.widget_ember_flame)
        val idleColor = ContextCompat.getColor(context, R.color.widget_ember_ink_dim)
        val accent = if (next != null) armedColor else idleColor
        val ink = ContextCompat.getColor(context, R.color.widget_ember_ink)

        appWidgetIds.forEach { widgetId ->
            val dims = appWidgetManager.dimensions(ALARM_WIDGET_SIZE_SPEC, widgetId)
            val tier = alarmTier(dims.widthDp, dims.heightDp)
            val views = RemoteViews(context.packageName, R.layout.odak_alarm_widget).apply {
                setContentDescription(
                    R.id.alarm_widget_root,
                    strings.getString(R.string.widget_next_alarm),
                )
                setInt(
                    R.id.alarm_widget_card,
                    "setBackgroundResource",
                    listCardBackground(tier),
                )
                applyRootPadding(context, R.id.alarm_widget_card, listCardPaddingDp(tier))
                // Kusur 1: kok artik id tasidigi icin baglanabiliyor.
                // §1.5: TEK dokunma hedefi koktur, yani widget'in tamami.
                setOnClickPendingIntent(
                    R.id.alarm_widget_root,
                    WidgetDeepLink.pendingIntent(
                        context,
                        WidgetDeepLink.ROUTE_CLOCK,
                        widgetId,
                    ),
                )

                setTextViewText(R.id.alarm_widget_time, timeText)
                setTextColor(R.id.alarm_widget_time, accent)
                applySp(R.id.alarm_widget_time, alarmTimeSp(tier))
                setViewVisibility(
                    R.id.alarm_widget_time,
                    if (alarmTimeVisible(tier)) View.VISIBLE else View.GONE,
                )

                // K1 cekirdegi: can glifi. `setColorFilter` ImageView'da
                // `@RemotableViewMethod`tur; ikonun pasif tonu `ink_dim`dir.
                setViewVisibility(
                    R.id.alarm_widget_icon,
                    if (alarmIconVisible(tier)) View.VISIBLE else View.GONE,
                )
                setInt(R.id.alarm_widget_icon, "setColorFilter", accent)

                setTextViewText(R.id.alarm_widget_label, labelText)
                setTextColor(R.id.alarm_widget_label, ink)
                applySp(R.id.alarm_widget_label, alarmLabelSp(tier))
                setViewVisibility(
                    R.id.alarm_widget_label,
                    if (alarmLabelVisible(tier)) View.VISIBLE else View.GONE,
                )

                setViewVisibility(
                    R.id.alarm_widget_caption,
                    if (alarmCaptionVisible(tier)) View.VISIBLE else View.GONE,
                )
                setViewVisibility(
                    R.id.alarm_widget_divider,
                    if (alarmCaptionVisible(tier)) View.VISIBLE else View.GONE,
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
