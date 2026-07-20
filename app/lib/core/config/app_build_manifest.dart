import 'dart:convert';

import 'package:flutter/services.dart' show appFlavor;

import 'supabase_config.dart';

enum AppEnvironment { local, staging, production }

enum AppReleaseChannel { local, beta, stable }

/// Derlenen artefaktın kanal/backend kimliği.
///
/// Bu sözleşme beta/stable etiketinden bağımsız olarak gerçek backend hedefini
/// doğrular. Uyuşmazlıkta [BuildConfigurationException] üretilir ve uygulama
/// Supabase başlatmadan kapanır (fail-closed).
class AppBuildManifest {
  const AppBuildManifest({
    required this.channel,
    required this.environment,
    required this.gitCommitSha,
    required this.migrationHead,
    required this.versionName,
    required this.buildNumber,
    required this.backendProjectRef,
    required this.usesSupabase,
    required this.flutterFlavor,
  });

  static const String _channelDefine = String.fromEnvironment(
    'CHANNEL',
    defaultValue: '',
  );
  static const String _environmentDefine = String.fromEnvironment(
    'APP_ENVIRONMENT',
    defaultValue: '',
  );
  static const String _selectedProjectRef = String.fromEnvironment(
    'SUPABASE_PROJECT_REF',
    defaultValue: '',
  );
  static const String _stagingProjectRef = String.fromEnvironment(
    'STAGING_SUPABASE_PROJECT_REF',
    defaultValue: '',
  );
  static const String _productionProjectRef = String.fromEnvironment(
    'PRODUCTION_SUPABASE_PROJECT_REF',
    defaultValue: '',
  );
  static const String _gitCommitSha = String.fromEnvironment(
    'GIT_COMMIT_SHA',
    defaultValue: '',
  );
  static const String _migrationHead = String.fromEnvironment(
    'MIGRATION_HEAD',
    defaultValue: '',
  );
  static const String _versionName = String.fromEnvironment(
    'APP_VERSION_NAME',
    defaultValue: '0.0.0-local',
  );
  static const int _buildNumber = int.fromEnvironment(
    'APP_BUILD_NUMBER',
    defaultValue: 0,
  );
  static const bool _allowInMemory = bool.fromEnvironment(
    'ALLOW_IN_MEMORY',
    defaultValue: false,
  );

  final AppReleaseChannel channel;
  final AppEnvironment environment;
  final String gitCommitSha;
  final String migrationHead;
  final String versionName;
  final int buildNumber;
  final String backendProjectRef;
  final bool usesSupabase;
  final String? flutterFlavor;

  String get channelName => channel.name;
  String get environmentName => environment.name;
  String get shortCommit =>
      gitCommitSha.length <= 8 ? gitCommitSha : gitCommitSha.substring(0, 8);

  String get redactedBackendRef {
    if (backendProjectRef == 'in-memory' || backendProjectRef == 'local') {
      return backendProjectRef;
    }
    if (backendProjectRef.length <= 10) return backendProjectRef;
    return '${backendProjectRef.substring(0, 6)}…'
        '${backendProjectRef.substring(backendProjectRef.length - 4)}';
  }

  /// Uygulama başlangıcındaki tek otorite. Geçersiz yapılandırma Supabase veya
  /// Android arka plan servisleri başlatılmadan reddedilir.
  static AppBuildManifest get current => resolve(
    channel: _channelDefine,
    environment: _environmentDefine,
    supabaseUrl: SupabaseConfig.url,
    supabaseAnonKey: SupabaseConfig.anonKey,
    selectedProjectRef: _selectedProjectRef,
    stagingProjectRef: _stagingProjectRef,
    productionProjectRef: _productionProjectRef,
    gitCommitSha: _gitCommitSha,
    migrationHead: _migrationHead,
    versionName: _versionName,
    buildNumber: _buildNumber,
    allowInMemory: _allowInMemory,
    flutterFlavor: appFlavor,
  );

  /// Tanı yüzeyi ve widget testleri için güvenli okuma. Başlangıç kapısı
  /// [current] kullanır; bu yardımcı geçersiz config'i kabul etmez.
  static AppBuildManifest? get currentOrNull {
    try {
      return current;
    } on BuildConfigurationException {
      return null;
    }
  }

