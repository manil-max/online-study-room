package com.manilmax.online_study_room.overlay

import android.content.Context
import android.content.SharedPreferences
import android.graphics.PixelFormat
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.Chronometer
import android.widget.TextView
import androidx.core.content.ContextCompat
import com.manilmax.online_study_room.R
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * WP-764 — **kendi penceremiz.**
 *
 * ## Neden bu yol
 *
 * Alti tur boyunca "dinamik panel" Android'in bildirim yuzeyinden istendi ve
 * hicbirinde cikmadi. Sonunda sebep OLCULDU (WP-763): sahibin Galaxy S23'unde
 * sistem terfiyi **veriyor** -- `FLAG_PROMOTED_ONGOING` gercekten yaziliyor --
 * ama Samsung ortada hicbir sey **cizmiyor**. Ne durum cubugu cipi, ne Now Bar
 * satiri. Ve hicbir API sinyali bunu onceden soylemiyor: bayrak yalniz "kabul
 * ettim" der, "gosterecegim" demez.
 *
 * Yani sorun izin degil, **baskasinin yuzeyine bagimli olmak**. Bu dosya o
 * bagimliligi kaldirir: pencereyi biz aciyoruz, iceriginin cizilecegi garanti.
 *
 * ## Bildirimden farki -- ve kazanci
 *
 * `RemoteViews` DEGILDIR. Bildirim panelinde ConstraintLayout, ozel View,
 * animasyon, `autoSizeTextType` kullanamiyoruz cunku gorunumu baska bir surec
 * (SystemUI) sisiriyor. Burada pencere BIZIM surecimizde yasar: normal bir
 * Android View agacidir, hicbir kisit yoktur.
 *
 * ## 🔴 NE VERMEZ -- baştan yazili durur ki bir sonraki tur yanlis yerde aramasin
 *
 * * **Kilit ekraninda GORUNMEZ.** `TYPE_APPLICATION_OVERLAY` pencereleri
 *   keyguard'in ustune cizilmez. Kilit ekrani icin elimizdeki sey bildirim
 *   kartidir ve o degismiyor.
 * * Bildirim golgesi, son uygulamalar ekrani ve `FLAG_SECURE` tasiyan ekranlar
 *   (banka uygulamalari) uzerine de cizilmez.
 * * Izin normal calisma-zamani penceresiyle ISTENEMEZ; kullanici Ayarlar'da
 *   elle acar ([permissionSettingsIntentNeeded]).
 *
 * ## WP-774 (sahip, cihazda) -- kok neden sonradan bulundu
 *
 * "Samsung cizmiyor" teshisi YANLISTI: Samsung, Now Bar listesini onayladigi
 * paketlerden kuruyor; onaysiz uygulama Developer options > "Live
 * notifications for all apps" acikken cizilir (WP-772). Serit yine de
 * kaldi: kilit ekrani disinda her uygulamanin ustunde duran, bizim
 * cizdigimiz bir yuzey. WP-775: sahibin cizimi -- logo / buyuk MM:SS /
 * metinli hap dugme (beyaz "Durdur", bosta sari "Baslat"); durunca KAYBOLMAZ.
 *
 * Nobetci: `TimerOverlayWp764Test`.
 */
internal object TimerOverlay {

    /**
     * Kullanicinin acik tercihi. **Varsayilan KAPALI.**
     *
     * 🔴 Bu varsayilan bir uslup tercihi degil, bu turda ucuncu kez ihlal edilen
     * bir kuralin karsiligi: WP-753 v71'de, WP-762 v74'te deneysel bir yolu
     * VARSAYILAN yapip calisan bildirimi bozdu. Sahip kurali kendi cumlesiyle
     * koydu: "test ederken sadece biz gorelim, digerlerinde normal olsun".
     * Overlay kapali dogar; yalniz gizli gelistirici bolumunden acilir.
     */
    const val KEY_ENABLED = "flutter.timer_overlay_enabled"

    /** Serit konumu (ekranin sol-ust kosesine gore piksel). */
    const val KEY_X = "flutter.timer_overlay_x"
    const val KEY_Y = "flutter.timer_overlay_y"

    /**
     * Serit cizilmeli mi? **Saf** -- cihazsiz JVM'de olculur.
     *
     * Iki kosulun IKISI de sart ve ikisi de AYRI seyler:
     *  - kullanici acmis olmali (varsayilan kapali);
     *  - izin verilmis olmali (kullanici Ayarlar'dan geri ALABILIR, o yuzden
     *    her seferinde sorulur, bir kez olculup saklanmaz).
     *
     * 🔴 WP-774: "sayac kosuyor olmali" kosulu KALKTI. Sahip cihazda: serit
     * durunca yok oluyordu, yeniden baslatilamiyordu. Serit bosta da durur;
     * ne cizecegi (`00:00` + Baslat) [show] icindeki `running` ile secilir.
     */
    fun shouldShow(enabled: Boolean, permitted: Boolean): Boolean =
        enabled && permitted

