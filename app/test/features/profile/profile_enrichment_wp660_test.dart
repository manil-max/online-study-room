import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/achievement.dart';
import 'package:online_study_room/data/models/daily_stat.dart';
import 'package:online_study_room/data/models/gamification_profile.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/gamification_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/features/profile/social_profile_screen.dart';
import 'package:online_study_room/features/profile/widgets/achievement_showcase.dart';
import 'package:online_study_room/features/profile/widgets/profile_stats_panel.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-660 — sahip maddesi 6: "gruptakilerin profiline girince görevlerindeki
/// ilerlemeleri görelim (gizliler hariç). profilde günlük aktif, günlük serisi
/// ve rekorları falan olsa güzel olur."
///
/// Bu dosya ÜÇ iddiayı ayrı ayrı kilitler:
///
///  1. **Başkasının profilinde ilerleme**. Ham metrik tablosu
///     (`achievement_metric_progress`) RLS'te `user_id = auth.uid()` ile
///     kilitli (`0050_achievement_metric_contract.sql:84`), yani başkasının
///     metrik değeri istemciye HİÇ gelmez. Ama kazanılmış **kademe**
///     (`user_achievements`) `can_see_user_sessions` kapısından geliyor
///     (`0024_achievements_ledger.sql:99`). Kademe 3/6 olan bir üyeye boş
///     çubuk + "İlerleme henüz hazır değil" yazmak yanlış: veri elde.
///
///  2. **Gizlilik**. Kilitli gizli başarım başkasının profilinde ne adıyla ne
///     de kademe sayısıyla görünmez. Bu, "filtreledim" cümlesi değil ölçüdür.
///
///  3. **Seri ≠ aktif gün** (WP-636/637). Panelde ikisi de varsa tanımları
///     ayrı yazılır, yoksa sahibin bu hafta yaşadığı karışıklık tekrarlar.
void main() {
  final now = DateTime(2026, 8, 10);

  GamificationProfile gamification(String userId) => GamificationProfile(
    userId: userId,
    streakFreezes: 1,
    xp: 0,
    crownRank: 'wood_novice',
    selectedBadges: const [],
    createdAt: now,
    updatedAt: now,
  );

  UserAchievement unlocked(
    String userId,
    String achievementId, {
    required int tier,
  }) => UserAchievement(
    id: '$userId-$achievementId',
    userId: userId,
    achievementId: achievementId,
    tier: tier,
    progress: tier,
    unlockedAt: now,
    createdAt: now,
    updatedAt: now,
  );

  Widget wrap(Widget child, {List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
  }

  group('başkasının profilinde başarım ilerlemesi', () {
    testWidgets(
      'kazanılmış kademe ilerleme olarak görünür (boş çubuk + "hazır değil" DEĞİL)',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            AchievementShowcase(
              gamification: gamification('other'),
              userAchievements: [
                unlocked('other', 'marathon_total', tier: 3),
              ],
              // Başkasının profilinde ham metrik YOK — RLS izin vermiyor.
              metricProgress: const [],
              isSelf: false,
              showCatalog: true,
            ),
          ),
        );
        await tester.pump();

        // Maratoncu 6 kademelidir; üye 3'ünü kazanmış.
        expect(
          find.text('3/6 kademe'),
          findsOneWidget,
          reason:
              'kademe verisi `user_achievements` üzerinden ZATEN istemcide; '
              'bunu çizmemek özelliği yok saymaktır',
        );
        expect(
          find.text('İlerleme henüz hazır değil'),
          findsNothing,
          reason:
              'kazanılmış kademesi olan bir üyeye "ilerleme yok" demek '
              'kullanıcının GÖRDÜĞÜ satırda yalandır',
        );
      },
    );

    testWidgets('kendi profilinde ham metrik yolu DEĞİŞMEZ (ters iddia)', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          AchievementShowcase(
            gamification: gamification('me'),
            userAchievements: [unlocked('me', 'marathon_total', tier: 3)],
            metricProgress: const [],
            isSelf: true,
            showCatalog: true,
          ),
        ),
      );
      await tester.pump();

      // Kendi profilinde metrik satırı yoksa dürüst cevap hâlâ "hazır değil";
      // kademe metnine düşülmez, yoksa kendi ilerlememiz sessizce kabalaşır.
      expect(find.text('3/6 kademe'), findsNothing);
      expect(find.text('İlerleme henüz hazır değil'), findsWidgets);
    });
  });

  group('gizlilik — gizli başarım başkasının profilinde sızmaz', () {
    testWidgets('kilitli gizli başarım ne adıyla ne kademesiyle görünür', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          AchievementShowcase(
            gamification: gamification('other'),
            userAchievements: [
              // Açık: normal başarım. Gizli olan HİÇ kazanılmamış.
              unlocked('other', 'marathon_total', tier: 2),
            ],
            metricProgress: const [],
            isSelf: false,
            showCatalog: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('?????'), findsWidgets);
      expect(find.text('Gece Kuşu'), findsNothing);
      expect(find.text('404 Dakika'), findsNothing);
      // Gizli başarımların hiçbiri "n/1 kademe" biçiminde ilerleme sızdırmaz:
      // yalnız normal başarımın kademesi görünür.
      expect(find.text('0/1 kademe'), findsNothing);
      expect(find.text('2/6 kademe'), findsOneWidget);
    });
  });

  group('profil istatistik paneli', () {
    List<StudySession> selfSessions() {
      // 3 ardışık gün, her biri 2 saat. Günlük hedef 60 dk → seri 3.
      return [
        for (var i = 0; i < 3; i++)
          StudySession(
            id: 's$i',
            userId: 'me',
            start: DateTime(2026, 8, 8 + i, 10),
            end: DateTime(2026, 8, 8 + i, 12),
            durationSeconds: 7200,
            source: StudySource.manual,
          ),
      ];
    }

    String valueOf(WidgetTester tester, String key) =>
        tester.widget<Text>(find.byKey(Key(key))).data!;

    testWidgets('kendi profilinde seri ve aktif gün AYRI tanımlarla çizilir', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const ProfileStatsPanel(userId: 'me', isSelf: true),
          overrides: [
            userSessionsProvider.overrideWith(
              (ref) => Stream.value(selfSessions()),
            ),
            dailyGoalMinutesProvider.overrideWith((ref) => 60),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aktif gün'), findsOneWidget);
      expect(find.text('En az bir çalışma kaydı olan gün'), findsOneWidget);
      expect(find.text('Günlük seri'), findsOneWidget);
      expect(
        // Seri döşemesi + rekor seri döşemesi aynı kuralı yazar.
        find.text('Günlük hedefi tutturulan ardışık gün'),
        findsNWidgets(2),
        reason:
            'WP-636/637: seri ile aktif gün FARKLI ölçüler; aynı ekranda '
            'ikisi de varsa tanımları ayrı yazılmalı',
      );
      expect(valueOf(tester, 'profile-stat-active-days'), '3');
      expect(valueOf(tester, 'profile-stat-record-streak'), '3 gün');
      // Kendi profilinde seri rozeti sunucudan gelir (uydurma sayı yok).
      expect(find.byKey(const Key('profile-stat-goal-streak')), findsOneWidget);
    });

    testWidgets(
      'başkasının profilinde aktif gün/rekor ortak gruptan gelir, '
      'güncel seri de aynı görünür kaynaktan gelir',
      (tester) async {
        final member = Profile(
          id: 'other',
          displayName: 'Komşu',
          createdAt: now,
          dailyGoalMinutes: 60,
        );
        await tester.pumpWidget(
          wrap(
            const ProfileStatsPanel(userId: 'other', isSelf: false),
            overrides: [
              groupMembersProvider.overrideWith(
                (ref) => Stream.value([member]),
              ),
              groupDailyStatsProvider.overrideWith(
                (ref) => Stream.value([
                  for (var i = 0; i < 3; i++)
                    DailyStat(
                      userId: 'other',
                      day: DateTime(2026, 8, 8 + i),
                      seconds: 7200,
                    ),
                  // Başka bir üyenin satırı sızmamalı.
                  DailyStat(
                    userId: 'baskasi',
                    day: DateTime(2026, 8, 1),
                    seconds: 36000,
                  ),
                ]),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Aktif gün'), findsOneWidget);
        expect(find.text('Rekor seri'), findsOneWidget);
        expect(find.text('Günlük seri'), findsOneWidget);
        expect(
          find.byKey(const Key('profile-stat-goal-streak')),
          findsOneWidget,
          reason:
              'güncel seri, ortak gruba açık gün toplamları ve '
              'üyenin görünür günlük hedefinden hesaplanır',
        );
        expect(
          find.byKey(const Key('profile-stat-streak-unavailable')),
          findsNothing,
        );
        // 3 gün × 2 saat; başka üyenin 10 saatlik günü karışmadı.
        expect(valueOf(tester, 'profile-stat-active-days'), '3');
        expect(valueOf(tester, 'profile-stat-record-streak'), '3 gün');
      },
    );

    testWidgets(
      'ortak grubu olmayan birinin profilinde panel HİÇ çizilmez '
      '(can_see_user_sessions kapısının istemci yansıması)',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            const ProfileStatsPanel(userId: 'yabanci', isSelf: false),
            overrides: [
              groupMembersProvider.overrideWith(
                (ref) => Stream.value(const <Profile>[]),
              ),
              groupDailyStatsProvider.overrideWith(
                (ref) => Stream.value(const <DailyStat>[]),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Aktif gün'), findsNothing);
        expect(find.text('Rekor seri'), findsNothing);
        expect(find.byType(ProfileStatsPanel), findsOneWidget);
      },
    );
  });

  group('ekran kablosu — panel gercekten SocialProfileScreen icinde', () {
    testWidgets(
      'grup arkadasinin profili acilinca panel EKRANDA cizilir '
      '(yazilmis ama cagrilmamis widget tuzagi)',
      (tester) async {
        final me = Profile(id: 'me', displayName: 'Ben', createdAt: now);
        final other = Profile(
          id: 'other',
          displayName: 'Komşu',
          createdAt: now,
          dailyGoalMinutes: 60,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authStateProvider.overrideWith((ref) => Stream.value(me)),
              gamificationProfileProvider(
                'other',
              ).overrideWith((ref) => Stream.value(gamification('other'))),
              userAchievementsProvider('other').overrideWith(
                (ref) => Stream.value([
                  unlocked('other', 'marathon_total', tier: 3),
                ]),
              ),
              groupMembersProvider.overrideWith(
                (ref) => Stream.value([me, other]),
              ),
              groupDailyStatsProvider.overrideWith(
                (ref) => Stream.value([
                  for (var i = 0; i < 3; i++)
                    DailyStat(
                      userId: 'other',
                      day: DateTime(2026, 8, 8 + i),
                      seconds: 7200,
                    ),
                ]),
              ),
            ],
            child: MaterialApp(
              locale: const Locale('tr'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: SocialProfileScreen(profile: other),
            ),
          ),
        );
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(
          find.byKey(const Key('profile-stats-panel')),
          findsOneWidget,
          reason:
              'bu depoda "backend bitmis, lib/ icinde cagri yeri yok" hatasi '
              'defalarca tekrarlandi; panel ekranin gercek agacinda olmali',
        );
        expect(find.text('3/6 kademe'), findsOneWidget);
      },
    );
  });
}
