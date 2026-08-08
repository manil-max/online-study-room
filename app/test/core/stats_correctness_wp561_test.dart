import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/istanbul_calendar.dart';
import 'package:online_study_room/core/stats/stats_period.dart';
import 'package:online_study_room/core/stats/study_stats.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/features/stats/analytics/analytics_period.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// WP-561 — "ne kadar çalıştığımı doğru göster" doğruluk sözleşmeleri.
///
/// 🔴 Girdiler bilerek **UTC** damgasıdır: hem CI (UTC) hem yerel makinede
/// (UTC+3) aynı sonucu üretirler. Cihaz zaman dilimi test sürecinde
/// değiştirilemediği için, "cihaz offset'i" sınıfındaki hatalar offset'i
/// **açıkça alan** kardeş fonksiyon [calendarDayInTimeZone] üzerinden
/// kanıtlanır — [istanbulDay] ile aynı normalizasyon çekirdeğini kullanır.
bool _tzReady = false;
void _ensureTz() {
  if (_tzReady) return;
  tz_data.initializeTimeZones();
  _tzReady = true;
}

DateTime _ist(int y, int m, int d, [int h = 12, int min = 0]) {
  _ensureTz();
  return tz.TZDateTime(tz.getLocation('Europe/Istanbul'), y, m, d, h, min);
}

StudySession _s(DateTime start, int seconds) => StudySession(
  id: 's-${start.toIso8601String()}',
  userId: 'u1',
  start: start,
  end: start.add(Duration(seconds: seconds)),
  durationSeconds: seconds,
  source: StudySource.live,
);

