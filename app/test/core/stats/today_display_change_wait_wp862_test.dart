// WP-862 — KABA KARTLARIN YENİLEME ANI, KARTIN GÖSTERDİĞİ YÜZDEYLE AYNI
// ARİTMETİKTEN HESAPLANIR.
//
// Avcı bulgusu (WP-856): `secondsUntilTodayDisplayChange` yüzde sınırını
// `(total * 100 / goal).round()` ile buluyordu; kartlar ise yüzdeyi
// `((total / goal).clamp(0, 1) * 100).round()` ile çiziyor
// (`goal_card.dart`, `study_timer_card.dart`). İki ifade kayan noktada tam
// yarımlarda ayrışıyor: hedef 10 dk, toplam 87 sn → yardımcı "%15 (14,5)",
// kart "%14" (14,499999…) görüyor. Yardımcı bir sonraki sınırı %15→%16'ya
// kuruyor; kartın %14→%15 geçişi (88. sn) kaçıyor ve günlük hedef kartı
// saniyelik sayaç kartından 5 sn boyunca bir yüzde geride kalıyor — WP-856'nın
// kapattığı "%84 / %65" çelişkisinin küçük hâli.
//
// Ölçüm: kartın gösterdiği HER şey (toplam, kalan, yüzde, eşik) için,
// yardımcının verdiği bekleme süresinin İÇİNDE hiçbir değişiklik olmamalı.
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/study_stats.dart';
import 'package:online_study_room/core/utils/duration_format.dart';

/// `goal_card.dart` / `study_timer_card.dart` ile birebir aynı ifadeler.
String _cardDisplay(int t, int g) {
  final pct = g <= 0 ? 0.0 : (t / g).clamp(0.0, 1.0);
  return [
    formatHumanForLocale(t, 'tr'),
    formatHumanForLocale((g - t).clamp(0, 1 << 30), 'tr'),
    '%${(pct * 100).round()}',
    t >= g && g > 0,
  ].join('|');
}

void main() {
  test('bekleme süresi içinde kartın gösterdiği hiçbir şey değişmez', () {
    final misses = <String>[];
    const goals = [0, 1, 7, 59, 60, 61, 90, 600, 1234, 3600, 5400, 9000];
    for (final g in [...goals, 7 * 3600 + 13, 43200]) {
      for (var t = 0; t < g + 7300 && misses.length < 10; t++) {
        final wait = secondsUntilTodayDisplayChange(
          totalSeconds: t,
          goalSeconds: g,
        );
        expect(wait, inInclusiveRange(1, 60));
        final shown = _cardDisplay(t, g);
        for (var k = 1; k < wait; k++) {
          if (_cardDisplay(t + k, g) != shown) {
            misses.add('hedef=$g toplam=$t bekleme=$wait değişim=+$k');
            break;
          }
        }
      }
    }
    expect(misses, isEmpty);
  });

  test('hedef 10 dk, toplam 87 sn: kart 88. saniyede %15 olur', () {
    expect(_cardDisplay(87, 600), contains('%14'));
    expect(_cardDisplay(88, 600), contains('%15'));
    expect(
      secondsUntilTodayDisplayChange(totalSeconds: 87, goalSeconds: 600),
      1,
    );
  });
}
