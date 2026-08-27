import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Çalışma sayacının native foreground servisinin **Dart cephesi** (V8-A · WP-42/51).
///
/// Artık bildirim/servis tamamen native Kotlin `StudyTimerService` tarafından
/// yönetilir (bkz. `android/.../timer/StudyTimerService.kt`). Bunun sebebi:
/// kullanıcı uygulamayı tamamen kapatmışken bile **widget/bildirim** üzerinden
/// Başlat/Durdur çalışsın — bir BroadcastReceiver servisi native ayağa kaldırır,
/// Flutter motoru gerekmez.
///
/// Bu sınıf yalnız uygulama içi Başlat/Durdur'u method channel üzerinden native
/// servise iletir. **Oturum kaydı burada YAPILMAZ:** app-kapalı Durdur'ların
/// ürettiği aralıklar native tarafından `timer_pending_intervals` kuyruğuna yazılır
/// ve uygulama açılınca `StudyTimerNotifier._reconcileBackgroundTimer` bunları
/// server-authoritative oturum olarak kaydeder.
class TimerForegroundService {
  TimerForegroundService._();

  static const MethodChannel _channel = MethodChannel(
    'com.manilmax.online_study_room/timer',
  );

  /// FGS görünüm modu bayrağı (native yazar, Dart reconcile okur): `running`/`idle`.
  static const fgModeKey = 'timer_fg_mode';

  /// App-kapalı Durdur'ların tamamlanmış çalışma aralıkları kuyruğu (native yazar,
  /// Dart `_reconcileBackgroundTimer` okur ve oturum olarak kaydeder).
  static const pendingIntervalsKey = 'timer_pending_intervals';
  static const activeRunIdKey = 'timer_active_live_run_id';
  static const activeRunTokenKey = 'timer_active_live_run_token';
  static const activeOriginKey = 'timer_active_start_origin';

  /// WP-764 — yüzen sayaç şeridinin **izin durumu**.
  ///
  /// 🔴 `SYSTEM_ALERT_WINDOW` normal bir çalışma-zamanı izni DEĞİLDİR: bir
  /// izin penceresiyle istenemez, kullanıcı Ayarlar'da elle açar. Bu yüzden
  /// iki ayrı çağrı var — biri durumu **sorar**, öteki kullanıcıyı doğru
  /// ekrana **götürür**.
  ///
  /// 🔴 Sonuç ÖNBELLEKLENMEZ. Kullanıcı izni Ayarlar'dan istediği an geri
  /// alabilir ve bundan haberimiz olmaz; bayat bir "izin var" değeri ekranda
  /// yalan söyler.
  ///
  /// Android dışında her zaman `false` döner: şerit yalnız Android'de vardır.
  static Future<bool> canDrawOverlays() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _channel.invokeMethod<bool>('canDrawOverlays') ?? false;
    } on PlatformException catch (e, s) {
      debugPrint('canDrawOverlays basarisiz: $e\n$s');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Sistemin "diğer uygulamaların üzerinde göster" ekranını açar.
  ///
  /// Dönen değer izin VERİLDİĞİNİ göstermez — yalnız ekranın açılabildiğini.
  /// İzin, kullanıcı geri döndükten sonra [canDrawOverlays] ile yeniden
  /// sorulur; bu ayrımı kaybetmek "açtım sandım ama açılmamış" durumunu
  /// görünmez yapar.
  static Future<bool> requestOverlayPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _channel.invokeMethod<bool>('requestOverlayPermission') ??
          false;
    } on PlatformException catch (e, s) {
      debugPrint('requestOverlayPermission basarisiz: $e\n$s');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Uygulama içi Başlat: native servise akan bildirimi başlat komutu gönderir.
  static Future<void> start({
    required DateTime startedAt,
    required String mode,
    required String phase,
    required int cycle,
    int? targetSeconds,
    String? subjectId,
    String? liveRunId,
    String? liveRunToken,
    String startOrigin = 'dart_app',
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('startTimer', <String, dynamic>{
        'startedAtMs': startedAt.millisecondsSinceEpoch,
        'mode': mode,
        'phase': phase,
        'cycle': cycle,
        'targetSeconds': targetSeconds,
        'subjectId': subjectId,
        'liveRunId': liveRunId,
        'liveRunToken': liveRunToken,
        'startOrigin': startOrigin,
      });
    } catch (_) {
      // Test/web-benzeri hostlarda platform kanalı yoktur; timer state bozulmaz.
    }
  }

  /// Uygulama içi Durdur: native yalnız bildirimi kaldırır. Oturum kaydını Dart
  /// yapar (çift kayıt olmasın diye native tarafta aralık kuyruğa yazılmaz).
  static Future<void> stop() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('stopTimer');
    } catch (_) {
      // Platform kanalı olmayan test hostu.
    }
  }

  /// WP-431: sunucu doğrulanmamış **ayna projeksiyonunu** yerelde düşürür.
  ///
  /// [stop] ile karıştırılmamalıdır: bu bir durdurma DEĞİLDİR. Koşunun sahibi
  /// başka cihazdır ve orada çalışmaya devam ediyor olabilir; bu yüzden native
  /// taraf ne V2 stop zarfı ne de bekleyen aralık yazar. Soğuk açılışta ayna
  /// durumu server onayı olmadan diriltilmesin diye vardır (V56-S04).
  static Future<void> discardProjection() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('discardProjection');
    } catch (_) {
      // Platform kanalı olmayan test hostu.
    }
  }

  /// Son native running notification'Ä±n Live Update uygunluk teÅŸhisini okur.
  /// SayaÃ§ henÃ¼z baÅŸlatÄ±lmadÄ±ysa Ã¶lÃ§Ã¼m alanlarÄ± null kalÄ±r.
}
