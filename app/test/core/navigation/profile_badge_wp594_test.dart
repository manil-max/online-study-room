// 🔴 WP-594/1 — masaüstü sol panelinde ROZET YOKTU.
//
// Ölçüm: `home_shell.dart` bekleyen ödül / okunmamış duyuru / eksik birincil
// grup rozetini yalnız **mobil** koldaki `NavigationBar`a basıyordu. Masaüstü
// kolu (`DesktopHomeShell`) hiçbirini geçmiyordu; yani Windows kullanıcısı
// üç sinyali de HİÇ görmüyordu. Üçü de sessiz kayıptır: rozet görünmezse
// kullanıcı ödülünü almaz, duyuruyu okumaz, grup ilerlemesi hiç işlemez.
//
// Aynı hata WP-550'de yenileme yolunda yaşanmıştı: masaüstü için ikinci bir
// liste tutuluyordu ve eksikti. Bu yüzden buradaki iddia "masaüstünde de rozet
// var" değil, **iki kol da aynı kaynağı kullanıyor**.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/navigation/home_shell.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/theme/warning_tokens.dart';
import 'package:online_study_room/data/models/achievement_reward.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/achievement_reward_provider.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/features/desktop/desktop_home_shell.dart';
import 'package:online_study_room/features/desktop/desktop_navigation_pane.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ProfileTabBadge — rozet kararı', () {
    test('bekleyen ödül sayı rozeti çizer, nokta çizmez', () {
      const badge = ProfileTabBadge(
        pendingRewardCount: 3,
        missingPrimaryGroup: true,
        unreadProfileSignals: 5,
      );
      expect(badge.showsCount, isTrue);
      expect(badge.showsWarningDot, isFalse);
      expect(badge.showsAnnouncementDot, isFalse);
      expect(badge.isVisible, isTrue);
    });

    test('kayıp (eksik grup) duyurudan önceliklidir', () {
      const badge = ProfileTabBadge(
        pendingRewardCount: 0,
        missingPrimaryGroup: true,
        unreadProfileSignals: 4,
      );
      expect(badge.showsWarningDot, isTrue);
      expect(badge.showsAnnouncementDot, isFalse);
    });

    test('yalnız okunmamış duyuru varsa duyuru noktası', () {
      const badge = ProfileTabBadge(
        pendingRewardCount: 0,
        missingPrimaryGroup: false,
        unreadProfileSignals: 1,
      );
      expect(badge.showsAnnouncementDot, isTrue);
      expect(badge.showsWarningDot, isFalse);
    });

    // İki yönlü iddianın diğer ucu: sinyal YOKKEN rozet olmamalı. Bu olmadan
    // "rozeti koşulsuz çiz" sabotajı sessizce geçerdi.
    test('hiçbir sinyal yokken rozet görünmez', () {
      expect(ProfileTabBadge.none.isVisible, isFalse);
      expect(
        const ProfileTabBadge(
          pendingRewardCount: 0,
          missingPrimaryGroup: false,
          unreadProfileSignals: 0,
        ).isVisible,
        isFalse,
      );
    });
  });

  group('masaüstü sol paneli', () {
    Widget shell({
      required ProfileTabBadge badge,
      Size size = const Size(1400, 900),
    }) {
      return MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DesktopHomeShell(
          selectedIndex: 0,
          screens: const [
            ColoredBox(color: Colors.red),
            ColoredBox(color: Colors.orange),
            ColoredBox(color: Colors.yellow),
            ColoredBox(color: Colors.green),
            ColoredBox(color: Colors.blue),
          ],
          onDestinationSelected: (_) {},
          onRefresh: () {},
          profileBadge: badge,
        ),
      );
    }

    /// Panelde **fiilen çizilen** rozetler. Bayrağa değil çizime bakar:
    /// `isLabelVisible: false` bırakan bir "düzeltme" buradan geçemez.
    List<Badge> paneBadges(WidgetTester tester) => tester
        .widgetList<Badge>(
          find.descendant(
            of: find.byType(DesktopNavigationPane),
            matching: find.byType(Badge),
          ),
        )
        .where((badge) => badge.isLabelVisible)
        .toList();

    Future<void> pump(
      WidgetTester tester,
      ProfileTabBadge badge, {
      Size size = const Size(1400, 900),
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(shell(badge: badge, size: size));
      await tester.pumpAndSettle();
    }

    testWidgets('bekleyen ödül sayısı sol panelde görünür', (tester) async {
      await pump(
        tester,
        const ProfileTabBadge(
          pendingRewardCount: 3,
          missingPrimaryGroup: false,
          unreadProfileSignals: 0,
        ),
      );

      expect(paneBadges(tester), hasLength(1));
      expect(
        find.descendant(
          of: find.byType(DesktopNavigationPane),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('okunmamış duyuru sol panelde nokta çizer', (tester) async {
      await pump(
        tester,
        const ProfileTabBadge(
          pendingRewardCount: 0,
          missingPrimaryGroup: false,
          unreadProfileSignals: 2,
        ),
      );
      expect(paneBadges(tester), hasLength(1));
    });

    testWidgets('eksik birincil grup uyarısı panel zemininden ayrışır', (
      tester,
    ) async {
      await pump(
        tester,
        const ProfileTabBadge(
          pendingRewardCount: 0,
          missingPrimaryGroup: true,
          unreadProfileSignals: 0,
        ),
      );

      final badges = paneBadges(tester);
      expect(badges, hasLength(1));

      // WP-358 dersi: uyarı rengi sol panelin KENDİ zemininden türemeli.
      // Alt çubuğun zeminine göre çözmek sessiz bir kontrast hatası olurdu.
      final scheme = Theme.of(
        tester.element(find.byType(DesktopNavigationPane)),
      ).colorScheme;
      expect(
        contrastRatio(
          badges.single.backgroundColor!,
          scheme.surfaceContainerLowest,
        ),
        greaterThanOrEqualTo(kMinSurfaceContrast),
      );
    });

    // 🔴 Asıl regresyon kapısı: hata "rozet yanlış çizildi" değil, "hiç
    // çizilmedi" idi. Sinyal yokken de tek yönlü ölçüm yapılmasın diye iki uç
    // birlikte tutuluyor.
    testWidgets('sinyal yokken panelde hiç rozet yok', (tester) async {
      await pump(tester, ProfileTabBadge.none);
      expect(paneBadges(tester), isEmpty);
    });

    testWidgets('daraltılmış şeritte de rozet çizilir', (tester) async {
      // Dar pencerede etiket gizlenir, yalnız ikon kalır. Rozet orada da
      // çizilmezse sinyal masaüstünde tamamen kaybolur.
      await pump(
        tester,
        const ProfileTabBadge(
          pendingRewardCount: 7,
          missingPrimaryGroup: false,
          unreadProfileSignals: 0,
        ),
        size: const Size(760, 900),
      );

      expect(
        find.descendant(
          of: find.byType(DesktopNavigationPane),
          matching: find.text('Profil'),
        ),
        findsNothing,
        reason: 'kurulum hatalı: bu genişlikte şerit daraltılmış olmalı',
      );
      expect(paneBadges(tester), hasLength(1));
    });

    testWidgets('rozet Profil sekmesine bağlanır, başka sekmeye değil', (
      tester,
    ) async {
      const badge = ProfileTabBadge(
        pendingRewardCount: 2,
        missingPrimaryGroup: false,
        unreadProfileSignals: 0,
      );
      await pump(tester, badge);

      final context = tester.element(find.byType(DesktopNavigationPane));
      final items = DesktopHomeShell.destinations(
        context,
        profileBadge: badge,
      );
      expect(items.last.badge, badge);
      expect(
        items.take(items.length - 1).where((i) => i.badge != null),
        isEmpty,
        reason: 'rozet yalnız Profil sekmesinde olmalı',
      );
    });
  });

  // 🔴 Asıl kablo: `HomeShell`in masaüstü kolu rozeti GERÇEKTEN geçiriyor mu?
  // Yukarıdaki testler `DesktopHomeShell`e rozeti kendileri veriyor; hatanın
  // ta kendisi ise `HomeShell`in vermemesiydi. Bu yüzden burada ağaçtaki
  // gerçek `DesktopHomeShell` widget'ı okunur.
  group('HomeShell → masaüstü kolu kablosu', () {
    /// Masaüstü kolunu kurar, ağaçtaki gerçek [DesktopHomeShell]i verir ve
    /// **testin gövdesi içinde** temizler.
    ///
    /// Platform override'ı `addTearDown` ile geri almak yetmez: flutter_test
    /// değişmezleri gövde biter bitmez denetler, tearDown daha sonra koşar.
    Future<void> withDesktopArm(
      WidgetTester tester, {
      required int pendingRewardCount,
      required bool missingPrimaryGroup,
      required int unreadProfileSignals,
      required void Function(DesktopHomeShell shell) expectations,
    }) async {
      SharedPreferences.setMockInitialValues(const {});
      final prefs = await SharedPreferences.getInstance();

      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 900);
      addTearDown(tester.view.reset);

      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              authStateProvider.overrideWith(
                (ref) => Stream<Profile?>.value(null),
              ),
              pendingAchievementRewardSummaryProvider.overrideWith(
                (ref) async => AchievementRewardSummary(
                  pendingCount: pendingRewardCount,
                  pendingXp: pendingRewardCount * 10,
                ),
              ),
              primaryGroupSelectionMissingProvider.overrideWithValue(
                missingPrimaryGroup,
              ),
              settingsBadgeCountProvider.overrideWithValue(
                unreadProfileSignals,
              ),
            ],
            child: MaterialApp(
              locale: const Locale('tr'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const HomeShell(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expectations(
          tester.widget<DesktopHomeShell>(find.byType(DesktopHomeShell)),
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        debugDefaultTargetPlatformOverride = null;
      }
    }

    testWidgets('bekleyen ödül masaüstü koluna geçer', (tester) async {
      await withDesktopArm(
        tester,
        pendingRewardCount: 4,
        missingPrimaryGroup: false,
        unreadProfileSignals: 0,
        expectations: (shell) {
          expect(shell.profileBadge.pendingRewardCount, 4);
          expect(shell.profileBadge.showsCount, isTrue);
        },
      );
    });

    testWidgets('okunmamış duyuru ve eksik grup da geçer', (tester) async {
      await withDesktopArm(
        tester,
        pendingRewardCount: 0,
        missingPrimaryGroup: true,
        unreadProfileSignals: 3,
        expectations: (shell) {
          expect(shell.profileBadge.missingPrimaryGroup, isTrue);
          expect(shell.profileBadge.unreadProfileSignals, 3);
          expect(shell.profileBadge.showsWarningDot, isTrue);
        },
      );
    });

    // İki yönlü: sinyal yokken masaüstü kolu da rozetsiz kalmalı.
    testWidgets('sinyal yokken masaüstü kolu rozetsiz', (tester) async {
      await withDesktopArm(
        tester,
        pendingRewardCount: 0,
        missingPrimaryGroup: false,
        unreadProfileSignals: 0,
        expectations: (shell) {
          expect(shell.profileBadge.isVisible, isFalse);
        },
      );
    });
  });
}
