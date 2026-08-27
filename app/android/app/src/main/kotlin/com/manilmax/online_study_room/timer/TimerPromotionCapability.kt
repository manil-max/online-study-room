package com.manilmax.online_study_room.timer

import android.app.NotificationManager
import android.content.SharedPreferences
import android.os.Build

/**
 * WP-759 (dinamik-panel) — **TERFININ SON KAPISI: GOZLENEN SONUC.**
 *
 * ## Sorulmayan soru
 *
 * Terfi (promoted ongoing / Live Update) sozlesmesinin dogrulanabilir uc
 * onkosulu vardir ve ucu de ayni seyi sorar:
 *
 *  1. `Build.VERSION.SDK_INT >= MIN_SDK` — platform terfiyi biliyor mu
 *  2. `NotificationManager.canPostPromotedNotifications()` — izin var mi
 *  3. `Notification.hasPromotableCharacteristics()` — bicimimiz uygun mu
 *
 * Ucu birden: **"terfi ISTEYEBILIR MIYIZ?"**
 *
 * Hicbiri: **"terfi VERILDI MI?"**
 *
 * v71'in kok nedeni bu ikisinin ayni sanilmasiydi. Olculen kanit:
 *
 *     .artifacts/wp759-goruntu/32-api36-dumpsys-notification.txt
 *       satir 45: android.requestPromotedOngoing=Boolean (true)   <- ISTEDIK
 *       satir  3: flags=ONGOING_EVENT|ONLY_ALERT_ONCE|NO_CLEAR|FOREGROUND_SERVICE
 *                 originalFlags=ONGOING_EVENT|ONLY_ALERT_ONCE|FOREGROUND_SERVICE
 *                                                              <- VERILMEDI
 *
 * Ayni dumpsys `contentView=null bigContentView=null`, dolu `contentTitle` ve
 * `shortCriticalText` gosteriyor — yani 2. ve 3. onkosul **gecerdi**. Sistem
 * yine de terfi etmedi ve kullanici karsiliksiz olarak bozuk karti gordu.
 *
 * ## Neden izin sorgusu yetmiyor: olculdu
 *
 * `.artifacts/wp759-terfi-olcum/01-api36-TERFI-NEDEN-OLMUYOR.txt`
 * (emulator `odak_api36`, Android 16 / API 36):
 *
 * - `pm list permissions | grep -i promoted` -> **BOS**. Platform
 *   `POST_PROMOTED_NOTIFICATIONS` iznini **hic tanimlamiyor**; manifestteki
 *   satir "requested permissions" listesinde gorunur, "granted" listesinde
 *   asla.
 * - Tum `device_config` namespace taramasi -> yalniz
 *   `android.app.api_rich_ongoing=true`. Yani **API yuzeyi** acik (bu yuzden
 *   `canPostPromotedNotifications()` cagrilabiliyor ve extra'lar kabul
 *   ediliyor), ama terfiyi CIZEN SystemUI bayraklari — `ui_rich_ongoing`,
 *   `status_bar_notification_chips`, `promoted_notification_*` — **yok**.
 * - `dumpsys notification | grep -i promot` -> **BOS**. Servis terfi diye bir
 *   kayit tutmuyor.
 *
 * Boyle bir ortamda uc onkosulun ucu birden "evet" diyebilir; terfi yine
 * olmaz. Onkosullar niyeti olcer, sonucu degil.
 *
 * ## Son kapi
 *
 * Tek dogruluk kaynagi, sistemin BIZIM bildirimimize yazdigi bayraktir:
 * `Notification.FLAG_PROMOTED_ONGOING`. Bildirim gonderilir, geri okunur,
 * bayrak var mi diye bakilir; sonuc kalici yazilir. Terfi etmeyen cihaz bir
 * daha Live Update yoluna girmez.
 *
 * Bu, `dumpsys` ile elle yapilan olcumun kodda kalici karsiligidir — yani
 * "cihazda bakan biri olmadigi icin alti tur boyunca fark edilmedi"
 * durumunun yapisal cozumu.
 *
 * ## Neden her sey bir `object` icinde
 *
 * Bu dosya, ayni pakette es zamanli yazilan `StudyTimerService.kt` ile
 * **hicbir ust duzey ad paylasmaz**. Sunum yolunun nasil secildigi baska bir
 * lane'in isidir ve o dosya bu tur boyunca birkac kez sekil degistirdi;
 * buradaki adlarin oraya carpmamasi gerekir. `object` sarmalayici bunu
 * yapisal olarak garanti eder.
 *
 * Nobetci: `TimerPromotionCapabilityWp759Test`.
 */
internal object TimerPromotion {

    /**
     * Terfi Android 16'da geldi.
     *
     * Kurulu `android-36` platformunda `Build.VERSION_CODES.BAKLAVA` sabiti
     * **yok** (javap ile dogrulandi: liste `VANILLA_ICE_CREAM = 35` ile
     * bitiyor), bu yuzden sayi duz yazilir. Lint `SDK_INT >= 36`
     * karsilastirmasini anlar.
     */
    const val MIN_SDK = 36

