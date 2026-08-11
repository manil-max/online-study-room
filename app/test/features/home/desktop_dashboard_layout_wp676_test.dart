// WP-676 — ANA PANONUN MASAUSTU DUZENI.
//
// Sahip v64 Windows surumunu reddetti: "dikey mobil uygulama icin tasarlanan
// arayuzler yatay pc ekraninda cok kotu duruyor". Ana panoda bunun OLCULEN
// hali (WP-671 kapisi, 1920 ve 2560 px pencere, cizilen glif/kart kutulari):
//
//   icerik araligi     1564 px (1920) / 1884 px (2560)   -- SPEC §2.3 tavani 1440
//   en genis kart      1440 px, icindeki en genis metin 717 px
//   etiket-deger satiri 1408 px ("Bugun ozeti" -> "0sn", arasi 1182 px bosluk)
//   masaustu yuzeyi    HICBIRI monte degil (SPEC §6)
//
// Bu dosya duzeltmeyi KILITLER. Her iddia CIZILEN kutudan okunur
// (`tester.getSize` / `getTopLeft`); hicbiri kaynakta sabit aramaz. Sebep
// depoda kayitli: "dogruluk kaynagi dogruyken ekran bos olabilir".
//
// NEYI KORUMAZ: guzellik, katlanin alti, renk/kontrast, veri dolu ekranlar.
// Golden YOK (bilerek): piksel farkini sebebe baglamaz.
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
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';
import 'package:online_study_room/features/desktop/desktop_page_scaffold.dart';
import 'package:online_study_room/features/home/dashboard_card.dart';
import 'package:online_study_room/features/home/dashboard_providers.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';
import 'package:online_study_room/main.dart';

import '../../support/v8_test_setup.dart';
import '../desktop/desktop_stretch_probe.dart';

/// SPEC §2.3 "Grafik karti **720** (min 360)" — pano kartinin en musamahakar
/// tavani. Tek sayilik doseme tavani (320) bundan sikidir.
const double kCardCeilingPx = kDesktopMaxCardWidthPx;

/// SPEC KURAL 2.2 hedefi: 66 karakter x 7.5 px (Bringhurst ideal olcusu).
/// Sert tavan 600 (WCAG 2.1 SC 1.4.8); bu kapi HEDEFI olcer.
const double kLabelValueTargetPx = DesktopBreakpoints.labelValueTargetWidth;

/// Bir kartin "dev kutu, tek satir" olcusu icin ust sinir (WP-671 ile ayni).
const double kDeadWidthCeilingPx = 480;

Rect _globalRect(RenderBox box) =>
    MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);

/// Cizilen (offstage olmayan) kart kutulari, ekran koordinatinda.
List<Rect> paintedCardRects(WidgetTester tester) {
  final out = <Rect>[];
  for (final element in find.byType(Card, skipOffstage: true).evaluate()) {
    final ro = element.renderObject;
    if (ro is! RenderBox || !ro.hasSize) continue;
    out.add(_globalRect(ro));
  }
  out.sort((a, b) => b.width.compareTo(a.width));
  return out;
}

/// Bir kartin icindeki EN GENIS boyanan metin (ikonlar haric).
double widestInkIn(RenderObject node) {
  var widest = 0.0;
  void walk(RenderObject n) {
    if (n is RenderOffstage && n.offstage) return;
    if (n is RenderParagraph && n.hasSize) {
      final text = n.text.toPlainText();
      final trimmed = text.trim();
      final isIcon =
          trimmed.runes.length == 1 &&
          trimmed.runes.first >= 0xE000 &&
          trimmed.runes.first <= 0xF8FF;
      if (trimmed.isNotEmpty && !isIcon) {
        final boxes = n.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: text.length),
        );
        for (final box in boxes) {
          final w = box.toRect().width;
          if (w > widest) widest = w;
        }
      }
    }
    n.visitChildren(walk);
  }

  walk(node);
  return widest;
}

