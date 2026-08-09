import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../time_engine/clock_permissions.dart';

final timerNotificationServiceProvider = Provider<TimerNotificationGateway>(
  (ref) => TimerNotificationService.instance,
);

enum TimerNotificationAction { open, stop, start }

/// Sayaç bildirimini **Dart üretmez.**
///
/// WP-134-137 SSOT geçişinden beri kullanıcının gördüğü canlı sayaç bildirimi
/// foreground service'in TEK bildirimidir; metnini ve kronometresini Kotlin
/// tarafı kurar (`StudyTimerService.kt`). Bu ağ geçidi yalnızca üç canlı iş
/// yapar: bildirim aksiyonlarını akışa çevirmek, bildirim iznini istemek ve
/// ESKİ sürümden kalmış flutter_local_notifications bildirimini iptal etmek.
///
/// WP-563: buraya bildirim GÖSTEREN bir metot eklenirse Kotlin ile çift
/// bildirim çıkar ve metin iki yerden üretilmeye başlar. Sözleşme testi:
/// `test/core/timer_notification_surface_wp563_test.dart`.
abstract interface class TimerNotificationGateway {
  Stream<TimerNotificationAction> get commands;

  Future<void> requestPermissionIfNeeded();

  Future<void> cancel();
}

/// WP-592: sayaç kartındaki "bildirim izni kapalı" şeridinin okuduğu yüzey.
///
/// 🔴 Bilerek [TimerNotificationGateway]'in **dışında** duruyor: o arayüzün
/// tamamı `test/core/timer_notification_surface_wp563_test.dart` içindeki
/// `_ExhaustiveGateway` tarafından derleme zamanında kapsanır. Oraya bir üye
/// eklemek, WP-563'ün "bildirim üretme yüzeyi geri doğmasın" kapısını
/// derlenemez hâle getirirdi. Ayrı arayüz iki kapıyı da canlı tutar.
abstract interface class TimerNotificationPermissionGateway {
  /// Kalıcı sayaç bildirimi kullanıcıya görünebiliyor mu?
  Future<bool> hasPermission();

  /// Sistemin bildirim ayarları sayfası — kullanıcının tek gerçek çıkışı.
  Future<void> openSystemNotificationSettings();
}

final timerNotificationPermissionProvider =
    Provider<TimerNotificationPermissionGateway>(
      (ref) => TimerNotificationService.instance,
    );

/// Sayaç kartındaki uyarı şeridinin okuduğu durum.
///
/// 🔴 Belirsizlikte `true`: olmayan bir sorun için uyarı çizmek, uyarıyı hiç
/// çizmemekten daha kötüdür (bkz. [TimerNotificationService.hasPermission]).
final timerNotificationPermissionStatusProvider = FutureProvider<bool>(
  (ref) => ref.watch(timerNotificationPermissionProvider).hasPermission(),
);

@pragma('vm:entry-point')
void timerNotificationBackgroundHandler(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final command = response.actionId == 'stop_timer'
      ? 'stop'
      : response.actionId == 'start_timer'
      ? 'start'
      : null;
  if (command == null) return;
  var sequence = 1;
  try {
    final raw = prefs.getString('timer_external_command');
    sequence =
        ((jsonDecode(raw ?? '{}') as Map<String, dynamic>)['sequence']
                as int? ??
            0) +
        1;
  } catch (_) {}
  await prefs.setString(
    'timer_external_command',
    jsonEncode({'command': command, 'sequence': sequence}),
  );
}

