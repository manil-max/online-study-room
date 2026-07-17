import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/config/distribution_channel.dart';
import 'package:online_study_room/features/updater/updater_service.dart';

/// WP-110: Play kanalında sideload updater kapalı; GitHub kanalları açık.
///
/// Not: [DistributionConfig.current] derleme-zamanı define okur. Bu test dosyası
/// varsayılan (define yok) = githubStable varsayar. Play izolasyonu için ayrı
/// koşu: `--dart-define=DISTRIBUTION_CHANNEL=play`.
void main() {
  group('DistributionConfig (default / no define)', () {
    test('varsayilan githubStable veya platform (windows)', () {
      // CI/desktop: genelde githubStable; Windows host'ta windows olabilir.
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
