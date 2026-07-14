package com.manilmax.online_study_room.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.WindowManager
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.activity.ComponentActivity
import com.manilmax.online_study_room.R
import kotlin.math.min
import kotlin.random.Random

/**
 * Kilit ekranı üstü alarm yüzeyi + USAGE_ALARM MediaPlayer crescendo.
 *
 * Flutter'a bağımlı değil — process death sonrası da çalabilir.
 */
class AlarmRingActivity : ComponentActivity() {
    private var player: MediaPlayer? = null
    private var streamMax = 7
    private var streamStartVol = 1
    private val handler = Handler(Looper.getMainLooper())
    private var startedAt = 0L
    private var crescendo = true
    private var vibrate = true
    private var antiSnooze = false
    private var snoozeMin = 5
    private var kind = AlarmIds.KIND_ALARM
    private var alarmId = ""
    private var label = ""
    private var hour = 0
    private var minute = 0
    private var mathA = 0
    private var mathB = 0
    private var answerField: EditText? = null
    private var levelBar: ProgressBar? = null

    private val stopReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == AlarmIds.ACTION_STOP_SOUND) {
                stopAll()
                finish()
            }
        }
    }

    private val tick = object : Runnable {
        override fun run() {
            val elapsed = System.currentTimeMillis() - startedAt
            val level = if (crescendo) {
                min(1.0, elapsed / 30_000.0)
            } else {
                1.0
            }
            applyVolume(level)
            levelBar?.progress = (level * 100).toInt()
            if (vibrate && elapsed % 1000 < 200) {
                pulseVibrate()
            }
            if (!isFinishing) {
                handler.postDelayed(this, 200)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        showOnLockScreen()
        readExtras(intent)
        buildUi()
        startSound()
        startedAt = System.currentTimeMillis()
        handler.post(tick)

        val filter = IntentFilter(AlarmIds.ACTION_STOP_SOUND)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(stopReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(stopReceiver, filter)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        readExtras(intent)
    }

    override fun onDestroy() {
        handler.removeCallbacks(tick)
        runCatching { unregisterReceiver(stopReceiver) }
        stopAll()
        super.onDestroy()
    }

    private fun readExtras(i: Intent?) {
        kind = i?.getStringExtra(AlarmIds.EXTRA_KIND) ?: AlarmIds.KIND_ALARM
        alarmId = i?.getStringExtra(AlarmIds.EXTRA_ID) ?: ""
        label = i?.getStringExtra(AlarmIds.EXTRA_LABEL)
            ?: getString(R.string.alarm_default_label)
        hour = i?.getIntExtra(AlarmIds.EXTRA_HOUR, 0) ?: 0
        minute = i?.getIntExtra(AlarmIds.EXTRA_MINUTE, 0) ?: 0
        crescendo = i?.getBooleanExtra(AlarmIds.EXTRA_CRESCENDO, true) ?: true
        vibrate = i?.getBooleanExtra(AlarmIds.EXTRA_VIBRATE, true) ?: true
        antiSnooze = i?.getBooleanExtra(AlarmIds.EXTRA_ANTI_SNOOZE, false) ?: false
        snoozeMin = i?.getIntExtra(AlarmIds.EXTRA_SNOOZE_MIN, 5) ?: 5
        mathA = 10 + Random.nextInt(40)
        mathB = 10 + Random.nextInt(40)
    }

    private fun showOnLockScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        @Suppress("DEPRECATION")
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
        )
    }

    private fun buildUi() {
        val pad = (24 * resources.displayMetrics.density).toInt()
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(0xFF000000.toInt())
            setPadding(pad, pad * 2, pad, pad)
        }

        val timeText = TextView(this).apply {
            text = if (kind == AlarmIds.KIND_TIMER) {
                "00:00"
            } else {
                String.format("%02d:%02d", hour, minute)
            }
            textSize = 64f
            setTextColor(0xFFEF4444.toInt())
            textAlignment = TextView.TEXT_ALIGNMENT_CENTER
        }
        val labelText = TextView(this).apply {
            text = if (kind == AlarmIds.KIND_TIMER) {
                getString(R.string.timer_label_format, label)
            } else {
                label
            }
            textSize = 20f
            setTextColor(0xB3FFFFFF.toInt())
            textAlignment = TextView.TEXT_ALIGNMENT_CENTER
            setPadding(0, pad, 0, pad)
        }
        levelBar = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = 100
            progress = 0
        }

        root.addView(timeText)
        root.addView(labelText)
        root.addView(levelBar)

        if (antiSnooze && kind == AlarmIds.KIND_ALARM) {
            val math = TextView(this).apply {
                text = getString(R.string.anti_snooze_prompt, mathA, mathB)
                textSize = 18f
                setTextColor(0xFFFFFFFF.toInt())
                setPadding(0, pad, 0, pad / 2)
            }
            answerField = EditText(this).apply {
                inputType = android.text.InputType.TYPE_CLASS_NUMBER
                setTextColor(0xFFFFFFFF.toInt())
                setHintTextColor(0x66FFFFFF.toInt())
                hint = getString(R.string.anti_snooze_hint)
            }
            root.addView(math)
            root.addView(answerField)
        }

        val buttons = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, pad, 0, 0)
        }
        val snoozeBtn = Button(this).apply {
            text = getString(R.string.snooze_minutes_format, snoozeMin)
            isEnabled = kind == AlarmIds.KIND_ALARM && !antiSnooze
            setOnClickListener { doSnooze() }
        }
        val dismissBtn = Button(this).apply {
            text = getString(R.string.action_dismiss)
            setOnClickListener { tryDismiss() }
        }
        val lp = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        buttons.addView(snoozeBtn, lp)
        buttons.addView(dismissBtn, lp)
        root.addView(buttons)

        setContentView(root)
    }

    private fun startSound() {
        val am = getSystemService(AUDIO_SERVICE) as AudioManager
        streamMax = am.getStreamMaxVolume(AudioManager.STREAM_ALARM).coerceAtLeast(1)
        streamStartVol = am.getStreamVolume(AudioManager.STREAM_ALARM)
        // Crescendo: düşükten başla
        val startVol = if (crescendo) 1 else streamMax
        am.setStreamVolume(AudioManager.STREAM_ALARM, startVol, 0)

        val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

        player = MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            isLooping = true
            try {
                setDataSource(this@AlarmRingActivity, uri)
                prepare()
                // MediaPlayer volume 0..1 relative
                val rel = if (crescendo) 0.05f else 1f
                setVolume(rel, rel)
                start()
            } catch (_: Exception) {
                // URI başarısız — sessiz kal, titreşim devam
            }
        }
    }

    private fun applyVolume(level: Double) {
        val am = getSystemService(AUDIO_SERVICE) as AudioManager
        val vol = if (crescendo) {
            (1 + (streamMax - 1) * level).toInt().coerceIn(1, streamMax)
        } else {
            streamMax
        }
        am.setStreamVolume(AudioManager.STREAM_ALARM, vol, 0)
        val rel = level.toFloat().coerceIn(0.05f, 1f)
        runCatching { player?.setVolume(rel, rel) }
    }

    private fun pulseVibrate() {
        val v = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vm = getSystemService(VibratorManager::class.java)
            vm?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(VIBRATOR_SERVICE) as? Vibrator
        } ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            v.vibrate(VibrationEffect.createOneShot(80, VibrationEffect.DEFAULT_AMPLITUDE))
        } else {
            @Suppress("DEPRECATION")
            v.vibrate(80)
        }
    }

    private fun tryDismiss() {
        if (antiSnooze && kind == AlarmIds.KIND_ALARM) {
            val ans = answerField?.text?.toString()?.trim()?.toIntOrNull()
            if (ans != mathA + mathB) {
                Toast.makeText(this, getString(R.string.toast_wrong_answer), Toast.LENGTH_SHORT)
                    .show()
                pulseVibrate()
                return
            }
        }
        NativeAlarmScheduler.cancel(this, kind, alarmId)
        AlarmNotificationFallback.cancel(this, kind, alarmId)
        // Tek seferlik / timer: mirror güncellemesi Dart tarafında boot reconcile ile
        stopAll()
        finish()
    }

    private fun doSnooze() {
        if (antiSnooze) {
            Toast.makeText(this, getString(R.string.toast_solve_to_snooze), Toast.LENGTH_SHORT)
                .show()
            return
        }
        val trigger = System.currentTimeMillis() + snoozeMin * 60_000L
        NativeAlarmScheduler.scheduleAlarm(
            this,
            id = alarmId,
            triggerAtMs = trigger,
            label = label,
            hour = hour,
            minute = minute,
            crescendo = crescendo,
            vibrate = vibrate,
            antiSnooze = antiSnooze,
            snoozeMin = snoozeMin,
        )
        AlarmNotificationFallback.cancel(this, kind, alarmId)
        stopAll()
        finish()
    }

    private fun stopAll() {
        handler.removeCallbacks(tick)
        runCatching {
            player?.stop()
            player?.release()
        }
        player = null
        // Orijinal alarm ses seviyesine dön (kullanıcı ayarını bozma)
        runCatching {
            val am = getSystemService(AUDIO_SERVICE) as AudioManager
            am.setStreamVolume(AudioManager.STREAM_ALARM, streamStartVol, 0)
        }
    }
}
