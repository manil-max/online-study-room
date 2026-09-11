import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/features/home/dashboard_card.dart';
import 'package:online_study_room/features/home/dday_prefs.dart';
import 'package:online_study_room/features/home/widgets/card_scaffold.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _action = Key('dday-card-header-edit');
const _body = Key('dday-card-open-editor');
const _capture = Key('card-capture');

Future<void> _pump(
  WidgetTester tester, {
  DashboardCardSize size = DashboardCardSize.small,
  Brightness brightness = Brightness.light,
  ScrollController? outerScroll,
  bool legacyLayout = false,
  bool previewFonts = false,
}) async {
  SharedPreferences.setMockInitialValues({
    kExamListKey: encodeExamList(
      ExamListState(
        entries: [
          for (var i = 0; i < 3; i++)
            ExamEntry(
              id: '$i',
              name: 'Sınav ${i + 1}',
              day: DateTime(2026, 11, i + 1),
            ),
        ],
      ),
    ),
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ddayClockProvider.overrideWithValue(() => DateTime(2026, 9, 11)),
      ],
      child: MaterialApp(
        theme: ThemeData(
          brightness: brightness,
          fontFamily: previewFonts ? 'Inter' : null,
        ),
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              final card = RepaintBoundary(
                key: _capture,
                child: SizedBox(
                  width: size == DashboardCardSize.small ? 180 : 360,
                  child: legacyLayout
                      ? SizedBox(
                          height: defaultCardHeight(size),
                          child: CardScaffold(
                            header: Row(
                              children: [
                                Expanded(
                                  child: cardTitle(
                                    context,
                                    AppLocalizations.of(
                                      context,
                                    ).homeSinavGeriSayimi,
                                  ),
                                ),
                                const SizedBox(width: 40, height: 24),
                              ],
                            ),
                            bodyBuilder: (_, height) =>
                                SizedBox(key: _body, height: height),
                          ),
                        )
                      : dashboardCardFor(
                          DashboardCardType.dday,
                          size,
                          height: defaultCardHeight(size),
                        ),
                ),
              );
              return outerScroll == null
                  ? Center(child: card)
                  : SingleChildScrollView(
                      controller: outerScroll,
                      child: Column(
                        children: [card, const SizedBox(height: 1200)],
                      ),
                    );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  for (final size in DashboardCardSize.values) {
    testWidgets('${size.name}: gerçek 48 dp hedef gövde alanını korur', (
      tester,
    ) async {
      await _pump(tester, size: size, legacyLayout: true);
      final previous = tester.getRect(find.byKey(_body));
      await _pump(tester, size: size);
      final current = tester.getRect(find.byKey(_body));
      expect(tester.getSize(find.byKey(_action)), const Size(48, 48));
      expect(current.top, closeTo(previous.top, 1));
      expect(current.height, greaterThanOrEqualTo(previous.height));
      expect(tester.takeException(), isNull);
      final scroll = find.descendant(
        of: find.byKey(_body),
        matching: find.byType(Scrollable),
      );
      expect(tester.state<ScrollableState>(scroll).position.maxScrollExtent, 0);
    });
  }

  for (final corner in [
    const Offset(1, 1),
    const Offset(47, 1),
    const Offset(1, 47),
    const Offset(47, 47),
  ]) {
    testWidgets('48 dp hedefin $corner köşesi düzenleyiciyi açar', (
      tester,
    ) async {
      await _pump(tester);
      await tester.tapAt(tester.getTopLeft(find.byKey(_action)) + corner);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dday-add-exam')), findsOneWidget);
    });
  }

  testWidgets('semantik düğme adı ve klavyeyle etkinleştirme korunur', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pump(tester);
      final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
      expect(
        tester.getSemantics(find.byKey(_action)),
        matchesSemantics(
          tooltip: l10n.homeSinavlariDuzenle,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dday-add-exam')), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('başlıktan sürükleme dış sayfayı kaydırır ve editör açmaz', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await _pump(tester, outerScroll: controller);
    await tester.drag(find.byKey(_action), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));
    expect(find.byKey(const Key('dday-add-exam')), findsNothing);
  });

  for (final brightness in Brightness.values) {
    testWidgets('küçük kart ${brightness.name} görünümü', (tester) async {
      await tester.runAsync(() async {
        final textFont = FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'));
        final iconFont = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await textFont.load();
        await iconFont.load();
      });
      await _pump(tester, brightness: brightness, previewFonts: true);
      await expectLater(
        find.byKey(_capture),
        matchesGoldenFile(
          'goldens/card_header_access_wp822_${brightness.name}.png',
        ),
      );
    }, tags: ['golden']);
  }
}