    /** Kullanici seridi acti mi. */
    fun isEnabled(prefs: SharedPreferences): Boolean =
        prefs.getBoolean(KEY_ENABLED, false)

    /**
     * Izin var mi.
     *
     * 🔴 Sonuc SAKLANMAZ. Kullanici izni Ayarlar'dan istedigi an geri alabilir
     * ve bundan haberdar olmayiz; onbelleklenmis bir "izin var" degeri
     * `addView` sirasinda `BadTokenException` ile cokerdi.
     */
    fun isPermitted(context: Context): Boolean =
        runCatching { Settings.canDrawOverlays(context) }.getOrDefault(false)

    /**
     * Izin ekrani acilmali mi? **Saf.**
     *
     * Kullanici seridi actiysa ama izin yoksa, ona yalniz "calismiyor" demek
     * yetmez -- izni verecegi yeri de gostermek gerekir.
     */
    fun permissionSettingsIntentNeeded(enabled: Boolean, permitted: Boolean): Boolean =
        enabled && !permitted

    /**
     * Pencere turu. **Saf.**
     *
     * `TYPE_APPLICATION_OVERLAY` API 26'da geldi; bu uygulamanin minSdk'si daha
     * dusuk oldugu icin eski cihazlarda `TYPE_PHONE` kullanilir. Sabitler
     * burada duz sayi olarak yazilmaz; platform sabitleri okunur ki bir surum
     * yukseltmesinde sessizce kaymasinlar.
     */
    fun windowType(sdkInt: Int = Build.VERSION.SDK_INT): Int =
        if (sdkInt >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

    /**
     * Bir dokunusun SURUKLEME mi yoksa TIKLAMA mi sayilacagi. **Saf.**
     *
     * 🔴 Esik olmadan serit tiklanamaz hale gelir: parmak birkac piksel kayar,
     * `ACTION_UP` surukleme sayilir ve dokunma hicbir sey yapmaz. Esik
     * `ViewConfiguration`in dokunma egimiyle ayni mantiktadir ama saf kalsin
     * diye disaridan verilir.
     */
    fun isDrag(dx: Float, dy: Float, touchSlopPx: Int): Boolean =
        abs(dx) >= touchSlopPx || abs(dy) >= touchSlopPx

    /**
     * Seridin ekran icinde kalmasi. **Saf.**
     *
     * Surukleme sirasinda serit ekranin disina tasabilir ve bir daha
     * yakalanamaz. Konum kalici yazildigi icin bu, seridi SONSUZA KADAR
     * gorunmez yapardi.
     */
    fun clampX(x: Int, viewWidth: Int, screenWidth: Int): Int =
        x.coerceIn(0, (screenWidth - viewWidth).coerceAtLeast(0))

    fun clampY(y: Int, viewHeight: Int, screenHeight: Int): Int =
        y.coerceIn(0, (screenHeight - viewHeight).coerceAtLeast(0))

    // -----------------------------------------------------------------------
    // Pencere yonetimi. Karar YOKTUR; kararlar yukaridaki saf fonksiyonlarda.
    // -----------------------------------------------------------------------

    private var view: View? = null

    /**
     * Seridi gosterir; zaten varsa yalnizca durumunu tazeler.
     *
     * WP-774: iki durum, tek dugme.
     *  - kosarken: kronometre akar, dugme Durdur (kare);
     *  - bosta: `00:00` durur, dugme Baslat (ucgen).
     * Dugme tek komut gonderir; servis bosta baslatirken kullanicinin SON
     * SECILI dersini ve modunu kullanir (widget ile ayni yol).
     *
     * @param onTap serite dokununca (uygulamayi ac)
     * @param onToggle dugmeye basinca (kosarken Durdur, bosta Baslat)
     */
    fun show(
        context: Context,
        running: Boolean,
        startedAtMs: Long,
        countDown: Boolean,
        totalSeconds: Int,
        onTap: () -> Unit,
        onToggle: () -> Unit,
    ) {
        if (!isPermitted(context)) return
        val wm = context.getSystemService(Context.WINDOW_SERVICE) as? WindowManager ?: return
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val existing = view
        if (existing != null) {
            bindState(existing, running, startedAtMs, countDown, totalSeconds)
            return
        }
        val root = LayoutInflater.from(context).inflate(R.layout.timer_overlay_pill, null)
        bindState(root, running, startedAtMs, countDown, totalSeconds)
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            windowType(),
            // 🔴 NOT_FOCUSABLE sart: aksi halde serit klavyeyi calar ve altindaki
            // uygulamada yazi yazilamaz. NOT_TOUCHABLE ise KULLANILMAZ --
            // dokunma ve suruklemeyi biz istiyoruz.
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = prefs.getInt(KEY_X, 0)
            y = prefs.getInt(KEY_Y, 0)
        }
        attachTouch(root, params, wm, prefs, onTap, onToggle)
        // `addView` izin o an geri alinmissa cokebilir; serit bir kolayliktir,
        // uygulamayi dusuremez.
        val added = runCatching { wm.addView(root, params) }.isSuccess
        view = if (added) root else null
    }

