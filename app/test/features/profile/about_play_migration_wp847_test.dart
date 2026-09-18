import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/config/app_build_manifest.dart';
import 'package:online_study_room/core/config/distribution_channel.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/features/profile/about_screen.dart';
import 'package:online_study_room/features/updater/play_migration.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WP-847: diyalog kapatıldıktan sonra da Play'e geçiş bilgisi Ayarlar →
/// Hakkında ve güncellemeler ekranında kalıcı satır olarak ulaşılabilir kalır.
void main() {
  AppBuildManifest manifestFor(AppReleaseChannel channel) => AppBuildManifest(
    channel: channel,
    environment: switch (channel) {
      AppReleaseChannel.stable => AppEnvironment.production,
      AppReleaseChannel.beta => AppEnvironment.staging,
      AppReleaseChannel.local => AppEnvironment.local,
    },
    gitCommitSha: 'abcdef1234567890',
    migrationHead: '0143',
    versionName: '1.0.86',
    buildNumber: 86,
    backendProjectRef: 'bbbbbbbbbbbbbbbbbbbb',
    usesSupabase: true,
    flutterFlavor: 'stable',
  );

  Future<void> pumpAbout(
    WidgetTester tester, {
    required DistributionChannel channel,
    required AppReleaseChannel release,
    ExternalUrlOpener? opener,
  }) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues({
      // Diyalog daha önce gösterildi ve kapatıldı.
      PlayMigration.dialogShownKey: true,
    });
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AboutScreen(
            buildManifest: manifestFor(release),
            distributionChannel: channel,
            playStoreOpener: opener,
            releaseNotesChannel: 'stable',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('githubStable: kalıcı satır görünür, Play adresini açar', (
    tester,
  ) async {
    final opened = <Uri>[];
    await pumpAbout(
      tester,
      channel: DistributionChannel.githubStable,
      release: AppReleaseChannel.stable,
      opener: (uri) async {
        opened.add(uri);
        return true;
      },
    );

    expect(find.byKey(const Key('play-migration-tile')), findsOneWidget);
    expect(find.text("Google Play'e geç"), findsOneWidget);

    await tester.tap(find.byKey(const Key('play-migration-tile')));
    await tester.pumpAndSettle();
    expect(opened, [Uri.parse(PlayMigration.listingUrl)]);

    // GitHub denetimi de kapalı: stable APK'ya giden yol yok.
    final check = tester.widget<ListTile>(
      find.byKey(const Key('about-check-for-updates')),
    );
    expect(check.onTap, isNull);
    expect(find.text('Güncelleme mağaza üzerinden yönetilir.'), findsOneWidget);
  });

  for (final (channel, release) in [
    (DistributionChannel.play, AppReleaseChannel.stable),
    (DistributionChannel.githubBeta, AppReleaseChannel.beta),
    (DistributionChannel.windows, AppReleaseChannel.stable),
    (DistributionChannel.microsoftStore, AppReleaseChannel.stable),
    (DistributionChannel.githubStable, AppReleaseChannel.local),
  ]) {
    testWidgets('$channel/$release: satır görünmez', (tester) async {
      await pumpAbout(tester, channel: channel, release: release);
      expect(find.byKey(const Key('play-migration-tile')), findsNothing);
    });
  }
}
