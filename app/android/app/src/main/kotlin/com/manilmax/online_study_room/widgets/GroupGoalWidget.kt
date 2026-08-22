package com.manilmax.online_study_room.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import com.manilmax.online_study_room.R
import es.antonborri.home_widget.HomeWidgetProvider

// ===========================================================================
// Grup hedefi — `odak_group_goal_widget`
//
// Ailenin en "grafik" uyesi: ters U yayi tasiyan iki widget'tan biri
// (digeri sinav geri sayimi). Kademe sozlugu `StatsWidget.kt` basindadir.
//
// CEKIRDEK (§1.4): grup hedef yuzdesi. `72%` uc karakter -> K1'de sigar;
// `100%` dort karakter -> `widget_flame_peak` glifine doner.
//
// 🔴 BOS DURUM ("Bir gruba katil") kademe merdiveninde NEREDE:
// Bos durum merdivene YENI BIR OGE olarak girmez - CEKIRDEGIN yerine gecer.
// Gerekce: `0%` bir olcum degil, olcumun yoklugudur; grubu olmayan kisiye
// sifir gostermek ona "hedefinin %0'indasin" demektir. §1.4 bu hal icin
// zaten bir yol yaziyor: "sayi yoksa cekirdek gliftir". Dolayisiyla
//   • cekirdek -> cadir ikonu (`widget_ic_group_goal`), her kademede
//   • grafik   -> yay GIZLENIR (bos bir iz "olculdu, sifir cikti" gibi
//                 okunur; ayni doktrin geri sayimda da yazili)
//   • detay    -> "Bir gruba katil" satiri, kendi sirasinda (K3/K4)
// Yani bos durum, dolu durumun kademe sirasini hic bozmaz.
// ===========================================================================

internal fun groupGoalDetailVisible(height: WidgetHeightClass): Boolean =
    height != WidgetHeightClass.SHORT

/** §1.3: baslik ilk dusen ogedir; grup hedefinde yalniz K4'te cizilir. */
internal fun groupGoalHeaderVisible(tier: ProgressWidgetTier): Boolean =
    progressHeaderVisible(tier)

/**
 * Yay yalniz K3/K4'te ve yalniz VERI VARKEN cizilir. Bos bir iz "olculdu ve
 * sifir cikti" demektir; grubu olmayan kullanici icin bu yanlistir.
 */
internal fun groupGoalArcVisible(tier: ProgressWidgetTier, hasData: Boolean): Boolean =
    progressGaugeVisible(tier) && hasData

/**
 * Yuzde KAHRAMAN mi, yayin okuma degeri mi?
 *
 * WP-730 gerekcesi: yay varken vurgu rengi (`flame`) YAYIN DOLGUSUNDA
 * tasinir, yuzde okunur `ink` tonuna alinir - iki turuncu yan yana
 * hiyerarsiyi duzler. Yay dustugu kademede (K1/K2) ise vurguyu tasiyacak
 * baska bir sey kalmaz; orada sayinin kendisi kahramandir ve `flame` olur.
 * Aile boylece her kademede TEK bir turuncu odak tasir.
 */
internal fun groupGoalPercentIsHero(tier: ProgressWidgetTier): Boolean =
    !progressGaugeVisible(tier)

/**
 * Cekirdek puntosu. Aile boyunca AYNI merdiven kullanilir; grup hedefinin
 * sayisi K3/K4'te yayin agzinda durur ve yatay butceyi yayla paylasir, ama
 * yay 48dp yuksekliginde oldugu icin dikey butce sayiyi degil YAYI baglar.
 */
internal fun groupGoalPercentSp(
    size: WidgetSizeClass,
    widthDp: Int = WIDGET_GROUP_GOAL_DEFAULT_WIDTH_DP,
): Float = when (
    progressWidgetTier(size, widthDp, WIDGET_GROUP_GOAL_DEFAULT_WIDTH_DP)
) {
    ProgressWidgetTier.K1 -> PROGRESS_K1_CORE_SP
    ProgressWidgetTier.K2 -> PROGRESS_K2_CORE_SP
    else -> PROGRESS_K3_CORE_SP
}

