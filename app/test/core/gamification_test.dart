import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/gamification.dart';
import 'package:online_study_room/core/stats/study_stats.dart';

void main() {
  test('currentStreakWithFreezes missed day bridges with available freeze', () {
    final today = DateTime(2026, 7, 10);
    final totals = {
      dayOf(today): 3600,
      dayOf(today.subtract(const Duration(days: 2))): 3600,
    };

    final streak = currentStreakWithFreezes(
      totals: totals,
      goalSeconds: 3600,
      availableFreezes: 1,
      today: today,
    );

    expect(streak.streak, 2);
    expect(streak.freezesUsed, 1);
    expect(
      streak.protectedDays.single,
      dayOf(today.subtract(const Duration(days: 1))),
    );
  });

  test('achievements and crown tier are derived from totals', () {
    final achievements = achievementsFor(
      sessionCount: 3,
      totalSeconds: 31 * 3600,
      streak: 7,
    );

    expect(achievements.where((a) => a.unlocked), hasLength(4));
    expect(crownTierFor(achievements), CrownTier.gold);
  });

  test('partial achievements produce bronze crown', () {
    final achievements = achievementsFor(
      sessionCount: 1,
      totalSeconds: 3600,
      streak: 1,
    );

    expect(achievements.where((a) => a.unlocked), hasLength(2));
    expect(crownTierFor(achievements), CrownTier.bronze);
  });
}
