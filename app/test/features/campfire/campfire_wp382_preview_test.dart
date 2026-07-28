@Tags(['golden'])
library;

// WP-382 sahibin seçtiği kompozisyonun 8 kişilik kanıtı. Bu test golden
// karşılaştırması değildir; gerçek sahneyi PNG olarak üretir ve etiketlerin
// birbirini örtmediğini geometriyle doğrular.
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
import 'package:online_study_room/features/classroom/widgets/campfire_scene.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

class _PreviewOption {
  const _PreviewOption(this.label, this.fireYOffset, this.seatVerticalSpread);

  final String label;
  final double fireYOffset;
  final double seatVerticalSpread;
}

Future<void> _loadPreviewFont() async {
  final loader = FontLoader('Inter');
  loader.addFont(
    File(
      'assets/fonts/Inter-Variable.ttf',
    ).readAsBytes().then((b) => ByteData.view(b.buffer)),
  );
  await loader.load();
}

void main() {
  testWidgets('WP-382 seçilen kompozisyonu tek önizleme karesine yazar', (tester) async {
    await tester.runAsync(_loadPreviewFont);
    const options = [
      _PreviewOption(
        'Seçilen · ateş +45 px · ayrım %25',
        kCampfireFireYOffset,
        kCampfireSeatVerticalSpread,
      ),
    ];
    const cellWidth = 330.0;
    await tester.binding.setSurfaceSize(
      Size(cellWidth * options.length + 32, 360),
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_harness(options, cellWidth));
    await tester.pump();
    final context = tester.element(find.byKey(const ValueKey('wp382-preview')));
    await tester.runAsync(() async {
      for (final asset in CampfireAssets.stackOrder) {
        await precacheImage(AssetImage(asset), context);
      }
    });
    await tester.pumpAndSettle();

    const names = ['Ada', 'Bora', 'Cem', 'Duru', 'Ece', 'Fırat', 'Gül', 'Hale'];
    final labelRects = [for (final name in names) tester.getRect(find.text(name))];
    for (var first = 0; first < labelRects.length; first++) {
      for (var second = first + 1; second < labelRects.length; second++) {
        expect(
          labelRects[first].overlaps(labelRects[second]),
          isFalse,
          reason: '${names[first]} ve ${names[second]} etiketleri örtüşmemeli',
        );
      }
    }

    // Canlı süre etiketi bulunduğundan karşılaştırma golden'ı değil, yalnız
    // sahibin bakacağı çıktı üretilir.
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('wp382-preview')),
      );
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ImageByteFormat.png);
      image.dispose();
      File(
        'test/features/goldens/campfire_wp382_preview.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}

Widget _harness(List<_PreviewOption> options, double cellWidth) {
  const animals = ['rabbit', 'fox', 'bear', 'cat'];
  const names = ['Ada', 'Bora', 'Cem', 'Duru', 'Ece', 'Fırat', 'Gül', 'Hale'];
  final members = [
    for (var index = 0; index < names.length; index++)
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
          for (var index = 0; index < members.length; index++)
            Presence(
              userId: members[index].id,
              status: index.isEven
                  ? PresenceStatus.offline
                  : PresenceStatus.studying,
              todaySeconds: index.isEven ? 0 : 900,
              startedAt: index.isEven ? null : DateTime(2026, 7, 28, 12),
            ),
        ]),
      ),
      groupTodaySecondsProvider.overrideWithValue({
        for (final member in members) member.id: 900,
      }),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        platform: TargetPlatform.android,
        textTheme: ThemeData.dark(
          useMaterial3: true,
        ).textTheme.apply(fontFamily: 'Inter'),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFF141018),
        body: RepaintBoundary(
          key: const ValueKey('wp382-preview'),
          child: ColoredBox(
            color: const Color(0xFF141018),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final option in options)
                    SizedBox(
                      width: cellWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option.label,
                            style: const TextStyle(
                              color: Color(0xFFFFD08A),
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: CampfireScene(
                              clock: () => DateTime(2026, 7, 28, 12, 30),
                              previewFireYOffset: option.fireYOffset,
                              previewSeatVerticalSpread:
                                  option.seatVerticalSpread,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
