package com.manilmax.online_study_room

import android.app.LocaleManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.LocaleList
import android.provider.Settings
import androidx.annotation.RequiresApi
import com.manilmax.online_study_room.overlay.TimerOverlay
import com.manilmax.online_study_room.timer.StudyTimerService
import com.manilmax.online_study_room.widgets.WidgetDeepLink
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.manilmax.online_study_room/device_integrations"
    private val TIMER_CHANNEL = "com.manilmax.online_study_room/timer"
    private var initialAction: String? = null
    private var timerChannel: MethodChannel? = null

    /**
     * WP-700 SOGUK YOL. Kullanici widget'a dokundugunda uygulama cogu zaman
     * KAPALIDIR; o durumda `onNewIntent` HIC cagrilmaz ve rota kaybolur.
     * Rota bu yuzden `onCreate`te yakalanip Dart ilk kez sorana kadar burada
     * bekletilir. Yalniz sicak yolu kurmak, ozelligi calisiyor gosterip
     * pratikte yari olu birakirdi.
     */
    private var initialWidgetRoute: String? = null
    private var widgetRouteChannel: MethodChannel? = null

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
        initialWidgetRoute = WidgetDeepLink.routeOf(
            intent.action,
            intent.getStringExtra(WidgetDeepLink.EXTRA_ROUTE),
        )
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialAction" -> {
                    result.success(initialAction)
                    initialAction = null
                }
                // WP-559: uygulama ici dil secimini NATIVE yuzeye tasir.
                // Bildirim/widget/alarm metinleri getString(R.string...) ile
                // cozulur; o da Configuration.locale'e, yani per-app override
                // yoksa CIHAZ diline bakar. Bos liste = override temizle
                // ("sistem" secildi), yoksa kullanici sistem diline donemez.
                "setApplicationLocales" -> {
                    val tags = call.argument<List<String>>("languageTags").orEmpty()
                    result.success(applyApplicationLocales(tags))
                }
                else -> result.notImplemented()
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
                        val targetSeconds = (call.argument<Number>("targetSeconds"))?.toInt()
                        val subjectId = call.argument<String>("subjectId")
                        val liveRunId = call.argument<String>("liveRunId")
                        val liveRunToken = call.argument<String>("liveRunToken")
                        val startOrigin = call.argument<String>("startOrigin") ?: "dart_app"
                        StudyTimerService.sendCommand(
                            this,
                            StudyTimerService.ACTION_START,
                            startedAtMs = startedAtMs,
                            mode = mode,
                            phase = phase,
                            cycle = cycle,
                            targetSeconds = targetSeconds,
                            subjectId = subjectId,
                            liveRunId = liveRunId,
                            liveRunToken = liveRunToken,
                            startOrigin = startOrigin,
                        )
                        result.success(null)
                    }
                    // Uygulama içi Durdur: native yalnız bildirimi kaldırır; oturum
                    // kaydını Dart yapar (çift kayıt olmasın) → STOP_SILENT.
                    "stopTimer" -> {
                        StudyTimerService.sendCommand(this, StudyTimerService.ACTION_STOP_SILENT)
                        result.success(null)
                    }
                    // WP-431: sogumus acilista SERVER DOGRULANMAMIS ayna
                    // projeksiyonunu dusurur. Durdurma DEGILDIR: kosunun sahibi
                    // baska cihazdir, sunucuya hicbir komut gitmez.
                    "discardProjection" -> {
                        StudyTimerService.sendCommand(
                            this,
                            StudyTimerService.ACTION_DISCARD_PROJECTION,
                        )
                        result.success(null)
                    }
                    // WP-764: yuzen serit izni.
                    //
                    // 🔴 Bu izin calisma-zamani penceresiyle ISTENEMEZ.
                    // `SYSTEM_ALERT_WINDOW` bir "ozel" izindir: kullanici
                    // Ayarlar'da elle acar. Bu yuzden iki ayri cagri var --
                    // biri durumu SORAR, oteki kullaniciyi dogru ekrana
                    // GOTURUR. Dart tarafi ikisini de gormeden dogru satiri
                    // cizemez.
                    "canDrawOverlays" -> result.success(TimerOverlay.isPermitted(this))
                    "requestOverlayPermission" -> {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:" + packageName),
                        )
                        // Ekran bulunamazsa (bazi OEM derlemeleri) uygulama
                        // cokmez; Dart `false` gorur ve kullaniciya elle
                        // gitmesi gerektigini soyler.
                        val opened = runCatching { startActivity(intent) }.isSuccess
                        result.success(opened)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // WP-700: widget rotasi AYRI kanaldan gider. `device_integrations`
        // kanalindaki `getInitialAction` tek seferliktir ve
        // `deviceIntegrationListener` tarafindan tuketilir; ayni kanali
        // paylasmak iki dinleyici arasinda yaris olustururdu.
        widgetRouteChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WidgetDeepLink.CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    WidgetDeepLink.METHOD_INITIAL_ROUTE -> {
                        result.success(initialWidgetRoute)
                        // Tek seferlik: yeniden baglanan bir engine ayni
                        // rotayi ikinci kez uygulamasin.
                        initialWidgetRoute = null
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

    /** Uygulanabildi mi? API 33 altinda per-app locale API'si YOKTUR -> false
     *  doner ve o cihazlarda native metinler cihaz dilinde kalir. Cagiran
     *  (Dart) donusu okur, sessiz eksik degildir. */
    private fun applyApplicationLocales(languageTags: List<String>): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return false
        return runCatching { applyApplicationLocalesTiramisu(languageTags) }
            .getOrDefault(false)
    }

    @RequiresApi(Build.VERSION_CODES.TIRAMISU)
    private fun applyApplicationLocalesTiramisu(languageTags: List<String>): Boolean {
        val manager = getSystemService(LocaleManager::class.java) ?: return false
        val requested = if (languageTags.isEmpty()) {
            LocaleList.getEmptyLocaleList()
        } else {
            LocaleList.forLanguageTags(languageTags.joinToString(","))
        }
        // Ayni degeri yeniden yazma: setApplicationLocales Activity'yi yeniden
        // yaratir. Acilista kosulan "mevcut tercihi bir kez uygula" adimi bu
        // kontrol olmadan her acilista bir recreate turu dogururdu.
        if (manager.applicationLocales == requested) return true
        manager.applicationLocales = requested
        return true
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // WP-700 SICAK YOL: uygulama zaten acikti.
        WidgetDeepLink.routeOf(
            intent.action,
            intent.getStringExtra(WidgetDeepLink.EXTRA_ROUTE),
        )?.let { route ->
            widgetRouteChannel?.invokeMethod(WidgetDeepLink.METHOD_ON_ROUTE, route)
        }
        intent.action?.let { action ->
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, CHANNEL).invokeMethod("onIntentAction", action)
            }
        }
    }
}
