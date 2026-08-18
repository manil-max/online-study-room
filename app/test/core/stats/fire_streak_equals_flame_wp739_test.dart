import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/achievement_ledger_engine.dart';
import 'package:online_study_room/core/stats/goal_streak_projection.dart';
import 'package:online_study_room/core/stats/goal_streak_rule.dart';
import 'package:online_study_room/core/stats/study_stats.dart';
import 'package:online_study_room/data/models/goal_streak.dart';
import 'package:online_study_room/data/models/study_session.dart';

/// WP-739 — **alev ile başarım aynı sayıyı söyler**.
///
/// 🔴 Sahip bildirimi (2026-08-19): *"bende 2/7 gösteriyor ama 9 günlük seriye
/// sahibim, ilkini almam lazım."* Kök neden: alev rozeti tek kaçırmayı affeden
/// `goal_streak_projection` kuralını okuyordu, Alevli Seri başarımı ise ilk
/// eksik günde duran ayrı bir motoru. Bu dosya farkı KAPATAN sözleşmedir —
/// üç motor (alev projeksiyonu, başarım metriği, profil "Güncel seri"
/// döşemesi) aynı geçmişte aynı sayıyı vermek ZORUNDA.
///
/// Ayrışma önceden `progression_matrix_wp455_test.dart` ve
/// `038_progression_matrix.test.sql §6` içinde açık bulgu olarak ölçülüyordu;
/// bu dosya onların yerine geçen POZİTİF iddiadır.
const _userId = 'u1';
const _goalMinutes = 60;

StudySession _goalDay(DateTime day) {
  final start = DateTime.utc(day.year, day.month, day.day, 7);
  return StudySession(
    id: 'session-${day.toIso8601String()}',
    userId: _userId,
    start: start,
    end: start.add(const Duration(hours: 1)),
    durationSeconds: 3600,
    source: StudySource.live,
  );
}

GoalProgressEvent _completed(DateTime day) => GoalProgressEvent(
  eventKey: 'personal:$_userId:goal_completed:${day.toIso8601String()}',
  scope: const GoalStreakScope.personal(_userId),
  kind: GoalProgressEventKind.goalCompleted,
  goalDay: DateTime.utc(day.year, day.month, day.day),
  occurredAt: DateTime.utc(day.year, day.month, day.day, 20),
);

/// Sahibin tarif ettiği hesap: **dokuz** hedef günü, aralarda üç tane TEK boş
/// gün (dün-önceki gün dahil). Eski "üst üste" kuralına göre kesintisiz olan
/// yalnız son iki gündür — ekranda görülen `2/7` tam olarak budur.
({List<DateTime> days, DateTime asOf}) _ownerHistory() {
  final asOf = DateTime.utc(2026, 8, 19);
  const emptyDaysBack = <int>{2, 5, 8}; // 17, 14 ve 11 Ağustos boş.
  final days = <DateTime>[
    for (var back = 11; back >= 0; back--)
      if (!emptyDaysBack.contains(back)) asOf.subtract(Duration(days: back)),
  ];
  return (days: days, asOf: asOf);
}

