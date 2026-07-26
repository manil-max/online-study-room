import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/tour/tour_controller.dart';
import 'package:online_study_room/core/tour/tour_gate.dart';
import 'package:online_study_room/core/tour/tour_host.dart';
import 'package:online_study_room/core/tour/tour_models.dart';
import 'package:online_study_room/core/tour/tour_prefs.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('görüldü anahtarı ekran, sürüm ve kullanıcıya özeldir', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await markTourSeen(prefs, storageId: 'home.v1', userId: 'ayse');

    expect(tourSeen(prefs, storageId: 'home.v1', userId: 'ayse'), isTrue);
    expect(tourSeen(prefs, storageId: 'home.v2', userId: 'ayse'), isFalse);
    expect(tourSeen(prefs, storageId: 'groups.v1', userId: 'ayse'), isFalse);
    expect(tourSeen(prefs, storageId: 'home.v1', userId: 'mehmet'), isFalse);
  });

  test(
    'sıfırlama yalnız geçerli kullanıcının tur anahtarlarını siler',
    () async {
      SharedPreferences.setMockInitialValues({
        'tour.home.v1.ayse': true,
        'tour.groups.v1.ayse': true,
        'tour.home.v1.mehmet': true,
        'theme.mode': 'dark',
      });
      final prefs = await SharedPreferences.getInstance();

      expect(await resetToursForUser(prefs, userId: 'ayse'), 2);
      expect(prefs.containsKey('tour.home.v1.ayse'), isFalse);
      expect(prefs.getBool('tour.home.v1.mehmet'), isTrue);
      expect(prefs.getString('theme.mode'), 'dark');
    },
  );

  test('kuyruk engeli turu görüldü saymaz ve nedenini korur', () {
    expect(
      tourBlockReason(
        seen: false,
        hasUser: true,
        otherTourRunning: false,
        routeIsCurrent: false,
        appResumed: true,
      ),
      TourBlockReason.routeNotCurrent,
    );
    expect(isPermanentBlock(TourBlockReason.routeNotCurrent), isFalse);
    expect(isPermanentBlock(TourBlockReason.alreadySeen), isTrue);
  });

  test('controller son adımda turu kalıcı olarak bitirir', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith((ref) => Stream.value(_profile('ayse'))),
      ],
    );
    addTearDown(container.dispose);
    container.listen(authStateProvider, (_, _) {});
    await container.read(authStateProvider.future);
    final definition = _definition();
    final controller = container.read(tourControllerProvider.notifier);

    expect(
      controller.maybeStart(definition, routeIsCurrent: true, appResumed: true),
      isTrue,
    );
    await controller.next();

    expect(container.read(tourControllerProvider).isRunning, isFalse);
    expect(
      tourSeen(prefs, storageId: definition.storageId, userId: 'ayse'),
      isTrue,
    );
  });

  testWidgets('360 px ekranda balon taşmaz; atla turu bitirir', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final anchor = GlobalKey();
    final definition = TourDefinition(
      id: 'test',
      version: 1,
      steps: [
        TourStep(id: 'welcome', title: 'Hoş geldin', text: 'Kısa tanıtım.'),
        TourStep(id: 'target', text: 'Bu alanı kullan.', anchor: anchor),
      ],
    );
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith(
            (ref) => Stream.value(_profile('ayse')),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TourHost(
            definition: definition,
            child: Scaffold(
              body: Center(child: SizedBox(key: anchor, width: 48, height: 48)),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final bubble = tester.getRect(find.byKey(const Key('tour-bubble')));
    expect(bubble.left, greaterThanOrEqualTo(0));
    expect(bubble.right, lessThanOrEqualTo(360));

    await tester.tap(find.byKey(const Key('tour-skip-button')));
    await tester.pump();
    expect(find.byKey(const Key('tour-bubble')), findsNothing);
    expect(
      tourSeen(prefs, storageId: definition.storageId, userId: 'ayse'),
      isTrue,
    );
  });
}

Profile _profile(String id) =>
    Profile(id: id, displayName: id, createdAt: DateTime(2026));

TourDefinition _definition() => TourDefinition(
  id: 'home',
  version: 1,
  steps: [TourStep(id: 'welcome', text: 'Welcome')],
);
