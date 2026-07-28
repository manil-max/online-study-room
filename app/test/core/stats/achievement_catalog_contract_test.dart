import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/achievement_ledger_engine.dart';
import 'package:online_study_room/features/profile/widgets/achievement_showcase.dart';
import 'package:online_study_room/l10n/app_localizations_en.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';

void main() {
  const firstTierThresholds = <String, int>{
    'marathon_total': 50,
    'steel_will': 60,
    'day_hero': 2,
    'fire_streak': 7,
    'weekend_goal_days': 4,
    'perfect_month': 1,
    'alpha_wolf': 7,
    'alpha_wolf_weekly': 1,
    'team_player': 10,
    'campfire_hours': 10,
    'inspiration': 5,
    'locomotive': 5,
  };

  test('katalog ilk kademe eşiklerini TR ve EN koşul metniyle korur', () {
    final visibleAchievements = kAchievementDictV3()
        .where((achievement) => !achievement.isSecret)
        .toList();

    expect(
      visibleAchievements.map((achievement) => achievement.id).toSet(),
      firstTierThresholds.keys.toSet(),
    );

    for (final achievement in visibleAchievements) {
      final firstTier = achievement.tiers.first;
      expect(firstTier.threshold, firstTierThresholds[achievement.id]);

      for (final l10n in [AppLocalizationsTr(), AppLocalizationsEn()]) {
        final condition = achievementTierConditionTr(
          l10n,
          achievement,
          firstTier,
        );

        expect(condition, endsWith('.'));
        expect(condition.split(' ').length, greaterThan(3));
        expect(achievementCatalogDescription(l10n, achievement), condition);
      }
    }
  });
}
