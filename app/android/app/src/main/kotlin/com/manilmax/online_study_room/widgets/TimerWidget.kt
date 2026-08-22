package com.manilmax.online_study_room.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import com.manilmax.online_study_room.R
import com.manilmax.online_study_room.timer.TimerStateStore
import es.antonborri.home_widget.HomeWidgetProvider

/** Kontrol hapinin yatay dolgusu (`odak_timer_widget.xml`). */
internal const val WIDGET_TIMER_PILL_H_PADDING_DP = 4

/**
 * Bir metin satirinin punto cinsinden yuksekligi (cizgi araligi dahil).
 *
 * Depodaki butun dikey butce olcumlerinin (WP-699/718/728 testleri) kullandigi
 * katsayinin ta kendisi; buraya alindi ki KOD da ayni sayiyi kullansin.
 * Ayrisirsa test "sigiyor" derken ekran kirpar.
 */
internal const val WIDGET_LINE_HEIGHT_RATIO = 1.30f

internal fun widgetLineHeightDp(sp: Float): Float = sp * WIDGET_LINE_HEIGHT_RATIO

/**
 * Sayac rakamlarinin `textScaleX` degeri.
 *
 * 🔴 WP-754: 0.55 -> 0.85. Eski deger bir daraltma DEGIL deformasyondu;
 * gliflerin dikey cizgileri kalin, yatay cizgileri ince kaliyordu ve rakam
 * "hastalikli" gorunuyordu - sahibin cihazda gordugu bozuk rakamlar buydu.
 * Daraltmayi artik yazi tipinin kendi glif formu yapiyor
 * (`android:fontFamily="sans-serif-condensed"`, ilerleme genisligi ~0.87).
 * Tasarim sistemi tabani [WIDGET_TEXT_SCALE_X_MIN] = 0.85'tir (§7 madde 6) ve
 * bu sabit `odak_timer_widget.xml`deki `android:textScaleX` ile AYNI SEYI
 * soyler; `WidgetRedesignWp730Test` ikisini karsilastirir.
 *
 * Gecis ATOMIKtir - besi birlikte yapildi:
 *   1. `odak_timer_widget.xml` -> `textScaleX` 0.85 + `sans-serif-condensed`,
 *   2. burasi -> 0.85,
 *   3. [timerTimeSp] genislik tavani artik HER kademede baglar (asagida),
 *   4. punto merdiveni o tavanin altina iner: 110dp kutuda 4dp dolguyla
 *      merdivenin 28sp'si degil butcenin 23sp'si secilir,
 *   5. K1 cekirdegi sekiz karakterlik kronometreden GLIFE gecti
 *      ([timerCoreIsGlyph]).
 *
 * 🔴 Neden `advanceScale` olarak DOGRUDAN bu deger kullaniliyor (yani
 * `0.85 x 0.87 = 0.74` degil): [WIDGET_GLYPH_ADVANCE] KDoc'undaki kural -
 * "`sans-serif-condensed`in dar olusu butceye degil EMNIYET PAYINA yazilir,
 * boylece hicbir kutu cihazda olculmeden once iyimser hesaplanmis olmaz".
 * Gercek cizim butcenin ~%87'sini kaplar; aradaki fark cihazda olculene kadar
 * emniyet payidir.
 */
internal const val WIDGET_TIMER_TEXT_SCALE_X = 0.85f

/** Launcher'in gercek 1x1 kutusunda kullanilan belirgin alt basamak. */
internal const val WIDGET_TIMER_ONE_CELL_SP = 20f

/** Kronometrenin en uzun hali: `00:00:00`. Genislik butcesinin girdisi. */
internal const val WIDGET_TIMER_TIME_CHARS = 8

/** K1 cekirdek glifi - `widget_ic_timer`, 24dp izgara (§4.3). */
internal const val WIDGET_TIMER_GLYPH_DP = 24

/** K3/K4 ocak isareti ve altindaki aralik. */
internal const val WIDGET_TIMER_MARK_DP = 16
internal const val WIDGET_TIMER_MARK_GAP_DP = 2

/** Kompakt eylem ipucu (`odak_timer_widget.xml`de 22dp) ve ustundeki aralik. */
internal const val WIDGET_TIMER_COMPACT_ACTION_DP = 22
internal const val WIDGET_TIMER_COMPACT_ACTION_GAP_DP = 2

