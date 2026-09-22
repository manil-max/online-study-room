import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/config/app_build_manifest.dart';
import 'package:online_study_room/core/config/distribution_channel.dart';
import 'package:online_study_room/features/updater/play_migration.dart';
import 'package:online_study_room/features/updater/updater_service.dart';

/// WP-901: App Store kanalında GitHub updater ve Play geçiş uyarısı yoktur.
void main() {
  test('appStore: GitHub isteği atılmadan mağaza-yönetimli döner', () async {
    final result = await UpdaterService(
      channelOverride: DistributionChannel.appStore,
      releaseChannelOverride: 'beta',
      isAndroidOverride: false,
    ).checkForUpdateDetailed();
    expect(result.outcome, UpdateCheckOutcome.managedByStore);
    expect(result.info, isNull);
  });

  test('appStore hiçbir beta bilgisiyle paket önermez', () {
    for (final isBeta in [true, false]) {
      expect(
        UpdaterService.offersSideloadPackage(
          channel: DistributionChannel.appStore,
          isBeta: isBeta,
        ),
        isFalse,
      );
    }
  });

  test("Play geçiş uyarısı iOS'ta hiçbir kanalda görünmez", () {
    for (final channel in DistributionChannel.values) {
      expect(
        PlayMigration.appliesTo(
          channel: channel,
          releaseChannel: AppReleaseChannel.stable,
          platform: TargetPlatform.iOS,
        ),
        isFalse,
        reason: '$channel',
      );
    }
    // Android GitHub stable davranışı korunur.
    expect(
      PlayMigration.appliesTo(
        channel: DistributionChannel.githubStable,
        releaseChannel: AppReleaseChannel.stable,
        platform: TargetPlatform.android,
      ),
      isTrue,
    );
  });
}
