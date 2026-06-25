import 'dart:io';

import 'package:dio/dio.dart';
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

  /// Yeni sürüm varsa bilgisini, yoksa `null` döndürür.
  /// Ağ/parse hatalarında sessizce `null` döner (uygulama açılışını bloklamaz).
  Future<UpdateInfo?> checkForUpdate() async {
    if (!Platform.isAndroid) return null;

    try {
      final info = await PackageInfo.fromPlatform();
      final currentCode = int.tryParse(info.buildNumber) ?? 0;

      final res = await _dio.get<Map<String, dynamic>>(
        _latestReleaseUrl,
        options: Options(
          headers: {'Accept': 'application/vnd.github+json'},
          // GitHub API'si erişilemezse uzun süre bekletme.
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      final data = res.data;
      if (data == null) return null;

      final latestCode = _parseVersionCode(data['tag_name'] as String?);
      if (latestCode == null || latestCode <= currentCode) return null;

      final apkUrl = _findApkUrl(data['assets']);
      if (apkUrl == null) return null;

      return UpdateInfo(
        versionCode: latestCode,
        versionName: (data['name'] as String?)?.trim().isNotEmpty == true
            ? (data['name'] as String).trim()
            : (data['tag_name'] as String? ?? 'v$latestCode'),
        releaseNotes: (data['body'] as String?)?.trim() ?? '',
        downloadUrl: apkUrl,
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

  /// Release asset'leri içinden `.apk` uzantılı ilk dosyanın indirme linki.
  static String? _findApkUrl(dynamic assets) {
    if (assets is! List) return null;
    for (final a in assets) {
      if (a is Map &&
          (a['name'] as String?)?.toLowerCase().endsWith('.apk') == true) {
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
  });

  final int versionCode;
  final String versionName;
  final String releaseNotes;
  final String downloadUrl;
}
