import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/config/app_build_manifest.dart';
import 'package:online_study_room/features/profile/about_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

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

  Future<void> pumpAbout(WidgetTester tester, {AppBuildManifest? build}) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AboutScreen(buildManifest: build ?? manifest),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('varsayılan olarak yalnız sürüm adı görünür', (tester) async {
    await pumpAbout(tester);

    expect(find.text('Hakkında'), findsOneWidget);
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
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AboutScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Test derlemesinde dart-define yok → manifest null; ekran yine de bir şey
    // söyler, sessizce boş kalmaz.
    expect(
      find.text('Kanal/backend kimliği bu test derlemesinde tanımlı değil.'),
      findsOneWidget,
    );
  });
}
