import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// WP-773: GitHub Release govdesi surum notlarindan turetilir.
///
/// `generate_release_notes: true` commit listesinden yalniz "Full Changelog"
/// baglantisi uretiyordu; uygulama icindeki pencere govdeyi oldugu gibi
/// gosterdigi icin kullanici not yerine link goruyordu (sahip, cihazda, v77).
void main() {
  final workflow = File(
    '../.github/workflows/release.yml',
  ).readAsStringSync().replaceAll('\r\n', '\n');
  final generator = File(
    '../tooling/release/release_body.py',
  ).readAsStringSync();

  test('release govdesi otomatik commit listesi DEGIL, surum notlari', () {
    expect(workflow, isNot(contains('generate_release_notes: true')));
    expect(workflow, contains('generate_release_notes: false'));
    expect(
      workflow,
      contains('body_path: release-assets/android/release-body.md'),
    );
  });

  test('uretec artefakt uretiminden once kendi self-testini kosar', () {
    final generate = workflow.indexOf('release_body.py --notes');
    final selfTest = workflow.indexOf('release_body.py --self-test');
    final upload = workflow.indexOf('name: android-release');
    expect(selfTest, greaterThan(-1));
    expect(selfTest, lessThan(generate));
    expect(generate, lessThan(upload), reason: 'govde artefaktla tasinir');
    expect(
      workflow,
      contains('--out build/app/outputs/flutter-apk/release-body.md'),
    );
  });

  test('uretec tek kaynaktan okur ve bos girdiyi hata sayar', () {
    expect(generator, contains('release_notes.json'));
    expect(generator, contains('def self_test'));
    expect(generator, contains('raise ValueError'));
    expect(generator, contains('def fallback_body'));
  });
}
