import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/animals/camp_animal.dart';
import '../../core/l10n/app_locale.dart';
import '../../core/tour/tour_controller.dart';
import '../../core/widgets/safe_screen_padding.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/admin_providers.dart';
import '../../data/providers/group_providers.dart';
import '../../data/providers/notification_providers.dart';
import '../admin/admin_screen.dart';
import '../desktop/desktop_surface.dart';
import '../notifications/announcements_screen.dart';
import '../notifications/notification_permissions_screen.dart';
import '../updater/release_notes_screen.dart';
import '../safety/blocked_users_screen.dart';
import 'account_settings_screen.dart';
import 'appearance_screen.dart';
import 'data_export_screen.dart';
import 'legal_center_screen.dart';
import 'widgets/camp_animal_picker.dart';
import 'widgets/report_issue_dialog.dart';

/// Ayarlar: görünüm, Ana Sayfa davranışı ve gelecek özelleştirme alanları.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.embedded = false});

  /// Desktop master-detail içinde gömülü: AppBar yok (WP-53).
  final bool embedded;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Seçim anında (realtime beklemeden) tile'ı güncellemek için optimistik id.
  String? _animalOverride;

  Future<void> _pickAnimal() async {
    final profile = ref.read(authStateProvider).value;
    if (profile == null) return;
    final currentId = _animalOverride ?? profile.animal;
    final shownId = campAnimalFor(userId: profile.id, animalId: currentId).id;

    final picked = await showCampAnimalPicker(context, currentId: shownId);
    if (picked == null || picked == currentId) return;

    await ref.read(authRepositoryProvider).updateAnimal(picked);
    // Sahnenin (grup üyeleri akışının) yeni hayvanı hemen çekmesi için yenile.
    ref.invalidate(groupMembersProvider);
    if (mounted) setState(() => _animalOverride = picked);
  }

  Future<void> _openReportDialog() async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (_) => ReportIssueDialog(),
    );
    if (!mounted || sent != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).profileGeriBildiriminGonderildi,
        ),
      ),
    );
  }

  Future<void> _resetTours() async {
    await ref.read(tourControllerProvider.notifier).resetAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).profileTanitimTurlariSifirlandi,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = ref.watch(appLanguageProvider);
    final profile = ref.watch(authStateProvider).value;
    final isAdmin = ref.watch(adminIsSuperAdminProvider).value ?? false;
    final unreadAnnouncements = ref.watch(unreadAnnouncementCountProvider);
    final animal = profile == null
        ? null
        : campAnimalFor(
            userId: profile.id,
            animalId: _animalOverride ?? profile.animal,
          );

    final list = ListView(
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
              _SettingsCard(
                child: ListTile(
                  leading: Icon(Icons.manage_accounts),
                  title: Text(
                    AppLocalizations.of(context).profileHesabimiYonet,
                  ),
                  subtitle: Text(
                    AppLocalizations.of(context).profileEpostaSifreVeGuvenli,
                  ),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => AccountSettingsScreen()),
                  ),
                ),
              ),
              SizedBox(height: 10),
              // WP-152: GDPR veri dışa aktarma
              _SettingsCard(
                child: ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: Text(l10n.exportMyData),
                  subtitle: Text(l10n.exportMyDataSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DataExportScreen()),
                  ),
                ),
              ),
              SizedBox(height: 10),
              _SettingsCard(
                child: ListTile(
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
              ),
              SizedBox(height: 10),
              // WP-129: engellenen kullanıcılar / unblock UI
              _SettingsCard(
                child: ListTile(
                  leading: const Icon(Icons.block),
                  title: Text(l10n.safetyBlockedUsersTitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const BlockedUsersScreen(),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10),
              _SettingsCard(
                child: ListTile(
                  leading: Icon(Icons.color_lens_outlined),
                  title: Text(
                    AppLocalizations.of(
                      context,
                    ).profileGorunumVeAtmosferTemalari,
                  ),
                  subtitle: Text(l10n.profileGorunumVeAtmosfer),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => AppearanceScreen())),
                ),
              ),
              SizedBox(height: 10),
              _SettingsCard(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: DropdownButtonFormField<AppLanguage>(
                    key: ValueKey(language),
                    initialValue: language,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.profileUygulamaDili,
                      helperText: l10n.profileDilDegisikligiAnindaUygulanir,
                      prefixIcon: const Icon(Icons.language_outlined),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: AppLanguage.system,
                        child: Text(l10n.profileDilSistemVarsayilani),
                      ),
                      DropdownMenuItem(
                        value: AppLanguage.turkish,
                        child: Text(l10n.profileDilTurkce),
                      ),
                      DropdownMenuItem(
                        value: AppLanguage.english,
                        child: Text(l10n.profileDilIngilizce),
                      ),
                      // WP-155
                      DropdownMenuItem(
                        value: AppLanguage.arabic,
                        child: Text(l10n.languageArabic),
                      ),
                      DropdownMenuItem(
                        value: AppLanguage.german,
                        child: Text(l10n.languageGerman),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        ref
                            .read(appLanguageProvider.notifier)
                            .setLanguage(value);
                      }
                    },
                  ),
                ),
              ),
              // WP-186: ızgara yoğunluğu herkeste sabit 32 — seçici kaldırıldı.
              SizedBox(height: 10),
              _SettingsCard(
                child: ListTile(
                  leading: Text(
                    animal?.emoji ?? '🦊',
                    style: TextStyle(fontSize: 26),
                  ),
                  title: Text(AppLocalizations.of(context).profileKampHayvanin),
                  subtitle: Text(
                    animal == null
                        ? AppLocalizations.of(
                            context,
                          ).profileSeniTemsilEdenHayvani
                        : l10n.profileDegistir,
                  ),
                  trailing: Icon(Icons.chevron_right),
                  onTap: profile == null ? null : _pickAnimal,
                ),
              ),
              SizedBox(height: 10),
              _SettingsCard(
                child: ListTile(
                  leading: Icon(Icons.notifications_outlined),
                  title: Text(
                    AppLocalizations.of(context).profileBildirimMerkezi,
                  ),
                  subtitle: Text(
                    AppLocalizations.of(
                      context,
                    ).profileDurtmeHatirlaticiDuyuruVe,
                  ),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationPermissionsScreen(),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10),
              // WP-304: duyurular Bildirim Merkezi'nden buraya taşındı.
              // Merkez bir ayar ekranı (neyi ne zaman alacağım), duyuru ise
              // içerik; aynı listede durunca yeni duyuru fark edilmiyordu.
              _SettingsCard(
                child: ListTile(
                  leading: const Icon(Icons.campaign_outlined),
                  title: Text(l10n.notificationsDuyurular),
                  subtitle: Text(l10n.notificationsUygulamaVeGrubunaOzel),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (unreadAnnouncements > 0) ...[
                        _UnreadDot(
                          key: const Key('announcements-unread-dot'),
                          count: unreadAnnouncements,
                        ),
                        const SizedBox(width: 8),
                      ],
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AnnouncementsScreen(),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10),
              _SettingsCard(
                child: ListTile(
                  leading: Icon(Icons.new_releases_outlined),
                  title: Text(
                    AppLocalizations.of(context).profileSurumVeGuncellemeler,
                  ),
                  subtitle: Text(
                    AppLocalizations.of(
                      context,
                    ).profileYenilikleriVeGecmisSurum,
                  ),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ReleaseNotesScreen()),
                  ),
                ),
              ),
              SizedBox(height: 10),
              _SettingsCard(
                child: ListTile(
                  leading: Icon(Icons.feedback_outlined),
                  title: Text(
                    AppLocalizations.of(context).profileGeriBildirimGonder,
                  ),
                  subtitle: Text(
                    AppLocalizations.of(context).profileHataVeyaOneriniBize,
                  ),
                  trailing: Icon(Icons.chevron_right),
                  onTap: profile == null ? null : _openReportDialog,
                ),
              ),
              SizedBox(height: 10),
              _SettingsCard(
                child: ListTile(
                  key: const Key('reset-introduction-tours'),
                  leading: const Icon(Icons.restart_alt_outlined),
                  title: Text(l10n.profileTanitimTurlariniSifirla),
                  subtitle: Text(l10n.profileTanitimTurlariAciklama),
                  onTap: profile == null ? null : _resetTours,
                ),
              ),
              if (isAdmin) ...[
                SizedBox(height: 10),
                _SettingsCard(
                  child: ListTile(
                    leading: Icon(Icons.admin_panel_settings_outlined),
                    title: Text(AppLocalizations.of(context).profileYonetim),
                    subtitle: Text(
                      AppLocalizations.of(
                        context,
                      ).profileOzetlerVeKullaniciRaporlari,
                    ),
                    trailing: Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(
                      context,
                    ).push(MaterialPageRoute(builder: (_) => AdminScreen())),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    if (widget.embedded) return list;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileAyarlar)),
      body: list,
    );
  }
}

/// Okunmamış duyuru göstergesi — başarım rozetiyle aynı dil: küçük dolu nokta.
class _UnreadDot extends StatelessWidget {
  const _UnreadDot({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      // Ekran okuyucu için nokta tek başına anlamsız; sayıyı sesli ver.
      label: AppLocalizations.of(context).notificationsDuyurular,
      value: '$count',
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: scheme.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Card(clipBehavior: Clip.antiAlias, child: child);
}
