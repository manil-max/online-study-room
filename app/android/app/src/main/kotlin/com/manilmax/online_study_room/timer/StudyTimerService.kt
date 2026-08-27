package com.manilmax.online_study_room.timer

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.os.HandlerCompat
import com.manilmax.online_study_room.MainActivity
import com.manilmax.online_study_room.R
import com.manilmax.online_study_room.widgets.TimerWidgets
import com.manilmax.online_study_room.widgets.rememberedSubjectId

/**
 * WP-753: Zengin özel panelin prefs anahtarı.
 *
 * 🔴 v71 SAHA GERI BILDIRIMI (2026-08-26) ILE VARSAYILAN `true`'YA DONDU.
 *
 * WP-753 varsayilani `false` (Live Update) yapmisti ve o karar CIHAZDA HIC
 * DOGRULANMADAN yayina cikti. Sahibin Galaxy S23'unde sonuc: bildirimde sayac
 * `00:00` gorunuyor ve Start/Stop dugmesi hic cizilmiyor -- yani uygulamanin
 * cekirdek islevi bildirimden kullanilamaz hale geldi.
 *
 * Iki ayri kusur birlestiler (IKISI DE WP-759'da KAPANDI, asagi bak):
 *  - Bosta duran bildirimin TUM icerigi sabit "00:00" idi -- kullanici bunu
 *    "sayac sifirlanmis" diye okuyor. Artik [idleTimerNotificationPlan]
 *    gercek durum metni tasiyor ve sabit saat metni YAZILMIYOR.
 *  - Dugme "gitmis" gorunuyordu. Bunun sebebi ikon degil KONTRASTTI (asagi).
 *
 * 🔴 WP-759 — GERI ALINAN TESHIS. Buraya bir kez "ikonsuz `addAction(0, ...)`
 * modern Android'de cizilmeyebilir" yazildi. Emulatorde YANLISLANDI:
 * API 36 GENISLETILMIS bildirimde ikonsuz eylem mavi metin dugmesi olarak
 * sorunsuz cizildi (`.artifacts/wp759-goruntu/36c-api36-LIVEUPDATE-BOSTA-TAMKART.png`).
 * Dugmenin gorunmedigi hal DARALMIS bildirimdir ve Android daralmis bildirimde
 * eylemleri ZATEN gostermez (`37b-api36-LIVEUPDATE-BOSTA-DARALMIS-YAKIN.png`) --
 * ikon eklemek bunu degistirmez.
 *
 * SAHIBIN "tus gitmis" SIKAYETININ GERCEK SEBEBI: zengin panelin hap dugmesi
 * rengini TEMA NITELIKLERINDEN aliyordu. `RemoteViews` uygulamanin
 * `ApplicationInfo` temasiyla sisirilir, `<application>` etiketinde
 * `android:theme` yoktur, yani nitelikler platformun ACIK varsayilanindan
 * cozulur; bildirim golgesi koyu oldugunda siyah ustune siyah kalir.
 * Olculen kontrast: API 36 koyu 1.08:1, API 33 koyu 1.04:1
 * (`50-OZET-dugme-acik-vs-koyu.png`). Duzeltme
 * `res/values/timer_notification_colors.xml` icindedir; nobetci
 * `TimerNotificationPanelWp759Test`.
 *
 * Varsayilan, sahibin v43'te KABUL ETTIGI zengin panele geri alindi.
 * Live Update yolu silinmedi: `timer_panel_expanded=false` yazilirsa kosar.
 */
internal const val KEY_PANEL_EXPANDED = "flutter.timer_panel_expanded"

/**
 * Kullanicinin ACIK tercihi; **yazilmamissa `null` = OTOMATIK**.
 *
 * 🔴 WP-760: burasi eskiden `getBoolean(KEY, true)` idi, yani "yazilmamis"
 * ile "kullanici zengin panel istedi" ayni sey sayiliyordu. Sonucu olculdu ve
 * agirdi: bkz. [useRichPanel]. Uc durum uc ayri seydir ve ayri kalmalidir.
 */
/**
 * Yoklama sonrasi yeniden gonderim karari. **Saf.**
 *
 * Ayrintili gerekce cagri yerindedir; ozet: RED olmali, sayac hala kosmali ve
 * kosan sey AYNI kosu olmali.
 */
internal fun shouldRepostAfterProbe(
    verdict: TimerPromotion.Verdict?,
    isRunning: Boolean,
    probedStartedAtMs: Long,
    currentStartedAtMs: Long,
): Boolean = verdict == TimerPromotion.Verdict.DENIED &&
    isRunning &&
    probedStartedAtMs == currentStartedAtMs

/** Yoklamanin sistem gonderimini beklemesi gereken sure. */
internal const val PROMOTION_PROBE_DELAY_MS = 400L

/**
 * Zengin panelde faz etiketi olarak NE yazilir. **Saf.**
 *
 * `0` = hic yazilmaz. Odakta bilerek bostur: panel yalniz calisirken vardir,
 * "FOCUS" yazmak tekrardir. Etiket yalniz ISTISNA durumu (mola) isaretler.
 */
internal fun panelPhaseLabelRes(isBreak: Boolean, shortCriticalTextRes: Int): Int =
    if (isBreak) shortCriticalTextRes else 0

internal fun panelOverride(prefs: SharedPreferences): Boolean? =
    if (prefs.contains(KEY_PANEL_EXPANDED)) {
        prefs.getBoolean(KEY_PANEL_EXPANDED, true)
    } else {
        null
    }

/**
 * Sunum yolu karari. **Saf** — cihazsiz JVM'de olculur.
 *
 * 🔴 WP-760 KOK NEDEN. Bu karar v72'ye kadar soyle yaziliyordu:
 *
 *     richPanel = useV43CustomPanel() || !mayRequestPromotion(...)
 *     useV43CustomPanel = prefs.getBoolean(KEY_PANEL_EXPANDED, true)   // <- true
 *
 * Sol taraf her zaman `true` oldugu icin `||` kisa devre yapiyordu: sag taraf
 * -- yani sistemin terfiyi verip vermedigi -- **hic sorulmuyordu**. Zincirin
 * devami `requestPromotedOngoing = !usesCustomView`, yani uygulama
 * `setRequestPromotedOngoing(true)`i HICBIR cihazda HIC cagirmiyordu.
 *
 * Bunun anlami: terfiyi destekleyen bir telefonda bile dinamik panel
 * cikamazdi. Terfi kapisi (`TimerPromotion`) eksiksiz yazilmis ama devreye
 * hic girmemisti -- bu deponun tekrar eden kusuru: "bitmis arka uc,
 * baglanmamis on uc". Alti tur boyunca aranan sey buydu.
 *
 * Yeni kural, oncelik SIRASI degismis halidir:
 *  - Kullanici acik tercih yazmissa **o kazanir** (iki yonde de).
 *  - Yazmamissa **otomatik**: sistem terfi ediyorsa terfi, etmiyorsa zengin panel.
 *
 * Yani varsayilan artik "her zaman zengin panel" degil, "cihaz ne yapabiliyorsa
 * o". Terfi etmeyen cihazda gorunen sey degismez; terfi eden cihazda ilk kez
 * dinamik panel cikar.
 *
 * @param override kullanicinin acik tercihi; `null` = yazmamis (otomatik)
 * @param mayPromote sistem terfiyi veriyor mu ([TimerPromotion.mayRequestPromotion])
 */
