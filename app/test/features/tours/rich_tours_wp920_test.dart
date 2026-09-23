// WP-920 — TANITIM KARTLARI EKRANI GERCEKTEN ANLATIR (sahip emri).
//
// Sahip: "kartlardaki bilgiler cok az, hicbir seyi anlatmiyor … cok karta
// gerek yok, karttaki bilgileri arttir." Kart sayisi ayni kaldi, govdeler
// birkac cumleye cikti. `app_tours_test.dart` metnin UZUNLUGUNU olcer; burasi
// uzun metnin EKRANA SIGDIGINI olcer:
//
//   - en kucuk telefon (320×568) + en buyuk yazi olcegi (2.0), TR ve EN,
//     acik ve koyu tema: her tur basindan sonuna yurunur; tasma/istisna yok,
//     "Devam" ve "Atla" her adimda dokunulabilir, son dokunusta tur biter
//     ve "goruldu" yazilir.
//   - normal telefon (360×640) + normal yazi: balon kaydirma GEREKTIRMEDEN
//     sigar. Test fontu her glifi kare cizdigi icin cihazdan daha genistir;
//     burada sigan metin cihazda rahat sigar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/tour/tour_host.dart';
import 'package:online_study_room/core/tour/tour_models.dart';
import 'package:online_study_room/core/tour/tour_prefs.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/features/tours/app_tours.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/l10n/app_localizations_en.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kUser = 'wp920';

Finder _bubble() => find.byKey(const Key('tour-bubble'));
Finder _next() => find.byKey(const Key('tour-next-button'));
Finder _skip() => find.byKey(const Key('tour-skip-button'));

/// Çapalı adımların hedefleri — gerçek ekranlardaki yerlerine benzer
/// konumlarda (başlıkta küçük düğme, ortada sahne, altta satır kartı).
class _Anchors {
  final content = GlobalKey();
  final switcher = GlobalKey();
  final campfire = GlobalKey();
  final identity = GlobalKey();
  final actions = GlobalKey();
}

List<TourDefinition> _definitions(AppLocalizations l10n, _Anchors a) => [
  AppTours.home(l10n),
  AppTours.dashboardEdit(l10n),
  AppTours.stats(l10n),
  AppTours.settings(l10n),
  for (final hasGroup in const [true, false]) ...[
    AppTours.groups(
      l10n,
      contentAnchor: a.content,
      switcherAnchor: a.switcher,
      hasGroup: hasGroup,
    ),
    AppTours.campfire(l10n, campfireAnchor: a.campfire, hasGroup: hasGroup),
  ],
  AppTours.profile(l10n, identityAnchor: a.identity, actionsAnchor: a.actions),
];

Widget _stage(_Anchors a) => Scaffold(
  body: Stack(
    children: [
      Positioned.fill(
        child: KeyedSubtree(key: a.content, child: const SizedBox.expand()),
      ),
      Positioned(
        top: 8,
        right: 8,
        child: SizedBox(key: a.switcher, width: 40, height: 40),
      ),
      Positioned(
        top: 16,
        left: 120,
        child: SizedBox(key: a.identity, width: 80, height: 80),
      ),
      Positioned(
        top: 120,
        left: 24,
        right: 24,
        child: SizedBox(key: a.campfire, height: 160),
      ),
      Positioned(
        bottom: 80,
        left: 16,
        right: 16,
        child: SizedBox(key: a.actions, height: 112),
      ),
    ],
  ),
);

Future<SharedPreferences> _pumpTour(
  WidgetTester tester, {
  required TourDefinition definition,
  required _Anchors anchors,
  required Locale locale,
  required Brightness brightness,
  required double textScale,
}) async {
  // Önceki turun ağacı (ve askıya alma mikro görevi) temizlensin.
  await tester.pumpWidget(const SizedBox());
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith(
          (ref) => Stream.value(
            Profile(id: _kUser, displayName: 'Ada', createdAt: DateTime(2026)),
          ),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        theme: ThemeData(brightness: brightness),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: TourHost(definition: definition, child: _stage(anchors)),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
  return prefs;
}

void _setScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  for (final locale in const [Locale('tr'), Locale('en')]) {
    final l10n = locale.languageCode == 'tr'
        ? AppLocalizationsTr()
        : AppLocalizationsEn();
    for (final brightness in Brightness.values) {
      testWidgets('every tour walks to the end on 320×568 at text scale 2.0 '
          '(${locale.languageCode}, ${brightness.name})', (tester) async {
        const screen = Size(320, 568);
        _setScreen(tester, screen);
        final anchors = _Anchors();

        for (final definition in _definitions(l10n, anchors)) {
          final prefs = await _pumpTour(
            tester,
            definition: definition,
            anchors: anchors,
            locale: locale,
            brightness: brightness,
            textScale: 2.0,
          );

          for (final step in definition.steps) {
            final where = '${definition.storageId}/${step.id}';
            expect(tester.takeException(), isNull, reason: where);
            expect(_bubble(), findsOneWidget, reason: where);
            expect(find.text(step.text), findsOneWidget, reason: where);

            final bubble = tester.getRect(_bubble());
            expect(bubble.left, greaterThanOrEqualTo(0), reason: where);
            expect(bubble.top, greaterThanOrEqualTo(0), reason: where);
            expect(bubble.right, lessThanOrEqualTo(screen.width));
            expect(bubble.bottom, lessThanOrEqualTo(screen.height));

            // İki düğme de her adımda gerçekten dokunulabilir: balon
            // "Atla"nın üstüne binmez, "Devam" kaydırmanın dışında kalır.
            expect(_skip().hitTestable(), findsOneWidget, reason: where);
            expect(_next().hitTestable(), findsOneWidget, reason: where);
            final skip = tester.getRect(_skip());
            expect(skip.overlaps(bubble), isFalse, reason: where);
            final next = tester.getRect(_next());
            expect(next.bottom, lessThanOrEqualTo(screen.height));

            await tester.tap(_next());
            await tester.pump();
          }

          expect(tester.takeException(), isNull);
          expect(_bubble(), findsNothing, reason: definition.storageId);
          expect(
            tourSeen(prefs, storageId: definition.storageId, userId: _kUser),
            isTrue,
            reason: definition.storageId,
          );
        }
      });
    }

    testWidgets(
      'on a 360×640 phone at normal text every card fits without scrolling '
      '(${locale.languageCode})',
      (tester) async {
        _setScreen(tester, const Size(360, 640));
        final anchors = _Anchors();

        for (final definition in _definitions(l10n, anchors)) {
          await _pumpTour(
            tester,
            definition: definition,
            anchors: anchors,
            locale: locale,
            brightness: Brightness.light,
            textScale: 1.0,
          );
          for (final step in definition.steps) {
            final where = '${definition.storageId}/${step.id}';
            expect(tester.takeException(), isNull, reason: where);
            final scrollable = tester.state<ScrollableState>(
              find.descendant(
                of: find.byKey(const Key('tour-bubble-scroll')),
                matching: find.byType(Scrollable),
              ),
            );
            expect(
              scrollable.position.maxScrollExtent,
              0,
              reason: '$where: balon normal telefonda kaydırma istiyor',
            );
            await tester.tap(_next());
            await tester.pump();
          }
          expect(_bubble(), findsNothing, reason: definition.storageId);
        }
      },
    );
  }
}
