package com.manilmax.online_study_room

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import com.manilmax.online_study_room.timer.StudyTimerService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.manilmax.online_study_room/device_integrations"
    private val TIMER_CHANNEL = "com.manilmax.online_study_room/timer"
    private var initialAction: String? = null
    private var timerChannel: MethodChannel? = null

    /** WP-136: Native servis durum değişince Dart'a reconcile.
     *  Eskiden yalnız onResume…onPause dinleniyordu → arka planda bayat UI.
     *  Engine ayaktayken (Activity yok edilene kadar) dinlenir. */
    private val timerStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            timerChannel?.invokeMethod("reconcile", null)
        }
    }
    private var timerStateReceiverRegistered = false

    override fun onCreate(savedInstanceState: Bundle?) {
        initialAction = intent.action
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getInitialAction") {
                result.success(initialAction)
                initialAction = null
            } else {
                result.notImplemented()
            }
        }

        timerChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TIMER_CHANNEL).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "startTimer" -> {
                        val startedAtMs = (call.argument<Number>("startedAtMs"))?.toLong()
                            ?: System.currentTimeMillis()
                        val mode = call.argument<String>("mode") ?: "stopwatch"
                        val phase = call.argument<String>("phase") ?: "work"
                        val cycle = (call.argument<Number>("cycle"))?.toInt() ?: 1
                        val subjectId = call.argument<String>("subjectId")
                        StudyTimerService.sendCommand(
                            this,
                            StudyTimerService.ACTION_START,
                            startedAtMs = startedAtMs,
                            mode = mode,
                            phase = phase,
                            cycle = cycle,
                            subjectId = subjectId,
                        )
                        result.success(null)
                    }
                    // Uygulama içi Durdur: native yalnız bildirimi kaldırır; oturum
                    // kaydını Dart yapar (çift kayıt olmasın) → STOP_SILENT.
                    "stopTimer" -> {
                        StudyTimerService.sendCommand(this, StudyTimerService.ACTION_STOP_SILENT)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // WP-58: Exact alarm izin kanalı
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ExactAlarmHelper.CHANNEL)
            .setMethodCallHandler { call, result ->
                ExactAlarmHelper.handle(this, call, result)
            }

        registerTimerStateReceiver()
    }

    override fun onResume() {
        super.onResume()
        // Cold/warm resume: broadcast kaçmış olabilir → store'dan türet.
        timerChannel?.invokeMethod("reconcile", null)
    }

    override fun onDestroy() {
        unregisterTimerStateReceiver()
        super.onDestroy()
    }

    private fun registerTimerStateReceiver() {
        if (timerStateReceiverRegistered) return
        val filter = IntentFilter(StudyTimerService.BROADCAST_STATE_CHANGED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(timerStateReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(timerStateReceiver, filter)
        }
        timerStateReceiverRegistered = true
    }

    private fun unregisterTimerStateReceiver() {
        if (!timerStateReceiverRegistered) return
        runCatching { unregisterReceiver(timerStateReceiver) }
        timerStateReceiverRegistered = false
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        intent.action?.let { action ->
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, CHANNEL).invokeMethod("onIntentAction", action)
            }
        }
    }
}
