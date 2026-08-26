package com.manilmax.online_study_room.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import com.manilmax.online_study_room.R
import es.antonborri.home_widget.HomeWidgetProvider

// ---------------------------------------------------------------------------
// WP-756 - LISTE ailesinin (siralama / gorev / alarm) ORTAK kademe sozlugu.
//
// Sozlesme: `docs/tasarim/widget-tasarim-sistemi.md` §1.1-1.5.
//
// 🔴 Bu blok mantiken `WidgetCommon.kt`e aittir; bu turda o dosya baska bir
// ajanin kilidinde oldugu icin ailenin ilk dosyasinda duruyor. Uc aile de
// indikten sonra paylasilan zemine tasinmalidir (LIDERE BILDIRILDI). Adi
// bilerek `List...` ile baslar: bir land-grab degil, aile kapsamli bir sozluk.
// ---------------------------------------------------------------------------

/** K1 Kor (40x40) · K2 Kutuk (110x40) · K3 Ocak (110x110) · K4 Kamp (180x110+). */
internal enum class ListWidgetTier { K1, K2, K3, K4 }

/**
 * §2.6: kart yaricapi KADEMEYE baglidir. 40x40dp'lik bir K1 kutusunda 20dp
 * yaricap koselerin TAMAMINI yer ve kart karta degil hapa doner.
 * Secim kodda yapilir: `View.setBackgroundResource` `@RemotableViewMethod`tur.
 */
internal fun listCardBackground(tier: ListWidgetTier): Int = when (tier) {
    ListWidgetTier.K1, ListWidgetTier.K2 -> R.drawable.widget_card_bg_tight
    ListWidgetTier.K3, ListWidgetTier.K4 -> R.drawable.widget_card_bg
}

/** Kok dolgu kademeyle buyur; K1'de her dp icerige gider. */
internal fun listCardPaddingDp(tier: ListWidgetTier): Int = when (tier) {
    ListWidgetTier.K1 -> 2
    ListWidgetTier.K2 -> 4
    ListWidgetTier.K3 -> 8
    ListWidgetTier.K4 -> 10
}

/**
 * K1'in ust siniri. Launcher hucre olcusu `70n - 30` oldugu icin pratikte
 * yalniz 40 / 110 / 180 / 250dp genislikler olusur; 110dp'nin altindaki tek
 * deger BIR hucredir. Yani "K1 = bir hucre genisliginde".
 */
internal const val WIDGET_LIST_ONE_CELL_MAX_WIDTH_DP = 110

/**
 * Cekirdek puntosu (§3.4 modeli):
 *   (40 - 2*2 - 8) / (0.60 * 0.85 * 0.87 * 3) = 21sp  ->  20sp kullanilir.
 * Uc karakterlik sinirin sayisal karsiligi budur; `ListFamilyRedesignWp756Test`
 * bunu `widgetMaxSp` ile YENIDEN kurar.
 */
internal const val WIDGET_LIST_CORE_SP = 20f

/** Cekirdegin yanindaki yardimci satir. §3.3 tabani: 11sp. */
internal const val WIDGET_LIST_CORE_HINT_SP = 11f

/** Sayi cekirdegi en fazla UC karakterdir (§1.4 / §7-1). */
internal const val WIDGET_LIST_CORE_MAX_CHARS = 3

// ---------------------------------------------------------------------------
// Kamp Siralamasi
//
// CEKIRDEK: kullanicinin KENDI sirasi (`#3`). Kod bunu zaten biliyordu
// (`leaderboardShowsMyRank`); WP-756 o zekayi kademe sistemine oturtur.
// ---------------------------------------------------------------------------

/** Kısa halde tek satır kalır; o satır listenin başı değil KULLANICININ sırasıdır. */
internal fun leaderboardShowsMyRank(height: WidgetHeightClass): Boolean =
    height == WidgetHeightClass.SHORT

