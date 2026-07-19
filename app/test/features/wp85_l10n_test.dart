import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/auth/auth_screen.dart';
import 'package:online_study_room/features/profile/widgets/goal_editor_dialog.dart';
import 'package:online_study_room/features/updater/release_notes_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

Widget _localizedApp(Locale locale, Widget home) {
  return ProviderScope(
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

void main() {
  for (final locale in const [Locale('en'), Locale('tr')]) {
    testWidgets('auth screen renders ${locale.languageCode} catalog', (
      tester,
    ) async {
      await tester.pumpWidget(_localizedApp(locale, const AuthScreen()));
      await tester.pumpAndSettle();

      if (locale.languageCode == 'tr') {
        expect(find.text('Hesabına giriş yap'), findsOneWidget);
        expect(find.text('E-posta'), findsOneWidget);
        expect(find.text('Şifre'), findsOneWidget);
        expect(find.text('Giriş yap'), findsOneWidget);
      } else {
        expect(find.text('Log in to your account'), findsOneWidget);
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
        expect(find.text('Log in'), findsOneWidget);
      }
    });

    testWidgets('release notes fallback renders ${locale.languageCode}', (
      tester,
    ) async {
      await tester.pumpWidget(
        _localizedApp(
          locale,
          const WhatsNewDialog(note: null, fallbackVersion: '1.0.0+1'),
        ),
      );
      await tester.pumpAndSettle();

      if (locale.languageCode == 'tr') {
        expect(find.text('Yenilikler'), findsOneWidget);
        expect(
          find.text('Bu sürüm için detaylı notlar yakında eklenecek.'),
          findsOneWidget,
        );
        expect(find.text('Tamam'), findsOneWidget);
      } else {
        expect(find.text("What's New"), findsOneWidget);
        expect(
          find.text('Detailed notes for this version will be added soon.'),
          findsOneWidget,
        );
        expect(find.text('OK'), findsOneWidget);
      }
    });

    testWidgets('profile goal dialog renders ${locale.languageCode}', (
      tester,
    ) async {
      await tester.pumpWidget(
        _localizedApp(
          locale,
          Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showGoalEditorDialog(context, initialMinutes: 60),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      if (locale.languageCode == 'tr') {
        expect(find.text('Günlük hedef'), findsNWidgets(2));
        expect(find.text('Saat'), findsOneWidget);
        expect(find.text('Dakika'), findsOneWidget);
        expect(find.text('Kaydet'), findsOneWidget);
      } else {
        expect(find.text('Daily goal'), findsNWidgets(2));
        // WP-222: saat birimi etiketi "Clock" → "Hours" (classroomSaat).
        expect(find.text('Hours'), findsOneWidget);
        expect(find.text('Minute'), findsOneWidget);
        expect(find.text('Save'), findsOneWidget);
      }
    });
  }
}
