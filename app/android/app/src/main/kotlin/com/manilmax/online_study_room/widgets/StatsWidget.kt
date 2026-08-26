package com.manilmax.online_study_room.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import com.manilmax.online_study_room.R
import es.antonborri.home_widget.HomeWidgetProvider

// ===========================================================================
// WP-755 · ILERLEME AILESI — paylasilan kademe sozlugu
//
// Uc widget ayni soruyu soruyor: "bir hedefe ne kadar kaldi?"
//   gunluk hedef      (`odak_stats_widget`)      -> bugunun yuzdesi
//   grup hedefi       (`odak_group_goal_widget`) -> grubun yuzdesi
//   sinav geri sayimi (`odak_countdown_widget`)  -> kalan gun
// Ailenin kimligi budur; asagidaki sozluk ucunun de PAYLASTIGI karardir.
//
// Sozlesme: `docs/tasarim/widget-tasarim-sistemi.md` §1 (kademe), §1.4
// (cekirdek), §2.6 (kart yaricapi), §3.4 (genislik modeli), §7 (on kural).
//
// 🔴 Neden burada, `WidgetCommon.kt`te degil: bu turda o dosya baska bir
// lane'in okuma zeminidir ve ayni anda iki ajan yazamaz. Ad oneki
// (`progress*` / `PROGRESS_*`) bilerek aile-ozgudur, boylece komsu lane'lerin
// ayni paketteki bildirimleriyle CAKISMAZ.
// ===========================================================================

/**
 * Kademe (§1.1). Ad kamp dunyasindan: K1 Kor · K2 Kutuk · K3 Ocak · K4 Kamp.
 *
 * Kademe [WidgetSizeClass]ten TEK BASINA turetilemez: K1 ile K2 ayni
 * (NARROW, SHORT) sinifidir ve onlari yalniz launcher'in bildirdigi GENISLIK
 * ayirir. Sayac widget'i ayni ayrimi zaten `widthDp in 1 until defaultWidthDp`
 * daliyla yapiyor (WP-718); burasi o davranisi ADLANDIRIR, degistirmez.
 */
internal enum class ProgressWidgetTier { K1, K2, K3, K4 }

internal fun progressWidgetTier(
    size: WidgetSizeClass,
    widthDp: Int,
    defaultWidthDp: Int,
): ProgressWidgetTier = when {
    // 🔴 GENISLIK ONCE bakilir, yukseklik sonra. Sahibin istedigi 1x2 kutusu
    // (40x110dp) yukseklikte TALL'dur ama 36dp'lik ic genisligine ne baslik
    // satiri ne yatay bir yardimci metin girer - yukseklige once bakan bir
    // siniflandirma orada K4 cizer ve butun metin uc noktaya iner. Dar kutuda
    // tasinabilen tek sey CEKIRDEKtir.
    widthDp in 1 until defaultWidthDp -> ProgressWidgetTier.K1
    size.height == WidgetHeightClass.TALL -> ProgressWidgetTier.K4
    size.height == WidgetHeightClass.MEDIUM -> ProgressWidgetTier.K3
    else -> ProgressWidgetTier.K2
}

/**
 * §1.4 / §3.4: K1 cekirdegi en fazla UC karakterdir.
 *
 * 40x40dp kutu, 2dp dolgu, taban sikistirma (k = 0.85 x 0.87 = 0.74):
 *   3 karakter -> 21sp (kahraman sayi) · 4 karakter -> 15sp (fisilti)
 * Yani `100%` bir K1 cekirdegi OLAMAZ; o durumda cekirdek GLIFtir.
 */
internal const val PROGRESS_CORE_MAX_CHARS = 3

/** §6 K1: kutunun izin verdigi 21sp'nin hemen altinda kalan deger. */
internal const val PROGRESS_K1_CORE_SP = 20f

/** §6 K2: 110x40dp kutuda cekirdek payina sigan deger. */
internal const val PROGRESS_K2_CORE_SP = 24f

/**
 * K3/K4 cekirdek puntosu.
 *
 * 🔴 Tavan YATAY degil DIKEY butceden gelir: 110dp yuksekligindeki bir K4
 * kutusunda baslik + ayrac + cekirdek + gosterge + iki satir ust uste durur
 * ve 24sp'nin ustu o yigini tasirir (aritmetigi
 * `WidgetSizeClassWp699Test.stats_hicbir_boyutta_kirpilmaz`). Bu yuzden
 * kademe buyudukce buyuyen sey punto degil BILGIdir - §6'daki referans
 * tasarimin K2 -> K3 gecisinde soyledigi seyin aynisi.
 *
 * Ayrica K2'nin ALTINA inmez: 2x1'den 2x2'ye buyuten kullanici sayinin
 * kuculdugunu gormemeli.
 */