class GroupGoalWidgetProvider : HomeWidgetProvider() {
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
        // Anahtarin VARLIGI, veriyi sifirdan ayirir.
        val hasData = runCatching {
            widgetData.contains(StudyWidgetKeys.GroupGoalPercent)
        }.getOrDefault(false)
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.odak_group_goal_widget).apply {
                setContentDescription(
                    R.id.group_goal_widget_root,
                    strings.getString(R.string.cd_group_goal_widget),
                )
                val dimensions = appWidgetManager.dimensions(WidgetSizeSpecs.groupGoal, widgetId)
                val size = dimensions.sizeClass
                val tier = progressWidgetTier(
                    size,
                    dimensions.widthDp,
                    WIDGET_GROUP_GOAL_DEFAULT_WIDTH_DP,
                )
                val percentText = widgetData.text(StudyWidgetKeys.GroupGoalPercent, "0%")
                val progress = progressPercentValue(percentText)
                val core = progressCoreKind(tier, hasData, percentText)

                // §2.6 - kart yaricapi kademeye bagli.
                setInt(
                    R.id.group_goal_widget_root,
                    "setBackgroundResource",
                    if (progressCardIsTight(tier)) {
                        R.drawable.widget_card_bg_tight
                    } else {
                        R.drawable.widget_card_bg
                    },
                )

                setTextViewText(
                    R.id.group_goal_widget_title,
                    strings.getString(R.string.widget_group_goal),
                )
                setTextViewText(R.id.group_goal_widget_percent, percentText)
                setProgressBar(
                    R.id.group_goal_widget_progress,
                    WidgetDesign.PROGRESS_MAX,
                    WidgetDesign.arcPercent(progress / 100.0),
                    false,
                )
                setTextViewText(
                    R.id.group_goal_widget_detail,
                    widgetData.text(
                        StudyWidgetKeys.GroupGoalDetail,
                        strings.getString(R.string.widget_join_group),
                    ),
                )
                setOnClickPendingIntent(
                    R.id.group_goal_widget_root,
                    WidgetDeepLink.pendingIntent(
                        context,
                        WidgetDeepLink.ROUTE_GROUP,
                        widgetId,
                    ),
                )
                // Cekirdek: sayi mi glif mi? Ayni yerde dururlar; ayni anda
                // yalniz biri gorunur.
                setViewVisibility(
                    R.id.group_goal_widget_percent,
                    if (core == ProgressCoreKind.NUMBER) View.VISIBLE else View.GONE,
                )
                setViewVisibility(
                    R.id.group_goal_widget_core_glyph,
                    if (core == ProgressCoreKind.NUMBER) View.GONE else View.VISIBLE,
                )
                setImageViewResource(
                    R.id.group_goal_widget_core_glyph,
                    if (core == ProgressCoreKind.GLYPH_FULL) {
                        R.drawable.widget_flame_peak
                    } else {
                        R.drawable.widget_ic_group_goal
                    },
                )
                setTextColor(
                    R.id.group_goal_widget_percent,
                    context.getColor(
                        if (groupGoalPercentIsHero(tier)) {
                            R.color.widget_ember_flame
                        } else {
                            R.color.widget_ember_ink
                        },
                    ),
                )
                setViewVisibility(
                    R.id.group_goal_widget_progress,
                    if (groupGoalArcVisible(tier, hasData)) View.VISIBLE else View.GONE,
                )
                // 🔴 Yukseklik kurali TEK BASINA yetmez: 1x2 (40x110dp) kutu
                // yukseklikte buyuktur ama 36dp ic genisliginde detay satiri
                // uc noktaya iner. Kademe kapisi (§1.2) onunde durur.
                setViewVisibility(
                    R.id.group_goal_widget_detail,
                    if (groupGoalDetailVisible(size.height) && !progressOnlyCore(tier)) {
                        View.VISIBLE
                    } else {
                        View.GONE
                    },
                )
                setViewVisibility(
                    R.id.group_goal_widget_header,
                    if (groupGoalHeaderVisible(tier)) View.VISIBLE else View.GONE,
                )
                setViewVisibility(
                    R.id.group_goal_widget_divider,
                    if (groupGoalHeaderVisible(tier)) View.VISIBLE else View.GONE,
                )
                applySp(
                    R.id.group_goal_widget_title,
                    minOf(WidgetTypography.statsTitle.of(size.width), 12f),
                )
                applySp(
                    R.id.group_goal_widget_percent,
                    groupGoalPercentSp(size, dimensions.widthDp),
                )
                applySp(
                    R.id.group_goal_widget_detail,
                    minOf(WidgetTypography.statsRow.of(size.width), 12f),
                )
                applyRootPadding(
                    context,
                    R.id.group_goal_widget_root,
                    if (progressCardIsTight(tier)) 2 else widgetRootPaddingDp(6, size.height),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
