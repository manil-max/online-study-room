import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/config/distribution_channel.dart';
import 'package:online_study_room/features/updater/updater_service.dart';

/// WP-110 Play fail-closed: checkForUpdate sideload kapalıyken ağ çağrısı yapmaz.
///
/// Bu dosyayı Play define ile çalıştır:
/// ```
/// flutter test test/features/updater/updater_play_channel_test.dart \
///   --dart-define=DISTRIBUTION_CHANNEL=play
/// ```
/// Define yoksa test skip edilir (varsayılan githubStable CI'yi bozmaz).
void main() {
  test('Play kanalinda checkForUpdate null ve Dio cagrilmaz', () async {
    if (DistributionConfig.current != DistributionChannel.play) {
      // ignore: avoid_print
      print(
        'SKIP: DISTRIBUTION_CHANNEL=play degil '
        '(current=${DistributionConfig.current.name}). '
        'Play izolasyonu icin: --dart-define=DISTRIBUTION_CHANNEL=play',
      );
      return;
    }

    expect(DistributionConfig.allowsSideloadUpdates, isFalse);

    var networkHits = 0;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            networkHits++;
            handler.reject(
              DioException(
                requestOptions: options,
                error: 'Play kanalinda ag cagrisi olmamali',
              ),
            );
          },
        ),
      );

    final info = await UpdaterService(dio: dio).checkForUpdate();
    expect(info, isNull);
    expect(networkHits, 0, reason: 'Play build GitHub Releases cagirmamali');
  });
}
