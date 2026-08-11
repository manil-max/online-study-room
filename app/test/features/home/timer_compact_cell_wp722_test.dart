// WP-722 — KOMPAKT SECILINCE IZGARA HUCRESI DE KUCULSUN.
//
// 🔴 WP-715 isin yarisini yapti: `ClockStyle.compact` kartin ISTEDIGI
// yuksekligi 676 -> 116 px'e indirdi (`timer_card_compact_wp715_test.dart`).
// Ama Ana Sayfa izgarasi karti `SizedBox(height: hucre)` icine koyuyor
// (`home_screen.dart` `heightOf` -> `dashboard_card.dart` `dashboardCardFor`)
// ve hucrenin yuksekligi SATIR SAYISINDAN geliyor. Satir sayisi degismedigi
// icin kullanici Kompakt'i secince kart 116 px boyaniyor, hucre eski yerini
// tutuyor ve altinda bos alan kaliyor — sahibin "kart hala cok buyuk"
// sikayetinin kalan yarisi.
//
// Bu dosya iddiayi KARTIN ISTEDIGI yukseklige degil, HUCRENIN AYIRDIGI
// yuksekliğe kurar: olculen sayi `dashboardCardFor`in kurdugu `SizedBox`in
// gercek pikselidir (360 dp telefon).
//
// Ayrica bu is kullanicinin KAYDEDILMIS duzenine dokunur; o yuzden uc kural
// ayri ayri baglanir:
//   1. Kompakt secilince sayac kartinin satiri duser (ve DISKE yazilir).
//   2. Geri donunce eski satir geri gelir — tek yonlu kapi yok.
//   3. Kullanici kompaktken karti ELLE boyutlandirmissa geri donuste onun
//      boyutu KORUNUR; kullanicinin isi sessizce geri alinmaz.
// ve dorduncu bir kural: bu degisiklik yalniz sayac kartina dokunur, duzenin
// geri kalanini kaydirmaz.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/features/classroom/widgets/clock_style.dart';
import 'package:online_study_room/features/classroom/widgets/study_timer_card.dart';
import 'package:online_study_room/features/home/dashboard_card.dart';
import 'package:online_study_room/features/home/dashboard_providers.dart';
import 'package:online_study_room/features/home/home_screen.dart';
import 'package:online_study_room/features/home/widgets/leaderboard_card.dart';
import 'package:online_study_room/features/home/widgets/today_summary_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sahibin sikayet ettigi yuzey: telefon genisligi.
const double _kPhoneWidth = 360;

/// Kalici duzen profilinin disk anahtari (32 sutun).
const String _kLayoutKey = 'dashboard_layout_v2_32';

const int _kColumns = 32;

/// Varsayilan duzende sayac karti (bkz. `defaultDashboardLayout`).
int get _defaultTimerRows => (4 * _kColumns / kDefaultGridColumns).round();

Future<SharedPreferences> _freshPrefs({ClockStyle? style}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    if (style != null) 'clock_style': style.name,
  });
  return SharedPreferences.getInstance();
}

DashboardCardConfig _timerOf(List<DashboardCardConfig> layout) =>
    layout.firstWhere((c) => c.type == DashboardCardType.timer);