/**
 * K1 (Kor): cekirdek SAYI degil GLIFtir.
 *
 * Iki bagimsiz gerekce - ikisi de aritmetik:
 *  1. **Genislik.** 40dp kutuda 2dp dolguyla sekiz karakterin tavani
 *     `widgetMaxSp(40, 2, 8, 0.85) = 6sp`; anlam tasiyan metnin tabani
 *     [WIDGET_MIN_TEXT_SP] = 11sp (§3.3). Yani sekiz karakter o kutuya OKUNUR
 *     bicimde girmiyor.
 *  2. **Canlilik.** Sayiyi §1.4'un onerdigi gibi 3 karaktere ("47" dakika)
 *     indirmek genisligi cozer ama sayiyi OLDURURDU: RemoteViews'ta kendi
 *     kendine tiklayan tek gorunum `Chronometer`dir ve onun en kisa bicimi
 *     `MM:SS`tir; dakika yazan bir `TextView` ancak bir yayin dustugunde
 *     tazelenir. `updatePeriodMillis=0` (info xml) ve `TimerWidgets.updateAll`
 *     yalniz baslat/durdur/boot aninda yayin yapar - iki saatlik bir oturum
 *     boyunca kutuda "0" yazardi.
 * §1.4 bu cikisi acikca veriyor: "sayi 3 karaktere sigmiyorsa cekirdek
 * gliftir". Glif yalniz DURUM degisince degisir, yani tam olarak bir yayinin
 * dustugu anda; bayatlayamaz.
 *
 * Esik yeni degil: [timerTimeSp] WP-718'den beri ayni dali tasiyordu
 * (`widthDp in 1 until WIDGET_TIMER_DEFAULT_WIDTH_DP`).
 */
internal fun timerCoreIsGlyph(widthDp: Int): Boolean =
    widthDp in 1 until WIDGET_TIMER_DEFAULT_WIDTH_DP

/**
 * O kutuda cizilen cekirdegin KARAKTER sayisi; glif cekirdek 0 dondurur.
 * §1.4 siniri: K1'de en fazla 3.
 */
internal fun timerCoreChars(widthDp: Int): Int =
    if (timerCoreIsGlyph(widthDp)) 0 else WIDGET_TIMER_TIME_CHARS

/**
 * Kontrol satiri (ders hapi + Baslat/Durdur) yalniz 48dp'lik hedefin
 * GERCEKTEN sigdigi yukseklikte cizilir.
 *
 * En kisa kutuda (80dp) dikey butce `80 - 2*6 - 8 = 60dp`dir; 48dp'lik hap +
 * en kucuk puntolu sayi (18sp -> 23.4dp) + 4dp aralik = 75.4dp. Yani hap o
 * kutuda ya kirpilir ya da sayiyi tekrar 15sp'ye dusurur - sahibin sikayet
 * ettigi yer. Cozum hapi kucultmek DEGIL, o boyutta kaldirip **kokun
 * kendisini** hedef yapmaktir: 1 hucrelik widget launcher'in gercek hucresine
 * cizilir (~70-85dp), yani yuzey zaten >= 48dp'dir.
 */
internal fun timerControlsVisible(height: WidgetHeightClass): Boolean =
    height != WidgetHeightClass.SHORT

/**
 * Ders hapi IKI eksene birden baglidir ve bu bilerek boyledir: satirin
 * yarisina dusen genislik `MEDIUM` (150dp) altinda "Durdur" bile sigmaz,
 * `SHORT` yukseklikte ise zaten kontrol satiri yoktur.
 */
internal fun timerSubjectVisible(size: WidgetSizeClass): Boolean =
    timerControlsVisible(size.height) && size.width != WidgetWidthClass.NARROW

