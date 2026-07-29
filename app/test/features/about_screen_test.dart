import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/config/app_build_manifest.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/features/profile/about_screen.dart';
import 'package:online_study_room/features/profile/legal_center_screen.dart';
import 'package:online_study_room/features/support/faq_screen.dart';
import 'package:online_study_room/features/updater/release_notes_screen.dart';
import 'package:online_study_room/features/updater/release_notes_service.dart';
import 'package:online_study_room/features/updater/updater_dialog.dart';
import 'package:online_study_room/features/updater/updater_service.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/core/config/build_identity_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WP-419: "Build diagnostics" kartı sürüm notlarından **silinmedi**, buraya
/// taşındı. Destekte "sürümün ne?" cevaplanabilir kalmalı; ama kanal / backend
/// project-ref / commit / migration başı ilk bakışta görünmemeli.
void main() {
  final manifest = AppBuildManifest.resolve(
    channel: 'beta',
    environment: 'staging',
    supabaseUrl: 'https://aaaaaaaaaaaaaaaaaaaa.supabase.co',
    supabaseAnonKey: 'sb_publishable_test_key',
    selectedProjectRef: 'aaaaaaaaaaaaaaaaaaaa',
    stagingProjectRef: 'aaaaaaaaaaaaaaaaaaaa',
    productionProjectRef: 'bbbbbbbbbbbbbbbbbbbb',
    gitCommitSha: 'abcdef1234567890',
    migrationHead: '0094',
    versionName: '1.0.44-beta.1',
    buildNumber: 4401,
    allowInMemory: false,
    flutterFlavor: 'beta',
  );

  Future<void> pumpAbout(
    WidgetTester tester, {
    AppBuildManifest? build,
    Future<UpdateCheckResult> Function()? updateCheck,
    bool allowsSideloadUpdates = true,
    ReleaseNotesService? releaseNotesService,
  }) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AboutScreen(
            buildManifest: build ?? manifest,
            updateCheck: updateCheck,
            allowsSideloadUpdates: allowsSideloadUpdates,
            releaseNotesService: releaseNotesService,
            releaseNotesChannel: 'stable',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('varsayılan olarak yalnız sürüm adı görünür', (tester) async {
    await pumpAbout(tester);

    expect(find.text('Hakkında ve güncellemeler'), findsNWidgets(2));
    expect(find.text('1.0.44-beta.1'), findsOneWidget);

    // Teknik satırlar kapalı.
    expect(find.text('abcdef12'), findsNothing);
    expect(find.text('0094'), findsNothing);
    expect(find.text('staging · aaaaaa…aaaa'), findsNothing);
    expect(find.text('Backend'), findsNothing);
    expect(find.text('Commit'), findsNothing);
    expect(find.text('Migration başı'), findsNothing);
  });

  testWidgets('sürüme dokununca teknik kimlik açılır ve tekrar kapanır', (
    tester,
  ) async {
    await pumpAbout(tester);

    await tester.tap(find.byKey(const Key('build-identity-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('Commit'), findsOneWidget);
    expect(find.text('abcdef12'), findsOneWidget);
    expect(find.text('Migration başı'), findsOneWidget);
    expect(find.text('0094'), findsOneWidget);
    expect(find.text('Backend'), findsOneWidget);
    expect(find.text('staging · aaaaaa…aaaa'), findsOneWidget);
    expect(find.text('1.0.44-beta.1+4401'), findsOneWidget);

    await tester.tap(find.byKey(const Key('build-identity-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('abcdef12'), findsNothing);
  });

  testWidgets('kimlik çözülemeyen derlemede boş kalmaz', (tester) async {
    // 🔴 Bu test eskiden `AboutScreen()` kuruyor ve "test derlemesinde
    // dart-define yoktur" varsayıyordu. Varsayım yerelde doğru, CI'da yanlış:
    // CI `flutter test --dart-define-from-file=env.json` ile koşar, ekran
    // `buildManifest ?? AppBuildManifest.currentOrNull` kullandığı için kimlik
    // çözülür ve yedek metin hiç basılmaz. v56 sürüm derlemesi tam buradan
    // düştü. Yedek metni üreten sözleşme `BuildIdentityCard`'ın kendisinde
    // olduğu için doğrudan ona bakılır — ortamdan bağımsız.
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: BuildIdentityCard(manifest: null)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Kanal/backend kimliği bu test derlemesinde tanımlı değil.'),
      findsOneWidget,
    );
  });

  testWidgets('sürüm, güncelleme, notlar ve destek tek hiyerarşidedir', (
    tester,
  ) async {
    await pumpAbout(tester);

    expect(find.text('Odak Kampı'), findsOneWidget);
    expect(find.byKey(const Key('about-check-for-updates')), findsOneWidget);
    expect(find.byKey(const Key('about-release-notes')), findsOneWidget);
    expect(find.byKey(const Key('about-faq')), findsOneWidget);
    expect(find.byKey(const Key('about-legal')), findsOneWidget);
    expect(find.text('Güncellemeleri denetle'), findsOneWidget);
    expect(find.text('Güncelleme notları'), findsOneWidget);
    expect(find.text('Sık sorulan sorular'), findsOneWidget);
    expect(find.text('Gizlilik ve yasal'), findsOneWidget);
  });

  testWidgets('manuel denetim güncel ve hata durumlarını ayırır', (
    tester,
  ) async {
    var checkCount = 0;
    await pumpAbout(
      tester,
      updateCheck: () async {
        checkCount++;
        return checkCount == 1
            ? const UpdateCheckResult.failed()
            : const UpdateCheckResult.upToDate();
      },
    );

    final checkTile = find.byKey(const Key('about-check-for-updates'));
    await tester.tap(checkTile);
    await tester.pump();
    expect(
      find.text(
        'Güncelleme denetlenemedi. İnternet bağlantını kontrol edip tekrar dene.',
      ),
      findsOneWidget,
    );

    await tester.tap(checkTile);
    await tester.pump();
    expect(find.text('Uygulaman güncel.'), findsOneWidget);
    expect(checkCount, 2);
  });

  testWidgets('yeni sürüm bulununca güvenli updater penceresi açılır', (
    tester,
  ) async {
    await pumpAbout(
      tester,
      updateCheck: () async => const UpdateCheckResult.updateAvailable(
        UpdateInfo(
          versionCode: 57,
          versionName: '1.0.57',
          releaseNotes: 'Test notu',
          downloadUrl: 'https://example.com/app.apk',
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('about-check-for-updates')));
    await tester.pumpAndSettle();

    expect(find.byType(UpdaterDialog), findsOneWidget);
    expect(find.text('Güncelleme var: 1.0.57'), findsOneWidget);
  });

  testWidgets('Play/Store kanalında self-update denetimi açılmaz', (
    tester,
  ) async {
    var called = false;
    await pumpAbout(
      tester,
      allowsSideloadUpdates: false,
      updateCheck: () async {
        called = true;
        return const UpdateCheckResult.upToDate();
      },
    );

    expect(find.text('Güncelleme mağaza üzerinden yönetilir.'), findsOneWidget);
    final tile = tester.widget<ListTile>(
      find.byKey(const Key('about-check-for-updates')),
    );
    expect(tile.onTap, isNull);
    expect(called, isFalse);
  });

  testWidgets('sürüm notları, SSS ve yasal bağlantılar gerçek ekranları açar', (
    tester,
  ) async {
    final releaseNotesService = ReleaseNotesService(
      assetLoader: (_) async => '''
{"releases":[{"versionName":"1.0.57","buildNumber":57,"channel":"stable",
"date":"2026-07-30","title":"Birleşik ekran","highlights":[],"fixes":[],"notes":[]}]}
''',
    );
    await pumpAbout(tester, releaseNotesService: releaseNotesService);

    await tester.tap(find.byKey(const Key('about-release-notes')));
    await tester.pumpAndSettle();
    expect(find.byType(ReleaseNotesScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(ReleaseNotesScreen))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('about-faq')));
    await tester.pumpAndSettle();
    expect(find.byType(FaqScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(FaqScreen))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('about-legal')));
    await tester.pumpAndSettle();
    expect(find.byType(LegalCenterScreen), findsOneWidget);
  });
}
