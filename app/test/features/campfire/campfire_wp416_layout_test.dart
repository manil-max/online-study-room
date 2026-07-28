import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/campfire_preview.dart';
import 'package:online_study_room/data/models/presence.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/presence_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/features/classroom/widgets/camp_critter.dart';
import 'package:online_study_room/features/classroom/widgets/campfire_layout.dart';
import 'package:online_study_room/features/classroom/widgets/campfire_scene.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// v55'te telefonda ölçülen yeşil bant. Sahip cihazda "çok az" dedi; WP-416
/// başlangıç değeri bunun **iki katı**dır.
const double _v55PhoneGreenArea = 68.4775;

const _names = ['Ada', 'Bora', 'Cem', 'Duru', 'Ece', 'Kaan', 'Lale', 'Mine'];

Widget _harness({
  required int memberCount,
  CampfireTuning tuning = const CampfireTuning(),
  double width = 360,
  TargetPlatform platform = TargetPlatform.android,
}) {
  final members = [
    for (var index = 0; index < memberCount; index++)
      Profile(
        id: 'u$index',
        displayName: _names[index % _names.length],
        createdAt: DateTime(2026, 1, 1),
      ),
  ];
  return ProviderScope(
    overrides: [
      groupMembersProvider.overrideWith((ref) => Stream.value(members)),
      groupPresenceProvider.overrideWith(
        (ref) => Stream.value([
          for (final member in members)
            Presence(
              userId: member.id,
              status: PresenceStatus.offline,
              todaySeconds: 0,
            ),
        ]),
      ),
      groupTodaySecondsProvider.overrideWithValue({
        for (final member in members) member.id: 0,
      }),
    ],
    child: MaterialApp(
      theme: ThemeData(platform: platform),
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: Scaffold(
            body: SizedBox(
              width: width,
              child: CampfireScene(
                clock: () => DateTime(2026, 7, 28, 12),
                tuning: tuning,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('WP-416 yeşil alan', () {
    test('telefon profili sahibin istediği 2× bandı üretir', () {
      const profile = CampfireViewportProfile.phone();
      final green = campfireGreenAreaHeight(
        sceneHeight: kCampfireSceneHeight,
        groundYFactor: profile.groundYFactor,
        fireYOffset: profile.fireYOffset,
        fireYPixelOffset: kCampfireFireYOffset,
      );

      expect(green, closeTo(kCampfirePhoneGreenAreaHeight, 0.05));
      expect(
        green,
        closeTo(_v55PhoneGreenArea * 2, 0.1),
        reason: 'sahip "şu anki px boyutu 2 katına çıkmalı" dedi',
      );
    });

    test('masaüstü kompozisyonu değişmedi (sahip v55\'te onayladı)', () {
      const profile = CampfireViewportProfile.desktop();
      expect(profile.groundYFactor, kCampfireGroundYFactor);
      expect(
        campfireGreenAreaHeight(
          sceneHeight: kCampfireSceneHeight,
          groundYFactor: profile.groundYFactor,
          fireYOffset: profile.fireYOffset,
          fireYPixelOffset: kCampfireFireYOffset,
        ),
        closeTo(93.3, 0.1),
      );
    });

    test('px ↔ oran çevrimi her iki yönde de aynı sayıyı verir', () {
      for (final target in const [80.0, 137.0, 180.0]) {
        final groundY = campfireGroundYFactorForGreenArea(
          sceneHeight: kCampfireSceneHeight,
          greenAreaHeight: target,
          fireYOffset: 0.09,
          fireYPixelOffset: kCampfireFireYOffset,
        );
        expect(
          campfireGreenAreaHeight(
            sceneHeight: kCampfireSceneHeight,
            groundYFactor: groundY,
            fireYOffset: 0.09,
            fireYPixelOffset: kCampfireFireYOffset,
          ),
          closeTo(target, 0.001),
        );
      }
    });

    test('ayarlanan px değeri sahnenin kullanacağı çıpaya dönüşür', () {
      const tuning = CampfireTuning(greenAreaHeight: 160);
      const phone = CampfireViewportProfile.phone();
      expect(tuning.resolvedGreenAreaHeight(phone), closeTo(160, 0.001));
      // Açık çıpa verilirse px'ten önce gelir (WP-377 golden varyantları).
      const pinned = CampfireTuning(greenAreaHeight: 160, groundYFactor: 0.5);
      expect(pinned.resolvedGroundYFactor(phone), 0.5);
    });
  });

  group('WP-416 kalabalık sahne', () {
    for (final memberCount in const [8, 6]) {
      testWidgets('$memberCount kişide isim etiketleri örtüşmez', (
        tester,
      ) async {
        await tester.pumpWidget(_harness(memberCount: memberCount));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final rects = [
          for (var index = 0; index < memberCount; index++)
            tester.getRect(find.text(_names[index])),
        ];
        for (var first = 0; first < rects.length; first++) {
          for (var second = first + 1; second < rects.length; second++) {
            expect(
              rects[first].overlaps(rects[second]),
              isFalse,
              reason:
                  '${_names[first]} ve ${_names[second]} etiketleri örtüşüyor',
            );
          }
        }

        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('8 kişide en öndeki hayvanın ayakları kelepçeye dayanmaz', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(memberCount: 8));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final sceneRect = tester.getRect(find.byType(CampfireScene));
      for (var index = 0; index < 8; index++) {
        final body = tester.getRect(find.byKey(ValueKey('b-u$index')));
        expect(body.bottom, lessThan(sceneRect.bottom));
        // 🔴 v55 hatası: alt sınırda `box * (1 - anchor)` düşülmediği için ayak
        // `ClipRRect` ile kesiliyordu. Kelepçe hâlâ doğru (kesme yok) ama artık
        // 2× yeşil alan sayesinde kelepçeye **dayanmıyoruz** — gövde alt
        // kenardan gerçekten uzakta duruyor.
        expect(
          body.bottom,
          lessThan(sceneRect.bottom - 8),
          reason: 'u$index dikey kelepçeye dayanmış (yeşil alan yetmiyor)',
        );
      }

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('sekiz kişilik sahne 2× yeşil alanı gerçekten çiziyor', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(memberCount: 8));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final forestFinder = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is GroundedForestPainter,
      );
      final forest =
          tester.widget<CustomPaint>(forestFinder).painter!
              as GroundedForestPainter;
      // Ufuk, painter'ın **kendi** kutusunda ölçülür: kartın 1 px'lik kenarlığı
      // çizim alanını sahne yüksekliğinden 2 px kısaltır.
      final paintedHeight = tester.getRect(forestFinder).height;
      expect(paintedHeight, closeTo(kCampfireSceneHeight - 2, 0.01));
      expect(
        paintedHeight - forest.horizonY,
        closeTo(kCampfirePhoneGreenAreaHeight, 2.5),
      );

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('WP-416 ayar kolları', () {
    testWidgets('isim yazı boyutu kolu etiketi büyütür', (tester) async {
      await tester.pumpWidget(_harness(memberCount: 2));
      await tester.pump();
      final baseline = tester.widget<Text>(find.text('Ada')).style!.fontSize;

      await tester.pumpWidget(
        _harness(
          memberCount: 2,
          tuning: const CampfireTuning(labelFontSize: 16),
        ),
      );
      await tester.pump();
      final tuned = tester.widget<Text>(find.text('Ada')).style!.fontSize;

      expect(baseline, kCampfireLabelFontSize);
      expect(tuned, greaterThan(baseline!));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('hayvan boyutu kolu gövde kutusunu büyütür', (tester) async {
      await tester.pumpWidget(_harness(memberCount: 2));
      await tester.pump();
      final baseline = tester.getRect(find.byKey(const ValueKey('b-u0'))).width;

      await tester.pumpWidget(
        _harness(memberCount: 2, tuning: const CampfireTuning(critterScale: 1.4)),
      );
      await tester.pump();
      final tuned = tester.getRect(find.byKey(const ValueKey('b-u0'))).width;

      expect(tuned, closeTo(baseline * 1.4, 0.01));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('satır aralığı kolu dikey açıklığı büyütür', (tester) async {
      Future<double> spreadFor(CampfireTuning tuning) async {
        await tester.pumpWidget(_harness(memberCount: 8, tuning: tuning));
        await tester.pump();
        final tops = [
          for (var index = 0; index < 8; index++)
            tester.getRect(find.byKey(ValueKey('b-u$index'))).center.dy,
        ]..sort();
        return tops.last - tops.first;
      }

      final canonical = await spreadFor(const CampfireTuning());
      final wider = await spreadFor(
        const CampfireTuning(seatVerticalSpread: 1.8),
      );

      expect(wider, greaterThan(canonical));

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('WP-416 mobil önizleme aracı', () {
    testWidgets('dört kol da ekranda ve gerçek sahneyi sürüyor', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(420, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildCampfirePreviewApp(locale: const Locale('tr')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(CampfireScene), findsOneWidget);
      for (final key in const [
        'green-area',
        'label-font',
        'seat-spread',
        'critter-scale',
      ]) {
        expect(
          find.byKey(ValueKey(key)),
          findsOneWidget,
          reason: '$key kolu önizlemede yok',
        );
      }

      // Araç açılışta sahibin başlangıç değerini gösterir.
      final scene = tester.widget<CampfireScene>(find.byType(CampfireScene));
      expect(scene.tuning.greenAreaHeight, kCampfirePhoneGreenAreaHeight);

      // Kol sürüklenince sahne gerçekten yeni değeri alır.
      await tester.drag(find.byKey(const ValueKey('label-font')), const Offset(60, 0));
      await tester.pump();
      final tuned = tester.widget<CampfireScene>(find.byType(CampfireScene));
      expect(tuned.tuning.labelFontSize, greaterThan(kCampfireLabelFontSize));

      // Varsayılana dön kolu kanonik değerleri geri getirir.
      await tester.tap(find.byKey(const ValueKey('reset-tuning')));
      await tester.pump();
      final reset = tester.widget<CampfireScene>(find.byType(CampfireScene));
      expect(reset.tuning.labelFontSize, kCampfireLabelFontSize);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
