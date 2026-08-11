import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/achievement_ledger_engine.dart';
import 'package:online_study_room/data/models/achievement.dart';
import 'package:online_study_room/data/models/achievement_reward.dart';
import 'package:online_study_room/data/models/gamification_profile.dart';
import 'package:online_study_room/features/profile/widgets/achievement_showcase.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-713 — gizli başarımlar "Bronz" kademesinde sınıflanıyor.
///
/// ÖLÇÜLEN GERÇEK (koddan, belgeden değil):
///
///  * Sözlükteki 9 gizli başarımın hepsi **tek kademelidir**:
///    `achievement_ledger_engine.dart:225-305` her birine `[(1, 1, ..., xp)]`
///    verir, yani `maxTier == 1` ve kazanıldığında `tier == 1`.
///  * `tierLabel(1)` = `coreBronz` = "Bronz"
///    (`progression_visuals.dart:33-36`, `app_tr.arb:499`).
///  * Renk tarafı zaten AYRIKTIR: `badgeVisualColor` gizli açık rozete
///    `kSecretAchievementColor` (mor) verir (`progression_visuals.dart:187`),
///    bronz rengini vermez. Yani kusur renkte değil **etikette**.
///
/// KUSUR: gizli bir başarımı açan kullanıcıya, 6 kademeli merdivenin en alt
/// basamağının adı gösteriliyor. "404" ya da "Yılbaşı Nöbeti" bir kademe
/// merdiveninin parçası değil — tek seferlik bir sırdır; "Bronz" demek onu
/// merdivenin en dibine yerleştirir.
///
/// SÖZLEŞME (bu dosyanın kilitlediği şey):
///  1. Gizli bir başarımın rozetinde (katalog + vitrin) kademe adı geçmez.
///  2. Ödül kutusunda gizli bir ödül satırında kademe adı geçmez.
///  3. KARŞI İDDİA: normal (gizli olmayan) başarımlarda kademe adı aynen kalır
///     — düzeltme 6 kademeli merdiveni bozmaz.
void main() {
  final now = DateTime(2026, 8, 11);

  GamificationProfile gamification({List<String> badges = const []}) =>
      GamificationProfile(
        userId: 'me',
        streakFreezes: 0,
        xp: 5000,
        crownRank: 'bronze_beginner',
        selectedBadges: badges,
        createdAt: now,
        updatedAt: now,
      );

  UserAchievement earned(String achievementId, {required int tier}) =>
      UserAchievement(
        id: 'me-$achievementId',
        userId: 'me',
        achievementId: achievementId,
        tier: tier,
        progress: tier,
        unlockedAt: now,
        createdAt: now,
        updatedAt: now,
      );

  AchievementReward reward(String achievementId, {required int tier}) =>
      AchievementReward(
        id: 'r-$achievementId',
        userId: 'me',
        achievementId: achievementId,
        tier: tier,
        xpAmount: 2000,
        status: AchievementRewardStatus.pending,
        createdAt: now,
      );

  Future<void> pumpShowcase(
    WidgetTester tester, {
    List<UserAchievement> achievements = const [],
    List<AchievementReward> rewards = const [],
    List<String> badges = const [],
  }) async {
    tester.view.physicalSize = const Size(1200, 12000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: AchievementShowcase(
              gamification: gamification(badges: badges),
              userAchievements: achievements,
              pendingRewards: rewards,
              pendingRewardCount: rewards.length,
              pendingRewardXp: rewards.fold(0, (a, r) => a + r.xpAmount),
              isSelf: true,
              showCatalog: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Bir başarım adını taşıyan rozet dairesinin tooltip metni.
  String tooltipFor(WidgetTester tester, String achievementName) {
    final card = find.ancestor(
      of: find.text(achievementName),
      matching: find.byType(Card),
    );
    final tooltip = tester.widget<Tooltip>(
      find.descendant(of: card, matching: find.byType(Tooltip)).first,
    );
    return tooltip.message ?? '';
  }

  test('ön koşul: gizli başarımlar gerçekten TEK kademeli', () {
    final secrets = kAchievementDictV3().where((d) => d.isSecret).toList();
    expect(
      secrets,
      isNotEmpty,
      reason: 'sözlükte gizli başarım yoksa bu dosyanın tamamı anlamsızdır',
    );
    for (final def in secrets) {
      expect(
        def.maxTier,
        1,
        reason:
            '${def.id} tek kademeli olmalı; çok kademeli gizli başarım '
            'gelirse "kademe adı gösterme" kuralı yeniden düşünülmeli',
      );
    }
  });

  test('ön koşul: kademe 1in adı gerçekten "Bronz"', () {
    // Bu iddia düşerse test yanlış şeyi arıyordur; sessizce yeşil kalmasın.
    final secretTiers = kAchievementDictV3()
        .where((d) => d.isSecret)
        .expand((d) => d.tiers)
        .map((t) => t.tier)
        .toSet();
    expect(secretTiers, {1});
  });

  testWidgets('açılmış gizli başarımın rozetinde kademe adı geçmez', (
    tester,
  ) async {
    await pumpShowcase(
      tester,
      achievements: [earned('secret_night_owl', tier: 1)],
    );

    expect(
      tooltipFor(tester, 'Gece Kuşu'),
      isNot(contains('Bronz')),
      reason:
          'gizli başarım tek seferlik bir sırdır, 6 kademeli merdivenin en '
          'alt basamağı değil; "Bronz" demek onu merdivenin dibine koyar',
    );
  });

  testWidgets('açılmış gizli başarımın rozeti gizli olduğunu söyler', (
    tester,
  ) async {
    await pumpShowcase(
      tester,
      achievements: [earned('secret_night_owl', tier: 1)],
    );

    expect(
      tooltipFor(tester, 'Gece Kuşu'),
      contains('Gizli'),
      reason:
          'kademe adı kaldırılırken yerine hiçbir şey konmazsa kullanıcı ne '
          'kazandığını bilmez; katalog kartındaki "Gizli · Tamamlandı" ile '
          'aynı dil kullanılmalı',
    );
  });

  testWidgets('vitrindeki gizli rozette de kademe adı geçmez', (tester) async {
    await pumpShowcase(
      tester,
      achievements: [earned('secret_404', tier: 1)],
      badges: const ['secret_404'],
    );

    // Vitrin satırındaki rozet: katalog kartının DIŞINDAKİ tooltip.
    final tooltips = tester
        .widgetList<Tooltip>(find.byType(Tooltip))
        .where((t) => (t.message ?? '').startsWith('404'))
        .toList();
    expect(
      tooltips,
      isNotEmpty,
      reason: 'vitrin + katalog: 404 rozeti en az bir kez çizilmeli',
    );
    for (final tooltip in tooltips) {
      expect(
        tooltip.message,
        isNot(contains('Bronz')),
        reason: 'vitrin rozeti de aynı `_BadgeCircle`; iki yerde de düzelmeli',
      );
    }
  });

  testWidgets('ödül kutusunda gizli ödül kademe adıyla etiketlenmez', (
    tester,
  ) async {
    await pumpShowcase(tester, rewards: [reward('secret_pi', tier: 1)]);

    final row = find.ancestor(
      of: find.text('Gizli ödül'),
      matching: find.byType(Row),
    );
    expect(row, findsWidgets, reason: 'gizli ödül satırı çizilmeli');
    expect(
      find.descendant(of: row.first, matching: find.textContaining('Bronz')),
      findsNothing,
      reason:
          'ödül satırı adı zaten gizler ("Gizli ödül"), altına "Bronz" yazmak '
          'sırrı kademe merdivenine bağlar',
    );
  });

  testWidgets('KARŞI İDDİA: normal başarımda kademe adı aynen kalır', (
    tester,
  ) async {
    await pumpShowcase(
      tester,
      achievements: [earned('marathon_total', tier: 1)],
    );

    expect(
      tooltipFor(tester, 'Maratoncu'),
      contains('Bronz'),
      reason:
          '6 kademeli merdiven bu WPde değişmiyor; kademeli başarımda '
          '"Bronz · 1" doğru gösterimdir',
    );
  });

  testWidgets('KARŞI İDDİA: normal ödül satırı kademe adını korur', (
    tester,
  ) async {
    await pumpShowcase(tester, rewards: [reward('marathon_total', tier: 2)]);

    // `find.textContaining('Gümüş')` burada işe yaramaz: XP barının altındaki
    // kademe şeridi de "Gümüş" yazar. Ölçüm ödül satırının tam metnine daralır.
    expect(
      find.text('Gümüş · +2000 XP'),
      findsOneWidget,
      reason: 'gizli olmayan ödülde kademe adı ödülün değerini anlatır',
    );
  });
}