class TimerNotificationService
    implements TimerNotificationGateway, TimerNotificationPermissionGateway {
  TimerNotificationService._(this._plugin);

  static final instance = TimerNotificationService._(
    FlutterLocalNotificationsPlugin(),
  );

  /// Testte taze örnek: `_initialized` ve bekleyen izin isteği sıfırlanmış olur
  /// (singleton `instance` bunları testler arasında taşır).
  @visibleForTesting
  TimerNotificationService.forTest() : this._(FlutterLocalNotificationsPlugin());

  /// Eski (WP-134 öncesi) flutter_local_notifications sayaç bildiriminin id'si.
  /// Artık bu id ile bildirim GÖSTERİLMEZ; yalnız eski sürümden güncelleyen
  /// cihazda tepside asılı kalmış bildirimi temizlemek için iptal edilir.
  static const int _notificationId = 7001;
  static const String _stopActionId = 'stop_timer';

  static final _commands =
      StreamController<TimerNotificationAction>.broadcast();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  // WP-520: izin diyaloğu açıkken uçan istek. Android aynı anda ikinci izin
  // isteğini `permissionRequestInProgress` koduyla reddeder; ikinci `Başlat`ı
  // platforma hiç götürmeyip bekleyen sonucu paylaşırız.
  Future<void>? _pendingPermissionRequest;

  @override
  Stream<TimerNotificationAction> get commands => _commands.stream;

  Future<void> initialize() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: dispatchResponse,
      onDidReceiveBackgroundNotificationResponse:
          timerNotificationBackgroundHandler,
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final response = launchDetails?.notificationResponse;
    if ((launchDetails?.didNotificationLaunchApp ?? false) &&
        response != null) {
      dispatchResponse(response);
    }

    _initialized = true;
  }

  /// WP-520: **hiçbir koşulda hata fırlatmaz** — sayaç başlatma izin isteğine
  /// bağlı değildir, izin yoksa yalnız bildirim olmaz.
  @override
  Future<void> requestPermissionIfNeeded() {
    if (!_isAndroid) return Future<void>.value();
    final pending = _pendingPermissionRequest;
    // Diyalog açıkken gelen ikinci basış: ikinci platform çağrısı üretilmez,
    // ilk isteğin sonucu paylaşılır.
    if (pending != null) return pending;
    final request = _requestNotificationsPermission();
    _pendingPermissionRequest = request;
    // Sonuç ne olursa olsun kilidi aç; aksi halde bir kez başarısız olan izin
    // isteği sonraki bütün başlatmaları sessizce engellerdi.
    return request.whenComplete(() => _pendingPermissionRequest = null);
  }

  Future<void> _requestNotificationsPermission() async {
    try {
      await initialize();
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } on PlatformException catch (error) {
      // Örn. `permissionRequestInProgress`: izin diyaloğu zaten açık. Kullanıcı
      // için doğru davranış çökmek değil, izinsiz devam etmektir.
      // (Geliştirici logu — kullanıcıya görünmez, bu yüzden İngilizce.)
      debugPrint('timer notification permission request failed: ${error.code}');
    }
  }

  /// WP-592: izin **okunur, istenmez.** `false` yalnız Android'de ve platform
  /// net biçimde "kapalı" dediğinde döner. Belirsizlikte (masaüstü, eklenti
  /// çözülemedi, platform hatası) `true` döner: olmayan bir sorun için uyarı
  /// çizmek, uyarıyı hiç çizmemekten daha kötüdür.
  @override
  Future<bool> hasPermission() async {
    if (!_isAndroid) return true;
    try {
      await initialize();
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.areNotificationsEnabled() ?? true;
    } on PlatformException catch (error) {
      // (Geliştirici logu — kullanıcıya görünmez, bu yüzden İngilizce.)
      debugPrint('timer notification permission probe failed: ${error.code}');
      return true;
    }
  }

  /// Sistem bildirim ayarları zaten `ClockPermissions` üzerinden açılıyor
  /// (saat/alarm ekranları); kanal adı ikinci kez tanımlanmaz.
  @override
  Future<void> openSystemNotificationSettings() =>
      ClockPermissions.instance.openNotificationSettings();

  @override
  Future<void> cancel() async {
    if (!_isAndroid) return;
    await initialize();
    await _plugin.cancel(id: _notificationId);
  }

  @visibleForTesting
  static void dispatchResponse(NotificationResponse response) {
    if (response.actionId == _stopActionId) {
      _commands.add(TimerNotificationAction.stop);
      return;
    }
    _commands.add(TimerNotificationAction.open);
  }

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
