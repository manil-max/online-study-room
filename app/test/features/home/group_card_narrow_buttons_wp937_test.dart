import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/home/widgets/group_card_shell.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-937: yarım genişlikli ana ekran hücresinde (360 dp telefon, ~170 dp
/// kart) "Grup oluştur" / "Koda katıl" düğmelerinin etiketleri iki satıra
/// kırılıyor, ikinci düğme kartın altında kesiliyordu (UX denetimi e01).
void main() {
  for (final locale in const [Locale('tr'), Locale('en')]) {
    for (final scale in const [1.0, 1.3]) {
      testWidgets('dar hucrede iki dugme de tam gorunur ($locale, x$scale)', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 170,
                    // Denetim karesinde (360 dp) hücre ~163 dp yüksekliğinde.
                    height: 165,
                    child: GroupCardShell(
                      title: 'Grup sıralaması',
                      onCreateGroup: () {},
                      onJoinGroup: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final card = tester.getRect(find.byType(Card));
        final create = find.byWidgetPredicate((w) => w is FilledButton);
        final join = find.byWidgetPredicate((w) => w is OutlinedButton);
        for (final button in [create, join]) {
          expect(button, findsOneWidget);
          final rect = tester.getRect(button);
          expect(rect.height, lessThanOrEqualTo(48),
              reason: 'etiket tek satır kalmalı');
          expect(rect.bottom, lessThanOrEqualTo(card.bottom),
              reason: 'düğme kartın altında kesilmemeli');
          expect(rect.right, lessThanOrEqualTo(card.right));
        }
      });
    }
  }
}
