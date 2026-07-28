import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../core/animals/camp_animal.dart';
import '../../core/l10n/app_locale.dart';
import '../../core/tour/tour_controller.dart';
import '../../core/widgets/safe_screen_padding.dart';
import '../../data/providers/admin_providers.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/group_providers.dart';
import '../../data/providers/notification_providers.dart';
import '../admin/admin_screen.dart';
import '../desktop/desktop_surface.dart';
import '../notifications/announcements_screen.dart';
import 'widgets/unread_announcement_dot.dart';
import '../notifications/notification_permissions_screen.dart';
import '../onboarding/onboarding_prefs.dart';
import '../safety/blocked_users_screen.dart';
import '../support/faq_screen.dart';
import '../updater/release_notes_screen.dart';
import 'about_screen.dart';
import 'account_settings_screen.dart';
import 'appearance_screen.dart';
import 'data_export_screen.dart';
import 'legal_center_screen.dart';
import 'widgets/camp_animal_picker.dart';
import 'widgets/report_issue_dialog.dart';

/// Ayarlar: davranışları değiştirmeden, bulunabilir bilgi mimarisi sunar.
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
    await ref.read(onboardingCompletedProvider.notifier).reset();
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
              _SettingsSection(
                title: l10n.settingsSectionAppearance,
                children: [
                  _SettingsCard(
                    child: ListTile(
                      leading: const Icon(Icons.color_lens_outlined),
                      title: Text(l10n.profileGorunumVeAtmosferTemalari),
                      subtitle: Text(l10n.profileGorunumVeAtmosfer),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => AppearanceScreen()),
                      ),
                    ),
                  ),
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
                ],
              ),
              _SettingsSection(
                title: l10n.settingsSectionNotifications,
                children: [
                  _SettingsCard(
                    child: ListTile(
                      leading: const Icon(Icons.notifications_outlined),
                      title: Text(l10n.profileBildirimMerkezi),
                      subtitle: Text(l10n.profileDurtmeHatirlaticiDuyuruVe),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const NotificationPermissionsScreen(),
                        ),
                      ),
                    ),
                  ),
                  _SettingsCard(
                    child: ListTile(
                      leading: const Icon(Icons.campaign_outlined),
                      title: Text(l10n.notificationsDuyurular),
                      subtitle: Text(l10n.notificationsUygulamaVeGrubunaOzel),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (unreadAnnouncements > 0) ...[
                            UnreadAnnouncementDot(
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
                ],
              ),
              _SettingsSection(
                title: l10n.settingsSectionAccount,
                children: [
                  _SettingsCard(
                    child: ListTile(
                      leading: const Icon(Icons.manage_accounts),
                      title: Text(l10n.profileHesabimiYonet),
                      subtitle: Text(l10n.profileEpostaSifreVeGuvenli),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AccountSettingsScreen(),
                        ),
                      ),
                    ),
                  ),
                  _SettingsCard(
                    child: ListTile(
                      leading: const Icon(Icons.download_outlined),
                      title: Text(l10n.exportMyData),
                      subtitle: Text(l10n.exportMyDataSubtitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DataExportScreen(),
                        ),
                      ),
                    ),
                  ),
                  if (isAdmin)
                    _SettingsCard(
                      child: ListTile(
                        leading: const Icon(
                          Icons.admin_panel_settings_outlined,
                        ),
                        title: Text(l10n.profileYonetim),
                        subtitle: Text(l10n.profileOzetlerVeKullaniciRaporlari),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => AdminScreen()),
                        ),
                      ),
                    ),
                ],
              ),
              _SettingsSection(
                title: l10n.settingsSectionStudyPreferences,
                children: [
                  _SettingsCard(
                    child: ListTile(
                      leading: Text(
                        animal?.emoji ?? '🦊',
                        style: const TextStyle(fontSize: 26),
                      ),
                      title: Text(l10n.profileKampHayvanin),
                      subtitle: Text(
                        animal == null
                            ? l10n.profileSeniTemsilEdenHayvani
                            : l10n.profileDegistir,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: profile == null ? null : _pickAnimal,
                    ),
                  ),
                  _SettingsCard(
                    child: ListTile(
                      key: const Key('reset-introduction-tours'),
                      leading: const Icon(Icons.restart_alt_outlined),
                      title: Text(l10n.profileTanitimTurlariniSifirla),
                      subtitle: Text(l10n.profileTanitimTurlariAciklama),
                      onTap: profile == null ? null : _resetTours,
                    ),
                  ),
                ],
              ),
              _SettingsSection(
                title: l10n.settingsSectionPrivacySecurity,
                children: [
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
                ],
              ),
              _SettingsSection(
                title: l10n.settingsSectionAboutLegal,
                children: [
                  _SettingsCard(
                    child: ListTile(
                      key: const Key('settings-faq'),
                      leading: const Icon(Icons.help_outline),
                      title: Text(l10n.faqTitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const FaqScreen()),
                      ),
                    ),
                  ),
                  _SettingsCard(
                    child: ListTile(
                      leading: const Icon(Icons.new_releases_outlined),
                      title: Text(l10n.profileSurumVeGuncellemeler),
                      subtitle: Text(l10n.profileYenilikleriVeGecmisSurum),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ReleaseNotesScreen()),
                      ),
                    ),
                  ),
                  _SettingsCard(
                    child: ListTile(
                      leading: const Icon(Icons.feedback_outlined),
                      title: Text(l10n.profileGeriBildirimGonder),
                      subtitle: Text(l10n.profileHataVeyaOneriniBize),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: profile == null ? null : _openReportDialog,
                    ),
                  ),
                  _SettingsCard(
                    child: ListTile(
                      key: const Key('settings-about'),
                      leading: const Icon(Icons.info_outline),
                      title: Text(l10n.aboutTitle),
                      subtitle: Text(l10n.aboutSubtitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      ),
                    ),
                  ),
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
                ],
              ),
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

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Card(clipBehavior: Clip.antiAlias, child: child);
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index != children.length - 1) const SizedBox(height: 10),
        ],
      ],
    ),
  );
}
