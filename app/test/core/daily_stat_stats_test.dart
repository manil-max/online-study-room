import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/study_stats.dart';
import 'package:online_study_room/data/models/daily_stat.dart';

DailyStat _d(String user, DateTime day, int seconds) =>
    DailyStat(userId: user, day: DateTime(day.year, day.month, day.day), seconds: seconds);

void main() {
  // İki kullanıcı, birkaç gün.
  final stats = [
    _d('u1', DateTime(2026, 6, 22), 600),
    _d('u1', DateTime(2026, 6, 23), 1200),
    _d('u1', DateTime(2026, 6, 25), 300),
    _d('u2', DateTime(2026, 6, 25), 900),
    _d('u2', DateTime(2026, 6, 24), 100),
  ];

  test('groupDayTotals: gün bazında tüm üyeleri birleştirir', () {
    final m = groupDayTotals(stats);
    expect(m[DateTime(2026, 6, 22)], 600);
    expect(m[DateTime(2026, 6, 25)], 1200); // u1 300 + u2 900
    expect(m[DateTime(2026, 6, 24)], 100);
  });

  test('userDayTotals: yalnızca o kullanıcı', () {
    final m = userDayTotals(stats, 'u1');
    expect(m.length, 3);
    expect(m[DateTime(2026, 6, 23)], 1200);
    expect(m.containsKey(DateTime(2026, 6, 24)), isFalse);
  });

  test('todaySecondsByUser: verilen gün için kullanıcı→saniye', () {
    final m = todaySecondsByUser(stats, today: DateTime(2026, 6, 25, 14));
    expect(m['u1'], 300);
    expect(m['u2'], 900);
    expect(m.containsKey('x'), isFalse);
  });

  test('userTotalsInRange: aralık (iki uç dâhil) per-user toplam', () {
    final m = userTotalsInRange(stats, DateTime(2026, 6, 23), DateTime(2026, 6, 25));
    expect(m['u1'], 1500); // 23:1200 + 25:300
    expect(m['u2'], 1000); // 24:100 + 25:900
  });

  test('parity: agregadan currentStreak == günlük toplamdan', () {
    // 🔴 WP-739: u1'in günleri 22-23-25; 24 boş. Tek boş gün artık seriyi
    // KIRMAZ (ürünün duraklamalı seri kuralı, `goal_streak_rule.dart`), yani
    // 25 Haziran'da seri 3'tür. Bu testin ölçtüğü şey kural değil PARİTE:
    // agregadan (DailyStat) türetilen harita ile günlük toplam haritası aynı
    // sayıyı vermeli.
    final u1 = userDayTotals(stats, 'u1');
    expect(currentStreak(const [], 1, today: DateTime(2026, 6, 25), totals: u1), 3);
    // bugün 23 olsaydı 22-23 → 2.
    expect(currentStreak(const [], 1, today: DateTime(2026, 6, 23), totals: u1), 2);
    // Ters iddia: üç günlük boşluk (26-28 boş) 29'da seriyi sıfırlar.
    expect(currentStreak(const [], 1, today: DateTime(2026, 6, 29), totals: u1), 0);
  });

  test('parity: lastNDays agregadan beklenen seriyi verir', () {
    final group = groupDayTotals(stats);
    final series = lastNDays(const [], 4, today: DateTime(2026, 6, 25), totals: group);
    // 22,23,24,25
    expect(series.map((e) => e.seconds).toList(), [600, 1200, 100, 1200]);
  });
}
