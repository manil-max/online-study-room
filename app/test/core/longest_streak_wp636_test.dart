import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/study_stats.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// WP-636 — "En uzun seri" rekoru.
///
/// Sahip bildirimi: Rekorlar bölümündeki "en uzun seri" 30 yazıyor, "sanırım
/// aktif günü baz alıyor". Bu dosya önce o HİPOTEZİ ÖLÇER (§1), sonra
/// fonksiyonun gerçek kırılma noktasını (§3) sözleşmeye bağlar.
///
/// 🔴 Cihazın zaman dilimi test sürecinde değiştirilemez. "Cihaz yerel gece
/// yarısı" sınıfındaki hatalar bu yüzden bölgeyi **açıkça taşıyan**
/// `tz.TZDateTime` anahtarlarıyla kanıtlanır: `istanbulDay` bir gün anahtarını
/// `DateTime(local.year, local.month, local.day)` ile kurar; Berlin'deki bir
/// cihazda o ifadenin ürettiği AN, `tz.TZDateTime(berlin, y, m, d)` ile
/// birebir aynıdır. Yani buradaki anahtarlar uydurma değil, DST uygulayan bir
/// cihazın gerçekten ürettiği anahtarlardır.
///
/// 🔴 WP-637 sonrası: rekorun KURALI değişti (artık "≥ 1 sn çalışılan gün"
/// değil, "günlük hedefi tutturan gün" — bkz. `longest_streak_wp637_test.dart`),
/// ardışıklığın ÖLÇÜSÜ değişmedi. Bu dosyanın konusu ikincisidir; o yüzden her
/// çağrı artık hedefini AÇIKÇA geçirir ve günler hedefi tutturacak şekilde
/// kurulur — böylece ölçülen tek değişken takvim farkı olarak kalır.
tz.Location _berlin() {
  tz_data.initializeTimeZones();
  return tz.getLocation('Europe/Berlin');
}

StudySession _s(DateTime start, int seconds) => StudySession(
  id: 's-${start.toIso8601String()}',
  userId: 'u1',
  start: start,
  end: start.add(Duration(seconds: seconds)),
  durationSeconds: seconds,
  source: StudySource.live,
);

Map<DateTime, int> _totals(Iterable<DateTime> days, {int seconds = 3600}) => {
  for (final d in days) d: seconds,
};

