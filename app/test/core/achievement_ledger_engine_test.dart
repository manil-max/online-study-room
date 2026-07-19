import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/achievement_ledger_engine.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_achievement_repository.dart';

StudySession _session({
  required String id,
  required DateTime start,
  required int minutes,
  String userId = 'u1',
}) {
  final end = start.add(Duration(minutes: minutes));
  return StudySession(
    id: id,
    userId: userId,
    start: start,
    end: end,
    durationSeconds: minutes * 60,
    source: StudySource.live,
  );
}

void main() {
  group('AchievementLedgerEngine', () {
    test('sözlük 20 başarım içerir (çalışma+seri+grup+sosyal+gizli)', () {
      final dict = kAchievementDictV3();
      expect(dict.length, 21);
      expect(dict.where((e) => e.isSecret).length, 9);
      expect(dict.any((e) => e.id == 'marathon_total'), isTrue);
      expect(dict.any((e) => e.id == 'secret_404'), isTrue);
      // secret_1337 (1337 Elite) beta-v42'de tamamen silindi.
      expect(dict.any((e) => e.id == 'secret_1337'), isFalse);
      // Kademeli başarımlar 6 kademe.
      expect(dict.firstWhere((e) => e.id == 'marathon_total').maxTier, 6);
      final weeklyWolf = dict.firstWhere(
        (entry) => entry.id == 'alpha_wolf_weekly',
      );
      expect(
        weeklyWolf.tiers.map((tier) => tier.threshold),
        [1, 4, 12, 26, 52, 104],
      );
      expect(
        weeklyWolf.tiers.map((tier) => tier.xp),
        [2500, 6000, 15000, 30000, 60000, 120000],
      );
      expect(
        kAchievementMetricSourceVersions['alpha_wolf_weekly'],
        'weekly_alpha_verified_v1',
      );
    });

    test('steel_will kademe 1: 60 dk oturum → 50 XP', () {
      final engine = AchievementLedgerEngine();
      final start = DateTime.utc(2026, 6, 1, 10, 0);
      final result = engine.processEvent(
        userId: 'u1',
        eventType: 'session_completed',
        sessions: [_session(id: 's1', start: start, minutes: 60)],
        dailyGoalMinutes: 360,
      );
      expect(
        result.awarded.any(
          (a) => a.achievementId == 'steel_will' && a.tier == 1 && a.xp == 50,
        ),
        isTrue,
      );
      expect(result.totalXp, greaterThanOrEqualTo(50));
    });

    test('aynı event_key ikinci çağrıda çift XP vermez (idempotency)', () {
      final engine = AchievementLedgerEngine();
      final start = DateTime.utc(2026, 6, 1, 10, 0);
      final sessions = [_session(id: 's1', start: start, minutes: 120)];

      final first = engine.processEvent(
        userId: 'u1',
        eventType: 'session_completed',
        sessions: sessions,
        dailyGoalMinutes: 360,
      );
      final xpAfterFirst = first.totalXp;
      expect(first.awarded, isNotEmpty);

      final second = engine.processEvent(
        userId: 'u1',
        eventType: 'session_completed',
        sessions: sessions,
        dailyGoalMinutes: 360,
      );
      expect(second.awarded, isEmpty);
      expect(second.totalXp, xpAfterFirst);
      expect(
        engine.eventKeys.contains(ledgerEventKey('u1', 'steel_will', 1)),
        isTrue,
      );
      expect(
        engine.eventKeys.contains(ledgerEventKey('u1', 'steel_will', 2)),
        isTrue,
      );
      // tier 3 = 120 dk
      expect(
        engine.eventKeys.contains(ledgerEventKey('u1', 'steel_will', 3)),
        isTrue,
      );
    });

    test('secret_404: tam 404 dakika oturum ödül verir', () {
      final engine = AchievementLedgerEngine();
      final result = engine.processEvent(
        userId: 'u1',
        eventType: 'session_completed',
        sessions: [
          _session(
            id: 's404',
            start: DateTime.utc(2026, 6, 2, 8, 0),
            minutes: 404,
          ),
        ],
        dailyGoalMinutes: 360,
      );
      expect(
        result.awarded.any(
          (a) => a.achievementId == 'secret_404' && a.xp == 5000,
        ),
        isTrue,
      );
    });

    test('secret_pi: 194 dakika → 3147 XP', () {
      final engine = AchievementLedgerEngine();
      final result = engine.processEvent(
        userId: 'u1',
        eventType: 'manual_refresh',
        sessions: [
          _session(
            id: 'spi',
            start: DateTime.utc(2026, 6, 3, 9, 0),
            minutes: 194,
          ),
        ],
        dailyGoalMinutes: 120,
      );
      expect(
        result.awarded.any(
          (a) => a.achievementId == 'secret_pi' && a.xp == 3147,
        ),
        isTrue,
      );
    });

    test('marathon_total: 50 saat kümülatif → kademe 1', () {
      final engine = AchievementLedgerEngine();
      // 50 × 60 dk = 50 saat
      final sessions = [
        for (var i = 0; i < 50; i++)
          _session(
            id: 'm$i',
            start: DateTime.utc(2026, 1, 1).add(Duration(days: i)),
            minutes: 60,
          ),
      ];
      final result = engine.processEvent(
        userId: 'u1',
        eventType: 'session_completed',
        sessions: sessions,
        dailyGoalMinutes: 30,
      );
      expect(
        result.awarded.any(
          (a) =>
              a.achievementId == 'marathon_total' && a.tier == 1 && a.xp == 100,
        ),
        isTrue,
      );
    });

    test('crownRankForXp 6 kademe eşikleri 0/20k/75k/200k/500k/1M', () {
      expect(crownRankForXp(0), 'bronze_beginner');
      expect(crownRankForXp(19999), 'bronze_beginner');
      expect(crownRankForXp(20000), 'silver_learner');
      expect(crownRankForXp(75000), 'gold_achiever');
      expect(crownRankForXp(200000), 'diamond_owl');
      expect(crownRankForXp(500000), 'emerald_sage');
      expect(crownRankForXp(1000000), 'immortal_legend');
    });

    test('her tamamlanan saat 50 XP verir ve idempotenttir', () {
      final engine = AchievementLedgerEngine();
      // 2.5 saat → 2 tam saat → 100 XP saat ödülü (+ başarım kademeleri)
      final sessions = [
        _session(
          id: 'h1',
          start: DateTime.utc(2026, 6, 1, 10, 0),
          minutes: 150, // 2.5 saat → total_hours=2
        ),
      ];
      final first = engine.processEvent(
        userId: 'u1',
        eventType: 'session_completed',
        sessions: sessions,
        dailyGoalMinutes: 360,
      );
      expect(first.metrics['total_hours'], 2);
      // Saat XP: 2 × 50 = 100 (başarım kademeleri üstüne eklenebilir)
      expect(engine.totalXp, greaterThanOrEqualTo(100));
      final hourOnlyKeys = engine.eventKeys
          .where((k) => k.contains('study_hour_xp'))
          .toList();
      expect(hourOnlyKeys.length, 2);
      expect(kStudyHourXp, 50);

      final second = engine.processEvent(
        userId: 'u1',
        eventType: 'session_completed',
        sessions: sessions,
        dailyGoalMinutes: 360,
      );
      expect(second.totalXp, first.totalXp);
      expect(
        engine.eventKeys.where((k) => k.contains('study_hour_xp')).length,
        2,
      );
    });

    test('Kusursuz Ay (WP-D) 27 günü reddeder, 28/29/30 günü kabul eder', () {
      List<StudySession> monthSessions(int year, int month, int days) => [
        for (var day = 1; day <= days; day++)
          _session(
            id: '$year-$month-$day',
            start: DateTime.utc(year, month, day, 12),
            minutes: 60,
          ),
      ];

      final twentySeven = AchievementLedgerEngine().computeMetrics(
        sessions: monthSessions(2026, 4, 27),
        dailyGoalMinutes: 60,
        now: DateTime.utc(2026, 5, 1),
      );
      final february = AchievementLedgerEngine().computeMetrics(
        sessions: monthSessions(2026, 2, 28),
        dailyGoalMinutes: 60,
        now: DateTime.utc(2026, 3, 1),
      );
      final leapFebruary = AchievementLedgerEngine().computeMetrics(
        sessions: monthSessions(2024, 2, 29),
        dailyGoalMinutes: 60,
        now: DateTime.utc(2024, 3, 1),
      );
      final april = AchievementLedgerEngine().computeMetrics(
        sessions: monthSessions(2026, 4, 30),
        dailyGoalMinutes: 60,
        now: DateTime.utc(2026, 5, 1),
      );

      expect(twentySeven['perfect_months'], 0);
      expect(february['perfect_months'], 1);
      expect(leapFebruary['perfect_months'], 1);
      expect(april['perfect_months'], 1);
    });

    test('Kusursuz Ay 28-gün eşiğinde önceki claim/XP geri alınmaz', () {
      final key = ledgerEventKey('legacy-user', 'perfect_month', 1);
      final engine = AchievementLedgerEngine(initialLedgerXp: {key: 300});
      final sessions = [
        for (var day = 1; day <= 28; day++)
          _session(
            id: 'legacy-$day',
            userId: 'legacy-user',
            start: DateTime.utc(2026, 2, day, 12),
            minutes: 60,
          ),
      ];

      final result = engine.processEvent(
        userId: 'legacy-user',
        eventType: 'manual_refresh',
        sessions: sessions,
        dailyGoalMinutes: 60,
        now: DateTime.utc(2026, 3, 1),
      );

      // 28-kuralı: 28 gün = 1 kusursuz ay; ama kademe zaten bankalı → yeni ödül yok.
      expect(result.metrics['perfect_months'], 1);
      expect(engine.eventKeys, contains(key));
      expect(result.totalXp, greaterThanOrEqualTo(300));
      expect(
        result.awarded.where((a) => a.achievementId == 'perfect_month'),
        isEmpty,
      );
    });
  });

  group('InMemoryAchievementRepository', () {
    test('processEvent idempotent ve sözlük dolu', () async {
      final repo = InMemoryAchievementRepository();
      final dict = await repo.fetchDictionary();
      expect(dict.length, 21);

      final sessions = [
        _session(id: 's1', start: DateTime.utc(2026, 6, 1, 12, 0), minutes: 90),
      ];
      final a = await repo.processEvent(
        eventType: 'session_completed',
        sessions: sessions,
        dailyGoalMinutes: 360,
        userId: 'u1',
      );
      final b = await repo.processEvent(
        eventType: 'session_completed',
        sessions: sessions,
        dailyGoalMinutes: 360,
        userId: 'u1',
      );
      expect(a.awarded, isNotEmpty);
      expect(b.awarded, isEmpty);
      expect(b.totalXp, a.totalXp);
      expect(repo.totalXp, a.totalXp);
    });
  });
}
