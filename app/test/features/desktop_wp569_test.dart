// WP-569: Windows masaüstü arayüzünün gerçek çalışan uygulamada ÖLÇÜLEN
// kusurları. Dördü de bu makinede (3840×2400 panel, %250 ölçekleme, dpr 2.5)
// koşan uygulamada Flutter VM service üzerinden doğrulandı:
//
//   1. Mini pencere (Compact Focus) bir **klavye tuzağıydı**. Ctrl+Shift+M
//      pencereyi 360×220'ye indiriyor, ama aynı tuş geri çıkaramıyordu: mini
//      kabuk `DesktopHomeShell`i ağaçtan çıkarır, onunla birlikte bütün
//      `CallbackShortcuts` katmanı da gider. Ölçüm: fareyle giriş/çıkış
//      çalışıyor, klavyeyle yalnız giriş çalışıyordu.
//   2. Mini pencere **kendi en küçük boyunda taşıyordu**. Pencere 320×180'e
//      çekilince istemci alanı 307×145 mantıksal piksele düşüyor ve render
//      ağacında `RenderFlex#... OVERFLOWING` beliriyordu (yaratıcı zinciri:
//      `Column <- Padding <- MediaQuery <- Padding <- SafeArea`).
//   3. Masaüstü panelleri **Esc ile kapanmıyordu**. Ayarlar panelini Ctrl+,
//      ile açıp Esc'e basınca `SettingsScreen` ağaçta kalıyordu; panelin kendi
//      iç `Navigator`ı Esc'i yutuyor.
//   4. Sol panelde **klavye odağı hover ile aynı görünüyordu** (ikisi de
//      `onSurface` %6 zemin) - koyu temada odak fiilen görünmezdi.
//
// Testlerin hepsi kasten kırık girdiyle sınandı; düzeltmeyi geri alınca
// kırmızıya dönerler.
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/features/desktop/compact_focus_view.dart';
import 'package:online_study_room/features/desktop/desktop_navigation_pane.dart';
import 'package:online_study_room/features/desktop/desktop_surface.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// Gerçek `StudyTimerNotifier` method channel + zamanlayıcı + yaşam döngüsü
/// dinleyicisi kurar; bu testlerin ölçtüğü şey yerleşim ve klavye, sayaç değil.
class _StaticStudyTimer extends StudyTimerNotifier {
  @override
  StudyTimerState build() => const StudyTimerState();
}

Widget _compactHost({
  Future<void> Function()? onToggleCompact,
  Future<void> Function()? onTogglePin,
}) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith(
        (ref) => Stream.value(
          Profile(id: 'u1', displayName: 'Deneme', createdAt: DateTime(2026)),
        ),
      ),
      userSubjectsProvider.overrideWith(
        (ref) => Stream.value(const <Subject>[]),
      ),
      studyTimerProvider.overrideWith(_StaticStudyTimer.new),
    ],
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: CompactFocusView(
        onToggleCompact: onToggleCompact ?? () async {},
        onTogglePin: onTogglePin ?? () async {},
      ),
    ),
  );
}

/// Ekranda gerçekten BOYANAN odak halkaları (saydam kenarlık sayılmaz).
///
/// Bayrağa değil boyaya bakar: `focused` true olup kenarlığı saydam bırakan
/// bir "düzeltme" bu yardımcıyı geçemez.
List<BorderSide> _paintedFocusRings(WidgetTester tester) {
  return tester
      .widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(DesktopNavFocusRing),
          matching: find.byType(DecoratedBox),
        ),
      )
      .map((box) => box.decoration)
      .whereType<BoxDecoration>()
      .map((decoration) => decoration.border)
      .whereType<Border>()
      .map((border) => border.top)
      .where((side) => side.color != Colors.transparent && side.width > 0)
      .toList();
}

