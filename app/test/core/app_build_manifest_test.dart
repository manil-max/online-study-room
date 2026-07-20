import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/config/app_build_manifest.dart';

const _stagingRef = 'aaaaaaaaaaaaaaaaaaaa';
const _productionRef = 'bbbbbbbbbbbbbbbbbbbb';
const _publishableKey = 'sb_publishable_test_key';

AppBuildManifest resolveManifest({
  String channel = 'beta',
  String environment = 'staging',
  String supabaseUrl = 'https://$_stagingRef.supabase.co',
  String supabaseAnonKey = _publishableKey,
  String selectedProjectRef = _stagingRef,
  String stagingProjectRef = _stagingRef,
  String productionProjectRef = _productionRef,
  String gitCommitSha = 'abcdef1234567890',
  String migrationHead = '0062',
  String versionName = '1.0.42-beta.1',
  int buildNumber = 4201,
  bool allowInMemory = false,
  String? flutterFlavor = 'beta',
}) {
  return AppBuildManifest.resolve(
    channel: channel,
    environment: environment,
    supabaseUrl: supabaseUrl,
    supabaseAnonKey: supabaseAnonKey,
    selectedProjectRef: selectedProjectRef,
    stagingProjectRef: stagingProjectRef,
    productionProjectRef: productionProjectRef,
    gitCommitSha: gitCommitSha,
    migrationHead: migrationHead,
    versionName: versionName,
    buildNumber: buildNumber,
    allowInMemory: allowInMemory,
    flutterFlavor: flutterFlavor,
  );
}

Matcher configurationError(String code) => isA<BuildConfigurationException>()
    .having((error) => error.code, 'code', code);

void main() {
  group('geçerli kanal/backend kimlikleri', () {
    test('beta yalnız staging ref ve URL ile açılır', () {
      final manifest = resolveManifest();
      expect(manifest.channel, AppReleaseChannel.beta);
      expect(manifest.environment, AppEnvironment.staging);
      expect(manifest.backendProjectRef, _stagingRef);
      expect(manifest.usesSupabase, isTrue);
    });

    test('stable yalnız production ref ve URL ile açılır', () {
      final manifest = resolveManifest(
        channel: 'stable',
        environment: 'production',
        supabaseUrl: 'https://$_productionRef.supabase.co',
        selectedProjectRef: _productionRef,
        flutterFlavor: 'stable',
        versionName: '1.0.42',
        buildNumber: 42,
      );
      expect(manifest.channel, AppReleaseChannel.stable);
      expect(manifest.environment, AppEnvironment.production);
      expect(manifest.backendProjectRef, _productionRef);
    });

    test('play flavor stable/production kimliği kullanır', () {
      final manifest = resolveManifest(
        channel: 'stable',
        environment: 'production',
        supabaseUrl: 'https://$_productionRef.supabase.co',
        selectedProjectRef: _productionRef,
        flutterFlavor: 'play',
        versionName: '1.0.42',
        buildNumber: 42,
      );
      expect(manifest.environment, AppEnvironment.production);
    });

    test('local açık izinle InMemory çalışabilir', () {
      final manifest = resolveManifest(
        channel: 'local',
        environment: 'local',
        supabaseUrl: '',
        supabaseAnonKey: '',
        selectedProjectRef: '',
        stagingProjectRef: '',
        productionProjectRef: '',
        gitCommitSha: 'local-dev',
        migrationHead: '0063',
        versionName: '0.0.0-local',
        buildNumber: 0,
        allowInMemory: true,
        flutterFlavor: 'local',
      );
      expect(manifest.usesSupabase, isFalse);
      expect(manifest.backendProjectRef, 'in-memory');
    });
  });

  group('fail-closed negatif matris', () {
    test('beta production environment ile açılamaz', () {
      expect(
        () => resolveManifest(environment: 'production'),
        throwsA(configurationError('flavor_identity_mismatch')),
      );
    });

    test('beta production ref seçemez', () {
      expect(
        () => resolveManifest(
          supabaseUrl: 'https://$_productionRef.supabase.co',
          selectedProjectRef: _productionRef,
        ),
        throwsA(configurationError('backend_ref_mismatch')),
      );
    });

    test('stable staging ref seçemez', () {
      expect(
        () => resolveManifest(
          channel: 'stable',
          environment: 'production',
          flutterFlavor: 'stable',
          versionName: '1.0.42',
          buildNumber: 42,
        ),
        throwsA(configurationError('backend_ref_mismatch')),
      );
    });

    test('seçili ref ile URL hostu birebir eşleşmelidir', () {
      expect(
        () => resolveManifest(
          supabaseUrl: 'https://$_stagingRef.supabase.co/rest/v1',
        ),
        throwsA(configurationError('backend_url_mismatch')),
      );
    });

    test('staging ve production aynı ref olamaz', () {
      expect(
        () => resolveManifest(productionProjectRef: _stagingRef),
        throwsA(configurationError('invalid_environment_refs')),
      );
    });

    test('release Supabase ayarları olmadan InMemoryye düşmez', () {
      expect(
        () => resolveManifest(
          supabaseUrl: '',
          supabaseAnonKey: '',
          selectedProjectRef: '',
          allowInMemory: true,
        ),
        throwsA(configurationError('supabase_required')),
      );
    });

    test('service-role/secret key istemci buildinde reddedilir', () {
      expect(
        () => resolveManifest(supabaseAnonKey: 'sb_secret_never_ship_this'),
        throwsA(configurationError('unsafe_supabase_key')),
      );
    });

    test('release commit ve migration head placeholder kabul etmez', () {
      expect(
        () => resolveManifest(gitCommitSha: 'REPLACE_WITH_GIT_SHA'),
        throwsA(configurationError('invalid_git_commit')),
      );
      expect(
        () => resolveManifest(migrationHead: '63'),
        throwsA(configurationError('invalid_migration_head')),
      );
    });

    test('beta ve stable sürüm/build kimliği birbirine karışamaz', () {
      expect(
        () => resolveManifest(versionName: '1.0.42', buildNumber: 42),
        throwsA(configurationError('invalid_version_build')),
      );
      expect(
        () => resolveManifest(
          channel: 'stable',
          environment: 'production',
          supabaseUrl: 'https://$_productionRef.supabase.co',
          selectedProjectRef: _productionRef,
          flutterFlavor: 'stable',
          versionName: '1.0.42-beta.1',
          buildNumber: 4201,
        ),
        throwsA(configurationError('invalid_version_build')),
      );
    });
  });
}
