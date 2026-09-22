import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/config/app_build_manifest.dart';
import 'package:online_study_room/core/config/distribution_channel.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/features/profile/about_screen.dart';
import 'package:online_study_room/features/updater/updater_service.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WP-901: App Store (iOS) derlemesinde Hakkında ekranı updater satırını ve
/// Play geçiş satırını hiç çizmez; sürüm notları kalır.
void main() {
  const manifest = AppBuildManifest(
    channel: AppReleaseChannel.stable,
    environment: AppEnvironment.production,
    gitCommitSha: 'abcdef1234567890',
    migrationHead: '0143',
    versionName: '1.0.88',
    buildNumber: 88,
    backendProjectRef: 'bbbbbbbbbbbbbbbbbbbb',
    usesSupabase: true,
    flutterFlavor: null,
  );

  Future<int> pumpAbout(
    WidgetTester tester, {
    required DistributionChannel channel,
  }) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    var checks = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AboutScreen(
            buildManifest: manifest,
            distributionChannel: channel,
            releaseNotesChannel: 'stable',
            updateCheck: () async {
              checks++;
              return const UpdateCheckResult.upToDate();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return checks;
  }

  testWidgets('iOS/appStore: updater ve Play geçiş satırı yok', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final checks = await pumpAbout(
      tester,
      channel: DistributionChannel.appStore,
    );

    expect(find.byKey(const Key('about-check-for-updates')), findsNothing);
    expect(find.byKey(const Key('play-migration-tile')), findsNothing);
    expect(find.byKey(const Key('about-release-notes')), findsOneWidget);
    expect(checks, 0);

    final line = tester.widget<Text>(
      find.byKey(const Key('about-diagnostic-line')),
    );
    expect(line.data, contains('App Store'));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('githubBeta (Android) updater satırını korur', (tester) async {
    await pumpAbout(tester, channel: DistributionChannel.githubBeta);
    expect(find.byKey(const Key('about-check-for-updates')), findsOneWidget);
  });
}
