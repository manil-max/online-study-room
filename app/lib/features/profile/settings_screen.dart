import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/animals/camp_animal.dart';
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
import 'account_settings_screen.dart';
import 'appearance_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final gridDensity = ref.watch(dashboardGridDensityProvider);
    final gridColumns = ref.watch(dashboardGridColumnsProvider);
    final profile = ref.watch(authStateProvider).value;
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
                  value: profile?.monthlyReportOptIn ?? true,
                  onChanged: profile == null
                      ? null
                      : (val) {
                          ref
                              .read(authRepositoryProvider)
                              .updateMonthlyReportOptIn(val);
                        },
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
