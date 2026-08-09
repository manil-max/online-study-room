// WP-612 — `docs/denetim/DENETIM-istatistik.md` K1/K2/K3.
//
// 🔴 Bu dosyanın varlık sebebi, mevcut kapının NEDEN ölçmediğidir.
// `a11y_and_period_nav_wp554_test.dart` gezinilmiş dönemin `to`sunu HAM
// değeriyle doğruluyordu (`expect(to, thisWeek - 1ms)`) — yani "uygulama =
// uygulama". Tüketicilerin gördüğü değer ise ham `to` değil `dayOf(to)`dur ve
// hata tam orada doğuyordu. Aralığın kaç GÜN kapsadığına dair tek bir iddia
// yoktu, bu yüzden hata CI'da (TZ=UTC) aktifken bile yeşil görünüyordu.
//
// Burada ölçülen şey her zaman **tüketicinin gördüğü değerdir**.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/session_window.dart';
import 'package:online_study_room/core/stats/stats_period.dart';
import 'package:online_study_room/core/stats/study_stats.dart';
import 'package:online_study_room/core/utils/duration_format.dart';
import 'package:online_study_room/data/models/daily_stat.dart';
import 'package:online_study_room/data/models/goal_streak.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/models/user_study_summary.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/analytics_query_providers.dart';
import 'package:online_study_room/data/providers/goal_streak_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/data/repositories/goal_streak_repository.dart';
import 'package:online_study_room/features/home/widgets/leaderboard_card.dart';
import 'package:online_study_room/features/home/widgets/records_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// 🔴 SAAT DİLİMİ ENJEKSİYONU.
///
/// Hata cihazın saat dilimine bağlıdır ve sahibin makinesinde (UTC+3)
/// üretilemez; test koşucusunun kendi TZ'sine güvenen bir iddia ya hiçbir şey
/// ölçmez ya da makineye göre sonuç değiştirir.
///
/// Bu yardımcı ürünün ürettiği değerin **duvar saatini** alır ve onu [zone]
/// bölgesindeki bir cihazın üreteceği **ana** çevirir. Yani "aynı kod, başka
/// cihaz" durumu deterministik olarak canlandırılır. Dönen `TZDateTime` bir
/// gün anahtarı sayılmaz (`istanbul_calendar._isDayKey`), dolayısıyla ürünün
/// batıdaki cihazda gerçekten yaşayacağı çevrim uygulanır.
DateTime asDeviceIn(String zone, DateTime wall) {
  final loc = tz.getLocation(zone);
  return tz.TZDateTime(
    loc,
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
    wall.second,
    wall.millisecond,
    wall.microsecond,
  );
}

/// UTC+3'ün BATISINDAKİ cihazlar + kontrol grubu olarak İstanbul'un kendisi.
const _westOfIstanbul = <String>[
  'Etc/UTC', // CI koşucusu (TZ=UTC)
  'Europe/London',
  'Europe/Berlin',
  'America/New_York',
  'America/Los_Angeles',
];

StudySession _session(DateTime day, int seconds) => StudySession(
  id: 'ses-${day.toIso8601String()}',
  userId: 'u1',
  start: day,
  end: day,
  durationSeconds: seconds,
  source: StudySource.live,
  // Gün sunucu damgasından gelir: oturumun günü test koşucusunun TZ'sine
  // bağlı OLMASIN, ölçülen tek değişken `to` kalsın.
  recordedDay: day,
);