    /** Seridi kaldirir. Yoksa hicbir sey yapmaz. */
    fun hide(context: Context) {
        val current = view ?: return
        view = null
        val wm = context.getSystemService(Context.WINDOW_SERVICE) as? WindowManager ?: return
        runCatching { wm.removeView(current) }
    }

    /** Iki durumu tek yerden cizer. */
    private fun bindState(
        root: View,
        running: Boolean,
        startedAtMs: Long,
        countDown: Boolean,
        totalSeconds: Int,
    ) {
        val chronometer = root.findViewById<Chronometer>(R.id.overlay_timer_elapsed)
        val action = root.findViewById<TextView>(R.id.overlay_timer_action)
        if (!running) {
            // Bosta: sayac durur ve `00:00` gosterir (`setBase` metni yeniden
            // cizer); dugme SARI hapta "Baslat" (WP-775, sahibin cizimi).
            chronometer.stop()
            chronometer.isCountDown = false
            chronometer.base = SystemClock.elapsedRealtime()
            action.setText(R.string.action_start)
            action.setBackgroundResource(R.drawable.timer_overlay_action_idle_bg)
            action.setTextColor(
                ContextCompat.getColor(root.context, R.color.timer_overlay_action_idle_ink),
            )
            return
        }
        // 🔴 Sira onemli: bayrak ONCE, taban SONRA -- `setBase` metni yeniden
        // cizer. Ayni tuzak bildirim panelinde de vardi (WP-759).
        chronometer.isCountDown = countDown
        val nowMs = System.currentTimeMillis()
        val nowElapsed = SystemClock.elapsedRealtime()
        val targetMs = if (countDown && totalSeconds > 0) {
            startedAtMs + totalSeconds * 1000L
        } else {
            startedAtMs
        }
        chronometer.base = nowElapsed - (nowMs - targetMs)
        chronometer.start()
        // Kosarken BEYAZ hapta "Durdur".
        action.setText(R.string.action_stop)
        action.setBackgroundResource(R.drawable.timer_overlay_action_bg)
        action.setTextColor(ContextCompat.getColor(root.context, R.color.timer_overlay_action_ink))
    }

    private fun attachTouch(
        root: View,
        params: WindowManager.LayoutParams,
        wm: WindowManager,
        prefs: SharedPreferences,
        onTap: () -> Unit,
        onToggle: () -> Unit,
    ) {
        root.findViewById<View>(R.id.overlay_timer_action).setOnClickListener { onToggle() }
        val slop = android.view.ViewConfiguration.get(root.context).scaledTouchSlop
        var downX = 0f
        var downY = 0f
        var startX = 0
        var startY = 0
        var dragging = false
        root.setOnTouchListener { v, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    downX = event.rawX
                    downY = event.rawY
                    startX = params.x
                    startY = params.y
                    dragging = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - downX
                    val dy = event.rawY - downY
                    if (!dragging && isDrag(dx, dy, slop)) dragging = true
                    if (dragging) {
                        val metrics = v.resources.displayMetrics
                        params.x = clampX(
                            (startX + dx).roundToInt(), v.width, metrics.widthPixels,
                        )
                        params.y = clampY(
                            (startY + dy).roundToInt(), v.height, metrics.heightPixels,
                        )
                        runCatching { wm.updateViewLayout(v, params) }
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (dragging) {
                        // Konum kalici: her acilista seridi yeniden yerlestirmek
                        // kullanicinin isi olmamali.
                        prefs.edit().putInt(KEY_X, params.x).putInt(KEY_Y, params.y).apply()
                    } else {
                        onTap()
                    }
                    true
                }
                else -> false
            }
        }
    }
}
