import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart' show appFlavor;

/// WP-110 / WP-128: Derleme / dağıtım kanalı.
///
/// Play Store build'inde GitHub APK indirme/kurma yolu kapalıdır.
/// GitHub sideload (`stable` / `beta` flavor) ve Windows MSIX ayrı kalır.
///
/// **WP-128 güvenlik:** Android `--flavor play` derlemesinde
/// `FLUTTER_APP_FLAVOR=play` Flutter araç zinciri tarafından enjekte edilir.
/// `DISTRIBUTION_CHANNEL` define unutulsa bile kanal `play` olur ve
/// `allowsSideloadUpdates` asla true olmaz.
///
/// Derleme:
/// ```
/// # Play AAB (define opsiyonel ama önerilir)
/// flutter build appbundle --flavor play --release \
///   --dart-define=DISTRIBUTION_CHANNEL=play \
///   --dart-define-from-file=env.json
///
/// # GitHub stable APK (mevcut CI)
/// flutter build apk --flavor stable --release \
///   --dart-define=CHANNEL=stable \
///   --dart-define=DISTRIBUTION_CHANNEL=githubStable \
///   --dart-define-from-file=env.json
/// ```
enum DistributionChannel {
  /// Play Store — harici APK/updater yok.
  play,

  /// GitHub Releases stable APK sideload.
  githubStable,

  /// GitHub Releases beta APK sideload.
  githubBeta,

  /// Windows MSIX (GitHub / portable).
  windows,
}

/// `DISTRIBUTION_CHANNEL` dart-define + flavor + platform / eski `CHANNEL`.
class DistributionConfig {
  const DistributionConfig._();

  /// Birincil define (WP-110). Değerler: play | githubStable | githubBeta | windows
  static const String _distributionDefine = String.fromEnvironment(
    'DISTRIBUTION_CHANNEL',
    defaultValue: '',
  );

  /// Eski CI: `CHANNEL=beta|stable` (release.yml).
  static const String _legacyChannel = String.fromEnvironment(
    'CHANNEL',
    defaultValue: 'stable',
  );

  /// Çözülmüş kanal (web → play benzeri; güncelleme yok).
  static DistributionChannel get current {
    return resolve(
      distributionDefine: _distributionDefine,
      legacyChannel: _legacyChannel,
      flutterAppFlavor: appFlavor,
      isWeb: kIsWeb,
      platform: defaultTargetPlatform,
    );
  }

  /// Saf çözümleyici — birim test ve flavor/define senaryoları için.
  ///
  /// Öncelik:
  /// 1. WP-128: `FLUTTER_APP_FLAVOR == play` → **her zaman** play
  ///    (define unutulsa veya yanlış github* yazılsa bile sideload açılmaz)
  /// 2. Açık `DISTRIBUTION_CHANNEL` define (bilinen değerler)
  /// 3. Platform / legacy CHANNEL çıkarımı
  static DistributionChannel resolve({
    required String distributionDefine,
    required String legacyChannel,
    String? flutterAppFlavor,
    bool isWeb = false,
    TargetPlatform platform = TargetPlatform.android,
  }) {
    // WP-128: play flavor mutlak — Play politikası için sideload asla açılmaz.
    final flavor = flutterAppFlavor?.trim().toLowerCase();
    if (flavor == 'play') {
      return DistributionChannel.play;
    }

    final raw = distributionDefine.trim();
    if (raw.isNotEmpty) {
      final parsed = _parseDefine(raw);
      if (parsed != null) return parsed;
    }

    return _inferFromLegacyAndPlatform(
      legacyChannel: legacyChannel,
      isWeb: isWeb,
      platform: platform,
    );
  }

  static DistributionChannel? _parseDefine(String raw) {
    return switch (raw) {
      'play' => DistributionChannel.play,
      'githubStable' => DistributionChannel.githubStable,
      'githubBeta' => DistributionChannel.githubBeta,
      'windows' => DistributionChannel.windows,
      _ => null,
    };
  }

  static DistributionChannel _inferFromLegacyAndPlatform({
    required String legacyChannel,
    required bool isWeb,
    required TargetPlatform platform,
  }) {
    if (isWeb) return DistributionChannel.play;
    if (!isWeb && platform == TargetPlatform.windows) {
      return DistributionChannel.windows;
    }
    if (legacyChannel == 'beta') return DistributionChannel.githubBeta;
    return DistributionChannel.githubStable;
  }

  /// GitHub APK/MSIX check + download + install açık mı?
  static bool get allowsSideloadUpdates => allowsSideloadUpdatesFor(current);

  static bool allowsSideloadUpdatesFor(DistributionChannel channel) {
    return switch (channel) {
      DistributionChannel.play => false,
      DistributionChannel.githubStable => true,
      DistributionChannel.githubBeta => true,
      DistributionChannel.windows => true,
    };
  }

  /// Android `REQUEST_INSTALL_PACKAGES` beklenen mi? (yalnız github Android)
  static bool get expectsInstallPackagesPermission {
    return current == DistributionChannel.githubStable ||
        current == DistributionChannel.githubBeta;
  }

  /// Release notes / etiket kanalı (`stable` | `beta`) — mevcut API ile uyum.
  static String get releaseNotesChannel {
    return current == DistributionChannel.githubBeta ? 'beta' : 'stable';
  }
}
