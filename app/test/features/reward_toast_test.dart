import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/profile/widgets/reward_toast.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

void main() {
  Widget app({
    required int count,
    required int xp,
    String? rank,
    VoidCallback? onOpen,
    VoidCallback? onRefresh,
    bool reduceMotion = false,
  }) {
    return MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: RewardToast(
            pendingCount: count,
            pendingXp: xp,
            crownRank: rank,
            onOpenProfile: onOpen ?? () {},
            onRefresh: onRefresh ?? () {},
          ),
        ),
      ),
    );
  }

  testWidgets('banner açar, kapanır ve badge verisini değiştirmez', (
    tester,
  ) async {
    var opened = 0;
    var refreshes = 0;
    await tester.pumpWidget(
      app(
        count: 3,
        xp: 900,
        onOpen: () => opened++,
        onRefresh: () => refreshes++,
      ),
    );

    expect(find.text('3 ödül hazır · 900 XP'), findsOneWidget);
    await tester.tap(find.text('Topla'));
    expect(opened, 1);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('3 ödül hazır · 900 XP'), findsNothing);

    await tester.pump(const Duration(seconds: 4));
    expect(refreshes, 1);
  });

  testWidgets('yeni pending imzası debounce sonrası bannerı yeniden açar', (
    tester,
  ) async {
    await tester.pumpWidget(app(count: 1, xp: 100));
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('1 ödül hazır · 100 XP'), findsNothing);

    await tester.pumpWidget(app(count: 2, xp: 300));
    await tester.pump(const Duration(milliseconds: 249));
    expect(find.text('2 ödül hazır · 300 XP'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.text('2 ödül hazır · 300 XP'), findsOneWidget);
  });

  testWidgets(
    'taç yükselişi ilk veri yükünde değil değişimde bir kez kutlanır',
    (tester) async {
      await tester.pumpWidget(
        app(count: 0, xp: 0, rank: 'bronze_beginner', reduceMotion: true),
      );
      expect(find.text('Bronz Taç'), findsNothing);

      await tester.pumpWidget(
        app(count: 0, xp: 0, rank: 'silver_learner', reduceMotion: true),
      );
      await tester.pump();
      expect(find.text('Gümüş Taç'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1800));
      expect(find.text('Gümüş Taç'), findsNothing);

      await tester.pumpWidget(
        app(count: 0, xp: 0, rank: 'silver_learner', reduceMotion: true),
      );
      await tester.pump();
      expect(find.text('Gümüş Taç'), findsNothing);
    },
  );

  testWidgets('uzun Almanca metin 360 px genişlikte taşmaz', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: RewardToast(
            pendingCount: 101,
            pendingXp: 123456,
            onOpenProfile: () {},
            onRefresh: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
