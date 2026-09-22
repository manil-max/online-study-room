import Flutter
import UIKit
import UserNotifications
// FlutterLocalNotificationsPlugin.setPluginRegistrantCallback icin gerekli.
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // Dart: lib/core/time_engine/device_timezone.dart (Android ile ayni ad).
  private static let timezoneChannelName = "com.manilmax.online_study_room/exact_alarm"
  private var timezoneChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // flutter_local_notifications: on-plan bildirimleri ve dokunma geri
    // cagrilarini almak icin (FlutterAppDelegate zaten
    // UNUserNotificationCenterDelegate; firebase_messaging bunu zincirler).
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // Bildirim aksiyon isolate'inde eklentilerin calisabilmesi icin
    // (flutter_local_notifications README, UIScene yasam dongusu).
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Cihazin IANA saat dilimi (alarm/zamanlayici duvar saati).
    let channel = FlutterMethodChannel(
      name: AppDelegate.timezoneChannelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { (call, result) in
      if call.method == "getLocalTimezoneId" {
        result(TimeZone.current.identifier)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    timezoneChannel = channel
  }
}
