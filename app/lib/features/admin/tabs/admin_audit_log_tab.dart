import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

class AdminAuditLogTab extends ConsumerWidget {
  const AdminAuditLogTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(adminAuditLogsProvider);
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
              return Card(
                child: ListTile(
                  title: Text(
                    l10n.adminLogactionHedefLogtargetuserid(
                      log.targetUserId ?? l10n.adminYok,
                      log.action,
                    ),
                  ),
                  subtitle: Text(
                    l10n.adminGerekceLogreasonntarihLogcreatedat(
                      log.reason,
                      log.createdAt.toString(),
                    ),
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
