import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'tabs/admin_announcements_tab.dart';
import 'tabs/admin_audit_log_tab.dart';
import 'tabs/admin_dashboard_tab.dart';
import 'tabs/admin_groups_tab.dart';
import 'tabs/admin_moderation_tab.dart';
import 'tabs/admin_reports_tab.dart';
import 'tabs/admin_users_tab.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(adminIsSuperAdminProvider);
    final l10n = AppLocalizations.of(context);

    return isAdmin.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.adminYonetim)),
        body: _AdminError(message: l10n.authBeklenmeyenBirHataOlustu),
      ),
      data: (allowed) {
        if (!allowed) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.adminYonetim)),
            body: _AdminError(
              icon: Icons.lock_outline,
              message: l10n.adminBuAlanYalnizcaSuperadmin,
            ),
          );
        }

        return DefaultTabController(
          length: 7,
          child: Scaffold(
            appBar: AppBar(
              title: Text(l10n.adminYonetimPaneli),
              bottom: TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: l10n.adminOzet, icon: const Icon(Icons.dashboard)),
                  Tab(
                    text: l10n.adminKullanicilar,
                    icon: const Icon(Icons.people),
                  ),
                  Tab(text: l10n.adminGruplar, icon: const Icon(Icons.groups)),
                  Tab(text: l10n.adminRaporlar, icon: const Icon(Icons.report)),
                  const Tab(
                    text: 'UGC',
                    icon: Icon(Icons.flag_outlined),
                  ),
                  Tab(
                    text: l10n.adminDuyurular,
                    icon: const Icon(Icons.campaign),
                  ),
                  Tab(
                    text: l10n.adminDenetim,
                    icon: const Icon(Icons.admin_panel_settings),
                  ),
                ],
              ),
            ),
            body: const TabBarView(
              children: [
                AdminDashboardTab(),
                AdminUsersTab(),
                AdminGroupsTab(),
                AdminReportsTab(),
                AdminModerationTab(),
                AdminAnnouncementsTab(),
                AdminAuditLogTab(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AdminError extends StatelessWidget {
  const _AdminError({required this.message, this.icon = Icons.error_outline});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