internal fun useRichPanel(override: Boolean?, mayPromote: Boolean): Boolean =
    when (override) {
        // 🔴 WP-763: OTOMATIK artik CALISAN paneli secer.
        //
        // WP-760'ta otomatik "sistem terfi veriyorsa terfi et" demekti ve o
        // kural KAGITTA dogruydu. Cihazda olculdu ve yanlislandi: sahibin
        // S23'unde sistem terfiyi VERIYOR (FLAG_PROMOTED_ONGOING yaziliyor)
        // ama Samsung ortada hicbir sey CIZMIYOR -- ne durum cubugu cipi ne
        // Now Bar satiri. Yani bedeli oduyoruz, karsiligini almiyoruz:
        // terfi eden bildirim ozel gorunum tasiyamadigi icin sahibin v43'te
        // kabul ettigi zengin panel gidiyor, yerine sade bir kart geliyor.
        //
        // Elimizde "cip GERCEKTEN cizilecek mi" sorusunu onceden cevaplayan
        // bir sinyal YOK; bayrak yalniz "sistem kabul etti" der. O yuzden
        // otomatik akilli davranamaz ve calisani secer.
        null -> true
        // Kullanici acikca zengin panel dedi.
        true -> true
        // Kullanici acikca Live Update dedi: sistem izin veriyorsa DENE.
        // Vermiyorsa (API < 36 ya da izin yok) sade karta dusup hicbir sey
        // kazanmamanin anlami yok -- zengin panel korunur.
        false -> !mayPromote
    }

/**
 * WP-753: durum çubuğu / Live Update çipi ikonu.
 *
 * Monokrom vektör olmak **zorunda**; renkli adaptif launcher ikonu
 * (`R.mipmap.ic_launcher`) yanlış türdür. Sabit olarak durur ki cihazsız JVM
 * testi türü ölçebilsin — `baseBuilder()` bir `Context` istediği için o yol
 * cihazsız ölçülemez.
 */
internal val TIMER_NOTIFICATION_SMALL_ICON: Int = R.drawable.ic_stat_focus_timer

/**
 * Bosta duran sayac bildiriminin **saf** sunum karari.
 *
 * 🔴 WP-759, EMULATORDE OLCULDU (API 33 + API 36, acik ve koyu golge):
 * eskiden boyle bir karar yoktu. `buildIdleRemoteViews` kartin TEK metin
 * alanina `IDLE_NOTIFICATION_TIMER_TEXT = "00:00"` yaziyor, ustelik ayni
 * metni Chronometer'in `format`ina da veriyordu. Kartta baska hicbir sey
 * yoktu: ne durum cumlesi, ne "hazir", ne ders adi. Sahip bunu "sayac
 * sifirlandi/bozuldu" diye okudu ve haksiz degildi -- SIFIRLANMIS BIR SAAT,
 * "hicbir sey kosmuyor"un gorsel karsiligi degildir; kosan ama donmus bir
 * sayacin gorsel karsiligidir.
 *
 * Karar `Notification` nesnesinden ayri, saf veri olarak durur ki cihazsiz
 * JVM olcebilsin (WP-622 `endBreakPlan` / WP-753 `runningTimerNotificationPlan`
 * deseni). Nobetci: `IdleNotificationWp759Test`.
 */
internal data class IdleTimerNotificationPlan(
    /** 0 OLAMAZ: kart bir durum cumlesi tasimak ZORUNDA. */
    val titleRes: Int,
    /** 0 OLAMAZ: baslik tek basina ne yapilacagini soylemiyor. */
    val bodyRes: Int,
    val actionLabelRes: Int,
    /**
     * 0 OLAMAZ: ikon, eylemin bildirim golgesi DISINDAKI yuzeylerde (Wear,
     * Auto, eski surumler, terfi cipi) tek gorsel karsiligidir.
     *
     * 🔴 WP-759 duzeltmesi: bu alanin gerekcesi "ikonsuz eylem cizilmeyebilir"
     * DEGILDIR -- o teshis emulatorde yanlislandi (bkz. [KEY_PANEL_EXPANDED]).
     * Golgede ikon zaten cizilmez; bosta kartta dokunulacak sey kalmamasinin
     * sebebi eylemin degil, DARALMIS bildirimin davranisiydi.
     */
    val actionIconRes: Int,
    /**
     * Bosta kart ozel `RemoteViews` TASIMAZ. Dugmeyi sistem cizer, yani rengi
     * golgenin GERCEK temasindan gelir. Ozel panelin dugmesi uygulama tema
     * niteliklerinden renk aliyordu ve koyu golgede 1.08:1 ile kayboluyordu.
     */
    val usesCustomView: Boolean,
    /**
     * Karta yazilan SABIT saat metni. `null` OLMAK ZORUNDA; bu alan yalniz
     * kusurun geri gelisini olcebilmek icin duruyor.
     */
    val frozenClockText: String?,
)

/** Bosta kartin tek kaynagi. */
internal fun idleTimerNotificationPlan(): IdleTimerNotificationPlan =
    IdleTimerNotificationPlan(
        titleRes = R.string.timer_ready,
        bodyRes = R.string.timer_idle_body,
        actionLabelRes = R.string.action_start,
        actionIconRes = TIMER_NOTIFICATION_SMALL_ICON,
        usesCustomView = false,
        frozenClockText = null,
    )

/** Koşan sayaç bildiriminin sunum yolu. */
internal enum class TimerNotificationStyle {
    /**
     * v43 zengin özel panel. `RemoteViews` taşır, bu yüzden Android **terfi
     * ettiremez**: *"Must NOT have any customContentView set (no RemoteViews)"*.
     * Geri dönüş valfi olarak durur, terfi istemez.
     */
    CUSTOM_PANEL,

    /**
     * Açık uçlu kronometre (stopwatch).
     *
     * 🔴 WP-762: bu dal `ProgressStyle` TAŞIMIYORDU ve terfinin görünmemesinin
     * en olası sebebi bu. Android 16'nın Live Update yüzeyleri (durum çubuğu
     * çipi, Now Bar) `ProgressStyle` etrafında kuruludur; `requestPromotedOngoing`
     * tek başına yalnız BAYRAĞI aldırır. Sahibin S23'ünde ölçülen tam olarak
     * buydu: `FLAG_PROMOTED_ONGOING` yazıldı, ekranda hiçbir şey çizilmedi.
     *
     * Açık uçlu koşunun toplamı yoktur, o yüzden ilerleme **belirsizdir**
     * (`setProgressIndeterminate`). Uydurma bir toplam yazmak yerine API'nin
     * bunun için var olan yolu kullanılır.
     */
    STANDARD,

    /** Hedefi olan mod (pomodoro/geri sayım): `ProgressStyle`, terfi edilebilir. */
    PROGRESS,
}

/**
 * Koşan bildirimin **saf** sunum kararı — cihazsız JVM'de ölçülebilsin diye
 * `Context`/`Notification` dokunmadan hesaplanır (WP-622'deki `endBreakPlan`
 * deseni). Bu kararın nöbetçisi `TimerLiveUpdateWp753Test`tir.
 */
