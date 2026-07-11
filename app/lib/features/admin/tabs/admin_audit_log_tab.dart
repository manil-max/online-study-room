import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/data/providers/admin_providers.dart';

class AdminAuditLogTab extends ConsumerWidget {
  const AdminAuditLogTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(adminAuditLogsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminAuditLogsProvider);
        await ref.read(adminAuditLogsProvider.future);
      },
      child: logs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text(err.toString())),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('Kayıt bulunamadı.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final log = items[index];
              return Card(
                child: ListTile(
                  title: Text('${log.action} - Hedef: ${log.targetUserId ?? "Yok"}'),
                  subtitle: Text('Gerekçe: ${log.reason}\nTarih: ${log.createdAt}'),
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