internal fun leaderboardRow2Visible(height: WidgetHeightClass): Boolean =
    height != WidgetHeightClass.SHORT

internal fun leaderboardRow3Visible(height: WidgetHeightClass): Boolean =
    height == WidgetHeightClass.TALL

/** Tire/bos placeholder satirlari artik gercek bir siralama satiri gibi cizilmez. */
internal fun leaderboardRowHasContent(value: String): Boolean =
    value.trim().let { it.isNotEmpty() && it != "-" && it != "\u2014" }

/** `#2` ya da `#2 (detay)` bicimindeki kendi sira aynasini ilk uce esler. */
internal fun leaderboardHighlightedPosition(myRank: String): Int? =
    Regex("^#([1-3])(?:\\b|\\s|\\u00B7)")
        .find(myRank.trim())
        ?.groupValues
        ?.get(1)
        ?.toIntOrNull()

/**
 * K1 CEKIRDEGI. Dart tarafi `#N` yazar (`study_providers.dart` `_rankLabel`);
 * sirasi yoksa uzun bir cumle gonderir ("Siralama olusunca burada gorunur").
 *
 * Donen deger en fazla [WIDGET_LIST_CORE_MAX_CHARS] karakterdir:
 *   1..99  -> `#7`, `#42`
 *   >=100  -> `99+`   (dort karakterlik `#100` 40dp kutuda 12sp'ye duserdi)
 * Sira cozulemezse `null`; o zaman cekirdek GLIFe duser (kupa ikonu). `0`
 * yazmak yanlis olurdu: sifirinci sira diye bir sey yok.
 */
internal fun leaderboardCoreRank(myRank: String): String? {
    val rank = Regex("^#(\\d{1,6})").find(myRank.trim())
        ?.groupValues
        ?.get(1)
        ?.toIntOrNull()
        ?: return null
    if (rank <= 0) return null
    return if (rank <= 99) "#$rank" else "99+"
}

/**
 * Kademe. K1 yalnizca GENISLIKten, K2/K3/K4 yukseklik sinifindan cikar;
 * yani var olan `leaderboardShowsMyRank` kurali K2'nin TANIMI olur ve ikisi
 * ayrisamaz.
 */
internal fun leaderboardTier(widthDp: Int, heightDp: Int): ListWidgetTier {
    if (widthDp in 1 until WIDGET_LIST_ONE_CELL_MAX_WIDTH_DP) return ListWidgetTier.K1
    val height = widgetSizeClass(WidgetSizeSpecs.leaderboard, widthDp, heightDp).height
    return when {
        leaderboardShowsMyRank(height) -> ListWidgetTier.K2
        height == WidgetHeightClass.TALL -> ListWidgetTier.K4
        else -> ListWidgetTier.K3
    }
}

/** K3/K4'te liste cizilir; K1/K2'de cekirdek seridi. */
internal fun leaderboardListVisible(tier: ListWidgetTier): Boolean =
    tier == ListWidgetTier.K3 || tier == ListWidgetTier.K4

// ---------------------------------------------------------------------------
// WP-757 - EKRANDA OLCULEN uc kusurun kapisi (emulator, API 33, AppWidgetHost)
//
// 1. Kart kutuyu DOLDURMUYORDU: 110x110dp kutuda kart 93.8dp (%85), 40x40'ta
//    30.5dp (%76). `leaderboard_widget_card` `wrap_content` idi ve kok
//    `center_vertical` ile onu ortaliyordu; ana ekranda widget kendi
//    hucresinden kucuk gorunuyor, komsu widget'larla hizalanmiyordu.
// 2. SATIRIN SURESI kirpiliyordu: `Muhammed Muhlis - 4 sa 12 dk` TEK bir
//    `TextView`di; uc noktaya ilk giden sey her zaman SAG uctaki SURE oluyordu.
//    Bir siralama widget'inda kirpilacak en son sey suredir.
// 3. Baslik 110dp genislikte kirpiliyordu (`Kamp siral...`, 5 karakter) ve
//    ustelik ucuncu siranin yerini yiyordu.
// ---------------------------------------------------------------------------

