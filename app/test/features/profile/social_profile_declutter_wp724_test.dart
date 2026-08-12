import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/achievement.dart';
import 'package:online_study_room/data/models/daily_stat.dart';
import 'package:online_study_room/data/models/gamification_profile.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/gamification_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/features/profile/social_profile_screen.dart';
import 'package:online_study_room/features/profile/widgets/achievement_showcase.dart';
import 'package:online_study_room/features/profile/widgets/social_profile_dialog.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-724 — salt-okunur sosyal profil, WP-712'nin tek satırlık taç/XP
/// özetini korur; büyük XP barını ve altı renkli kademe şeridini tekrarlamaz.
void main() {
  final now = DateTime.utc(2026, 8, 12);
  final me = Profile(id: 'me', displayName: 'Ben', createdAt: now);
  final other = Profile(
    id: 'other',
    displayName: 'Komşu',
    dailyGoalMinutes: 60,
    createdAt: now,
  );
  final gamification = GamificationProfile(
    userId: other.id,
    streakFreezes: 0,
    xp: 500000,
    crownRank: 'emerald_sage',
    selectedBadges: const [],
    createdAt: now,
    updatedAt: now,
  );

  List<Override> overrides() => [
    authStateProvider.overrideWith((ref) => Stream.value(me)),
    gamificationProfileProvider(
      other.id,
    ).overrideWith((ref) => Stream.value(gamification)),
    userAchievementsProvider(
      other.id,
    ).overrideWith((ref) => Stream.value(const <UserAchievement>[])),
    groupMembersProvider.overrideWith((ref) => Stream.value([me, other])),
    groupDailyStatsProvider.overrideWith(
      (ref) =>
          Stream.value([DailyStat(userId: other.id, day: now, seconds: 7200)]),
    ),
  ];

  Widget app(Widget home) => ProviderScope(
    overrides: overrides(),
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );

  void use360DpSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  void expectDeclutteredShowcase(WidgetTester tester) {
    final showcase = find.byType(AchievementShowcase);
    final crownGate = find.descendant(
      of: showcase,
      matching: find.byKey(const ValueKey('crown-header-tiers-gate')),
    );

    expect(showcase, findsOneWidget);
    expect(
      find.descendant(
        of: showcase,
        matching: find.byKey(const ValueKey('crown-xp-progress-section')),
      ),
      findsNothing,
      reason:
          'salt-okunur profilde büyük LinearProgressIndicator bölümü çizilmemeli',
    );
    expect(
      find.descendant(
        of: showcase,
        matching: find.byKey(const ValueKey('crown-strip-tiers-gate')),
      ),
      findsNothing,
      reason: 'salt-okunur profilde altı renkli kademe şeridi çizilmemeli',
    );
    expect(crownGate, findsOneWidget);
    expect(find.text('Zümrüt Taç'), findsOneWidget);
    expect(find.text('500000 XP'), findsOneWidget);
    expect(
      tester.getSize(crownGate).height,
      greaterThanOrEqualTo(48),
      reason: 'kademeler keşif kapısı erişilebilir dokunma alanını korumalı',
    );

    final semantics = tester.getSemantics(crownGate).getSemanticsData();
    expect(semantics.flagsCollection.isButton, isTrue);
    expect(semantics.hasAction(ui.SemanticsAction.tap), isTrue);
    expect(semantics.label, contains('Zümrüt Taç'));
    expect(semantics.label, contains('500000 XP'));
  }

  testWidgets(
    'salt-okunur tam profil 360 dp’de taşmadan tek taç/XP satırı çizer',
    (tester) async {
      use360DpSurface(tester);
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(app(SocialProfileScreen(profile: other)));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(tester.takeException(), isNull);
      expectDeclutteredShowcase(tester);
      final crownRect = tester.getRect(
        find.byKey(const ValueKey('crown-header-tiers-gate')),
      );
      expect(crownRect.left, greaterThanOrEqualTo(0));
      expect(crownRect.right, lessThanOrEqualTo(360));
      semantics.dispose();
    },
  );

  testWidgets(
    'salt-okunur profil diyaloğu ayrı kolda aynı sade/a11y sözleşmesini taşır',
    (tester) async {
      use360DpSurface(tester);
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        app(
          Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  key: const Key('open-social-profile-dialog'),
                  onPressed: () => SocialProfileDialog.show(context, other),
                  child: const Text('Profili aç'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open-social-profile-dialog')));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(find.byType(SocialProfileDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      expectDeclutteredShowcase(tester);
      final dialogRect = tester.getRect(find.byType(Dialog));
      expect(dialogRect.left, greaterThanOrEqualTo(0));
      expect(dialogRect.right, lessThanOrEqualTo(360));
      await tester.tap(find.byKey(const ValueKey('crown-header-tiers-gate')));
      await tester.pumpAndSettle();
      expect(
        find.text('Tüm kademeler'),
        findsOneWidget,
        reason: 'sadeleştirme taç/kademe keşif kapısını kaldırmamalı',
      );
      semantics.dispose();
    },
  );
}
