import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/stats/goal_streak_projection.dart';
import '../../models/goal_streak.dart';
import '../goal_streak_repository.dart';

/// WP-453 Faz 2: seri durumu **sunucudan** okunur.
///
/// Faz 1 saf Dart durum makinesini indirdi; burada aynı sözleşme
/// `0112_goal_streak_projection.sql` içindeki `goal_streak_projection`
/// RPC'sine bağlanıyor. İstemci hesaplamayı tekrarlamaz — tekrarlasaydı iki uç
/// sessizce ayrışır ve kullanıcı ekranda başka, sunucuda başka bir seri görürdü
/// (WP-373 sınıfı hata).
///
/// Yazma yolu bilinçli olarak [GoalStreakRepository] arayüzünde yok: uygulama
/// açılışı, sayaç başlangıcı veya kısmi ilerleme kodu seriyi doğrudan
/// artıramasın diye. Tek yazıcı `record_goal_completion` RPC'sidir ve o da
/// `study_sessions`'tan gerçekten hedefe ulaşıldığını doğrular.
class SupabaseGoalStreakRepository implements GoalStreakRepository {
  SupabaseGoalStreakRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<GoalStreakProjection> readProjection(
    GoalStreakScope scope, {
    DateTime? asOfDay,
  }) async {
    final day = _day(asOfDay ?? DateTime.now());
    final rows = await _client.rpc(
      'goal_streak_projection',
      params: projectionParams(scope: scope, asOfDay: day),
    );

    final list = (rows as List?) ?? const [];
    if (list.isEmpty) return _empty(scope, day);
    final map = Map<String, dynamic>.from(list.first as Map);
    // Sunucu hiç tamamlama görmediyse ölçek alanları null döner; sözleşmenin
    // kanonik "boş" hâli tek yerde üretilsin diye modele bırakılmıyor.
    if (map['last_completed_day'] == null) return _empty(scope, day);
    return GoalStreakProjection.fromMap({
      ...map,
      'scope_type': scope.type.wireValue,
      'scope_id': scope.id,
      'time_zone': scope.timeZone,
    });
  }

  @override
  Stream<GoalStreakProjection> watchProjection(
    GoalStreakScope scope, {
    DateTime? asOfDay,
  }) {
    late final StreamController<GoalStreakProjection> controller;
    StreamSubscription<List<Map<String, dynamic>>>? subscription;

    Future<void> emit() async {
      try {
        controller.add(await readProjection(scope, asOfDay: asOfDay));
      } catch (error, stack) {
        controller.addError(error, stack);
      }
    }

    controller = StreamController<GoalStreakProjection>(
      onListen: () {
        unawaited(emit());
        subscription = _client
            .from('goal_progress_events')
            .stream(primaryKey: ['event_key'])
            .listen((_) => unawaited(emit()));
      },
      onCancel: () async {
        await subscription?.cancel();
        subscription = null;
      },
    );
    return controller.stream;
  }

  /// RPC parametreleri tek kaynaktan üretilir; sözleşme testi bu fonksiyonu
  /// okuyup `0112`deki imzayla karşılaştırır (WP-472'de kurulan desen).
  static Map<String, dynamic> projectionParams({
    required GoalStreakScope scope,
    required DateTime asOfDay,
  }) => {
    'p_scope_type': scope.type.wireValue,
    'p_scope_id': scope.id,
    'p_as_of_day': _wireDay(asOfDay),
  };

  /// Hedef tamamlamasını sunucuya **doğrulatır**. Dönen `false`, "sunucu
  /// kayıtlara göre hedefe ulaşılmadığını söyledi" demektir; hata değildir.
  static Map<String, dynamic> completionParams({
    required GoalStreakScope scope,
    required DateTime day,
  }) => {
    'p_scope_type': scope.type.wireValue,
    'p_scope_id': scope.id,
    'p_day': _wireDay(day),
  };

  GoalStreakProjection _empty(GoalStreakScope scope, DateTime day) =>
      GoalStreakProjection(
        scope: scope,
        asOfDay: day,
        currentStreak: 0,
        completionCount: 0,
        state: GoalStreakState.empty,
        sourceVersion: goalStreakProjectionSourceVersion,
      );

  static DateTime _day(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);

  static String _wireDay(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
