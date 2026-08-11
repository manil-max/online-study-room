import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-D (`docs/design/ADMIN-PANEL-PLAN.md` §2.1 sonu / §5 WP-D kabul 3) —
/// denetim kaydi.
///
/// 🔴 Duzeltilen kusur: `AdminAuditLog` modeli `adminId` ve `targetUserEmail`
/// alanlarini **ayristiriyordu** (`admin_audit_log.dart:18,21`) ama sekme
/// (`admin_audit_log_tab.dart:36-47`) ikisini de **cizmiyordu**. Ekranda ham
/// bir hedef UUID'si, eylem, gerekce ve tarih vardi; kaydin "kim yapti"
/// sutunu — yani hesap verebilirligin tamami — gorunmuyordu.
class AdminAuditLogTab extends ConsumerWidget {
  const AdminAuditLogTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(adminAuditLogsProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminAuditLogsProvider);
        await ref.read(adminAuditLogsProvider.future);
      },
      child: logs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) =>
            Center(child: Text(l10n.authBeklenmeyenBirHataOlustu)),
        data: (items) {
          if (items.isEmpty) {
            return Center(child: Text(l10n.adminKayitBulunamadi));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final log = items[index];
              // WP-464: silinen yonetici icin `0114` `admin_id`yi NULL'lar;
              // o zaman "Yok" yazar, satiri gizlemez.
              final admin = log.adminId ?? l10n.adminYok;
              final target =
                  log.targetUserEmail ?? log.targetUserId ?? l10n.adminYok;
              return Card(
                child: ListTile(
                  isThreeLine: true,
                  title: Text(log.action),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.adminDenetimYonetici(admin)),
                      Text(l10n.adminDenetimHedef(target)),
                      // E-posta cizildiginde ham kimlik kaybolmasin: destek
                      // yazismasinda kullanilan sey odur.
                      if (log.targetUserEmail != null &&
                          log.targetUserId != null)
                        Text(
                          l10n.adminIdGroupid(log.targetUserId!),
                          style: theme.textTheme.bodySmall,
                        ),
                      Text(
                        l10n.adminGerekceLogreasonntarihLogcreatedat(
                          log.reason,
                          log.createdAt.toString(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
