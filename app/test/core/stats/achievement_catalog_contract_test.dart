import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/achievement_ledger_engine.dart';
import 'package:online_study_room/features/profile/widgets/achievement_showcase.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/l10n/app_localizations_en.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';

/// WP-457 mağaza runtime'ının ürettiği iki dilde katalog sözleşmesini korur.
List<AppLocalizations> _releaseLocales() => [
  AppLocalizationsTr(),
  AppLocalizationsEn(),
];

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
    // WP-721
    'ancient_member': 30,
    'metronome': 4,
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

  group('WP-418 · koşul metni ölçülebilir ve koddan türetilmiş', () {
    test('her kademe metni kendi eşiğini sayıyla yazar (TR/EN)', () {
      for (final achievement in kAchievementDictV3().where(
        (achievement) => !achievement.isSecret,
      )) {
        for (final tier in achievement.tiers) {
          for (final l10n in _releaseLocales()) {
            final condition = achievementTierConditionTr(
              l10n,
              achievement,
              tier,
            );
            expect(
              condition.trim(),
              isNotEmpty,
              reason: '${achievement.id}/${tier.tier} boş',
            );
            // Eşiği 1 olan kademede diller "bir/واحد" gibi sözcük kullanıyor;
            // sayı zorunluluğu yalnız 1'den büyük eşiklerde anlamlı.
            if (tier.threshold > 1) {
              expect(
                condition,
                contains('${tier.threshold}'),
                reason:
                    '${l10n.localeName}/${achievement.id}/${tier.tier} eşiği '
                    'metinde geçmiyor — kullanıcı neyi hedeflediğini okuyamaz',
              );
            }
          }
        }
      }
    });

    test('İlham Kaynağı: metrik 20 dakikadaki başarılı dönüşümdür', () {
      // WP-476 / 0116: yalnız dürtmeden sonraki 20 dakikada başlayan
      // doğrulanmış canlı oturumlar başarı metriğine girer.
      final inspiration = kAchievementDictV3().firstWhere(
        (achievement) => achievement.id == 'inspiration',
      );
      expect(inspiration.tiers.first.unit, 'nudge_starts');

      final tr = achievementTierConditionTr(
        AppLocalizationsTr(),
        inspiration,
        inspiration.tiers.first,
      );
      final en = achievementTierConditionTr(
        AppLocalizationsEn(),
        inspiration,
        inspiration.tiers.first,
      );
      expect(tr.toLowerCase(), contains('20 dakika'));
      expect(en.toLowerCase(), contains('20 minutes'));
      expect(tr.toLowerCase(), contains('çalışmaya başlasın'));
      expect(en.toLowerCase(), contains('start studying'));
    });

    test('Lokomotif: 15 dakikalık takip penceresi metinde yazılı', () {
      // 🔴 Kod gerçeği (`0059_campfire_dynamic_threshold.sql`, `loco` CTE):
      //   follower.a between leader.a and least(leader.z, leader.a + 15 min)
      // Bir olay = sen başladıktan sonraki 15 dk içinde (sen hâlâ çalışırken)
      // başlayan **farklı** bir grup arkadaşı. "İlk başlayan üye ol" değil.
      final locomotive = kAchievementDictV3().firstWhere(
        (achievement) => achievement.id == 'locomotive',
      );
      expect(locomotive.tiers.first.unit, 'locomotive_events');

      for (final l10n in _releaseLocales()) {
        expect(
          achievementTierConditionTr(l10n, locomotive, locomotive.tiers.first),
          contains('15'),
          reason:
              '${l10n.localeName}: takip penceresi yazılmamış — sahip koşulu '
              'anlamadığını bildirdi',
        );
      }
    });

    test('Kamp Ateşi: eşik sabit 3 değil, grubun yarısı', () {
      // 🔴 Kod gerçeği (`0059`, `thr` CTE): greatest(2, ceil(N/2)).
      // Sabit 3'ü yazan metin `0059`'dan beri yanlıştı.
      final campfire = kAchievementDictV3().firstWhere(
        (achievement) => achievement.id == 'campfire_hours',
      );
      final tr = achievementTierConditionTr(
        AppLocalizationsTr(),
        campfire,
        campfire.tiers.first,
      );
      final en = achievementTierConditionTr(
        AppLocalizationsEn(),
        campfire,
        campfire.tiers.first,
      );
      expect(tr, isNot(contains('3 grup')));
      expect(en, isNot(contains('3 group')));
      expect(tr.toLowerCase(), contains('yarısı'));
      expect(en.toLowerCase(), contains('half'));
    });

    test('Takım Oyuncusu: grubun hedefe ulaşması koşul değil', () {
      // 🔴 Kod gerçeği (`0025:167`): aktif grup üyeliği varken oturum yapılan
      // **farklı gün** sayısı. Grubun hedefi hiç hesaba girmiyor.
      final teamPlayer = kAchievementDictV3().firstWhere(
        (achievement) => achievement.id == 'team_player',
      );
      final tr = achievementTierConditionTr(
        AppLocalizationsTr(),
        teamPlayer,
        teamPlayer.tiers.first,
      );
      expect(tr.toLowerCase(), contains('üyesiyken'));
      expect(tr.toLowerCase(), isNot(contains('hedefine katkı')));
      expect(
        AppLocalizationsTr().profileAchievementTeamPlayerRule.toLowerCase(),
        contains('gerekmez'),
      );
      expect(
        AppLocalizationsEn().profileAchievementTeamPlayerRule.toLowerCase(),
        contains('does not need'),
      );
    });

    test('Alfa Kurt: beraberlikte kimse kazanmaz', () {
      // Kod gerçeği (`0059`, `alpha` CTE): count(*) over(partition by seconds)=1
      // — yani **tek başına** birincilik şart.
      final alpha = kAchievementDictV3().firstWhere(
        (achievement) => achievement.id == 'alpha_wolf',
      );
      expect(
        achievementTierConditionTr(
          AppLocalizationsTr(),
          alpha,
          alpha.tiers.first,
        ).toLowerCase(),
        contains('tek başına'),
      );
      expect(
        achievementTierConditionTr(
          AppLocalizationsEn(),
          alpha,
          alpha.tiers.first,
        ).toLowerCase(),
        contains('sole'),
      );
    });
  });
}