Future<AppLocalizations> _l10n() =>
    AppLocalizations.delegate.load(const Locale('tr'));

Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('tr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: SizedBox(width: 380, height: 520, child: child))),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(tz_data.initializeTimeZones);

  group('WP-612 K1 — gezinilmiş dönemin kapanışı GÜN ANAHTARIdır', () {
    // Çarşamba 5 Ağustos 2026, İstanbul 12:00. `now` UTC AN olarak verilir:
    // böylece dönemin kendisi koşucunun TZ'sinden bağımsız sabitlenir.
    final now = DateTime.utc(2026, 8, 5, 9);
    final lastWeek = const StatsPeriodSelection(
      period: StatsPeriod.week,
    ).shifted(-1);

    test('`to` gün anahtarıdır — `dayOf` ikinci kez ÇEVİRMEZ', () {
      final (from, to) = lastWeek.range(now: now);
      expect(from, DateTime(2026, 7, 27), reason: 'geçen haftanın Pazartesi\'si');
      expect(
        to,
        DateTime(2026, 8, 2),
        reason: 'kapanış dönemin son GÜNÜ (Pazar), "son anı" değil',
      );
      // 🔴 Asıl sözleşme: `dayOf` idempotent olsun. Eski değerde (23:59:59.999)
      // bu iddia HER makinede kırmızıdır — hatayı UTC+3'te de görünür kılan
      // budur.
      expect(
        dayOf(to),
        to,
        reason: 'anahtar olmayan kapanış İstanbul\'a çevrilir ve gün kayar',
      );
    });

    test('batıdaki HER cihazda pencere 7 gün — 8 değil', () {
      final (from, to) = lastWeek.range(now: now);
      for (final zone in [..._westOfIstanbul, 'Europe/Istanbul']) {
        final deviceFrom = asDeviceIn(zone, from);
        final deviceTo = asDeviceIn(zone, to);
        expect(dayOf(deviceTo), DateTime(2026, 8, 2), reason: zone);
        // `analytics_query_providers.dart:45` ve `dailyAverageSeconds`
        // paydasının kullandığı sayının ta kendisi.
        expect(
          dayOf(deviceTo).difference(dayOf(deviceFrom)).inDays + 1,
          7,
          reason: '$zone: "geçen hafta" 8 gün olmamalı',
        );
      }
    });

    test('bu haftanın Pazartesi\'si geçen haftanın hanesine yazılmaz', () {
      final (from, to) = lastWeek.range(now: now);
      final sessions = <StudySession>[
        for (var i = 0; i < 7; i++)
          _session(DateTime(2026, 7, 27).add(Duration(days: i)), 3600),
        // Bu haftanın Pazartesi'si — aralığın DIŞINDA olmalı.
        _session(DateTime(2026, 8, 3), 7200),
      ];

      for (final zone in [..._westOfIstanbul, 'Europe/Istanbul']) {
        final deviceFrom = asDeviceIn(zone, from);
        final deviceTo = asDeviceIn(zone, to);
        final picked = inRange(sessions, deviceFrom, deviceTo).toList();
        expect(picked.length, 7, reason: '$zone: 8 gün toplanmış');
        expect(
          picked.any((s) => s.day == DateTime(2026, 8, 3)),
          isFalse,
          reason: '$zone: bu haftanın Pazartesi\'si geçen haftaya sızdı',
        );
        expect(totalSeconds(picked), 7 * 3600, reason: zone);
        // Payda da 7: hatalı hâlde (25200 + 7200) / 8 = 4050 çıkıyordu.
        expect(
          dailyAverageSeconds(sessions, deviceFrom, deviceTo),
          3600,
          reason: '$zone: günlük ortalama paydası şişmiş',
        );
      }
    });

    test('ay ve yıl da gün anahtarıyla kapanır', () {
      final (mFrom, mTo) = const StatsPeriodSelection(
        period: StatsPeriod.month,
      ).shifted(-1).range(now: now);
      expect(mFrom, DateTime(2026, 7, 1));
      expect(mTo, DateTime(2026, 7, 31));

      final (yFrom, yTo) = const StatsPeriodSelection(
        period: StatsPeriod.year,
      ).shifted(-1).range(now: now);
      expect(yFrom, DateTime(2025, 1, 1));
      expect(yTo, DateTime(2025, 12, 31));

      for (final zone in _westOfIstanbul) {
        expect(dayOf(asDeviceIn(zone, mTo)), DateTime(2026, 7, 31), reason: zone);
        expect(dayOf(asDeviceIn(zone, yTo)), DateTime(2025, 12, 31), reason: zone);
      }
    });

    test('UTC+3\'te davranış DEĞİŞMEDİ, batıda DÜZELDİ (iki yönlü iddia)', () {
      final (_, to) = lastWeek.range(now: now);
      // Eski üretim değeri: dönemin son "anı".
      final legacy = DateTime(2026, 8, 3).subtract(const Duration(milliseconds: 1));

      // İstanbul cihazda eski ve yeni aynı güne indirgenir → regresyon yok.
      expect(dayOf(asDeviceIn('Europe/Istanbul', legacy)), DateTime(2026, 8, 2));
      expect(dayOf(asDeviceIn('Europe/Istanbul', to)), DateTime(2026, 8, 2));

      // Batıda eski değer bir gün ileri kayıyordu; düzeltmenin tüm gerekçesi bu.
      expect(
        dayOf(asDeviceIn('Etc/UTC', legacy)),
        DateTime(2026, 8, 3),
        reason: 'kök neden belgesi: yerel 23:59:59.999 İstanbul\'da ertesi gün',
      );
      expect(dayOf(asDeviceIn('Etc/UTC', to)), DateTime(2026, 8, 2));
    });
  });

  group('WP-612 K2 — ana ekran "Rekorlar" kartı kapsamını SÖYLER', () {
    final me = Profile(
      id: 'u1',
      displayName: 'Sahip',
      createdAt: DateTime(2025, 1, 1),
    );

    // Sıcak pencere: 90 gün × 1 saat = 90 saat. Gerçek ömür ise 400 saat.
    List<StudySession> hotSessions() => [
      for (var i = 0; i < 90; i++)
        _session(DateTime(2026, 8, 5).subtract(Duration(days: i)), 3600),
    ];

    Future<void> pumpCard(
      WidgetTester tester, {
      required AsyncValue<UserStudySummary> summary,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(me)),
            userSessionsProvider.overrideWith(
              (ref) => Stream.value(hotSessions()),
            ),
            userStudySummaryProvider.overrideWith(
              (ref) => summary.when(
                data: (v) => Future<UserStudySummary>.value(v),
                loading: () => Completer<UserStudySummary>().future,
                error: (e, s) => Future<UserStudySummary>.error(e, s),
              ),
            ),
            userSubjectsProvider.overrideWith(
              (ref) => Stream.value(const <Subject>[]),
            ),
          ],
          child: _wrap(const RecordsCard()),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('400 saatlik geçmiş "Toplam"da DÖRTTE BİR görünmez', (
      tester,
    ) async {
      await pumpCard(
        tester,
        summary: const AsyncValue.data(
          UserStudySummary(
            lifetimeSeconds: 400 * 3600,
            yearSeconds: 400 * 3600,
            hotWindowSeconds: 90 * 3600,
          ),
        ),
      );
      final l10n = await _l10n();

      // Toplam = ömür boyu (400 sa), 90 saatlik pencere değil.
      expect(find.text(formatHuman(400 * 3600)), findsOneWidget);
      expect(
        find.text(formatHuman(90 * 3600)),
        findsNothing,
        reason: 'sıcak pencere toplamı "Toplam" diye sunulmamalı',
      );

      // Pencereye bağlı kalan döşemeler kapsamlarını SÖYLER.
      final scope = ' · ${l10n.statsStreakGun(kUserSessionsHotWindowDays.toString())}';
      expect(find.text('${l10n.statsRekorSeri}$scope'), findsOneWidget);
      expect(find.text('${l10n.statsAktifGun}$scope'), findsOneWidget);
      // "Toplam" artık pencereyle sınırlı DEĞİL → ona etiket asılmaz.
      expect(find.text(l10n.statsToplam), findsOneWidget);
    });

    testWidgets('veri zaten pencereye sığıyorsa YANLIŞ uyarı asılmaz', (
      tester,
    ) async {
      await pumpCard(
        tester,
        summary: const AsyncValue.data(
          UserStudySummary(
            lifetimeSeconds: 90 * 3600,
            yearSeconds: 90 * 3600,
            hotWindowSeconds: 90 * 3600,
          ),
        ),
      );
      final l10n = await _l10n();

      expect(find.text(l10n.statsRekorSeri), findsOneWidget);
      expect(find.text(l10n.statsAktifGun), findsOneWidget);
      // NOT: "90 gün" metni DEĞERLERDE zaten geçiyor (90 aktif gün, 90 günlük
      // rekor seri). Ölçülen şey ETİKETE kapsam eklenip eklenmediğidir.
      final scope =
          ' · ${l10n.statsStreakGun(kUserSessionsHotWindowDays.toString())}';
      expect(
        find.text('${l10n.statsRekorSeri}$scope'),
        findsNothing,
        reason: 'doğru veriye yanlış kapsam uyarısı da bir yalandır (WP-585)',
      );
      expect(find.text('${l10n.statsAktifGun}$scope'), findsNothing);
      expect(find.text('${l10n.statsToplam}$scope'), findsNothing);
    });
  });

  group('WP-612 K3 — ana ekranda TEK grup-serisi motoru', () {
    final me = Profile(
      id: 'u1',
      displayName: 'Sahip',
      createdAt: DateTime(2025, 1, 1),
    );
    final group = StudyGroup(
      id: 'g-1',
      name: 'Odak Grubu',
      inviteCode: 'ABC123',
      createdBy: me.id,
      createdAt: DateTime(2025, 1, 1),
      dailyGoalMinutes: 60,
    );

    testWidgets('"Sıralama" kartı sunucu projeksiyonunu çizer, kendi hesabını değil', (
      tester,
    ) async {
      // Eski motorun (`currentStreak`, grace'siz) üreteceği seri: bugün dâhil
      // üst üste 3 gün hedef tutulmuş.
      final today = dayOf(DateTime.now());
      final stats = <DailyStat>[
        for (var i = 0; i < 3; i++)
          DailyStat(
            userId: me.id,
            day: today.subtract(Duration(days: i)),
            seconds: 3600,
          ),
      ];
      expect(
        currentStreak(const [], 3600, totals: groupDayTotals(stats)),
        3,
        reason: 'kurulum bozuk: eski motor 3 vermiyor, iddia bir şey ölçmez',
      );

      // Kanonik motor (sunucu) grace ile 9 diyor. İkisi FARKLI olmalı ki
      // "hangisi çiziliyor" sorusu yanıtlanabilsin.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(me)),
            userGroupProvider.overrideWithValue(AsyncValue.data(group)),
            groupDailyStatsProvider.overrideWith((ref) => Stream.value(stats)),
            groupMembersProvider.overrideWith((ref) => Stream.value([me])),
            groupAlphaScoresProvider.overrideWith(
              (ref) async => const <String, int>{},
            ),
            goalStreakRepositoryProvider.overrideWithValue(
              const _FixedStreakRepository(9),
            ),
          ],
          child: _wrap(const LeaderboardCard()),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.text('9'),
        findsOneWidget,
        reason: 'kanonik (grace\'li) sunucu serisi çizilmeli',
      );
      expect(
        find.text('3'),
        findsNothing,
        reason: 'grace\'siz eski motor hâlâ ekranda: iki motor yan yana',
      );
    });
  });
}

/// Sabit seri döndüren sahte depo: ölçülen şey "ekrandaki sayı hangi motordan
/// geliyor", o yüzden değer eski motorunkinden bilerek farklıdır.
class _FixedStreakRepository implements GoalStreakRepository {
  const _FixedStreakRepository(this.streak);

  final int streak;

  GoalStreakProjection _p(GoalStreakScope scope) => GoalStreakProjection(
    scope: scope,
    asOfDay: DateTime.utc(2026, 8, 5),
    currentStreak: streak,
    completionCount: streak,
    state: GoalStreakState.completedToday,
    sourceVersion: 'test',
  );

  @override
  Stream<GoalStreakProjection> watchProjection(
    GoalStreakScope scope, {
    DateTime? asOfDay,
  }) => Stream.value(_p(scope));

  @override
  Future<GoalStreakProjection> readProjection(
    GoalStreakScope scope, {
    DateTime? asOfDay,
  }) async => _p(scope);
}
