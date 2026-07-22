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

  /// Uygulama içi Başlat: native servise akan bildirimi başlat komutu gönderir.
  static Future<void> start({
    required DateTime startedAt,
    required String mode,
    required String phase,
    required int cycle,
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

  /// Son native running notification'Ä±n Live Update uygunluk teÅŸhisini okur.
  /// SayaÃ§ henÃ¼z baÅŸlatÄ±lmadÄ±ysa Ã¶lÃ§Ã¼m alanlarÄ± null kalÄ±r.
}
