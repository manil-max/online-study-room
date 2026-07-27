@Tags(['golden'])
library;

// WP-377 parametrik önizleme.
//
// Sahibin isteği sayısaldı: "hafif halkayı genişlet" ve "gökyüzü çok uzun,
// kartı biraz yukarıdan kesmek lazım". Sayıyı tahmin etmek yerine adayları
// yan yana basıyoruz; sahip birini seçer, seçilen değer
// `campfire_layout.dart`teki kanonik sabitlere yazılır ve golden'a bağlanır.
//
// Bu dosya bir kabul testi DEĞİLDİR — yalnız `goldens/` altına karşılaştırma
// karesi üretir. `flutter test --tags golden` ile koşar.
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

/// Gökyüzünü **üstten** kırpan varyant.
///
/// Doğru ölçüt "ateş aynı piksel Y'de kalsın" değil, **zemin bandı aynı kalsın**:
/// kart kısalırken içerik yukarı gelmeli, aşağı taşıp kırpılmamalı. Bu yüzden
/// zeminin alt kenara uzaklığı (`h · (1 − groundY)`) sabit tutulur.
({double height, double groundY}) croppedSky(double cropPx) {
  // Kırpma öncesi kompozisyon. Sabitler sahip seçimiyle değiştiği için önizleme
  // kendi tabanını taşır; aksi hâlde kare kendi kendine kayardı.
  const baseHeight = 360.0;
  const baseGroundY = 0.66;
  const groundBand = baseHeight * (1 - baseGroundY);
  final height = baseHeight - cropPx;
  return (height: height, groundY: 1 - groundBand / height);
}

/// Golden karesinde etiketlerin kutu değil **yazı** çıkması için gömülü fontu
/// yükler. Test ortamı varsayılan olarak boş bir font kullanır.
Future<void> loadPreviewFont() async {
  final loader = FontLoader('Inter');
  loader.addFont(
    File(
      'assets/fonts/Inter-Variable.ttf',
    ).readAsBytes().then((b) => ByteData.view(b.buffer)),
  );
  await loader.load();
}

void main() {
  testWidgets('WP-377 önizleme karesini üretir (iddia değil, çıktı)', (
    tester,
  ) async {
    await tester.runAsync(loadPreviewFont);
    // Sahip 2026-07-28'de en geniş halkayı ve daha derin kırpmayı seçti; nihai
    // değerler `campfire_layout.dart` sabitlerinde. Kare, seçilenin yanında bir
    // eski ve bir ara kademe göstererek karşılaştırmayı korur.
    const ringOptions = <double>[1.2, 1.35, kCampfirePhoneRingWidthMultiplier];
    const cropOptions = <double>[0, 60, 85];

    const cellWidth = 300.0;
    await tester.binding.setSurfaceSize(
      Size(cellWidth * ringOptions.length + 24, 1320),
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _previewHarness(
        ringOptions: ringOptions,
        cropOptions: cropOptions,
        cellWidth: cellWidth,
      ),
    );
    await tester.pump();
    final imageContext = tester.element(
      find.byKey(const ValueKey('campfire-preview-boundary')),
    );
    await tester.runAsync(() async {
      for (final asset in CampfireAssets.stackOrder) {
        await precacheImage(AssetImage(asset), imageContext);
      }
    });
    await tester.pumpAndSettle();

    // 🔴 Bilerek `matchesGoldenFile` DEĞİL. Sahnedeki canlı süre etiketleri
    // `SecondTicker` üzerinden duvar saatini okur; 9 hücrelik bu karede
    // koşumlar arası fark %0.5'lik golden toleransını aşıyor ve önizleme
    // CI'da kararsız bir "test" hâline geliyordu. Burası bir iddia değil,
    // sahibin bakacağı bir **çıktıdır** — o yüzden yalnız yazılır.
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('campfire-preview-boundary')),
      );
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ImageByteFormat.png);
      image.dispose();
      File(
        'test/features/goldens/campfire_wp377_preview.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    });

    await tester.pumpWidget(const SizedBox());
  });
}

Widget _previewHarness({
  required List<double> ringOptions,
  required List<double> cropOptions,
  required double cellWidth,
}) {
  const memberCount = 8;
  final animals = ['rabbit', 'fox', 'bear', 'cat'];
  final names = ['Ada', 'Bora', 'Cem', 'Duru', 'Ece', 'Fırat', 'Gül', 'Hale'];
  final members = [
    for (var index = 0; index < memberCount; index++)
      Profile(
        id: 'u${index + 1}',
        displayName: names[index],
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
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        platform: TargetPlatform.android,
        // Sahnedeki isim etiketleri de kutu değil yazı çıksın.
        textTheme: ThemeData.dark(
          useMaterial3: true,
        ).textTheme.apply(fontFamily: 'Inter'),
      ),
      // Golden'lardaki kararsızlık nedeni: alev fazı ve köz parçacıkları
      // gerçek zamana bağlı. Reduce-motion kareyi sabitler.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFF100D14),
        body: SingleChildScrollView(
          child: RepaintBoundary(
            key: const ValueKey('campfire-preview-boundary'),
            // RepaintBoundary yalnız kendi alt ağacını yakalar; Scaffold'un
            // zemini kareye girmiyordu ve beyaz etiketler beyaz zeminde
            // kayboluyordu.
            child: ColoredBox(
              color: const Color(0xFF141018),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final crop in cropOptions) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 6),
                        child: Text(
                          crop == 0
                              ? 'Gökyüzü: ESKİ (kırpma yok · yükseklik 360)'
                              : 'Gökyüzü: üstten ${crop.toInt()} px kırpık '
                                    '(yükseklik '
                                    '${croppedSky(crop).height.toInt()})'
                                    '${croppedSky(crop).height == kCampfireSceneHeight ? "  <- SECILEN" : ""}',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < ringOptions.length; i++)
                            SizedBox(
                              width: cellWidth,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${String.fromCharCode(65 + i)} · halka '
                                    '${ringOptions[i].toStringAsFixed(2)}'
                                    '${ringOptions[i] == kCampfirePhoneRingWidthMultiplier ? "  <- SECILEN" : ""}',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      color: Color(0xFFFFD08A),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: MediaQuery(
                                      data: const MediaQueryData(
                                        disableAnimations: true,
                                      ),
                                      child: CampfireScene(
                                        clock: () =>
                                            DateTime(2026, 7, 26, 12, 30),
                                        ringWidthScale: ringOptions[i],
                                        sceneHeight: crop == 0
                                            ? kCampfireSceneHeight
                                            : croppedSky(crop).height,
                                        groundYFactor: crop == 0
                                            ? kCampfireGroundYFactor
                                            : croppedSky(crop).groundY,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