internal data class TimerNotificationPlan(
    val style: TimerNotificationStyle,
    /**
     * Kisa durum cumlesi. 🔴 WP-759: ozel panel yolunda da 0 OLAMAZ.
     * `DecoratedCustomViewStyle` basligi cizmez, ama bildirim gecmisi/TalkBack/
     * `NotificationListenerService` onu okur.
     */
    val titleRes: Int,
    val bodyRes: Int,
    /**
     * KISA faz etiketi (Odak/Mola). Iki yuzeyi birden besler:
     *  - Live Update yolunda `setShortCriticalText` (0 = yazilmaz; cip metnini
     *    `when` kronometresi tasir),
     *  - zengin panel yolunda panelin GORUNEN faz isareti (0 OLAMAZ; WP-759
     *    kusur 3'te mola ile odak bildirimde ayirt edilemiyordu).
     */
    val shortCriticalTextRes: Int,
    val whenMs: Long,
    val countDown: Boolean,
    val progressSeconds: Int,
    val totalSeconds: Int,
) {
    val usesCustomView: Boolean get() = style == TimerNotificationStyle.CUSTOM_PANEL

    /**
     * Terfi yalnız özel görünüm **taşımayan** yolda istenir. Altı denemenin
     * kök nedeni tam olarak buydu: zengin panel ile Live Update birbirini
     * dışlar, ikisi aynı bildirimde tutulamaz.
     */
    val requestPromotedOngoing: Boolean get() = !usesCustomView
}

/**
 * WP-753: sunum yolunu seçer.
 *
 * Çip metni kararı resmî belgeden çıkar
 * (<https://developer.android.com/develop/ui/views/notifications/live-update>):
 * *"The when time is in the past: The text isn't shown"* ve *"The Chronometer
 * timer is shown in the chip as long as it is positive"*.
 * - **Açık uçlu kronometre**: `when` başlangıç anıdır, yani GEÇMİŞTE kalır →
 *   çip süreyi çizemez; kısa kritik metin (Odak/Mola) şart.
 * - **Hedefli mod**: `when` bitiş anıdır, yani GELECEKTEDİR → çipte canlı geri
 *   sayım akar; sabit kısa metin o canlı sayıyı gölgelemesin diye yazılmaz.
 */
internal fun runningTimerNotificationPlan(
    richPanel: Boolean,
    isBreak: Boolean,
    targetSeconds: Int?,
    startedAtMs: Long,
    nowMs: Long,
): TimerNotificationPlan {
    val titleRes = if (isBreak) R.string.timer_break_title else R.string.timer_focusing_title
    val bodyRes = if (isBreak) R.string.timer_break_body else R.string.timer_focusing_body
    val phaseLabelRes = if (isBreak) {
        R.string.timer_subtext_break
    } else {
        R.string.timer_subtext_focus
    }
    if (richPanel) {
        // 🔴 WP-759 kusur 2: bu dal `targetSeconds`i TAMAMEN atiyordu
        // (`countDown = false`, `totalSeconds = 0`). Emulatorde olculdu:
        // mode=pomodoro / targetSeconds=300 / phase=rest ile baslatilan sayac
        // uygulamada 5:00'dan GERIYE sayarken bildirimde 00:07'den ILERI
        // sayiyordu (`.artifacts/wp759-goruntu/28b-api36-MOLA-YAKIN.png`).
        // Hedef, sunum yolundan bagimsizdir: zengin panel de geri saymali.
        val richTotal = targetSeconds?.takeIf { it > 0 }
        return TimerNotificationPlan(
            style = TimerNotificationStyle.CUSTOM_PANEL,
            // 🔴 WP-759 kusur 3: ikisi de 0'di ve builder `setContentTitle("")`
            // yaziyordu. `DecoratedCustomViewStyle` basligi CIZMEZ ama bildirim
            // gecmisi, TalkBack ve NotificationListener onu okur; bos birakmak
            // sayaci o yuzeylerde isimsiz birakiyordu. Panelin GORUNEN faz
            // isareti ayrica `shortCriticalTextRes` ile cizilir.
            titleRes = titleRes,
            bodyRes = bodyRes,
            shortCriticalTextRes = phaseLabelRes,
            whenMs = if (richTotal != null) startedAtMs + richTotal * 1000L else startedAtMs,
            countDown = richTotal != null,
            progressSeconds = if (richTotal == null) {
                0
            } else {
                ((nowMs - startedAtMs) / 1000L).coerceIn(0L, richTotal.toLong()).toInt()
            },
            totalSeconds = richTotal ?: 0,
        )
    }
    val total = targetSeconds?.takeIf { it > 0 }
        ?: return TimerNotificationPlan(
            style = TimerNotificationStyle.STANDARD,
            titleRes = titleRes,
            bodyRes = bodyRes,
            shortCriticalTextRes = phaseLabelRes,
            whenMs = startedAtMs,
            countDown = false,
            progressSeconds = 0,
            totalSeconds = 0,
        )
    return TimerNotificationPlan(
        style = TimerNotificationStyle.PROGRESS,
        titleRes = titleRes,
        bodyRes = bodyRes,
        // 🔴 WP-762: burasi `0` idi -- yani hedefi olan modda cipin YAZISI hic
        // gonderilmiyordu. Cip once `shortCriticalText`i cizer; bos birakmak
        // terfi edilmis bildirimi icerik olarak SESSIZ birakir.
        shortCriticalTextRes = phaseLabelRes,
        whenMs = startedAtMs + total * 1000L,
        countDown = true,
        progressSeconds = ((nowMs - startedAtMs) / 1000L)
            .coerceIn(0L, total.toLong())
            .toInt(),
        totalSeconds = total,
    )
}

/**
 * Zengin panelin `Chronometer` **tabani** (`elapsedRealtime` ekseninde).
 *
 * 🔴 WP-759 kusur 2'nin ikinci yarisi. `Chronometer` iki yonu AYNI alandan
 * cizer ama TERS okur:
 *  - yukari sayarken `now - base` -> taban BASLANGIC anidir,
 *  - geri sayarken `base - now`   -> taban BITIS anidir.
 * Eski kod her iki halde de baslangic anini yaziyor ve
 * `setChronometerCountDown`u hic cagirmiyordu; sonuc, pomodoro molasinin
 * bildirimde yukari saymasiydi. Hesap burada SAF durur ki cihazsiz JVM
 * olcebilsin -- `RemoteViews` uzerinden olculemez.
 */
internal fun panelChronometerBaseMs(
    plan: TimerNotificationPlan,
    startedAtMs: Long,
    nowMs: Long,
    nowElapsedMs: Long,
): Long {
    val startedElapsedMs = nowElapsedMs - (nowMs - startedAtMs)
    return if (plan.countDown) {
        startedElapsedMs + plan.totalSeconds * 1000L
    } else {
        startedElapsedMs
    }
}