/**
 * Sayinin puntosu: genislik merdiveni, `MEDIUM` yukseklikte TAVANLI, sonra
 * §3.4 GENISLIK butcesiyle kirpilmis.
 *
 * 4x2 gibi genis ama kisa bir kutuda dikey butce `110 - 2*7 - 8 = 88dp`dir;
 * 40sp'lik satir (52dp) + 4dp aralik + 48dp hap = 104dp > 88dp. Tavan olmadan
 * bu kutuda ya sayi ya dugme kirpilirdi. `SHORT`ta kontrol satiri olmadigi
 * icin tavana gerek yoktur, `TALL`da ise yer zaten var.
 *
 * 🔴 WP-754: genislik tavani artik K1 dali dahil HER kademede baglar. Eskiden
 * `oneCell` dali erken donuyordu ve o kutuda 20sp'lik sekiz karakter
 * `textScaleX=0.55` ile ancak "sigmis" sayiliyordu; taban sikistirmada (0.85)
 * ayni satir kutuyu asar. Model artik hangi kutuda neyin sigdiginin dogrusunu
 * soyler - K1'de sayi zaten cizilmez ([timerCoreIsGlyph]) ama fonksiyon
 * "cizilseydi ne olurdu" sorusuna DURUST cevap verir.
 */
internal fun timerTimeSp(size: WidgetSizeClass, widthDp: Int = 0): Float {
    val box = if (widthDp > 0) widthDp else WIDGET_TIMER_DEFAULT_WIDTH_DP
    val base = if (timerCoreIsGlyph(box)) {
        WIDGET_TIMER_ONE_CELL_SP
    } else {
        WidgetTypography.timerTime.of(size.width)
    }
    val capped = when (size.height) {
        WidgetHeightClass.SHORT -> minOf(base, 34f)
        WidgetHeightClass.MEDIUM -> minOf(base, 28f)
        WidgetHeightClass.TALL -> base
    }
    val budget = widgetMaxSp(
        widthDp = box,
        paddingDp = timerRootPaddingDp(size),
        chars = WIDGET_TIMER_TIME_CHARS,
        advanceScale = WIDGET_TIMER_TEXT_SCALE_X,
    )
    return maxOf(minOf(capped, budget), WIDGET_MIN_TEXT_SP)
}

/** Isaret + (varsa) ayrac + sayi + aralik + 48dp hap toplaminin dikey maliyeti. */
internal fun timerMarkBlockDp(size: WidgetSizeClass, widthDp: Int): Float {
    val rule = if (size.height == WidgetHeightClass.TALL) {
        1f + WIDGET_DESIGN_ROW_GAP_DP
    } else {
        0f
    }
    return WIDGET_TIMER_MARK_DP + WIDGET_TIMER_MARK_GAP_DP + rule +
        widgetLineHeightDp(timerTimeSp(size, widthDp)) +
        WIDGET_DESIGN_ROW_GAP_DP + WIDGET_MIN_TOUCH_TARGET_DP
}

/**
 * Ocak isareti (§4.3 ikon ailesi) - K3/K4'un GRAFIGI.
 *
 * §1.3 dusme sirasi: grafik, cekirdekten ONCE duser. Karari goz degil
 * aritmetik verir: isaret + sayi + 48dp hap ayni dikey butceye sigmiyorsa
 * isaret duser. Somut sonuc (dolgu [timerRootPaddingDp]):
 *   110x110 (2x2): 16+2 + 23sp*1.3 + 4 + 48 = 99.9 <= 102 -> cizilir
 *   180x110 (3x2): 16+2 + 28sp*1.3 + 4 + 48 = 106.4 > 100 -> duser
 * Yani genis ama KISA kutuda sayi ve dokunma hedefi butceyi zaten doldurur.
 *
 * K1'de isaret yoktur cunku cekirdegin KENDISI ayni gliftir; K2'de yoktur
 * cunku o kademe tek ogelidir (§1.2).
 */
internal fun timerMarkVisible(size: WidgetSizeClass, widthDp: Int, heightDp: Int): Boolean {
    if (timerCoreIsGlyph(widthDp)) return false
    if (!timerControlsVisible(size.height)) return false
    val available = heightDp - 2f * timerRootPaddingDp(size)
    return timerMarkBlockDp(size, widthDp) <= available
}

/**
 * 1dp ayrac (§4.4 - RemoteViews'ta duz `View` yoktur, ayrac bir `ImageView`
 * zeminidir). Yalniz K4-uzun'da ve yalniz isaret cizildiginde vardir; ayrac
 * tek basina bir sey ayirmaz.
 */
internal fun timerRuleVisible(size: WidgetSizeClass, widthDp: Int, heightDp: Int): Boolean =
    size.height == WidgetHeightClass.TALL && timerMarkVisible(size, widthDp, heightDp)

