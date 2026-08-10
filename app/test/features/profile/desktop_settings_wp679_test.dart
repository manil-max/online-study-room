// WP-679 — AYARLAR VE ALT EKRANLARIN MASAUSTU DUZEN KAPISI.
//
// Sahip v64 Windows surumunu reddetti: "dikey mobil uygulama icin tasarlanan
// arayuzler yatay pc ekraninda cok kotu duruyor". WP-674 profili/basarimlari
// duzeltti; Profil'in ALTINDAKI ekranlar hic ellenmemisti.
//
// ================== DUZELTME ONCESI OLCUM (2026-08-10) =====================
//
// Butun sayilar bu dosyanin ilk halinde (olcum turu) `WP679 | ...` satirlariyla
// koşularak alindi; hicbiri kaynak dosyadan okunmadi, hepsi BOYANAN kutudan.
//
// A) GERCEK KABUK — Profil -> "Ayarlar" (`showDesktopPanel`, 920 px `Dialog`):
//      @1920 icerik 772 px (516..1288)   @2560 icerik 772 px (836..1608)
//    Yani panel pencereyle BUYUMEZ; ayni ekran iki pencerede de ayni.
//    Bu, WP'nin en onemli bulgusu: SPEC §1.2'nin PENCERE merdiveni bu ekran
//    ailesinde hicbir zaman tetiklenmez.
//
// B) TAM PENCERE ROTASI (sayac kartindan acilanlar + her ekranin ust siniri):
//    ekran            @1920 icerik / en genis kart   @2560 icerik / en genis kart
//    KAYITLAR         1868 px / —                    2508 px / —
//    DERSLER          1868 px / —                    2508 px / —
//    HESABIM          1848 px / kart 1888 px         2488 px / kart 2528 px
//    YASAL            1736 px / kart 1888 px         1823 px / kart 2528 px
//    SAYAC-GUNLUGU    1193 px / —                    1513 px / —
//    DISA-AKTAR       1101 px / —                    1421 px / —
//    GERI-BILDIRIM    1872 px, "Iptal"->"Gonder" satiri 1028 px
//                                                    2512 px, satir 1348 px
//    AYARLAR           760 px'lik tek sutun (govde)   ayni
//    HAKKINDA          760 px'lik tek sutun (govde)   ayni
//
// ============================= NEYI KORUR ==================================
//
// 1. Her iddia CIZILEN kutudan okunur (`getRect` / glif kutusu). Kaynakta
//    `maxWidth: 760` yazmasi kanit degildir (depo dersi: 0126 regresyonu tum
//    kapilar boyunca yesil kaldi).
// 2. Esikler `docs/design/DESKTOP-UI-SPEC.md` §2.3'ten gelir: prose 600,
//    form/ayar satiri 760, etiket-deger sert tavan 600.
// 3. Ayarlar panelinin GERCEKTEN cok sutuna aktigi, uygulamanin kendi
//    kabugu uzerinden olculur — izole monte edilmis bir widget uzerinden degil.
// 4. Mobil (390x844) tek sutun kalir.
//
// ============================ NEYI KORUMAZ =================================
//
// - Guzellik, renk, kontrast, golden. Olculen sey MESAFE ve TAVAN.
// - Katlanin alti: yalniz ilk karede boyanan icerik.
// - Tema olusturucu studyosu (`theme_builder/`): 1040 px'lik sabit studio
//   panelinde zaten yan yana iki bolme cizer; bu kapinin disinda.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/desktop/desktop_layout.dart';
import 'package:online_study_room/core/device_integrations/samsung_modes_service.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';
import 'package:online_study_room/features/profile/about_screen.dart';
import 'package:online_study_room/features/profile/account_settings_screen.dart';
import 'package:online_study_room/features/profile/data_export_screen.dart';
import 'package:online_study_room/features/profile/feedback_screen.dart';
import 'package:online_study_room/features/profile/legal_center_screen.dart';
import 'package:online_study_room/features/profile/session_history_screen.dart';
import 'package:online_study_room/features/profile/settings_screen.dart';
import 'package:online_study_room/features/desktop/desktop_page_scaffold.dart';
import 'package:online_study_room/features/profile/subjects_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';
import 'package:online_study_room/main.dart';

