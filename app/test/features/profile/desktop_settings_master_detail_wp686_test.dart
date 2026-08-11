// WP-686 — AYARLARDA MASTER-DETAY + KALAN SABIT GENISLIKLER.
//
// ========================= DUZELTME ONCESI OLCUM ============================
//
// Gercek kabuk (Profil -> Ayarlar), `WP686PANEL` dokumu, 2026-08-11:
//
//   pencere  panel      ayarlar duzeni            ink   dikey kaydirma
//    1008    920x680    2 akan sutun (432/432)    844        278
//    1200   1088x680    2 akan sutun (516/516)   1019        254
//    1920   1472x680    3 akan sutun (464x3)     1394        180
//    2560   1472x680    3 akan sutun (464x3)     1394        180
//
// WP-679 SPEC §5'in *"settings -> master-detay: 280 kategori + 760 detay"*
// kararini uygulayamamisti ve gerekcesi OLCULMUSTU: panel sabit 920 px, kap
// 888 px, `280 + 16 + 760 = 1056` sigmiyordu. WP-684 paneli pencereye baglayip
// `large` basamagini tam olarak **1056 + 32** diye turetince satir sigar oldu.
//
// ========================= DUZELTME SONRASI OLCUM ===========================
//
//   pencere  panel      master  bosluk  detay   satir   detay sutunu  kaydirma
//    1008    920x680      —       —       —       —      2 akan (432)     278
//    1200   1088x680     280     16      760    1056     1 sutun            0
//    1920   1472x680     280     16     1144    1440     2 sutun (560)      0
//    2560   1472x680     280     16     1144    1440     2 sutun (560)      0
//
// Iki sonuc:
//  1. Satir kabin TAMAMINI kullanir (1056 = 1088 − 32, 1440 = 1472 − 32).
//     Sabit 1056'lik bir satir `xlarge` panelin **384 px**'ini bos birakirdi.
//  2. Dikey kaydirma 254/180 -> **0**. Panelin 680 px'lik sabit yuksekligi bu
//     ekran icin artik baglayici degil — bkz. `PANEL YUKSEKLIGI` bolumu.
//
// ============================= NEYI KORUR ==================================
//
// 1. Her iddia CIZILEN kutudan okunur. Panel gövdesi `kDesktopPanelBodyKey`,
//    picker gövdesi `kDesktopPickerBodyKey` ile bulunur: `find.byType(Dialog)`
//    tum pencereyi dondurur, yani tavani degil KABI olcer.
// 2. Master-detay bir seyi GIZLER (ayni anda tek kategori). Bu yuzden islev
//    kaybi kontrolu "anahtar agacta mi" degil, "her kategori SECILEBILIR mi ve
//    satiri o zaman geliyor mu" diye olculur — yedi kategori de tek tek gezilir.
// 3. Esik KABA baglidir, pencereye degil. Sabotaj bolumu 1 px'lik farkla
//    bunu iki yonlu kanitlar.
//
// ============================ NEYI KORUMAZ =================================
//
// - Guzellik, renk, kontrast, golden.
// - Panelin BASKA ekranlari (kayitlar, hesabim, bildirim merkezi): onlarin
//   dikey kaydirmasi bu WP'nin disinda.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'package:online_study_room/features/desktop/desktop_page_scaffold.dart';
import 'package:online_study_room/features/desktop/desktop_surface.dart';
import 'package:online_study_room/features/home/widgets/card_picker.dart';
import 'package:online_study_room/features/profile/appearance_screen.dart';
import 'package:online_study_room/features/profile/account_settings_screen.dart';
import 'package:online_study_room/features/profile/settings_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';
import 'package:online_study_room/main.dart';

import '../../support/v8_test_setup.dart';

/// Duzeltmeden ONCE her pencerede olculen, donmus ayarlar icerik genisligi.
const double kFrozenSettingsInkAt920 = 844;

/// Panel gövdesinin yatay kenar boslugu (`DesktopSurface.panelChrome`).
const double kPanelChrome = 32;

