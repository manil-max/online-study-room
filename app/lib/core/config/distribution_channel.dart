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
///
/// # Microsoft Store MSIX (Faz H) — updater kapalı
/// flutter build windows --release \
///   --dart-define=DISTRIBUTION_CHANNEL=microsoftStore \
///   --dart-define-from-file=env.json
/// ```
///
/// **WP-322 uyarısı:** Windows'ta Android'in `--flavor` zorlaması yoktur, yani
/// `microsoftStore` kanalını **yalnız define** seçer. Store işi (Faz H) bu
/// define'ı CI'da set etmek ve `msix_config.store: true` ile paketlemekle
/// yükümlüdür; define unutulursa Windows varsayımı [windows] olur ve updater
/// açık kalır. Bu yüzden Faz H'de build öncesi bir kapı testi şarttır.
enum DistributionChannel {
  /// Play Store — harici APK/updater yok.
  play,

  /// GitHub Releases stable APK sideload.
  githubStable,

  /// GitHub Releases beta APK sideload.
  githubBeta,

  /// Windows MSIX (GitHub / portable).
  windows,

  /// Microsoft Store MSIX — mağaza dışı güncelleme **yasak**.
  ///
  /// WP-322: Store politikası, paketin kendini mağaza dışından güncellemesine
  /// izin vermez. [windows] kanalı GitHub Releases'tan MSIX indirir; Store
  /// paketi aynı kodla çıkarsa politika ihlali olur. Bu yüzden ayrı kanal:
  /// `allowsSideloadUpdates` burada **asla** true olmaz.
  microsoftStore,
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
    // WP-227: local flavor release kanalı değildir; GitHub updater/ağ isteği yok.
    final flavor = flutterAppFlavor?.trim().toLowerCase();
    if (flavor == 'play' || flavor == 'local') {
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
      'microsoftStore' => DistributionChannel.microsoftStore,
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
      DistributionChannel.microsoftStore => false,
    };
  }

  /// Android `REQUEST_INSTALL_PACKAGES` beklenen mi? (yalnız github Android)
  static bool get expectsInstallPackagesPermission {
    return current == DistributionChannel.githubStable ||
        current == DistributionChannel.githubBeta;
  }

  /// Release notes / etiket kanalı (`stable` | `beta`).
  ///
  /// Windows dağıtım türü her iki release kanalında da `windows` olduğu için
  /// yalnız [current] üzerinden beta bilgisi çıkarılamaz. Açık `CHANNEL` define'ı
  /// Android ve Windows'ta tek release kanalı otoritesidir.
  static String get releaseNotesChannel => resolveReleaseNotesChannel(
    legacyChannel: _legacyChannel,
    distributionChannel: current,
  );

  static String resolveReleaseNotesChannel({
    required String legacyChannel,
    required DistributionChannel distributionChannel,
  }) {
    // WP-322: Store paketi her zaman stable'dır. Unutulmuş bir `CHANNEL=beta`
    // define'ı Store build'ine beta sürüm notlarını gösteremez.
    if (distributionChannel == DistributionChannel.microsoftStore) {
      return 'stable';
    }
    if (legacyChannel.trim().toLowerCase() == 'beta') return 'beta';
    if (distributionChannel == DistributionChannel.githubBeta) return 'beta';
    return 'stable';
  }
}
