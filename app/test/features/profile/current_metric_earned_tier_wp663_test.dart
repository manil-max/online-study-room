import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/achievement_ledger_engine.dart';
import 'package:online_study_room/data/models/achievement.dart';
import 'package:online_study_room/data/models/achievement_metric_progress.dart';
import 'package:online_study_room/data/models/gamification_profile.dart';
import 'package:online_study_room/features/profile/widgets/achievement_showcase.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-663 — kazanılmış rozetin yanında sıfır.
///
/// ÖLÇÜLEN GERÇEK (belge değil, çalıştırılabilir kod):
///
///  * `fire_streak` tek `'current'` sınıfı metriktir
///    (`achievement_ledger_engine.dart:353` `kCurrentAchievementMetrics`).
///    Sunucu tarafı da aynısını söylüyor: `0050:45` satırında kayıt
///    `('fire_streak', 'streak_days', 'current', ...)`; `greatest` yalnız
///    `'cumulative'` dalında uygulanır (`0050:296-302`). Yani bu metriğin
///    değeri **düşer** — iki gün ara veren kullanıcıda 0 olur.
///  * Kazanılmış kademe ise durur (`0126` uzlaştırması `fire_streak`e
///    dokunmaz), ve **durmalıdır**: "zorlama yok" politikası
///    (`docs/URUN-POLITIKALARI.md §3`) tatil için ceza vermeyi yasaklar.
///
/// KUSUR: iki gerçek doğru, **gösterim** yanlıştı. Kademe 1 kazanmış bir
/// kullanıcının kartında yanan kademe şeridi + "1" rozeti ile birlikte
/// `0/30 · sonraki kademe` yazıyordu: kazandığı rozetin altında çıplak bir
/// sıfır. Ekranda hiçbir yerde "kademe 1 sende kalıyor" demiyordu.
///
/// SÖZLEŞME (bu dosyanın kilitlediği şey):
///  1. `'current'` sınıfı bir metrikte kademe kazanılmışsa, kart çıplak
///     `N/M · sonraki kademe` satırını **çizmez** ve ilerleme çubuğu koymaz —
///     çubuk biriken bir değer ima eder, bu değer birikmez.
///  2. Kazanılmış kademenin kalıcı olduğu **yazılır**.
///  3. Sonraki kademeye ilerleme **kaybolmaz**; hangi kademeye sayıldığı
///     adıyla yazılır (madde 4: "Kademe 1 açık" + "Kademe 2 için 0/30"
///     doğrudur, yanlış olan kademesiz çıplak sıfırdır).
///  4. Kümülatif metrikler ve kademe kazanılmamış hâl **değişmez**.
void main() {
  final now = DateTime(2026, 8, 10);

  GamificationProfile gamification() => GamificationProfile(
    userId: 'me',
    streakFreezes: 0,
    xp: 1000,
    crownRank: 'bronze_beginner',
    selectedBadges: const [],
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

  AchievementMetricProgress metric(String achievementId, int value) =>
      AchievementMetricProgress(
        userId: 'me',
        achievementId: achievementId,
        metricValue: value,
        sourceVersion: 'metric_v2',
        updatedAt: now,
      );

  Future<void> pumpShowcase(
    WidgetTester tester, {
    required List<UserAchievement> achievements,
    required List<AchievementMetricProgress> metrics,
    bool isSelf = true,
  }) async {
    tester.view.physicalSize = const Size(1200, 8000);
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
              gamification: gamification(),
              userAchievements: achievements,
              metricProgress: metrics,
              isSelf: isSelf,
              showCatalog: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Katalogda `Ateş Harlı` kartının kendisi. "En yakın başarım" şeridi de aynı
  /// adı taşıyabildiği için ölçüm karta daraltılır.
  Finder fireStreakCard() => find.ancestor(
    of: find.text('Ateş Harlı'),
    matching: find.byType(Card),
  );

  test('ön koşul: fire_streak gerçekten `current` sınıfı bir metrik', () {
    expect(
      kCurrentAchievementMetrics,
      contains('fire_streak'),
      reason:
          'bu dosyanın tamamı bu sözleşmeye dayanıyor; sınıf değişirse test '
          'anlamsız kalır, sessizce yeşil kalmasın',
    );
  });

  testWidgets(
    'kademe kazanılmışken çıplak "0/30 · sonraki kademe" gösterilmez',
    (tester) async {
      await pumpShowcase(
        tester,
        achievements: [earned('fire_streak', tier: 1)],
        // Seri kırıldı: `current` metrik 0'a düştü. Kademe 1 duruyor.
        // `marathon_total` yalnız "En yakın başarım" şeridini meşgul etmek
        // için var — ölçüm katalog kartına ait olsun diye.
        metrics: [metric('fire_streak', 0), metric('marathon_total', 12)],
      );

      expect(
        find.text('0/30 · sonraki kademe'),
        findsNothing,
        reason:
            'kullanıcının kazandığı rozetin altında çıplak sıfır; hangi '
            'kademeye sayıldığı ve kademe 1in kalıcı olduğu yazmıyor',
      );
    },
  );

  testWidgets('kazanılmış kademenin kalıcı olduğu yazılır', (tester) async {
    await pumpShowcase(
      tester,
      achievements: [earned('fire_streak', tier: 1)],
      metrics: [metric('fire_streak', 0), metric('marathon_total', 12)],
    );

    expect(
      find.descendant(
        of: fireStreakCard(),
        matching: find.text('Kademe 1 kazanıldı · kalıcı'),
      ),
      findsOneWidget,
      reason:
          'tatil yaptı diye rozet geri alınmaz (URUN-POLITIKALARI §3); '
          'ekran bunu söylemezse kullanıcı kaybettiğini sanır',
    );
  });

  testWidgets('sonraki kademeye ilerleme kaybolmaz, kademesiyle yazılır', (
    tester,
  ) async {
    await pumpShowcase(
      tester,
      achievements: [earned('fire_streak', tier: 1)],
      metrics: [metric('fire_streak', 0), metric('marathon_total', 12)],
    );

    expect(
      find.descendant(
        of: fireStreakCard(),
        matching: find.text('Şu anki seri 0 · Kademe 2 için 30 gerek'),
      ),
      findsOneWidget,
      reason:
          '"Kademe 1 açık" + "Kademe 2 için 0/30" DOĞRUdur ve görünmelidir; '
          'yanlış olan sayının hangi kademeye ait olduğunun yazılmamasıydı',
    );
  });

  testWidgets('birikmeyen metrikte ilerleme çubuğu çizilmez', (tester) async {
    await pumpShowcase(
      tester,
      achievements: [earned('fire_streak', tier: 1)],
      metrics: [metric('fire_streak', 0), metric('marathon_total', 12)],
    );

    expect(
      find.descendant(
        of: fireStreakCard(),
        matching: find.byType(LinearProgressIndicator),
      ),
      findsNothing,
      reason:
          'çubuk biriken bir değer ima eder; `current` metrik düşer, '
          'boş çubuk "her şeyi kaybettin" diye okunur (WP-234 ile aynı gerekçe)',
    );
  });

  testWidgets('KARŞI İDDİA: kümülatif metrik değişmez', (tester) async {
    await pumpShowcase(
      tester,
      achievements: [earned('marathon_total', tier: 1)],
      metrics: [metric('marathon_total', 120)],
    );

    final card = find.ancestor(
      of: find.text('Maratoncu'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(
        of: card,
        matching: find.text('120/200 · sonraki kademe'),
      ),
      findsOneWidget,
      reason:
          'düzeltme yalnız `current` sınıfına dokunmalı; kümülatif metrikte '
          'çubuk + N/M doğru gösterimdir',
    );
    expect(
      find.descendant(of: card, matching: find.byType(LinearProgressIndicator)),
      findsOneWidget,
    );
  });

  testWidgets('KARŞI İDDİA: kademe kazanılmamışken ilk kademe çubuğu durur', (
    tester,
  ) async {
    await pumpShowcase(
      tester,
      achievements: const [],
      metrics: [metric('fire_streak', 5)],
    );

    expect(
      find.descendant(
        of: fireStreakCard(),
        matching: find.text('5/7 · sonraki kademe'),
      ),
      findsOneWidget,
      reason:
          'henüz rozeti olmayan kullanıcıda çelişki yok; ilk kademeye '
          'ilerleme normal çubuğuyla görünmeye devam etmeli',
    );
  });

  testWidgets('KARŞI İDDİA: başkasının profilindeki kademe yolu (WP-660) bozulmaz', (
    tester,
  ) async {
    await pumpShowcase(
      tester,
      achievements: [earned('fire_streak', tier: 1)],
      metrics: const [],
      isSelf: false,
    );

    expect(
      find.descendant(of: fireStreakCard(), matching: find.text('1/6 kademe')),
      findsOneWidget,
      reason:
          'başkasının profilinde ham metrik RLS ile gelmez; WP-660 kademe '
          'temelli yolu bu WPde değişmemeli',
    );
  });
}
