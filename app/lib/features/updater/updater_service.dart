import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';

/// GitHub Releases üzerinden in-app güncelleme kontrolü.
///
/// Tasarım: APK'lar GitHub Releases'te tutulur. Her sürüm `v<buildNumber>`
/// etiketiyle yayınlanır (ör. `v2`). Uygulama kendi buildNumber'ını
/// (pubspec'teki `+N`) okur ve GitHub'daki en son release etiketiyle
/// karşılaştırır. Ücretsiz; Supabase'e gerek yoktur.
///
/// Yalnızca Android'de anlamlıdır (iOS sideload'a izin vermez).
class UpdaterService {
  UpdaterService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  /// GitHub deposu — APK release'lerinin yayınlandığı yer.
  static const String _owner = 'manil-max';
  static const String _repo = 'online-study-room';

  static const String _latestReleaseUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  /// Beta kanalı prerelease'ler dahil tüm release'leri tarar; stable yalnızca
  /// `releases/latest`e bakar (prerelease'ler oraya düşmez → stable beta görmez).
  static const String _allReleasesUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases';

  /// Derleme kanalı. Beta CI derlemesi `--dart-define=CHANNEL=beta` geçer;
  /// varsayılan `stable` olduğu için mevcut kullanıcılar etkilenmez.
  static const String channel =
      String.fromEnvironment('CHANNEL', defaultValue: 'stable');

  static bool get _isBeta => channel == 'beta';

  /// Yeni sürüm varsa bilgisini, yoksa `null` döndürür.
  /// Ağ/parse hatalarında sessizce `null` döner (uygulama açılışını bloklamaz).
  Future<UpdateInfo?> checkForUpdate() async {
    // Web ve Android dışı platformlarda güncelleme yok. kIsWeb derleme-zamanı
    // sabiti; web'de `Platform`'a hiç dokunulmaz (web'de erişmek hata fırlatır).
    if (kIsWeb || !Platform.isAndroid) return null;

    try {
      final info = await PackageInfo.fromPlatform();
      final currentCode = int.tryParse(info.buildNumber) ?? 0;

      final options = Options(
        headers: {'Accept': 'application/vnd.github+json'},
        // GitHub API'si erişilemezse uzun süre bekletme.
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
      );

      final Map<String, dynamic>? data;
      if (_isBeta) {
        // Beta: tüm release listesinden en yüksek beta ön-sürümünü seç.
        final res = await _dio.get<List<dynamic>>(
          _allReleasesUrl,
          options: options,
        );
        data = _pickLatestBeta(res.data);
      } else {
        final res = await _dio.get<Map<String, dynamic>>(
          _latestReleaseUrl,
          options: options,
        );
        data = res.data;
      }
      if (data == null) return null;

      final latestCode = _parseVersionCode(data['tag_name'] as String?);
      if (latestCode == null || latestCode <= currentCode) return null;

      final assets = data['assets'];
      // Yalnızca CI'nın ürettiği sabit isimli APK'yı kabul et (rastgele .apk değil).
      final apkUrl = _findAssetUrl(assets, _apkName);
      if (apkUrl == null) return null;

      return UpdateInfo(
        versionCode: latestCode,
        versionName: (data['name'] as String?)?.trim().isNotEmpty == true
            ? (data['name'] as String).trim()
            : (data['tag_name'] as String? ?? 'v$latestCode'),
        releaseNotes: (data['body'] as String?)?.trim() ?? '',
        downloadUrl: apkUrl,
        // Varsa SHA-256 dosyası; indirme sonrası bütünlük doğrulamasında kullanılır.
        sha256Url: _findAssetUrl(assets, '$_apkName.sha256'),
      );
    } catch (_) {
      // Güncelleme kontrolü "best effort"tur; hata olursa görmezden gelinir.
      return null;
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

  /// CI tarafından üretilen APK'nın sabit adı (release.yml ile aynı olmalı).
  /// Beta flavor'ın çıktısı ayrı isimlidir; stable `app-release.apk` korunur
  /// (eski kullanıcıların güncelleme kontrolü kırılmasın diye CI adı sabit tutar).
  static String get _apkName =>
      _isBeta ? 'app-beta-release.apk' : 'app-release.apk';

  /// Beta kanalı için: prerelease olan ve `beta` etiketli release'ler arasından
  /// build kodu en yüksek olanı (ve APK asset'i bulunanı) seçer.
  static Map<String, dynamic>? _pickLatestBeta(List<dynamic>? releases) {
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
      if (_findAssetUrl(r['assets'], _apkName) == null) continue;
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

/// Bulunan yeni sürümün bilgileri.
class UpdateInfo {
  const UpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.releaseNotes,
    required this.downloadUrl,
    this.sha256Url,
  });

  final int versionCode;
  final String versionName;
  final String releaseNotes;
  final String downloadUrl;

  /// APK'nın beklenen SHA-256 özetini içeren `.sha256` dosyasının linki.
  /// `null` ise bütünlük doğrulaması atlanır (eski/manuel release'ler için).
  final String? sha256Url;
}
