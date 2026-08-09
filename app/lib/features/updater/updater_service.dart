import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/config/distribution_channel.dart';

/// GitHub Releases üzerinden in-app güncelleme kontrolü.
///
/// - **Play (`DISTRIBUTION_CHANNEL=play`):** kapalı (WP-110) — ağ isteği yok.
/// - **Android GitHub sideload:** sabit isimli APK + SHA-256.
/// - **Windows (WP-578):** sabit isimli **taşınabilir ZIP** + SHA-256. MSIX
///   üretilmeye devam ediyor ama imzasız olduğu için kullanıcıda hiç kurulmuyor
///   (`0x800B010A` — SmartScreen uyarısı değil, sert blok), bu yüzden uygulama
///   içi güncelleme onu bilerek indirmez.
/// - iOS/web: yok.
///
/// Etiket: `v<buildNumber>` / `beta-v<buildNumber>`.
class UpdaterService {
  UpdaterService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  /// GitHub deposu — release artefaktlarının yayınlandığı yer.
  static const String _owner = 'manil-max';
  static const String _repo = 'online-study-room';

  static const String _latestReleaseUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  /// Beta kanalı prerelease'ler dahil tüm release'leri tarar; stable yalnızca
  /// `releases/latest`e bakar (prerelease'ler oraya düşmez → stable beta görmez).
  static const String _allReleasesUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases';

  /// Release notes / etiket kanalı (`stable` | `beta`).
  /// WP-110: [DistributionConfig.releaseNotesChannel] ile hizalı.
  static String get channel => DistributionConfig.releaseNotesChannel;

  // Windows'ta DistributionChannel her iki kanal için `windows` olduğundan
  // beta/stable seçimi açık CHANNEL manifestinden okunur (WP-227).
  static bool get _isBeta => channel == 'beta';

  /// Yeni sürüm varsa bilgisini, yoksa `null` döndürür.
  /// Ağ/parse hatalarında sessizce `null` döner (uygulama açılışını bloklamaz).
  Future<UpdateInfo?> checkForUpdate() async {
    final result = await checkForUpdateDetailed();
    return result.info;
  }

  /// Manuel güncelleme denetimi için kaybı olmayan sonuç.
  ///
  /// Açılıştaki sessiz akış [checkForUpdate] ile geriye uyumlu kalır. Ayarlar
  /// ekranı ise "güncel", mağaza-yönetimli ve ağ/yanıt hatasını birbirine
  /// karıştırmadan kullanıcıya gösterebilir.
  Future<UpdateCheckResult> checkForUpdateDetailed() async {
    // WP-110: Play Store build — GitHub APK yolu unreachable (yalnız UI gizle değil).
    if (!DistributionConfig.allowsSideloadUpdates) {
      return const UpdateCheckResult.managedByStore();
    }

    // kIsWeb derleme-zamanı; web'de `Platform`'a hiç dokunulmaz.
    if (kIsWeb) return const UpdateCheckResult.unsupported();
    final isAndroid = Platform.isAndroid;
    final isWindows = Platform.isWindows;
    if (!isAndroid && !isWindows) {
      return const UpdateCheckResult.unsupported();
    }

    try {
      final info = await PackageInfo.fromPlatform();
      final currentCode = int.tryParse(info.buildNumber) ?? 0;

      final options = Options(
        headers: {'Accept': 'application/vnd.github+json'},
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
      );

      final assetName = isWindows ? _windowsZipName : _apkName;

      final Map<String, dynamic>? data;
      if (_isBeta) {
        final res = await _dio.get<List<dynamic>>(
          _allReleasesUrl,
          options: options,
        );
        data = _pickLatestBeta(res.data, assetName: assetName);
      } else {
        final res = await _dio.get<Map<String, dynamic>>(
          _latestReleaseUrl,
          options: options,
        );
        data = res.data;
      }
      if (data == null) return const UpdateCheckResult.upToDate();

      final latestCode = _parseVersionCode(data['tag_name'] as String?);
      if (latestCode == null) return const UpdateCheckResult.failed();
      if (latestCode <= currentCode) {
        return const UpdateCheckResult.upToDate();
      }

      final assets = data['assets'];
      final packageUrl = _findAssetUrl(assets, assetName);
      if (packageUrl == null) return const UpdateCheckResult.failed();

      return UpdateCheckResult.updateAvailable(
        UpdateInfo(
          versionCode: latestCode,
          versionName: (data['name'] as String?)?.trim().isNotEmpty == true
              ? (data['name'] as String).trim()
              : (data['tag_name'] as String? ?? 'v$latestCode'),
          releaseNotes: (data['body'] as String?)?.trim() ?? '',
          downloadUrl: packageUrl,
          sha256Url: _findAssetUrl(assets, '$assetName.sha256'),
          packageKind: isWindows
              ? UpdatePackageKind.windowsZip
              : UpdatePackageKind.apk,
        ),
      );
    } catch (_) {
      return const UpdateCheckResult.failed();
    }
  }