/**
 * Kompakt eylem ipucu (22dp hap) - yalniz kontrol satirinin cizilmedigi ama
 * ipucunun GERCEKTEN sigdigi kutuda.
 *
 * 🔴 Eskiden `!controlsVisible` tek kosuldu ve 110x40dp'lik VARSAYILAN kutuda
 * sayi (29.9dp) + 2dp + 22dp = 53.9dp, kutunun 32dp'lik ic yuksekligine
 * sigmiyordu: hap ya kirpiliyor ya sayiyi asagi itiyordu. K1'de ise ikinci bir
 * tiklanabilir alan zaten YASAKTIR (§1.5) - kokun kendisi hedeftir ve
 * launcher'in gercek hucresi kadar buyuktur.
 */
internal fun timerCompactActionVisible(
    size: WidgetSizeClass,
    widthDp: Int,
    heightDp: Int,
): Boolean {
    if (timerCoreIsGlyph(widthDp)) return false
    if (timerControlsVisible(size.height)) return false
    val needed = widgetLineHeightDp(timerTimeSp(size, widthDp)) +
        WIDGET_TIMER_COMPACT_ACTION_GAP_DP + WIDGET_TIMER_COMPACT_ACTION_DP
    return needed <= heightDp - 2f * timerRootPaddingDp(size)
}

/**
 * Kart yaricapi KADEMEYE baglidir (§2.6): K1/K2'de 12dp (`_tight`), K3/K4'te
 * 20dp. 40x40dp'lik bir kutuda 20dp yaricap koselerin TAMAMINI yer ve kart
 * karta degil hapa doner. Secim kodda yapilir cunku tek bir layout tek zemin
 * beyan edebilir; `View.setBackgroundResource` `@RemotableViewMethod`tur.
 */
internal fun widgetCardBackground(height: WidgetHeightClass): Int =
    if (height == WidgetHeightClass.SHORT) {
        R.drawable.widget_card_bg_tight
    } else {
        R.drawable.widget_card_bg
    }

/**
 * Kok dolgu. WP-717'nin paylasilan `widget_design_padding` olcusu 12dp'dir ve
 * metin+ilerleme kartlari icin dogrudur; sayac tile'i icin degil: 110dp'lik
 * bir kutuda 12dp'lik cift yan dolgu genisligin %22'sini yer ve puntoyu tam da
 * sahibin sikayet ettigi yere geri dusurur. WP-717 rengi ve olcuyu ayri
 * simgelerde tuttugu icin bu ayrisma dilin disina cikmaz.
 *
 * 🔴 Dolgu YUKSEKLIKLE buyur (WP-699: "uzun kutuda cerceve de nefes alsin"),
 * ama DAR kutuda buyumez. 2x3 gibi dar-uzun bir kutuda 8dp'lik dolgu
 * genisligin 16dp'sini yer ve 18sp'lik sayiyi kirpar; kazanilan estetigin
 * bedeli okunabilirlik olurdu.
 */
internal fun timerRootPaddingDp(size: WidgetSizeClass): Int =
    if (size.width == WidgetWidthClass.NARROW) 4 else widgetRootPaddingDp(4, size.height)

