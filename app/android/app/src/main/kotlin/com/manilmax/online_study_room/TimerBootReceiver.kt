package com.manilmax.online_study_room

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.manilmax.online_study_room.widgets.TimerWidgets

/**
 * Boot / paket guncellemesi sonrasi sayac widget'ini yeniden cizer.
 *
 * WP-558 (neden gerekli): 1x1 sayac widget'i sureyi bir `Chronometer` ile
 * gosterir ve `Chronometer.base` **`SystemClock.elapsedRealtime()`e goredir**
 * (`StudyWidgetProviders.timerChronometerProjection`). Reboot'ta
 * `elapsedRealtime` sifirlanir; launcher'in sakladigi eski `base` degeri
 * anlamsizlasir ve widget yanlis sure gosterir. Boot'ta widget'i tazeleyen
 * baska hicbir kod yok -- `updatePeriodMillis` de 0'a cekildigi icin sistem
 * periyodik `onUpdate` gondermez. Tazeleme bu receiver'in isidir.
 *
 * WP-558 (kaldirilan): eski govde yalnizca olu bir "restore bekliyor"
 * prefs bayragi yaziyordu. Dart o anahtari HICBIR yerde okumuyordu (repo
 * genelinde tek eslesme bu dosyaydi), yani receiverin var olus
 * gerekcesi yalandi.
 *
 * Not: Android 15'te BOOT_COMPLETED icinden dataSync foreground service
 * baslatmak yasaktir; burada servis baslatilmaz, yalnizca widget yayini
 * gonderilir. Sayac durumu zaten `TimerStateStore` prefs'inde durur ve
 * `TimerWidgetProvider.onUpdate` onu yeniden projekte eder.
 */
class TimerBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        TimerWidgets.updateAll(context)
    }
}