  /// Saf çözümleyici; bütün kanal/backend negatif senaryoları birim testlenir.
  static AppBuildManifest resolve({
    required String channel,
    required String environment,
    required String supabaseUrl,
    required String supabaseAnonKey,
    required String selectedProjectRef,
    required String stagingProjectRef,
    required String productionProjectRef,
    required String gitCommitSha,
    required String migrationHead,
    required String versionName,
    required int buildNumber,
    required bool allowInMemory,
    String? flutterFlavor,
  }) {
    final normalizedFlavor = _normalize(flutterFlavor);
    final parsedChannel = _parseChannel(channel);
    final parsedEnvironment = _parseEnvironment(environment);

    _validateFlavorPair(
      flavor: normalizedFlavor,
      channel: parsedChannel,
      environment: parsedEnvironment,
    );

    final expectedEnvironment = switch (parsedChannel) {
      AppReleaseChannel.local => AppEnvironment.local,
      AppReleaseChannel.beta => AppEnvironment.staging,
      AppReleaseChannel.stable => AppEnvironment.production,
    };
    if (parsedEnvironment != expectedEnvironment) {
      throw const BuildConfigurationException('channel_environment_mismatch');
    }

    final normalizedCommit = gitCommitSha.trim().toLowerCase();
    final normalizedHead = migrationHead.trim();
    if (!_isValidCommit(normalizedCommit, parsedChannel)) {
      throw const BuildConfigurationException('invalid_git_commit');
    }
    if (!RegExp(r'^\d{4}$').hasMatch(normalizedHead)) {
      throw const BuildConfigurationException('invalid_migration_head');
    }
    final normalizedVersion = versionName.trim().toLowerCase();
    if (!_isValidVersionBuild(normalizedVersion, buildNumber, parsedChannel)) {
      throw const BuildConfigurationException('invalid_version_build');
    }

    final url = supabaseUrl.trim();
    final anonKey = supabaseAnonKey.trim();
    final hasUrl = url.isNotEmpty;
    final hasKey = anonKey.isNotEmpty;
    if (hasUrl != hasKey) {
      throw const BuildConfigurationException('partial_supabase_credentials');
    }
    if (!hasUrl) {
      if (parsedEnvironment != AppEnvironment.local || !allowInMemory) {
        throw const BuildConfigurationException('supabase_required');
      }
      return AppBuildManifest(
        channel: parsedChannel,
        environment: parsedEnvironment,
        gitCommitSha: normalizedCommit,
        migrationHead: normalizedHead,
        versionName: normalizedVersion,
        buildNumber: buildNumber,
        backendProjectRef: 'in-memory',
        usesSupabase: false,
        flutterFlavor: normalizedFlavor,
      );
    }
    if (!_isClientSafeKey(anonKey)) {
      throw const BuildConfigurationException('unsafe_supabase_key');
    }

    final selectedRef = selectedProjectRef.trim().toLowerCase();
    if (parsedEnvironment == AppEnvironment.local) {
      if (!_isLocalSupabaseUrl(url) || selectedRef != 'local') {
        throw const BuildConfigurationException('invalid_local_backend');
      }
    } else {
      final stagingRef = stagingProjectRef.trim().toLowerCase();
      final productionRef = productionProjectRef.trim().toLowerCase();
      if (!_isHostedProjectRef(stagingRef) ||
          !_isHostedProjectRef(productionRef) ||
          stagingRef == productionRef) {
        throw const BuildConfigurationException('invalid_environment_refs');
      }
      final expectedRef = parsedEnvironment == AppEnvironment.staging
          ? stagingRef
          : productionRef;
      final forbiddenRef = parsedEnvironment == AppEnvironment.staging
          ? productionRef
          : stagingRef;
      if (selectedRef != expectedRef || selectedRef == forbiddenRef) {
        throw const BuildConfigurationException('backend_ref_mismatch');
      }
      if (!_hostedUrlMatchesRef(url, selectedRef)) {
        throw const BuildConfigurationException('backend_url_mismatch');
      }
    }

    return AppBuildManifest(
      channel: parsedChannel,
      environment: parsedEnvironment,
      gitCommitSha: normalizedCommit,
      migrationHead: normalizedHead,
      versionName: normalizedVersion,
      buildNumber: buildNumber,
      backendProjectRef: selectedRef,
      usesSupabase: true,
      flutterFlavor: normalizedFlavor,
    );
  }

