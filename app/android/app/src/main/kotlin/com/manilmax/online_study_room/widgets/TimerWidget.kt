package com.manilmax.online_study_room.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import com.manilmax.online_study_room.R
import com.manilmax.online_study_room.timer.TimerStateStore
import es.antonborri.home_widget.HomeWidgetProvider

/** Kontrol hapinin yatay dolgusu (`odak_timer_widget.xml`). */
internal const val WIDGET_TIMER_PILL_H_PADDING_DP = 4

/**
 * Sayac rakamlarinin BIRLESIK yatay katsayisi (`k`): `textScaleX` x yazitipi
 * daralmasi. Sabit dar glif geometrisi; 8 karakterlik `00:00:00` yeniden akmaz.
 *
 * 🔴 WP-752 borcu — bu deger `odak_timer_widget.xml:25`teki
 * `android:textScaleX="0.55"` ile AYNI SEYI soyler ve tasarim sisteminin
 * tabaninin ([WIDGET_TEXT_SCALE_X_MIN] = 0.85) ALTINDADIR. Tabana cikarmak TEK
 * BASINA yapilamaz, atomik bir uctur:
 *   1. `odak_timer_widget.xml` -> `textScaleX` 0.85 + `sans-serif-condensed`
 *      (`k` = 0.85 x 0.87 = 0.74),
 *   2. ayni duzendeki `android:textSize="28sp"` -> 26sp,
 *   3. burasi -> `WIDGET_TEXT_SCALE_X_MIN * WIDGET_CONDENSED_ADVANCE`,
 *   4. [WidgetTypography].`timerTime` dar basamagi 28f -> 26f,
 *   5. K1 cekirdegi 8 karakterlik kronometreden 3 karakterlik dakikaya.
 * Aritmetik: 110dp kutuda 4dp dolguyla `k = 0.74` iken 8 karaktere en fazla
 * `widgetMaxSp(110, 4, 8, 0.74) = 26sp` sigar; bugunku 28sp o tabanda KIRPILIR.
 * Duzenler bu WP'nin SAHIP yolu degildir; adimlarin hepsi WP-753'undur.
 */
internal const val WIDGET_TIMER_TEXT_SCALE_X = 0.55f

/** Launcher'in gercek 1x1 kutusunda kullanilan belirgin alt basamak. */
internal const val WIDGET_TIMER_ONE_CELL_SP = 20f

/** Kronometrenin en uzun hali: `00:00:00`. Genislik butcesinin girdisi. */
internal const val WIDGET_TIMER_TIME_CHARS = 8

/**
 * Kontrol satiri (ders hapi + Baslat/Durdur) yalniz 48dp'lik hedefin
 * GERCEKTEN sigdigi yukseklikte cizilir.
 *
 * En kisa kutuda (80dp) dikey butce `80 - 2*6 - 8 = 60dp`dir; 48dp'lik hap +
 * en kucuk puntolu sayi (18sp -> 23.4dp) + 4dp aralik = 75.4dp. Yani hap o
 * kutuda ya kirpilir ya da sayiyi tekrar 15sp'ye dusurur — sahibin sikayet
 * ettigi yer. Cozum hapi kucultmek DEGIL, o boyutta kaldirip **kokun
 * kendisini** hedef yapmaktir: 1 hucrelik widget launcher'in gercek
 * hucresine cizilir (~70-85dp), yani yuzey zaten >= 48dp'dir.
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
 * Sayinin puntosu: genislik merdiveni, `MEDIUM` yukseklikte TAVANLI.
 *
 * 4x2 gibi genis ama kisa bir kutuda dikey butce `110 - 2*7 - 8 = 88dp`dir;
 * 40sp'lik satir (52dp) + 4dp aralik + 48dp hap = 104dp > 88dp. Tavan
 * olmadan bu kutuda ya sayi ya dugme kirpilirdi. `SHORT`ta kontrol satiri
 * olmadigi icin tavana gerek yoktur, `TALL`da ise yer zaten var.
 */
internal fun timerTimeSp(size: WidgetSizeClass, widthDp: Int = 0): Float {
    val oneCell = widthDp in 1 until WIDGET_TIMER_DEFAULT_WIDTH_DP
    val base = if (oneCell) {
        WIDGET_TIMER_ONE_CELL_SP
    } else {
        WidgetTypography.timerTime.of(size.width)
    }
    val capped = when (size.height) {
        WidgetHeightClass.SHORT -> minOf(base, 34f)
        WidgetHeightClass.MEDIUM -> minOf(base, 28f)
        WidgetHeightClass.TALL -> base
    }
    // 🔴 WP-752 (§3.4): dikey tavanin yanina GENISLIK tavani. Bugunku
    // degerlerde ISLEMEZ (110dp/4dp dolgu/8 karakter/k=0.55 -> 35sp tavan,
    // merdivenin en buyugu 28sp) — yani davranis degismez. Isi, yatay
    // sikistirma tabana (`WIDGET_TEXT_SCALE_X_MIN`) cikarildiginda punto
    // merdiveni de inmediyse ekranda kirpilan bir sayi BIRAKMAMAKTIR.
    //
    // K1 dali (`oneCell`) bilerek disarida: o kutuda 8 karakter zaten
    // sigmiyor ve model 11sp tabaninin altina duserdi. K1'in dogru cozumu
    // puntoyu ezmek degil CEKIRDEGI 3 karaktere indirmektir (§1.4/§3.4).
    if (oneCell) return capped
    val box = if (widthDp > 0) widthDp else WIDGET_TIMER_DEFAULT_WIDTH_DP
    val budget = widgetMaxSp(
        widthDp = box,
        paddingDp = timerRootPaddingDp(size),
        chars = WIDGET_TIMER_TIME_CHARS,
        advanceScale = WIDGET_TIMER_TEXT_SCALE_X,
    )
    return maxOf(minOf(capped, budget), WIDGET_MIN_TEXT_SP)
}

/**
 * Kok dolgu. WP-717'nin paylasilan `widget_design_padding` olcusu 12dp'dir ve
 * metin+ilerleme kartlari icin dogrudur; sayac tile'i icin degil: 110dp'lik
 * bir kutuda 12dp'lik cift yan dolgu genisligin %22'sini yer ve puntoyu tam
 * da sahibin sikayet ettigi yere geri dusurur. WP-717 rengi ve olcuyu ayri
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
                val controlsVisible = timerControlsVisible(size.height)
                val subjectVisible = timerSubjectVisible(size)
                setViewVisibility(R.id.timer_widget_elapsed, View.VISIBLE)
                setViewVisibility(
                    R.id.timer_widget_controls,
                    if (controlsVisible) View.VISIBLE else View.GONE,
                )
                setViewVisibility(
                    R.id.timer_widget_compact_action,
                    if (controlsVisible) View.GONE else View.VISIBLE,
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
