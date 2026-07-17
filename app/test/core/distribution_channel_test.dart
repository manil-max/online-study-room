import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/config/distribution_channel.dart';
import 'package:online_study_room/features/updater/updater_service.dart';

/// WP-110 / WP-128: Play kanalında sideload updater kapalı; GitHub kanalları açık.
///
/// Not: [DistributionConfig.current] derleme-zamanı define + FLUTTER_APP_FLAVOR okur.
/// Bu dosya varsayılan (define yok, flavor yok) = githubStable/windows varsayar.
/// Flavor zorlaması [DistributionConfig.resolve] ile birim test edilir.
void main() {
  group('DistributionConfig (default / no define)', () {
    test('varsayilan githubStable veya platform (windows)', () {
      final c = DistributionConfig.current;
      expect(
        c == DistributionChannel.githubStable ||
            c == DistributionChannel.windows ||
            c == DistributionChannel.githubBeta,
        isTrue,
      );
    });

    test('allowsSideloadUpdates default true (play degilse)', () {
      if (DistributionConfig.current == DistributionChannel.play) {
        expect(DistributionConfig.allowsSideloadUpdates, isFalse);
      } else {
        expect(DistributionConfig.allowsSideloadUpdates, isTrue);
      }
    });
  });

  group('WP-128 play flavor force (define yok)', () {
    test('flavor=play + bos define → play ve sideload kapali', () {
      final channel = DistributionConfig.resolve(
        distributionDefine: '',
        legacyChannel: 'stable',
        flutterAppFlavor: 'play',
        isWeb: false,
        platform: TargetPlatform.android,
      );
      expect(channel, DistributionChannel.play);
      expect(DistributionConfig.allowsSideloadUpdatesFor(channel), isFalse);
    });

    test('flavor=play buyuk/kucuk harf duyarsiz', () {
      final channel = DistributionConfig.resolve(
        distributionDefine: '',
        legacyChannel: 'stable',
        flutterAppFlavor: 'Play',
        isWeb: false,
        platform: TargetPlatform.android,
      );
      expect(channel, DistributionChannel.play);
      expect(DistributionConfig.allowsSideloadUpdatesFor(channel), isFalse);
    });

    test('yanlis githubStable define + flavor=play → yine play (sideload kapali)', () {
      final channel = DistributionConfig.resolve(
        distributionDefine: 'githubStable',
        legacyChannel: 'stable',
        flutterAppFlavor: 'play',
        isWeb: false,
        platform: TargetPlatform.android,
      );
      expect(channel, DistributionChannel.play);
      expect(DistributionConfig.allowsSideloadUpdatesFor(channel), isFalse);
    });

    test('flavor=stable define yok → githubStable (android)', () {
      final channel = DistributionConfig.resolve(
        distributionDefine: '',
        legacyChannel: 'stable',
        flutterAppFlavor: 'stable',
        isWeb: false,
        platform: TargetPlatform.android,
      );
      expect(channel, DistributionChannel.githubStable);
      expect(DistributionConfig.allowsSideloadUpdatesFor(channel), isTrue);
    });

    test('flavor=beta + legacy beta → githubBeta', () {
      final channel = DistributionConfig.resolve(
        distributionDefine: '',
        legacyChannel: 'beta',
        flutterAppFlavor: 'beta',
        isWeb: false,
        platform: TargetPlatform.android,
      );
      expect(channel, DistributionChannel.githubBeta);
      expect(DistributionConfig.allowsSideloadUpdatesFor(channel), isTrue);
    });
  });

  group('UpdaterService', () {
    test('parseVersionCode etiketlerden build numarasi cikarir', () {
      expect(UpdaterService.parseVersionCodeForTest('v29'), 29);
      expect(UpdaterService.parseVersionCodeForTest('beta-v29'), 29);
      expect(UpdaterService.parseVersionCodeForTest('1.0.29+29'), 29);
    });

    test('channel releaseNotesChannel ile hizali', () {
      expect(
        UpdaterService.channel,
        DistributionConfig.releaseNotesChannel,
      );
    });
  });
}
