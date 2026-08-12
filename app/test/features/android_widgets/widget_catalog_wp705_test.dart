// WP-705: yayindaki widget uygulamanin KENDI katalogunda gorunmuyordu.
//
// OLCULEN kusur: `clock_widgets_screen.dart` kartlari ELLE sayarak ciziyordu.
// Bes saglayici icin ayri `if (isHomeWidgetPublished(...))` blogu vardi
// (`timer`, `clock`, `alarm`, `studyStats`, `groupLeaderboard`), ama yayin
// listesi `[timer, countdown, task]`ti. Sonuc: WP-695'in geri sayimi ve
// WP-701'in gorev widget'i yayinda oldugu halde kullanicinin katalogunda HIC
// gorunmuyordu; yalniz Android'in kendi widget secicisinde bulunabiliyorlardi.
//
// 🔴 Kapinin kacirdigi sey: `published_home_widgets_wp461_test.dart` icindeki
// "katalog ekrani allowlist bayragini okuyor" testi YESILDI, cunku BAZI
// kartlar bayragi okuyordu. Hicbir iddia "yayindaki HER widget'in bir karti
// var" demiyordu. Bu dosyanin iddiasi bu yuzden **cift yonludur**:
//
//   1. yayindaki her saglayicinin katalogda karti VAR,
//   2. yayinda olmayan saglayicinin karti YOK.
//
// Tek yon yeterli olsaydi "hepsini kosulsuz ciz" sabotaji sessizce gecerdi.
//
// Olcum GERCEK ekran uzerinde yapilir (`ClockWidgetsScreen` monte edilir);
// bileseni izole kurup olcmek bu depoda bir kez yalan soyledi.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/time_engine/clock_permissions.dart';
import 'package:online_study_room/features/android_widgets/published_home_widgets.dart';
import 'package:online_study_room/features/android_widgets/widget_deep_link.dart';
import 'package:online_study_room/features/clock/clock_widgets_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// Android'de kanal cevap verdiginde olusan gercek durum (WP-687 testinin
/// kullandigi ayni anlik goruntu): katalog yarisi tam olarak cizilir.
const _androidSnapshot = ClockPermissionSnapshot(
  availability: ClockPermissionAvailability.available,
  notifications: false,
  exactAlarm: false,
  batteryUnrestricted: false,
  fullScreenIntent: false,
);

const String _xmlDir = 'android/app/src/main/res/xml';
const String _kotlinDir =
    'android/app/src/main/kotlin/com/manilmax/online_study_room/widgets';

/// Saglayici -> `res/xml/odak_<ad>_widget_info.xml` govde adi.
const Map<HomeWidgetProvider, String> _infoXmlName = {
  HomeWidgetProvider.timer: 'timer',
  HomeWidgetProvider.minimalTimer: 'minimal_timer',
  HomeWidgetProvider.studyStats: 'stats',
  HomeWidgetProvider.groupGoal: 'group_goal',
  HomeWidgetProvider.groupLeaderboard: 'leaderboard',
  HomeWidgetProvider.clock: 'clock',
  HomeWidgetProvider.alarm: 'alarm',
  HomeWidgetProvider.countdown: 'countdown',
  HomeWidgetProvider.task: 'task',
};

/// Saglayici sinifinin yasadigi Kotlin dosyasi.
const Map<HomeWidgetProvider, String> _kotlinFile = {
  HomeWidgetProvider.timer: 'StudyWidgetProviders.kt',
  HomeWidgetProvider.minimalTimer: 'MinimalTimerWidget.kt',
  HomeWidgetProvider.studyStats: 'StudyWidgetProviders.kt',
  HomeWidgetProvider.groupGoal: 'StudyWidgetProviders.kt',
  HomeWidgetProvider.groupLeaderboard: 'StudyWidgetProviders.kt',
  HomeWidgetProvider.clock: 'StudyWidgetProviders.kt',
  HomeWidgetProvider.alarm: 'StudyWidgetProviders.kt',
  HomeWidgetProvider.countdown: 'CountdownWidget.kt',
  HomeWidgetProvider.task: 'TaskWidget.kt',
};

String _read(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path yok');
  return file.readAsStringSync().replaceAll('\r\n', '\n');
}

/// `android:ad="deger"` -> `deger`; yorumlar elenir (WP-640 tuzagi).
String? _attr(String xml, String name) {
  final stripped = xml.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
  return RegExp('android:$name="([^"]*)"').firstMatch(stripped)?.group(1);
}

int? _cellCountFromDp(String? value) {
  final match = RegExp(r'^(\d+)dp$').firstMatch(value ?? '');
  if (match == null) return null;
  final dp = int.parse(match.group(1)!);
  final numerator = dp + 30;
  return numerator % 70 == 0 ? numerator ~/ 70 : null;
}

/// Saglayici sinifinin govdesi: bir sonraki ust duzey `class` bildirimine kadar.
String _kotlinClassBody(HomeWidgetProvider provider) {
  final source = _read('$_kotlinDir/${_kotlinFile[provider]}');
  final start = source.indexOf('class ${provider.androidClassName} ');
  expect(start, greaterThan(-1), reason: '${provider.androidClassName} yok');
  final next = source.indexOf('\nclass ', start + 1);
  return next == -1 ? source.substring(start) : source.substring(start, next);
}

Key _cardKey(HomeWidgetProvider provider) =>
    ValueKey<String>('home_widget_card_${provider.name}');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('tr'));
  });

  tearDown(() => ClockPermissions.debugSnapshotOverride = null);

  /// Gercek ekrani Android kolunda monte eder.
  ///
  /// Platform enjeksiyonu agac oturduktan SONRA geri alinir: iddialar artik
  /// monte edilmis agaci okur, yeni bir `pump` yok. `addTearDown` ile geri
  /// almak GEC kalirdi — flutter_test foundation degiskenlerini tearDown'dan
  /// ONCE denetler ve testi alakasiz bir hatayla dusururdu.
  Future<void> pumpCatalog(WidgetTester tester) async {
    // Katalog + dort izin satiri uzun bir liste; kisa bir gorunum penceresinde
    // ListView alt ogeleri hic MONTE ETMEZ ve "yok" iddiasi bedavaya gecerdi.
    tester.view.physicalSize = const Size(1080, 9000);
    tester.view.devicePixelRatio = 3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    ClockPermissions.debugSnapshotOverride = _androidSnapshot;
    try {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ClockWidgetsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  group('WP-705 · katalog yayin listesinden turer (iki yonlu)', () {
    testWidgets('YON 1 — yayindaki HER saglayicinin karti ekranda', (
      tester,
    ) async {
      await pumpCatalog(tester);

      expect(publishedHomeWidgets, isNotEmpty, reason: 'iddia bos olmasin');
      for (final provider in publishedHomeWidgets) {
        final spec = homeWidgetCardSpec(provider, l10n);
        expect(
          find.byKey(_cardKey(provider)),
          findsOneWidget,
          reason:
              '${provider.androidClassName} yayinda ama katalogda karti yok: '
              'kullanici onu yalniz Android widget secicisinde bulabilir',
        );
        expect(
          find.descendant(
            of: find.byKey(_cardKey(provider)),
            matching: find.text(spec.title),
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets('YON 2 — yayinda OLMAYAN saglayicinin karti ekranda YOK', (
      tester,
    ) async {
      await pumpCatalog(tester);

      final dormant = HomeWidgetProvider.values
          .where((provider) => !isHomeWidgetPublished(provider))
          .toList();
      expect(dormant, isNotEmpty, reason: 'iddia bos olmasin');
      for (final provider in dormant) {
        final spec = homeWidgetCardSpec(provider, l10n);
        expect(
          find.byKey(_cardKey(provider)),
          findsNothing,
          reason:
              '${provider.androidClassName} dormant; kart cizilirse kullaniciya '
              'pickerda bulunmayan bir widget vaat edilir (WP-461 karari)',
        );
        expect(find.text(spec.title), findsNothing);
      }
    });

    testWidgets('kart sayisi yayin listesiyle birebir (fazlasi da yok)', (
      tester,
    ) async {
      await pumpCatalog(tester);

      expect(
        find.byWidgetPredicate((widget) {
          final key = widget.key;
          return key is ValueKey<String> &&
              key.value.startsWith('home_widget_card_');
        }),
        findsNWidgets(publishedHomeWidgets.length),
      );
    });
  });

  group('WP-705 · kart ne vaat ediyorsa ekranda yazili', () {
    testWidgets('her yayindaki kart ozet + boyut + dokunma satirini cizer', (
      tester,
    ) async {
      await pumpCatalog(tester);

      for (final provider in publishedHomeWidgets) {
        final spec = homeWidgetCardSpec(provider, l10n);
        final card = find.byKey(_cardKey(provider));

        expect(
          find.descendant(of: card, matching: find.text(spec.summary)),
          findsOneWidget,
          reason: '${provider.name}: ne gosterdigi yazili degil',
        );

        expect(
          spec.cellWidth,
          isNotNull,
          reason: '${provider.name} yayinda; varsayilan boyutu beyan etmeli',
        );
        expect(
          find.descendant(
            of: card,
            matching: find.text(
              l10n.clockWidgetVarsayilanBoyut(spec.cellWidth!, spec.cellHeight!),
            ),
          ),
          findsOneWidget,
          reason: '${provider.name}: boyut satiri yok',
        );

        if (spec.minimumCellWidth != null && spec.minimumCellHeight != null) {
          expect(
            find.descendant(
              of: card,
              matching: find.text(
                l10n.clockWidgetEnKucukBoyut(
                  spec.minimumCellWidth!,
                  spec.minimumCellHeight!,
                ),
              ),
            ),
            findsOneWidget,
            reason: '${provider.name}: gercek kucultme alt siniri yazili degil',
          );
        }

        expect(
          find.descendant(
            of: card,
            matching: find.text(homeWidgetCardTapLine(spec, l10n)),
          ),
          findsOneWidget,
          reason: '${provider.name}: dokununca ne oldugu yazili degil',
        );
      }
    });

    testWidgets('gomulu Turkce metin yok — kart metni l10n\'dan gelir', (
      tester,
    ) async {
      await pumpCatalog(tester);

      // EN katalogda ayni kart cizildiginde baslik EN dizesine donmeli; donmezse
      // metin l10n'dan degil koddan geliyordur.
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      expect(
        homeWidgetCardSpec(HomeWidgetProvider.task, en).summary,
        isNot(homeWidgetCardSpec(HomeWidgetProvider.task, l10n).summary),
      );
      expect(
        homeWidgetCardSpec(HomeWidgetProvider.countdown, en).summary,
        isNot(homeWidgetCardSpec(HomeWidgetProvider.countdown, l10n).summary),
      );
      final minimalTr = homeWidgetCardSpec(
        HomeWidgetProvider.minimalTimer,
        l10n,
      );
      final minimalEn = homeWidgetCardSpec(HomeWidgetProvider.minimalTimer, en);
      expect(minimalEn.title, isNot(minimalTr.title));
      expect(minimalEn.summary, isNot(minimalTr.summary));
      expect(minimalTr.title, isNot(l10n.clockCalismaSayaci));
      expect(minimalEn.title, isNot(en.clockCalismaSayaci));
    });
  });

  group('WP-705 · vaat kodla dogrulanir (uydurma yok)', () {
    test('beyan edilen hucre boyutu odak_*_widget_info.xml ile ayni', () {
      for (final provider in HomeWidgetProvider.values) {
        final xml = _read('$_xmlDir/odak_${_infoXmlName[provider]}_widget_info.xml');
        final spec = homeWidgetCardSpec(provider, l10n);
        final declaredWidth = _attr(xml, 'targetCellWidth');
        final declaredHeight = _attr(xml, 'targetCellHeight');

        expect(
          spec.cellWidth?.toString(),
          declaredWidth,
          reason:
              '${provider.name}: kart varsayilan GENISLIGI XML ile ayrisiyor '
              '(kart $declaredWidth degil ${spec.cellWidth} diyor)',
        );
        expect(
          spec.cellHeight?.toString(),
          declaredHeight,
          reason: '${provider.name}: kart varsayilan YUKSEKLIGI XML ile ayrisiyor',
        );
        if (spec.minimumCellWidth != null || spec.minimumCellHeight != null) {
          expect(
            spec.minimumCellWidth,
            _cellCountFromDp(_attr(xml, 'minResizeWidth')),
            reason:
                '${provider.name}: kart minimum GENISLIGI XML ile ayrisiyor',
          );
          expect(
            spec.minimumCellHeight,
            _cellCountFromDp(_attr(xml, 'minResizeHeight')),
            reason:
                '${provider.name}: kart minimum YUKSEKLIGI XML ile ayrisiyor',
          );
        }
      }
    });

    test('dokunma vaadi Kotlin saglayicisindaki gercek intent ile ayni', () {
      for (final provider in HomeWidgetProvider.values) {
        final body = _kotlinClassBody(provider);
        final spec = homeWidgetCardSpec(provider, l10n);
        final route = spec.route;

        if (spec.directTap == HomeWidgetDirectTap.togglesTimer) {
          expect(provider, HomeWidgetProvider.minimalTimer);
          expect(route, isNull);
          expect(
            body.contains('TimerActionReceiver.ACTION_TOGGLE_TIMER'),
            isTrue,
            reason: 'kart baslat/durdur diyor ama native broadcast yok',
          );
          expect(
            body.contains('WidgetDeepLink.pendingIntent('),
            isFalse,
            reason: 'minimal sayac toggle yerine uygulamayi acmaya donmus',
          );
          continue;
        }

        if (route == null) {
          expect(
            body.contains('WidgetDeepLink.pendingIntent('),
            isFalse,
            reason:
                '${provider.androidClassName} artik derin baglanti kuruyor; '
                'kart "belirli bir bolume gitmez" derken bayat kaldi',
          );
          continue;
        }

        final constant = 'WidgetDeepLink.ROUTE_${route.nativeName.toUpperCase()}';
        expect(
          body.contains(constant),
          isTrue,
          reason:
              '${provider.androidClassName} $constant kullanmiyor; kart '
              'dokununca acilmayacak bir bolumu vaat ediyor',
        );
      }
    });

    // 🔴 WP-706 — BU IDDIA TERSINE CEVRILDI, SILINMEDI.
    //
    // WP-705 bu testi "gorev widget'i BILEREK derin baglanti vaat etmiyor"
    // diye yazmisti ve HAKLIYDI: `ROUTE_TASKS` sabiti tanimliydi ama
    // `TaskWidget.kt` icinde hic KULLANILMIYORDU. Iki ajan da dosyayi
    // "digerinin SAHIP yolu" sayip dokunmayinca is dikiste kalmisti.
    // WP-706 baglantiyi kurdu; iddia artik ters yonu olcer.
    test('gorev widgeti gercekten Gorevler bolumune baglaniyor', () {
      expect(
        homeWidgetCardSpec(HomeWidgetProvider.task, l10n).route,
        WidgetRoute.tasks,
      );
      final body = _read('$_kotlinDir/TaskWidget.kt');
      expect(
        body.contains('WidgetDeepLink.ROUTE_TASKS'),
        isTrue,
        reason: 'kart "Gorevler bolumu acilir" diyor ama Kotlin baglamiyor',
      );
      // Satirlarin KENDISI toggle KALMALI: sahibin birincil istegi
      // "yaptiklarini oradan isaretleseler". Satir da gezinmeye baglanirsa
      // ana ekrandan isaretleme ozelligi sessizce olur.
      expect(
        body.contains('togglePendingIntent(context, widgetId, index, item.id)'),
        isTrue,
        reason:
            'satir toggle baglantisi kayboldu: ana ekrandan isaretleme oldu',
      );
    });
  });
}
