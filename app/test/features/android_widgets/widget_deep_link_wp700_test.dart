// WP-700: widget'a dokununca uygulamada ILGILI bolum acilir.
//
// 🔴 OLCULEN KUSUR: `openAppPendingIntent()` yalniz
// `getLaunchIntentForPackage()` cagiriyordu; uretilen intent HICBIR rota
// bilgisi tasimiyordu. Yani hangi widget'a dokunulursa dokunulsun uygulama
// "en son nerede kaldiysa" oraya aciliyordu.
//
// 🔴 ASIL TUZAK: kullanici widget'a dokundugunda uygulama cogu zaman
// KAPALIDIR ve o durumda `onNewIntent` HIC cagrilmaz. Yalniz sicak yolu
// olcen bir test, ozelligi "calisiyor" gosterip pratikte yari olu birakirdi.
// Bu yuzden asagidaki iddialar SOGUK ve SICAK yolu AYRI AYRI olcer; ayrica
// iki yolun native ucunun (`MainActivity`) durdugu da kaynaktan dogrulanir --
// Dart tarafi tek basina yesil yanabilir ve ozellik yine olabilir
// (`bitmis-backend-baglanmamis-ui`).
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:online_study_room/core/navigation/nav_index.dart';
import 'package:online_study_room/core/notifications/timer_notification_service.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_study_repository.dart';
import 'package:online_study_room/features/android_widgets/widget_deep_link.dart';
import 'package:online_study_room/features/clock/clock_screen.dart';
import 'package:online_study_room/features/clock/tasks_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gercek servis MethodChannel kurar; `enabled: false` ile kanal hic acilmaz
/// (desen: `timer_start_source_journal_wp599_test.dart`).
class _FakeWidgetDeepLinkService extends WidgetDeepLinkService {
  _FakeWidgetDeepLinkService({this.initialRoute}) : super(enabled: false);

  /// SOGUK yolda `getInitialRoute()`in donecegi rota.
  final WidgetRoute? initialRoute;

  @override
  Future<WidgetRoute?> getInitialRoute() async => initialRoute;
}

String _read(String relativePath) =>
    File(relativePath).readAsStringSync().replaceAll('\r\n', '\n');

String _kotlin(String name) =>
    _read('android/app/src/main/kotlin/com/manilmax/online_study_room/$name');

/// Bir saglayici sinifinin `onUpdate` govdesi (bir sonraki `class` satirina
/// kadar) — "dosyanin bir yerinde gecıyor" kacamagini kapatir.
String _providerBody(String source, String className) {
  final start = source.indexOf('class $className');
  expect(start, greaterThan(-1), reason: '$className bulunamadi');
  final next = source.indexOf('\nclass ', start + 1);
  return source.substring(start, next == -1 ? source.length : next);
}

