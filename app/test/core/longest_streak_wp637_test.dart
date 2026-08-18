import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/study_stats.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/features/stats/widgets/study_records.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// WP-637 — "En uzun seri" YANLIŞ KURALA bağlıydı.
///
/// Sahip kararı (2026-08-10): Rekorlar bölümündeki "en uzun seri" *"o gün en
/// az 1 saniye kayıt var mı"* ile sayılıyordu. Sahip reddetti:
/// *"kim koydu onu, ne anlamı var — en uzun seri demişsin, onu normal günlük
/// seriye bağla o zaman. aktif gün var zaten ayrı olarak, onu saymasına gerek
/// yok."*
///
/// Ürünün günlük seri kuralı TEK yerdedir: [currentStreak]
/// (`lib/core/stats/study_stats.dart`) — bir gün seriye ancak o günün toplamı
/// günlük hedefe ULAŞIRSA girer. Bu dosya rekorun aynı eşiğe bağlandığını,
/// "Aktif gün" ölçüsünün ise AYRI kaldığını sözleşmeye bağlar.
///
/// 🔴 Ters iddialar bilerek yazılmıştır: "hep 0 döndür" (§2), "eskisi gibi her
/// çalışılan günü say" (§1, §3) ve "hedefi yok say" (§4) çözümlerinin hiçbiri
/// bu dosyadan geçemez.
tz.Location _berlin() {
  tz_data.initializeTimeZones();
  return tz.getLocation('Europe/Berlin');
}

const int _goal = 3600; // 1 saat — testlerin ortak günlük hedefi.

StudySession _s(DateTime start, int seconds) => StudySession(
  id: 's-${start.toIso8601String()}-$seconds',
  userId: 'u1',
  start: start,
  end: start.add(Duration(seconds: seconds)),
  durationSeconds: seconds,
  source: StudySource.live,
);

/// Gün → saniye haritası: [seconds] listesi 1 Mayıs'tan itibaren ARDIŞIK
/// günlere yazılır (takvimde boşluk yok — kıran tek şey hedef olsun).
Map<DateTime, int> _run(List<int> seconds) {
  final base = DateTime(2026, 5, 1);
  return {
    for (var i = 0; i < seconds.length; i++)
      base.add(Duration(days: i)): seconds[i],
  };
}

