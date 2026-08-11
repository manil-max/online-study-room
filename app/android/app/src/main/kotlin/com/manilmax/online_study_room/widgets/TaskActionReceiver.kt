package com.manilmax.online_study_room.widgets

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import java.util.UUID

/**
 * WP-701: gorev widget'indaki kutucuk dokunusunu yakalar.
 *
 * Flutter surecine HIC ihtiyac duymaz — kullanicinin dokundugu an uygulama
 * cogu zaman kapalidir. Yaptigi is uc adimdir ve hepsi tek `apply()` ile
 * ayni dosyaya duser:
 *
 *  1. Aynadaki gorevi ters cevirir (iyimser gorunum),
 *  2. Bekleyen kuyruga **istenen mutlak durumu** yazar (`done: true/false`),
 *  3. Widget'i hemen yeniden cizdirir.
 *
 * Gercek `toggle` uygulama acilinca Dart tarafinda kosar
 * (`android_widget_service.dart` -> `drainTaskWidgetToggles`). Kuyruk toggle
 * degil mutlak durum tasidigi icin ayni kayit iki kez islense de sonuc
 * degismez.
 *
 * `exported=false` (WP-118 deseni): yalniz bu uygulamanin kendi explicit +
 * IMMUTABLE `PendingIntent`i tetikler.
 */
class TaskActionReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_TOGGLE_TASK = "com.manilmax.online_study_room.ACTION_TOGGLE_TASK"
        const val EXTRA_TASK_ID = "task_id"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_TOGGLE_TASK) return
        val taskId = intent.getStringExtra(EXTRA_TASK_ID)?.trim().orEmpty()
        if (taskId.isEmpty()) return

        // Govde bastan sona runCatching: bozuk bir kayit widget'i sessiz
        // birakir, uygulamayi OLDURMEZ (receiver icindeki istisna sureci
        // dusurur).
        val applied = runCatching {
            val prefs = context.getSharedPreferences(
                TASK_PREFS_NAME,
                Context.MODE_PRIVATE,
            )
            val result = toggleTaskInMirror(readTaskMirrorJson(prefs), taskId)
                ?: return@runCatching false
            val pending = appendPendingTaskToggle(
                rawPending = readTaskPendingJson(prefs),
                taskId = taskId,
                done = result.done,
                opId = UUID.randomUUID().toString(),
                atMs = System.currentTimeMillis(),
            )
            prefs.edit()
                .putString(TASK_MIRROR_PREFS_KEY, result.mirrorJson)
                .putString(TASK_PENDING_PREFS_KEY, pending)
                .apply()
            true
        }.getOrDefault(false)

        if (applied) requestTaskWidgetRedraw(context)
    }
}
