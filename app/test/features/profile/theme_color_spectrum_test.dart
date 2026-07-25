import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/profile/theme_builder/theme_builder_widgets.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-309 — sahip: "hazır renkler vermek yerine spektrumlu hazır renkler daha
/// güzel olur… en sağdakine basınca spektrum açılıyor, istediğin rengi
/// seçebiliyorsun." (Samsung Notes deseni)
void main() {
  testWidgets('hazır renk ızgarasının sonundaki düğme spektrumu açar', (
    tester,
  ) async {
    Color? picked;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ColorField(
            label: 'Ana renk',
            color: const Color(0xFF3186E9),
            onChanged: (value) => picked = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ana renk'));
    await tester.pumpAndSettle();

    // Hazır palet açılır ve içinde spektrum düğmesi vardır.
    expect(
      find.byKey(ValueKey('themeColor_${const Color(0xFF3186E9).toARGB32()}')),
      findsOneWidget,
    );
    final spectrumButton = find.byKey(const Key('themeColorSpectrumButton'));
    expect(spectrumButton, findsOneWidget);

    await tester.ensureVisible(spectrumButton);
    await tester.pumpAndSettle();
    await tester.tap(spectrumButton);
    await tester.pumpAndSettle();

    // Spektrum modu: üç HSV kaydırıcısı + uygula düğmesi.
    expect(find.text('Ton'), findsOneWidget);
    expect(find.text('Doygunluk'), findsOneWidget);
    expect(find.text('Parlaklık'), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(3));

    // Ton kaydırıcısını sürükle → hazır palette olmayan bir renk üret.
    await tester.drag(find.byType(Slider).first, const Offset(-120, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('themeColorSpectrumApply')));
    await tester.pumpAndSettle();

    expect(picked, isNotNull);
    expect(picked, isNot(const Color(0xFF3186E9)));
  });
}