void main() {
  group('WP-636 §1: seri AKTİF GÜN SAYISI değildir', () {
    // Sahibin hipotezi: "aktif günü baz alıyor". Doğruysa aşağıdaki iki sayı
    // eşit çıkar. Bu test hipotezi ölçer ve aynı zamanda kalıcı bir kapıdır:
    // biri `longestStudyStreak`'i `activeDayCount`e çevirirse kırmızı olur.
    test('boşluklu günlerde seri KIRILIR (aktif gün 5, seri 1)', () {
      final base = DateTime(2026, 5, 1);
      final gapped = [
        base,
        base.add(const Duration(days: 2)),
        base.add(const Duration(days: 4)),
        base.add(const Duration(days: 6)),
        base.add(const Duration(days: 8)),
      ];
      final totals = _totals(gapped);
      expect(activeDayCount(totals), 5, reason: 'ölçüm: 5 aktif gün var');
      expect(
        longestStudyStreak(const [], totals: totals, goalSeconds: 3600),
        1,
        reason: 'her gün tek başına — en uzun ardışık seri 1 olmalı',
      );
    });

    test('30 aktif gün + tek boşluk = 30 DEĞİL', () {
      // Sahibin gördüğü sayıya en yakın kurulum: 30 aktif gün, ama ortada bir
      // gün eksik. "Aktif gün" 30, "en uzun seri" 30 olamaz.
      final base = DateTime(2026, 5, 1);
      final days = <DateTime>[
        for (var i = 0; i < 31; i++)
          if (i != 15) base.add(Duration(days: i)),
      ];
      final totals = _totals(days);
      expect(activeDayCount(totals), 30);
      expect(
        longestStudyStreak(const [], totals: totals, goalSeconds: 3600),
        15,
      );
    });
  });

  group('WP-636 §2: ters iddia — ardışık günler BİRLEŞİR', () {
    // "Hep 1 döndür" gibi bir çözüm bu gruptan geçemez.
    test('30 ardışık gün = 30', () {
      final base = DateTime(2026, 5, 1);
      final totals = _totals([
        for (var i = 0; i < 30; i++) base.add(Duration(days: i)),
      ]);
      expect(
        longestStudyStreak(const [], totals: totals, goalSeconds: 3600),
        30,
      );
    });

    test('en uzun blok kazanır (3 / 5 / 2 → 5)', () {
      final base = DateTime(2026, 5, 1);
      final days = <DateTime>[
        for (var i = 0; i < 3; i++) base.add(Duration(days: i)),
        for (var i = 5; i < 10; i++) base.add(Duration(days: i)),
        for (var i = 12; i < 14; i++) base.add(Duration(days: i)),
      ];
      expect(
        longestStudyStreak(const [], totals: _totals(days), goalSeconds: 3600),
        5,
      );
    });

    test('oturumlardan (totals verilmeden) da aynı sonuç', () {
      // `dailyTotals` yolu: gün anahtarı oturumun BAŞLANGIÇ gününden çıkar.
      final sessions = [
        _s(DateTime.utc(2026, 5, 1, 9), 1800),
        _s(DateTime.utc(2026, 5, 2, 9), 1800),
        _s(DateTime.utc(2026, 5, 2, 20), 1800), // aynı gün ikinci oturum
        _s(DateTime.utc(2026, 5, 4, 9), 1800),
      ];
      // Hedef 1800: 1 ve 2 Mayıs tutturur (2 Mayıs iki oturumla 3600), 4 Mayıs
      // da tutturur ama 3 Mayıs boştur → en uzun blok 2.
      expect(longestStudyStreak(sessions, goalSeconds: 1800), 2);
    });
  });

  group('WP-636 §3: gün sınırı ARİTMETİK DEĞİL TAKVİMSEL', () {
    // 🔴 Kök neden: eski kod ardışıklığı
    //   days[i].difference(days[i - 1]).inDays == 1
    // ile ölçüyordu. Bu iki gün anahtarı arasındaki GEÇEN SÜREdir, takvim
    // farkı değil. DST uygulayan bir cihazda gece yarısıdan gece yarısına
    // 23 ya da 25 saat olabilir; sonuç İKİ YÖNLÜ bozuktur.
    test('DST atlaması: 2 günlük BOŞLUK seriyi birleştirmez (şişirme)', () {
      final berlin = _berlin();
      // Berlin 2026: DST 29 Mart 02:00'da başlar.
      // 29 Mart 00:00 = 28 Mart 23:00Z, 31 Mart 00:00 = 30 Mart 22:00Z
      // → aradaki fark 47 saat → eski kodda `inDays == 1` → yanlışlıkla ardışık.
      final d29 = tz.TZDateTime(berlin, 2026, 3, 29);
      final d31 = tz.TZDateTime(berlin, 2026, 3, 31);
      expect(
        d31.difference(d29).inHours,
        47,
        reason: 'kurulum doğrulaması: gerçekten 47 saat',
      );
      expect(
        longestStudyStreak(
          const [],
          totals: {d29: 3600, d31: 3600},
          goalSeconds: 3600,
        ),
        1,
        reason: '30 Mart çalışılmadı — 29 ve 31 ardışık değildir',
      );
    });

    test('DST atlaması: ARDIŞIK iki gün seriyi kırmaz (düşürme)', () {
      final berlin = _berlin();
      // 29 Mart 00:00 → 30 Mart 00:00 = 23 saat → eski kodda `inDays == 0`
      // → gerçek seri sessizce kırılıyordu.
      final d29 = tz.TZDateTime(berlin, 2026, 3, 29);
      final d30 = tz.TZDateTime(berlin, 2026, 3, 30);
      expect(d30.difference(d29).inHours, 23);
      expect(
        longestStudyStreak(
          const [],
          totals: {d29: 3600, d30: 3600},
          goalSeconds: 3600,
        ),
        2,
        reason: '29 ve 30 Mart takvimde ardışıktır',
      );
    });

    test('sonbahar geri alması (25 saat) da ardışık sayılır', () {
      final berlin = _berlin();
      final d25 = tz.TZDateTime(berlin, 2026, 10, 25);
      final d26 = tz.TZDateTime(berlin, 2026, 10, 26);
      expect(d26.difference(d25).inHours, 25);
      expect(
        longestStudyStreak(
          const [],
          totals: {d25: 3600, d26: 3600},
          goalSeconds: 3600,
        ),
        2,
      );
    });

    test('aynı takvim gününü gösteren iki anahtar seriyi kırmaz', () {
      // Aynı gün iki farklı temsille haritaya girerse (UTC damgası + yerel
      // anahtar) fark 0 olur; bu bir BOŞLUK değildir, seri kırılmamalıdır.
      final totals = <DateTime, int>{
        DateTime(2026, 5, 1): 3600,
        DateTime.utc(2026, 5, 1): 1800,
        DateTime(2026, 5, 2): 3600,
      };
      expect(
        longestStudyStreak(const [], totals: totals, goalSeconds: 1800),
        2,
      );
    });
  });

  group('WP-636 §4: WP-561 kuralları korunur', () {
    test('0 saniyelik gün seriyi köprülemez', () {
      final d = DateTime(2026, 8, 1);
      expect(
        longestStudyStreak(
          const [],
          totals: {
            d: 3600,
            d.add(const Duration(days: 1)): 0,
            d.add(const Duration(days: 2)): 3600,
          },
          goalSeconds: 3600,
        ),
        1,
      );
    });

    test('veri yoksa 0', () {
      expect(longestStudyStreak(const [], goalSeconds: 3600), 0);
      expect(
        longestStudyStreak(const [], totals: const {}, goalSeconds: 3600),
        0,
      );
    });
  });
}