internal const val PROGRESS_K3_CORE_SP = 24f

/**
 * §2.6: kart yaricapi KADEMEYE baglidir. 40dp yuksekligindeki bir kutuda
 * 20dp yaricap koselerin tamamini yer; kart karta degil HAPA doner.
 */
internal fun progressCardIsTight(tier: ProgressWidgetTier): Boolean =
    tier == ProgressWidgetTier.K1 || tier == ProgressWidgetTier.K2

/** §1.3: baslik ILK dusen ogedir; yalniz en buyuk kademede cizilir. */
internal fun progressHeaderVisible(tier: ProgressWidgetTier): Boolean =
    tier == ProgressWidgetTier.K4

/**
 * §1.2: K1'de EN FAZLA BIR oge vardir - cekirdek. Bu kapi olmadan 1x2 gibi
 * dar ama UZUN bir kutuda yukseklige bagli satirlar (gun ozeti, seri, sinav
 * adi) acilir ve 36dp'lik ic genislikte hepsi uc noktaya iner.
 */
internal fun progressOnlyCore(tier: ProgressWidgetTier): Boolean =
    tier == ProgressWidgetTier.K1

/**
 * §1.2: K1/K2'de GRAFIK yoktur. 4dp'lik bir cubuk bile 40dp'lik dikey
 * butcede cekirdegin puntosunu yer - sahibin gordugu 15sp'lik yuzde tam
 * olarak bu takasin sonucuydu.
 */
internal fun progressGaugeVisible(tier: ProgressWidgetTier): Boolean =
    tier == ProgressWidgetTier.K3 || tier == ProgressWidgetTier.K4

/**
 * Cekirdegin turu (§1.4).
 *
 * - [NUMBER] — sayi cekirdegi.
 * - [GLYPH_EMPTY] — veri YOK. `0%` bir olcum degil, olcumun yoklugudur;
 *   sifir gostermek yalan olurdu. Widget'in kendi ikonu cizilir.
 * - [GLYPH_FULL] — sayi K1'in uc karakterine sigmiyor (`100%`). Kayip degil,
 *   durust bir karar: dolmus bir hedefi anlatan en guclu isaret zaten sayi
 *   degildir.
 */
internal enum class ProgressCoreKind { NUMBER, GLYPH_EMPTY, GLYPH_FULL }

internal fun progressCoreKind(
    tier: ProgressWidgetTier,
    hasData: Boolean,
    coreText: String,
): ProgressCoreKind = when {
    !hasData -> ProgressCoreKind.GLYPH_EMPTY
    tier == ProgressWidgetTier.K1 &&
        coreText.trim().length > PROGRESS_CORE_MAX_CHARS -> ProgressCoreKind.GLYPH_FULL
    else -> ProgressCoreKind.NUMBER
}

/** §4.2 seri alevi. Uc AYRI dosya; secim saf kalir ve JVM'de olculur. */
internal enum class ProgressFlame { OFF, ON, PEAK }

internal fun progressFlame(percent: Int): ProgressFlame = when {
    percent >= 100 -> ProgressFlame.PEAK
    percent > 0 -> ProgressFlame.ON
    else -> ProgressFlame.OFF
}

internal fun progressFlameRes(flame: ProgressFlame): Int = when (flame) {
    ProgressFlame.OFF -> R.drawable.widget_flame_off
    ProgressFlame.ON -> R.drawable.widget_flame_on
    ProgressFlame.PEAK -> R.drawable.widget_flame_peak
}

/** `"72%"` -> 72. Bozuk/eksik deger 0 sayilir; widget asla catlamaz. */
internal fun progressPercentValue(raw: String?): Int =
    raw?.trim()?.removeSuffix("%")?.trim()?.toIntOrNull()?.coerceIn(0, 100) ?: 0

// ===========================================================================
// Gunluk hedef — `odak_stats_widget`
//
// CEKIRDEK (§1.4, K1'de tek basina hayatta kalan bilgi): **gunluk hedef
// yuzdesi**. `72%` uc karakterdir ve sigar; `100%` DORT karakterdir ve
// sigmaz - o durumda cekirdek `widget_flame_peak` glifine doner (§4.2
// "rekor / bugun tamam"). Boylece K1'de ya bir sayi ya bir alev vardir;
// hicbir zaman kirpilmis bir sayi yoktur.
// ===========================================================================

internal fun statsDetailVisible(height: WidgetHeightClass): Boolean =
    height != WidgetHeightClass.SHORT

internal fun statsStreakVisible(height: WidgetHeightClass): Boolean =
    height == WidgetHeightClass.TALL

