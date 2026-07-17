import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// WP-110: Derleme / dağıtım kanalı.
///
/// Play Store build'inde GitHub APK indirme/kurma yolu kapalıdır.
/// GitHub sideload (`stable` / `beta` flavor) ve Windows MSIX ayrı kalır.
///
/// Derleme:
/// ```
/// # Play AAB
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

/// `DISTRIBUTION_CHANNEL` dart-define + platform / eski `CHANNEL` geriye uyum.
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
    final raw = _distributionDefine.trim();
    if (raw.isNotEmpty) {
      return switch (raw) {
        'play' => DistributionChannel.play,
        'githubStable' => DistributionChannel.githubStable,
        'githubBeta' => DistributionChannel.githubBeta,
        'windows' => DistributionChannel.windows,
        _ => _inferFromLegacyAndPlatform(),
      };
    }
    return _inferFromLegacyAndPlatform();
  }

  static DistributionChannel _inferFromLegacyAndPlatform() {
    if (kIsWeb) return DistributionChannel.play;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return DistributionChannel.windows;
    }
    if (_legacyChannel == 'beta') return DistributionChannel.githubBeta;
    return DistributionChannel.githubStable;
  }

  /// GitHub APK/MSIX check + download + install açık mı?
  static bool get allowsSideloadUpdates {
    return switch (current) {
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