void main() {
  group('WP-739 tek seri kuralı', () {
    test('alev ile başarım metriği aynı geçmişte AYNI sayıyı verir', () {
      final history = _ownerHistory();

      final flame = projectGoalStreak(
        scope: const GoalStreakScope.personal(_userId),
        events: history.days.map(_completed),
        asOfDay: history.asOf,
      );

      final metrics = AchievementLedgerEngine().computeMetrics(
        sessions: history.days.map(_goalDay).toList(),
        dailyGoalMinutes: _goalMinutes,
        now: history.asOf.add(const Duration(hours: 12)),
      );

      expect(
        flame.currentStreak,
        9,
        reason: 'kurgu sahibin hesabı: dokuz hedef günü, aralarda tek boşluk',
      );
      expect(
        metrics['streak_days'],
        flame.currentStreak,
        reason: 'ayrışma kapandı: rozet 9 derken başarım ekranı 2 diyemez',
      );
    });

    test('9 günlük alev ilk kademeyi (7) hak eder', () {
      final history = _ownerHistory();
      final engine = AchievementLedgerEngine();
      final result = engine.processEvent(
        userId: _userId,
        eventType: 'profile_opened',
        sessions: history.days.map(_goalDay).toList(),
        dailyGoalMinutes: _goalMinutes,
        now: history.asOf.add(const Duration(hours: 12)),
      );

      final fireTiers = result.awarded
          .where((award) => award.achievementId == 'fire_streak')
          .map((award) => award.tier)
          .toList();
      expect(fireTiers, contains(1), reason: 'sahip: "ilkini almam lazım"');
      expect(
        fireTiers,
        isNot(contains(2)),
        reason: '30 günlük kademe hak edilmedi; eşik gevşetilmedi',
      );
    });

    test('tamamla-boş-tamamla-boş-tamamla üç motorda da 3 sayar', () {
      final asOf = DateTime.utc(2026, 8, 19);
      final days = <DateTime>[
        asOf.subtract(const Duration(days: 4)),
        asOf.subtract(const Duration(days: 2)),
        asOf,
      ];

      final flame = projectGoalStreak(
        scope: const GoalStreakScope.personal(_userId),
        events: days.map(_completed),
        asOfDay: asOf,
      );
      final metrics = AchievementLedgerEngine().computeMetrics(
        sessions: days.map(_goalDay).toList(),
        dailyGoalMinutes: _goalMinutes,
        now: asOf.add(const Duration(hours: 12)),
      );
      final panelTile = currentStreak(
        const [],
        _goalMinutes * 60,
        totals: {for (final day in days) day: 3600},
        today: asOf,
      );

      expect(flame.currentStreak, 3);
      expect(metrics['streak_days'], 3);
      expect(
        panelTile,
        3,
        reason: 'profil "Güncel seri" döşemesi de aynı motoru okur',
      );
    });

    test('iki ardışık boş gün seriyi KIRAR (grace tek kaçırmalıktır)', () {
      final asOf = DateTime.utc(2026, 8, 19);
      final days = <DateTime>[
        asOf.subtract(const Duration(days: 5)),
        asOf.subtract(const Duration(days: 4)),
        asOf.subtract(const Duration(days: 3)),
      ];
      final metrics = AchievementLedgerEngine().computeMetrics(
        sessions: days.map(_goalDay).toList(),
        dailyGoalMinutes: _goalMinutes,
        now: asOf.add(const Duration(hours: 12)),
      );
      expect(
        metrics['streak_days'],
        0,
        reason: 'son tamamlama 3 gün geride: seri yaşamaz',
      );
      expect(
        metrics['best_streak_days'],
        3,
        reason: 'rekor koşu durur; ödül hakkı anlık değerle silinmez',
      );
    });

    test('rekor seri güncel seriden küçük OLAMAZ', () {
      final history = _ownerHistory();
      final totals = {for (final day in history.days) day: 3600};
      final current = currentStreak(
        const [],
        _goalMinutes * 60,
        totals: totals,
        today: history.asOf,
      );
      final record = longestStudyStreak(
        const [],
        totals: totals,
        goalSeconds: _goalMinutes * 60,
      );
      expect(current, 9);
      expect(
        record,
        greaterThanOrEqualTo(current),
        reason: 'rekor grace tanımazken güncel seri tanıyorsa rekor küçük çıkar',
      );
    });

    test('kazanılmış kademe düşen seride geri alınmaz', () {
      final engine = AchievementLedgerEngine();
      final asOf = DateTime.utc(2026, 8, 19);
      // Sekiz günlük kesintisiz seri: kademe 1 hak edilir.
      final earned = <DateTime>[
        for (var back = 30; back >= 23; back--)
          asOf.subtract(Duration(days: back)),
      ];
      final first = engine.processEvent(
        userId: _userId,
        eventType: 'session_completed',
        sessions: earned.map(_goalDay).toList(),
        dailyGoalMinutes: _goalMinutes,
        now: asOf.subtract(const Duration(days: 23)).add(
          const Duration(hours: 12),
        ),
      );
      expect(
        first.awarded.where((a) => a.achievementId == 'fire_streak').length,
        1,
      );

      // Aynı geçmiş, ama bugüne göre seri çoktan bitmiş.
      final later = engine.processEvent(
        userId: _userId,
        eventType: 'profile_opened',
        sessions: earned.map(_goalDay).toList(),
        dailyGoalMinutes: _goalMinutes,
        now: asOf.add(const Duration(hours: 12)),
      );
      expect(later.metrics['streak_days'], 0, reason: 'anlık değer düşer');
      expect(
        engine.eventKeys,
        contains(ledgerEventKey(_userId, 'fire_streak', 1)),
        reason: 'kademe defterde kalır',
      );
      expect(
        later.awarded.where((a) => a.achievementId == 'fire_streak'),
        isEmpty,
        reason: 'ikinci kez XP yazılmaz',
      );
    });
  });

  group('WP-739 saf kural', () {
    test('koşu uzunlukları affedilen boş günü SAYMAZ', () {
      final base = DateTime.utc(2026, 8, 1);
      final days = <DateTime>[
        base,
        base.add(const Duration(days: 2)),
        base.add(const Duration(days: 4)),
        // Üç günlük boşluk yeni koşu başlatır.
        base.add(const Duration(days: 8)),
        base.add(const Duration(days: 9)),
      ];
      expect(goalStreakRunLengths(days), [3, 2]);
      expect(longestGoalStreakDays(days), 3);
    });

    test('boş geçmiş 0 verir', () {
      expect(goalStreakRunLengths(const []), isEmpty);
      expect(longestGoalStreakDays(const []), 0);
      expect(
        currentGoalStreakDays(
          completedDays: const [],
          asOfDay: DateTime.utc(2026, 8, 19),
        ),
        0,
      );
    });

    test('gelecek günler güncel seriye giremez', () {
      final asOf = DateTime.utc(2026, 8, 19);
      expect(
        currentGoalStreakDays(
          completedDays: [asOf.add(const Duration(days: 3))],
          asOfDay: asOf,
        ),
        0,
      );
    });
  });

  group('WP-739 iki uç aynı kuralı yazar', () {
    // Sunucu ucu bu süreçte koşamaz (Docker yerelde kalkmıyor). Ölçülebilen
    // şey, migration'ın gerçekten AYNI grace kuralını taşıdığıdır — WP-373'te
    // bir özellik tam da iki uçlu sözleşme yokluğundan sessizce ölmüştü.
    final migration = File(
      '../supabase/migrations/0136_fire_streak_equals_paused_streak.sql',
    ).readAsStringSync();

    test('_current_fire_streak_days grace kuralını taşır', () {
      expect(
        migration,
        contains('create or replace function public._current_fire_streak_days'),
      );
      expect(
        migration,
        contains('(goal_day - prev_day) > 2'),
        reason: 'koşu bölmesi projeksiyonla aynı olmalı',
      );
      expect(
        migration,
        contains('(p_as_of_day - s.last_completed_day) <= 2'),
        reason: 'yaşam koşulu projeksiyonla aynı olmalı',
      );
      expect(
        migration,
        isNot(contains("and e.time_zone = 'Europe/Istanbul'")),
        reason: '0135 süzgeci kaldırıldı; where projeksiyonla birebir',
      );
    });

    test('ödül dalı rekor seriyi okur, metrik anlık kalır', () {
      expect(
        migration,
        contains("when 'fire_streak' then public._best_fire_streak_days(v_uid)"),
      );
      expect(migration, contains("'goal_completion_grace_v3'"));
      expect(
        migration,
        contains('public.backfill_wp739_fire_streak()'),
        reason: 'hak edilmiş kademeler geriye dönük verilmeli',
      );
    });

    test('0112 projeksiyonu ile 0136 aynı koşu ifadesini kullanır', () {
      final projection = File(
        '../supabase/migrations/0112_goal_streak_projection.sql',
      ).readAsStringSync();
      const runSplit = 'when prev_day is null or (goal_day - prev_day) > 2';
      expect(projection, contains(runSplit));
      expect(migration, contains(runSplit));
    });
  });
}
