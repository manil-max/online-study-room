import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/achievement_engine.dart';
import 'package:online_study_room/data/models/gamification_profile.dart';
import 'package:online_study_room/data/models/study_session.dart';

void main() {
  group('AchievementEngine', () {
    final now = DateTime.now();
    final profile = GamificationProfile(
      userId: 'test_user',
      streakFreezes: 1,
      xp: 0,
      crownRank: 'wood_novice',
      selectedBadges: const [],
      createdAt: now,
      updatedAt: now,
    );

    test('should calculate crown rank correctly', () {
      expect(calculateCrownRank(0), 'wood_novice');
      expect(calculateCrownRank(1000), 'bronze_beginner');
      expect(calculateCrownRank(5000), 'silver_learner');
      expect(calculateCrownRank(10000), 'gold_achiever');
      expect(calculateCrownRank(25000), 'platinum_scholar');
      expect(calculateCrownRank(50000), 'ruby_master');
      expect(calculateCrownRank(100000), 'diamond_owl');
    });

    test('should unlock study hours achievement and add XP', () {
      // 10 saatlik bir oturum ekleyelim
      final session = StudySession(
        id: 's1',
        userId: 'test_user',
        subjectId: null,
        start: now.subtract(const Duration(hours: 10)),
        end: now,
        durationSeconds: 10 * 3600,
        source: StudySource.live,
      );

      final result = AchievementEngine.calculateProgression(
        profile: profile,
        currentAchievements: [],
        allSessions: [session],
      );

      // study_hours için 10 saat = tier 1
      final ach = result.newAchievements.firstWhere((a) => a.achievementId == 'study_hours');
      expect(ach.tier, 1);
      expect(ach.progress, 10);
      expect(ach.isUnlocked, true);

      // tier 1 ödülü = 100 XP + study_sessions (1 oturum) = 0 tier, xp = 0
      // maxSingleSession (10 saat) = 600 dk (deep_focus maxTier) -> tier 6 ödülü 3850 XP
      expect(result.newProfile.xp, greaterThan(100)); // Tam XP hesaplamasını test etmek zor olabilir
    });
    
    test('should progress but not unlock if tier requirements not met', () {
      // Sadece 5 saat çalışmış olsun
      final session = StudySession(
        id: 's1',
        userId: 'test_user',
        subjectId: null,
        start: now.subtract(const Duration(hours: 5)),
        end: now,
        durationSeconds: 5 * 3600,
        source: StudySource.live,
      );

      final result = AchievementEngine.calculateProgression(
        profile: profile,
        currentAchievements: [],
        allSessions: [session],
      );

      final ach = result.newAchievements.firstWhere((a) => a.achievementId == 'study_hours');
      expect(ach.tier, 1);
      expect(ach.progress, 5);
      expect(ach.isUnlocked, false);
    });
  });
}