/** Dart tarafinin urettigi satir bicimi: ad + orta nokta + sure. */
internal const val LEADERBOARD_ROW_SEPARATOR = " \u00B7 "

/** Rozet genisligi (dp) - `odak_leaderboard_widget.xml` ile ayni sayi. */
internal const val LEADERBOARD_RANK_DP = 22

/** Rozet ile ad, ad ile sure arasindaki bosluk (dp). */
internal const val LEADERBOARD_ROW_GAP_DP = 6

/** Sure sutununun puntosu; `sans-serif-condensed` + 0.85 ile cizilir. */
internal const val LEADERBOARD_VALUE_SP = 11f

/** `12 sa 30 dk` - Turkce en uzun makul sure dizisi. */
internal const val LEADERBOARD_VALUE_MAX_CHARS = 11

/** Sure gorunurken addan geriye kalmasi gereken en az karakter. */
internal const val LEADERBOARD_NAME_MIN_CHARS = 6

/** Satirin ad kismi. Ayirici yoksa satirin tamami addir. */
internal fun leaderboardRowName(raw: String): String =
    raw.substringBefore(LEADERBOARD_ROW_SEPARATOR).trim()

/** Satirin sure kismi. Ayirici yoksa `null` (yer tutucu satirlar). */
internal fun leaderboardRowValue(raw: String): String? =
    if (raw.contains(LEADERBOARD_ROW_SEPARATOR)) {
        raw.substringAfter(LEADERBOARD_ROW_SEPARATOR).trim().takeIf { it.isNotEmpty() }
    } else {
        null
    }

/**
 * Sure sutunu SIGIYOR mu? (§3.4 butcesi, `widgetMaxSp` ile ayni model.)
 *
 * Sure kirpilmaz - ya tam cizilir ya hic cizilmez. Sigmasi icin addan da en
 * az [LEADERBOARD_NAME_MIN_CHARS] karakter kalmalidir; yoksa satir "sure ve
 * bir harf" olurdu.
 */
internal fun leaderboardValueVisible(
    tier: ListWidgetTier,
    widthDp: Int,
    rowSp: Float,
): Boolean {
    if (!leaderboardListVisible(tier)) return false
    val usable = widthDp - 2f * listCardPaddingDp(tier) -
        LEADERBOARD_RANK_DP - 2f * LEADERBOARD_ROW_GAP_DP
    val valueDp = WIDGET_GLYPH_ADVANCE * WIDGET_TEXT_SCALE_X_MIN * WIDGET_CONDENSED_ADVANCE *
        LEADERBOARD_VALUE_SP * LEADERBOARD_VALUE_MAX_CHARS
    val nameDp = WIDGET_PROSE_ADVANCE * rowSp * LEADERBOARD_NAME_MIN_CHARS
    return usable >= valueDp + nameDp
}

/**
 * §1.3: baslik ILK duser. 110dp genislikte `Kamp siralamasi` (15 karakter)
 * 13sp ile 117dp ister, kutuda 74dp vardir - yani baslik ORADA ZATEN
 * kirpiliyordu. Dusurulunce yerine UCUNCU SIRA gelir: bilgi kaybi degil takas.
 */
internal fun leaderboardHeaderVisible(tier: ListWidgetTier, widthDp: Int): Boolean =
    leaderboardListVisible(tier) && widthDp >= LEADERBOARD_HEADER_MIN_WIDTH_DP

