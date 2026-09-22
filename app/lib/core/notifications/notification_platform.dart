import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// WP-901: `flutter_local_notifications` kurulumunun **tek** tanımı.
///
/// 🔴 FLN, iOS'ta `InitializationSettings.iOS == null` görünce `ArgumentError`
/// fırlatır ("iOS settings must be set when targeting iOS platform"). Kod
/// yıllarca yalnız `android:` veriyordu; iOS derlemesinde hatırlatıcı, alarm ve
/// push servislerinin hepsi kurulumda düşerdi. Android alanı bu sabitte
/// **aynen** durur — Android davranışı değişmez, FLN yalnız hedef platformun
/// alanını okur.
///
/// iOS izinleri kurulumda **istenmez** (`request*Permission: false`): izin
/// penceresi bağlamsız, açılışın ilk karesinde patlardı. İzin, Android'deki gibi
/// açıkça ve bir kez istenir (onboarding düğmesi / WP-848 kabuk sorusu /
/// İzinler ekranı) — bkz. [requestDarwinNotificationPermission].
const kDarwinNotificationInitSettings = DarwinInitializationSettings(
  requestAlertPermission: false,
  requestSoundPermission: false,
  requestBadgePermission: false,
);

/// Uygulamanın bütün FLN örnekleri için ortak kurulum ayarı.
const kLocalNotificationInitSettings = InitializationSettings(
  android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  iOS: kDarwinNotificationInitSettings,
);

/// Hedef platform iOS mu? `defaultTargetPlatform` üzerinden okunur (`dart:io`
/// değil): testte `debugDefaultTargetPlatformOverride` ile enjekte edilebilir.
bool get isIosTarget => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// iOS bildirim izni penceresini açar (izin zaten verildi/reddedildiyse sistem
/// pencereyi yeniden göstermez, yalnız mevcut durumu döndürür).
///
/// Hiçbir koşulda fırlatmaz: eklenti çözülemezse (test hostu) veya kanal hata
/// verirse `false` döner — izin sorusu hiçbir akışı düşürmemeli.
Future<bool> requestDarwinNotificationPermission(
  FlutterLocalNotificationsPlugin plugin,
) async {
  try {
    final ios = plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
  } catch (_) {
    return false;
  }
}

/// iOS'ta bildirim izni şu an açık mı? Okunamazsa `null` (belirsiz).
Future<bool?> darwinNotificationsEnabled(
  FlutterLocalNotificationsPlugin plugin,
) async {
  try {
    final ios = plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios == null) return null;
    final options = await ios.checkPermissions();
    return options?.isEnabled;
  } catch (_) {
    return null;
  }
}
