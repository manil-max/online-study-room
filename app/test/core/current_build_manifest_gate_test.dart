import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/config/app_build_manifest.dart';

/// Android'de Gradle compileFlutterBuild* kapısı aynı sözleşmeyi ayrıca uygular.
/// Windows/web release akışı bu testi ENFORCE_CURRENT_BUILD_MANIFEST=true ile
/// build'den önce çalıştırır; yanlış env varsa artefakt üretilmez.
void main() {
  test('current release build manifest is valid', () {
    const enforce = bool.fromEnvironment(
      'ENFORCE_CURRENT_BUILD_MANIFEST',
      defaultValue: false,
    );
    if (!enforce) return;
    expect(() => AppBuildManifest.current, returnsNormally);
  });
}
