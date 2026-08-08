import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/gamification_profile.dart';
import 'package:online_study_room/features/profile/widgets/achievement_showcase.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-512: XP eşikleri sayfasının (`showCrownTiers`) tek kapısı Profil'deki
/// avatarın tacıydı; kullanıcı onu bulamıyordu. Başarımlar ekranındaki rütbe
/// satırı ve altındaki 6 kademe şeridi ikinci kapı oldu.
///
/// `1000000 XP` yalnız kademe sayfasında yazılır (Immortal eşiği) — bu yüzden
/// "sayfa gerçekten açıldı" kanıtı olarak kullanılıyor.
void main() {
  final now = DateTime(2026, 8, 8);

  GamificationProfile profile() => GamificationProfile(
    userId: 'u1',
    streakFreezes: 0,
    xp: 30000,
    crownRank: 'silver_learner',
    selectedBadges: const [],
    createdAt: now,
    updatedAt: now,
  );

  Widget harness() => MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: AchievementShowcase(
          gamification: profile(),
          userAchievements: const [],
          isSelf: true,
          showCatalog: false,
        ),
      ),
    ),
  );

  testWidgets('rütbe satırına dokununca kademe sayfası açılır', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.text('Tüm kademeler'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('crown-header-tiers-gate')));
    await tester.pumpAndSettle();

    expect(find.text('Tüm kademeler'), findsOneWidget);
    expect(find.text('1000000 XP'), findsOneWidget);
  });

  testWidgets('kademe şeridine dokununca da aynı sayfa açılır', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('crown-strip-tiers-gate')));
    await tester.pumpAndSettle();

    expect(find.text('Tüm kademeler'), findsOneWidget);
    expect(find.text('1000000 XP'), findsOneWidget);
  });

  testWidgets('rütbe satırı keşfedilebilir ipucu ikonu taşır', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    final gate = find.byKey(const ValueKey('crown-header-tiers-gate'));
    expect(
      find.descendant(of: gate, matching: find.byIcon(Icons.info_outline)),
      findsOneWidget,
    );
    // 48 dp dokunma alanı (DoD erişilebilirlik maddesi).
    expect(tester.getSize(gate).height, greaterThanOrEqualTo(48));
  });
}
