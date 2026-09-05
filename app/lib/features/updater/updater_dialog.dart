import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/distribution_channel.dart';
import '../../core/notifications/notification_preferences.dart';
import '../../l10n/app_localizations.dart';
import 'release_notes_service.dart';
import 'updater_service.dart';

/// Açılışta çağrılır: yeni sürüm varsa güncelleme penceresini gösterir.
/// Sessizdir; güncelleme yoksa veya hata olursa hiçbir şey yapmaz.
/// WP-110: Play kanalında hiç çalışmaz (sideload updater kapalı).
Future<void> maybeShowUpdateDialog(BuildContext context) async {
  if (!DistributionConfig.allowsSideloadUpdates) return;

  final l10n = AppLocalizations.of(context);
  final prefs = await SharedPreferences.getInstance();
  if (!(prefs.getBool(NotificationPreferencesNotifier.kUpdates) ?? true)) {
    return;
  }

  var info = await UpdaterService().checkForUpdate();
  if (info == null || !context.mounted) return;

  // WP-773 (sahip, cihazda): "notlar kisminda hicbir sey yok, sadece GitHub
  // linki". GitHub Release govdesi otomatik uretilen "Full Changelog"
  // baglantisiydi; BOS olmadigi icin bundled not hic devreye girmiyordu.
  // Sira artik: etiketin kendi release_notes.json'u (kullanicinin dilinde)
  // -> bundled not -> GitHub govdesi. Ilk ikisi de yoksa govde kalir.
  final notesService = ReleaseNotesService(
    remoteLoader: _fetchReleaseNotesText,
  );
  var note = await notesService.fetchNoteForTag(
    tag: info.tag,
    buildNumber: info.versionCode,
  );
  note ??= await notesService.noteForBuild(
    info.versionCode,
    channel: UpdaterService.channel,
  );
  if (note != null) {
    // WP-131: async gap sonrası locale için mounted guard.
    if (!context.mounted) return;
    final locale = Localizations.localeOf(context);
    info = info.copyWith(
      releaseNotes: note.forLocale(locale).plainText(
        highlightsLabel: l10n.updaterYenilikler,
        fixesLabel: l10n.updaterDuzeltmeler,
        notesLabel: l10n.updaterNotlar,
      ),
    );
  }

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => UpdaterDialog(info: info!),
  );
}

/// GitHub raw dosyasini duz metin olarak ceker (10 sn sinir, hata = firlatir;
/// cagiran sessizce GitHub govdesine iner).
Future<String> _fetchReleaseNotesText(Uri url) async {
  final response = await Dio().get<String>(
    url.toString(),
    options: Options(
      responseType: ResponseType.plain,
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
    ),
  );
  return response.data ?? '';
}

/// Yeni sürümü tanıtan ve indirmeyi yöneten pencere.
///
/// Android'de indirilen APK doğrudan kurulum ekranına verilir. **Windows'ta bu
/// mümkün değildir** (WP-578): çalışan uygulamanın kendi `.exe`/`.dll`
/// dosyaları kilitlidir, güncelleme onların üzerine yazamaz. Bu yüzden Windows
/// kolu taşınabilir ZIP indirir, SHA-256 ile doğrular ve **son adımı
/// kullanıcıya açıkça söyler**; "kuruyormuş gibi" yapıp sessizce ölmez.
class UpdaterDialog extends StatefulWidget {
  const UpdaterDialog({
    super.key,
    required this.info,
    this.dioOverride,
    this.saveDirectoryOverride,
  });

  final UpdateInfo info;

  /// Test tohumu: bütünlük kapısı gerçek davranışla sınanabilsin diye ağ
  /// katmanı dışarıdan verilebilir.
  @visibleForTesting
  final Dio? dioOverride;

  /// Test tohumu: birim testte platform eklentisi (path_provider) yoktur.
  @visibleForTesting
  final Directory? saveDirectoryOverride;

  @override
  State<UpdaterDialog> createState() => _UpdaterDialogState();
}

class _UpdaterDialogState extends State<UpdaterDialog> {
  bool _downloading = false;
  double _progress = 0; // 0..1
  String? _error;

