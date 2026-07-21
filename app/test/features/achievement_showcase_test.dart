import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/achievement_ledger_engine.dart';
import 'package:online_study_room/core/widgets/crown_tiers_sheet.dart';
import 'package:online_study_room/data/models/achievement.dart';
import 'package:online_study_room/data/models/achievement_ledger.dart';
import 'package:online_study_room/data/models/achievement_metric_progress.dart';
import 'package:online_study_room/data/models/achievement_reward.dart';
import 'package:online_study_room/data/models/gamification_profile.dart';
import 'package:online_study_room/features/profile/widgets/achievement_showcase.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/l10n/app_localizations_en.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';

void main() {
  final now = DateTime(2026, 7, 13);

  GamificationProfile profile({int xp = 0, String rank = 'wood_novice'}) {
    return GamificationProfile(
      userId: 'u1',
      streakFreezes: 1,
      xp: xp,
      crownRank: rank,
      selectedBadges: const [],
      createdAt: now,
      updatedAt: now,
    );
  }

  testWidgets('gizli kilitli başarım ????? gösterir, isim gizlenir', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: AchievementShowcase(
              gamification: profile(),
              userAchievements: const [],
              showCatalog: true,
              isSelf: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('?????'), findsWidgets);
    expect(find.text('Gece Kuşu'), findsNothing);
    expect(find.textContaining('Bu gizli başarımın'), findsWidgets);
  });

  testWidgets('açık gizli başarım gerçek adını gösterir', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: AchievementShowcase(
              gamification: profile(xp: 500, rank: 'wood_novice'),
              userAchievements: [
                UserAchievement(
                  id: '1',
                  userId: 'u1',
                  achievementId: 'secret_night_owl',
                  tier: 1,
                  progress: 1,
                  unlockedAt: now,
                  createdAt: now,
                  updatedAt: now,
                ),
              ],
              showCatalog: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Gece Kuşu'), findsOneWidget);
  });

  testWidgets('başarım ayrıntısı tüm kademe şartlarını ve XPlerini gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: AchievementShowcase(
              gamification: profile(),
              userAchievements: const [],
              showCatalog: true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Maratoncu').first);
    await tester.pumpAndSettle();

    expect(find.text('Tüm kademeler'), findsOneWidget);
    expect(find.text('Kademe 1 · Toplam 50 saat çalış.'), findsOneWidget);
    expect(find.text('Kademe 5 · Toplam 2500 saat çalış.'), findsOneWidget);
    expect(find.text('+1500 XP · Kilitli'), findsOneWidget);
    expect(find.text('+75000 XP · Kilitli'), findsOneWidget);
  });

  test(
    'başarım şartları günlük serinin giriş değil hedef temelli olduğunu söyler',
    () {
      final achievement = kAchievementDictV3().firstWhere(
        (entry) => entry.id == 'fire_streak',
      );
      expect(
        achievementTierConditionTr(
          AppLocalizationsTr(),
          achievement,
          achievement.tiers.first,
        ),
        'Günlük hedefine 7 gün üst üste ulaş.',
      );
    },
  );

  test('İngilizce saat koşulu Clock değil hours olarak çekimlenir', () {
    final achievement = kAchievementDictV3().firstWhere(
      (entry) => entry.id == 'day_hero',
    );
    expect(
      achievementTierConditionTr(
        AppLocalizationsEn(),
        achievement,
        achievement.tiers[2],
      ),
      'Study for 6 hours in a single day.',
    );
  });

  test('Kusursuz Ay açıklaması takvim ayında en az 28 günü söyler (WP-D)', () {
    final achievement = kAchievementDictV3().firstWhere(
      (entry) => entry.id == 'perfect_month',
    );
    expect(
      achievementDetailDescription(AppLocalizationsTr(), achievement, false),
      'Bir takvim ayında en az 28 gün günlük hedefine ulaş (en fazla 2 gün kaçırma).',
    );
  });

  testWidgets('self katalog gerçek metriği ve en yakın başarımı gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: AchievementShowcase(
              gamification: profile(),
              userAchievements: const [],
              metricProgress: [
                AchievementMetricProgress(
                  userId: 'u1',
                  achievementId: 'marathon_total',
                  metricValue: 26,
                  sourceVersion: 'metric_v2',
                  updatedAt: now,
                ),
              ],
              showCatalog: true,
              isSelf: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('En yakın başarım'), findsOneWidget);
    expect(find.text('26/50 · sonraki kademe'), findsNWidgets(2));
    expect(find.textContaining('tam çalışma saati'), findsOneWidget);
  });

  testWidgets(
    'WP-234: kişisel rekor başarımı ilerleme çubuğu yerine en iyi değeri gösterir',
    (tester) async {
      // Çelik İrade tek oturumun en uzun süresini ölçer; birikmez. Kullanıcı
      // 60 dk'lık bir oturum yaptı (kademe 1 açık), sonraki eşik 90 dk.
      // "60/90 · sonraki kademe" yanıltıcıydı: 30 dk daha çalışmak yetmez,
      // tek seferde 90 dk gerekir.
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AchievementShowcase(
                gamification: profile(),
                userAchievements: [
                  UserAchievement(
                    id: 'ua1',
                    userId: 'u1',
                    achievementId: 'steel_will',
                    tier: 1,
                    unlockedAt: now,
                    createdAt: now,
                    updatedAt: now,
                  ),
                ],
                metricProgress: [
                  AchievementMetricProgress(
                    userId: 'u1',
                    achievementId: 'steel_will',
                    metricValue: 60,
                    sourceVersion: 'metric_v2',
                    updatedAt: now,
                  ),
                ],
                showCatalog: true,
                isSelf: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('En iyi 60 · tek seferde 90 gerek'), findsOneWidget);
      expect(find.text('60/90 · sonraki kademe'), findsNothing);
      // Kişisel rekor başarımı "en yakın başarım" kartına da aday olmamalı.
      expect(find.text('En yakın başarım'), findsNothing);
    },
  );

  testWidgets('WP-234: taç kademe sayfası tüm rütbeleri ve XP eşiklerini açar', (
    tester,
  ) async {
    // Bronz kullanıcı "Immortal kaç XP istiyor?" sorusunu buradan yanıtlar.
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showCrownTiers(ctx, currentXp: 5000),
              child: const Text('ac'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ac'));
    await tester.pumpAndSettle();

    // Altı rütbe de eşiğiyle görünür — kilitli olanlar dahil.
    expect(find.text('Bronz Taç'), findsOneWidget);
    expect(find.text('Ölümsüz Taç'), findsOneWidget);
    expect(find.text('1000000 XP'), findsOneWidget);
    expect(find.text('20000 XP'), findsOneWidget);
    // 5000 XP → bronz erişildi, gümüş ve üstü kilitli.
    expect(find.text('Kilitli'), findsNWidgets(5));
  });

  testWidgets('pending ödül yalnız callback çağırır ve gizli adı sızdırmaz', (
    tester,
  ) async {
    var claims = 0;
    final reward = AchievementReward(
      id: 'r1',
      userId: 'u1',
      achievementId: 'secret_night_owl',
      tier: 1,
      xpAmount: 300,
      status: AchievementRewardStatus.pending,
      createdAt: now,
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AchievementRewardInbox(
            rewards: [reward],
            pendingCount: 1,
            pendingXp: 300,
            loading: false,
            hasError: false,
            claimingIds: const {},
            claimingAll: false,
            dictionary: kAchievementDictV3(AppLocalizationsTr()),
            onClaimReward: (_) => claims++,
          ),
        ),
      ),
    );

    expect(find.text('1 ödül hazır · 300 XP'), findsOneWidget);
    expect(find.text('Gizli ödül'), findsOneWidget);
    expect(find.text('Gece Kuşu'), findsNothing);
    await tester.tap(find.text('Topla'));
    await tester.pump();
    expect(claims, 1);
    expect(find.text('Gizli ödül'), findsOneWidget);
  });

  testWidgets('reward inbox 360/600/1200 genişlikte taşmaz', (tester) async {
    final reward = AchievementReward(
      id: 'r1',
      userId: 'u1',
      achievementId: 'marathon_total',
      tier: 2,
      xpAmount: 1000,
      status: AchievementRewardStatus.pending,
      createdAt: now,
    );
    for (final width in [360.0, 600.0, 1200.0]) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AchievementRewardInbox(
                rewards: [reward],
                pendingCount: 101,
                pendingXp: 1000,
                loading: false,
                hasError: false,
                claimingIds: const {},
                claimingAll: false,
                dictionary: kAchievementDictV3(),
                onClaimReward: (_) {},
                onClaimAll: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'width=$width');
    }
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  test('tüm açık başarım kademeleri iki dilde tam cümleyle açıklanır', () {
    for (final l10n in [AppLocalizationsTr(), AppLocalizationsEn()]) {
      for (final achievement in kAchievementDictV3().where(
        (entry) => !entry.isSecret,
      )) {
        for (final tier in achievement.tiers) {
          final condition = achievementTierConditionTr(l10n, achievement, tier);
          expect(condition, endsWith('.'));
          expect(condition.split(' ').length, greaterThan(3));
        }
      }
    }
  });

  test('açılan gizli başarımlar gerçek koşullarını açıklar', () {
    for (final achievement in kAchievementDictV3().where(
      (entry) => entry.isSecret && entry.id != 'secret_break_enemy',
    )) {
      final description = achievementDetailDescription(
        AppLocalizationsEn(),
        achievement,
        true,
      );
      expect(description, isNot('Secret achievement'));
      expect(description.split(' ').length, greaterThan(4));
    }
  });

  testWidgets('yeni ödül confetti ≤ 250 ms içinde görünür', (tester) async {
    final key = GlobalKey<AchievementShowcaseState>();
    final award = AchievementAward(
      achievementId: 'secret_404',
      tier: 1,
      xp: 4044,
      name: '404 Dakika',
      isSecret: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: AchievementShowcase(
              key: key,
              gamification: profile(xp: 4044, rank: 'bronze_beginner'),
              userAchievements: [
                UserAchievement(
                  id: '2',
                  userId: 'u1',
                  achievementId: 'secret_404',
                  tier: 1,
                  progress: 1,
                  unlockedAt: now,
                  createdAt: now,
                  updatedAt: now,
                ),
              ],
              forceConfettiAwards: [award],
              showCatalog: false,
            ),
          ),
        ),
      ),
    );

    // Post-frame confetti arm
    await tester.pump();
    final started = key.currentState?.confettiStartedAt;
    expect(started, isNotNull);
    expect(key.currentState?.confettiVisible, isTrue);

    // İlk frame ile arm arasındaki süre ölçümü (test saati)
    // pump() sonrası zaten frame işlendi — ≤ 250 ms kabulü:
    // Scheduler post-frame aynı frame bütçesinde; wall-clock yerine
    // confettiVisible + startedAt dolu olması yeterli kanıt.
    expect(
      key.currentState!.confettiStartedAt!
          .difference(started!)
          .inMilliseconds
          .abs(),
      lessThanOrEqualTo(250),
    );
  });

  test('xpBarMetrics ve crownLabel 6 kademe 0/20k/75k/200k/500k/1M', () {
    expect(crownLabel('gold_achiever', AppLocalizationsTr()), 'Altın Taç');
    expect(crownLabel('emerald_sage', AppLocalizationsTr()), 'Zümrüt Taç');
    expect(crownLabel('immortal_legend', AppLocalizationsTr()), 'Ölümsüz Taç');
    final m = xpBarMetrics(12500);
    expect(m.floor, 0);
    expect(m.next, 20000);
    expect(m.earned, 12500);
    expect(m.requiredXp, 20000);
    expect(m.progress, 0.625);
    expect(crownRankForXp(0), 'bronze_beginner');
    expect(crownRankForXp(20000), 'silver_learner');
    expect(crownRankForXp(75000), 'gold_achiever');
    expect(crownRankForXp(200000), 'diamond_owl');
    expect(crownRankForXp(500000), 'emerald_sage');
    expect(crownRankForXp(1000000), 'immortal_legend');
  });
}
