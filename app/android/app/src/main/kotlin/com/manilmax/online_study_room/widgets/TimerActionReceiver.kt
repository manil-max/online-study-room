package com.manilmax.online_study_room.widgets

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import org.json.JSONObject

/**
 * Widget veya bildirim üzerinden gelen zamanlayıcı (sayaç) başlatma/durdurma
 * eylemlerini yakalayan BroadcastReceiver.
 *
 * Flutter UI'ını açmadan ortak state store'a sıralı komut yazar.
 */
class TimerActionReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_TOGGLE_TIMER = "com.manilmax.online_study_room.ACTION_TOGGLE_TIMER"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_TOGGLE_TIMER) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val active = prefs.contains("flutter.timer_active_started_at")
            val raw = prefs.getString("flutter.timer_external_command", null)
            val sequence = try { JSONObject(raw ?: "{}").optInt("sequence", 0) + 1 } catch (_: Exception) { 1 }
            val command = if (active) "stop" else "start"
            prefs.edit().putString(
                "flutter.timer_external_command",
                JSONObject().put("command", command).put("sequence", sequence).toString(),
            ).apply()
        }
    }
}