/**
 * WP-757 - seri satirinin GENISLIK kapisi.
 *
 * Olculen kusur (emulator, API 33, 110x110dp kutu): `Gunluk hedef serisi:
 * 12 gun` satirinin 13 karakteri uc noktaya indi. Yukseklik kurali tek
 * basina yetmiyor - o kutu TALL'dir ama 110dp genislikte 26 karakterlik bir
 * satir 11sp tabaninda bile sigmaz (§3.4: (110-2*5-8)/(0.60*26) = 5.9sp).
 * §1.3 bu durumda ne yapilacagini soyluyor: yardimci satir DUSER.
 */
internal fun statsStreakFitsWidth(width: WidgetWidthClass): Boolean =
    width != WidgetWidthClass.NARROW

/**
 * WP-730: baslik yalniz TALL kutuda cizilir. 2x2'lik (MEDIUM) kutunun dikey
 * butcesi olculdu: yuzde + cubuk + gun ozeti zaten 80dp'nin kullanilabilir
 * 64dp'sini doldurur. Baslik da eklenirse ya satirlar kirpilir ya da yuzde
 * okunmaz puntoya duser -- sahibin sikayet ettigi tam sey.
 *
 * WP-755: stats'ta TALL == K4 oldugu icin bu kural [progressHeaderVisible]
 * ile birebir ayni seyi soyler; ikisi ayrisirsa aile dagilir.
 */
internal fun statsTitleVisible(height: WidgetHeightClass): Boolean =
    height == WidgetHeightClass.TALL

/** Baslik puntosu: TALL kutuda bile 13sp'yi asmaz (dikey butce). */
internal fun statsTitleSp(size: WidgetSizeClass): Float =
    minOf(WidgetTypography.statsTitle.of(size.width), 13f)

/** Satir puntosu: gun ozeti + seri satiri 12sp tavaninda kalir. */
internal fun statsRowSp(size: WidgetSizeClass): Float =
    minOf(WidgetTypography.statsRow.of(size.width), 12f)

/**
 * Cekirdek puntosu.
 *
 * 🔴 WP-755'te SHORT dali degisti (tek bir 15sp -> K1 20sp / K2 24sp). Eski
 * deger yuzdeyi 4dp'lik cubukla ayni 40dp'ye sikistirmaktan geliyordu; yeni
 * kademe butcesi (§1.2) K1/K2'de grafik cizmez, dolayisiyla dikey butcenin
 * tamami cekirdegin olur.
 *
 * [widthDp] varsayilanlidir: K1 ile K2 ayni boyut sinifidir, onlari yalniz
 * launcher'in bildirdigi genislik ayirir.
 */
internal fun statsValueSp(
    size: WidgetSizeClass,
    widthDp: Int = WIDGET_STATS_DEFAULT_WIDTH_DP,
): Float = when (progressWidgetTier(size, widthDp, WIDGET_STATS_DEFAULT_WIDTH_DP)) {
    ProgressWidgetTier.K1 -> PROGRESS_K1_CORE_SP
    ProgressWidgetTier.K2 -> PROGRESS_K2_CORE_SP
    else -> PROGRESS_K3_CORE_SP
}

