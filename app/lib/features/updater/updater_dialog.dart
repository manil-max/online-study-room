import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'updater_service.dart';

/// Açılışta çağrılır: yeni sürüm varsa güncelleme penceresini gösterir.
/// Sessizdir; güncelleme yoksa veya hata olursa hiçbir şey yapmaz.
Future<void> maybeShowUpdateDialog(BuildContext context) async {
  final info = await UpdaterService().checkForUpdate();
  if (info == null || !context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => UpdaterDialog(info: info),
  );
}

/// Yeni sürümü tanıtan ve indirip kurmayı yöneten pencere.
class UpdaterDialog extends StatefulWidget {
  const UpdaterDialog({super.key, required this.info});

  final UpdateInfo info;

  @override
  State<UpdaterDialog> createState() => _UpdaterDialogState();
}

class _UpdaterDialogState extends State<UpdaterDialog> {
  bool _downloading = false;
  double _progress = 0; // 0..1
  String? _error;

  Future<void> _downloadAndInstall() async {
    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
    });

    try {
      final dio = Dio();
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/update_${widget.info.versionCode}.apk';
      final apkFile = File(savePath);

      await dio.download(
        widget.info.downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() => _progress = received / total);
          }
        },
      );

      // Bütünlük doğrulaması: release SHA-256 yayınlamışsa indirilen APK ile karşılaştır.
      // Eşleşmezse dosyayı sil ve kurulumu iptal et (kurcalanmış/eksik indirme koruması).
      final sha256Url = widget.info.sha256Url;
      if (sha256Url != null) {
        final expected = _parseSha256(
          (await dio.get<String>(sha256Url)).data,
        );
        final actual = sha256.convert(await apkFile.readAsBytes()).toString();
        if (expected == null || expected != actual) {
          if (await apkFile.exists()) await apkFile.delete();
          if (mounted) {
            setState(() {
              _downloading = false;
              _error = 'Güvenlik doğrulaması başarısız (dosya bütünlüğü). '
                  'Kurulum iptal edildi.';
            });
          }
          return;
        }
      }

      // APK'yı aç → Android kurulum ekranı tetiklenir.
      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done && mounted) {
        setState(() {
          _downloading = false;
          _error = 'Kurulum açılamadı: ${result.message}';
        });
        return;
      }
      // Kurulum ekranı açıldı; pencereyi kapat.
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _error = 'İndirme başarısız oldu. İnternet bağlantını kontrol et.';
        });
      }
    }
  }

  /// `sha256sum` çıktısından (`hex  dosya.apk`) 64 karakterlik hex özeti çıkarır.
  static String? _parseSha256(String? content) {
    if (content == null) return null;
    final m = RegExp(r'\b([a-fA-F0-9]{64})\b').firstMatch(content);
    return m?.group(1)?.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.system_update),
          const SizedBox(width: 8),
          Expanded(child: Text('Güncelleme var: ${info.versionName}')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (info.releaseNotes.isNotEmpty) ...[
              Text('Yenilikler:', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(info.releaseNotes),
              const SizedBox(height: 16),
            ],
            if (_downloading) ...[
              LinearProgressIndicator(value: _progress == 0 ? null : _progress),
              const SizedBox(height: 8),
              Text('İndiriliyor… %${(_progress * 100).toStringAsFixed(0)}'),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: _downloading
          ? null
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Sonra'),
              ),
              FilledButton.icon(
                onPressed: _downloadAndInstall,
                icon: const Icon(Icons.download),
                label: Text(_error == null ? 'Güncelle' : 'Tekrar dene'),
              ),
            ],
    );
  }
}
