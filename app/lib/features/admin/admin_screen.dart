import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/data/providers/admin_providers.dart';
import 'tabs/admin_announcements_tab.dart';
import 'tabs/admin_audit_log_tab.dart';
import 'tabs/admin_dashboard_tab.dart';
import 'tabs/admin_groups_tab.dart';
import 'tabs/admin_reports_tab.dart';
import 'tabs/admin_users_tab.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(adminIsSuperAdminProvider);

    return isAdmin.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Yönetim')),
        body: _AdminError(message: error.toString()),
      ),
      data: (allowed) {
        if (!allowed) {
          return Scaffold(
            appBar: AppBar(title: const Text('Yönetim')),
            body: const _AdminError(
              icon: Icons.lock_outline,
              message: 'Bu alan yalnızca süper-admin içindir.',
            ),
          );
        }

        return DefaultTabController(
          length: 6,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Yönetim Paneli'),
              bottom: const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'Özet', icon: Icon(Icons.dashboard)),
                  Tab(text: 'Kullanıcılar', icon: Icon(Icons.people)),
                  Tab(text: 'Gruplar', icon: Icon(Icons.groups)),
                  Tab(text: 'Raporlar', icon: Icon(Icons.report)),
                  Tab(text: 'Duyurular', icon: Icon(Icons.campaign)),
                  Tab(text: 'Denetim', icon: Icon(Icons.admin_panel_settings)),
                ],
              ),
            ),
            body: const TabBarView(
              children: [
                AdminDashboardTab(),
                AdminUsersTab(),
                AdminGroupsTab(),
                AdminReportsTab(),
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