void main() {
  group('WP-569/1 mini pencere klavye tuzağı', () {
    testWidgets('Ctrl+Shift+M mini pencereden ÇIKARIR', (tester) async {
      var exits = 0;
      await tester.pumpWidget(
        _compactHost(onToggleCompact: () async => exits++),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(exits, 1, reason: 'mini pencere klavyeyle terk edilebilmeli');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Ctrl+Shift+P mini pencerede de üstte-tut anahtarını çevirir', (
      tester,
    ) async {
      var pins = 0;
      await tester.pumpWidget(_compactHost(onTogglePin: () async => pins++));
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(pins, 1);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('WP-569/2 mini pencere en küçük boyunda taşmaz', () {
    testWidgets('en küçük mini pencerenin istemci alanında taşma yok', (
      tester,
    ) async {
      // 🔴 Bu sayı 320x180 DEĞİL. `_compactMinimumSize` pencere ÇERÇEVESİNİN
      // en küçük boyu; Flutter'ın gördüğü istemci alanı başlık çubuğu ve
      // kenarlık kadar daha küçüktür. Çalışan uygulamada ölçülen değer
      // (render ağacı `configuration:` satırı): 307.2 x 144.8 mantıksal.
      // İlk yazdığım sürüm 320x180'i istemci sanıyordu ve hiçbir şey
      // ölçmüyordu — sabotaj matrisi bunu yakaladı.
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(307, 145);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_compactHost());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Taşmayı "saati gizleyerek" çözmek de kabul değil: saat hâlâ ekranda.
      expect(find.byKey(const ValueKey('compact-focus-time')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('compact-focus-toggle')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('WP-569/3 Esc masaüstü panelini kapatır', () {
    testWidgets('Esc önce panel içi geçmişi, sonra paneli kapatır', (
      tester,
    ) async {
      // `isDesktopWindow` buna bakar: masaüstü kolu ancak windows'ta çalışır.
      // Bayrak test GÖVDESİNDE geri alınır — `_verifyInvariants` tearDown'dan
      // önce koşuyor ve açık kalan bayrak testi düşürüyor.
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showDesktopPanel<void>(
                    context: context,
                    builder: (panelContext) => Scaffold(
                      body: Center(
                        child: FilledButton(
                          onPressed: () =>
                              Navigator.of(panelContext).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (_) => const Scaffold(
                                    body: Center(child: Text('panel-ikinci')),
                                  ),
                                ),
                              ),
                          child: const Text('panel-ilk'),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('paneli-ac'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('paneli-ac'));
      await tester.pumpAndSettle();
      expect(find.text('panel-ilk'), findsOneWidget);

      await tester.tap(find.text('panel-ilk'));
      await tester.pumpAndSettle();
      expect(find.text('panel-ikinci'), findsOneWidget);

      // 1. Esc: panelin İÇİNDEKİ geçmiş geri alınır, panel açık kalır.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('panel-ikinci'), findsNothing);
      expect(find.text('panel-ilk'), findsOneWidget);

      // 2. Esc: geçmiş bittiği için panelin kendisi kapanır.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('panel-ilk'), findsNothing);
      expect(find.text('paneli-ac'), findsOneWidget);

      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('WP-569/4 sol panelde odak görünür ve hover ile karışmaz', () {
    Widget pane({int selectedIndex = 0}) {
      return MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(
          body: Row(
            children: [
              DesktopNavigationPane(
                items: const [
                  DesktopNavItem(
                    icon: Icons.home_outlined,
                    selectedIcon: Icons.home,
                    label: 'Ana Sayfa',
                  ),
                  DesktopNavItem(
                    icon: Icons.groups_outlined,
                    selectedIcon: Icons.groups,
                    label: 'Gruplar',
                  ),
                ],
                selectedIndex: selectedIndex,
                onSelected: (_) {},
                footer: const SizedBox.shrink(),
              ),
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ),
      );
    }

    testWidgets('Tab görünür bir odak halkası çizer', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(pane());
      await tester.pumpAndSettle();
      expect(
        _paintedFocusRings(tester),
        isEmpty,
        reason: 'odak yokken halka boyanmamalı',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      final rings = _paintedFocusRings(tester);
      expect(rings, hasLength(1), reason: 'tam olarak odaklı öğe işaretlenir');

      final scheme = Theme.of(
        tester.element(find.byType(DesktopNavigationPane)),
      ).colorScheme;
      expect(rings.single.color, scheme.primary);
      expect(rings.single.width, DesktopNavFocusRing.thickness);
    });

    testWidgets('fareyle üzerine gelmek odak halkası çizmez', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(pane());
      await tester.pumpAndSettle();

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('Gruplar')));
      await tester.pumpAndSettle();

      expect(
        _paintedFocusRings(tester),
        isEmpty,
        reason: 'hover ile klavye odağı ayırt edilebilmeli',
      );
    });
  });
}
