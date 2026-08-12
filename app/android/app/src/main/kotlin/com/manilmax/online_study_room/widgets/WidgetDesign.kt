package com.manilmax.online_study_room.widgets

import android.content.Context
import android.content.res.Configuration
import java.util.Locale
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.roundToInt

internal const val WIDGET_FLUTTER_PREFS_NAME = "FlutterSharedPreferences"
internal const val WIDGET_LANGUAGE_PREFS_KEY = "flutter.app_language_preference"

/**
 * Widget metinlerinin dili icin tek karar noktasi.
 *
 * API 33'ten once Android'in uygulama-bazli dil API'si yoktur. Bu nedenle
 * `context.getString` dogrudan cagrilirsa widget cihaz diline geri duser.
 * Flutter tercihi ise `SharedPreferences`ta kalicidir ve uygulama prosesi hic
 * acilmadan calisan `AppWidgetProvider` tarafindan da okunabilir.
 */
internal fun widgetLanguageCode(
    storedPreference: String?,
    systemLanguageCode: String?,
): String = when (storedPreference) {
    "turkish" -> "tr"
    "english", "arabic", "german" -> "en"
    else -> if (systemLanguageCode.equals("tr", ignoreCase = true)) "tr" else "en"
}

internal fun widgetLocalizedContext(context: Context): Context {
    val preference = runCatching {
        context
            .getSharedPreferences(WIDGET_FLUTTER_PREFS_NAME, Context.MODE_PRIVATE)
            .getString(WIDGET_LANGUAGE_PREFS_KEY, null)
    }.getOrNull()
    val languageCode = widgetLanguageCode(preference, Locale.getDefault().language)
    val currentCode = context.resources.configuration.locales[0].language
    if (currentCode == languageCode) return context

    val locale = Locale.forLanguageTag(languageCode)
    val configuration = Configuration(context.resources.configuration).apply {
        setLocale(locale)
        setLayoutDirection(locale)
    }
    return context.createConfigurationContext(configuration)
}

/**
 * WP-717 — ana ekran widget'larinin **paylasilan gorsel dili**nin kod tarafi.
 *
 * Kaynak tarafi `res/values/widget_design.xml` (+ `values-night/`) ve
 * `res/drawable/widget_*`; burasi yalniz o kaynaklari **surmek** icin gereken
 * saf aritmetiktir. Saf tutulmasinin sebebi olculebilirlik: bu projede JVM
 * birim testinde `android.*` saplamalari cagrilamaz, dolayisiyla `Canvas`,
 * `Bitmap` ya da gercek bir `RemoteViews` uzerinden yazilan hicbir gorsel
 * iddia test edilemez. Kirilgan kisim (yuzde hesabi) buraya alininca
 * olculebilir hale gelir.
 *
 * ## Kullanim (WP-718 / WP-719 dahil)
 *
 * Duzen dosyasinda:
 * ```xml
 * <LinearLayout
 *     android:background="@drawable/widget_card_bg"
 *     android:padding="@dimen/widget_design_padding" …>
 *   <TextView android:textColor="@color/widget_design_ink" … />
 *   <TextView android:textColor="@color/widget_design_ink_muted" … />
 *   <ProgressBar
 *       style="?android:attr/progressBarStyleHorizontal"
 *       android:progressDrawable="@drawable/widget_progress_bar"
 *       android:max="100" … />
 * </LinearLayout>
 * ```
 *
 * Saglayicida:
 * ```kotlin
 * setProgressBar(R.id.x, WidgetDesign.PROGRESS_MAX, WidgetDesign.barPercent(f), false)
 * setViewVisibility(R.id.x, if (…) View.VISIBLE else View.GONE)
 * ```
 *
 * Iki cizim vardir ve **karistirilmaz**:
 * - `@drawable/widget_progress_bar` (duz pill) → [barPercent]
 * - `@drawable/widget_progress_arc` ("ters U" yay) → [arcPercent]
 *
 * 🔴 Yanlis eslesme sessizdir: yay cizimini [barPercent] ile surersen yay
 * ortada hizlanir, uclarda takilir. Sebep [arcPercent] belgesinde.
 */
internal object WidgetDesign {
    /** `setProgressBar` icin ust sinir; yuzde konusuruz, 0..100. */
    const val PROGRESS_MAX = 100

    /** 0.0..1.0 disina cikan her deger kirpilir; NaN 0 sayilir. */
    fun clampFraction(fraction: Double): Double = when {
        fraction.isNaN() -> 0.0
        fraction <= 0.0 -> 0.0
        fraction >= 1.0 -> 1.0
        else -> fraction
    }

    /** Duz cubuk: yatay konum zaten ilerlemedir, yalniz kirp ve yuvarla. */
    fun barPercent(fraction: Double): Int =
        (clampFraction(fraction) * PROGRESS_MAX).roundToInt()

    /**
     * Ters U yay icin yuzde — **acisal duzeltme yapilmis** hali.
     *
     * `ProgressBar` seviyeyi yatay bir `<clip>`e verir; yani `p` yuzdesi
     * yayin **yatay** olarak ne kadarinin gorundugudur. Yarim daire uzerinde
     * yatay konum ile aci arasindaki bagintiysa dogrusal degildir:
     * `x = R·cos θ`. Duzeltilmeden birakilirsa gosterge uclarda neredeyse
     * hic kimildamaz, tepede firlar.
     *
     * Istenen sey "gorunen YAY UZUNLUGU ∝ ilerleme"dir; yani `θ/π = f`.
     * Bunu yatay kesire cevirmek: `h = (1 − cos(π·f)) / 2`.
     *
     * Kontrol noktalari (testte sabitlendi): f=0 → 0, f=0.5 → 50, f=1 → 100,
     * f=0.25 → 15 (yariya kadar dogrusal olmayan, ama yay uzunlugu olarak
     * tam olarak ceyrek).
     */
    fun arcPercent(fraction: Double): Int {
        val f = clampFraction(fraction)
        return (PROGRESS_MAX * (1.0 - cos(PI * f)) / 2.0).roundToInt()
    }
}
