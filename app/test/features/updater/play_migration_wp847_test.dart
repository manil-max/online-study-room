import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/config/app_build_manifest.dart';
import 'package:online_study_room/core/config/distribution_channel.dart';
import 'package:online_study_room/features/updater/play_migration.dart';
import 'package:online_study_room/features/updater/updater_service.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WP-847: GitHub stable kurulumu Play'e yönlendirilir; beta ve Windows
/// sideload aynen kalır.
void main() {
  group('PlayMigration.appliesTo — yalnız GitHub stable sürüm derlemesi', () {
    test('githubStable + stable manifest → görünür', () {
      expect(
        PlayMigration.appliesTo(
          channel: DistributionChannel.githubStable,
          releaseChannel: AppReleaseChannel.stable,
        ),
        isTrue,
      );
    });

    for (final channel in DistributionChannel.values.where(
      (c) => c != DistributionChannel.githubStable,
    )) {
      for (final release in [...AppReleaseChannel.values, null]) {
        test('$channel + $release → görünmez', () {
          expect(
            PlayMigration.appliesTo(channel: channel, releaseChannel: release),
            isFalse,
          );
        });
      }
    }

    test(
      'githubStable ama yerel/çözülmemiş manifest (geliştirme) → görünmez',
      () {
        for (final release in [
          AppReleaseChannel.local,
          AppReleaseChannel.beta,
          null,
        ]) {
          expect(
            PlayMigration.appliesTo(
              channel: DistributionChannel.githubStable,
              releaseChannel: release,
            ),
            isFalse,
          );
        }
      },
    );

    test('web ve Windows platformu → görünmez', () {
      expect(
        PlayMigration.appliesTo(
          channel: DistributionChannel.githubStable,
          releaseChannel: AppReleaseChannel.stable,
          isWeb: true,
        ),
        isFalse,
      );
      expect(
        PlayMigration.appliesTo(
          channel: DistributionChannel.githubStable,
          releaseChannel: AppReleaseChannel.stable,
          platform: TargetPlatform.windows,
        ),
        isFalse,
      );
    });

    test('Play bağlantısı doğru paketi hedefler', () {
      expect(
        PlayMigration.listingUrl,
        'https://play.google.com/store/apps/details?id=com.manilmax.online_study_room',
      );
    });
  });

  group('UpdaterService.offersSideloadPackage — kanal tablosu', () {
    test('githubStable stable APK artık önerilmez', () {
      expect(
        UpdaterService.offersSideloadPackage(
          channel: DistributionChannel.githubStable,
          isBeta: false,
        ),
        isFalse,
      );
    });

    test('githubBeta ve Windows (iki kanal) aynen açık', () {
      expect(
        UpdaterService.offersSideloadPackage(
          channel: DistributionChannel.githubBeta,
          isBeta: true,
        ),
        isTrue,
      );
      for (final beta in [true, false]) {
        expect(
          UpdaterService.offersSideloadPackage(
            channel: DistributionChannel.windows,
            isBeta: beta,
          ),
          isTrue,
        );
      }
    });

    test('mağaza kanalları kapalı kalır', () {
      for (final channel in [
        DistributionChannel.play,
        DistributionChannel.microsoftStore,
      ]) {
        for (final beta in [true, false]) {
          expect(
            UpdaterService.offersSideloadPackage(
              channel: channel,
              isBeta: beta,
            ),
            isFalse,
          );
        }
      }
    });
  });

  group('UpdaterService.checkForUpdateDetailed — gerçek akış, sahte ağ', () {
    setUp(() {
      PackageInfo.setMockInitialValues(
        appName: 'Odak Kampı',
        packageName: 'com.manilmax.online_study_room.beta',
        version: '1.0.86',
        buildNumber: '8600',
        buildSignature: '',
      );
    });

    test(
      'githubBeta: releases taranır, beta APK önerilir (WP-847 öncesiyle aynı)',
      () async {
        final adapter = _FakeGithubAdapter(
          jsonEncode([
            {
              'tag_name': 'v86',
              'prerelease': false,
              'assets': [
                {
                  'name': 'app-release.apk',
                  'browser_download_url': 'https://example.test/stable.apk',
                },
              ],
            },
            {
              'tag_name': 'beta-v8601',
              'name': 'beta-v8601',
              'prerelease': true,
              'body': '',
              'assets': [
                {
                  'name': 'app-beta-release.apk',
                  'browser_download_url': 'https://example.test/beta.apk',
                },
                {
                  'name': 'app-beta-release.apk.sha256',
                  'browser_download_url':
                      'https://example.test/beta.apk.sha256',
                },
              ],
            },
          ]),
        );
        final service = UpdaterService(
          dio: Dio()..httpClientAdapter = adapter,
          channelOverride: DistributionChannel.githubBeta,
          releaseChannelOverride: 'beta',
          isAndroidOverride: true,
        );

        final result = await service.checkForUpdateDetailed();

        expect(adapter.paths, ['/repos/manil-max/online-study-room/releases']);
        expect(result.outcome, UpdateCheckOutcome.updateAvailable);
        expect(result.info!.versionCode, 8601);
        expect(result.info!.downloadUrl, 'https://example.test/beta.apk');
        expect(result.info!.sha256Url, 'https://example.test/beta.apk.sha256');
        expect(result.info!.packageKind, UpdatePackageKind.apk);
      },
    );

    test('githubStable: ağ isteği YOK, stable APK önerilmez', () async {
      final adapter = _FakeGithubAdapter(
        jsonEncode({
          'tag_name': 'v99',
          'assets': [
            {
              'name': 'app-release.apk',
              'browser_download_url': 'https://example.test/stable.apk',
            },
          ],
        }),
      );
      final service = UpdaterService(
        dio: Dio()..httpClientAdapter = adapter,
        channelOverride: DistributionChannel.githubStable,
        releaseChannelOverride: 'stable',
        isAndroidOverride: true,
      );

      final result = await service.checkForUpdateDetailed();

      expect(adapter.paths, isEmpty);
      expect(result.outcome, UpdateCheckOutcome.managedByStore);
      expect(result.info, isNull);
    });
  });

  group('Geçiş diyaloğu — bir kez, engellemeden', () {
    Future<void> pumpHost(
      WidgetTester tester, {
      required SharedPreferences prefs,
      required bool applies,
      required ExternalUrlOpener opener,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => maybeShowPlayMigrationDialog(
                  context,
                  applies: applies,
                  preferences: prefs,
                  opener: opener,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('ilk açılışta görünür, kapatılınca bir daha gelmez', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await pumpHost(
        tester,
        prefs: prefs,
        applies: true,
        opener: (_) async => true,
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('play-migration-dialog')), findsOneWidget);
      expect(find.text("Odak Kampı artık Google Play'de"), findsOneWidget);
      expect(
        find.textContaining('Hesabın ve çalışma verilerin sunucuda duruyor'),
        findsOneWidget,
      );
      expect(prefs.getBool(PlayMigration.dialogShownKey), isTrue);

      await tester.tap(find.text('Sonra'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('play-migration-dialog')), findsNothing);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('play-migration-dialog')), findsNothing);
    });

    testWidgets('kanal uygun değilse hiç görünmez ve işaret yazılmaz', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await pumpHost(
        tester,
        prefs: prefs,
        applies: false,
        opener: (_) async => true,
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('play-migration-dialog')), findsNothing);
      expect(prefs.getBool(PlayMigration.dialogShownKey), isNull);
    });

    testWidgets('Play düğmesi doğru adresi açar ve diyaloğu kapatır', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final opened = <Uri>[];
      await pumpHost(
        tester,
        prefs: prefs,
        applies: true,
        opener: (uri) async {
          opened.add(uri);
          return true;
        },
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('play-migration-open-play')));
      await tester.pumpAndSettle();

      expect(opened, [Uri.parse(PlayMigration.listingUrl)]);
      expect(find.byKey(const Key('play-migration-dialog')), findsNothing);
    });

    testWidgets('Play açılamazsa bağlantı panoya kopyalanır ve söylenir', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpHost(
        tester,
        prefs: prefs,
        applies: true,
        opener: (_) async => false,
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('play-migration-open-play')));
      await tester.pumpAndSettle();

      expect(clipboard, PlayMigration.listingUrl);
      expect(
        find.text('Google Play açılamadı. Bağlantı panoya kopyalandı.'),
        findsOneWidget,
      );
    });
  });
}

/// GitHub API'sini taklit eder; hangi yolların istendiğini kaydeder.
class _FakeGithubAdapter implements HttpClientAdapter {
  _FakeGithubAdapter(this.body);

  final String body;
  final List<String> paths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.uri.path);
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
