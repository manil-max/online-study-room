import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/animals/camp_animal.dart';
import '../../core/l10n/app_locale.dart';
import '../../core/widgets/safe_screen_padding.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/admin_providers.dart';
import '../../data/providers/group_providers.dart';
import '../admin/admin_screen.dart';
import '../clock/clock_widgets_screen.dart';
import '../desktop/desktop_surface.dart';
import '../home/dashboard_providers.dart';
import '../notifications/notification_center_screen.dart';
import '../updater/release_notes_screen.dart';
import '../safety/blocked_users_screen.dart';
import '../stats/analytics/analytics_flag.dart';
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
  bool? _monthlyReportOptInOverride;
  bool _isSavingMonthlyReportPreference = false;

  Future<void> _setMonthlyReportOptIn(bool value, bool previousValue) async {
    setState(() {
      _monthlyReportOptInOverride = value;
      _isSavingMonthlyReportPreference = true;
    });
    try {
      await ref.read(authRepositoryProvider).updateMonthlyReportOptIn(value);
      // Supabase stream'i profil satırı güncellemesinde olay üretmez; yeni değeri
      // sunucudan yeniden okuyup kalıcı tercihi doğrula.
      ref.invalidate(authStateProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _monthlyReportOptInOverride = previousValue);
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingMonthlyReportPreference = false);
      }
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final gridDensity = ref.watch(dashboardGridDensityProvider);
    final gridColumns = ref.watch(dashboardGridColumnsProvider);
    final language = ref.watch(appLanguageProvider);
    final profile = ref.watch(authStateProvider).value;
    final monthlyReportOptIn =
        _monthlyReportOptInOverride ?? profile?.monthlyReportOptIn ?? true;
    final analyticsGridOn = ref.watch(analyticsGridV1Provider);
    final isAdmin = ref.watch(adminIsSuperAdminProvider).value ?? false;
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
              SizedBox(height: 10),
              _SettingsCard(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: DropdownButtonFormField<DashboardGridDensity>(
                    key: ValueKey(gridDensity),
                    initialValue: gridDensity,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(
                        context,
                      ).profileIzgaraYogunlugu,
                      helperText: l10n.profileBuCihazdaGridcolumnsSutun(
                        '$gridColumns',
                      ),
                      prefixIcon: Icon(Icons.grid_view_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final density in DashboardGridDensity.values)
                        DropdownMenuItem(
                          value: density,
                          child: Text(density.label),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        ref
                            .read(dashboardGridDensityProvider.notifier)
                            .set(value);
                      }
                    },
                  ),
                ),
              ),
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
                      builder: (_) => NotificationCenterScreen(),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10),
              _SettingsCard(
                child: ListTile(
                  leading: Icon(Icons.widgets_outlined),
                  title: Text(
                    AppLocalizations.of(context).profileWidgetVeAlarmIzinleri,
                  ),
                  subtitle: Text(l10n.notificationsCihazIzinleri),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ClockWidgetsScreen()),
                  ),
                ),
              ),
              SizedBox(height: 10),
              _SettingsCard(
                child: SwitchListTile(
                  secondary: Icon(Icons.mark_email_unread_outlined),
                  title: Text(
                    AppLocalizations.of(
                      context,
                    ).profileAylikCalismaRaporuEposta,
                  ),
                  subtitle: Text(l10n.profileOzetlerVeKullaniciRaporlari),
                  value: monthlyReportOptIn,
                  onChanged: profile == null || _isSavingMonthlyReportPreference
                      ? null
                      : (value) => _setMonthlyReportOptIn(
                          value,
                          profile.monthlyReportOptIn,
                        ),
                ),
              ),
              SizedBox(height: 10),
              // ADIM 1: analytics_grid_v1 flag — default kapalı; setEnabled yoksa ızgara açılamıyor
              _SettingsCard(
                child: Semantics(
                  label: l10n.analyticsGridBetaTitle,
                  toggled: analyticsGridOn,
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    secondary: const Icon(Icons.grid_view_rounded),
                    title: Text(l10n.analyticsGridBetaTitle),
                    subtitle: Text(l10n.analyticsGridBetaSubtitle),
                    value: analyticsGridOn,
                    onChanged: (value) => ref
                        .read(analyticsGridV1Provider.notifier)
                        .setEnabled(value),
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
                  leading: Icon(Icons.shortcut_outlined),
                  title: Text(
                    AppLocalizations.of(
                      context,
                    ).profileUygulamaKisayollariRutinler,
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

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Card(clipBehavior: Clip.antiAlias, child: child);
}