void main() {
  final tr = AppLocalizationsTr();

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

  /// 🔴 `debugDefaultTargetPlatformOverride` test GOVDESI BITMEDEN geri
  /// alinmali; `tearDown` gec kalir ve "foundation debug variable was changed"
  /// diye YALANCI kirmizi uretir (WP-671'in bu dosyaya devrettigi tuzak).
  Future<void> onPlatform(
    TargetPlatform platform,
    Future<void> Function() body,
  ) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  Future<void> openHome(WidgetTester tester, {required Size window}) async {
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
          ...desktopInMemoryDataOverrides(),
        ],
        child: const OnlineStudyRoomApp(),
      ),
    );
    await settle(tester);
    expect(find.text(tr.homeAnaSayfa), findsWidgets);
    await tester.tap(find.text(tr.homeAnaSayfa).first);
    await settle(tester);
  }

  // ===================== MASAUSTU: CIZILEN DUZEN =========================

  for (final window in [const Size(1920, 1080), const Size(2560, 1440)]) {
    final w = window.width.toInt();

    testWidgets('ana pano @${w}px — kart tavani ve iki sutun', (tester) async {
      await onPlatform(TargetPlatform.windows, () async {
        await openHome(tester, window: window);

        final cards = paintedCardRects(tester);
        expect(
          cards,
          isNotEmpty,
          reason: 'Pano hic kart cizmemis; olculecek bir sey yok.',
        );

        // --- SPEC §2.3: kart 720 px'i gecmez -----------------------------
        for (final rect in cards) {
          expect(
            rect.width,
            lessThanOrEqualTo(kCardCeilingPx),
            reason:
                'SPEC §2.3 grafik karti tavani ${kCardCeilingPx.toInt()} px. '
                'Kart ${rect.width.toStringAsFixed(0)} px genisliginde '
                '(${rect.left.toStringAsFixed(0)}..'
                '${rect.right.toStringAsFixed(0)}); icerigine gore degil '
                'PENCEREYE gore boyutlanmis. WP-676 oncesi bu sayi 1440 idi.',
          );
        }

        // --- Masaustu = cok sutun: en az iki kart AYNI satirda -----------
        final sideBySide = <String>[];
        for (var i = 0; i < cards.length; i++) {
          for (var j = i + 1; j < cards.length; j++) {
            final a = cards[i];
            final b = cards[j];
            final sameRow = (a.top - b.top).abs() < 4;
            final apart = a.right <= b.left + 1 || b.right <= a.left + 1;
            if (sameRow && apart) {
              sideBySide.add(
                '${a.left.toStringAsFixed(0)}..${a.right.toStringAsFixed(0)} | '
                '${b.left.toStringAsFixed(0)}..${b.right.toStringAsFixed(0)}',
              );
            }
          }
        }
        expect(
          sideBySide,
          isNotEmpty,
          reason:
              'Masaustunde pano hala TEK SUTUN: hicbir iki kart ayni satirda '
              'yan yana degil. Cizilen kartlar: '
              '${cards.map((r) => "${r.left.toStringAsFixed(0)}..${r.right.toStringAsFixed(0)}@${r.top.toStringAsFixed(0)}").join(", ")}',
        );

        // --- OLU ALAN: dev kutu / tek satir ------------------------------
        for (final element
            in find.byType(Card, skipOffstage: true).evaluate()) {
          final ro = element.renderObject;
          if (ro is! RenderBox || !ro.hasSize) continue;
          final rect = _globalRect(ro);
          final ink = widestInkIn(ro);
          if (ink <= 0) continue;
          expect(
            rect.width - ink,
            lessThanOrEqualTo(kDeadWidthCeilingPx),
            reason:
                'Kart ${rect.width.toStringAsFixed(0)} px, icindeki en genis '
                'metin ${ink.toStringAsFixed(0)} px — '
                '${(rect.width - ink).toStringAsFixed(0)} px olu alan.',
          );
        }

        // --- SPEC §6: masaustu yuzeyi BAGLI mi ---------------------------
        expect(
          find.byType(DesktopPageScaffold, skipOffstage: true),
          findsOneWidget,
          reason:
              'SPEC §6 "BAGLA, ATMA": ana pano masaustu sayfa yuzeyine bagli '
              'degil, kendi ciplak Scaffold\'unu kuruyor.',
        );
      });
    });

    testWidgets('ana pano @${w}px — etiket-deger satiri 496 px\'te durur', (
      tester,
    ) async {
      await onPlatform(TargetPlatform.windows, () async {
        await openHome(tester, window: window);

        // "Bugun ozeti" -> "0sn": WP-676 oncesi 1408 px, arasi 1182 px bosluk.
        final label = tester.getRect(find.text(tr.homeBugunOzeti).first);
        final valueFinder = find.descendant(
          of: find.byType(Card),
          matching: find.textContaining('sn'),
        );
        expect(
          valueFinder,
          findsWidgets,
          reason: '"Bugun ozeti" kartinin toplam suresi cizilmemis.',
        );
        final value = tester.getRect(valueFinder.first);
        final span = value.right - label.left;
        expect(
          span,
          lessThanOrEqualTo(kLabelValueTargetPx + 1),
          reason:
              'SPEC KURAL 2.2 hedefi ${kLabelValueTargetPx.toInt()} px '
              '(Bringhurst 66ch). "Bugun ozeti" -> deger satiri '
              '${span.toStringAsFixed(0)} px; goz etiketten degere atlarken '
              'satiri kaybediyor. WP-676 oncesi 1408 px idi.',
        );
      });
    });
  }

  // ===================== MASAUSTU: ISLEV KORUNDU MU ======================

  testWidgets('ana pano @1920 — duzenleme yolu ve boyut paneli duruyor', (
    tester,
  ) async {
    await onPlatform(TargetPlatform.windows, () async {
      await openHome(tester, window: const Size(1920, 1080));

      final editButton = find.byIcon(Icons.dashboard_customize_outlined);
      expect(
        editButton,
        findsOneWidget,
        reason:
            'Masaustu basligindaki "Panoyu duzenle" dugmesi kayboldu — '
            'duzenlemeye giris yolu yok.',
      );
      await tester.tap(editButton);
      await settle(tester);

      expect(
        find.byKey(const Key('home-sticky-size-panel')),
        findsOneWidget,
        reason: 'Duzenleme modunda yapisik boyut paneli cizilmiyor.',
      );
      for (final icon in [
        Icons.vertical_align_top,
        Icons.restart_alt,
        Icons.add,
      ]) {
        expect(
          find.byIcon(icon),
          findsWidgets,
          reason: 'Duzenleme eylemi kayboldu: $icon',
        );
      }
    });
  });

  // ===================== MOBIL REGRESYON =================================

  testWidgets('mobil 390x844 — pano duzeni BIREBIR korunur', (tester) async {
    await onPlatform(TargetPlatform.android, () async {
      await openHome(tester, window: const Size(390, 844));

      expect(
        find.byType(DesktopPageScaffold, skipOffstage: true),
        findsNothing,
        reason:
            'Masaustu sayfa yuzeyi mobil agaca sizmis. SPEC §7: mobil dal '
            'degismez.',
      );

      final cards = paintedCardRects(tester);
      expect(cards, isNotEmpty);
      // Mobilde kartlar hala TAM GENISLIK ve ALT ALTA: hicbir iki kart yan
      // yana degil. Masaustu sigdirmasi genislik kosuluna bagli oldugu icin
      // (`large` = 1200) burada hic calismaz.
      for (var i = 0; i < cards.length; i++) {
        for (var j = i + 1; j < cards.length; j++) {
          final a = cards[i];
          final b = cards[j];
          final sameRow = (a.top - b.top).abs() < 4;
          final apart = a.right <= b.left + 1 || b.right <= a.left + 1;
          expect(
            sameRow && apart,
            isFalse,
            reason:
                'Mobilde pano iki sutuna acilmis — masaustu duzeni genislik '
                'kosulunu asmis. ${a.left}..${a.right} | ${b.left}..${b.right}',
          );
        }
      }
    });
  });

  // ===================== SAF FONKSIYON: SIGDIRMA =========================

  test('desktopMaxCardCells — 1440 px bantta izgaranin tam yarisi', () {
    // Icerik bandi 1440, sayfa kenar boslugu 2x24 → izgara 1392 px, 32 sutun,
    // 8 px bosluk. Hucre = (1392 - 31x8)/32 = 35.75.
    const cell = (1392 - 31 * 8) / 32;
    expect(
      desktopMaxCardCells(cell: cell, gap: 8, columns: 32),
      16,
      reason:
          'SPEC §2.3 kart tavani (720 px) 1440 bantta tam yarim izgara eder; '
          'yani masaustu panosu en az iki sutuna acilir.',
    );
    // Tavani asmadigi OLCULUR, varsayilmaz.
    expect(16 * cell + 15 * 8, lessThanOrEqualTo(kDesktopMaxCardWidthPx));
    expect(17 * cell + 16 * 8, greaterThan(kDesktopMaxCardWidthPx));
  });

  test('fitLayoutToDesktopBand — sigan duzene DOKUNMAZ (idempotent)', () {
    final fitted = [
      const DashboardCardConfig(
        DashboardCardType.today,
        x: 0,
        y: 0,
        w: 16,
        h: 8,
      ),
      const DashboardCardConfig(
        DashboardCardType.leaderboard,
        x: 16,
        y: 0,
        w: 16,
        h: 8,
      ),
    ];
    expect(
      identical(
        fitLayoutToDesktopBand(fitted, columns: 32, maxCells: 16),
        fitted,
      ),
      isTrue,
      reason:
          'Sigan duzen icin AYNI liste donmeli; yoksa her karede yeniden '
          'yazilir ve kalicilastirma dongusu olusur.',
    );
  });

  test('fitLayoutToDesktopBand — tam genislik yigini iki sutuna acilir', () {
    final stacked = [
      const DashboardCardConfig(
        DashboardCardType.today,
        x: 0,
        y: 0,
        w: 32,
        h: 8,
      ),
      const DashboardCardConfig(
        DashboardCardType.leaderboard,
        x: 0,
        y: 8,
        w: 32,
        h: 8,
      ),
    ];
    final fitted = fitLayoutToDesktopBand(stacked, columns: 32, maxCells: 16);

    expect(fitted.length, stacked.length, reason: 'Kart sayisi degismemeli.');
    expect(
      fitted.map((c) => c.type).toList(),
      stacked.map((c) => c.type).toList(),
      reason: 'Kart sirasi/turu degismemeli.',
    );
    expect(fitted.every((c) => c.w <= 16), isTrue);
    expect(fitted.every((c) => c.h == 8), isTrue, reason: 'Yukseklik korunur.');
    // Iki kart da ayni satirda, yan yana.
    expect(fitted[0].y, 0);
    expect(fitted[1].y, 0);
    expect(fitted[0].x, 0);
    expect(fitted[1].x, 16);
  });
}
