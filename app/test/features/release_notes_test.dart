import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/updater/release_notes_screen.dart';
import 'package:online_study_room/features/updater/release_notes_service.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Locale is from flutter/material.dart.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReleaseNotesService', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('shouldShowWhatsNew returns true if build is newer', () async {
      final service = ReleaseNotesService(
        preferences: prefs,
        packageInfoLoader: () async => PackageInfo(
          appName: 'Test',
          packageName: 'test',
          version: '1.0.0',
          buildNumber: '10',
        ),
      );

      // Initially should show (last seen is 0)
      expect(await service.shouldShowWhatsNew(), isTrue);

      // Mark as seen
      await service.markCurrentBuildSeen();

      // Should no longer show
      expect(await service.shouldShowWhatsNew(), isFalse);
    });

    test(
      'shouldShowWhatsNew returns false if build is same or older',
      () async {
        await prefs.setInt('release_notes_last_seen_build', 10);

        final service = ReleaseNotesService(
          preferences: prefs,
          packageInfoLoader: () async => PackageInfo(
            appName: 'Test',
            packageName: 'test',
            version: '1.0.0',
            buildNumber: '9', // Older build
          ),
        );

        expect(await service.shouldShowWhatsNew(), isFalse);
      },
    );

    test('forLocale picks English fields when language is not tr', () {
      const note = ReleaseNote(
        versionName: '1.0.27',
        buildNumber: 27,
        channel: 'stable',
        date: '2026-07-15',
        title: 'Türkçe başlık',
        highlights: ['TR madde'],
        fixes: ['TR düzeltme'],
        notes: ['TR not'],
        titleEn: 'English title',
        highlightsEn: ['EN item'],
        fixesEn: ['EN fix'],
        notesEn: ['EN note'],
      );

      final en = note.forLocale(const Locale('en'));
      expect(en.title, 'English title');
      expect(en.highlights, ['EN item']);
      expect(en.fixes, ['EN fix']);
      expect(en.notes, ['EN note']);

      final tr = note.forLocale(const Locale('tr'));
      expect(tr.title, 'Türkçe başlık');
      expect(tr.highlights, ['TR madde']);
    });

    test('forLocale falls back to Turkish when EN fields empty', () {
      const note = ReleaseNote(
        versionName: '1.0.0',
        buildNumber: 1,
        channel: 'stable',
        date: '2026-01-01',
        title: 'Sadece TR',
        highlights: ['A'],
        fixes: [],
        notes: [],
      );
      final en = note.forLocale(const Locale('de'));
      expect(en.title, 'Sadece TR');
      expect(en.highlights, ['A']);
    });
  });

  group('ReleaseNotesScreen', () {
    testWidgets('renders loading and then list', (tester) async {
      final service = ReleaseNotesService(
        assetLoader: (path) async => '''
{
  "releases": [
    {
      "versionName": "1.0.0",
      "buildNumber": 1,
      "channel": "stable",
      "date": "2026-06-21",
      "title": "İlk sürüm",
      "highlights": ["A", "B"],
      "fixes": [],
      "notes": []
    }
  ]
}
''',
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ReleaseNotesScreen(service: service),
        ),
      );

      // Wait for future to complete
      await tester.pumpAndSettle();

      expect(find.text('Güncelleme notları'), findsOneWidget);
      expect(find.text('İlk sürüm'), findsOneWidget);
    });

    testWidgets('English locale shows titleEn', (tester) async {
      final service = ReleaseNotesService(
        assetLoader: (path) async => '''
{
  "releases": [
    {
      "versionName": "1.0.0",
      "buildNumber": 1,
      "channel": "stable",
      "date": "2026-06-21",
      "title": "İlk sürüm",
      "titleEn": "First release",
      "highlights": ["A"],
      "highlightsEn": ["A-en"],
      "fixes": [],
      "notes": []
    }
  ]
}
''',
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ReleaseNotesScreen(service: service),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Release notes'), findsOneWidget);
      expect(find.text('First release'), findsOneWidget);
      expect(find.text('İlk sürüm'), findsNothing);
    });
  });
}
