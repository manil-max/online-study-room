import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:shared_preferences/shared_preferences.dart';
// 🔴 WP-847: `url_launcher` pubspec'te DOĞRUDAN değil, `supabase_flutter`
// üzerinden geçişli bağımlılık (Android/Windows eklentisi zaten kayıtlı).
// Kod tabanında hazır bir bağlantı açıcı yoktu; pubspec sıcak dosya olduğu
// için bu WP'ye verilmedi. Lider pubspec'e `url_launcher` ekleyince bu
// `ignore` satırı silinmeli.
// ignore: depend_on_referenced_packages
import 'package:url_launcher/url_launcher.dart' as launcher;

import '../../core/config/app_build_manifest.dart';
import '../../core/config/distribution_channel.dart';
import '../../l10n/app_localizations.dart';

/// WP-847 (sahip kararı 2026-09-18): normal kullanıcı artık uygulamayı
/// **Google Play**'den alır; GitHub yalnız BETA kanalıdır.
///
/// GitHub'dan **stable APK** kurmuş kullanıcı bundan sonra oradan stable
/// güncelleme almayacak. Uyarı olmadan updater sessizce susardı ve kullanıcı
/// eski sürümde kaldığını hiç öğrenmezdi.
///
/// Neden "kaldır, sonra kur"? Stable APK ile Play derlemesi aynı
/// `applicationId`yi taşır ama imzaları farklıdır (APK yükleme anahtarıyla,
/// Play derlemesi Play'in uygulama imzalama anahtarıyla imzalanır). Android
/// farklı imzalı paketi üstüne kurdurmaz; önce kaldırmak şarttır.
class PlayMigration {
  const PlayMigration._();

  /// Play mağaza sayfası (`play` flavor'ın `applicationId`si).
  static const String listingUrl =
      'https://play.google.com/store/apps/details?id=com.manilmax.online_study_room';

  /// Diyaloğun bir kez gösterildiğini işaretleyen yerel anahtar.
  static const String dialogShownKey = 'play_migration_notice_shown_v1';

  /// Uyarı yalnız **GitHub stable sürüm derlemesinde** görünür.
  ///
  /// `releaseChannel == stable` şartı yerel/geliştirme derlemelerini dışarıda
  /// tutar: define'sız derleme kanalı `githubStable`a düşer (varsayılan), ama
  /// onun manifesti `local`dır veya hiç çözülmez (`null`).
  static bool appliesTo({
    required DistributionChannel channel,
    required AppReleaseChannel? releaseChannel,
    bool isWeb = false,
    TargetPlatform platform = TargetPlatform.android,
  }) {
    return !isWeb &&
        platform == TargetPlatform.android &&
        channel == DistributionChannel.githubStable &&
        releaseChannel == AppReleaseChannel.stable;
  }

  /// Çalışan derleme için karar.
  static bool get appliesToCurrent => appliesTo(
    channel: DistributionConfig.current,
    releaseChannel: AppBuildManifest.currentOrNull?.channel,
    isWeb: kIsWeb,
    platform: defaultTargetPlatform,
  );
}

/// Dış bağlantı açıcı; testte gerçek platform kanalı yerine verilir.
typedef ExternalUrlOpener = Future<bool> Function(Uri uri);

Future<bool> _launchExternal(Uri uri) async {
  try {
    return await launcher.launchUrl(
      uri,
      mode: launcher.LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}

/// Play sayfasını açar. Açılamazsa (Play yüklü değil, tarayıcı yok) kullanıcı
/// yolsuz kalmasın diye bağlantı panoya kopyalanır ve bu söylenir.
Future<void> openPlayStoreListing(
  BuildContext context, {
  ExternalUrlOpener? opener,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final opened = await (opener ?? _launchExternal)(
    Uri.parse(PlayMigration.listingUrl),
  );
  if (opened) return;
  await Clipboard.setData(const ClipboardData(text: PlayMigration.listingUrl));
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(l10n.playMigrationOpenFailed)));
}

/// Açılışta **bir kez** gösterilen geçiş diyaloğu.
///
/// Engellemez: "Sonra" ile kapanır, dışına dokununca kapanır. Kapatılan
/// diyalog bir daha açılmaz; aynı bilgi Ayarlar → Hakkında ve güncellemeler
/// ekranındaki kalıcı satırda ([PlayMigrationTile]) durur.
///
/// İşaret diyalog **açılmadan önce** yazılır: uygulama diyalog açıkken
/// öldürülürse her açılışta yeniden karşısına çıkmasın.
Future<void> maybeShowPlayMigrationDialog(
  BuildContext context, {
  bool? applies,
  SharedPreferences? preferences,
  ExternalUrlOpener? opener,
}) async {
  if (!(applies ?? PlayMigration.appliesToCurrent)) return;
  final prefs = preferences ?? await SharedPreferences.getInstance();
  if (prefs.getBool(PlayMigration.dialogShownKey) ?? false) return;
  await prefs.setBool(PlayMigration.dialogShownKey, true);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => PlayMigrationDialog(opener: opener),
  );
}

class PlayMigrationDialog extends StatelessWidget {
  const PlayMigrationDialog({super.key, this.opener});

  @visibleForTesting
  final ExternalUrlOpener? opener;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      key: const Key('play-migration-dialog'),
      title: Row(
        children: [
          const Icon(Icons.shop_outlined),
          const SizedBox(width: 8),
          Expanded(child: Text(l10n.playMigrationTitle)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.playMigrationBody),
            const SizedBox(height: 12),
            Text(l10n.playMigrationSteps),
            const SizedBox(height: 12),
            Text(l10n.playMigrationDataSafe, style: theme.textTheme.titleSmall),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.updaterSonra),
        ),
        FilledButton.icon(
          key: const Key('play-migration-open-play'),
          onPressed: () async {
            final navigator = Navigator.of(context);
            await openPlayStoreListing(context, opener: opener);
            if (navigator.mounted) navigator.pop();
          },
          icon: const Icon(Icons.open_in_new),
          label: Text(l10n.playMigrationOpenPlay),
        ),
      ],
    );
  }
}

/// Hakkında ve güncellemeler ekranındaki kalıcı satır: diyalog kapatılsa da
/// bilgi ve Play düğmesi burada ulaşılabilir kalır.
class PlayMigrationTile extends StatelessWidget {
  const PlayMigrationTile({super.key, this.opener});

  @visibleForTesting
  final ExternalUrlOpener? opener;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      key: const Key('play-migration-tile'),
      leading: const Icon(Icons.shop_outlined),
      title: Text(l10n.playMigrationTileTitle),
      subtitle: Text(l10n.playMigrationTileSubtitle),
      trailing: const Icon(Icons.open_in_new),
      onTap: () => openPlayStoreListing(context, opener: opener),
    );
  }
}
