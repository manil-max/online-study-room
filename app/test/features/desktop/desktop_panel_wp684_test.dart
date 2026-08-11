// WP-684 — PANEL GENISLIGI PENCEREYLE BUYUMUYOR + KAPI OLCUTU YANLIS SEYI
// CEZALANDIRIYOR.
//
// ============================ KUSUR 1 (OLCULDU) ==============================
//
// Ayarlar ve alt ekranlari masaustunde `showDesktopPanel` ile, yani
// `DesktopSurface.panelWidth = 920` px SABIT bir `Dialog` icinde aciliyordu ve
// panel pencereyle HIC buyumuyordu. Duzeltmeden ONCE olculdu (2026-08-10,
// HEAD `72ee426`, `WP684PANEL` dokumu — gercek kabuk, Profil -> Ayarlar):
//
//   pencere   panel govdesi   ayarlar icerigi (boyanan glif araligi)
//    1008          920                844
//    1200          920                844
//    1920          920                844
//    2560          920                844
//
// Dort pencerede ayni sayi. Yani SPEC §1.2'nin pencere merdiveni bu ekran
// ailesinde hicbir zaman tetiklenmiyordu; 2560 px'lik monitorde de 1008 px'lik
// laptopta da AYNI kare boyaniyordu. WP-679 bunu kendi kaynak yorumunda zaten
// itiraf etmisti ("panel genisletilemez; o yuzden karar KABIN genisliginden
// verilir") — kabin kendisi de sabitti.
//
// Duzeltmeden SONRA (ayni olcum):
//
//   pencere   panel govdesi   ayarlar icerigi   sutun (ProfileFlowColumns)
//    1008          920                844                2
//    1200         1088               1019                2
//    1920         1472               1394                3
//    2560         1472               1394                3
//
// 1472 bir TAVANDIR: 2560 px pencerede de 1472'de durur. Merdivenin turetimi
// `desktop_surface.dart` icindeki `desktopPanelWidthFor` belgesindedir.
//
// ============================ KUSUR 2 (OLCULDU) ==============================
//
// `desktop_stretch_contract_test` OLCUM 3b (kart olu alani) esigi
// `kart genisligi − en genis METIN` diye hesaplaniyordu. Bu, icerigi metin
// OLMAYAN kartlari yapisal olarak cezalandiriyordu. Olculdu (ayni agac,
// istatistik/grup @1920, karsilastirma tablosu karti):
//
//   kart 684 px · hucreleri [13..41] [144..317] [321..493] [497..670]
//   en genis METIN 62 px ("V8 QA")  ->  eski olcut "olu alan 622 px" = KIRMIZI
//   gercek icerik kutusu 657 px      ->  yeni olcut "olu alan 27 px"  = yesil
//
// Kart doluydu; olculen sey yanlisti. Duzeltme `desktop_stretch_probe.dart`
// icindeki `contentInkOf`tur ve ESIK (480 px) AYNEN KALDI.
//
// 🔴 Bu dosyanin son bolumu (`olu alan olcutu`) tam olarak bunun kotuye
// kullanilamayacagini kanitlar: olcut gevsetilmedi, olcuye ALINAN sey degisti.
// Gercekten bos bir kart, gorunmez bir ayrac tasisa bile hala KIRMIZI duser.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/desktop/desktop_layout.dart';
import 'package:online_study_room/core/device_integrations/samsung_modes_service.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';
import 'package:online_study_room/features/desktop/desktop_surface.dart';
import 'package:online_study_room/features/profile/settings_screen.dart';
import 'package:online_study_room/features/profile/theme_builder/theme_builder_screen.dart';
import 'package:online_study_room/features/profile/theme_builder/theme_builder_widgets.dart';
import 'package:online_study_room/features/profile/theme_builder/theme_preview.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';
import 'package:online_study_room/main.dart';

import '../../support/v8_test_setup.dart';
import 'desktop_stretch_probe.dart';

/// Duzeltmeden sonra beklenen panel merdiveni (pencere -> panel govdesi).
///
/// Sayilar `desktop_surface.dart`'tan OKUNMAZ, birebir yazilir: sabiti
/// degistiren bir degisiklik testi de sessizce degistiremesin.
final Map<double, double> kExpectedPanelWidth = <double, double>{
  1008: 920,
  1200: 1088,
  1920: 1472,
  2560: 1472,
};

