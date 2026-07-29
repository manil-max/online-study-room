import 'package:flutter/material.dart';

import '../../core/config/app_build_manifest.dart';
import '../../core/config/build_identity_card.dart';
import '../../core/config/distribution_channel.dart';
import '../../core/widgets/safe_screen_padding.dart';
import '../../l10n/app_localizations.dart';
import '../desktop/desktop_surface.dart';
import '../support/faq_screen.dart';
import '../updater/release_notes_screen.dart';
import '../updater/release_notes_service.dart';
import '../updater/updater_dialog.dart';
import '../updater/updater_service.dart';
import 'legal_center_screen.dart';

/// Ayarlar → Hakkında ve güncellemeler.
///
/// WP-419: Derleme kimliği (kanal / backend project-ref / commit / migration
/// başı) daha önce sürüm notları ekranının en üstünde son kullanıcıya açıktı.
/// Kart silinmedi, buraya taşındı: varsayılan yalnız sürüm adı görünür, teknik
/// satırlar dokununca açılır. Destek yazışmasında "sürümün ne?" sorusu
/// cevaplanabilir kalır.
///
/// WP-456: Sürüm notları ve Hakkında ayarları bu ekranda birleşir. Güncelleme
/// denetimi kanal politikasını izler; Play/Microsoft Store derlemeleri GitHub
/// self-update yolunu hiçbir koşulda açmaz.
class AboutScreen extends StatefulWidget {
  const AboutScreen({
    super.key,
    this.buildManifest,
    this.updateCheck,
    this.allowsSideloadUpdates,
    this.releaseNotesService,
    this.releaseNotesChannel,
  });

  final AppBuildManifest? buildManifest;
  final Future<UpdateCheckResult> Function()? updateCheck;
  final bool? allowsSideloadUpdates;
  final ReleaseNotesService? releaseNotesService;
  final String? releaseNotesChannel;

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  bool _checking = false;
  UpdateCheckOutcome? _updateOutcome;

  bool get _allowsSideloadUpdates =>
      widget.allowsSideloadUpdates ?? DistributionConfig.allowsSideloadUpdates;

  Future<void> _checkForUpdates() async {
    if (!_allowsSideloadUpdates || _checking) return;

    setState(() {
      _checking = true;
      _updateOutcome = null;
    });

    final result =
        await (widget.updateCheck ?? UpdaterService().checkForUpdateDetailed)();
    if (!mounted) return;

    setState(() {
      _checking = false;
      _updateOutcome = result.outcome;
    });

    final info = result.info;
    if (result.outcome == UpdateCheckOutcome.updateAvailable && info != null) {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => UpdaterDialog(info: info),
      );
    }
  }

  String _updateStatus(AppLocalizations l10n) {
    if (!_allowsSideloadUpdates) return l10n.updaterMagazaUzerindenYonetilir;
    if (_checking) return l10n.updaterCheckingForUpdates;

    return switch (_updateOutcome) {
      UpdateCheckOutcome.updateAvailable =>
        l10n.updaterUpdateAvailableOpenDialog,
      UpdateCheckOutcome.upToDate => l10n.updaterAppUpToDate,
      UpdateCheckOutcome.managedByStore => l10n.updaterMagazaUzerindenYonetilir,
      UpdateCheckOutcome.unsupported => l10n.updaterUnavailableOnDevice,
      UpdateCheckOutcome.failed => l10n.updaterCheckFailed,
      null => l10n.updaterCheckDescription,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileSurumVeGuncellemeler)),
      body: ListView(
        padding: getSafePadding(
          context,
          const EdgeInsets.fromLTRB(16, 12, 16, 24),
        ),
        children: [
          DesktopReadingBody(
            maxWidth: DesktopSurface.readingWidth,
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    l10n.appTitle,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                BuildIdentityCard(
                  manifest:
                      widget.buildManifest ?? AppBuildManifest.currentOrNull,
                ),
                const SizedBox(height: 24),
                _AboutSection(
                  title: l10n.profileSurumVeGuncellemeler,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        ListTile(
                          key: const Key('about-check-for-updates'),
                          leading: const Icon(Icons.system_update_outlined),
                          title: Text(l10n.updaterCheckForUpdates),
                          subtitle: Text(_updateStatus(l10n)),
                          trailing: _checking
                              ? const SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : _allowsSideloadUpdates
                              ? const Icon(Icons.refresh)
                              : const Icon(Icons.store_outlined),
                          onTap: _allowsSideloadUpdates && !_checking
                              ? _checkForUpdates
                              : null,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          key: const Key('about-release-notes'),
                          leading: const Icon(Icons.new_releases_outlined),
                          title: Text(l10n.updaterGuncellemeNotlari),
                          subtitle: Text(l10n.profileYenilikleriVeGecmisSurum),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ReleaseNotesScreen(
                                service: widget.releaseNotesService,
                                channel:
                                    widget.releaseNotesChannel ??
                                    DistributionConfig.releaseNotesChannel,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _AboutSection(
                  title: l10n.settingsSectionAboutLegal,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        ListTile(
                          key: const Key('about-faq'),
                          leading: const Icon(Icons.help_outline),
                          title: Text(l10n.faqTitle),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const FaqScreen(),
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          key: const Key('about-legal'),
                          leading: const Icon(Icons.policy_outlined),
                          title: Text(l10n.legalCenterTitle),
                          subtitle: Text(l10n.legalPrivacyPolicy),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LegalCenterScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      child,
    ],
  );
}
