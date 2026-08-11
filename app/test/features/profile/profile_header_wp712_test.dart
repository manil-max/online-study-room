import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/stats/gamification.dart';
import 'package:online_study_room/core/stats/progression_visuals.dart';
import 'package:online_study_room/core/widgets/crowned_avatar.dart';
import 'package:online_study_room/data/models/achievement.dart';
import 'package:online_study_room/data/models/daily_stat.dart';
import 'package:online_study_room/data/models/gamification_profile.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/gamification_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/features/profile/social_profile_screen.dart';
import 'package:online_study_room/features/profile/widgets/gamification_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WP-712 — profil başlığı + taç/XP bölümü.
///
/// Sahip emri (birebir):
///  1. "pp → stats → isim" sırası yanlış; isim pp'nin ALTINA taşınsın.
///  2. Bölüm verimsiz, her şey üst üste dizilmiş.
///  3. Ünvan/rütbe etiketi sola yaslı; ortalansın.
///  4. XP barı ve altındaki renkli kademe şeridi SİLİNSİN (hem başkasının
///     profilinde hem genel profilde).
///  5. Kalan taç satırındaki XP `XP/XP` biçimine dönsün — barı kaldırdığımız
///     için "sonraki eşiğe ne kadar kaldı" bilgisini artık O satır taşır.
///  6. Satıra basınca kademeler açılmaya devam etsin.
///  7. Açılan kademe listesinde açılmamış taçlar SİLİK olsun; mevcut taç net
///     biçimde ayrılsın.
///
/// Bu dosya iddiaları KOORDİNATLA ölçer; "widget ağacında şu sırada" demez.
void main() {
  final now = DateTime.utc(2026, 8, 11);

  Future<Widget> gamificationCardScope({
    required int xp,
    required String rank,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final profile = Profile(id: 'u1', displayName: 'Test', createdAt: now);
    final gam = GamificationProfile(
      userId: 'u1',
      streakFreezes: 0,
      xp: xp,
      crownRank: rank,
      selectedBadges: const [],
      createdAt: now,
      updatedAt: now,
    );
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith((ref) => Stream.value(profile)),
        gamificationSummaryProvider.overrideWith(
          (ref) => AsyncValue.data(
            GamificationSummary(
              profile: gam,
              freezeAwareStreak: const FreezeAwareStreak(
                streak: 0,
                freezesUsed: 0,
                protectedDays: [],
              ),
              achievements: const [],
              crownTier: CrownTier.none,
              totalSeconds: 0,
              sessionCount: 0,
            ),
          ),
        ),
        userAchievementsProvider.overrideWith(
          (ref, userId) => Stream.value(const <UserAchievement>[]),
        ),
        gamificationProgressSyncProvider.overrideWith((ref) async {}),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: GamificationCard(),
          ),
        ),
      ),
    );
  }

  group('genel profil kartı — bar ve yüzde gitti, XP/XP kaldı', () {
    testWidgets('XP barı yok; taç satırı XP/XP gösterir', (tester) async {
      await tester.pumpWidget(
        await gamificationCardScope(xp: 30000, rank: 'silver_learner'),
      );
      await tester.pumpAndSettle();

      expect(
        find.byType(LinearProgressIndicator),
        findsNothing,
        reason: 'sahip maddesi 4: alttaki bar silinecek',
      );
      expect(find.textContaining('Sonraki taç'), findsNothing);
      expect(
        find.text('30000 / 75000 XP'),
        findsOneWidget,
        reason: 'sahip maddesi 5: XP/XP biçimi',
      );
      expect(
        find.textContaining('%'),
        findsNothing,
        reason: 'yüzde metni barla birlikte gitti',
      );
    });

    testWidgets('taç satırına basınca kademeler açılır (madde 6)', (
      tester,
    ) async {
      await tester.pumpWidget(
        await gamificationCardScope(xp: 30000, rank: 'silver_learner'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tüm kademeler'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('crown-xp-header')));
      await tester.pumpAndSettle();
      expect(find.text('Tüm kademeler'), findsOneWidget);
    });

    testWidgets('taç satırı içeriği ORTALI (madde 3)', (tester) async {
      await tester.pumpWidget(
        await gamificationCardScope(xp: 30000, rank: 'silver_learner'),
      );
      await tester.pumpAndSettle();

      final row = tester.getRect(find.byKey(const ValueKey('crown-xp-header')));
      final chip = tester.getRect(find.byKey(const ValueKey('crown-xp-value')));
      final label = tester.getRect(find.text('Gümüş Taç'));
      // Soldaki rütbe etiketi ile sağdaki XP rozeti satırın merkezine göre
      // simetrik durmalı; eski düzende ikisi de sola yaslıydı.
      final leftGap = label.left - row.left;
      final rightGap = row.right - chip.right;
      expect(
        (leftGap - rightGap).abs(),
        lessThan(24),
        reason:
            'ortalama iddiası: sol boşluk $leftGap, sağ boşluk $rightGap '
            '(sola yaslıysa fark büyür)',
      );
    });

    testWidgets('360 dp genişlikte taşma yok', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        // En uzun XP metni: 6 + 7 basamak.
        await gamificationCardScope(xp: 500000, rank: 'emerald_sage'),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final row = tester.getRect(find.byKey(const ValueKey('crown-xp-header')));
      expect(row.left, greaterThanOrEqualTo(0));
      expect(row.right, lessThanOrEqualTo(360));
    });

    testWidgets('en yüksek taçta bilgi kaybolmaz: toplam XP + "Şu an" işareti', (
      tester,
    ) async {
      await tester.pumpWidget(
        await gamificationCardScope(xp: 1200000, rank: 'immortal_legend'),
      );
      await tester.pumpAndSettle();

      expect(find.text('1200000 XP'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('crown-xp-header')));
      await tester.pumpAndSettle();
      // "En yüksek taçtayım" bilgisi kademe sayfasında erişilebilir kalır.
      expect(find.text('Şu an'), findsOneWidget);
    });
  });

  group('kademe sayfası — silik/açık/mevcut ayrımı (madde 7)', () {
    testWidgets('açılmamış taç silik, açılmış tam, mevcut kalın kenarlı', (
      tester,
    ) async {
      await tester.pumpWidget(
        await gamificationCardScope(xp: 30000, rank: 'silver_learner'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('crown-xp-header')));
      await tester.pumpAndSettle();

      double opacityOf(int tier) => tester
          .widget<Opacity>(find.byKey(ValueKey('crown-tier-row-$tier')))
          .opacity;

      double borderOf(int tier) {
        final container = tester.widget<Container>(
          find.descendant(
            of: find.byKey(ValueKey('crown-tier-row-$tier')),
            matching: find.byType(Container),
          ),
        );
        return ((container.decoration! as BoxDecoration).border! as Border)
            .top
            .width;
      }

      // 30000 XP → 2. kademe (Gümüş) mevcut; 1 açık, 3..6 kilitli.
      expect(opacityOf(1), 1.0);
      expect(opacityOf(2), 1.0);
      for (final tier in const [3, 4, 5, 6]) {
        expect(
          opacityOf(tier),
          kCrownTierLockedOpacity,
          reason: 'açılmamış taç silik olmalı (tier $tier)',
        );
        expect(opacityOf(tier), lessThan(opacityOf(1)));
      }
      expect(
        borderOf(2),
        greaterThan(borderOf(1)),
        reason: 'mevcut taç açılmış taçtan da ayrışmalı',
      );
      expect(find.text('Şu an'), findsOneWidget);
    });
  });

  group('sosyal profil sırası — pp → isim → istatistik (madde 1)', () {
    testWidgets('isim avatarın ALTINDA, istatistik panelinin ÜSTÜNDE', (
      tester,
    ) async {
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
            gamificationProfileProvider('other').overrideWith(
              (ref) => Stream.value(
                GamificationProfile(
                  userId: 'other',
                  streakFreezes: 0,
                  xp: 30000,
                  crownRank: 'silver_learner',
                  selectedBadges: const [],
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
            ),
            userAchievementsProvider(
              'other',
            ).overrideWith((ref) => Stream.value(const <UserAchievement>[])),
            groupMembersProvider.overrideWith(
              (ref) => Stream.value([me, other]),
            ),
            groupDailyStatsProvider.overrideWith(
              (ref) => Stream.value([
                DailyStat(
                  userId: 'other',
                  day: DateTime(2026, 8, 8),
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

      final avatar = tester.getCenter(find.byType(CrownedAvatar).first).dy;
      final name = tester
          .getCenter(find.byKey(const Key('social-profile-display-name')))
          .dy;
      final stats = tester
          .getCenter(find.byKey(const Key('profile-stats-panel')))
          .dy;

      expect(
        avatar,
        lessThan(name),
        reason:
            'isim avatarın altında olmalı (ölçüm: avatar $avatar, isim $name)',
      );
      expect(
        name,
        lessThan(stats),
        reason:
            'istatistik paneli ismin ALTINDA olmalı (ölçüm: isim $name, '
            'istatistik $stats)',
      );
      expect(
        find.text('Komşu'),
        findsOneWidget,
        reason: 'isim iki kolda birden çizilmemeli (tek kaynak)',
      );
    });
  });
}
