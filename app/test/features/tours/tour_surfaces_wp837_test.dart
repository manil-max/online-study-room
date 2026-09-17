// WP-837 — TANITIM KARTLARI SADELESTI (sahip geri bildirimi, v86).
//
// Sahibin iki cumlesi bu dosyanin tamami:
//   1. "'2 adimin 2. adimi' gibi metinler gereksiz" → sayac HER YERDEN kalkti.
//   2. "ana ekranda tek kart, duzenleme modunda tek kart, istatistiklerde tek
//      kart" → uc yuzey, uc balon, her biri bir kez.
//
// 🔴 OLCULEN SEY TANIM DEGIL, EKRAN. `app_tours_test.dart` tanimlarin sekline
// bakar (kac adim, kac karakter). Burasi gercek ekrani pompalar: karta uzun
// basinca balon CIKIYOR mu, "gorculdu" isaretlendikten sonra bir daha CIKMIYOR
// mu. Bu ayrim bu depoda pahaliya mal oldu: WP-799'da kamp atesi turu tanimli,
// metinli, testli ve HIC MONTE EDILMEMISTI.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/navigation/nav_index.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/tour/tour_host.dart';
import 'package:online_study_room/core/tour/tour_prefs.dart';
import 'package:online_study_room/data/models/daily_stat.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/features/home/home_screen.dart';
import 'package:online_study_room/features/stats/stats_screen.dart';
import 'package:online_study_room/features/tours/app_tours.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/l10n/app_localizations_en.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kUser = 'ayse';

final _tr = AppLocalizationsTr();

Profile _profile() =>
    Profile(id: _kUser, displayName: 'Ayşe', createdAt: DateTime(2026));

String _seenKey(String storageId) =>
    tourSeenKey(storageId: storageId, userId: _kUser);

Finder _bubble() => find.byKey(const Key('tour-bubble'));

/// İstatistik sekmesi seçiliymiş gibi davranan gezinme durumu.
///
/// Tur yalnız o sekme seçiliyken başlar (`stats_screen.dart`); varsayılan
/// `NavIndexNotifier` Ana Sayfa'da durur, yani override olmadan bu dosya
/// istatistik turunu hiç göremezdi.
class _StatsTabNav extends NavIndexNotifier {
  @override
  int build() => AppTab.stats.index;
}

Future<SharedPreferences> _prefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

