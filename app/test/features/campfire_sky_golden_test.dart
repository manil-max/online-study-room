@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/presence.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/presence_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/features/classroom/widgets/campfire/campfire_assets.dart';
import 'package:online_study_room/features/classroom/widgets/campfire_layout.dart';
import 'package:online_study_room/features/classroom/widgets/campfire_scene.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

void main() {
  for (final scenario in <({String name, DateTime time})>[
    (name: 'day', time: DateTime(2026, 7, 26, 12, 30)),
    // WP-377: çıpalar artık mevsime göre kayıyor. 26 Temmuz'da gerçek
    // günbatımı ~20:16, sivil karanlık ~20:46 — eski 19:00 artık tam gündüz.
    (name: 'transition', time: DateTime(2026, 7, 26, 20, 30)),
    (name: 'night', time: DateTime(2026, 7, 26, 23)),
  ]) {
    testWidgets('kamp gökyüzü golden · ${scenario.name}', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 380));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_goldenHarness(scenario.time));
      await tester.pump();
      final imageContext = tester.element(
        find.byKey(const ValueKey('campfire-golden-boundary')),
      );
      await tester.runAsync(() async {
        for (final asset in CampfireAssets.stackOrder) {
          await precacheImage(AssetImage(asset), imageContext);
        }
      });
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(const ValueKey('campfire-golden-boundary')),
        matchesGoldenFile('goldens/campfire_sky_${scenario.name}.png'),
      );

      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final memberCount in [1, 4, 8]) {
    testWidgets('kamp telefonu golden · $memberCount kişi', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _goldenHarness(
          DateTime(2026, 7, 26, 12, 30),
          memberCount: memberCount,
          platform: TargetPlatform.android,
          sceneWidth: 360,
        ),
      );
      await tester.pump();
      final imageContext = tester.element(
        find.byKey(const ValueKey('campfire-golden-boundary')),
      );
      await tester.runAsync(() async {
        for (final asset in CampfireAssets.stackOrder) {
          await precacheImage(AssetImage(asset), imageContext);
        }
      });
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(const ValueKey('campfire-golden-boundary')),
        matchesGoldenFile('goldens/campfire_phone_$memberCount.png'),
      );

      await tester.pumpWidget(const SizedBox());
    });
  }
}

Widget _goldenHarness(
  DateTime localNow, {
  int memberCount = 2,
  TargetPlatform platform = TargetPlatform.windows,
  double sceneWidth = 400,
}) {
  final animals = ['rabbit', 'fox', 'bear', 'cat'];
  final members = [
    for (var index = 0; index < memberCount; index++)
      Profile(
        id: 'u${index + 1}',
        displayName: [
          'Ada',
          'Bora',
          'Cem',
          'Duru',
          'Ece',
          'Fırat',
          'Gül',
          'Hale',
        ][index],
        animal: animals[index % animals.length],
        createdAt: DateTime(2026, 1, 1),
      ),
  ];
  return ProviderScope(
    overrides: [
      groupMembersProvider.overrideWith((ref) => Stream.value(members)),
      groupPresenceProvider.overrideWith(
        (ref) => Stream.value([
          for (var index = 0; index < memberCount; index++)
            Presence(
              userId: 'u${index + 1}',
              status: index.isEven
                  ? PresenceStatus.offline
                  : PresenceStatus.studying,
              todaySeconds: index.isEven ? 0 : 900,
              startedAt: index.isEven ? null : DateTime(2026, 7, 26, 12),
            ),
        ]),
      ),
      groupTodaySecondsProvider.overrideWithValue({
        for (var index = 0; index < memberCount; index++)
          'u${index + 1}': index.isEven ? 0 : 900,
      }),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(useMaterial3: true).copyWith(platform: platform),
      // 🔴 Golden kareler deterministik olmak ZORUNDA. Reduce-motion olmadan
      // sahne alev fazını (`t`) canlı tutar ve **3+ çalışan** olduğunda
      // `CampfireActivity.high` köz parçacıklarını da çizer
      // (`layered_campfire_fire.dart` `_EmberSpritePainter`). Parçacıkların yeri
      // `t`'ye bağlıdır; yakalanan kare koşuma göre değişir.
      //
      // Bu yüzden yalnız 8 kişi golden'ı kararsızdı: 1 kişi `empty`, 4 kişi ve
      // gökyüzü senaryoları `low` kalıyor, hiçbiri köz üretmiyor. 8 kişide 4
      // kişi çalışıyor → tek `high` senaryo. Sonuç: aynı makinede izole koşumda
      // geçen, tam pakette düşen bir golden ve CI'da sınırda (%0.50) bir fark.
      //
      // Çözüm toleransı yükseltmek DEĞİL (o gerçek regresyonu gizler,
      // `flutter_test_config.dart` bunu açıkça yasaklar) — kareyi sabitlemek.
      // Reduce-motion `t`'yi 0.55'e sabitler ve köz parçacıklarını kapatır.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFF100D14),
        body: Center(
          child: RepaintBoundary(
            key: const ValueKey('campfire-golden-boundary'),
            child: SizedBox(
              width: sceneWidth,
              // WP-377: kart yüksekliği artık tek sabitten gelir; golden kutusu
              // sahneden büyük kalırsa kare boş bant taşır.
              height: kCampfireSceneHeight,
              child: MediaQuery(
                data: const MediaQueryData(disableAnimations: true),
                child: CampfireScene(clock: () => localNow),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