/// Diskte YAZILI olan satir sayisi (bellekteki degil). Bu depoda bellekte
/// dogru olup diske yazilmayan bir degisiklik daha once sessizce kayboldu.
int? _storedTimerRows(SharedPreferences prefs) {
  final raw = prefs.getStringList(_kLayoutKey);
  if (raw == null) return null;
  final decoded = DashboardCardConfig.decodeList(raw, columns: _kColumns);
  final timer = decoded.where((c) => c.type == DashboardCardType.timer);
  return timer.isEmpty ? null : timer.first.h;
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('tr'));

  // ===================== 1) SAF DURUM: SATIR SAYISI =======================

  /// Notifier durumuna bakan her test dinleyici tutar: Riverpod 3'te
  /// dinleyicisiz provider her `read`de yeniden kurulur ve regresyonu gizler.
  ProviderContainer container(SharedPreferences prefs) {
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    final sub = c.listen(dashboardLayoutProvider, (_, _) {});
    addTearDown(sub.close);
    return c;
  }

  test(
    'kompakt secilince sayac kartinin SATIRI duser ve diske yazilir',
    () async {
      final prefs = await _freshPrefs();
      final c = container(prefs);

      final before = _timerOf(c.read(dashboardLayoutProvider)).h;
      expect(before, _defaultTimerRows, reason: 'varsayilan duzen degismis');

      c.read(clockStyleProvider.notifier).set(ClockStyle.compact);
      final after = _timerOf(c.read(dashboardLayoutProvider)).h;

      expect(
        after,
        lessThan(before),
        reason:
            'Kompakt secildi ama sayac karti izgarada hala $after satir tutuyor '
            '(onceki $before). Kart 116 px boyanirken hucre eski yerini tutar; '
            'kullanici altinda bos alan gorur.',
      );
      expect(
        _storedTimerRows(prefs),
        after,
        reason:
            'Satir bellekte dustu ama DISKE yazilmadi — uygulama yeniden '
            'acilinca eski buyuk kart geri gelir.',
      );
    },
  );

  test(
    'kompakttan cikinca eski satir geri gelir (tek yonlu kapi yok)',
    () async {
      final prefs = await _freshPrefs();
      final c = container(prefs);
      final before = _timerOf(c.read(dashboardLayoutProvider)).h;

      c.read(clockStyleProvider.notifier).set(ClockStyle.compact);
      final compactRows = _timerOf(c.read(dashboardLayoutProvider)).h;
      expect(compactRows, lessThan(before));

      c.read(clockStyleProvider.notifier).set(ClockStyle.digits);
      expect(
        _timerOf(c.read(dashboardLayoutProvider)).h,
        before,
        reason:
            'Kompakttan cikildi ama kart kucuk kaldi: tam kart $before satirlik '
            'yerini geri alamiyor, yani secim tek yonlu bir kapi.',
      );
      expect(_storedTimerRows(prefs), before);
    },
  );

  test('kompaktken ELLE buyutulen boyut geri donuste EZILMEZ', () async {
    final prefs = await _freshPrefs();
    final c = container(prefs);
    final before = _timerOf(c.read(dashboardLayoutProvider)).h;

    c.read(clockStyleProvider.notifier).set(ClockStyle.compact);
    final compactRows = _timerOf(c.read(dashboardLayoutProvider)).h;
    expect(compactRows, lessThan(before));

    // Kullanici kompakt kartı kendi eliyle buyutuyor.
    const manual = 9;
    expect(manual, isNot(compactRows));
    expect(manual, isNot(before));
    c
        .read(dashboardLayoutProvider.notifier)
        .setBounds(DashboardCardType.timer, h: manual);
    expect(_timerOf(c.read(dashboardLayoutProvider)).h, manual);

    c.read(clockStyleProvider.notifier).set(ClockStyle.digits);
    expect(
      _timerOf(c.read(dashboardLayoutProvider)).h,
      manual,
      reason:
          'Kullanici karti elle $manual satira ayarlamisti; geri donuste '
          'hatirlanan eski boyut onu ezdi. Elle verilmis bir boyutu sessizce '
          'geri almak kullanicinin isini silmektir.',
    );
    expect(_storedTimerRows(prefs), manual);
  });

  test('kompaktken elle KUCULTULEN boyut da korunur', () async {
    final prefs = await _freshPrefs();
    final c = container(prefs);

    c.read(clockStyleProvider.notifier).set(ClockStyle.compact);
    final compactRows = _timerOf(c.read(dashboardLayoutProvider)).h;
    final manual = compactRows - 1;
    expect(manual, greaterThanOrEqualTo(1));
    c
        .read(dashboardLayoutProvider.notifier)
        .setBounds(DashboardCardType.timer, h: manual);

    c.read(clockStyleProvider.notifier).set(ClockStyle.digits);
    expect(_timerOf(c.read(dashboardLayoutProvider)).h, manual);
  });

  test('yeniden acilista kucultme TEKRARLANMAZ, satir korunur', () async {
    final prefs = await _freshPrefs();
    final first = container(prefs);
    first.read(clockStyleProvider.notifier).set(ClockStyle.compact);
    final compactRows = _timerOf(first.read(dashboardLayoutProvider)).h;

    // Kullanici kompaktken karti buyutuyor, sonra uygulamayi kapatip aciyor.
    const manual = 18;
    first
        .read(dashboardLayoutProvider.notifier)
        .setBounds(DashboardCardType.timer, h: manual);

    final second = container(prefs);
    expect(
      _timerOf(second.read(dashboardLayoutProvider)).h,
      manual,
      reason:
          'Yeniden acilista kucultme bir daha uygulandi ve kullanicinin elle '
          'verdigi $manual satir $compactRows satira dusuruldu.',
    );
  });

  test('kompaktken SIFIRLAMA buyuk hucreyi geri getirmez', () async {
    // Sifirlama duzeni tazeler, saat secimini degil: kullanici hala kompakt
    // gorunumdeyse varsayilan 21 satirlik sayac hucresi geri gelmemeli.
    final prefs = await _freshPrefs();
    final c = container(prefs);
    c.read(clockStyleProvider.notifier).set(ClockStyle.compact);
    final compactRows = _timerOf(c.read(dashboardLayoutProvider)).h;

    c.read(dashboardLayoutProvider.notifier).reset();
    expect(
      _timerOf(c.read(dashboardLayoutProvider)).h,
      compactRows,
      reason:
          'Sifirlamadan sonra sayac karti $_defaultTimerRows satira dondu; '
          'kullanici kompakt secili oldugu halde dev hucreyi geri aldi.',
    );
    expect(_storedTimerRows(prefs), compactRows);

    // Geri donus yolu sifirlamadan sonra da acik kalir.
    c.read(clockStyleProvider.notifier).set(ClockStyle.digits);
    expect(_timerOf(c.read(dashboardLayoutProvider)).h, _defaultTimerRows);
  });

  test('kompakt secimi duzenin GERI KALANINI kaydirmaz', () async {
    final prefs = await _freshPrefs();
    final c = container(prefs);
    final before = c.read(dashboardLayoutProvider);
    final othersBefore = [
      for (final card in before)
        if (card.type != DashboardCardType.timer) card,
    ];
    expect(othersBefore, isNotEmpty, reason: 'karsilastirilacak kart yok');

    c.read(clockStyleProvider.notifier).set(ClockStyle.compact);
    final othersAfter = [
      for (final card in c.read(dashboardLayoutProvider))
        if (card.type != DashboardCardType.timer) card,
    ];

    expect(
      othersAfter,
      othersBefore,
      reason:
          'Kompakt secimi yalniz sayac kartini degistirmeliydi; diger kartlarin '
          'hucreleri de oynadi.\noncesi: $othersBefore\nsonrasi: $othersAfter',
    );

    c.read(clockStyleProvider.notifier).set(ClockStyle.digits);
    expect(
      [
        for (final card in c.read(dashboardLayoutProvider))
          if (card.type != DashboardCardType.timer) card,
      ],
      othersBefore,
      reason: 'Geri donuste diger kartlar yerinden oynadi.',
    );
  });

  test('sayac karti duzende yokken kompakt secimi hicbir sey bozmaz', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      _kLayoutKey: <String>['today:0:0:16:16', 'leaderboard:16:0:16:16'],
      'dashboard_grid_last_columns': _kColumns,
    });
    final prefs = await SharedPreferences.getInstance();
    final c = container(prefs);
    final before = c.read(dashboardLayoutProvider);

    c.read(clockStyleProvider.notifier).set(ClockStyle.compact);
    expect(c.read(dashboardLayoutProvider), before);
    c.read(clockStyleProvider.notifier).set(ClockStyle.digits);
    expect(c.read(dashboardLayoutProvider), before);
  });

  // ================= 2) OLCUM: 360 dp'de HUCRENIN PIKSELI =================

  group('WP-722 · 360 dp izgara hucresi (cizilen piksel)', () {
    Future<void> settle(WidgetTester tester) async {
      try {
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 3),
        );
      } catch (_) {
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 120));
        }
      }
    }

    Future<SharedPreferences> pumpHome(WidgetTester tester) async {
      final prefs = await _freshPrefs();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(_kPhoneWidth, 900);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const HomeScreen(),
          ),
        ),
      );
      await settle(tester);
      return prefs;
    }

    /// Izgaranin sayac kartina AYIRDIGI kutu: `dashboardCardFor`in kurdugu
    /// `SizedBox` (`home_screen.dart` `heightOf` sonucu).
    Rect cellRect(WidgetTester tester, Type cardType) => tester.getRect(
      find
          .ancestor(of: find.byType(cardType), matching: find.byType(SizedBox))
          .first,
    );

    /// Kartin O HUCREDE gercekten boyanan yuksekligi.
    double paintedCardHeight(WidgetTester tester) => tester
        .getSize(
          find
              .descendant(
                of: find.byType(StudyTimerCard),
                matching: find.byType(Card),
              )
              .first,
        )
        .height;

    /// Kart-ici kaydirma payi: 0'dan buyukse icerik hucreye SIGMIYOR.
    double innerScrollExtent(WidgetTester tester) {
      final scrollable = find.descendant(
        of: find.byType(StudyTimerCard),
        matching: find.byType(Scrollable),
      );
      if (scrollable.evaluate().isEmpty) return 0;
      return tester
          .state<ScrollableState>(scrollable.first)
          .position
          .maxScrollExtent;
    }

    Future<void> pickClockStyle(WidgetTester tester, String label) async {
      await tester.tap(find.byTooltip(l10n.classroomSaatGorunumu).first);
      await settle(tester);
      expect(find.text(label), findsOneWidget, reason: '$label menude yok');
      await tester.tap(find.text(label));
      await settle(tester);
    }

    testWidgets('Kompakt secilince hucre KUCULUR, taşma/ic kaydirma yok', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final prefs = await pumpHome(tester);

        final beforeCell = cellRect(tester, StudyTimerCard);
        final beforePainted = paintedCardHeight(tester);

        await pickClockStyle(tester, l10n.classroomSaatKompakt);

        final afterCell = cellRect(tester, StudyTimerCard);
        final afterPainted = paintedCardHeight(tester);
        final afterScroll = innerScrollExtent(tester);

        // ignore: avoid_print
        print(
          'WP-722 · 360 dp sayac hucresi (px)\n'
          'once   hucre ${beforeCell.height.toStringAsFixed(1)}  '
          'boyanan ${beforePainted.toStringAsFixed(1)}\n'
          'sonra  hucre ${afterCell.height.toStringAsFixed(1)}  '
          'boyanan ${afterPainted.toStringAsFixed(1)}  '
          'ic kaydirma ${afterScroll.toStringAsFixed(1)}',
        );

        expect(tester.takeException(), isNull);
        expect(
          afterCell.height,
          lessThan(beforeCell.height),
          reason:
              'Kompakt secildi ama izgara hucresi hala '
              '${afterCell.height.toStringAsFixed(1)} px '
              '(onceki ${beforeCell.height.toStringAsFixed(1)} px). Kart '
              '${afterPainted.toStringAsFixed(1)} px boyaniyor, gerisi bos '
              'alan — sahibin "kart hala cok buyuk" sikayeti aynen duruyor.',
        );
        expect(
          afterPainted,
          lessThanOrEqualTo(afterCell.height),
          reason: 'kart hucreye sigmiyor',
        );
        expect(
          afterScroll,
          0,
          reason:
              'Hucre kartin icerigine gore FAZLA kisaldi: kart icinde '
              '${afterScroll.toStringAsFixed(1)} px kaydirma dogdu. Kucultme '
              'icerigi kirpmamali.',
        );
        // Kucultme "bir tik" degil, olculebilir olmali: bos alanin buyuk
        // kismi gitmeli.
        expect(
          beforeCell.height - afterCell.height,
          greaterThanOrEqualTo(60),
          reason:
              'Hucre yalnizca '
              '${(beforeCell.height - afterCell.height).toStringAsFixed(1)} px '
              'kisaldi.',
        );
        expect(_storedTimerRows(prefs), isNotNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Kompakt secimi DIGER kartlarin hucrelerini oynatmaz', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await pumpHome(tester);
        final todayBefore = cellRect(tester, TodaySummaryCard);
        final leaderboardBefore = cellRect(tester, LeaderboardCard);

        await pickClockStyle(tester, l10n.classroomSaatKompakt);

        expect(cellRect(tester, TodaySummaryCard), todayBefore);
        expect(cellRect(tester, LeaderboardCard), leaderboardBefore);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('menuden geri donunce hucre eski boyuna doner', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await pumpHome(tester);
        final before = cellRect(tester, StudyTimerCard).height;

        await pickClockStyle(tester, l10n.classroomSaatKompakt);
        expect(cellRect(tester, StudyTimerCard).height, lessThan(before));

        await pickClockStyle(tester, l10n.classroomSadeRakam);
        expect(
          cellRect(tester, StudyTimerCard).height,
          before,
          reason:
              'Kullanici menuden Sade rakam\'a dondu ama kart kucuk kaldi — '
              'geri donus yolu yok.',
        );
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
