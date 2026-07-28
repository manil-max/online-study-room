import 'dart:io';

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

    test(
      'bundled asset includes v28, v29 and staged v30 with EN fields',
      () async {
        // TestWidgetsFlutterBinding + rootBundle → assets/release_notes.json
        final service = ReleaseNotesService(preferences: prefs);
        final notes = await service.loadBundledNotes();
        final byBuild = {for (final n in notes) n.buildNumber: n};
        expect(byBuild.containsKey(28), isTrue);
        expect(byBuild.containsKey(29), isTrue);
        expect(byBuild.containsKey(30), isTrue);

        final v29 = byBuild[29]!;
        expect(v29.titleEn, isNotEmpty);
        expect(v29.highlightsEn, isNotEmpty);
        final en = v29.forLocale(const Locale('en'));
        expect(en.title, v29.titleEn);
        final tr = v29.forLocale(const Locale('tr'));
        expect(tr.title, v29.title);

        final v30 = byBuild[30]!;
        expect(
          v30.notes.any(
            (n) =>
                n.toLowerCase().contains('taslak') ||
                n.toLowerCase().contains('release'),
          ),
          isTrue,
        );
        expect(v30.titleEn.toLowerCase(), contains('draft'));
        final de = v30.forLocale(const Locale('de'));
        expect(de.title, v30.titleEn); // non-tr → EN
      },
    );
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
          home: ReleaseNotesScreen(service: service, channel: 'stable'),
        ),
      );

      // Wait for future to complete
      await tester.pumpAndSettle();

      expect(find.text('Güncelleme notları'), findsOneWidget);
      expect(find.text('İlk sürüm'), findsOneWidget);
      // WP-419: derleme tanısı kartı bu ekrandan Ayarlar → Hakkında'ya taşındı.
      expect(find.text('Derleme tanısı'), findsNothing);
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
          home: ReleaseNotesScreen(service: service, channel: 'stable'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Release notes'), findsOneWidget);
      expect(find.text('First release'), findsOneWidget);
      expect(find.text('İlk sürüm'), findsNothing);
    });
  });

  group('WP-419 — teknik sızıntı ve kanal süzgeci', () {
    // Liste tembel: varsayılan 800x600 viewport'ta alttaki kartlar ve "daha
    // fazla" düğmesi hiç build edilmez, sayım/tap iddiaları sessizce yanılır.
    setUp(() {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.physicalSize = const Size(1080, 12000);
      view.devicePixelRatio = 3.0;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });
    });

    /// Ekranda görünen **bütün** metinleri toplar.
    ///
    /// v55'te düzeltme yarım kaldı çünkü kapı yalnız `release_notes.json`
    /// gövdelerine bakıyordu; kimlik kartı ayrı bir widget olduğu için testin
    /// altından geçti. Kapsam artık gövde değil, ekranın tamamı.
    List<String> visibleTexts(WidgetTester tester) => <String>[
      ...tester.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? ''),
      ...tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .map((w) => w.data ?? ''),
    ];

    testWidgets('gerçek sürüm notlarının hiçbir yerinde teknik kimlik yok', (
      tester,
    ) async {
      // Kaynak uydurulmuyor: bundle'daki gerçek `assets/release_notes.json`
      // okunup ekrana veriliyor, yani denetlenen şey üretim içeriği.
      // (`rootBundle` widget testinde gerçek async I/O ister; FakeAsync altında
      // çözülmez ve pump'ı kilitler. Dosya doğrudan okunuyor — içerik aynı.)
      final raw = File(ReleaseNotesService.assetPath).readAsStringSync();
      final service = ReleaseNotesService(assetLoader: (path) async => raw);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ReleaseNotesScreen(service: service, channel: 'stable'),
        ),
      );
      await tester.pumpAndSettle();

      final texts = visibleTexts(tester);
      expect(texts, isNotEmpty);
      // "daha fazla" ile gizlenen kartlar da açılıp denetlenir.
      final showMore = find.byKey(const Key('release-notes-show-more'));
      if (showMore.evaluate().isNotEmpty) {
        await tester.tap(showMore);
        await tester.pumpAndSettle();
        texts.addAll(visibleTexts(tester));
      }

      final forbidden = RegExp(
        r'commit|migration|backend|project[- ]?ref|supabase',
        caseSensitive: false,
      );
      for (final text in texts) {
        expect(
          forbidden.hasMatch(text),
          isFalse,
          reason: 'sürüm notları ekranında teknik kimlik metni: "$text"',
        );
      }
    });

    testWidgets('stable kanalda beta rozetli kart listelenmez', (tester) async {
      final service = ReleaseNotesService(
        assetLoader: (path) async => _twoChannelAsset,
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ReleaseNotesScreen(service: service, channel: 'stable'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kararlı sürüm'), findsOneWidget);
      expect(find.text('Beta deneme'), findsNothing);
      expect(find.text('Beta'), findsNothing);
    });

    testWidgets('beta kanalı her iki zinciri de görür', (tester) async {
      final service = ReleaseNotesService(
        assetLoader: (path) async => _twoChannelAsset,
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ReleaseNotesScreen(service: service, channel: 'beta'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kararlı sürüm'), findsOneWidget);
      expect(find.text('Beta deneme'), findsOneWidget);
    });

    testWidgets('liste son N sürümle sınırlanır, gerisi düğmeyle açılır', (
      tester,
    ) async {
      final releases = List.generate(
        kReleaseNotesInitialCount + 3,
        (index) =>
            '{"versionName": "1.0.${index + 1}", "buildNumber": ${index + 1}, '
            '"channel": "stable", "date": "2026-07-0${(index % 9) + 1}", '
            '"title": "Sürüm ${index + 1}", "highlights": [], "fixes": [], '
            '"notes": []}',
      ).join(',');
      final service = ReleaseNotesService(
        assetLoader: (path) async => '{"releases": [$releases]}',
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ReleaseNotesScreen(service: service, channel: 'stable'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byType(ReleaseNoteCard),
        findsNWidgets(kReleaseNotesInitialCount),
      );
      // En yeni sürüm (en yüksek build) üstte, en eskisi gizli.
      expect(
        find.text('Sürüm ${kReleaseNotesInitialCount + 3}'),
        findsOneWidget,
      );
      expect(find.text('Sürüm 1'), findsNothing);

      await tester.tap(find.byKey(const Key('release-notes-show-more')));
      await tester.pumpAndSettle();

      expect(
        find.byType(ReleaseNoteCard),
        findsNWidgets(kReleaseNotesInitialCount + 3),
      );
      expect(find.byKey(const Key('release-notes-show-more')), findsNothing);
    });
  });
}

const _twoChannelAsset = '''
{
  "releases": [
    {"versionName": "1.0.44-beta.2", "buildNumber": 4402, "channel": "beta",
     "date": "2026-07-20", "title": "Beta deneme", "highlights": [], "fixes": [],
     "notes": []},
    {"versionName": "1.0.44", "buildNumber": 44, "channel": "stable",
     "date": "2026-07-21", "title": "Kararlı sürüm", "highlights": [],
     "fixes": [], "notes": []}
  ]
}
''';