void main() {
  group('WP-561 #2: gün anahtarı idempotenttir', () {
    // Anahtar (`DateTime(y,m,d)`) cihazın YEREL gece yarısıdır. Kod bu anahtarı
    // sürekli tekrar dönüştürüyor (`dayOf(dayOf(x))`, `inRange`, `startOfWeek →
    // range → inRange`). Dönüşüm idempotent değilse tüm pencereler bir gün
    // kayar.
    final samples = <DateTime>[
      DateTime.utc(2026, 8, 7, 20, 0), // İstanbul 23:00
      DateTime.utc(2026, 8, 7, 21, 30), // İstanbul ertesi gün 00:30
      DateTime.utc(2026, 1, 1, 0, 0),
      DateTime.utc(2025, 12, 31, 22, 0),
      DateTime.utc(2026, 6, 15, 12, 0),
    ];

    test('istanbulDay(istanbulDay(x)) == istanbulDay(x)', () {
      for (final x in samples) {
        final once = istanbulDay(x);
        expect(istanbulDay(once), once, reason: '$x');
        expect(istanbulDay(istanbulDay(once)), once, reason: '$x (3. tur)');
      }
    });

    test('dayOf çift uygulandığında pencere genişlemez', () {
      // `class_stats_view.dart:131` gibi açık çift `dayOf` çağrıları vardı.
      for (final x in samples) {
        expect(dayOf(dayOf(x)), dayOf(x));
        expect(startOfWeek(startOfWeek(x)), startOfWeek(x));
        expect(startOfMonth(startOfMonth(x)), startOfMonth(x));
        expect(startOfYear(startOfYear(x)), startOfYear(x));
      }
    });

    // 🔴 SABOTAJ TANIĞI: bu zonelar cihazın (UTC+3 yerel / UTC CI) offset'inin
    // BATISINDA. Idempotens koruması kaldırılırsa anahtar bir gün geri kayar —
    // aynı hata, UTC+4 ve doğusundaki cihazlarda `istanbulDay` için oluyor.
    for (final zone in const [
      'America/New_York', // UTC-4/-5
      'Pacific/Honolulu', // UTC-10
      'Etc/GMT+11', // UTC-11
    ]) {
      test('calendarDayInTimeZone idempotent — $zone', () {
        _ensureTz();
        for (final x in samples) {
          final once = calendarDayInTimeZone(x, zone);
          expect(
            calendarDayInTimeZone(once, zone),
            once,
            reason: '$zone / $x — anahtar tekrar çevrilince kaydı',
          );
        }
      });
    }

    test('gerçek anlar (UTC damgası) hâlâ çevrilir — koruma körleştirmez', () {
      // Kapı yalnız "zaten anahtar" olan yerel değerlere açılır; UTC damgası
      // (DB'den gelen `DateTime.parse('…Z')`) her zaman çevrilir.
      expect(istanbulDay(DateTime.utc(2026, 8, 7, 21, 30)), DateTime(2026, 8, 8));
      expect(istanbulDay(DateTime.utc(2026, 8, 7, 20, 59)), DateTime(2026, 8, 7));
      // Gece yarısındaki UTC anı da çevrilir (03:00 İstanbul, aynı gün).
      expect(istanbulDay(DateTime.utc(2026, 8, 7, 0, 0)), DateTime(2026, 8, 7));
    });

    test('anahtar düz DateTime tipindedir (TZDateTime sızmaz)', () {
      // `istanbulNow()` TZDateTime verir; TZDateTime.hashCode düz DateTime ile
      // eşleşmediği için gün→saniye haritalarında sessizce ıskalanırdı.
      final key = dayOf(istanbulNow());
      expect(key.runtimeType, DateTime);
      expect(<DateTime, int>{key: 1}[DateTime(key.year, key.month, key.day)], 1);
    });

    test('istanbulDayStart gerçek İstanbul 00:00 anını verir', () {
      final start = istanbulDayStart(DateTime.utc(2026, 8, 7, 22, 30));
      // İstanbul 8 Ağustos 01:30 → günün başı 8 Ağustos 00:00 IST = 7 Ağustos
      // 21:00 UTC.
      expect(
        start.microsecondsSinceEpoch,
        DateTime.utc(2026, 8, 7, 21).microsecondsSinceEpoch,
      );
    });
  });

  group('WP-561 #3: startOfMonth / startOfYear İstanbul sözleşmesi', () {
    // 🔴 Eski testler totolojikti (`expect(from, startOfYear(now))` =
    // "uygulama = uygulama"). Aşağıdaki beklentiler ELLE hesaplanmış sabit
    // tarihlerdir.
    test('Almanya (UTC+2) 31 Ağustos 23:30 = İstanbul 1 Eylül 00:30', () {
      // 31 Ağustos 21:30 UTC → İstanbul 1 Eylül 00:30.
      final instant = DateTime.utc(2026, 8, 31, 21, 30);
      expect(dayOf(instant), DateTime(2026, 9, 1));
      expect(
        startOfMonth(instant),
        DateTime(2026, 9, 1),
        reason: 'ham t.month 1 Ağustos derdi → "Ay" dönemi 32 gün olurdu',
      );
      // Aynı ekranda "Bugün" 1 Eylül'ken dönem 1 Ağustos'ta başlayamaz.
      final span = dayOf(instant).difference(startOfMonth(instant)).inDays + 1;
      expect(span, 1);
    });

    test('yılbaşı: 31 Aralık 22:00 UTC İstanbul\'da yeni yıldır', () {
      final instant = DateTime.utc(2025, 12, 31, 22, 0);
      expect(dayOf(instant), DateTime(2026, 1, 1));
      expect(startOfYear(instant), DateTime(2026, 1, 1));
      expect(startOfMonth(instant), DateTime(2026, 1, 1));
    });

    test('gün içi normal anlarda davranış değişmez', () {
      final instant = DateTime.utc(2026, 7, 18, 12, 30);
      expect(startOfMonth(instant), DateTime(2026, 7, 1));
      expect(startOfYear(instant), DateTime(2026, 1, 1));
    });

    test('StatsPeriodSelection: ay/yıl sınırları İstanbul tabanlıdır', () {
      final instant = DateTime.utc(2026, 8, 31, 21, 30); // İstanbul 1 Eylül
      final month = const StatsPeriodSelection(period: StatsPeriod.month);
      expect(month.range(now: instant).$1, DateTime(2026, 9, 1));
      // Bir önceki ay = Ağustos (İstanbul takvimi), Temmuz değil.
      expect(month.shifted(-1).range(now: instant).$1, DateTime(2026, 8, 1));

      final year = const StatsPeriodSelection(period: StatsPeriod.year);
      final ny = DateTime.utc(2025, 12, 31, 22); // İstanbul 1 Ocak 2026
      expect(year.range(now: ny).$1, DateTime(2026, 1, 1));
      expect(year.shifted(-1).range(now: ny).$1, DateTime(2025, 1, 1));
    });
  });

  group('WP-561 #4: "Tümü"/"Yıl" günlük ortalama paydası', () {
    test('payda takvim gününden değil VERİ UFKUNDAN gelir', () {
      final now = DateTime.utc(2026, 8, 8, 9);
      // 90 günlük sıcak pencerede 300 saat (günde ~3sa20dk).
      final hotStart = dayOf(now).subtract(const Duration(days: 89));
      final totals = <DateTime, int>{
        for (var i = 0; i < 90; i++)
          hotStart.add(Duration(days: i)): 12000, // 90 * 12000 = 300 sa
      };
      final sessions = [
        for (var i = 0; i < 90; i++)
          _s(_ist(2026, 5, 11, 10).add(Duration(days: i)), 12000),
      ];

      // "Tümü": from = DateTime(2000) → ~9718 takvim günü.
      final (allFrom, allTo) = const StatsPeriodSelection(
        period: StatsPeriod.all,
      ).range(now: now);
      final naive = dailyAverageSeconds(sessions, allFrom, allTo);
      expect(
        naive,
        lessThan(120),
        reason: 'eski hata: 300 sa toplamın yanında ~37 sn ortalama',
      );

      final w = averageWindow(
        periodFrom: allFrom,
        hotWindowStart: hotStart,
        dayTotals: totals,
      );
      expect(w.hotLimited, isTrue);
      expect(w.from, hotStart);
      expect(dailyAverageSeconds(sessions, w.from, allTo).round(), 12000);
    });

    test('sıcak pencereye sığan dönemlerde payda değişmez', () {
      final now = DateTime.utc(2026, 8, 8, 9);
      final hotStart = dayOf(now).subtract(const Duration(days: 89));
      final (weekFrom, _) = const StatsPeriodSelection(
        period: StatsPeriod.week,
      ).range(now: now);
      final w = averageWindow(
        periodFrom: weekFrom,
        hotWindowStart: hotStart,
        dayTotals: {dayOf(now): 3600},
      );
      expect(w.hotLimited, isFalse);
      expect(w.from, dayOf(weekFrom));
    });

    test('kullanıcı sıcak pencereden yeniyse ilk veri gününden sayılır', () {
      final now = DateTime.utc(2026, 8, 8, 9);
      final hotStart = dayOf(now).subtract(const Duration(days: 89));
      final firstDay = dayOf(now).subtract(const Duration(days: 9));
      final w = averageWindow(
        periodFrom: DateTime(2000),
        hotWindowStart: hotStart,
        dayTotals: {
          for (var i = 0; i < 10; i++)
            firstDay.add(Duration(days: i)): 3600,
          // 0 saniyelik gün ufku geriye çekmemeli.
          hotStart: 0,
        },
      );
      expect(w.from, firstDay);
      expect(w.hotLimited, isTrue);
    });
  });

  group('WP-561 #6: AnalyticsPeriod gezinmeyi taşır', () {
    test('offset == / hashCode\'a dâhildir (family cache çakışmaz)', () {
      const a = AnalyticsPeriod(AnalyticsPeriodKind.week);
      const b = AnalyticsPeriod(AnalyticsPeriodKind.week, offset: -1);
      expect(a == b, isFalse);
      // Family provider cache'i anahtar olarak kullanır: iki dönem AYNI
      // kovaya düşmemeli.
      final cache = <AnalyticsPeriod, String>{a: 'bu hafta', b: 'geçen hafta'};
      expect(cache.length, 2);
      expect(cache[a], 'bu hafta');
      expect(cache[b], 'geçen hafta');
      expect(a, const AnalyticsPeriod(AnalyticsPeriodKind.week));
    });

    test('"geçen hafta" başlığının altında geçen haftanın aralığı olur', () {
      final now = DateTime.utc(2026, 8, 5, 9); // Çarşamba (İstanbul 12:00)
      final thisWeek = const AnalyticsPeriod(AnalyticsPeriodKind.week);
      final lastWeek = const AnalyticsPeriod(
        AnalyticsPeriodKind.week,
        offset: -1,
      );
      expect(thisWeek.range(now: now).$1, DateTime(2026, 8, 3)); // Pazartesi
      expect(lastWeek.range(now: now).$1, DateTime(2026, 7, 27));
      expect(
        lastWeek.range(now: now).$2.isBefore(DateTime(2026, 8, 3)),
        isTrue,
        reason: 'geçmiş dönem KAPALIDIR; "to" şimdi değil dönemin son anıdır',
      );
    });

    test('seçimden köprü offset\'i taşır, gezinilemeyen dönemde sıfırlar', () {
      final sel = const StatsPeriodSelection(
        period: StatsPeriod.month,
      ).shifted(-2);
      expect(analyticsPeriodFromSelection(sel).offset, -2);
      final today = const StatsPeriodSelection(
        period: StatsPeriod.today,
      ).copyWith(offset: -3);
      expect(analyticsPeriodFromSelection(today).offset, 0);
    });
  });

  group('WP-561 #7: bu hafta vs geçen hafta — kısmî/kısmî', () {
    test('geçen hafta aynı gün+saate kırpılır', () {
      // 2026-08-04 Salı, İstanbul 12:00.
      final now = _ist(2026, 8, 4, 12);
      final sessions = [
        // Bu hafta: Pzt + Salı sabahı = 2 sa.
        _s(_ist(2026, 8, 3, 10), 3600),
        _s(_ist(2026, 8, 4, 10), 3600),
        // Geçen hafta Pzt + Salı sabahı (kesim ÖNCESİ) = 2 sa.
        _s(_ist(2026, 7, 27, 10), 3600),
        _s(_ist(2026, 7, 28, 10), 3600),
        // Geçen haftanın kalanı (kesim SONRASI) — kıyasa girmemeli.
        _s(_ist(2026, 7, 28, 20), 3600),
        _s(_ist(2026, 7, 30, 10), 7200),
        _s(_ist(2026, 8, 1, 10), 7200),
      ];
      final w = weekOverWeekSeconds(sessions, now: now);
      expect(w.thisWeek, 7200);
      expect(
        w.lastWeek,
        7200,
        reason:
            'eski davranış tam haftayı (25200 sn) alıp Salı günü kullanıcıya '
            'her zaman "kötüye gidiyorsun" gösteriyordu',
      );
      expect(w.thisWeek - w.lastWeek, 0);
    });

    test('gerçek düşüş hâlâ düşüş görünür', () {
      final now = _ist(2026, 8, 4, 12);
      final sessions = [
        _s(_ist(2026, 8, 3, 10), 600),
        _s(_ist(2026, 7, 27, 10), 3600),
      ];
      final w = weekOverWeekSeconds(sessions, now: now);
      expect(w.thisWeek, 600);
      expect(w.lastWeek, 3600);
    });
  });

  group('WP-561 #8: longestStudyStreak 0 saniyelik günü saymaz', () {
    test('sıfır gün seriyi köprülemez', () {
      final d = DateTime(2026, 8, 1);
      final totals = <DateTime, int>{
        d: 3600,
        d.add(const Duration(days: 1)): 0, // sıfırlanmış/silinmiş gün
        d.add(const Duration(days: 2)): 3600,
      };
      expect(longestStudyStreak(const [], totals: totals), 1);
      expect(activeDayCount(totals), 2);
    });

    test('tümü sıfırsa seri 0', () {
      expect(
        longestStudyStreak(
          const [],
          totals: {DateTime(2026, 8, 1): 0, DateTime(2026, 8, 2): 0},
        ),
        0,
      );
    });

    test('gerçek seri bozulmaz', () {
      final d = DateTime(2026, 8, 1);
      expect(
        longestStudyStreak(
          const [],
          totals: {
            for (var i = 0; i < 4; i++) d.add(Duration(days: i)): 60,
          },
        ),
        4,
      );
    });
  });
}