import '../../support/v8_test_setup.dart';

/// SPEC §2.3 "Form / ayar satiri" (= `DesktopSurface.readingWidth`, 760).
const double kFormCap = DesktopBreakpoints.maxFormWidth;

/// SPEC §2.3 "Duz metin / prose" — 80 karakter x 7.5 px (WCAG 2.1 SC 1.4.8).
const double kProseCap = DesktopBreakpoints.maxProseWidth;

/// SPEC KURAL 2.2 sert tavani.
const double kLabelValueCap = DesktopBreakpoints.maxLabelValueWidth;

void main() {
  final tr = AppLocalizationsTr();

  /// 🔴 `debugDefaultTargetPlatformOverride` test GOVDESI BITMEDEN geri
  /// alinmali; `tearDown` cok gec kalir ve "foundation debug variable was
  /// changed by the test" hatasi asil iddianin yerine gecer.
  Future<void> onWindows(Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

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

  /// Bir paragrafin EKRANDA boyanan glif kutusu.
  ///
  /// 🔴 Kutusu degil GLIFI: `Expanded(child: Text(...))` icindeki
  /// `RenderParagraph`in kutusu tum satiri kaplar, boyanan harfler solda
  /// kalir. `getRect` kullanmak etiket-deger mesafesini SIFIR gosterirdi.
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

  /// [root] alt agacindaki, AppBar'in ALTINDA ve FAB'in DISINDA kalan glifler.
  ///
  /// Ikisi de bilerek disarida:
  ///  · **AppBar** basligi daima sol kenarda durur (Material sozlesmesi);
  ///    govde basa yasli oldugunda aradaki mesafe "icerik yayiliyor" gibi
  ///    okunurdu.
  ///  · 🔴 **FAB** ekranin SAG ALT kosesine yapisiktir. Bu kapinin ilk kosumu
  ///    tam da bu yuzden YALANCI kirmizi dustu: `SessionHistoryScreen` iki
  ///    pane'i dogru cizdigi halde "Manuel ekle" etiketi 1904 px'te durdugu
  ///    icin olculen aralik 1850 px cikti. FAB bir icerik sutunu degil, yuzen
  ///    bir eylemdir; genislik sozlesmesinin disindadir.
  List<(String, Rect)> bodyInk(WidgetTester tester, Finder root) {
    final ro = root.evaluate().first.renderObject!;
    var appBarBottom = 0.0;
    for (final e
        in find
            .descendant(of: root, matching: find.byType(AppBar))
            .evaluate()) {
      final box = e.renderObject;
      if (box is RenderBox && box.hasSize) {
        final r = globalRect(box);
        if (r.bottom > appBarBottom) appBarBottom = r.bottom;
      }
    }
    final floating = <Rect>[
      for (final e
          in find
              .descendant(of: root, matching: find.byType(FloatingActionButton))
              .evaluate())
        if (e.renderObject is RenderBox &&
            (e.renderObject! as RenderBox).hasSize)
          globalRect(e.renderObject! as RenderBox),
    ];
    final out = <(String, Rect)>[];
    walk(ro, (node) {
      if (node is! RenderParagraph) return;
      final rect = ink(node);
      if (rect == null || rect.top < appBarBottom) return;
      if (floating.any((f) => f.overlaps(rect))) return;
      out.add((node.text.toPlainText(), rect));
    });
    return out;
  }

  /// Cizilen [ProfileFlowColumns] sutunlari (SPEC §3 A2), soldan saga.
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

  ({double width, String widest}) bodySpan(WidgetTester tester, Finder root) {
    Rect? union;
    var widest = '';
    for (final (text, rect) in bodyInk(tester, root)) {
      if (union == null) {
        union = rect;
        widest = text;
      } else {
        if (rect.left < union.left || rect.right > union.right) widest = text;
        union = union.expandToInclude(rect);
      }
    }
    return (width: union?.width ?? 0, widest: widest);
  }

  List<Rect> cardRects(WidgetTester tester, Finder root) => [
    for (final e
        in find
            .descendant(
              of: root,
              matching: find.byType(Card, skipOffstage: true),
            )
            .evaluate())
      if (e.renderObject is RenderBox && (e.renderObject! as RenderBox).hasSize)
        globalRect(e.renderObject! as RenderBox),
  ];

  // =========================================================================
  // 1) GERCEK KABUK — Profil -> Ayarlar paneli
  // =========================================================================

  Future<void> pumpApp(WidgetTester tester, Size window) async {
    tester.binding.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = window;
    addTearDown(tester.view.reset);

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
    await tester.tap(find.text(tr.profileProfil).first);
    await settle(tester);
  }

  group('ayarlar paneli — gercek kabuk', () {
    for (final window in const [Size(1920, 1080), Size(2560, 1440)]) {
      final w = window.width.toInt();

      testWidgets(
        '@$w bolumler YAN YANA akiyor, her sutun <= 760 px',
        (tester) async => onWindows(() async {
          await pumpApp(tester, window);
          await tester.tap(find.text(tr.profileAyarlar).last);
          await settle(tester);

          final dialog = find.byType(Dialog);
          expect(
            dialog,
            findsOneWidget,
            reason: 'Ayarlar paneli acilmadi; hicbir sey olculemez.',
          );

          // ÖNCE: tek sutun, 772 px icerik (@1920 ve @2560 AYNI).
          //
          // 🔴 WP-686 bu bandi DEGISTIRDI: panel artik 1472 px acilir ve
          // ayarlar SPEC §5'in soyledigi **master-detay**a gecer (280 kategori
          // + 16 + detay). Olculen sutunlar artik ayarlar BOLUMLERI degil,
          // secili kategorinin KARTLARIDIR (detay 1144 px -> SPEC §3 A2 akisi,
          // 2 x 560). Iddia gevsemedi — hem kategori sutunu hem cok sutunlu
          // detay aranir; tek sutunluk mobil kaydirma yine KIRMIZI duser.
          expect(
            tester.getRect(find.byKey(kSettingsMasterListKey)).width,
            kSettingsMasterWidth,
            reason:
                'SPEC §3 A1: 1440 px\'lik panel bandinda kategori sutunu 280 '
                'px olmali.',
          );
          final columns = flowColumns(tester);
          expect(
            columns.length,
            greaterThanOrEqualTo(2),
            reason:
                'SPEC §3 A2: detay pane\'inin kartlari cok sutuna akmali. '
                'Cizilen sutun sayisi ${columns.length} — ekran hala tek '
                'sutunluk mobil kaydirma.',
          );
          expect(
            columns[1].left,
            greaterThanOrEqualTo(columns[0].right - 1),
            reason:
                'Iki sutun UST USTE cizilmis: '
                '${columns[0].left.toStringAsFixed(0)}..'
                '${columns[0].right.toStringAsFixed(0)} ve '
                '${columns[1].left.toStringAsFixed(0)}..'
                '${columns[1].right.toStringAsFixed(0)}',
          );
          for (final column in columns) {
            expect(
              column.width,
              lessThanOrEqualTo(kFormCap),
              reason:
                  'SPEC §2.3: bir ayar sutunu 760 px\'i asamaz; olculen '
                  '${column.width.toStringAsFixed(0)} px.',
            );
          }

          // ISLEV KAYBI YOK: alti bolumun basligi da, en alttaki SSS satiri da
          // hala CIZILIYOR. Sutuna akitmak hicbir satiri gizlemedi.
          for (final title in [
            tr.settingsSectionAppearance,
            tr.settingsSectionNotifications,
            tr.settingsSectionAccount,
            tr.settingsSectionStudyPreferences,
            tr.settingsSectionPrivacySecurity,
            tr.settingsSectionAboutLegal,
            tr.settingsSectionHelp,
          ]) {
            expect(
              find.descendant(of: dialog, matching: find.text(title)),
              findsWidgets,
              reason: 'Ayarlar bolumu kayboldu: "$title"',
            );
          }
          // 🔴 WP-686: master-detay ayni anda TEK kategori cizer, yani
          // "anahtar agacta mi" artik YANLIS olcum. Dogrusu: her kategori
          // secilebiliyor mu ve satiri o zaman geliyor mu. Yedi kategorinin
          // hepsi tek tek gezilir — eski dort anahtardan DAHA GENIS bir kapi.
          for (final entry in <String, List<Key>>{
            tr.settingsSectionStudyPreferences: const [
              Key('settings-daily-goal'),
              Key('settings-exam-date'),
            ],
            tr.settingsSectionPrivacySecurity: const [
              Key('settings-muted-nudges'),
            ],
            tr.settingsSectionAboutLegal: const [
              Key('settings-about-updates'),
              Key('settings-feedback'),
            ],
            tr.settingsSectionHelp: const [Key('settings-faq')],
          }.entries) {
            await selectCategory(tester, entry.key);
            for (final key in entry.value) {
              expect(
                find.byKey(key),
                findsOneWidget,
                reason:
                    'Ayar satiri "${entry.key}" kategorisinde bulunamadi: '
                    '$key. Master-detay bir satiri ULASILAMAZ yaptiysa islev '
                    'kaybi vardir.',
              );
            }
          }
        }),
      );
    }
  });

  // =========================================================================
  // 2) TAM PENCERE ROTASI — her ekranin SPEC tavani
  // =========================================================================

  /// SubjectsScreen bos listede tek satirlik bir bos-durum metni cizer ve
  /// hicbir sey olculemez; izgara icin ders tohumlanir.
  const seededSubjects = <Subject>[
    Subject(id: 'a', userId: 'me', name: 'Matematik', color: 'chart-1'),
    Subject(id: 'b', userId: 'me', name: 'Fizik', color: 'chart-2'),
    Subject(id: 'c', userId: 'me', name: 'Kimya', color: 'chart-3'),
    Subject(id: 'd', userId: 'me', name: 'Biyoloji', color: 'chart-4'),
  ];

  Future<Widget> wrap(
    Widget child, {
    List<StudySession> sessions = const [],
    List<Subject> subjects = const [],
  }) async {
    final preferences = await v8SharedPreferences();
    final auth = await signedInV8AuthRepository(prefs: preferences);
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        groupRepositoryProvider.overrideWithValue(InMemoryGroupRepository()),
        sharedPreferencesProvider.overrideWithValue(preferences),
        deviceIntegrationServiceProvider.overrideWithValue(
          V8TestDeviceIntegrationService(),
        ),
        androidWidgetServiceProvider.overrideWithValue(V8TestWidgetGateway()),
        if (sessions.isNotEmpty)
          userSessionsProvider.overrideWith((ref) => Stream.value(sessions)),
        if (subjects.isNotEmpty)
          userSubjectsProvider.overrideWith((ref) => Stream.value(subjects)),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }

  Future<void> mount(
    WidgetTester tester,
    Size window,
    Widget child, {
    List<StudySession> sessions = const [],
    List<Subject> subjects = const [],
  }) async {
    tester.binding.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = window;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      await wrap(child, sessions: sessions, subjects: subjects),
    );
    await settle(tester);
  }

  /// Bu ekranlarin hepsi masaustunde ya tam pencere rotasiyla (sayac karti,
  /// duyurular) ya da 920 px'lik panel icinde acilir. Tavan ikisinde de ayni:
  /// govde SPEC §2.3'un form sutununu asamaz.
  final formScreens = <String, Widget Function()>{
    'HESABIM': () => const AccountSettingsScreen(),
    'HAKKINDA': () => const AboutScreen(),
    'YASAL': () => const LegalCenterScreen(),
    'DISA-AKTAR': () => const DataExportScreen(),
  };

  /// SPEC §3 **A2**: bu ikisi bagimsiz bloklar tasir, tek bir form sutunu
  /// degildir. Govde tavani izgara toplami (1440), SUTUN tavani 760.
  ///
  /// 🔴 WP-686 notu: AYARLAR tam pencere yolunda artik **A1 + A2**dir
  /// (kap 1056 px'i astigi icin master-detay acilir, detay kartlari da A2
  /// akisina duser). Bu grubun olctugu sey degismedi: govde 1440'i asmasin,
  /// cizilen sutunlar 760'i asmasin, ust uste binmesin.
  final flowScreens = <String, Widget Function()>{
    'AYARLAR': () => const SettingsScreen(),
    'DERSLER': () => const SubjectsScreen(),
  };

  group('tam pencere — SPEC §2.3 form tavani', () {
    for (final window in const [Size(1920, 1080), Size(2560, 1440)]) {
      final w = window.width.toInt();
      for (final entry in formScreens.entries) {
        testWidgets(
          '@$w ${entry.key} govdesi <= 760 px',
          (tester) async => onWindows(() async {
            await mount(tester, window, entry.value());
            final root = find.byType(Scaffold).first;

            final span = bodySpan(tester, root);
            expect(
              span.width,
              lessThanOrEqualTo(kFormCap),
              reason:
                  'SPEC §2.3 form/ayar sutunu ${kFormCap.toInt()} px. '
                  '${entry.key} govdesi ${span.width.toStringAsFixed(0)} px '
                  'yayiliyor (en distaki metin: "${span.widest}"). Ekran '
                  'icerigine gore degil PENCEREYE gore boyutlanmis.',
            );

            final cards = cardRects(tester, root)
              ..sort((a, b) => b.width.compareTo(a.width));
            if (cards.isNotEmpty) {
              expect(
                cards.first.width,
                lessThanOrEqualTo(kFormCap),
                reason:
                    'SPEC §2.3: bir kart yuzeyi 760 px\'i asamaz. '
                    '${entry.key} en genis kart '
                    '${cards.first.width.toStringAsFixed(0)} px.',
              );
            }
          }),
        );
      }
    }
  });

  group('tam pencere — SPEC §3 A2 izgara', () {
    for (final window in const [Size(1920, 1080), Size(2560, 1440)]) {
      final w = window.width.toInt();
      for (final entry in flowScreens.entries) {
        testWidgets(
          '@$w ${entry.key} cok sutuna akiyor, govde <= 1440 / sutun <= 760',
          (tester) async => onWindows(() async {
            await mount(
              tester,
              window,
              entry.value(),
              subjects: seededSubjects,
            );
            final root = find.byType(Scaffold).first;

            final span = bodySpan(tester, root);
            expect(
              span.width,
              lessThanOrEqualTo(DesktopBreakpoints.maxContentWidth),
              reason:
                  'SPEC §2.3 izgara toplami 1440 px. ${entry.key} govdesi '
                  '${span.width.toStringAsFixed(0)} px (en distaki metin: '
                  '"${span.widest}").',
            );

            final columns = flowColumns(tester);
            expect(
              columns.length,
              greaterThanOrEqualTo(2),
              reason:
                  'SPEC §3 A2: $w px pencerede ${entry.key} bloklari cok '
                  'sutuna akmali; cizilen sutun sayisi ${columns.length}.',
            );
            for (var i = 1; i < columns.length; i++) {
              expect(
                columns[i].left,
                greaterThanOrEqualTo(columns[i - 1].right - 1),
                reason: '${entry.key}: iki sutun ust uste cizilmis.',
              );
            }
            for (final column in columns) {
              expect(
                column.width,
                lessThanOrEqualTo(kFormCap),
                reason:
                    'SPEC 2.3: bir sutun 760 px sinirini asamaz; olculen '
                    '${column.width.toStringAsFixed(0)} px.',
              );
            }
          }),
        );
      }
    }
  });

  group('yasal belge — SPEC §3 A3 prose', () {
    for (final window in const [Size(1920, 1080), Size(2560, 1440)]) {
      final w = window.width.toInt();
      testWidgets(
        '@$w gizlilik metni <= 600 px (WCAG 1.4.8)',
        (tester) async => onWindows(() async {
          await mount(tester, window, const LegalCenterScreen());
          await tester.tap(find.text(tr.legalPrivacyPolicy).first);
          await settle(tester);

          // ÖNCE: tavansiz `SelectableText`; @1920 satir 1888 px = 251 karakter.
          //
          // 🔴 `SelectableText` bir `RenderEditable`dir, `RenderParagraph`
          // DEGILDIR: glif tarayicisi onu hic gormez (kapinin ilk kosumunda
          // 0 px olcup yalanci kirmizi dustu). Boyanan kutusu dogrudan okunur.
          final text = find.byType(SelectableText);
          expect(
            text,
            findsOneWidget,
            reason: 'yasal belge cizilmemis; olculecek metin yok',
          );
          final width = tester.getSize(text).width;
          expect(
            width,
            lessThanOrEqualTo(kProseCap),
            reason:
                'SPEC §2.3 + WCAG 2.1 SC 1.4.8: duz metin sutunu 600 px '
                '(80 karakter). Olculen ${width.toStringAsFixed(0)} px = '
                '${(width / 7.5).round()} karakter.',
          );
        }),
      );
    }
  });

  group('geri bildirim — SPEC §2.3 form sutunu', () {
    for (final window in const [Size(1920, 1080), Size(2560, 1440)]) {
      final w = window.width.toInt();
      testWidgets(
        '@$w "Iptal" ile "Gonder" arasi <= 760 px',
        (tester) async => onWindows(() async {
          await mount(tester, window, const FeedbackScreen());

          // ÖNCE: @1920 1028 px, @2560 1348 px — iki `Expanded` dugme pencere
          // buyudukce birbirinden uzaklasiyordu.
          final cancel = tester.getRect(
            find.byKey(const Key('feedback-cancel')),
          );
          final submit = tester.getRect(
            find.byKey(const Key('feedback-submit')),
          );
          final span = submit.right - cancel.left;
          expect(
            span,
            lessThanOrEqualTo(kFormCap),
            reason:
                'SPEC §2.3 form sutunu ${kFormCap.toInt()} px. Olculen '
                '${span.toStringAsFixed(0)} px — serit pencereyle buyuyor.',
          );

          // ISLEV KAYBI YOK: form alanlari ve ek dosya dugmesi yerinde.
          expect(
            find.byKey(const Key('feedback-subject-field')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('feedback-message-field')),
            findsOneWidget,
          );
        }),
      );
    }
  });

  // =========================================================================
  // 3) CALISMA KAYITLARI — SPEC §3 A1 master-detay
  // =========================================================================

  List<StudySession> seedSessions() {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    StudySession at(DateTime day, int hour, int seconds, String id) {
      final start = DateTime.utc(day.year, day.month, day.day, hour);
      return StudySession(
        id: id,
        userId: 'me',
        start: start,
        end: start.add(Duration(seconds: seconds)),
        durationSeconds: seconds,
        source: StudySource.live,
      );
    }

    return [
      at(today, 9, 3600, 's1'),
      at(today, 14, 1800, 's2'),
      at(yesterday, 10, 2700, 's3'),
    ];
  }

  group('calisma kayitlari — SPEC §3 A1', () {
    for (final window in const [Size(1920, 1080), Size(2560, 1440)]) {
      final w = window.width.toInt();
      testWidgets(
        '@$w gun listesi ve oturum detayi YAN YANA, master 320 px',
        (tester) async => onWindows(() async {
          await mount(
            tester,
            window,
            const SessionHistoryScreen(),
            sessions: seedSessions(),
          );

          // ÖNCE: tek sutun; satirlar @1920 1868 px, @2560 2508 px.
          final root = find.byType(Scaffold).first;
          final span = bodySpan(tester, root);
          expect(
            span.width,
            lessThanOrEqualTo(
              kSessionMasterWidth + kSessionPaneSpacing + kFormCap,
            ),
            reason:
                'SPEC §3 A1: 320 (gun listesi) + 16 + 760 (detay) = 1096 px. '
                'Olculen ${span.width.toStringAsFixed(0)} px.',
          );

          final master = tester.getRect(find.byType(DesktopSectionList));
          expect(
            master.width,
            kSessionMasterWidth,
            reason:
                'SPEC §3 A1 tablosu: session history master sutunu 320 px; '
                'olculen ${master.width.toStringAsFixed(0)} px.',
          );

          // Detay pane'i master'in SAGINDA: "Bugun" basligi iki kez cizilir
          // (master satiri + detay basligi); saga dusen olan detaydir.
          final bugun = find.text(tr.profileBugun);
          expect(bugun, findsWidgets);
          final rects = [
            for (final e in bugun.evaluate())
              globalRect(e.renderObject! as RenderBox),
          ]..sort((a, b) => a.left.compareTo(b.left));
          expect(
            rects.last.left,
            greaterThanOrEqualTo(master.right),
            reason:
                'Detay pane\'i master sutununun sagina dusmemis: master '
                '${master.left.toStringAsFixed(0)}..'
                '${master.right.toStringAsFixed(0)}, detay basligi '
                '${rects.last.left.toStringAsFixed(0)} px.',
          );

          // ISLEV KAYBI YOK: manuel ekleme dugmesi ve oturum satirlarinin
          // duzenle/sil menusu duruyor.
          expect(
            find.widgetWithText(FloatingActionButton, tr.profileManuelEkle),
            findsOneWidget,
            reason: 'Manuel sure ekleme dugmesi kayboldu.',
          );
          expect(
            find.byType(PopupMenuButton<String>),
            findsWidgets,
            reason: 'Oturum satirindaki duzenle/sil menusu kayboldu.',
          );
        }),
      );
    }
  });

  // =========================================================================
  // 4) MOBIL REGRESYON — 390x844
  // =========================================================================

  group('mobil 390x844 — SPEC §7', () {
    testWidgets('ayarlar TEK sutun kalir, hicbir bolum yana kaymaz', (
      tester,
    ) async {
      // Platform override YOK → `isDesktopWindow == false`.
      await mount(tester, const Size(390, 844), const SettingsScreen());

      expect(
        find.byKey(const ValueKey('${kProfileFlowColumnKeyPrefix}1')),
        findsNothing,
        reason:
            'SPEC §7: masaustu izgarasi mobil dala sizmis — ikinci sutun '
            'mobilde de cizilmis.',
      );
      final cards = cardRects(tester, find.byType(Scaffold).first);
      expect(cards.length, greaterThanOrEqualTo(2));
      for (final card in cards.skip(1)) {
        expect(
          (card.left - cards.first.left).abs(),
          lessThan(1),
          reason:
              'SPEC §7: mobilde butun ayar kartlari ayni sol kenardan '
              'baslar. Iki kart farkli `dx`\'te cizildi.',
        );
      }
    });

    testWidgets('calisma kayitlari mobilde katlanabilir gun listesi kalir', (
      tester,
    ) async {
      await mount(
        tester,
        const Size(390, 844),
        const SessionHistoryScreen(),
        sessions: seedSessions(),
      );
      expect(
        find.byType(DesktopSectionList),
        findsNothing,
        reason:
            'SPEC §7: master-detay mobil dala sizmis. Mobilde bugunku '
            'katlanabilir gun listesi kalmali.',
      );
      expect(
        find.byType(ExpansionTile),
        findsWidgets,
        reason: 'Gecmis gunun katlanabilir satiri kayboldu.',
      );
    });

    testWidgets('yasal metin mobilde tavansiz (tam genislik) kalir', (
      tester,
    ) async {
      await mount(tester, const Size(390, 844), const LegalCenterScreen());
      await tester.tap(find.text(tr.legalPrivacyPolicy).first);
      await settle(tester);
      final width = tester.getSize(find.byType(SelectableText)).width;
      expect(
        width,
        greaterThan(300),
        reason:
            'SPEC §7: 600 px\'lik masaustu prose tavani mobile sizmamali; '
            'mobilde metin ekran genisligini kullanir.',
      );
    });
  });
}
