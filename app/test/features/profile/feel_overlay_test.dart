import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/theme/app_theme.dart';
import 'package:online_study_room/features/profile/theme_builder/feel_overlay.dart';
import 'package:online_study_room/features/profile/theme_builder/theme_draft.dart';
import 'package:online_study_room/features/profile/theme_builder/theme_feel_catalog.dart';

ThemeData _themeWithFeel(String feelId) => ThemeDraft.fromPreset(
  slotId: 'custom_1',
  name: 'T',
  preset: themePresetById('campfire_night'),
).withFeel(feelOptionById(feelId).feel).themeFor(Brightness.dark);

Future<void> _pump(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: FeelOverlay(child: const Scaffold(body: Text('içerik'))),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('efekt yoksa hiçbir ek çizim katmanı eklenmez', (tester) async {
    // Modern his: gren 0, parıltı 0, cam 0 → child olduğu gibi döner.
    await _pump(tester, _themeWithFeel('modern'));

    expect(find.text('içerik'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is FeelOverlayPainter,
      ),
      findsNothing,
    );
  });

  testWidgets('dokulu his gren katmanını çizer', (tester) async {
    await _pump(tester, _themeWithFeel('vintage'));

    expect(
      find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is FeelOverlayPainter,
      ),
      findsOneWidget,
    );
  });

  testWidgets('parıltılı his atmosfer katmanını çizer ve dokunuşu yutmaz', (
    tester,
  ) async {
    await _pump(tester, _themeWithFeel('neon'));

    final painter = tester.widget<CustomPaint>(
      find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is FeelOverlayPainter,
      ),
    );
    final spec = (painter.painter! as FeelOverlayPainter).spec;
    expect(spec.paintsGlow, isTrue);
    // Katman IgnorePointer içinde: altındaki arayüz tıklanabilir kalır.
    expect(
      find.ancestor(
        of: find.byWidget(painter),
        matching: find.byType(IgnorePointer),
      ),
      findsWidgets,
    );
  });

  testWidgets('tema uzantısı yokken sarmalayıcı şeffaf davranır', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: FeelOverlay(child: const Scaffold(body: Text('içerik'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('içerik'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is FeelOverlayPainter,
      ),
      findsNothing,
    );
  });

  testWidgets('WP-314: atmosfer kapalıyken bile his kendi imzasını çizer', (
    tester,
  ) async {
    // Sahip: "6/8'deki feels kısmı önizlemede hiçbir şey değiştirmiyor."
    // Sebep: WP-307'den sonra his artık kullanıcının atmosferini ezmiyor;
    // zen/neon/cam'ın gren gücü de 0 olduğu için çizecek bir şey kalmıyordu.
    final base = ThemeDraft.fromPreset(
      slotId: 'custom_1',
      name: 'T',
      preset: themePresetById('campfire_night'),
    ).withAtmosphere(
      const AppAtmosphere(
        gradientStart: Color(0xFF101010),
        gradientEnd: Color(0xFF202020),
        glowColor: Color(0xFF3186E9),
        glowStrength: 0,
        blurSigma: 0,
        glassOpacity: 0,
      ),
    );

    for (final feelId in ['zen', 'neon', 'glass', 'vintage']) {
      await _pump(
        tester,
        base.withFeel(feelOptionById(feelId).feel).themeFor(Brightness.dark),
      );
      final painter = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is FeelOverlayPainter,
      );
      expect(painter, findsOneWidget, reason: '$feelId hiçbir şey çizmiyor');
      final spec =
          (tester.widget<CustomPaint>(painter).painter! as FeelOverlayPainter)
              .spec;
      expect(spec.feelId, feelId);
      expect(spec.paintsSignature, isTrue);
    }

    // Kimliği "efekt yok" olan hisler bilerek boş kalır.
    for (final feelId in ['modern', 'flat']) {
      await _pump(
        tester,
        base.withFeel(feelOptionById(feelId).feel).themeFor(Brightness.dark),
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint && widget.painter is FeelOverlayPainter,
        ),
        findsNothing,
        reason: '$feelId efektsiz olmalı',
      );
    }
  });

  test('spec eşitliği gereksiz yeniden çizimi engeller', () {
    const a = FeelOverlaySpec(
      feelId: 'vintage',
      grainStrength: 0.5,
      grainKind: 'film',
      gradientStart: Color(0xFF000000),
      gradientEnd: Color(0xFF111111),
      glowColor: Color(0xFFF97316),
      glowStrength: 0.4,
      blurSigma: 0,
      glassOpacity: 0,
    );
    const b = FeelOverlaySpec(
      feelId: 'vintage',
      grainStrength: 0.5,
      grainKind: 'film',
      gradientStart: Color(0xFF000000),
      gradientEnd: Color(0xFF111111),
      glowColor: Color(0xFFF97316),
      glowStrength: 0.4,
      blurSigma: 0,
      glassOpacity: 0,
    );
    expect(const FeelOverlayPainter(a).shouldRepaint(const FeelOverlayPainter(b)), isFalse);
    expect(
      const FeelOverlayPainter(a).shouldRepaint(
        const FeelOverlayPainter(
          FeelOverlaySpec(
            feelId: 'vintage',
            grainStrength: 0.9,
            grainKind: 'film',
            gradientStart: Color(0xFF000000),
            gradientEnd: Color(0xFF111111),
            glowColor: Color(0xFFF97316),
            glowStrength: 0.4,
            blurSigma: 0,
            glassOpacity: 0,
          ),
        ),
      ),
      isTrue,
    );
  });
}