  static AppReleaseChannel _parseChannel(String raw) {
    return switch (raw.trim().toLowerCase()) {
      'local' => AppReleaseChannel.local,
      'beta' => AppReleaseChannel.beta,
      'stable' => AppReleaseChannel.stable,
      _ => throw const BuildConfigurationException('invalid_channel'),
    };
  }

  static AppEnvironment _parseEnvironment(String raw) {
    return switch (raw.trim().toLowerCase()) {
      'local' => AppEnvironment.local,
      'staging' => AppEnvironment.staging,
      'production' => AppEnvironment.production,
      _ => throw const BuildConfigurationException('invalid_environment'),
    };
  }

  static void _validateFlavorPair({
    required String? flavor,
    required AppReleaseChannel channel,
    required AppEnvironment environment,
  }) {
    if (flavor == null) return;
    final valid = switch (flavor) {
      'local' =>
        channel == AppReleaseChannel.local &&
            environment == AppEnvironment.local,
      'beta' =>
        channel == AppReleaseChannel.beta &&
            environment == AppEnvironment.staging,
      'stable' || 'play' =>
        channel == AppReleaseChannel.stable &&
            environment == AppEnvironment.production,
      _ => false,
    };
    if (!valid) {
      throw const BuildConfigurationException('flavor_identity_mismatch');
    }
  }

  static bool _isValidCommit(String value, AppReleaseChannel channel) {
    if (channel == AppReleaseChannel.local) {
      return value == 'local-dev' ||
          RegExp(r'^[0-9a-f]{7,40}$').hasMatch(value);
    }
    return RegExp(r'^[0-9a-f]{7,40}$').hasMatch(value);
  }

  static bool _isValidVersionBuild(
    String version,
    int build,
    AppReleaseChannel channel,
  ) {
    if (channel == AppReleaseChannel.local) {
      return version == '0.0.0-local' && build == 0;
    }
    if (channel == AppReleaseChannel.stable) {
      final match = RegExp(r'^\d+\.\d+\.(\d+)$').firstMatch(version);
      return match != null && build == int.parse(match.group(1)!);
    }
    final match = RegExp(r'^\d+\.\d+\.(\d+)-beta\.(\d+)$').firstMatch(version);
    if (match == null) return false;
    final patch = int.parse(match.group(1)!);
    final sequence = int.parse(match.group(2)!);
    return sequence >= 1 && sequence <= 99 && build == patch * 100 + sequence;
  }

  static bool _isHostedProjectRef(String value) =>
      RegExp(r'^[a-z0-9]{20}$').hasMatch(value);

  static bool _hostedUrlMatchesRef(String rawUrl, String projectRef) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != '$projectRef.supabase.co' ||
        uri.hasPort ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      return false;
    }
    return uri.path.isEmpty || uri.path == '/';
  }

  static bool _isLocalSupabaseUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return false;
    }
    return (uri.host == '127.0.0.1' || uri.host == 'localhost') &&
        uri.port == 54321;
  }

  static bool _isClientSafeKey(String key) {
    final normalized = key.trim().toLowerCase();
    if (normalized.startsWith('sb_secret_') ||
        normalized.contains('service_role')) {
      return false;
    }
    if (normalized.startsWith('sb_publishable_')) return true;

    final parts = key.split('.');
    if (parts.length != 3) return false;
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final decoded = jsonDecode(payload);
      return decoded is Map && decoded['role'] == 'anon';
    } catch (_) {
      return false;
    }
  }

  static String? _normalize(String? value) {
    final normalized = value?.trim().toLowerCase();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

class BuildConfigurationException implements Exception {
  const BuildConfigurationException(this.code);

  final String code;

  @override
  String toString() => 'BuildConfigurationException($code)';
}