/// Panelin icindeki ayarlar govdesinin, duzeltmeden ONCE her pencerede olculen
/// sabit genisligi. Buyume iddiasi bunun USTUNE kurulur.
const double kFrozenContentWidthBefore = 844;

/// `desktop_stretch_contract_test.kMaxCardDeadWidthPx` ile ayni esik.
const double kDeadWidthCap = 480;

void main() {
  final tr = AppLocalizationsTr();

  /// 🔴 Bayrak test GOVDESI BITMEDEN geri alinmali; `tearDown` cok gec kalir ve
  /// "foundation debug variable was changed by the test" hatasi asil iddianin
  /// yerine gecer.
  Future<void> onWindows(Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  Future<void> settle(WidgetTester tester) async {
    for (var attempt = 0; attempt < 3; attempt++) {
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
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  void prepareWindow(WidgetTester tester, Size window) {
    tester.binding.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = window;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpApp(WidgetTester tester, Size window) async {
    prepareWindow(tester, window);
    final preferences = await v8SharedPreferences();
    final auth = await signedInV8AuthRepository(prefs: preferences);
    final groupRepository = InMemoryGroupRepository();
    final profile = (await auth.authStateChanges().first)!;
    await groupRepository.createGroup(name: 'Odak Kampi', creator: profile);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          groupRepositoryProvider.overrideWithValue(groupRepository),
          sharedPreferencesProvider.overrideWithValue(preferences),
          deviceIntegrationServiceProvider.overrideWithValue(
            V8TestDeviceIntegrationService(),
          ),
          androidWidgetServiceProvider.overrideWithValue(V8TestWidgetGateway()),
        ],
        child: const OnlineStudyRoomApp(),
      ),
    );
    await settle(tester);
  }

  Future<void> openSettingsPanel(WidgetTester tester) async {
    await tester.tap(find.text(tr.profileProfil).first);
    await settle(tester);
    await tester.tap(find.text(tr.profileAyarlar).last);
    await settle(tester);
  }

  Rect globalRect(RenderBox box) => MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );

  /// Master listedeki bir kategoriyi secer (WP-686 master-detay dali).
  Future<void> selectCategory(WidgetTester tester, String title) async {
    final row = find.descendant(
      of: find.byKey(kSettingsMasterListKey),
      matching: find.text(title),
    );
    expect(
      row,
      findsOneWidget,
      reason: 'Kategori master listede yok: "$title"',
    );
    await tester.tap(row);
    await settle(tester);
  }

  List<Rect> flowColumns(WidgetTester tester) {
    final out = <Rect>[];
    for (var i = 0; i < 4; i++) {
      for (final e
          in find
              .byKey(ValueKey('$kProfileFlowColumnKeyPrefix$i'))
              .evaluate()) {
        final box = e.renderObject;
        if (box is RenderBox && box.hasSize) out.add(globalRect(box));
      }
    }
    out.sort((a, b) => a.left.compareTo(b.left));
    return out;
  }

  // ==========================================================================
  // 1) PANEL PENCEREYLE BUYUR — KUSUR 1
  // ==========================================================================

  group('panel genisligi pencereye bagli — SPEC §1.2', () {
    kExpectedPanelWidth.forEach((window, expected) {
      testWidgets(
        '@${window.toInt()} panel ${expected.toInt()} px',
        (tester) async => onWindows(() async {
          await pumpApp(tester, Size(window, 1000));
          await openSettingsPanel(tester);

          // 🔴 Olculen kutu, genisligi VERILEN kutudur. `find.byType(Dialog)`
          // burada yalan soyler: `Dialog`in render kutusu tum pencereyi
          // kaplar (2560 px pencerede `getSize(...).width == 2560`), yani
          // tavani degil KABI olcer. Ayni tuzak `Align`/`Center` icin de
          // gecerli — bu yuzden anahtar `SizedBox`in uzerinde.
          final body = find.byKey(kDesktopPanelBodyKey);
          expect(
            body,
            findsOneWidget,
            reason: 'Ayarlar paneli acilmadi; olculecek kutu yok.',
          );
          final measured = tester.getSize(body).width;
          expect(
            measured,
            expected,
            reason:
                'SPEC §1.2 merdiveni: ${window.toInt()} px pencerede panel '
                '${expected.toInt()} px olmali; olculen '
                '${measured.toStringAsFixed(0)} px. Panel pencereyle '
                'buyumuyorsa bu sayi butun pencerelerde 920 kalir — kusurun '
                'ta kendisi.',
          );

          // Kutu buyudu diye ICERIK buyumus sayilmaz: boyanan glif araligi da
          // olculur. (Depo dersi: "kullanicinin GORDUGU satiri test et".)
          final probe = DesktopStretchProbe(
            tester,
            scope: find.byType(SettingsScreen),
          );
          final ink = probe.contentInkBounds();
          expect(ink, isNotNull, reason: 'Panelde hic metin boyanmamis.');
          if (window >= DesktopBreakpoints.large) {
            // 🔴 WP-686: bu bantta ayarlar artik master-detay cizer
            // (SPEC §5). "Icerik buyudu" kaniti bu yuzden glif araligi DEGIL,
            // cizilen master-detay SATIRIDIR: satir sonlari `ListTile`
            // metinleri oldugu icin ink detay sutununun sag kenarina kadar
            // uzanmaz (@1200 olculen ink 810 px), ama satirin kendisi kabin
            // tamamini kullanir.
            final master = tester.getRect(find.byKey(kSettingsMasterListKey));
            final detail = tester.getRect(find.byKey(kSettingsDetailPaneKey));
            final row = detail.right - master.left;
            expect(
              row,
              greaterThan(kFrozenContentWidthBefore),
              reason:
                  'Panel kutusu buyudu ama ICERIK satiri hala '
                  '${row.toStringAsFixed(0)} px — duzeltmeden onceki donmus '
                  '${kFrozenContentWidthBefore.toInt()} px degerinin ustune '
                  'cikmadi. Genisleyen sey yalniz bos kap.',
            );
            expect(
              row,
              expected - DesktopSurface.panelChrome,
              reason:
                  'Master-detay satiri panel bandini doldurmuyor: satir '
                  '${row.toStringAsFixed(0)} px, bant '
                  '${(expected - DesktopSurface.panelChrome).toInt()} px.',
            );
          } else {
            expect(
              ink!.width,
              closeTo(kFrozenContentWidthBefore, 1),
              reason:
                  '1200 px altinda WP-679 duzeni BIREBIR korunmali; olculen '
                  '${ink.width.toStringAsFixed(0)} px.',
            );
          }
          // Panel bir `Dialog`tir: pencereyi KAPLAMAZ.
          expect(
            measured,
            lessThan(window),
            reason: 'Panel pencereyi kapladi; artik dialog degil.',
          );
          // SPEC §2.3 izgara toplami: icerik 1440'ta durur.
          expect(
            ink!.width,
            lessThanOrEqualTo(DesktopBreakpoints.maxContentWidth),
            reason:
                'Panel icerigi SPEC §2.3 izgara tavanini asti: '
                '${ink.width.toStringAsFixed(0)} px.',
          );

          // ISLEV KAYBI YOK: butun ayar bolumleri ve kritik satirlar duruyor.
          for (final title in [
            tr.settingsSectionAppearance,
            tr.settingsSectionNotifications,
            tr.settingsSectionAccount,
            // WP-710: "Calisma tercihleri" bolumu kaldirildi (sahip emri).
            tr.settingsSectionPrivacySecurity,
            tr.settingsSectionAboutLegal,
            tr.settingsSectionHelp,
          ]) {
            expect(
              find.text(title),
              findsWidgets,
              reason: 'Panel genisleyince ayar bolumu kayboldu: "$title"',
            );
          }
          // 🔴 WP-686: >= 1200'de ayarlar master-detaydir, yani ayni anda
          // TEK kategori cizilir. "Anahtar agacta mi" artik YANLIS olcumdur;
          // dogru olcum "kategorisi secilince geliyor mu".
          // WP-710: olculen satir degisti. "Gunluk hedef" Ayarlar'dan
          // kaldirildi; yerine ayni kapiyi TASINAN satir tasiyor — sifirlama
          // artik "Yardim" kategorisinde ve SSS ile ayni yerde olculuyor.
          if (window >= DesktopBreakpoints.large) {
            await selectCategory(tester, tr.settingsSectionHelp);
          }
          expect(
            find.byKey(const Key('settings-faq')),
            findsOneWidget,
            reason: 'SSS satiri "Yardim" kategorisinde bulunamadi.',
          );
          expect(
            find.byKey(const Key('reset-introduction-tours')),
            findsOneWidget,
            reason:
                'Tasinan sifirlama satiri "Yardim" kategorisinde bulunamadi '
                '— master-detay bir satiri ULASILAMAZ yapti.',
          );
          expect(
            find.byKey(const Key('settings-daily-goal')),
            findsNothing,
            reason: 'Gunluk hedef satiri hala Ayarlar\'da.',
          );

          // ISLEV KAYBI YOK: panel Esc ile kapanir (WP-569 sozlesmesi).
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await settle(tester);
          expect(
            find.byKey(kDesktopPanelBodyKey),
            findsNothing,
            reason: 'Esc paneli kapatmiyor — WP-569 sozlesmesi kirildi.',
          );
        }),
      );
    });

    testWidgets(
      'panel 920 kalirken ayarlar 2 sutun (WP-679 duzeni korunur)',
      (tester) async => onWindows(() async {
        await pumpApp(tester, const Size(1008, 1000));
        await openSettingsPanel(tester);
        expect(
          flowColumns(tester).length,
          2,
          reason:
              '1008 px pencerede panel 920 px kalir; WP-679 duzeni 2 sutundur.',
        );
      }),
    );

    // 🔴 WP-686 bu iddiayi DEGISTIRDI. Eskiden "kap 1440 -> 3 akan sutun"
    // deniyordu; SPEC §5 ayarlari **A1 / master-detay** sayar ve WP-686 onu
    // uyguladi. Korunan sey AYNI: 1472 px'lik panelin 1440 px'lik bandi
    // GERCEKTEN kullanilmali. Olcut, akan sutun sayisindan cizilen
    // master-detay satirina tasindi — gevsemedi: sabit 1056 px'lik bir satir
    // (SPEC §5'in lafzi) bu iddiayi 384 px farkla KIRMIZI dusurur.
    testWidgets(
      'xlarge pencerede master-detay satiri 1440 px bandi doldurur',
      (tester) async => onWindows(() async {
        await pumpApp(tester, const Size(1920, 1000));
        await openSettingsPanel(tester);

        final master = tester.getRect(find.byKey(kSettingsMasterListKey));
        final detail = tester.getRect(find.byKey(kSettingsDetailPaneKey));
        expect(
          master.width,
          kSettingsMasterWidth,
          reason: 'SPEC §3 A1: kategori sutunu 280 px.',
        );
        expect(
          detail.left - master.right,
          kSettingsPaneSpacing,
          reason: 'SPEC §3 A1: pane araligi 16 px.',
        );
        expect(
          detail.right - master.left,
          DesktopSurface.panelWidthXLarge - DesktopSurface.panelChrome,
          reason:
              'Panel 1472 px -> kap 1440 px. Master-detay satiri '
              '${(detail.right - master.left).toStringAsFixed(0)} px — kabin '
              'kalani bos kaliyor (sahibin "iki yan bos" sikayeti).',
        );

        // Detay kartlari SPEC §3 A2 akisina duser; hicbir sutun 760'i asmaz.
        final columns = flowColumns(tester);
        expect(
          columns.length,
          2,
          reason:
              'Detay 1144 px -> `profileFlowColumns` 2 sutun demeli. Olculen '
              '${columns.length} sutun.',
        );
        for (var i = 1; i < columns.length; i++) {
          expect(
            columns[i].left,
            greaterThanOrEqualTo(columns[i - 1].right - 1),
            reason: 'Iki sutun ust uste cizilmis.',
          );
        }
        for (final column in columns) {
          expect(
            column.width,
            lessThanOrEqualTo(DesktopBreakpoints.maxFormWidth),
            reason:
                'SPEC §2.3: bir ayar sutunu 760 px\'i asamaz; olculen '
                '${column.width.toStringAsFixed(0)} px.',
          );
        }
      }),
    );
  });

  // ==========================================================================
  // 2) MOBIL REGRESYON — SPEC §7
  // ==========================================================================

  group('mobil 390x844 — SPEC §7 panel dali degismedi', () {
    testWidgets('showDesktopPanel mobilde hala TAM SAYFA rota iter', (
      tester,
    ) async {
      // Platform override YOK -> `isDesktopWindow == false`.
      prepareWindow(tester, const Size(390, 844));
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showDesktopPanel<void>(
                    context: context,
                    builder: (_) => const Scaffold(
                      body: Center(child: Text('panel-govdesi')),
                    ),
                  ),
                  child: const Text('ac'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ac'));
      await settle(tester);

      expect(find.text('panel-govdesi'), findsOneWidget);
      expect(
        find.byKey(kDesktopPanelBodyKey),
        findsNothing,
        reason:
            'SPEC §7: masaustu paneli mobil dala sizmis. Mobilde '
            '`MaterialPageRoute` itilir, `Dialog` acilmaz.',
      );
      expect(
        find.byType(Dialog),
        findsNothing,
        reason: 'Mobilde dialog acildi — mobil agac degisti.',
      );
    });
  });

  // ==========================================================================
  // 3) TEMA OLUSTURUCU — hic olculmemisti (KUSUR 3)
  // ==========================================================================
  //
  // 🔴 YALANLANAN BELGE: `desktop_settings_wp679_test.dart` bas yorumu tema
  // olusturucuyu "1040 px'lik sabit studio panelinde zaten yan yana iki bolme
  // cizer" diye kapsam disi birakmisti. Kaynakta olculdu: `showDesktopStudio`
  // fonksiyonunun `lib/` icinde TEK BIR cagri yeri yok. `ThemeBuilderScreen`
  // `appearance_screen.dart` icinde duz bir `MaterialPageRoute` ile itilir ve o
  // rota AYARLAR PANELININ kendi `Navigator`ina duser — yani ekran 1040 px'lik
  // studyoda degil, ayarlar panelinin bandinda cizilir. Bant sabit 920 iken
  // kusur gorunmuyordu.
  //
  // Duzeltme oncesi olcum (`WP684THEME`, panel bandinda):
  //   band 920  : duzenleyici 484 · onizleme 388 · en genis satir 358
  //   band 1088 : duzenleyici 578 · onizleme 462 · en genis satir 432
  //   band 1472 : duzenleyici 791 · onizleme 633 · en genis satir 603
  // 1472'de IKI ihlal: duzenleyici 791 > 760 (SPEC §2.3 form sutunu) ve
  // "Canli onizleme -> Koyu" satiri 603 > 600 (SPEC KURAL 2.2 sert tavani).
  // Ikisi de panel buyudugu ANDA aciliyordu; yani KUSUR 1'in duzeltmesi bu
  // ekranda olculebilir bir kusur uretecekti.

  Future<void> mountThemeBuilder(WidgetTester tester, double band) async {
    prepareWindow(tester, const Size(2560, 1440));
    final preferences = await v8SharedPreferences();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // Panel bandinin taklidi: `showDesktopPanel` govdesi de tam olarak
          // boyle bir `SizedBox`tir.
          home: Center(
            child: SizedBox(
              width: band,
              height: 680,
              child: const ThemeBuilderScreen(),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  group('tema olusturucu — panel bandinda', () {
    for (final band in kExpectedPanelWidth.values.toSet()) {
      testWidgets(
        'band ${band.toInt()} — duzenleyici <= 760, satir <= 600',
        (tester) async => onWindows(() async {
          await mountThemeBuilder(tester, band);

          final editor = find.byKey(const Key(kThemeBuilderEditorPaneKey));
          expect(
            editor,
            findsOneWidget,
            reason:
                'Yan yana duzen cizilmedi: ${band.toInt()} px bant '
                '720 esiginin ustunde, duzenleyici bolmesi olmali.',
          );
          final editorWidth = tester.getSize(editor).width;
          expect(
            editorWidth,
            lessThanOrEqualTo(DesktopBreakpoints.maxFormWidth),
            reason:
                'SPEC §2.3 form sutunu 760 px. Duzenleyici bolmesi '
                '${editorWidth.toStringAsFixed(0)} px — `Expanded(flex: 5)` '
                'tavansiz oldugu icin bant buyudukce buyuyordu.',
          );

          // ISLEV: onizleme hala YANDA.
          final previewFinder = find.byType(ThemePreviewCard);
          expect(
            previewFinder,
            findsOneWidget,
            reason: 'Canli onizleme kayboldu.',
          );
          final preview = tester.getRect(previewFinder);
          final editorRect = tester.getRect(editor);
          expect(
            preview.left,
            greaterThanOrEqualTo(editorRect.right - 1),
            reason:
                'Onizleme duzenleyicinin sagina dusmemis: duzenleyici '
                '${editorRect.left.toStringAsFixed(0)}..'
                '${editorRect.right.toStringAsFixed(0)}, onizleme '
                '${preview.left.toStringAsFixed(0)}..'
                '${preview.right.toStringAsFixed(0)}',
          );

          final probe = DesktopStretchProbe(
            tester,
            scope: find.byType(ThemeBuilderScreen),
          );
          for (final row in probe.labelValueRows().take(3)) {
            expect(
              row.span,
              lessThanOrEqualTo(DesktopBreakpoints.maxLabelValueWidth),
              reason:
                  'SPEC KURAL 2.2 sert tavani 600 px (80 karakter, '
                  'WCAG 2.1 SC 1.4.8): "${row.label.text}" -> '
                  '"${row.value.text}" satiri '
                  '${row.span.toStringAsFixed(0)} px.',
            );
          }

          // ISLEV KAYBI YOK: adim noktalari, ileri dugmesi ve zemin adiminin
          // secenek izgarasi yerinde.
          expect(find.byType(StepDots), findsOneWidget);
          expect(find.text(tr.profileIleri), findsOneWidget);
          expect(find.byType(GridView), findsWidgets);
        }),
      );
    }

    testWidgets('mobil 390x844 — yan yana duzen mobile sizmadi', (
      tester,
    ) async {
      // Platform override YOK -> `isDesktopWindow == false`.
      prepareWindow(tester, const Size(390, 844));
      final preferences = await v8SharedPreferences();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
          child: MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ThemeBuilderScreen(),
          ),
        ),
      );
      await settle(tester);
      expect(
        find.byKey(const Key(kThemeBuilderEditorPaneKey)),
        findsNothing,
        reason: 'SPEC §7: masaustu yan yana duzeni mobil dala sizmis.',
      );
      expect(find.byType(ThemePreviewCard), findsOneWidget);
    });

    testWidgets(
      'kaydetme yolu duruyor — son adimda ad alani ve Bitir',
      (tester) async => onWindows(() async {
        await mountThemeBuilder(tester, 1472);
        // Ozet adimina (8/8) gec: yedi kez "Ileri".
        for (var i = 0; i < 7; i++) {
          await tester.tap(find.text(tr.profileIleri));
          await settle(tester);
        }
        expect(
          find.byType(TextField),
          findsWidgets,
          reason: 'Tema adi alani kayboldu — kaydetme yolu kirildi.',
        );
        expect(
          find.text(tr.profileBitir),
          findsOneWidget,
          reason: 'Kaydet/Bitir dugmesi kayboldu.',
        );
      }),
    );
  });

  // ==========================================================================
  // 4) OLU ALAN OLCUTU — KUSUR 2 ve SABOTAJI
  // ==========================================================================
  //
  // Bu bolum bir BILESEN testidir, ekran testi degil: olcutun KENDISI
  // sinaniyor. Gerekcesi, kapilarin genellikle sessizce gevsetilmesi. Her durum
  // olcutun dogru seyi cezalandirdigini iki yonlu gosterir.

  Future<PaintedCard> measureCard(WidgetTester tester, Widget child) async {
    prepareWindow(tester, const Size(2000, 400));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 1400, child: Card(child: child)),
          ),
        ),
      ),
    );
    await tester.pump();
    final cards = DesktopStretchProbe(tester).paintedCards();
    expect(cards, isNotEmpty, reason: 'Kart cizilmedi.');
    return cards.first;
  }

  group('olu alan olcutu — dogru seyi cezalandiriyor mu', () {
    testWidgets('SABOTAJ: 1400 px kart + tek satir metin -> KIRMIZI', (
      tester,
    ) async {
      final card = await measureCard(
        tester,
        const SizedBox(
          height: 80,
          child: Align(alignment: Alignment.centerLeft, child: Text('2s')),
        ),
      );
      expect(card.rect.width, 1400);
      expect(
        card.deadWidth,
        greaterThan(kDeadWidthCap),
        reason:
            'Sahibin "800 px kart, icinde tek bir 2s" sikayeti hala '
            'yakalanmali. Olculen olu alan '
            '${card.deadWidth.toStringAsFixed(0)} px.',
      );
    });

    testWidgets('SABOTAJ: gorunmez ayrac olcutu kandirmaz -> hala KIRMIZI', (
      tester,
    ) async {
      // `Divider` kabin TAMAMINI kaplayan bir `RenderDecoratedBox` cizer.
      // Sayilsaydi, icinde ayrac bulunan HER kart "dolu" gorunur ve olcut
      // sessizce olurdu.
      final card = await measureCard(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text('2s'), Divider(), Text('4s')],
        ),
      );
      expect(
        card.deadWidth,
        greaterThan(kDeadWidthCap),
        reason:
            'Kil payi ayrac icerik sayilmis: olu alan '
            '${card.deadWidth.toStringAsFixed(0)} px. Olcut kendini kapatti.',
      );
    });

    testWidgets('SABOTAJ: kartin KENDI yuzeyi icerik sayilmaz', (tester) async {
      // Her `Card` icin kart genisliginde bir `RenderPhysicalShape` +
      // `RenderCustomPaint` boyanir. Sayilsalardi olu alan HER kartta 0 cikar.
      final card = await measureCard(
        tester,
        const SizedBox(
          height: 80,
          child: Align(alignment: Alignment.centerLeft, child: Text('x')),
        ),
      );
      expect(
        card.contentInk!.width,
        lessThan(100),
        reason:
            'Kartin kendi Material yuzeyi "icerik" sayilmis: icerik kutusu '
            '${card.contentInk!.width.toStringAsFixed(0)} px.',
      );
    });

    testWidgets('GRAFIK karti artik cezalandirilmaz -> YESIL', (tester) async {
      final card = await measureCard(
        tester,
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 120,
            child: CustomPaint(
              painter: _BarsPainter(),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      expect(
        card.widestText,
        0,
        reason: 'Bu kartta hic metin yok — eski olcut 1400 px olu alan derdi.',
      );
      expect(
        card.deadWidth,
        lessThanOrEqualTo(kDeadWidthCap),
        reason:
            'Cizim dolu bir kart hala cezalandiriliyor: olu alan '
            '${card.deadWidth.toStringAsFixed(0)} px.',
      );
    });

    testWidgets('TABLO karti artik cezalandirilmaz -> YESIL', (tester) async {
      // Karsilastirma tablosunun sadelestirilmis hali: dar metinler, genis
      // hucreler. Gercek kartta olculen desen buydu.
      final card = await measureCard(
        tester,
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const SizedBox(width: 60, child: Text('V8')),
              for (var i = 0; i < 3; i++) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 28,
                    color: const Color(0xFF335577),
                    child: const Center(child: Text('-')),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
      expect(
        card.textOnlyDeadWidth,
        greaterThan(kDeadWidthCap),
        reason:
            'ESKI olcut bu karti KIRMIZI dusururdu; kanit olarak burada hala '
            'tavanin ustunde olmali. Degilse durum kusuru temsil etmiyor.',
      );
      expect(
        card.deadWidth,
        lessThanOrEqualTo(kDeadWidthCap),
        reason:
            'YENI olcut tablo kartini hala cezalandiriyor: olu alan '
            '${card.deadWidth.toStringAsFixed(0)} px.',
      );
    });

    testWidgets('yeni olcut eskisinden GEVSEK degil, DAR', (tester) async {
      // `contentInk` her zaman en genis metni KAPSAR, yani
      // `deadWidth <= textOnlyDeadWidth`. Bu, olcut degisiminin hicbir yeni
      // kirmizi URETEMEYECEGINI de garanti eder.
      final card = await measureCard(
        tester,
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Bu donemde henuz calisma kaydi yok.'),
        ),
      );
      expect(card.deadWidth, lessThanOrEqualTo(card.textOnlyDeadWidth));
    });
  });
}

/// Grafik kartinin taklidi: kabin tamamini boyayan bir `CustomPaint`.
class _BarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF4488CC);
    for (var i = 0; i < 20; i++) {
      final x = size.width * i / 20;
      canvas.drawRect(
        Rect.fromLTWH(x, size.height * 0.2, size.width / 30, size.height * 0.8),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
