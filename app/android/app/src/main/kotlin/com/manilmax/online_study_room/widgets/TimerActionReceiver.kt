package com.manilmax.online_study_room.widgets

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.manilmax.online_study_room.timer.StudyTimerService

/**
 * Widget'taki tek Başlat/Durdur düğmesinden gelen dokunmayı yakalar ve **native**
 * foreground servisine iletir. Servis, sayaç çalışıyorsa durdurur (idle'a geçer),
 * duruyorsa başlatır — hepsi uygulama tamamen kapalıyken de çalışır (dead-switch
 * sorunu giderilir). Oturum kaydı Dart tarafında (app açılışında) yapılır.
 */
class TimerActionReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_TOGGLE_TIMER = "com.manilmax.online_study_room.ACTION_TOGGLE_TIMER"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_TOGGLE_TIMER) {
            StudyTimerService.sendCommand(context, StudyTimerService.ACTION_TOGGLE)
        }
    }
}