  /// `v2`, `V2`, `2`, `v1.0.1+2` gibi etiketlerden sayısal build kodunu çıkarır.
  /// Etikette `+N` varsa onu, yoksa son sayı grubunu kullanır.
  static int? _parseVersionCode(String? tag) {
    if (tag == null) return null;
    final plus = RegExp(r'\+(\d+)').firstMatch(tag);
    if (plus != null) return int.tryParse(plus.group(1)!);
    final nums = RegExp(r'\d+').allMatches(tag).toList();
    if (nums.isEmpty) return null;
    return int.tryParse(nums.last.group(0)!);
  }

  /// Test görünürlüğü (WP-28).
  static int? parseVersionCodeForTest(String? tag) => _parseVersionCode(tag);

  /// CI tarafından üretilen APK'nın sabit adı (release.yml ile aynı olmalı).
  static String get _apkName =>
      _isBeta ? 'app-beta-release.apk' : 'app-release.apk';

  /// CI `windows-release.yml` ile hizalı **taşınabilir ZIP** adı (WP-578).
  ///
  /// İş akışı `prefix=odak-kampi-windows-$channel` üretip `$prefix.zip` yazar;
  /// buradaki iki dize onunla harfi harfine aynı olmak zorundadır. Sözleşme
  /// `test/features/updater/windows_packaging_wp568_test.dart` ile kilitli.
  static String get _windowsZipName => _isBeta
      ? 'odak-kampi-windows-beta.zip'
      : 'odak-kampi-windows-stable.zip';

  /// Beta kanalı için: prerelease + `beta` etiket + asset'i olan en yüksek build.
  static Map<String, dynamic>? _pickLatestBeta(
    List<dynamic>? releases, {
    required String assetName,
  }) {
    if (releases == null) return null;
    Map<String, dynamic>? best;
    var bestCode = -1;
    for (final r in releases) {
      if (r is! Map<String, dynamic>) continue;
      if (r['prerelease'] != true) continue;
      final tag = r['tag_name'] as String?;
      if (tag == null || !tag.toLowerCase().startsWith('beta')) continue;
      final code = _parseVersionCode(tag);
      if (code == null) continue;
      if (_findAssetUrl(r['assets'], assetName) == null) continue;
      if (code > bestCode) {
        bestCode = code;
        best = r;
      }
    }
    return best;
  }

  /// Release asset'leri içinden adı tam eşleşen dosyanın indirme linki.
  static String? _findAssetUrl(dynamic assets, String name) {
    if (assets is! List) return null;
    for (final a in assets) {
      if (a is Map && a['name'] == name) {
        return a['browser_download_url'] as String?;
      }
    }
    return null;
  }
}

enum UpdateCheckOutcome {
  updateAvailable,
  upToDate,
  managedByStore,
  unsupported,
  failed,
}

class UpdateCheckResult {
  const UpdateCheckResult._(this.outcome, this.info);

  const UpdateCheckResult.updateAvailable(UpdateInfo info)
    : this._(UpdateCheckOutcome.updateAvailable, info);

  const UpdateCheckResult.upToDate()
    : this._(UpdateCheckOutcome.upToDate, null);

  const UpdateCheckResult.managedByStore()
    : this._(UpdateCheckOutcome.managedByStore, null);

  const UpdateCheckResult.unsupported()
    : this._(UpdateCheckOutcome.unsupported, null);

  const UpdateCheckResult.failed() : this._(UpdateCheckOutcome.failed, null);

  final UpdateCheckOutcome outcome;
  final UpdateInfo? info;
}

/// İndirilecek paket türü (kurulum yolu platforma göre değişir).
///
/// WP-578: Windows kolu MSIX değil **taşınabilir ZIP** indirir. ZIP kurulmaz,
/// açılır: çalışan uygulama kendi dosyalarının üzerine yazamayacağı için son
/// adımı kullanıcı yapar.
enum UpdatePackageKind { apk, windowsZip }

/// Bulunan yeni sürümün bilgileri.
class UpdateInfo {
  const UpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.releaseNotes,
    required this.downloadUrl,
    this.sha256Url,
    this.packageKind = UpdatePackageKind.apk,
  });

  final int versionCode;
  final String versionName;
  final String releaseNotes;
  final String downloadUrl;

  /// Beklenen SHA-256 dosyasının linki; `null` ise doğrulama atlanır.
  final String? sha256Url;

  /// Android APK veya Windows taşınabilir ZIP.
  final UpdatePackageKind packageKind;

  UpdateInfo copyWith({
    int? versionCode,
    String? versionName,
    String? releaseNotes,
    String? downloadUrl,
    String? sha256Url,
    UpdatePackageKind? packageKind,
  }) {
    return UpdateInfo(
      versionCode: versionCode ?? this.versionCode,
      versionName: versionName ?? this.versionName,
      releaseNotes: releaseNotes ?? this.releaseNotes,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      sha256Url: sha256Url ?? this.sha256Url,
      packageKind: packageKind ?? this.packageKind,
    );
  }
}