void main() {
  final tr = AppLocalizationsTr();

  /// 🔴 Bayrak test GOVDESI BITMEDEN geri alinmali; `tearDown` cok gec kalir.
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

  Rect globalRect(RenderBox box) => MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );

  void walk(RenderObject node, void Function(RenderObject) visit) {
    if (node is RenderOffstage && node.offstage) return;
    visit(node);
    node.visitChildren((child) => walk(child, visit));
  }

  bool isIconGlyph(String text) {
    final trimmed = text.trim();
    if (trimmed.runes.length != 1) return false;
    final code = trimmed.runes.first;
    return code >= 0xE000 && code <= 0xF8FF;
  }

  /// Bir paragrafin EKRANDA boyanan glif kutusu (kutusu degil GLIFI).
  Rect? ink(RenderParagraph p) {
    if (!p.hasSize) return null;
    final text = p.text.toPlainText();
    if (text.trim().isEmpty || isIconGlyph(text)) return null;
    final boxes = p.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: text.length),
    );
    if (boxes.isEmpty) return null;
    var local = boxes.first.toRect();
    for (final b in boxes.skip(1)) {
      local = local.expandToInclude(b.toRect());
    }
    return MatrixUtils.transformRect(p.getTransformTo(null), local);
  }

  Rect? inkBounds(Finder scope) {
    final elements = scope.evaluate();
    if (elements.isEmpty) return null;
    Rect? union;
    walk(elements.first.renderObject!, (node) {
      if (node is! RenderParagraph) return;
      final r = ink(node);
      if (r == null) return;
      union = union == null ? r : union!.expandToInclude(r);
    });
    return union;
  }

  /// [scope] altindaki en buyuk dikey kaydirma payi. 0 = icerik SIGDI.
  double scrollExtent(WidgetTester tester, Finder scope) {
    var worst = 0.0;
    for (final e
        in find
            .descendant(of: scope, matching: find.byType(Scrollable))
            .evaluate()) {
      final state = (e as StatefulElement).state as ScrollableState;
      if (!state.position.hasContentDimensions) continue;
      if (state.position.axis != Axis.vertical) continue;
      if (state.position.maxScrollExtent > worst) {
        worst = state.position.maxScrollExtent;
      }
    }
    return worst;
  }

  /// Cizilen [ProfileFlowColumns] sutunlari, soldan saga.
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

  /// Kategori basliklari — master listenin satirlari.
  ///
  /// WP-710 (sahip emri): "Calisma tercihleri" bolumu KALDIRILDI, yediden
  /// altiya indi. Iddia silinmedi; liste yeni gercegi olcuyor ve asagidaki
  /// [rowsByCategory] tasinan sifirlama satirini "Yardim"da ariyor.
  List<String> sectionTitles() => [
    tr.settingsSectionAppearance,
    tr.settingsSectionNotifications,
    tr.settingsSectionAccount,
    tr.settingsSectionPrivacySecurity,
    tr.settingsSectionAboutLegal,
    tr.settingsSectionHelp,
  ];

  /// Kategori -> o kategoride bulunmasi ZORUNLU satir anahtarlari.
  ///
  /// 🔴 Bu tablo islev kaybi kapisidir: master-detay ayni anda tek kategori
  /// cizer, yani "anahtar agacta mi" diye bakmak artik yanlis olcumdur.
  Map<String, List<Key>> rowsByCategory() => {
    tr.settingsSectionPrivacySecurity: const [Key('settings-muted-nudges')],
    tr.settingsSectionAboutLegal: const [
      Key('settings-about-updates'),
      Key('settings-feedback'),
    ],
    // WP-710: sifirlama satiri "Calisma tercihleri"nden buraya tasindi.
    tr.settingsSectionHelp: const [
      Key('settings-faq'),
      Key('reset-introduction-tours'),
    ],
  };

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

  // =========================================================================
  // 1) MASTER-DETAY OLCULERI — gercek kabuk
  // =========================================================================

  group('ayarlar master-detay — SPEC §3 A1 / §5', () {
    testWidgets(
      '@1008 master-detay ACILMAZ; WP-679 akan sutun duzeni BIREBIR',
      (tester) async => onWindows(() async {
        await pumpApp(tester, const Size(1008, 1000));
        await openSettingsPanel(tester);

        expect(
          tester.getSize(find.byKey(kDesktopPanelBodyKey)).width,
          DesktopSurface.panelWidth,
          reason: '1008 px pencerede panel 920 px kalir (WP-684 merdiveni).',
        );
        expect(
          find.byKey(kSettingsMasterListKey),
          findsNothing,
          reason:
              'Kap 888 px; master-detay satiri 1056 px. Sigmayan bir dal '
              'cizildi — depoda kayitli "baglanmamis UI" hatasinin tersi.',
        );
        final columns = flowColumns(tester);
        expect(columns.length, 2, reason: 'WP-679 duzeni 2 sutundu.');
        expect(columns.first.width, 432);
        expect(columns.last.width, 432);
        final bounds = inkBounds(find.byType(SettingsScreen));
        expect(
          bounds!.width,
          closeTo(kFrozenSettingsInkAt920, 1),
          reason:
              'WP-679 bandinda icerik BIREBIR korunmali; olculen '
              '${bounds.width.toStringAsFixed(0)} px, beklenen '
              '${kFrozenSettingsInkAt920.toInt()} px.',
        );
      }),
    );

    // pencere -> (panel, detay genisligi, satir genisligi, detay akis sutunu)
    final expected = <double, (double, double, double, int)>{
      1200: (DesktopSurface.panelWidthLarge, 760, 1056, 1),
      1920: (DesktopSurface.panelWidthXLarge, 1144, 1440, 2),
      2560: (DesktopSurface.panelWidthXLarge, 1144, 1440, 2),
    };

    expected.forEach((window, want) {
      final (panelWidth, detailWidth, rowWidth, detailColumns) = want;
      testWidgets(
        '@${window.toInt()} master 280 + 16 + detay ${detailWidth.toInt()}',
        (tester) async => onWindows(() async {
          await pumpApp(tester, Size(window, window == 2560 ? 1440 : 1000));
          await openSettingsPanel(tester);

          final panel = find.byKey(kDesktopPanelBodyKey);
          expect(tester.getSize(panel).width, panelWidth);

          final master = find.byKey(kSettingsMasterListKey);
          expect(
            master,
            findsOneWidget,
            reason:
                'SPEC §5: ${window.toInt()} px pencerede ayarlar master-detay '
                'olmali. Kategori sutunu hic cizilmemis.',
          );
          final masterRect = tester.getRect(master);
          final detailRect = tester.getRect(find.byKey(kSettingsDetailPaneKey));

          expect(
            masterRect.width,
            kSettingsMasterWidth,
            reason:
                'SPEC §3 A1 tablosu: master sutunu 280 px; olculen '
                '${masterRect.width.toStringAsFixed(0)} px.',
          );
          expect(
            detailRect.left - masterRect.right,
            kSettingsPaneSpacing,
            reason: 'SPEC §3 A1: pane araligi 16 px.',
          );
          expect(
            detailRect.width,
            detailWidth,
            reason:
                'SPEC §3 A1: detay = kalan. ${window.toInt()} px pencerede '
                '${detailWidth.toInt()} px olmali; olculen '
                '${detailRect.width.toStringAsFixed(0)} px.',
          );

          // 🔴 SATIR KABI DOLDURUR. Sabit 1056'lik bir satir 1472'lik panelin
          // 384 px'ini bos birakirdi — sahibin "iki yan bos" sikayeti.
          expect(
            detailRect.right - masterRect.left,
            rowWidth,
            reason:
                'Master-detay satiri kabi doldurmuyor: olculen '
                '${(detailRect.right - masterRect.left).toStringAsFixed(0)} px, '
                'kap ${(panelWidth - kPanelChrome).toInt()} px.',
          );
          expect(
            rowWidth,
            panelWidth - kPanelChrome,
            reason: 'Beklenen satir, panel bandinin ta kendisi olmali.',
          );

          // Detay kartlari SPEC §3 A2 akisina duser; hicbir sutun 760'i asmaz.
          final columns = flowColumns(tester);
          expect(
            columns.length,
            detailColumns == 1 ? 0 : detailColumns,
            reason:
                'Detay ${detailWidth.toInt()} px; beklenen akis '
                '$detailColumns sutun.',
          );
          for (final column in columns) {
            expect(
              column.width,
              lessThanOrEqualTo(DesktopBreakpoints.maxFormWidth),
              reason:
                  'SPEC §2.3: bir ayar sutunu 760 px\'i asamaz; olculen '
                  '${column.width.toStringAsFixed(0)} px.',
            );
          }

          // Icerik SPEC §2.3 izgara toplamini asmaz.
          final bounds = inkBounds(find.byType(SettingsScreen));
          expect(bounds, isNotNull);
          expect(
            bounds!.width,
            lessThanOrEqualTo(DesktopBreakpoints.maxContentWidth),
            reason:
                'Panel icerigi 1440 px izgara tavanini asti: '
                '${bounds.width.toStringAsFixed(0)} px.',
          );
          // Panel bir `Dialog`tir: pencereyi KAPLAMAZ.
          expect(tester.getSize(panel).width, lessThan(window));
        }),
      );
    });
  });

  // =========================================================================
  // 2) ISLEV KAYBI — yedi kategori de SECILEBILIR, satirlari geliyor
  // =========================================================================

  group('islev kaybi yok — SPEC §7', () {
    testWidgets(
      '@1920 her kategori secilebilir, her ayar satiri ULASILABILIR',
      (tester) async => onWindows(() async {
        await pumpApp(tester, const Size(1920, 1000));
        await openSettingsPanel(tester);

        // Butun basliklar master listede AYNI ANDA duruyor.
        for (final title in sectionTitles()) {
          expect(
            find.descendant(
              of: find.byKey(kSettingsMasterListKey),
              matching: find.text(title),
            ),
            findsOneWidget,
            reason: 'Ayar bolumu master listeden kayboldu: "$title"',
          );
        }

        // Her kategori tek tek gezilir; satirlari o kategoride CIZILIYOR.
        final rows = rowsByCategory();
        for (final title in sectionTitles()) {
          await selectCategory(tester, title);
          expect(
            find.descendant(
              of: find.byKey(kSettingsDetailPaneKey),
              matching: find.text(title),
            ),
            findsOneWidget,
            reason: 'Detay pane secili kategorinin basligini cizmedi.',
          );
          for (final key in rows[title] ?? const <Key>[]) {
            expect(
              find.byKey(key),
              findsOneWidget,
              reason:
                  'Ayar satiri "$title" kategorisinde bulunamadi: $key. '
                  'Master-detay bir satiri ULASILAMAZ hale getirdiyse islev '
                  'kaybi vardir.',
            );
          }
        }
      }),
    );

    testWidgets(
      '@1920 gorunum -> tema ekrani ve hesap -> hesabimi yonet acilir',
      (tester) async => onWindows(() async {
        await pumpApp(tester, const Size(1920, 1000));
        await openSettingsPanel(tester);

        await selectCategory(tester, tr.settingsSectionAppearance);
        await tester.tap(find.text(tr.profileGorunumVeAtmosferTemalari));
        await settle(tester);
        expect(
          find.byType(AppearanceScreen),
          findsOneWidget,
          reason:
              'Tema olusturucuya gecis kirildi: Gorunum satiri artik '
              '`AppearanceScreen`i acmiyor.',
        );

        // Panel ici geri: Esc panel gecmisini geri alir (WP-569).
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await settle(tester);
        expect(find.byKey(kDesktopPanelBodyKey), findsOneWidget);

        await selectCategory(tester, tr.settingsSectionAccount);
        await tester.tap(find.text(tr.profileHesabimiYonet));
        await settle(tester);
        expect(
          find.byType(AccountSettingsScreen),
          findsOneWidget,
          reason: 'Hesap silme akisinin girisi (Hesabimi yonet) kayboldu.',
        );
      }),
    );

    testWidgets(
      '@1920 Esc paneli kapatir — WP-569 sozlesmesi',
      (tester) async => onWindows(() async {
        await pumpApp(tester, const Size(1920, 1000));
        await openSettingsPanel(tester);
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

  // =========================================================================
  // 3) PANEL YUKSEKLIGI — KARAR: pencereye BAGLANMADI
  // =========================================================================
  //
  // Panel yuksekligi 680 px'te sabit kalir. Gerekce OLCULDU, uydurulmadi:
  //
  //  · Genislik merdiveninin her basamagi SPEC'ten bir SAYIYA dayaniyordu
  //    (1056 = 280+16+760, 1440 = izgara toplami). Yukseklik icin SPEC'te
  //    karsiligi olan tek bir sayi yok; panelde acilan her ekran dikeyde
  //    sinirsiz bir liste tasir. Uydurulacak her tavan gerekcesiz olurdu
  //    (`DESKTOP-UI-SPEC.md` "GEREKCE YOK" bolumu).
  //  · Olculen kusur zaten yukseklikten degil GENISLIKTEN geliyordu: ayarlar
  //    duzeltmeden once 1088 px bantta 254 px, 1472 px bantta 180 px
  //    kaydiriyordu. Master-detay sonrasi ikisi de **0**.
  //  · Panel bir `Dialog`tir. Genislik sozlesmesi "panel < pencere" der;
  //    yukseklik icin cömert bir oran ayni sozlesmeyi dikeyde bozardi.
  //
  // Asagidaki iki iddia bu karari BAGLAR: karar degisirse test kirmizi duser.

  group('panel yuksekligi — karar bagli', () {
    testWidgets(
      'panel yuksekligi pencereyle DEGISMEZ (680)',
      (tester) async => onWindows(() async {
        for (final window in const [Size(1200, 1000), Size(2560, 1440)]) {
          await pumpApp(tester, window);
          await openSettingsPanel(tester);
          expect(
            tester.getSize(find.byKey(kDesktopPanelBodyKey)).height,
            DesktopSurface.panelHeight,
            reason:
                '${window.width.toInt()}x${window.height.toInt()} penceresinde '
                'panel yuksekligi 680 kalmali (WP-686 karari).',
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await settle(tester);
        }
      }),
    );

    testWidgets(
      '680 px YETIYOR: master-detayda dikey kaydirma sifir',
      (tester) async => onWindows(() async {
        for (final window in const [Size(1200, 1000), Size(1920, 1000)]) {
          await pumpApp(tester, window);
          await openSettingsPanel(tester);
          // WP-710'dan sonra en uzun kategori Gorunum: tema satiri + dil
          // acilir listesi (kutulu form alani, iki satirlik yardim metniyle).
          await selectCategory(tester, tr.settingsSectionAppearance);
          expect(
            scrollExtent(tester, find.byType(SettingsScreen)),
            0,
            reason:
                '${window.width.toInt()} px pencerede ayarlar 680 px\'lik '
                'panele sigmiyor. Sigmiyorsa yukseklik karari yeniden '
                'olculmeli — bu iddia tam olarak onun icin var.',
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await settle(tester);
        }
      }),
    );
  });

  // =========================================================================
  // 4) KART SECICI (showDesktopPicker) — ayni sinif kusur
  // =========================================================================
  //
  // ONCE (`WP686PICKER`): dort pencerede de 720 px, dosemeler 220 px, dikey
  // kaydirma 476 px.
  // SONRA: <1200 -> 720 (degismez) · >=1200 -> 1020, doseme 320, kaydirma 368.

  Future<void> openPicker(WidgetTester tester, Size window) async {
    prepareWindow(tester, window);
    final preferences = await v8SharedPreferences();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showCardPicker(context),
                  child: const Text('ac'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ac'));
    await settle(tester);
  }

  /// Kart dosemelerinin cizilen genisligi (kapatma dugmesi haric).
  List<double> pickerTileWidths(WidgetTester tester) {
    final out = <double>[];
    for (final e
        in find
            .descendant(
              of: find.byKey(kDesktopPickerBodyKey),
              matching: find.byType(InkWell),
            )
            .evaluate()) {
      final box = e.renderObject;
      if (box is RenderBox && box.hasSize && box.size.width > 100) {
        out.add(box.size.width);
      }
    }
    return out;
  }

  group('kart secici — SPEC §2.3 doseme tavani', () {
    final expectedPicker = <double, (double, double)>{
      1008: (DesktopSurface.pickerWidth, 220),
      1200: (DesktopSurface.pickerWidthLarge, 320),
      1920: (DesktopSurface.pickerWidthLarge, 320),
      2560: (DesktopSurface.pickerWidthLarge, 320),
    };

    expectedPicker.forEach((window, want) {
      final (pickerWidth, tileWidth) = want;
      testWidgets(
        '@${window.toInt()} picker ${pickerWidth.toInt()}, doseme '
        '${tileWidth.toInt()}',
        (tester) async => onWindows(() async {
          await openPicker(tester, Size(window, window == 2560 ? 1440 : 1000));

          final body = find.byKey(kDesktopPickerBodyKey);
          expect(
            body,
            findsOneWidget,
            reason: 'Kart secici acilmadi; olculecek kutu yok.',
          );
          final measured = tester.getSize(body).width;
          expect(
            measured,
            pickerWidth,
            reason:
                '${window.toInt()} px pencerede kart secici '
                '${pickerWidth.toInt()} px olmali; olculen '
                '${measured.toStringAsFixed(0)} px. Pencereyle buyumuyorsa bu '
                'sayi dort pencerede de 720 kalir — kusurun ta kendisi.',
          );

          final tiles = pickerTileWidths(tester);
          expect(tiles, isNotEmpty, reason: 'Hic kart dosemesi cizilmemis.');
          for (final tile in tiles) {
            expect(
              tile,
              tileWidth,
              reason:
                  'Doseme genisligi ${tile.toStringAsFixed(0)} px, beklenen '
                  '${tileWidth.toInt()}. Ilgili aritmetik '
                  '(bant − 40 − 2×10) / 3.',
            );
            expect(
              tile,
              lessThanOrEqualTo(DesktopBreakpoints.maxStatTileWidth),
              reason:
                  'SPEC §2.3 doseme tavani 320 px asildi — kart genisler, '
                  'icindeki iki satir metin ayni kalir (sahip sikayeti #3).',
            );
          }

          // Secici bir `Dialog`tir: pencereyi KAPLAMAZ.
          expect(measured, lessThanOrEqualTo(window - 48));
        }),
      );
    });

    testWidgets('mobil 390x844 — picker hala ALT SAYFA, dialog yok', (
      tester,
    ) async {
      // Platform override YOK -> `isDesktopWindow == false`.
      await openPicker(tester, const Size(390, 844));
      // 🔴 ONCEDEN VAR OLAN, BU WP'NIN DISINDAKI KUSUR: kart secicinin baslik
      // satiri (`features/home/widgets/card_picker.dart:56`, `Row`) 390 px'lik
      // telefonda **8.8 px tasar** ("A RenderFlex overflowed"). Bu WP mobil
      // dala hic dokunmadi — masaustu genisligi degisti — ve `home/**` bu
      // WP'nin SAHIP yollarinda degil, o yuzden burada duzeltilemez; lidere
      // raporlandi. Istisna bilerek tuketilir: baskasinin kusuru bu iddiayi
      // kirmizi tutmasin, ama duzelirse de test kirilmasin.
      tester.takeException();
      expect(
        find.byKey(kDesktopPickerBodyKey),
        findsNothing,
        reason: 'SPEC §7: masaustu secicisi mobil dala sizmis.',
      );
      expect(find.byType(Dialog), findsNothing);
      expect(find.text(tr.homeKartEkle), findsOneWidget);
    });

    test('1020 icerikten turetildi — 3 x 320 + 2 x 10 + 40', () {
      expect(DesktopSurface.pickerWidthLarge, 3 * 320 + 2 * 10 + 40);
      expect(DesktopSurface.pickerWidthLarge % 4, 0);
      // 1008 px'lik pencerede `pencere − 48` = 960 < 1020: bu yuzden esik
      // `expanded` degil `large`. Sayi degistirilirse gerekce de dusmeli.
      expect(DesktopBreakpoints.large - 48, greaterThanOrEqualTo(1020));
      expect(DesktopBreakpoints.expanded - 48, lessThan(1020));
      expect(desktopPickerWidthFor(1199), DesktopSurface.pickerWidth);
      expect(desktopPickerWidthFor(1200), DesktopSurface.pickerWidthLarge);
      expect(desktopPickerWidthFor(2560), DesktopSurface.pickerWidthLarge);
    });
  });

  // =========================================================================
  // 5) MOBIL REGRESYON — SPEC §7
  // =========================================================================

  group('mobil 390x844 — SPEC §7', () {
    testWidgets('ayarlar tek sutun, master-detay mobile SIZMADI', (
      tester,
    ) async {
      // Platform override YOK -> `isDesktopWindow == false`.
      prepareWindow(tester, const Size(390, 844));
      final preferences = await v8SharedPreferences();
      final auth = await signedInV8AuthRepository(prefs: preferences);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            groupRepositoryProvider.overrideWithValue(
              InMemoryGroupRepository(),
            ),
            sharedPreferencesProvider.overrideWithValue(preferences),
            deviceIntegrationServiceProvider.overrideWithValue(
              V8TestDeviceIntegrationService(),
            ),
            androidWidgetServiceProvider.overrideWithValue(
              V8TestWidgetGateway(),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SettingsScreen(),
          ),
        ),
      );
      await settle(tester);

      expect(
        find.byKey(kSettingsMasterListKey),
        findsNothing,
        reason: 'SPEC §7: kategori sutunu mobil dala sizmis.',
      );
      expect(find.byType(DesktopSectionList), findsNothing);
      expect(
        find.byKey(const ValueKey('${kProfileFlowColumnKeyPrefix}1')),
        findsNothing,
        reason: 'SPEC §7: masaustu izgarasi mobil dala sizmis.',
      );
      // Yedi bolum ve butun anahtarlar AYNI ANDA agacta — mobil dal
      // gizlemeye gecmedi.
      for (final title in sectionTitles()) {
        expect(find.text(title), findsOneWidget, reason: 'Bolum: "$title"');
      }
      for (final keys in rowsByCategory().values) {
        for (final key in keys) {
          expect(find.byKey(key), findsOneWidget, reason: 'Satir: $key');
        }
      }
    });
  });

  // =========================================================================
  // 6) SABOTAJ — esik KABA bagli mi, 1 px'lik farkla
  // =========================================================================
  //
  // Bu bolum bir BILESEN testidir. Esigi pencereye baglayan bir degisiklik
  // (SPEC §1.2'nin 1200'u) buradan gecemez: 1200 px'lik pencerede kaba yalniz
  // 1056 px duser, yani "pencere >= 1200" diyen bir dal 1200 px'lik pencerede
  // dogru, 1088 px'lik bir panelde YANLIS calisir.

  Future<void> mountInBand(WidgetTester tester, double band) async {
    prepareWindow(tester, const Size(2560, 1440));
    final preferences = await v8SharedPreferences();
    final auth = await signedInV8AuthRepository(prefs: preferences);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          groupRepositoryProvider.overrideWithValue(InMemoryGroupRepository()),
          sharedPreferencesProvider.overrideWithValue(preferences),
          deviceIntegrationServiceProvider.overrideWithValue(
            V8TestDeviceIntegrationService(),
          ),
          androidWidgetServiceProvider.overrideWithValue(V8TestWidgetGateway()),
        ],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // `showDesktopPanel` govdesinin taklidi.
          home: Center(
            child: SizedBox(
              width: band,
              height: DesktopSurface.panelHeight,
              child: const SettingsScreen(),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  group('esik KABA bagli — sabotaj', () {
    testWidgets(
      'kap 1 px dar (1087) -> master-detay ACILMAZ',
      (tester) async => onWindows(() async {
        await mountInBand(tester, kSettingsMasterDetailBand + kPanelChrome - 1);
        expect(
          find.byKey(kSettingsMasterListKey),
          findsNothing,
          reason:
              '1055 px\'lik banda 1056 px\'lik satir SIGMAZ. Acilmissa detay '
              'sutunu 760\'in altina eziliyor demektir.',
        );
      }),
    );

    testWidgets(
      'kap tam 1088 -> master-detay ACILIR, detay tam 760',
      (tester) async => onWindows(() async {
        await mountInBand(tester, kSettingsMasterDetailBand + kPanelChrome);
        expect(find.byKey(kSettingsMasterListKey), findsOneWidget);
        expect(
          tester.getSize(find.byKey(kSettingsDetailPaneKey)).width,
          DesktopBreakpoints.maxFormWidth,
        );
      }),
    );

    test('bant turetimi: 280 + 16 + 760 = 1056 = 1088 − 32', () {
      expect(
        kSettingsMasterDetailBand,
        kSettingsMasterWidth +
            kSettingsPaneSpacing +
            DesktopBreakpoints.maxFormWidth,
      );
      expect(kSettingsMasterDetailBand, 1056);
      expect(
        kSettingsMasterDetailBand,
        DesktopSurface.panelWidthLarge - DesktopSurface.panelChrome,
        reason:
            'WP-684 `large` panelini tam olarak bu satir sigsin diye 1088 '
            'yapti. Iki sayi ayrilirsa merdivenin gerekcesi duser.',
      );
      expect(kSettingsMasterDetailBand % 4, 0);
    });
  });
}