  /// Doğrulanmış Windows arşivinin yolu; doluysa pencere yönerge moduna geçer.
  String? _readyFilePath;
  CancelToken? _cancelToken;

  bool get _isWindowsZip =>
      widget.info.packageKind == UpdatePackageKind.windowsZip;

  @override
  void dispose() {
    // Pencere kapanırsa süren indirmeyi bırak (kaynak sızıntısını önler).
    _cancelToken?.cancel();
    super.dispose();
  }

  /// Windows arşivi kullanıcının **elle açacağı** bir dosyadır; geçici klasör
  /// onun bulabileceği bir yer değil. İndirilenler klasörü yoksa geçiciye
  /// düşülür ve yol yine ekranda gösterilir.
  Future<Directory> _saveDirectory() async {
    final override = widget.saveDirectoryOverride;
    if (override != null) return override;
    if (_isWindowsZip) {
      return await getDownloadsDirectory() ?? await getTemporaryDirectory();
    }
    return getTemporaryDirectory();
  }

  Future<void> _downloadAndInstall() async {
    // WP-110: Play build'de dialog açılmamalı; yine de fail-closed.
    if (!DistributionConfig.allowsSideloadUpdates) {
      if (mounted) {
        final storeMessage = AppLocalizations.of(
          context,
        ).updaterMagazaUzerindenYonetilir;
        setState(() {
          _error = storeMessage;
        });
      }
      return;
    }

    final l10n = AppLocalizations.of(context);
    final cancelToken = CancelToken();
    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
      _readyFilePath = null;
      _cancelToken = cancelToken;
    });

    try {
      // Takılı bağlantıda sonsuza kadar beklememek için zaman aşımları.
      final dio =
          widget.dioOverride ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(minutes: 3),
            ),
          );
      final dir = await _saveDirectory();
      final savePath = _isWindowsZip
          ? '${dir.path}/odak-kampi-windows-${widget.info.versionCode}.zip'
          : '${dir.path}/update_${widget.info.versionCode}.apk';
      final packageFile = File(savePath);

      await dio.download(
        widget.info.downloadUrl,
        savePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() => _progress = received / total);
          }
        },
      );

      // Bütünlük doğrulaması: release SHA-256 yayınlamışsa dosya ile karşılaştır.
      final sha256Url = widget.info.sha256Url;

      // 🔴 WP-578: Windows'ta doğrulama ATLANAMAZ. CI her artefaktın yanında
      // `<ad>.sha256` üretir; yoksa release eksiktir. Doğrulanmamış bir arşivi
      // "hazır" diye sunmak bu WP'nin tam tersi olurdu. Android tarafı eski
      // release'lerle uyum için sha256 yoksa atlamaya devam eder.
      if (_isWindowsZip && sha256Url == null) {
        await _discard(packageFile);
        if (mounted) {
          setState(() {
            _downloading = false;
            _error = l10n.updaterDosyaDogrulanamadi;
          });
        }
        return;
      }

      if (sha256Url != null) {
        final expected = _parseSha256(
          (await dio.get<String>(sha256Url, cancelToken: cancelToken)).data,
        );
        final actual = sha256
            .convert(await packageFile.readAsBytes())
            .toString();
        if (expected == null || expected != actual) {
          await _discard(packageFile);
          if (mounted) {
            setState(() {
              _downloading = false;
              // Eskiden burada "Kurulum iptal edildi." yazıyordu: bozuk indirme
              // ile kullanıcının vazgeçmesi aynı cümleye düşüyordu.
              _error = l10n.updaterDosyaDogrulanamadi;
            });
          }
          return;
        }
      }

      // Windows: kurulum başlatmıyoruz (çalışan uygulamanın üzerine yazılamaz).
      // Doğrulanmış arşivin yerini ve üç adımı gösteriyoruz.
      if (_isWindowsZip) {
        if (mounted) {
          setState(() {
            _downloading = false;
            _readyFilePath = savePath;
          });
        }
        return;
      }

      // APK → Android kurulum ekranı.
      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done && mounted) {
        setState(() {
          _downloading = false;
          _error = l10n.updaterKurulumIptalEdildi;
        });
        return;
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      // Kullanıcı iptal ettiyse hata gösterme, sadece indirmeyi durdur.
      final cancelled = e is DioException && e.type == DioExceptionType.cancel;
      setState(() {
        _downloading = false;
        _error = cancelled ? null : l10n.updaterIndirmeBasarisizOlduInternet;
      });
    }
  }

  /// Doğrulamayı geçemeyen dosya diskte bırakılmaz.
  static Future<void> _discard(File file) async {
    if (await file.exists()) await file.delete();
  }

  /// İndirilen arşivin bulunduğu klasörü dosya yöneticisinde açar. Açılamazsa
  /// kullanıcı yolsuz kalmasın diye tam yol hata satırında gösterilir.
  Future<void> _revealDownload() async {
    final path = _readyFilePath;
    if (path == null) return;
    final l10n = AppLocalizations.of(context);
    final result = await OpenFilex.open(File(path).parent.path);
    if (result.type != ResultType.done && mounted) {
      setState(() => _error = l10n.updaterKlasorAcilamadiPath(path));
    }
  }

  /// `sha256sum` çıktısından (`hex  dosya.apk`) 64 karakterlik hex özeti çıkarır.
  static String? _parseSha256(String? content) {
    if (content == null) return null;
    final m = RegExp(r'\b([a-fA-F0-9]{64})\b').firstMatch(content);
    return m?.group(1)?.toLowerCase();
  }

  List<Widget> _actions(AppLocalizations l10n, String? readyPath) {
    if (_downloading) {
      return [
        TextButton(
          onPressed: () => _cancelToken?.cancel(),
          child: Text(l10n.updaterIptal),
        ),
      ];
    }
    if (readyPath != null) {
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.updaterTamam),
        ),
        FilledButton.icon(
          onPressed: _revealDownload,
          icon: const Icon(Icons.folder_open),
          label: Text(l10n.updaterKlasoruAc),
        ),
      ];
    }
    return [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(l10n.updaterSonra),
      ),
      FilledButton.icon(
        onPressed: _downloadAndInstall,
        icon: const Icon(Icons.download),
        label: Text(
          _error == null ? l10n.updaterGuncelle : l10n.updaterTekrarDene,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final readyPath = _readyFilePath;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.system_update),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.updaterGuncellemeVarInfoversionname(info.versionName),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (readyPath == null && info.releaseNotes.isNotEmpty) ...[
              Text(
                l10n.updaterYeniliklerYenilikler,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(info.releaseNotes),
              const SizedBox(height: 16),
            ],
            if (readyPath != null) WindowsUpdateReadyView(filePath: readyPath),
            if (_downloading) ...[
              LinearProgressIndicator(value: _progress == 0 ? null : _progress),
              const SizedBox(height: 8),
              Text(
                l10n.updaterIndiriliyorProgress100tostringasfixed0(
                  (_progress * 100).toStringAsFixed(0),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: _actions(l10n, readyPath),
    );
  }
}

/// Doğrulanmış Windows arşivi indirildikten sonra gösterilen yönerge (WP-578).
///
/// Bu metin bu iş paketinin asıl teslimatıdır: Windows'ta güncelleme otomatik
/// tamamlanamıyor ve kullanıcı bunu **tahmin etmek zorunda kalmadan**
/// öğrenmeli. Dosya yolu seçilebilir bırakıldı; kopyalanabilmesi gerekiyor.
class WindowsUpdateReadyView extends StatelessWidget {
  const WindowsUpdateReadyView({super.key, required this.filePath});

  final String filePath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.updaterIndirmeDogrulandi,
                style: theme.textTheme.titleSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(l10n.updaterWindowsAcikkenYazilamaz),
        const SizedBox(height: 8),
        Text(l10n.updaterWindowsAdimKapat),
        const SizedBox(height: 4),
        Text(l10n.updaterWindowsAdimCikar),
        const SizedBox(height: 4),
        Text(l10n.updaterWindowsAdimCalistir),
        const SizedBox(height: 12),
        SelectableText(
          l10n.updaterIndirilenDosyaPath(filePath),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