    /**
     * `Notification.FLAG_PROMOTED_ONGOING`.
     *
     * Platform sabiti `@FlaggedApi` altindadir; degeri burada sabitlenir ki
     * derleme hedefi degisince sessizce cozulemez hale gelmesin. Dogrulandi:
     *
     *     javap -constants -classpath <sdk>/platforms/android-36/android.jar \
     *         android.app.Notification
     *       public static final int FLAG_PROMOTED_ONGOING = 262144;
     */
    const val FLAG_PROMOTED_ONGOING = 0x0004_0000

    /**
     * Sistemin verdigi terfi kararinin **gozlenmis** hali.
     *
     * Neden kalici: karar her bildirim yapisinda sifirdan sorulursa, terfi
     * etmeyen bir cihazda kullanici her Baslat'ta once bozuk karti gorur.
     * Bir kez olculur, yazilir, o yola bir daha girilmez.
     */
    /**
     * 🔴 WP-760: ad `flutter.` onekiyle yazilir ve bu KASITLIDIR.
     *
     * `shared_preferences` Android'de her anahtari `flutter.` ile onekler; bu
     * servis zaten ayni dosyayi (`FlutterSharedPreferences`) kullaniyor. Onek
     * sayesinde olcum sonucu Dart'tan `timer_promotion_verdict_v1` adiyla
     * OKUNABILIR hale gelir.
     *
     * Neden onemli: bu olcum alti tur boyunca yapildi ama sonucunu **kimse
     * goremiyordu** -- ne sahip, ne biz. "Cihazda ne oldu?" sorusu her turda
     * tahminle cevaplandi. Anahtar artik Hakkinda ekraninda gorunur; sahip
     * bakar, okur, doner dongu biter.
     */
    const val KEY_VERDICT = "flutter.timer_promotion_verdict_v1"

    /** Sistemin terfi karari. */
    enum class Verdict {
        /** Platform terfiyi hic bilmiyor (API < [MIN_SDK]). */
        UNSUPPORTED,

        /** Istendi, sistem VERMEDI. */
        DENIED,

        /** Istendi, sistem VERDI (`FLAG_PROMOTED_ONGOING` olculdu). */
        GRANTED,
    }

    /**
     * Gonderilmis bildirimin bayraklarindan verdict cikarir. **Saf.**
     *
     * @param postedFlags gonderilen bildirimin `Notification.flags` degeri;
     *   `null` = bildirim aktif listede bulunamadi
     * @return `null` = **olcum yapilmadi** (red DEGIL)
     */
    fun observedVerdict(sdkInt: Int, postedFlags: Int?): Verdict? {
        // Terfi olmayan platformda "gozlem" diye bir sey yok.
        if (sdkInt < MIN_SDK) return null
        // 🔴 Bildirimi goremiyorsak bu bir RED DEGILDIR. Aksi halde gonderim
        // ile okuma arasindaki tek bir yaris cihazi kalici damgalardi.
        if (postedFlags == null) return null
        return if (postedFlags and FLAG_PROMOTED_ONGOING != 0) Verdict.GRANTED else Verdict.DENIED
    }

    /**
     * Onkosul sonucunu gozlenen sonucla birlestirir. **Saf.**
     *
     * 🔴 Gozlem onkosulu HER ZAMAN ezer. Sistem "izin var" deyip yine de
     * terfi etmeyebilir — olculen tam olarak budur.
     *
     * @param preconditionsMet 1./2./3. onkosul gecti mi
     * @param observed son kapinin kalici sonucu; `null` = hic olculmedi
     */
    fun effectiveVerdict(preconditionsMet: Boolean, observed: Verdict?): Verdict {
        // Onkosul gecmiyorsa gozlemin anlami yok: platform ya da izin yok.
        if (!preconditionsMet) return Verdict.UNSUPPORTED
        return observed ?: Verdict.GRANTED
    }

    /**
     * Live Update yoluna girilebilir mi? **Saf.**
     *
     * `GRANTED` gozlem yokken de doner ki kapi kendini kilitlemesin: hic
     * terfi istemeyen bir uygulama hic terfi gozlemleyemez. Bir kerelik
     * deneme hakki verilir, sonucunu [observedVerdict] yazar.
     */
    fun mayRequestPromotion(verdict: Verdict): Boolean = verdict == Verdict.GRANTED