/**
 * Çalışma sayacının **native** foreground servisi (V8-A · WP-42/51 birleşik).
 *
 * Neden native: Kullanıcı uygulamayı tamamen kapatmışken bile widget/bildirim
 * üzerinden **Başlat/Durdur** çalışsın diye. Bir BroadcastReceiver (widget veya
 * bildirim aksiyonu) bu servisi `startForegroundService` ile ayağa kaldırır;
 * Flutter motoruna ihtiyaç yoktur.
 *
 * Sorumluluk sınırı (önemli): Bu servis **oturum KAYDETMEZ**. Durdur'da tamamlanan
 * çalışma aralığını yalnızca `timer_pending_intervals` kuyruğuna yazar; gerçek
 * server-authoritative oturum yazımı, uygulama açılınca Dart tarafındaki
 * `StudyTimerNotifier._reconcileBackgroundTimer` tarafından yapılır. Böylece native
 * taraf "aptal" kalır: bildirim + prefs + widget yönetir, muhasebe Dart'ta.
 *
 * Yaşam döngüsü / çökme güvenliği (beta-v13):
 * - `START_NOT_STICKY`: Süreç öldürülürse Android servisi **null intent ile
 *   yeniden başlatmasın**. START_STICKY yeniden başlatması `startForeground`
 *   çağrılmadan gelir ve Android 12+'da `ForegroundServiceDidNotStartInTimeException`
 *   ile açılışta çökme döngüsü yaratıyordu. Durum zaten prefs'te; otomatik
 *   yeniden başlatmaya gerek yok.
 * - Her komut yolu (Başlat **ve** Durdur) 5 sn içinde `startForeground` çağırır;
 *   arka plandan getForegroundService ile ayağa kalkan servis kuralı bozmaz.
 * - Bildirim aksiyonları `getForegroundService` kullanır; uygulama kapalıyken
 *   arka plan servis başlatma yasağına (`BackgroundServiceStartNotAllowed`) takılmaz.
 */
