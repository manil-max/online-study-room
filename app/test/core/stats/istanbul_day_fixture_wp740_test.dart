import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/istanbul_calendar.dart';
import 'package:online_study_room/core/stats/study_stats.dart';
import 'package:online_study_room/data/models/daily_stat.dart';

/// WP-740 — **"bugün" cihazın günü değil, İstanbul günüdür.**
///
/// 🔴 Kök neden. İki kapı (`leaderboard_dense_row_wp662_test.dart`,
/// `desktop_settings_wp679_test.dart`) fixture'ını `DateTime.now()` ile, yani
/// KOŞUCUNUN yerel takvim günüyle kuruyordu. Uygulama ise günü her yerde
/// [istanbulDay] ile kesiyor. CI (UTC) saat 21:00'den sonra koştuğunda İstanbul
/// çoktan ertesi güne geçmiş oluyor ve fixture'ın "bugün"ü uygulamanın
/// "bugün"üne düşmüyordu: sıralama kartı 0 kişi çizdi, oturum geçmişinde
/// "Bugün" satırı hiç oluşmadı.
///
/// Kusur 2026-08-18 23:02 UTC koşumunda ortaya çıktı; v70'in CI'ı 17:12 UTC'de
/// koştuğu için aynı kod aylarca yeşil göründü. Yani kapı yeşil DEĞİLDİ,
/// sadece doğru saatte koşuyordu.
///
/// Bu dosya kusuru **duvar saatinden bağımsız** sabitler: `todaySecondsByUser`
/// enjekte edilebilir bir `today` alır, biz de gün sınırının iki yakasını
/// açıkça ölçeriz. Fixture'ları düzeltmek kusuru kapatır; bu test onun bir daha
/// açılmadığını söyler.
void main() {
  group('WP-740 gün anahtarı sözleşmesi', () {
    // 18 Ağustos 2026, 23:02 UTC — CI'ın gerçekten kırmızı düştüğü an.
    final ciInstant = DateTime.utc(2026, 8, 18, 23, 2);

    test('UTC gecesi İstanbul için ERTESİ gündür', () {
      expect(istanbulDay(ciInstant), DateTime(2026, 8, 19));
      expect(
        DateTime(ciInstant.year, ciInstant.month, ciInstant.day),
        DateTime(2026, 8, 18),
        reason: 'kurulum: koşucunun yerel günü ile İstanbul günü ayrışıyor',
      );
    });

    test('cihaz gününe kurulan fixture o saatte GÖRÜNMEZ', () {
      // Eski fixture'ın yaptığı: gün anahtarı `DateTime.now()`dan.
      final deviceDayStats = [
        DailyStat(userId: 'u1', day: DateTime(2026, 8, 18), seconds: 3600),
        DailyStat(userId: 'u2', day: DateTime(2026, 8, 18), seconds: 1800),
      ];
      expect(
        todaySecondsByUser(deviceDayStats, today: ciInstant),
        isEmpty,
        reason: 'kart tam da bu yüzden "0 kişi çizdi" diyordu',
      );
    });

    test('İstanbul gününe kurulan fixture GÖRÜNÜR', () {
      final istanbulDayStats = [
        for (final stat in const [('u1', 3600), ('u2', 1800)])
          DailyStat(
            userId: stat.$1,
            day: istanbulDay(ciInstant),
            seconds: stat.$2,
          ),
      ];
      expect(todaySecondsByUser(istanbulDayStats, today: ciInstant), {
        'u1': 3600,
        'u2': 1800,
      });
    });

    test('gündüz iki tanım çakışır — kusur bu yüzden gizlenebiliyordu', () {
      // v70 CI'ı 17:12 UTC'de koştu: o saatte İstanbul da aynı gündeydi, yanlış
      // fixture yeşil geçti. "Kapı yeşildi" tek başına kanıt değildir; aynı kod
      // altı saat sonra kırmızıya düşüyordu.
      final daytimeInstant = DateTime.utc(2026, 8, 18, 17, 12);
      expect(istanbulDay(daytimeInstant), DateTime(2026, 8, 18));

      final deviceDayStats = [
        DailyStat(userId: 'u1', day: DateTime(2026, 8, 18), seconds: 3600),
      ];
      expect(
        todaySecondsByUser(deviceDayStats, today: daytimeInstant),
        {'u1': 3600},
        reason: 'aynı yanlış fixture gündüz koşumunda sorunsuz görünüyor',
      );
    });
  });
}