/**
 * Basligin sigdigi en kucuk kutu.
 *
 * `Kamp siralamasi` 15 karakter, K3 basligi 13sp. Duz metin ilerlemesiyle
 * (bkz. [WIDGET_PROSE_ADVANCE], cihazda olculdu): 0.47 x 13 x 15 = 92dp.
 * Yaninda 14dp ikon, 6dp bosluk ve 2 x 8dp kart dolgusu durur:
 *   92 + 14 + 6 + 16 = 128dp.
 *
 * Cihaz olcumu ayni yeri gosteriyor: 110dp kutuda baslik 5 karakter kirpildi,
 * 180dp kutuda kirpilmadi. Launcher hucre olculeri `70n - 30` oldugu icin bu
 * esik pratikte "2 hucre genislikte baslik YOK, 3 hucrede VAR" demektir.
 */
internal const val LEADERBOARD_HEADER_MIN_WIDTH_DP = 128

/** Baslik dustugunde acilan ucuncu satir. */
internal fun leaderboardRow3Drawn(
    height: WidgetHeightClass,
    headerVisible: Boolean,
): Boolean = leaderboardRow3Visible(height) ||
    (!headerVisible && height != WidgetHeightClass.SHORT)

private val LEADERBOARD_ROW_CONTAINERS = intArrayOf(
    R.id.leaderboard_widget_row_container_1,
    R.id.leaderboard_widget_row_container_2,
    R.id.leaderboard_widget_row_container_3,
)

private val LEADERBOARD_RANKS = intArrayOf(
    R.id.leaderboard_widget_rank_1,
    R.id.leaderboard_widget_rank_2,
    R.id.leaderboard_widget_rank_3,
)

private val LEADERBOARD_ROWS = intArrayOf(
    R.id.leaderboard_widget_row_1,
    R.id.leaderboard_widget_row_2,
    R.id.leaderboard_widget_row_3,
)

private val LEADERBOARD_VALUES = intArrayOf(
    R.id.leaderboard_widget_value_1,
    R.id.leaderboard_widget_value_2,
    R.id.leaderboard_widget_value_3,
)

