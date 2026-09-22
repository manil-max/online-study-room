// WP-907 — Hakkında: App Store kanal etiketi `.arb`'dan gelir; gizli
// geliştirici bölümünün Android'e özgü satırları iOS'ta çizilmez.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/config/app_build_manifest.dart';
import 'package:online_study_room/core/config/distribution_channel.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/features/profile/about_screen.dart';
import 'package:online_study_room/features/profile/developer_mode.dart';
import 'package:online_study_room/features/updater/updater_service.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/l10n/app_localizations_en.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _manifest = AppBuildManifest(
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

const _androidDevRows = [
  'developer-live-update-panel',
  'developer-panel-choice',
  'developer-promotion-verdict',
  'developer-overlay-enabled',
  'developer-overlay-permission',
];

Future<void> _pumpAbout(
  WidgetTester tester, {
  required DistributionChannel channel,
  Locale locale = const Locale('tr'),
  bool developerMode = false,
}) async {
  tester.view.physicalSize = const Size(1080, 9000);
  tester.view.devicePixelRatio = 3;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
  );
  addTearDown(container.dispose);
  if (developerMode) {
    await container.read(developerModeProvider.notifier).setEnabled(true);
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AboutScreen(
          buildManifest: _manifest,
          distributionChannel: channel,
          releaseNotesChannel: 'stable',
          updateCheck: () async => const UpdateCheckResult.upToDate(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _diagLine(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('about-diagnostic-line'))).data!;

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  testWidgets('App Store tanı etiketi yerelleştirilmiş anahtardan gelir', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await _pumpAbout(tester, channel: DistributionChannel.appStore);
    expect(
      _diagLine(tester),
      contains(AppLocalizationsTr().aboutDiagChannelAppStore),
    );
    expect(AppLocalizationsTr().aboutDiagChannelAppStore, 'App Store');

    await _pumpAbout(
      tester,
      channel: DistributionChannel.appStore,
      locale: const Locale('en'),
    );
    expect(
      _diagLine(tester),
      contains(AppLocalizationsEn().aboutDiagChannelAppStore),
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('iOS: geliştirici bölümünde Android satırları yok', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await _pumpAbout(
      tester,
      channel: DistributionChannel.appStore,
      developerMode: true,
    );
    expect(find.byKey(const ValueKey('timer-journal-entry')), findsOneWidget);
    expect(find.byKey(const Key('developer-mode-disable')), findsOneWidget);
    for (final key in _androidDevRows) {
      expect(find.byKey(Key(key)), findsNothing, reason: key);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Android: geliştirici bölümü değişmedi', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await _pumpAbout(
      tester,
      channel: DistributionChannel.githubBeta,
      developerMode: true,
    );
    for (final key in _androidDevRows) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    }
    debugDefaultTargetPlatformOverride = null;
  });
}
