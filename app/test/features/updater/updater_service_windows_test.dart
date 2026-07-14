import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/updater/updater_service.dart';

void main() {
  group('UpdaterService version parse', () {
    test('vN and beta-vN and +N', () {
      expect(UpdaterService.parseVersionCodeForTest('v8'), 8);
      expect(UpdaterService.parseVersionCodeForTest('beta-v12'), 12);
      expect(UpdaterService.parseVersionCodeForTest('1.0.18+8'), 8);
      expect(UpdaterService.parseVersionCodeForTest(null), isNull);
    });
  });

  group('UpdatePackageKind', () {
    test('default apk for backward compatibility', () {
      const info = UpdateInfo(
        versionCode: 1,
        versionName: 't',
        releaseNotes: '',
        downloadUrl: 'https://example.com/a.apk',
      );
      expect(info.packageKind, UpdatePackageKind.apk);
    });

    test('msix copyWith preserves kind', () {
      const info = UpdateInfo(
        versionCode: 2,
        versionName: 't',
        releaseNotes: '',
        downloadUrl: 'https://example.com/a.msix',
        packageKind: UpdatePackageKind.msix,
      );
      expect(info.copyWith(versionName: 'x').packageKind, UpdatePackageKind.msix);
    });
  });
}