class StudyStatsWidgetProvider : HomeWidgetProvider() {
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
        // Anahtarin VARLIGI, veriyi sifirdan ayirir: widget uygulama hic
        // acilmadan da eklenebilir ve o hal `0%` DEGILDIR.
        val hasData = runCatching {
            widgetData.contains(StudyWidgetKeys.DailyGoalPercent)
        }.getOrDefault(false)
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.odak_stats_widget).apply {
                setContentDescription(
                    R.id.stats_widget_root,
                    strings.getString(R.string.cd_stats_widget),
                )
                val dimensions = appWidgetManager.dimensions(WidgetSizeSpecs.stats, widgetId)
                val size = dimensions.sizeClass
                val tier = progressWidgetTier(
                    size,
                    dimensions.widthDp,
                    WIDGET_STATS_DEFAULT_WIDTH_DP,
                )
                val percentText = widgetData.text(StudyWidgetKeys.DailyGoalPercent, "0%")
                val percent = progressPercentValue(percentText)
                val core = progressCoreKind(tier, hasData, percentText)

                // §2.6 - kart yaricapi kademeye bagli.
                setInt(
                    R.id.stats_widget_root,
                    "setBackgroundResource",
                    if (progressCardIsTight(tier)) {
                        R.drawable.widget_card_bg_tight
                    } else {
                        R.drawable.widget_card_bg
                    },
                )

                setTextViewText(
                    R.id.stats_widget_title,
                    strings.getString(R.string.widget_daily_goal),
                )
                setTextViewText(R.id.stats_widget_today, percentText)
                setProgressBar(
                    R.id.stats_goal_progress,
                    WidgetDesign.PROGRESS_MAX,
                    WidgetDesign.barPercent(percent / 100.0),
                    false,
                )
                setOnClickPendingIntent(
                    R.id.stats_widget_root,
                    WidgetDeepLink.pendingIntent(
                        context,
                        WidgetDeepLink.ROUTE_STATS,
                        widgetId,
                    ),
                )
                setTextViewText(
                    R.id.stats_widget_week,
                    widgetData.text(
                        StudyWidgetKeys.DailyGoalDetail,
                        strings.getString(R.string.widget_goal_detail_zero),
                    ),
                )
                setTextViewText(
                    R.id.stats_widget_streak,
                    widgetData.text(
                        StudyWidgetKeys.StatsStreak,
                        strings.getString(R.string.widget_streak_zero),
                    ),
                )
                // §1.3 "yardimci etiket ya ikona doner ya sayiya emilir":
                // seri satirinin basindaki alev, "Seri:" sozcugunun gorsel
                // karsiligidir ve durumu RENKle soyler.
                setImageViewResource(
                    R.id.stats_widget_streak_flame,
                    progressFlameRes(progressFlame(percent)),
                )
                // Cekirdek: sayi mi glif mi? Ikisi ayni yerde durur; ayni
                // anda yalniz biri gorunur.
                setViewVisibility(
                    R.id.stats_widget_today,
                    if (core == ProgressCoreKind.NUMBER) View.VISIBLE else View.GONE,
                )
                setViewVisibility(
                    R.id.stats_widget_core_glyph,
                    if (core == ProgressCoreKind.NUMBER) View.GONE else View.VISIBLE,
                )
                setImageViewResource(
                    R.id.stats_widget_core_glyph,
                    if (core == ProgressCoreKind.GLYPH_FULL) {
                        R.drawable.widget_flame_peak
                    } else {
                        R.drawable.widget_ic_stats
                    },
                )
                // WP-699: iki satır artık AYRI eşiklerde açılır. Eskiden ikisi
                // birden tek `compact` bayrağına bağlıydı; 2×2'de ikisi de
                // taşıyor, 2×3'te ikisi birden gelip sıkışıyordu.
                // 🔴 Yukseklik kurallari TEK BASINA yetmez: 1x2 (40x110dp)
                // kutu TALL'dur ama 36dp ic genisliginde bu satirlarin hepsi
                // uc noktaya iner. Kademe kapisi (§1.2) onlerinde durur.
                setViewVisibility(
                    R.id.stats_widget_week,
                    if (statsDetailVisible(size.height) && !progressOnlyCore(tier)) {
                        View.VISIBLE
                    } else {
                        View.GONE
                    },
                )
                setViewVisibility(
                    R.id.stats_widget_streak_row,
                    if (statsStreakVisible(size.height) &&
                        statsStreakFitsWidth(size.width) &&
                        !progressOnlyCore(tier)
                    ) {
                        View.VISIBLE
                    } else {
                        View.GONE
                    },
                )
                setViewVisibility(
                    R.id.stats_widget_header,
                    if (statsTitleVisible(size.height) && progressHeaderVisible(tier)) {
                        View.VISIBLE
                    } else {
                        View.GONE
                    },
                )
                setViewVisibility(
                    R.id.stats_widget_divider,
                    if (progressHeaderVisible(tier)) View.VISIBLE else View.GONE,
                )
                setViewVisibility(
                    R.id.stats_goal_progress,
                    if (progressGaugeVisible(tier)) View.VISIBLE else View.GONE,
                )
                applySp(R.id.stats_widget_title, statsTitleSp(size))
                applySp(R.id.stats_widget_today, statsValueSp(size, dimensions.widthDp))
                applySp(R.id.stats_widget_week, statsRowSp(size))
                // 🔴 Seri satiri ailenin EN AZ onemli satiridir ve en uzunudur
                // (`Gunluk hedef serisi: 12 gun`, 27 karakter). 12sp ile 180dp
                // kutuda 167dp isterken 158dp yer var - yani ORADA da kirpma
                // sinirindaydi. §3.3 tabani (11sp) ile 155dp'ye iner ve satir
                // 3x2'de KORUNUR; 2x2'de zaten `statsStreakFitsWidth` duser.
                applySp(R.id.stats_widget_streak, WIDGET_MIN_TEXT_SP)
                applyRootPadding(
                    context,
                    R.id.stats_widget_root,
                    if (progressCardIsTight(tier)) 2 else widgetRootPaddingDp(3, size.height),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
