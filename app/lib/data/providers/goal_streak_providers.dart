import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/config/supabase_config.dart';
import '../../core/stats/istanbul_calendar.dart';
import '../models/goal_streak.dart';
import '../repositories/goal_streak_repository.dart';
import '../repositories/in_memory/in_memory_goal_streak_repository.dart';
import '../repositories/supabase/supabase_goal_streak_repository.dart';

/// WP-453 Faz 2: seri durumunun tek okuma kaynağı.
///
/// Faz 1 saf Dart durum makinesini indirmiş ama hiçbir yere bağlamamıştı;
/// WP-454'ün alev göstergesi "durum yalnız server projection'dan" diyor, o
/// yüzden bağ burada kuruluyor. Supabase yapılandırılmışsa gerçek projeksiyon
/// RPC'si, değilse demo/offline için bellek-içi eş kullanılır.
final goalStreakRepositoryProvider = Provider<GoalStreakRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseGoalStreakRepository(Supabase.instance.client);
  }
  return InMemoryGoalStreakRepository();
});

/// Bir kapsamın güncel seri projeksiyonu.
///
/// 🔴 Bilinçli olarak yalnız OKUR. Seri artırma yolu ne burada ne de
/// [GoalStreakRepository] arayüzünde var: uygulama açılışı, sayaç başlangıcı
/// ve kısmi ilerleme kodu seriye hiçbir şekilde dokunamasın diye. Tek yazıcı
/// sunucudaki `record_goal_completion` RPC'sidir ve o da hedefe gerçekten
/// ulaşıldığını `study_sessions` üzerinden doğrular.
final goalStreakProjectionProvider =
    StreamProvider.family<GoalStreakProjection, GoalStreakScope>((ref, scope) {
      // 🔴 WP-604: gün dönüşünde yeniden hesapla. Bkz. [GoalStreakDayRollover].
      ref.watch(goalStreakDayRolloverProvider);
      return ref.watch(goalStreakRepositoryProvider).watchProjection(scope);
    });

/// 🔴 WP-604 — bu depoda serinin defalarca "takılı kalmasının" ASIL sebebi.
///
/// Seri durumu (`completedToday` / `pendingToday` / `atRisk` / `expired`) bir
/// **zaman** fonksiyonudur: aynı veriyle, yalnız gün değiştiği için durum
/// değişir. Ama projeksiyon yalnız **veri** değiştiğinde yeniden hesaplanıyordu:
/// `SupabaseGoalStreakRepository.watchProjection` bir kez `emit()` ediyor, sonra
/// yalnız `goal_progress_events` tablosu değişince tekrar ediyor.
///
/// Gece yarısında hiçbir satır değişmez. Yani dün hedefini tutturan kullanıcı
/// `completedToday` (canlı alev) ile kalır ve ertesi gün hedefini tutturmasa
/// bile alev **canlı kalmaya devam eder** — sahibin bildirdiği belirti tam
/// olarak budur. Rengi düzeltmek bunu çözmez; durum zaten yanlış durumdur.
///
/// Aynı desenin doğrusu depoda zaten var: `UserTaskDayRefreshLifecycle`
/// (İstanbul gece yarısına zamanlayıcı + uygulama öne gelince tazeleme).
/// Seri ona bağlanmamıştı — "yazılmış ama çağıran yok" hatasının bir örneği daha.
///
/// İki tetikleyici birden gerekiyor:
///   * **zamanlayıcı**: uygulama açıkken gece yarısını geçen kullanıcı,
///   * **öne gelme**: uygulama arka planda uyurken zamanlayıcı çalışmaz;
///     kullanıcı sabah uygulamayı açtığında tazeleme oradan gelir.
class GoalStreakDayRollover with WidgetsBindingObserver {
  GoalStreakDayRollover(this._ref, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Ref _ref;

  /// Saat ENJEKTE edilir. Gerçek saate bağlı bir gün-dönüşü testi ya hiçbir
  /// şey ölçemez ya da gece yarısı sürüm koşumunu kırar; bu depoda ikincisi
  /// iki kez oldu (WP-565, WP-571).
  final DateTime Function() _now;

  Timer? _timer;
  var _started = false;

  /// Son tazelemenin ait olduğu İstanbul günü. Öne gelme her seferinde değil,
  /// yalnız **gün gerçekten değiştiyse** tazeler; aksi halde sekmeler arası
  /// her geçişte sunucuya gidilirdi.
  DateTime? _lastDay;

  void start() {
    if (_started) return;
    _started = true;
    _lastDay = istanbulDay(_now());
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final today = istanbulDay(_now());
    if (_lastDay != today) {
      _lastDay = today;
      _invalidate();
    }
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final istanbul = tz.getLocation('Europe/Istanbul');
    final now = tz.TZDateTime.from(_now(), istanbul);
    final nextDay = tz.TZDateTime(istanbul, now.year, now.month, now.day + 1);
    final delay = nextDay.toUtc().difference(_now().toUtc());
    _timer = Timer(delay + const Duration(milliseconds: 100), () {
      _lastDay = istanbulDay(_now());
      _invalidate();
      _schedule();
    });
  }

  void _invalidate() => _ref.invalidate(goalStreakProjectionProvider);

  void dispose() {
    if (!_started) return;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
    _started = false;
  }
}

/// Testte saati enjekte etmek için override edilir.
final goalStreakClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final goalStreakDayRolloverProvider = Provider<GoalStreakDayRollover>((ref) {
  final rollover = GoalStreakDayRollover(
    ref,
    now: ref.watch(goalStreakClockProvider),
  )..start();
  ref.onDispose(rollover.dispose);
  return rollover;
});