    /**
     * Prefs'teki gozlem. Taninmayan deger "hic olculmedi" sayilir.
     *
     * 🔴 YAPI DAMGASI: deger "VERDICT|<Build.FINGERPRINT>" olarak yazilir ve
     * damga eslesmiyorse gozlem GECERSIZ sayilir (null = hic olculmedi).
     *
     * Gerekcesi olculdu: bu turda `odak_api36` imajinda terfi IMKANSIZ cikti
     * (POST_PROMOTED_NOTIFICATIONS izni platformda tanimli degil, cizen
     * arayuz bayragi imajda yok). Damgasiz bir DENIED, kullanici ilerde
     * terfiyi acan bir guncelleme alsa bile SONSUZA KADAR yapisirdi -- yani
     * bir olcum, kalici bir tavana donusurdu. Damga degisince yeniden olculur.
     */
    fun readVerdict(
        prefs: SharedPreferences,
        fingerprint: String = currentFingerprint(),
    ): Verdict? {
        val raw = prefs.getString(KEY_VERDICT, null) ?: return null
        val parts = raw.split(VERDICT_SEPARATOR, limit = 2)
        // Damgasiz eski kayit: hangi yapida olculdugu bilinmiyor -> guvenilmez.
        if (parts.size != 2 || parts[1] != fingerprint) return null
        return when (parts[0]) {
            Verdict.GRANTED.name -> Verdict.GRANTED
            Verdict.DENIED.name -> Verdict.DENIED
            else -> null
        }
    }

    /**
     * Gozlemi kalici yazar.
     *
     * `null` ve `UNSUPPORTED` YAZILMAZ: ikisi de "henuz bilmiyoruz" demektir
     * ve yazilirlarsa bir sonraki gercek olcumu bloke ederlerdi.
     */
    fun writeVerdict(
        prefs: SharedPreferences,
        verdict: Verdict?,
        fingerprint: String = currentFingerprint(),
    ) {
        if (verdict != Verdict.GRANTED && verdict != Verdict.DENIED) return
        prefs.edit()
            .putString(KEY_VERDICT, verdict.name + VERDICT_SEPARATOR + fingerprint)
            .commit()
    }

    /** Verdict ile yapi damgasini ayiran isaret; `FINGERPRINT` icinde gecmez. */
    private const val VERDICT_SEPARATOR = "|"

    /**
     * Yapi damgasi, cihazsiz JVM'de de guvenli.
     *
     * 🔴 `Build.FINGERPRINT` platform tipidir ve unmocked `android.jar`
     * uzerinde **null**'dir; varsayilan parametre olarak dogrudan kullanmak
     * JVM testini NPE ile dusuruyordu. Bu dosyanin acik tasarim hedefi
     * "cihazsiz olculebilir olmak" -- damga o hedefi bozmamali. Bos damga
     * tutarlidir: ayni kosuda yazilan ve okunan deger eslesir.
     */
    internal fun currentFingerprint(): String = (Build.FINGERPRINT as String?).orEmpty()

    // -----------------------------------------------------------------------
    // Ince sarmalayicilar. Icinde KARAR YOKTUR; yalniz sistemden veri okurlar.
    // Cihazsiz JVM'de olculemezler ve olculdugu iddia EDILMEZ.
    // -----------------------------------------------------------------------

    /**
     * 2. onkosul. `null` = sorulamadi.
     *
     * `runCatching`: `canPostPromotedNotifications()` `@FlaggedApi`
     * altindadir; bayragi kapali bir OEM derlemesinde `NoSuchMethodError`
     * atabilir. Terfi sorusu uygulamayi cokertemez.
     */
    fun canSystemPostPromoted(
        manager: NotificationManager,
        sdkInt: Int = Build.VERSION.SDK_INT,
    ): Boolean? {
        if (sdkInt < MIN_SDK) return null
        return runCatching { manager.canPostPromotedNotifications() }.getOrNull()
    }

    /** Gonderilmis bildirimimizin bayraklari; bulunamazsa `null`. */
    fun postedFlags(manager: NotificationManager, notificationId: Int): Int? = runCatching {
        manager.activeNotifications
            .firstOrNull { it.id == notificationId }
            ?.notification
            ?.flags
    }.getOrNull()

    /**
     * Kosan bildirim kurulmadan ONCE cagrilir: terfi yoluna girilebilir mi?
     *
     * Onkosullari kendi sorar, gozlemi prefs'ten okur.
     */
    fun currentVerdict(
        prefs: SharedPreferences,
        manager: NotificationManager,
        sdkInt: Int = Build.VERSION.SDK_INT,
    ): Verdict = effectiveVerdict(
        preconditionsMet = canSystemPostPromoted(manager, sdkInt) == true,
        observed = readVerdict(prefs),
    )

    /**
     * Terfi istenen bildirim gonderildikten SONRA cagrilir: sistem gercekten
     * verdi mi diye bakar ve verdicti kalici yazar.
     *
     * Doner deger cagirana bilgi icindir; kalici etki prefs'tedir. Bir
     * sonraki bildirim yapisinda [currentVerdict] bu verdicti okur.
     *
     * @return gozlenen verdict; `null` = olcum yapilamadi
     */
    fun recordOutcome(
        prefs: SharedPreferences,
        manager: NotificationManager,
        notificationId: Int,
        sdkInt: Int = Build.VERSION.SDK_INT,
    ): Verdict? {
        val verdict = observedVerdict(sdkInt, postedFlags(manager, notificationId))
        writeVerdict(prefs, verdict)
        return verdict
    }
}