Future<(ProviderContainer, _FakeWidgetDeepLinkService)> _container({
  WidgetRoute? initialRoute,
}) async {
  final service = _FakeWidgetDeepLinkService(initialRoute: initialRoute);
  final container = ProviderContainer(
    overrides: [widgetDeepLinkServiceProvider.overrideWithValue(service)],
  );
  addTearDown(container.dispose);
  // Riverpod 3: dinleyicisiz provider her okumada yeniden kurulur; sekme ve
  // rota durumu await'ler arasinda hayatta kalmalı.
  container.listen(navIndexProvider, (_, _) {});
  container.listen(widgetRouteProvider, (_, _) {});
  return (container, service);
}

Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Dinleyici yalniz Android'de kurulur.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('1) rota tablosu', () {
    test('her rota kendi bolumune gider, hicbiri kayitsiz degil', () {
      expect(WidgetRoute.timer.tab, AppTab.home);
      expect(WidgetRoute.countdown.tab, AppTab.home);
      expect(WidgetRoute.stats.tab, AppTab.stats);
      expect(WidgetRoute.group.tab, AppTab.groups);
      expect(WidgetRoute.clock.tab, AppTab.tools);
      expect(WidgetRoute.tasks.tab, AppTab.tools);
      // Ad tekilligi: iki rota ayni native ada baglanirsa biri sessizce
      // digerinin bolumunu acardi.
      final names = WidgetRoute.values.map((r) => r.nativeName).toList();
      expect(names.toSet(), hasLength(names.length));
    });

    test('tanimadigi rota adi yok sayilir', () {
      expect(WidgetRoute.fromNative('profile'), isNull);
      expect(WidgetRoute.fromNative(null), isNull);
      expect(WidgetRoute.fromNative(''), isNull);
      expect(WidgetRoute.fromNative('stats'), WidgetRoute.stats);
    });

    test('Araclar sekmesinin IKINCI seviyesi rotadan cozulur', () {
      expect(clockTabForWidgetRoute(WidgetRoute.tasks), ClockTab.tasks);
      expect(clockTabForWidgetRoute(WidgetRoute.clock), ClockTab.alarm);
      // Araclar disindaki rotalar alt sekmeye KARISMAZ.
      expect(clockTabForWidgetRoute(WidgetRoute.stats), isNull);
      expect(clockTabForWidgetRoute(null), isNull);
    });
  });

  group('2) SICAK yol (uygulama zaten acikti)', () {
    test('gelen rota ilgili sekmeyi acar', () async {
      final (container, service) = await _container();
      container.read(widgetDeepLinkListenerProvider);
      await _settle();
      expect(
        container.read(navIndexProvider),
        AppTab.home.index,
        reason: 'baslangicta Ana Sayfa',
      );

      service.onRouteReceived!(WidgetRoute.stats);
      expect(container.read(navIndexProvider), AppTab.stats.index);

      service.onRouteReceived!(WidgetRoute.group);
      expect(container.read(navIndexProvider), AppTab.groups.index);

      service.onRouteReceived!(WidgetRoute.clock);
      expect(container.read(navIndexProvider), AppTab.tools.index);
    });

    test('AYNI widget iki kez dokunulunca ikinci seviye yeniden uygulanir',
        () async {
      // Tick olmasa ikinci dokunus hicbir sey yapmazdi: rota degismedigi icin
      // `ref.listen` tetiklenmez ve kullanici alt sekmeyi elle degistirdiyse
      // widget bir daha oraya donduremezdi (yari olu anahtar).
      final (container, service) = await _container();
      container.read(widgetDeepLinkListenerProvider);
      await _settle();

      service.onRouteReceived!(WidgetRoute.tasks);
      final first = container.read(widgetRouteProvider);
      service.onRouteReceived!(WidgetRoute.tasks);
      final second = container.read(widgetRouteProvider);

      expect(first.route, WidgetRoute.tasks);
      expect(second.route, WidgetRoute.tasks);
      expect(second.tick, first.tick + 1);
    });
  });

  group('3) SOGUK yol (surec widget intent\'iyle DOGDU)', () {
    test('acilista bekleyen rota uygulanir', () async {
      // `onNewIntent` bu senaryoda HIC cagrilmaz; rota yalniz
      // `getInitialWidgetRoute` ile gelir.
      final (container, _) = await _container(initialRoute: WidgetRoute.group);
      container.read(widgetDeepLinkListenerProvider);
      await _settle();

      expect(
        container.read(navIndexProvider),
        AppTab.groups.index,
        reason: 'soguk baslangicta rota kayboluyor -> kullanici ana ekranda kalir',
      );
      expect(container.read(widgetRouteProvider).route, WidgetRoute.group);
    });

    test('bekleyen rota yoksa sekme degismez', () async {
      final (container, _) = await _container();
      container.read(widgetDeepLinkListenerProvider);
      await _settle();
      expect(container.read(navIndexProvider), AppTab.home.index);
      expect(container.read(widgetRouteProvider).route, isNull);
      expect(container.read(widgetRouteProvider).tick, 0);
    });
  });

  group('4) gercek kanal (sahte servis degil)', () {
    const channel = WidgetDeepLinkService.channel;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      channel.setMethodCallHandler(null);
    });

    test('SOGUK yol native tarafa dogru metodu sorar', () async {
      final asked = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        asked.add(call.method);
        return 'countdown';
      });

      final service = WidgetDeepLinkService(enabled: true);
      expect(await service.getInitialRoute(), WidgetRoute.countdown);
      expect(asked, ['getInitialWidgetRoute']);
    });

    test('SICAK yol native cagrisini rotaya cevirir', () async {
      final service = WidgetDeepLinkService(enabled: true);
      final seen = <WidgetRoute>[];
      service.onRouteReceived = seen.add;

      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onWidgetRoute', 'timer'),
        ),
        (_) {},
      );
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onWidgetRoute', 'bilinmeyen'),
        ),
        (_) {},
      );

      expect(seen, [WidgetRoute.timer]);
    });
  });

  group('5) Kotlin sozlesmesi', () {
    test('rota adlari iki dilde ayni', () {
      final source = _kotlin('widgets/WidgetDeepLink.kt');
      final listed = RegExp(r'val ROUTES = listOf\(([^)]*)\)')
          .firstMatch(source)!
          .group(1)!;
      for (final route in WidgetRoute.values) {
        expect(
          source,
          contains('= "${route.nativeName}"'),
          reason: '${route.nativeName} Kotlin tarafinda sabit degil',
        );
        expect(
          listed,
          contains(route.name.toUpperCase()),
          reason: '${route.nativeName} Kotlin ROUTES listesinde yok',
        );
      }
      expect(source, contains(WidgetDeepLinkService.channel.name));
    });

    test('her widget kendi rotasini tasir', () {
      final providers = _kotlin('widgets/StudyWidgetProviders.kt');
      final countdown = _kotlin('widgets/CountdownWidget.kt');
      final expected = <String, String>{
        'TimerWidgetProvider': 'ROUTE_TIMER',
        'StudyStatsWidgetProvider': 'ROUTE_STATS',
        'GroupGoalWidgetProvider': 'ROUTE_GROUP',
        'GroupLeaderboardWidgetProvider': 'ROUTE_GROUP',
        'ClockWidgetProvider': 'ROUTE_CLOCK',
      };
      expected.forEach((className, route) {
        final body = _providerBody(providers, className);
        expect(
          body,
          contains('WidgetDeepLink.$route'),
          reason: '$className rota tasimiyor -> uygulama en son sayfada acilir',
        );
      });
      expect(
        _providerBody(countdown, 'CountdownWidgetProvider'),
        contains('WidgetDeepLink.ROUTE_COUNTDOWN'),
      );

      // Rota tasimayan eski cagri hicbir widget'ta kalmadi.
      expect(providers, isNot(contains('getLaunchIntentForPackage')));
      expect(countdown, isNot(contains('getLaunchIntentForPackage')));
    });

    test('SOGUK yol native tarafta gercekten var', () {
      final main = _kotlin('MainActivity.kt');
      final onCreate = main.substring(
        main.indexOf('override fun onCreate'),
        main.indexOf('override fun configureFlutterEngine'),
      );
      expect(
        onCreate,
        contains('initialWidgetRoute = WidgetDeepLink.routeOf('),
        reason:
            'onCreate rotayi yakalamazsa uygulama KAPALIYKEN dokunulan widget '
            'kullaniciyi ana ekranda birakir -- ozelligin yarisi olur',
      );
      expect(
        main,
        contains('WidgetDeepLink.METHOD_INITIAL_ROUTE ->'),
        reason: 'Dart bekleyen rotayi soramaz',
      );
      expect(
        main.contains('initialWidgetRoute = null'),
        isTrue,
        reason: 'tek seferlik degilse ayni rota ikinci kez uygulanir',
      );
    });

    test('SICAK yol native tarafta gercekten var', () {
      final main = _kotlin('MainActivity.kt');
      final onNewIntent = main.substring(main.indexOf('override fun onNewIntent'));
      expect(
        onNewIntent,
        contains('WidgetDeepLink.routeOf('),
        reason: 'uygulama acikken gelen rota Dart\'a hic ulasmaz',
      );
      expect(onNewIntent, contains('WidgetDeepLink.METHOD_ON_ROUTE'));
    });
  });

  group('6) ikinci seviye ekranda gercekten acilir', () {
    late SharedPreferences prefs;

    setUp(() async {
      // `testWidgets` foundation debug degiskenlerinin test sonunda temiz
      // olmasini sart kosar; bu grup zaten kanal kurmuyor.
      debugDefaultTargetPlatformOverride = null;
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      await initializeDateFormatting('tr_TR', null);
    });

    testWidgets('gorev rotasi Araclar > Gorevler alt sekmesini acar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(InMemoryAuthRepository()),
          studyRepositoryProvider.overrideWithValue(InMemoryStudyRepository()),
          timerNotificationServiceProvider.overrideWithValue(
            _NoopTimerNotificationService(),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ClockScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byType(TasksScreen),
        findsNothing,
        reason: 'baslangicta Alarm alt sekmesi acik',
      );

      container.read(widgetRouteProvider.notifier).open(WidgetRoute.tasks);
      await tester.pump();

      expect(
        find.byType(TasksScreen),
        findsOneWidget,
        reason: 'rota yalniz ust sekmeyi acsa kullanici yine Alarm ekraninda kalirdi',
      );

      // Gorev ekrani gun siniri icin bir Timer kurar (`user_task_providers`).
      // Agac ve container test BITMEDEN kapatilir; `addTearDown` cok gec
      // kalirdi ve "bekleyen Timer" iddiasi patlardi.
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
  });
}

class _NoopTimerNotificationService implements TimerNotificationService {
  @override
  Stream<TimerNotificationAction> get commands => const Stream.empty();
  @override
  Future<void> cancel() async {}
  @override
  Future<void> initialize() async {}
  @override
  Future<void> requestPermissionIfNeeded() async {}
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<void> openSystemNotificationSettings() async {}
}