class TimerWidgetProvider : HomeWidgetProvider() {
    // WP-699: yeniden boyutlandırma tek başına `onUpdate` tetiklemez —
    // `AppWidgetProvider.onAppWidgetOptionsChanged` gövdesi boştur ve
    // `HomeWidgetProvider` onu geçersiz kılmaz. Bu metot yazılmadan boyut
    // sınıfı ekranda hiç değişmezdi; `updatePeriodMillis=0` olan bu widget'ta
    // ise bir daha ASLA yeniden çizilmezdi.
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
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.odak_timer_widget).apply {
                val dimensions = appWidgetManager.dimensions(WidgetSizeSpecs.timer, widgetId)
                val size = dimensions.sizeClass
                val widgetPrefs = context.getSharedPreferences(
                    TimerStateStore.PREFS_NAME,
                    Context.MODE_PRIVATE,
                )
                val timerPrefs = readTimerWidgetPrefs(widgetPrefs)
                val isRunning = timerPrefs.startedAtMs != null
                val projection = timerChronometerProjection(
                    isRunning = isRunning,
                    mode = timerPrefs.mode,
                    startedAtMs = timerPrefs.startedAtMs,
                    targetSeconds = timerPrefs.targetSeconds,
                    nowWallClockMs = System.currentTimeMillis(),
                    nowElapsedRealtimeMs = SystemClock.elapsedRealtime(),
                )
                // WP-134: Chronometer HER boyutta VISIBLE (compact GONE kaldırıldı).
                // WP-699: iki satırın ikisi de her boyutta duruyordu.
                // 🔴 WP-718 bunu boyuta bagladi: en kisa kutuda 48dp'lik hedef
                // ile okunur bir sayi AYNI ANDA sigmiyor (gerekce
                // `timerControlsVisible`). O kutuda kontrol satiri kalkar ve
                // kokun kendisi baslat/durdur olur — islev kaybolmaz, hedef
                // BUYUR.
                // 🔴 WP-754: en kucuk kademede (K1) sayinin YERINE ocak glifi
                // cizilir; gerekce `timerCoreIsGlyph`.
                val controlsVisible = timerControlsVisible(size.height)
                val subjectVisible = timerSubjectVisible(size)
                val coreIsGlyph = timerCoreIsGlyph(dimensions.widthDp)
                val markVisible = timerMarkVisible(size, dimensions.widthDp, dimensions.heightDp)
                val ruleVisible = timerRuleVisible(size, dimensions.widthDp, dimensions.heightDp)
                val compactVisible =
                    timerCompactActionVisible(size, dimensions.widthDp, dimensions.heightDp)
                val accent = ContextCompat.getColor(context, R.color.widget_ember_flame)
                val muted = ContextCompat.getColor(context, R.color.widget_ember_ink_dim)
                val ink = ContextCompat.getColor(context, R.color.widget_ember_ink)

                setInt(
                    R.id.timer_widget_root,
                    "setBackgroundResource",
                    widgetCardBackground(size.height),
                )
                setViewVisibility(
                    R.id.timer_widget_glyph,
                    if (coreIsGlyph) View.VISIBLE else View.GONE,
                )
                setViewVisibility(
                    R.id.timer_widget_elapsed,
                    if (coreIsGlyph) View.GONE else View.VISIBLE,
                )
                setViewVisibility(
                    R.id.timer_widget_mark,
                    if (markVisible) View.VISIBLE else View.GONE,
                )
                setViewVisibility(
                    R.id.timer_widget_rule,
                    if (ruleVisible) View.VISIBLE else View.GONE,
                )
                setViewVisibility(
                    R.id.timer_widget_controls,
                    if (controlsVisible) View.VISIBLE else View.GONE,
                )
                setViewVisibility(
                    R.id.timer_widget_compact_action,
                    if (compactVisible) View.VISIBLE else View.GONE,
                )
                setViewVisibility(
                    R.id.timer_widget_subject,
                    if (subjectVisible) View.VISIBLE else View.GONE,
                )
                applySp(R.id.timer_widget_elapsed, timerTimeSp(size, dimensions.widthDp))
                applySp(R.id.timer_widget_action, WidgetTypography.timerAction.of(size.width))
                applySp(
                    R.id.timer_widget_compact_action,
                    WidgetTypography.timerAction.of(size.width),
                )
                applySp(R.id.timer_widget_subject, WidgetTypography.timerSubject.of(size.width))
                applyRootPadding(
                    context,
                    R.id.timer_widget_root,
                    timerRootPaddingDp(size),
                )
                // §6: durum (calisiyor/duruyor) ikinci bir OGEyle degil,
                // cekirdegin RENGIYLE anlatilir. Cekirdek K1'de glif, ustunde
                // sayidir; ikisi de ayni iki tonu kullanir. Renk her turda
                // ACIKCA yazilir - yoksa onceki cizimin filtresi sizar ve duran
                // sayac turuncu kalirdi.
                setTextColor(R.id.timer_widget_elapsed, if (isRunning) accent else ink)
                setInt(
                    R.id.timer_widget_glyph,
                    "setColorFilter",
                    if (isRunning) accent else muted,
                )
                setInt(R.id.timer_widget_mark, "setColorFilter", if (isRunning) accent else muted)
                if (projection.direction != TimerChronometerDirection.IDLE) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        setChronometerCountDown(
                            R.id.timer_widget_elapsed,
                            projection.direction == TimerChronometerDirection.DOWN,
                        )
                    }
                    setChronometer(
                        R.id.timer_widget_elapsed,
                        projection.baseElapsedRealtimeMs,
                        null,
                        projection.running,
                    )
                } else {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        setChronometerCountDown(R.id.timer_widget_elapsed, false)
                    }
                    // Idle / sıfır: native Chronometer'ın MM:SS biçimiyle hizalı.
                    setChronometer(
                        R.id.timer_widget_elapsed,
                        SystemClock.elapsedRealtime(),
                        WIDGET_IDLE_TIMER_TEXT,
                        false,
                    )
                    setTextViewText(R.id.timer_widget_elapsed, WIDGET_IDLE_TIMER_TEXT)
                }
                // Tek düğme: çalışıyorsa Durdur, duruyorsa Başlat (native servis).
                setTextViewText(
                    R.id.timer_widget_action,
                    if (isRunning) {
                        context.getString(R.string.action_stop)
                    } else {
                        context.getString(R.string.action_start)
                    },
                )
                setTextViewText(
                    R.id.timer_widget_compact_action,
                    if (isRunning) {
                        context.getString(R.string.action_stop)
                    } else {
                        context.getString(R.string.action_start)
                    },
                )
                // K1/K2'de gorunur tek oge cekirdektir ve kokun kendisi tek
                // hedeftir; o hedefin adi burada verilir - glif kademesinde
                // ekranda okunacak METIN hic yoktur.
                if (!controlsVisible) {
                    setContentDescription(
                        R.id.timer_widget_root,
                        context.getString(
                            if (isRunning) R.string.action_stop else R.string.action_start,
                        ),
                    )
                }

                // WP-718: ders hapinin metni. Sayac KOSARKEN o kosunun dersi
                // (`KEY_SUBJECT`), dururken KALICI TERCIH okunur — ikisi ayri
                // anahtardir ve birincisi durunca silinir.
                if (subjectVisible) {
                    val accountId = widgetAccountId(widgetPrefs)
                    val subjects = widgetSubjectOptions(widgetPrefs, accountId)
                    // Bozuk prefs widget'i etiketsiz birakir, SURECI oldurmez
                    // (bu kod bir BroadcastReceiver icinde kosar).
                    val current = runCatching {
                        if (isRunning) {
                            widgetPrefs.getString(TimerStateStore.KEY_SUBJECT, null)
                        } else {
                            widgetPrefs.getString(subjectPreferenceKey(accountId), null)
                        }
                    }.getOrNull()
                    val label = widgetSubjectLabel(current, subjects)
                    setTextViewText(R.id.timer_widget_subject, label)
                    setContentDescription(R.id.timer_widget_subject, label)
                }

                val togglePending = widgetBroadcast(
                    context,
                    TimerActionReceiver.ACTION_TOGGLE_TIMER,
                    requestCode = 0,
                )
                setOnClickPendingIntent(R.id.timer_widget_action, togglePending)
                setOnClickPendingIntent(R.id.timer_widget_compact_action, togglePending)
                // WP-718: ders hapi yalniz DURURKEN secim yapar; kosarken
                // baglanmaz ve kokun derin baglantisini devralir (kullanici o
                // an dersi degil kosuyu gormek ister). Dart'ta da kural ayni:
                // `selectSubject` kosarken hicbir sey yapmaz.
                if (subjectVisible && !isRunning) {
                    setOnClickPendingIntent(
                        R.id.timer_widget_subject,
                        widgetBroadcast(
                            context,
                            TimerActionReceiver.ACTION_CYCLE_SUBJECT,
                            requestCode = 1,
                        ),
                    )
                }
                // WP-700: KOK sayac bolumunu ACAR, toggle etmez.
                // 🔴 WP-718 istisnasi: kontrol satirinin cizilmedigi en kucuk
                // boyutta kok baslat/durdur olur. Aksi halde o boyutta
                // widget'in HICBIR aksiyonu kalmazdi.
                setOnClickPendingIntent(
                    R.id.timer_widget_root,
                    if (controlsVisible) {
                        WidgetDeepLink.pendingIntent(
                            context,
                            WidgetDeepLink.ROUTE_TIMER,
                            widgetId,
                        )
                    } else {
                        togglePending
                    },
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
