import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/istanbul_calendar.dart';
import 'package:online_study_room/data/providers/study_providers.dart';

/// 🔴 WP-865 — "bugün kaydedilen" gece yarısında kendini yeniler.
///
/// Avcı İDDİA 1: `todayRecordedSecondsProvider` günü yalnız oturum listesi
/// değişince okuyordu; uygulama gece yarısını açık geçirirse dünün toplamı
/// "bugün" diye kalıyordu. Kodda enjekte edilebilir saat yok; bu yüzden ölçüm
/// iki parçadır: (1) bekleme süresi doğru sınıra denk geliyor mu, (2) sağlayıcı
/// o süreyle gerçekten bir yenileme zamanlayıcısı kuruyor mu.
void main() {
  test('bekleme bir sonraki İstanbul gece yarısına denk gelir (+1 sn)', () {
    // İstanbul 23:59:30 = UTC 20:59:30.
    final now = DateTime.utc(2026, 9, 18, 20, 59, 30);
    final wait = durationUntilNextIstanbulDay(now);
    expect(wait, const Duration(seconds: 31));
    expect(
      istanbulDay(now.add(wait)),
      isNot(istanbulDay(now)),
      reason: 'bekleme sonunda yeni güne geçilmiş olmalı',
    );
  });

  test('gün ortasında bekleme gece yarısına kadar olan süredir', () {
    // İstanbul 12:00 = UTC 09:00.
    final now = DateTime.utc(2026, 9, 18, 9);
    expect(
      durationUntilNextIstanbulDay(now),
      const Duration(hours: 12, seconds: 1),
    );
  });

  test('sağlayıcı gece yarısı yenilemesi için zamanlayıcı kurar ve bırakır', () {
    fakeAsync((async) {
      final container = ProviderContainer(
        overrides: [dailyTotalsProvider.overrideWithValue(const {})],
      );
      expect(async.pendingTimers, isEmpty);
      container.read(todayRecordedSecondsProvider);
      final timers = async.pendingTimers.toList();
      expect(timers, hasLength(1), reason: 'yenileme zamanlayıcısı kurulmadı');
      expect(timers.single.duration, greaterThan(Duration.zero));
      expect(
        timers.single.duration,
        lessThanOrEqualTo(const Duration(hours: 25, seconds: 1)),
      );
      container.dispose();
      expect(async.pendingTimers, isEmpty, reason: 'dispose zamanlayıcıyı iptal etmeli');
    });
  });
}
