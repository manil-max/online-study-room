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
    test('sözlük 21 başarım içerir (çalışma+seri+grup+sosyal+gizli)', () {
      final dict = kAchievementDictV3();
      expect(dict.length, 21);
      expect(dict.where((e) => e.isSecret).length, 10);
      expect(dict.any((e) => e.id == 'marathon_total'), isTrue);
      expect(dict.any((e) => e.id == 'secret_404'), isTrue);
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
          (a) => a.achievementId == 'secret_404' && a.xp == 4044,
        ),
        isTrue,
      );
    });

    test('secret_pi: 194 dakika → 314 XP', () {
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
          (a) => a.achievementId == 'secret_pi' && a.xp == 314,
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

    test('crownRankForXp 5 kademe eşikleri', () {
      expect(crownRankForXp(0), 'bronze_beginner');
      expect(crownRankForXp(999), 'bronze_beginner');
      expect(crownRankForXp(1000), 'silver_learner');
      expect(crownRankForXp(5000), 'gold_achiever');
      expect(crownRankForXp(15000), 'platinum_scholar');
      expect(crownRankForXp(50000), 'diamond_owl');
    });
  });

  group('InMemoryAchievementRepository', () {
    test('processEvent idempotent ve sözlük dolu', () async {
      final repo = InMemoryAchievementRepository();
      final dict = await repo.fetchDictionary();
      expect(dict.length, 21);

      final sessions = [
        _session(
          id: 's1',
          start: DateTime.utc(2026, 6, 1, 12, 0),
          minutes: 90,
        ),
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