class GroupLeaderboardWidgetProvider : HomeWidgetProvider() {
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
        val ink = ContextCompat.getColor(context, R.color.widget_ember_ink)
        val inkDim = ContextCompat.getColor(context, R.color.widget_ember_ink_dim)
        val flame = ContextCompat.getColor(context, R.color.widget_ember_flame)
        val night = ContextCompat.getColor(context, R.color.widget_ember_night)
        appWidgetIds.forEach { widgetId ->
            val views =
                RemoteViews(context.packageName, R.layout.odak_leaderboard_widget).apply {
                    setContentDescription(
                        R.id.leaderboard_widget_root,
                        strings.getString(R.string.cd_leaderboard_widget),
                    )
                    val dims = appWidgetManager.dimensions(WidgetSizeSpecs.leaderboard, widgetId)
                    val size = dims.sizeClass
                    val tier = leaderboardTier(dims.widthDp, dims.heightDp)
                    val listVisible = leaderboardListVisible(tier)
                    val myRank = widgetData.text(
                        StudyWidgetKeys.LeaderboardMyRank,
                        strings.getString(R.string.widget_no_rank),
                    )
                    val coreRank = leaderboardCoreRank(myRank)
                    val row1 = widgetData.text(
                        StudyWidgetKeys.LeaderboardRow1,
                        strings.getString(R.string.widget_no_records),
                    )
                    val row1HasRank = widgetData.contains(StudyWidgetKeys.LeaderboardRow1) &&
                        leaderboardRowHasContent(row1)
                    val row2 = widgetData.text(StudyWidgetKeys.LeaderboardRow2, "-")
                    val row3 = widgetData.text(StudyWidgetKeys.LeaderboardRow3, "-")
                    val highlighted = leaderboardHighlightedPosition(myRank)

                    // Kart: kademeye gore yaricap + dolgu (§2.6).
                    setInt(
                        R.id.leaderboard_widget_card,
                        "setBackgroundResource",
                        listCardBackground(tier),
                    )
                    applyRootPadding(
                        context,
                        R.id.leaderboard_widget_card,
                        listCardPaddingDp(tier),
                    )
                    // §1.5: bu widget'in TEK dokunma hedefi koktur - yani
                    // widget'in tamami. K1/K2'de ikinci bir hedef yasaktir ve
                    // K3/K4'te de ikincisine gerek yok: butun satirlar ayni
                    // ekrani acar.
                    setOnClickPendingIntent(
                        R.id.leaderboard_widget_root,
                        WidgetDeepLink.pendingIntent(
                            context,
                            WidgetDeepLink.ROUTE_GROUP,
                            widgetId,
                        ),
                    )

                    // --- K1/K2: cekirdek seridi -------------------------------
                    setViewVisibility(
                        R.id.leaderboard_widget_core,
                        if (listVisible) View.GONE else View.VISIBLE,
                    )
                    // Cekirdek sayi ise sayi, degilse GLIF (§1.4). Ikisi ayni
                    // anda cizilmez: K1 butcesi TEK ogedir.
                    setViewVisibility(
                        R.id.leaderboard_widget_core_rank,
                        if (!listVisible && coreRank != null) View.VISIBLE else View.GONE,
                    )
                    setViewVisibility(
                        R.id.leaderboard_widget_core_icon,
                        if (!listVisible && coreRank == null) View.VISIBLE else View.GONE,
                    )
                    setTextViewText(R.id.leaderboard_widget_core_rank, coreRank ?: "")
                    setTextColor(R.id.leaderboard_widget_core_rank, flame)
                    applySp(R.id.leaderboard_widget_core_rank, WIDGET_LIST_CORE_SP)
                    // K2'nin K1'e gore kazandigi sey BOYUT degil BILGI: lider.
                    setViewVisibility(
                        R.id.leaderboard_widget_core_lead,
                        if (tier == ListWidgetTier.K2 && leaderboardRowHasContent(row1)) {
                            View.VISIBLE
                        } else {
                            View.GONE
                        },
                    )
                    setTextViewText(R.id.leaderboard_widget_core_lead, row1)
                    setTextColor(R.id.leaderboard_widget_core_lead, inkDim)
                    applySp(R.id.leaderboard_widget_core_lead, WIDGET_LIST_CORE_HINT_SP)

                    // --- K3/K4: baslik + ayrac --------------------------------
                    // Dusme sirasinda baslik ILK duser (§1.3): kullanici
                    // widget'i kendi eliyle kurdu, hangisi oldugunu bilir.
                    val headerVisible = leaderboardHeaderVisible(tier, dims.widthDp)
                    setViewVisibility(
                        R.id.leaderboard_widget_header,
                        if (headerVisible) View.VISIBLE else View.GONE,
                    )
                    setTextViewText(
                        R.id.leaderboard_widget_title,
                        widgetData.text(
                            StudyWidgetKeys.LeaderboardTitle,
                            strings.getString(R.string.widget_leaderboard_title),
                        ),
                    )
                    applySp(
                        R.id.leaderboard_widget_title,
                        WidgetTypography.leaderboardTitle.of(size.width),
                    )
                    setViewVisibility(
                        R.id.leaderboard_widget_divider,
                        if (headerVisible && tier == ListWidgetTier.K4) {
                            View.VISIBLE
                        } else {
                            View.GONE
                        },
                    )

                    // --- K3/K4: satirlar --------------------------------------
                    val rowSp = WidgetTypography.leaderboardRow.of(size.width)
                    val valueColumnFits = leaderboardValueVisible(tier, dims.widthDp, rowSp)
                    val rowTexts = arrayOf(row1, row2, row3)
                    for (index in 0..2) {
                        val position = index + 1
                        val isMine = highlighted == position
                        // WP-757: ad ve sure IKI SUTUNA ayrilir. Tek metin
                        // oldugunda uc noktaya ilk giden sey SURE oluyordu.
                        val value = leaderboardRowValue(rowTexts[index])
                        val showValue = value != null && valueColumnFits
                        // 🔴 Sure sutunu SIGMASA DA satir yalniz ADdir. Ilk
                        // deneme burada tam metne geri dusuyordu ve olcum bunu
                        // yakaladi: 110x110dp kutuda `Muhammed Muhlis - 4 sa
                        // 12 dk` yine 22 karakter kirpildi, yani sure zaten
                        // gorunmuyordu. Adi tek basina cizmek ayni yere iki
                        // kat daha fazla AD karakteri sigdirir.
                        setTextViewText(
                            LEADERBOARD_ROWS[index],
                            if (value != null) {
                                leaderboardRowName(rowTexts[index])
                            } else {
                                rowTexts[index]
                            },
                        )
                        applySp(LEADERBOARD_ROWS[index], rowSp)
                        setViewVisibility(
                            LEADERBOARD_VALUES[index],
                            if (showValue) View.VISIBLE else View.GONE,
                        )
                        setTextViewText(LEADERBOARD_VALUES[index], value ?: "")
                        setTextColor(LEADERBOARD_VALUES[index], if (isMine) flame else inkDim)
                        applySp(LEADERBOARD_VALUES[index], LEADERBOARD_VALUE_SP)
                        setTextColor(LEADERBOARD_ROWS[index], if (isMine) flame else ink)
                        // 🔴 Rozet metni: 1. sira `night` on `glow` (12.22:1),
                        // KENDI satirin `flame` on `night` (8.19:1), digerleri
                        // `ink_dim` on `night` (6.59:1).
                        //
                        // Digerleri eskiden `accent` (flame) idi. Ikisi de WCAG
                        // AA'yi (4.5:1) gecer; karar KONTRAST degil HIYERARSI
                        // gerekcesiyle verildi: bu ailede `flame` "SEN" demek.
                        // 2. ve 3. siranin rakamlari da flame olsaydi kisisel
                        // vurgu bir sinyal olmaktan cikardi.
                        setTextViewText(
                            LEADERBOARD_RANKS[index],
                            if (isMine) {
                                strings.getString(R.string.widget_you)
                            } else {
                                position.toString()
                            },
                        )
                        setTextColor(
                            LEADERBOARD_RANKS[index],
                            when {
                                position == 1 -> night
                                isMine -> flame
                                else -> inkDim
                            },
                        )
                        setInt(
                            LEADERBOARD_RANKS[index],
                            "setBackgroundResource",
                            when {
                                position == 1 -> R.drawable.widget_rank_first_bg
                                isMine -> R.drawable.widget_rank_self_bg
                                else -> R.drawable.widget_rank_other_bg
                            },
                        )
                    }
                    setViewVisibility(
                        R.id.leaderboard_widget_rank_1,
                        if (row1HasRank) View.VISIBLE else View.GONE,
                    )
                    setViewVisibility(
                        LEADERBOARD_ROW_CONTAINERS[0],
                        if (listVisible) View.VISIBLE else View.GONE,
                    )
                    // WP-699: üçüncü satır ancak gerçekten uzun kutuda gelir.
                    // Eskiden 2. ve 3. satır birlikte açılıyordu; 3×2'de üç
                    // satır + başlık 110dp'ye sığmıyordu.
                    setViewVisibility(
                        LEADERBOARD_ROW_CONTAINERS[1],
                        if (
                            listVisible &&
                            leaderboardRow2Visible(size.height) &&
                            leaderboardRowHasContent(row2)
                        ) View.VISIBLE else View.GONE,
                    )
                    setViewVisibility(
                        LEADERBOARD_ROW_CONTAINERS[2],
                        if (
                            listVisible &&
                            leaderboardRow3Drawn(size.height, headerVisible) &&
                            leaderboardRowHasContent(row3)
                        ) View.VISIBLE else View.GONE,
                    )
                }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