Future<void> _pumpHome(WidgetTester tester, SharedPreferences prefs) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith((ref) => Stream.value(_profile())),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              IndexedStack(index: 0, children: [HomeScreen(), SizedBox()]),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _pumpStats(WidgetTester tester, SharedPreferences prefs) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith((ref) => Stream.value(_profile())),
        navIndexProvider.overrideWith(_StatsTabNav.new),
        userGroupsProvider.overrideWith(
          (_) => Stream.value(const <StudyGroup>[]),
        ),
        userSessionsProvider.overrideWith(
          (_) => Stream.value(const <StudySession>[]),
        ),
        userSubjectsProvider.overrideWith(
          (_) => Stream.value(const <Subject>[]),
        ),
        groupDailyStatsProvider.overrideWith(
          (_) => Stream.value(const <DailyStat>[]),
        ),
        groupMembersProvider.overrideWith(
          (_) => Stream.value(const <Profile>[]),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const StatsScreen(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
}

Map<String, Object> _homeLayoutPrefs() => <String, Object>{
  'dashboard_layout_v2_32': <String>['timer:0:0:32:49', 'tasks:0:49:32:18'],
  'dashboard_grid_last_columns': 32,
};

void main() {
  group('üç yüzeyin her birinde tek kart', () {
    test('ana ekran turu tam olarak bir adımdır', () {
      for (final l10n in [_tr, AppLocalizationsEn()]) {
        expect(AppTours.home(l10n).steps, hasLength(1));
      }
    });

    test('düzenleme ve istatistik turları da tek adımdır', () {
      for (final l10n in [_tr, AppLocalizationsEn()]) {
        expect(AppTours.dashboardEdit(l10n).steps, hasLength(1));
        expect(AppTours.stats(l10n).steps, hasLength(1));
      }
    });
  });

  // 🔴 Sahip cumlesi: "2 adimin 2. adimi" gibi metinler gereksiz.
  //
  // Iddia iki katmanda olculur, cunku tek katman yeterli degil: anahtari
  // silmek balonu duzeltmez (baska bir yerde elle yazilmis olabilir), balona
  // bakmak da anahtarin geri gelmesini engellemez.
  group('adım sayacı hiçbir yerde yok', () {
    test('katalogda tourAdim anahtarı kalmadı', () {
      for (final path in ['lib/l10n/app_tr.arb', 'lib/l10n/app_en.arb']) {
        final catalog = File(path).readAsStringSync();
        // Boş ölçüm koruması: dosya gerçekten okundu mu?
        expect(catalog, contains('"tourAtla"'), reason: '$path okunamadı');
        expect(
          catalog,
          isNot(contains('tourAdim')),
          reason: '$path içinde adım sayacı anahtarı geri gelmiş',
        );
      }
    });

    testWidgets('iki adımlı bir turda bile balonda sayaç yazmıyor', (
      tester,
    ) async {
      // Gruplar turu iki adimlidir; sayac YASAYAN tek yer orasiydi.
      final definition = AppTours.groups(
        _tr,
        contentAnchor: GlobalKey(),
        switcherAnchor: GlobalKey(),
        hasGroup: true,
      );
      final prefs = await _prefs(<String, Object>{});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authStateProvider.overrideWith((ref) => Stream.value(_profile())),
          ],
          child: MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TourHost(
              definition: definition,
              child: const Scaffold(body: SizedBox.expand()),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(_bubble(), findsOneWidget);
      final counter = RegExp(r'\d+\s*(/|\.|of|adım)');
      final texts = tester
          .widgetList<Text>(
            find.descendant(of: _bubble(), matching: find.byType(Text)),
          )
          .map((text) => text.data ?? '')
          .toList();
      expect(texts, isNotEmpty);
      for (final text in texts) {
        expect(
          counter.hasMatch(text),
          isFalse,
          reason: 'balonda adım sayacına benzeyen metin var: "$text"',
        );
      }
    });
  });

  // 🔴 "Bir kez" iddiasi iki yonlu olmak zorunda. Tek yonlu olcum ("balon
  // cikiyor") turu HER acilista gosteren bir regresyonu sessizce gecirirdi.
  testWidgets('düzenleme modu turu ilk uzun basmada çıkar', (tester) async {
    final prefs = await _prefs({
      ..._homeLayoutPrefs(),
      // Ana ekran turu yoldan cekilir: balonun opak bariyeri uzun basmayi yutar.
      _seenKey(AppTours.home(_tr).storageId): true,
    });
    await _pumpHome(tester, prefs);
    expect(_bubble(), findsNothing, reason: 'görüntüleme modunda balon yok');

    await tester.longPress(find.byType(Card).first);
    await tester.pump(const Duration(milliseconds: 600));

    expect(_bubble(), findsOneWidget);
    expect(find.text(_tr.tourDashboardEditOverview), findsOneWidget);
  });

  testWidgets('görüldü işaretlenen düzenleme turu bir daha çıkmaz', (
    tester,
  ) async {
    final prefs = await _prefs({
      ..._homeLayoutPrefs(),
      _seenKey(AppTours.home(_tr).storageId): true,
      _seenKey(AppTours.dashboardEdit(_tr).storageId): true,
    });
    await _pumpHome(tester, prefs);

    await tester.longPress(find.byType(Card).first);
    await tester.pump(const Duration(milliseconds: 600));

    // Düzenleme modu gerçekten açıldı (aksi hâlde "balon yok" boş ölçüm olur).
    expect(find.byKey(const Key('home-sticky-size-panel')), findsOneWidget);
    expect(_bubble(), findsNothing);
  });

  testWidgets('istatistik turu ilk açılışta çıkar', (tester) async {
    final prefs = await _prefs(<String, Object>{});
    await _pumpStats(tester, prefs);

    expect(_bubble(), findsOneWidget);
    expect(find.text(_tr.tourStatsOverview), findsOneWidget);
  });

  testWidgets('görüldü işaretlenen istatistik turu bir daha çıkmaz', (
    tester,
  ) async {
    final prefs = await _prefs({_seenKey(AppTours.stats(_tr).storageId): true});
    await _pumpStats(tester, prefs);

    // Ekran gerçekten çizildi; "balon yok" iddiası boş ölçüm değil.
    expect(find.text(_tr.statsKisisel), findsWidgets);
    expect(_bubble(), findsNothing);
  });
}
