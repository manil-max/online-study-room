import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/config/app_build_manifest.dart';
import 'package:online_study_room/core/config/distribution_channel.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/features/auth/google_sign_in_availability.dart';
import 'package:online_study_room/features/profile/about_screen.dart';
import 'package:online_study_room/features/updater/play_migration.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WP-846: Hakkında ekranındaki tek satır teşhis. Sahip "düğme yok" dediğinde
/// bu satırın ekran görüntüsü nedenini söylemeli: sürüm, kanal, sunucu,
/// Google girişi.
void main() {
  AppBuildManifest manifest({
    required AppReleaseChannel channel,
    required AppEnvironment environment,
    required String version,
    required int build,
  }) => AppBuildManifest(
    channel: channel,
    environment: environment,
    gitCommitSha: 'abcdef1234567890',
    migrationHead: '0143',
    versionName: version,
    buildNumber: build,
    backendProjectRef: 'bbbbbbbbbbbbbbbbbbbb',
    usesSupabase: true,
    flutterFlavor: null,
  );

  final stable = manifest(
    channel: AppReleaseChannel.stable,
    environment: AppEnvironment.production,
    version: '1.0.86',
    build: 86,
  );

  Future<String> pumpLine(
    WidgetTester tester, {
    required AppBuildManifest? build,
    required DistributionChannel channel,
    required bool google,
    Locale locale = const Locale('tr'),
  }) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues({
      PlayMigration.dialogShownKey: true,
    });
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          googleSignInEnabledProvider.overrideWithValue(google),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AboutScreen(
            buildManifest: build,
            distributionChannel: channel,
            releaseNotesChannel: 'stable',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final finder = find.byKey(const Key('about-diagnostic-line'));
    expect(finder, findsOneWidget);
    // Kopyalanabilir: `SelectionArea` içindeki `Text` (ek `Scrollable` yok).
    expect(
      find.ancestor(of: finder, matching: find.byType(SelectionArea)),
      findsOneWidget,
    );
    return tester.widget<Text>(finder).data!;
  }

  testWidgets('Play + canlı + Google açık', (tester) async {
    expect(
      await pumpLine(
        tester,
        build: stable,
        channel: DistributionChannel.play,
        google: true,
      ),
      'Sürüm 1.0.86 (86) · Play · Sunucu: canlı · Google girişi: açık',
    );
  });

  testWidgets('GitHub beta + test sunucusu + Google kapalı', (tester) async {
    expect(
      await pumpLine(
        tester,
        build: manifest(
          channel: AppReleaseChannel.beta,
          environment: AppEnvironment.staging,
          version: '1.0.86-beta.1',
          build: 8601,
        ),
        channel: DistributionChannel.githubBeta,
        google: false,
      ),
      'Sürüm 1.0.86-beta.1 (8601) · GitHub beta · Sunucu: test · '
      'Google girişi: kapalı',
    );
  });

  testWidgets('GitHub stable → "GitHub (eski)"', (tester) async {
    expect(
      await pumpLine(
        tester,
        build: stable,
        channel: DistributionChannel.githubStable,
        google: true,
      ),
      'Sürüm 1.0.86 (86) · GitHub (eski) · Sunucu: canlı · Google girişi: açık',
    );
  });

  testWidgets('Windows', (tester) async {
    expect(
      await pumpLine(
        tester,
        build: stable,
        channel: DistributionChannel.windows,
        google: false,
      ),
      'Sürüm 1.0.86 (86) · Windows · Sunucu: canlı · Google girişi: kapalı',
    );
  });

  testWidgets('yerel derleme → geliştirme + yerel sunucu', (tester) async {
    expect(
      await pumpLine(
        tester,
        build: manifest(
          channel: AppReleaseChannel.local,
          environment: AppEnvironment.local,
          version: '0.0.0-local',
          build: 0,
        ),
        // `local` flavor kanalı `play`a çözülür; yine de "geliştirme" yazmalı.
        channel: DistributionChannel.play,
        google: false,
      ),
      'Sürüm 0.0.0-local (0) · geliştirme · Sunucu: yerel · '
      'Google girişi: kapalı',
    );
  });

  testWidgets('manifest çözülemezse satır yine görünür, "bilinmiyor" der', (
    tester,
  ) async {
    expect(
      await pumpLine(
        tester,
        build: null,
        channel: DistributionChannel.githubStable,
        google: false,
      ),
      // Test ortamında env.json CHANNEL=local ise manifest yerel çözülür;
      // her iki durumda da kanal "geliştirme"dir.
      anyOf(
        'Sürüm bilinmiyor (bilinmiyor) · geliştirme · Sunucu: bilinmiyor · '
        'Google girişi: kapalı',
        startsWith('Sürüm 0.0.0-local (0) · geliştirme · Sunucu: yerel'),
      ),
    );
  });

  testWidgets('İngilizce', (tester) async {
    expect(
      await pumpLine(
        tester,
        build: stable,
        channel: DistributionChannel.play,
        google: true,
        locale: const Locale('en'),
      ),
      'Version 1.0.86 (86) · Play · Server: live · Google sign-in: on',
    );
  });
}