class StudyTimerService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Hiçbir komut yolu uygulamayı çökertmesin: FGS bildirimleri/OEM kısıtları
        // beklenmedik istisna atabilir; servis sessizce toparlanmalı.
        try {
            when (intent?.action) {
                ACTION_START -> {
                    val startedAtMs =
                        intent.getLongExtra(EXTRA_STARTED_AT_MS, System.currentTimeMillis())
                    // 🔴 WP-645: EXTRA_MODE yoksa "stopwatch" DEGIL, kullanicinin
                    // sectigi mod. Bildirimin Baslat PendingIntent'i (actionPending)
                    // moda hic deginmiyor; eski `?: "stopwatch"` o yolu sessizce
                    // kronometreye ceviriyordu.
                    val startPlan = TimerStateStore.nativeStartPlan(prefs())
                    val mode = intent.getStringExtra(EXTRA_MODE) ?: startPlan.mode
                    val phase = intent.getStringExtra(EXTRA_PHASE) ?: "work"
                    val cycle = intent.getIntExtra(EXTRA_CYCLE, 1).coerceAtLeast(1)
                    // Intent hedefi tasimiyorsa (bildirimin Baslat'i tasimaz) ve
                    // baslatilan mod kullanicinin sectigi modsa, hedef plandan gelir.
                    val targetSeconds = intent.getIntExtra(EXTRA_TARGET_SECONDS, 0)
                        .takeIf { it > 0 }
                        ?: startPlan.targetSeconds.takeIf { mode == startPlan.mode }
                    // Bildirimdeki Başlat intent'i ders extra'sı taşımaz. Boş
                    // yazmak son seçimi her seferinde Genel'e düşürüyordu;
                    // widget ile aynı hesap-kapsamlı kalıcı tercih kullanılır.
                    val subjectId = if (intent.hasExtra(EXTRA_SUBJECT_ID)) {
                        intent.getStringExtra(EXTRA_SUBJECT_ID).orEmpty()
                    } else {
                        rememberedSubjectId(prefs())
                    }
                    val liveRunId = intent.getStringExtra(EXTRA_LIVE_RUN_ID).orEmpty()
                    val liveRunToken = intent.getStringExtra(EXTRA_LIVE_RUN_TOKEN).orEmpty()
                    val startOrigin = intent.getStringExtra(EXTRA_START_ORIGIN)
                        ?: "native_notification"
                    handleStart(
                        startedAtMs, mode, phase, cycle, targetSeconds, subjectId,
                        liveRunId, liveRunToken, startOrigin,
                    )
                }
                ACTION_STOP -> handleStop(
                    recordInterval = true,
                    commandOrigin = "native_notification",
                )
                ACTION_STOP_SILENT -> handleStop(
                    recordInterval = false,
                    commandOrigin = "dart_app",
                )
                ACTION_DISCARD_PROJECTION -> handleDiscardProjection()
                ACTION_END_BREAK -> handleEndBreak()
                ACTION_TOGGLE -> {
                    // WP-135: idle→start; running→stop + 00:00 (writeIdle).
                    if (TimerStateStore.isRunning(prefs())) {
                        handleStop(
                            recordInterval = true,
                            commandOrigin = "native_widget",
                        )
                    } else {
                        // 🔴 WP-645: burasi `mode = "stopwatch"` SABIT yaziyordu.
                        // Pomodoro/geri sayim secmis kullanicinin widget Baslat'i
                        // acik uclu bir kronometre baslatiyor, sonra Dart bu modu
                        // benimseyip kullanicinin SECIMINI diske de yaziyordu.
                        val plan = TimerStateStore.nativeStartPlan(prefs())
                        handleStart(
                            startedAtMs = System.currentTimeMillis(),
                            mode = plan.mode,
                            phase = "work",
                            cycle = 1,
                            targetSeconds = plan.targetSeconds,
                            subjectId = rememberedSubjectId(prefs()),
                            startOrigin = "native_widget",
                        )
                    }
                }
                else -> {
                    // START_NOT_STICKY ile normalde null-intent yeniden başlatma
                    // gelmez; yine de gelirse güvenle kendini kapat. FGS bekleyen
                    // bir başlatma varsa 5 sn kuralını bozmamak için önce kısa bir
                    // foreground'a geç, sonra bırak.
                    safeStopEverything()
                }
            }
        } catch (t: Throwable) {
            // Çökme yerine sessiz toparlanma: FGS'i düşür, servisi kapat.
            runCatching { safeStopEverything() }
        }
        return START_NOT_STICKY
    }

    private fun handleStart(
        startedAtMs: Long,
        mode: String,
        phase: String,
        cycle: Int,
        // WP-645: varsayilani KALDIRILDI. `= null`, hedefi gecirmeyi unutan
        // her cagirani sessizce hedefsiz kosuya dusuruyordu; bu soruyu
        // derleyici sormali, kullanici degil.
        targetSeconds: Int?,
        subjectId: String,
        liveRunId: String = "",
        liveRunToken: String = "",
        startOrigin: String = "dart_app",
    ) {
        // Eski Flutter bildirimi 7001; native panel tek otoritedir.
        notificationManager().cancel(LEGACY_FLUTTER_NOTIFICATION_ID)
        // WP-135: store yazımı senkron commit (beta-v15 idle race koruması).
        TimerStateStore.writeRunning(
            prefs(),
            startedAtMs = startedAtMs,
            mode = mode,
            phase = phase,
            cycle = cycle,
            targetSeconds = targetSeconds,
            subjectId = subjectId,
            liveRunId = liveRunId,
            liveRunToken = liveRunToken,
            startOrigin = startOrigin,
            // WP-431: rol store'da acik tutulur; handleStop kararini buradan verir.
            controllerRole = TimerStateStore.roleForStartOrigin(startOrigin),
        )
        // V1 global coordination yalnız stopwatch work start/stop'u kapsar.
        // Countdown/Pomodoro için global phase komutu üretmeyiz; mevcut local
        // davranış ve legacy verified queue değişmeden kalır.
        // WP-343 remote mirror, doğrulanmış sunucu snapshot'ını yalnız yerel
        // yüzeylere uygular. Onu yeni bir native producer gibi kuyruğa yazmak
        // echo/tekrar start üretirdi; normal local start yolları değişmez.
        if (mode == "stopwatch" && phase == "work" && startOrigin != "global_timer_mirror") {
            TimerStateStore.appendV2Command(prefs(), "start", startOrigin)
        }

        startForegroundCompat(buildRunningNotification(startedAtMs))
        notificationManager().notify(
            NOTIFICATION_ID,
            buildRunningNotification(startedAtMs),
        )
        // 🔴 WP-760 YARIS: olcumu BURADA yapmak ERKENDIR.
        //
        // `NotificationManager.notify()` bildirimi sisteme KUYRUKLAR;
        // `NotificationManagerService` gercek gonderimi kendi handler'inda
        // yapar. `activeNotifications` ise gonderilmis listeyi okur. Yani
        // notify'in hemen ardindan bakinca bildirim cogu zaman HENUZ ORADA
        // DEGILDIR: `postedFlags` null doner, `observedVerdict` "olcum yok"
        // der (dogru olarak -- gorememek red degildir) ve verdict HIC
        // yazilmaz. Sonuc: terfi etmeyen cihaz her Baslat'ta yeniden denenir
        // ve kullanici surekli duz kartta kalir.
        //
        // WP-759 bu cagriyi buraya koymustu ve kimse fark etmedi, cunku o
        // turda `richPanel` her zaman `true` idi: olcum zaten hicbir seyi
        // degistirmiyordu. Kablo takilinca yaris gorunur oldu.
        schedulePromotionProbe(startedAtMs)
        // Deterministik sıra: store → UI yüzeyler → Dart broadcast.
        TimerWidgets.updateAll(this)
        notifyStateChanged()
    }

    /**
     * Molayı bitirip pomodoro'nun **BİR SONRAKİ** çalışma döngüsünü başlatır
     * (bildirimdeki "Çalışmaya dön" düğmesi). Mola aralığı oturum değildir; bu
     * nedenle kuyruk yazılmaz.
     *
     * WP-622: hangi döngüyle/hedefle başlanacağı kararı burada DEĞİL,
     * [TimerStateStore.endBreakPlan] içinde saf olarak verilir — cihazsız JVM
     * testiyle ölçülebilsin diye. Eskiden karar burada gömülüydü ve döngüyü
     * aynen yeniden yazıyordu.
     */
    private fun handleEndBreak() {
        val p = prefs()
        val plan = TimerStateStore.endBreakPlan(p) ?: return
        val liveRunToken = plan.liveRunToken
        val startOrigin = plan.startOrigin
        if (liveRunToken.isNotBlank()) {
            TimerStateStore.appendPendingVerifiedCommand(
                p, "resume", liveRunToken, startOrigin,
            )
        }
        handleStart(
            startedAtMs = System.currentTimeMillis(),
            mode = plan.mode,
            phase = "work",
            cycle = plan.cycle,
            targetSeconds = plan.targetSeconds,
            subjectId = plan.subjectId,
            liveRunId = plan.liveRunId,
            liveRunToken = liveRunToken,
            startOrigin = startOrigin,
        )
    }

    private fun handleStop(
        recordInterval: Boolean,
        commandOrigin: String = "native_notification",
    ) {
        // Bekleyen terfi yoklamasi iptal edilir. Saf karar zaten
        // "durmussa gonderme" der; bu satir isin bosuna kuyrukta
        // beklemesini de onler.
        mainHandler.removeCallbacksAndMessages(PROMOTION_PROBE_TOKEN)
        // ÖNEMLİ: 5 sn içinde startForeground (Android 12+ FGS borcu).
        startForegroundCompat(buildIdleNotification())

        val p = prefs()
        val phase = p.getString(TimerStateStore.KEY_PHASE, "work") ?: "work"
        val mode = p.getString(TimerStateStore.KEY_MODE, "stopwatch") ?: "stopwatch"
        val startOrigin = p.getString(
            TimerStateStore.KEY_START_ORIGIN,
            "native_notification",
        ).orEmpty()

        // WP-431 (V56-S01, ikinci yuz): AYNA cihaz projeksiyondur — asla yerel
        // oturum uretmez. Eskiden bildirim/widget Durdur'u `recordInterval=true`
        // ile geliyordu ve ayna cihazda UYDURMA bir calisma araligi yaziliyordu;
        // Dart onu acilista gercek oturum olarak kaydediyordu.
        val isMirror = TimerStateStore.isMirror(p)

        if (recordInterval && !isMirror) {
            val startedAtMs = TimerStateStore.startedAtMs(p)
            val nowMs = System.currentTimeMillis()
            val liveRunToken = p.getString(TimerStateStore.KEY_LIVE_RUN_TOKEN, "").orEmpty()
            // Yalnız çalışma fazı kaydedilir (mola sayılmaz).
            if (liveRunToken.isNotBlank()) {
                TimerStateStore.appendPendingVerifiedCommand(
                    p, "finalize", liveRunToken, startOrigin,
                )
            } else if (startedAtMs in 1 until nowMs && phase == "work") {
                TimerStateStore.appendPendingInterval(
                    p,
                    startMs = startedAtMs,
                    endMs = nowMs,
                    subject = p.getString(TimerStateStore.KEY_SUBJECT, "") ?: "",
                    origin = startOrigin,
                )
            }
        }

        // WP-373 (KÖK NEDEN 2): V2 senkron zarfı oturum muhasebesinden BAĞIMSIZDIR.
        //
        // 🔴 Eskiden bu blok `recordInterval` koşulunun İÇİNDEYDİ. Uygulama içi
        // Durdur `ACTION_STOP_SILENT` → `handleStop(recordInterval = false)`
        // yolunu kullanır (oturumu Dart yazar, çift kayıt olmasın diye), yani
        // **en sık kullanılan durdurma** hiçbir zaman durdurma sinyali
        // üretmiyordu; diğer cihazda aynalanan sayaç koşmaya devam ediyordu.
        //
        // `recordInterval` "oturumu kim yazacak" sorusunun cevabıdır; "kullanıcı
        // sayacı durdurdu mu" sorusunun değil. İkisi ayrıldı.
        //
        // Ayna cihazında zarf üretilmez: `startOrigin == "global_timer_mirror"`
        // için `canonicalV2Origin` null döner (koşunun sahibi karşı cihazdır).
        // WP-431: AYNA cihazda yerel mod/faz onemsizdir — koşu tanimi geregi
        // global bir stopwatch kosusudur. Eski `mode == "stopwatch"` kosulu,
        // yerel modu countdown olan bir ayna cihazda durdurma komutunu sessizce
        // dusuruyordu (V56-S01'in ucuncu yuzu).
        if (isMirror || (mode == "stopwatch" && phase == "work")) {
            TimerStateStore.appendV2Command(
                p,
                action = "stop",
                startOrigin = commandOrigin,
                runId = p.getString(TimerStateStore.KEY_V2_RUN_ID, null),
                expectedRunRevision = p.getString(TimerStateStore.KEY_V2_RUN_REVISION, null)
                    ?.toLongOrNull(),
            )
        }

        // WP-135: idle + sıfır — senkron commit (apply asimetri kapatıldı).
        TimerStateStore.writeIdle(p)

        exitForegroundRemovingNotification()
        TimerWidgets.updateAll(this)
        notifyStateChanged()
        stopSelf()
    }

    /**
     * WP-431: yalnız YEREL projeksiyonu düşürür — sunucuya hiçbir sey gitmez.
     *
     * Sogumus acilista ayna durumu server dogrulanmadan diriltilmemelidir
     * (V56-S04: sabah gorunen sekiz saatlik hayalet). Ama bu bir DURDURMA
     * degildir: kosunun sahibi baska cihazdir ve orada calismaya devam
     * ediyor olabilir. Bu yuzden `handleStop`tan farkli olarak ne V2 stop
     * zarfi ne de bekleyen aralik yazilir.
     */
    private fun handleDiscardProjection() {
        startForegroundCompat(buildIdleNotification())
        TimerStateStore.writeIdle(prefs())
        exitForegroundRemovingNotification()
        TimerWidgets.updateAll(this)
        notifyStateChanged()
        stopSelf()
    }

    /** Beklenmedik/boş komutta güvenli kapanış: kısa foreground + tam kaldırma. */
    private fun safeStopEverything() {
        // Foreground borcu olabilir; kisa bir bildirimle kapat ve tamamen kaldir.
        runCatching { startForegroundCompat(buildIdleNotification()) }
        exitForegroundRemovingNotification()
        stopSelf()
    }

    /**
     * 🔴 WP-759: HER durdurma yolu bildirimi GOTURUR.
     *
     * Eskiden burasi `detachForegroundKeepNotification` idi ve adi ne yaptigini
     * durustce soyluyordu: `STOP_FOREGROUND_DETACH` foreground bagini koparir,
     * bildirimi BILEREK birakir. `handleStop` bunu cagirdigi icin her
     * Durdur'dan sonra golgede bir "00:00" karti kaliyor ve kendiliginden
     * gitmiyordu.
     *
     * Emulatorde olculdu: taze kurulumda sayac HIC baslatilmadan golgede
     * bildirim YOKTUR (`dumpsys notification` icinde id=7040 sifir kayit).
     * Yani bosta bildirim bir urun gereksinimi degil, FGS borcunun artigiydi.
     * Borc odenir, artik birakilmaz.
     */
    private fun exitForegroundRemovingNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            runCatching { stopForeground(Service.STOP_FOREGROUND_REMOVE) }
        } else {
            @Suppress("DEPRECATION")
            runCatching { stopForeground(true) }
        }
        runCatching { notificationManager().cancel(NOTIFICATION_ID) }
    }

    /**
     * WP-103: Runtime tip, manifest `dataSync|specialUse` alt kümesi olmalı.
     * - API 34+ (UPSIDE_DOWN_CAKE): SPECIAL_USE (Android 15 dataSync 6s cap'ten muaf)
     * - API 29–33: DATA_SYNC (önceki yalnız-specialUse manifest ile uyumsuzdu → çökme)
     * - API ≤28: tip parametresiz
     */
    /**
     * Gecikmeli terfi yoklamasi.
     *
     * Yalniz **hic olculmemis** cihazda kosar; olculmus cihazda tek fazladan
     * is bile yapilmaz. Sonuc RED ise dogru kart hemen yeniden gonderilir,
     * boylece kullanici o oturumu yanlis kartla gecirmez.
     */
    /**
     * Yoklama icin tek handler. Servis komut guduludur ve baska hicbir yerde
     * zamanlayici YOKTUR; bu handler yalniz terfi yoklamasi icin vardir.
     */
    private val mainHandler by lazy { Handler(Looper.getMainLooper()) }

    private fun schedulePromotionProbe(startedAtMs: Long) {
        // 🔴 WP-763: terfi ISTENMEDIYSE olculecek bir sey yoktur. Zengin panel
        // gonderilmisken bayragi aramak, bulamamak ve bunu RED diye yazmak
        // cihaza YANLIS bir karar damgalardi.
        if (useRichPanel(panelOverride(prefs()), mayPromote = true)) return
        if (TimerPromotion.readVerdict(prefs()) != null) return
        mainHandler.removeCallbacksAndMessages(PROMOTION_PROBE_TOKEN)
        HandlerCompat.postDelayed(
            mainHandler,
            { runPromotionProbe(startedAtMs) },
            PROMOTION_PROBE_TOKEN,
            PROMOTION_PROBE_DELAY_MS,
        )
    }

    /**
     * Sonucsuz denemeyi sayar; esik asilirsa RED yazip doner, aksi halde `null`.
     */
    private fun giveUpProbingIfExhausted(
        p: SharedPreferences,
    ): TimerPromotion.Verdict? {
        val attempts = TimerPromotion.recordUnobservedAttempt(p)
        if (!TimerPromotion.shouldGiveUpProbing(attempts)) return null
        TimerPromotion.writeVerdict(p, TimerPromotion.Verdict.DENIED)
        return TimerPromotion.Verdict.DENIED
    }

    private fun runPromotionProbe(startedAtMs: Long) {
        val p = prefs()
        // 🔴 Sonucsuz yoklama SESSIZCE surunmemeli. `observedVerdict` bildirimi
        // goremezse dogru olarak "olcum yok" der; ama bu her Baslat'ta
        // tekrarlanirsa cihaz SUREKLI terfi edilebilir (duz) kartta kalir ve
        // sahibin v43'te kabul ettigi zengin panel bir daha hic gorunmez.
        // Uc sonucsuz denemeden sonra RED yazilir; yapi damgasi degisince
        // (sistem guncellemesi) sayac sifirlanir, yani kalici tavan olmaz.
        val verdict =
            TimerPromotion.recordOutcome(p, notificationManager(), NOTIFICATION_ID)
                ?: giveUpProbingIfExhausted(p)
        if (!shouldRepostAfterProbe(
                verdict = verdict,
                isRunning = TimerStateStore.isRunning(p),
                probedStartedAtMs = startedAtMs,
                currentStartedAtMs = TimerStateStore.startedAtMs(p),
            )
        ) {
            return
        }
        runCatching {
            notificationManager().notify(
                NOTIFICATION_ID,
                buildRunningNotification(startedAtMs),
            )
        }
    }

    private fun startForegroundCompat(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // dataSync Android 15'te toplam 6 saat ile sınırlı. Kullanıcı açıkça
            // başlatmış görünür sayaç, manifestte beyan edilen specialUse türüyle
            // çalışır; bu tür için runtime önkoşulu yoktur.
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    /**
     * WP-753: varsayılan yol artık **Android Live Update sözleşmesi**dir —
     * özel görünüm yok, dolu `contentTitle`, standart/`ProgressStyle` stil,
     * `setRequestPromotedOngoing(true)`. Terfi eden bildirim durum çubuğunda
     * çip, kilit ekranında ve (Samsung'da) Now Bar'da çizilir.
     *
     * v43 zengin özel panel yalnız `timer_panel_expanded=true` yazılmışsa
     * koşar ve terfi **istemez** (özel görünüm ile terfi birbirini dışlar).
     */
    private fun buildRunningNotification(startedAtMs: Long): Notification {
        ensureChannel()
        val p = prefs()
        val isBreak = p.getString(TimerStateStore.KEY_PHASE, "work") == "rest"
        val plan = runningTimerNotificationPlan(
            // 🔴 WP-759 dikisi: zengin panel yalniz kullanici istedigi icin degil,
            // sistem terfiyi VERMEDIGI icin de secilir. Olculdu (odak_api36,
            // Android 16): API yarisi acik, cizen arayuz imajda yok -- uygulama
            // terfi istiyor, sistem FLAG_PROMOTED_ONGOING yazmiyor ve kullanici
            // dugmesiz gri bir satirda kaliyordu. Sahibin S23'te gordugu buydu.
            richPanel = useRichPanel(
                override = panelOverride(p),
                mayPromote = TimerPromotion.mayRequestPromotion(
                    TimerPromotion.currentVerdict(p, notificationManager()),
                ),
            ),
            isBreak = isBreak,
            targetSeconds = TimerStateStore
                .readIntCompat(p, TimerStateStore.KEY_TARGET_SECONDS, 0)
                .takeIf { it > 0 },
            startedAtMs = startedAtMs,
            nowMs = System.currentTimeMillis(),
        )
        val builder = baseBuilder()
            .setOngoing(true)
            .setContentIntent(openAppPending())
            .setCategory(NotificationCompat.CATEGORY_STOPWATCH)
        if (plan.usesCustomView) {
            val custom = buildRunningRemoteViews(startedAtMs, isBreak, plan)
            builder
                // 🔴 WP-759 kusur 3: burasi `""` yaziyordu. Panel kendi metnini
                // cizdigi icin gorunurde fark etmiyordu, ama bildirim gecmisi,
                // TalkBack ve NotificationListener yuzeylerinde sayac ISIMSIZ
                // kaliyordu. Baslik/govde artik planla birlikte gelir.
                .setContentTitle(getString(plan.titleRes))
                .setContentText(getString(plan.bodyRes))
                .setUsesChronometer(false)
                .setShowWhen(false)
                .setStyle(NotificationCompat.DecoratedCustomViewStyle())
                .setCustomContentView(custom)
                .setCustomBigContentView(custom)
            return builder.build()
        }
        builder
            .setContentTitle(getString(plan.titleRes))
            .setContentText(getString(plan.bodyRes))
            .setUsesChronometer(true)
            .setWhen(plan.whenMs)
            .setShowWhen(true)
            .setChronometerCountDown(plan.countDown)
            .setRequestPromotedOngoing(plan.requestPromotedOngoing)
            // 🔴 WP-759 kusur 5: ikon `0` idi. Bildirim golgesi Android 7'den
            // beri eylem ikonunu ZATEN cizmez, ama Wear/Auto, eski surumler ve
            // terfi cipi icin ikon eylemin TEK gorsel karsiligidir.
            .addAction(
                if (isBreak) R.drawable.ic_notif_action_start
                else R.drawable.ic_notif_action_stop,
                if (isBreak) getString(R.string.action_return_to_work)
                else getString(R.string.action_stop),
                if (isBreak) endBreakActionPending() else stopActionPending(),
            )
        if (plan.shortCriticalTextRes != 0) {
            builder.setShortCriticalText(getString(plan.shortCriticalTextRes))
        }
        // 🔴 WP-762: terfi edilebilir HER iki dal da `ProgressStyle` tasir.
        // Eskiden yalniz hedefi olan mod tasiyordu; acik uclu kronometre
        // standart stille terfi istiyordu ve sistem bayragi yazsa bile cizecek
        // bir Live Update ogesi bulamiyordu.
        when (plan.style) {
            TimerNotificationStyle.PROGRESS -> builder.setStyle(
                NotificationCompat.ProgressStyle()
                    .addProgressSegment(
                        NotificationCompat.ProgressStyle.Segment(plan.totalSeconds),
                    )
                    .setProgress(plan.progressSeconds),
            )
            // 🔴 WP-763 GERI ALMA. WP-762 buraya
            // `ProgressStyle().setProgressIndeterminate(true)` koymustu ve o
            // karar CIHAZDA DOGRULANMADAN yayina cikti (v74). Sahip aninda
            // olctu: bildirimde soldan saga suzulen belirsiz cubuk belirdi,
            // sayac 00:00'a dustu ve dugme kayboldu -- yani calisan bildirim
            // BOZULDU, ustelik cip yine cikmadi.
            //
            // Ayni hatanin ucuncu tekrariydi (WP-753, WP-762, ve bu):
            // "muhtemelen boyle olmali" diyip cihazsiz yayina cikarmak.
            // Hipotez bir sonraki turda cihazda olculur; varsayilan yol
            // hipoteze baglanmaz.
            TimerNotificationStyle.STANDARD -> Unit
            TimerNotificationStyle.CUSTOM_PANEL -> Unit
        }
        return builder.build()
    }

    /**
     * Bosta kart: **standart** bildirim, gercek metin, IKONLU sistem eylemi.
     *
     * 🔴 WP-759 oncesi iki dal vardi ve IKISI DE ayni sonucu veriyordu:
     *  - ozel panel dali kartin tek metnine "00:00" yaziyordu;
     *  - standart dalda `contentTitle` YINE "00:00", eylem ise `addAction(0, ...)`
     *    yani ikonsuzdu.
     * Golgede gorunen sey her iki halde de sifirlanmis bir saat ve dokunulacak
     * hicbir sey oluyordu. Artik tek dal var: karar [idleTimerNotificationPlan]
     * icinde saf durur, valf (`KEY_PANEL_EXPANDED`) yalniz KOSAN bildirimi
     * yonetir. Bosta kart kisa omurludur (yalniz FGS borcunu oder, hemen
     * kaldirilir) -- ozel gorunum tasimasinin bedeli var, faydasi yok.
     */
    private fun buildIdleNotification(): Notification {
        ensureChannel()
        val plan = idleTimerNotificationPlan()
        return baseBuilder()
            .setOngoing(false)
            .setContentIntent(openAppPending())
            .setCategory(NotificationCompat.CATEGORY_STOPWATCH)
            .setUsesChronometer(false)
            .setShowWhen(false)
            .setContentTitle(getString(plan.titleRes))
            .setContentText(getString(plan.bodyRes))
            .addAction(
                plan.actionIconRes,
                getString(plan.actionLabelRes),
                startActionPending(),
            )
            .build()
    }

    /**
     * Zengin panelin `RemoteViews`i.
     *
     * 🔴 WP-759: HER alan HER cagrida yazilir. SystemUI ayni sisirilmis
     * gorunumu yeniden kullanir; yazilmayan alan ONCEKI degeriyle kalir. Bir
     * geri sayimdan sonra yazilmayan `countDown` bayragi, acik uclu kronometreyi
     * de geri saydirirdi.
     */
    private fun buildRunningRemoteViews(
        startedAtMs: Long,
        isBreak: Boolean,
        plan: TimerNotificationPlan,
    ): RemoteViews {
        val views = RemoteViews(packageName, R.layout.timer_notification)
        // Sira onemli: bayrak once, taban sonra. `setBase` metni yeniden cizer.
        views.setChronometerCountDown(R.id.notif_timer_elapsed, plan.countDown)
        views.setChronometer(
            R.id.notif_timer_elapsed,
            panelChronometerBaseMs(
                plan = plan,
                startedAtMs = startedAtMs,
                nowMs = System.currentTimeMillis(),
                nowElapsedMs = SystemClock.elapsedRealtime(),
            ),
            null,
            true,
        )
        // 🔴 WP-761 (sahip, cihazda): "buradaki FOCUS yazisi ne alaka".
        // Hakliydi. Etiket, mola ile odagi ayirt etsin diye eklenmisti ama
        // ODAKTA hicbir sey soylemiyordu: panel zaten yalniz calisirken
        // vardir, "FOCUS" yazmak tekrardi ve 26sp sayacin yanina gurultu
        // koyuyordu. Isaret, durum ISTISNA oldugunda hak eder: mola.
        // Ayirt etme kaybolmaz -- molada etiket yazar, odakta bosluk kalir ve
        // dugme etiketi de zaten farklidir.
        views.setTextViewText(
            R.id.notif_timer_label,
            panelPhaseLabelRes(isBreak, plan.shortCriticalTextRes)
                .takeIf { it != 0 }
                ?.let { getString(it) }
                .orEmpty(),
        )
        views.setTextViewText(
            R.id.notif_timer_action,
            if (isBreak) getString(R.string.action_return_to_work)
            else getString(R.string.action_stop),
        )
        // 🔴 WP-761 (sahip, cihazda): "butondaki kare isaret ne alaka".
        // Hap simgesi kaldirildi. Dolu kare, 15sp kalin "Durdur" yazisinin
        // yaninda bir DURDURMA simgesi olarak degil, rastgele bir leke olarak
        // okunuyordu -- taninmayan bir simge simge degildir. Anlami etiketin
        // kendisi tasiyor; hap dolu zemin + net etiketle zaten dugme gibi
        // duruyor (dokunma hedefi 44dp korunur).
        views.setOnClickPendingIntent(
            R.id.notif_timer_action,
            if (isBreak) endBreakActionPending() else stopActionPending(),
        )
        return views
    }

    private fun baseBuilder(): NotificationCompat.Builder =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(TIMER_NOTIFICATION_SMALL_ICON)
            .setContentText("")
            .setOnlyAlertOnce(true)
            .setSound(null)
            .setVibrate(null)
            .setCategory(NotificationCompat.CATEGORY_STOPWATCH)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)

    private fun stopActionPending(): PendingIntent = actionPending(ACTION_STOP, 1)

    private fun startActionPending(): PendingIntent = actionPending(ACTION_START, 2)

    private fun endBreakActionPending(): PendingIntent = actionPending(ACTION_END_BREAK, 4)

    /** Bildirim aksiyonu: uygulama kapalıyken de FGS başlatabilmek için
     *  `getForegroundService` (API 26+) — düz `getService` arka plan yasağına
     *  takılıp çökertiyordu. */
    private fun actionPending(action: String, requestCode: Int): PendingIntent {
        val intent = Intent(this, StudyTimerService::class.java).apply {
            this.action = action
            if (action == ACTION_START) putExtra(EXTRA_START_ORIGIN, "native_notification")
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            PendingIntent.getForegroundService(this, requestCode, intent, flags)
        } else {
            PendingIntent.getService(this, requestCode, intent, flags)
        }
    }

    private fun openAppPending(): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getActivity(this, 0, intent, flags)
    }

    /** Uygulama önplandaysa Dart'ın hemen uzlaşması için (yalnız kendi paketimize)
     *  yayın gönder. MainActivity çalışırken bir runtime receiver bunu dinler. */
    private fun notifyStateChanged() {
        sendBroadcast(
            Intent(BROADCAST_STATE_CHANGED).setPackage(packageName),
        )
    }

    /**
     * WP-558: kanal her serviste KOŞULSUZ yeniden yaratılır.
     *
     * `createNotificationChannel` var olan bir kanalın **adını ve
     * açıklamasını günceller** (importance ve kullanıcının kendi ayarları
     * korunur). Eski erken `return` yüzünden kanal adı ilk kurulumdaki dile
     * çakılıyor, kullanıcı dili değiştirince "Sayaç" başlığı eski dilde
     * kalıyordu. Dart tarafı (`app_push_notification_service.dart`) ve
     * `AlarmNotificationFallback.ensureChannel` zaten koşulsuz çağırır;
     * asimetri tek nokta buydu.
     */
    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.timer_channel_name),
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = getString(R.string.timer_channel_desc)
            setSound(null, null)
            enableVibration(false)
            setShowBadge(false)
        }
        notificationManager().createNotificationChannel(channel)
    }

    private fun notificationManager(): NotificationManager =
        getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun prefs(): SharedPreferences = TimerStateStore.prefs(this)

    companion object {
        const val ACTION_START = "com.manilmax.online_study_room.timer.START"
        const val ACTION_STOP = "com.manilmax.online_study_room.timer.STOP"
        const val ACTION_STOP_SILENT = "com.manilmax.online_study_room.timer.STOP_SILENT"
        const val ACTION_TOGGLE = "com.manilmax.online_study_room.timer.TOGGLE"
        const val ACTION_DISCARD_PROJECTION =
            "com.manilmax.online_study_room.timer.DISCARD_PROJECTION"
        const val ACTION_END_BREAK = "com.manilmax.online_study_room.timer.END_BREAK"

        const val EXTRA_STARTED_AT_MS = "startedAtMs"
        const val EXTRA_MODE = "mode"
        const val EXTRA_PHASE = "phase"
        const val EXTRA_CYCLE = "cycle"
        const val EXTRA_TARGET_SECONDS = "targetSeconds"
        const val EXTRA_SUBJECT_ID = "subjectId"
        const val EXTRA_LIVE_RUN_ID = "liveRunId"
        const val EXTRA_LIVE_RUN_TOKEN = "liveRunToken"
        const val EXTRA_START_ORIGIN = "startOrigin"

        const val BROADCAST_STATE_CHANGED = "com.manilmax.online_study_room.timer.STATE_CHANGED"

        private const val CHANNEL_ID = "study_timer_live_fg"
        /** Gecikmeli yoklamayi iptal edilebilir kilan isaret. */
        private val PROMOTION_PROBE_TOKEN = Any()

        private const val NOTIFICATION_ID = 7040
        private const val LEGACY_FLUTTER_NOTIFICATION_ID = 7001

        /** Servisi belirli bir komutla ayağa kaldırır (receiver/notification/Dart). */
        fun sendCommand(
            context: Context,
            action: String,
            startedAtMs: Long? = null,
            mode: String? = null,
            phase: String? = null,
            cycle: Int? = null,
            targetSeconds: Int? = null,
            subjectId: String? = null,
            liveRunId: String? = null,
            liveRunToken: String? = null,
            startOrigin: String? = null,
        ) {
            val intent = Intent(context, StudyTimerService::class.java).apply {
                this.action = action
                startedAtMs?.let { putExtra(EXTRA_STARTED_AT_MS, it) }
                mode?.let { putExtra(EXTRA_MODE, it) }
                phase?.let { putExtra(EXTRA_PHASE, it) }
                cycle?.let { putExtra(EXTRA_CYCLE, it) }
                targetSeconds?.takeIf { it > 0 }?.let { putExtra(EXTRA_TARGET_SECONDS, it) }
                subjectId?.let { putExtra(EXTRA_SUBJECT_ID, it) }
                liveRunId?.let { putExtra(EXTRA_LIVE_RUN_ID, it) }
                liveRunToken?.let { putExtra(EXTRA_LIVE_RUN_TOKEN, it) }
                startOrigin?.let { putExtra(EXTRA_START_ORIGIN, it) }
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }
}