Future<AppLocalizations> _l10n() =>
    AppLocalizations.delegate.load(const Locale('tr'));

Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('tr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Center(child: SizedBox(width: 380, height: 520, child: child)),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(tz_data.initializeTimeZones);

  group('WP-637 §1: hedefi TUTTURMAYAN gün seriyi KIRAR', () {
    // 🔴 WP-739: hedefin altında kalan gün sayısı 1'den 2'ye çıkarıldı. Cetvel
    // değişti — ürünün günlük seri kuralı artık TEK kaçırmayı affediyor
    // (`goal_streak_rule.dart`), yani tek eksik gün bloğu bölmez. Bu dosyanın
    // ölçtüğü iddia aynı kaldı: seriye giren gün "≥ 1 sn" değil, "hedefi
    // tutturan" gündür.
    test('ortadaki iki eksik gün 6 günlük seriyi ikiye böler', () {
      // Altı ARDIŞIK gün; ortadaki iki gün çalışılmış ama hedefin altında.
      // Eski kural ("≥ 1 sn") 6 derdi — kırılma noktası tam burasıdır.
      final totals = _run([_goal, _goal, 600, 600, _goal, _goal]);
      expect(
        longestStudyStreak(const [], totals: totals, goalSeconds: _goal),
        2,
        reason: '3–4 Mayıs hedefi tutturmadı; 6 günlük blok 2 + 2 olur',
      );
    });

    test('🔴 "Aktif gün" AYRI ölçüdür — dokunulmadı', () {
      // Sahibin cümlesi: "aktif gün var zaten ayrı olarak". Aynı veride iki
      // sayı FARKLI olmalı; eşitlerse iki döşeme aynı şeyi anlatıyor demektir.
      final totals = _run([_goal, _goal, 600, 600, _goal, _goal]);
      expect(activeDayCount(totals), 6, reason: 'çalışılan gün sayısı 6');
      expect(
        longestStudyStreak(const [], totals: totals, goalSeconds: _goal),
        isNot(activeDayCount(totals)),
      );
    });

    test('hiçbir gün hedefe ulaşmazsa rekor 0 (veri olsa bile)', () {
      final totals = _run([600, 900, 1200, 60]);
      expect(activeDayCount(totals), 4);
      expect(
        longestStudyStreak(const [], totals: totals, goalSeconds: _goal),
        0,
      );
    });

    test('oturum yolunda da (totals verilmeden) aynı kural işler', () {
      // UTC damgalı anlar: gün anahtarı koşucunun TZ'sinden bağımsız çıksın.
      final sessions = [
        _s(DateTime.utc(2026, 5, 1, 9), _goal),
        _s(DateTime.utc(2026, 5, 2, 9), _goal),
        _s(DateTime.utc(2026, 5, 3, 9), 600), // hedefin altında
        _s(DateTime.utc(2026, 5, 4, 9), 600), // hedefin altında (WP-739)
        _s(DateTime.utc(2026, 5, 5, 9), _goal),
      ];
      expect(longestStudyStreak(sessions, goalSeconds: _goal), 2);
    });
  });

  group('WP-637 §2: ters iddia — hedefi tutturan günler BİRLEŞİR', () {
    test('5 ardışık hedefli gün = 5 ("hep 0/1 döndür" geçemez)', () {
      final totals = _run([_goal, _goal, _goal, _goal, _goal]);
      expect(
        longestStudyStreak(const [], totals: totals, goalSeconds: _goal),
        5,
      );
    });

    test('hedefin ÜSTÜ de sayılır, en uzun blok kazanır (2 / 4 → 4)', () {
      // 🔴 WP-739: ayırıcı boşluk iki güne çıkarıldı; tek boş gün artık iki
      // bloğu BİRLEŞTİRİR ve ortada "en uzun blok" diye bir seçim kalmazdı.
      final totals = _run([
        _goal + 1, _goal * 3, 0, 0, //
        _goal, _goal + 60, _goal * 2, _goal, //
      ]);
      expect(
        longestStudyStreak(const [], totals: totals, goalSeconds: _goal),
        4,
      );
    });

    test('eşik ">" değil ">=": TAM hedef kadar çalışılan gün sayılır', () {
      final totals = _run([_goal, _goal, _goal]);
      expect(
        longestStudyStreak(const [], totals: totals, goalSeconds: _goal),
        3,
        reason: 'hedefe tam ulaşmak tutturmaktır (currentStreak ile aynı eşik)',
      );
    });
  });

  group('WP-637 §3: eşik currentStreak ile AYNI kaynaktır', () {
    // "Rekor" ile "güncel seri" aynı kuralı kullanmazsa kullanıcı aynı ekranda
    // iki farklı gerçek görür (WP-253'ün ateş ikonu vakası).
    test('güncel seri ile rekor aynı gün kümesinde aynı sayıyı verir', () {
      final today = DateTime(2026, 5, 5);
      final totals = _run([_goal, _goal, _goal, _goal, _goal]);
      expect(currentStreak(const [], _goal, today: today, totals: totals), 5);
      expect(
        longestStudyStreak(const [], totals: totals, goalSeconds: _goal),
        5,
      );
    });

    test('güncel seriyi kıran gün rekoru da kırar', () {
      final today = DateTime(2026, 5, 6);
      final totals = _run([_goal, _goal, 600, 600, _goal, _goal]);
      expect(
        currentStreak(const [], _goal, today: today, totals: totals),
        2,
        reason: 'kurulum: günlük seri motoru 3–4 Mayıs\'ta kırılıyor',
      );
      expect(
        longestStudyStreak(const [], totals: totals, goalSeconds: _goal),
        2,
      );
    });

    test('aynı veri, farklı hedef → farklı rekor (parametre GERÇEKTEN etkili)', () {
      // "Eskisi gibi say" çözümü bu iddiadan geçemez: iki çağrı aynı sayıyı
      // veremez.
      final totals = _run([_goal, _goal, 600, 600, _goal, _goal]);
      expect(longestStudyStreak(const [], totals: totals, goalSeconds: 600), 6);
      expect(
        longestStudyStreak(const [], totals: totals, goalSeconds: _goal),
        2,
      );
    });
  });

  group('WP-637 §4: hedef yoksa seri hesaplanamaz', () {
    test('hedef 0/negatif → 0 (currentStreak ile aynı davranış)', () {
      final totals = _run([_goal, _goal, _goal]);
      expect(currentStreak(const [], 0, totals: totals), 0);
      expect(longestStudyStreak(const [], totals: totals, goalSeconds: 0), 0);
      expect(longestStudyStreak(const [], totals: totals, goalSeconds: -1), 0);
    });

    test('veri yoksa 0', () {
      expect(longestStudyStreak(const [], goalSeconds: _goal), 0);
      expect(
        longestStudyStreak(const [], totals: const {}, goalSeconds: _goal),
        0,
      );
    });
  });

  group('WP-637 §5: WP-636 (takvimsel ardışıklık) KORUNUR', () {
    test('DST: 71 saatlik boşluk hedefli günleri BİRLEŞTİRMEZ', () {
      // 🔴 WP-739: takvim farkı 2 artık affediliyor, o yüzden hatayı görünür
      // kılan boşluk 3 güne taşındı. Geçen SÜREye bakan bir uygulama 71 saati
      // `inDays = 2` sayıp yanlışlıkla birleştirir; takvim farkına bakan doğru
      // uygulama 3 der ve birleştirmez.
      final berlin = _berlin();
      final d29 = tz.TZDateTime(berlin, 2026, 3, 29);
      final d1 = tz.TZDateTime(berlin, 2026, 4, 1);
      expect(d1.difference(d29).inHours, 71, reason: 'kurulum doğrulaması');
      expect(
        longestStudyStreak(
          const [],
          totals: {d29: _goal, d1: _goal},
          goalSeconds: _goal,
        ),
        1,
      );
    });

    test('DST: 23 saatlik ARDIŞIK iki gün seriyi kırmaz', () {
      final berlin = _berlin();
      final d29 = tz.TZDateTime(berlin, 2026, 3, 29);
      final d30 = tz.TZDateTime(berlin, 2026, 3, 30);
      expect(d30.difference(d29).inHours, 23, reason: 'kurulum doğrulaması');
      expect(
        longestStudyStreak(
          const [],
          totals: {d29: _goal, d30: _goal},
          goalSeconds: _goal,
        ),
        2,
      );
    });

    test('aynı takvim gününün iki anahtarı TOPLANIR, boşluk sayılmaz', () {
      // Gün yarısı bir anahtarda, yarısı diğerinde duruyorsa hedef günün
      // TOPLAMINA uygulanır; yoksa hedefi tutturan bir gün "tutturmadı" olurdu.
      final totals = <DateTime, int>{
        DateTime(2026, 5, 1): 1800,
        DateTime.utc(2026, 5, 1): 1800,
        DateTime(2026, 5, 2): _goal,
      };
      expect(
        longestStudyStreak(const [], totals: totals, goalSeconds: _goal),
        2,
      );
    });
  });

  group('WP-637 §6: WP-561 (0 saniyelik gün) KORUNUR', () {
    test('sıfırlanmış günler seriyi köprülemez', () {
      // 🔴 WP-739: tek sıfır gün artık kuralen affediliyor; iddia iki ardışık
      // sıfır günle ölçülüyor. Ölçülen şey aynı: sıfır saniye "çalışıldı"
      // değildir, köprü kurmaz.
      final totals = _run([_goal, 0, 0, _goal]);
      expect(
        longestStudyStreak(const [], totals: totals, goalSeconds: _goal),
        1,
      );
      expect(activeDayCount(totals), 2);
    });
  });

  group('WP-637 §7: YÜZEY gerçekten hedefi geçiriyor', () {
    // 🔴 Saf fonksiyonu düzeltip çağıranı bağlamamak bu depoda tekrarlayan bir
    // hatadır ("bitmiş backend + bağlanmamış UI"). Ölçülen şey kullanıcının
    // Rekorlar kartında GÖRDÜĞÜ sayıdır.
    testWidgets('Rekor seri hedefe göre, Aktif gün ESKİ ölçüyle çizilir', (
      tester,
    ) async {
      final sessions = [
        for (final e in const [
          (1, 3600),
          (2, 3600),
          // 🔴 WP-739: iki ardışık eksik gün — tek eksik gün artık affediliyor.
          (3, 600), // hedefin altında → seriyi kırar, aktif günü kırmaz
          (4, 600),
          (5, 3600),
        ])
          _s(DateTime.utc(2026, 5, e.$1, 9), e.$2),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dailyGoalMinutesProvider.overrideWithValue(60), // 3600 sn
            userSubjectsProvider.overrideWith(
              (ref) => Stream.value(const <Subject>[]),
            ),
          ],
          child: _wrap(StudyRecords(sessions: sessions)),
        ),
      );
      await tester.pump();
      final l10n = await _l10n();

      expect(
        find.text(l10n.statsStreakGun('2')),
        findsOneWidget,
        reason: 'Rekor seri = hedefi tutturulan en uzun ardışık blok',
      );
      expect(
        find.text(l10n.statsStreakGun('5')),
        findsOneWidget,
        reason: 'Aktif gün 5 kalmalı — sahip onun ayrı kalmasını istedi',
      );
      expect(find.text(l10n.statsRekorSeri), findsOneWidget);
      expect(find.text(l10n.statsAktifGun), findsOneWidget);
    });
  });
}
