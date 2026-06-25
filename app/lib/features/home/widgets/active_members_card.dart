import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/second_ticker.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/models/presence.dart';
import '../../../data/models/profile.dart';
import '../../../data/providers/group_providers.dart';
import '../../../data/providers/presence_providers.dart';
import '../dashboard_card.dart';
import 'group_card_shell.dart';

/// "Şu an çalışanlar" kartı (§3.11): grupta o an **çalışıyor** durumundaki üyeler,
/// canlı geçen süreyle. Geçen süre her satırda kendi `SecondTicker`'ı ile
/// güncellenir; kart yalnızca presence/üye verisi değişince yeniden çizilir.
class ActiveMembersCard extends ConsumerWidget {
  const ActiveMembersCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final group = ref.watch(userGroupProvider).value;
    if (group == null) return const GroupCardShell(title: 'Şu an çalışanlar');

    final presence = ref.watch(groupPresenceProvider).value ?? const [];
    final members = ref.watch(groupMembersProvider).value ?? const <Profile>[];
    final active = presence
        .where((p) => p.status == PresenceStatus.studying)
        .toList()
      // En uzun süredir çalışan üstte (startedAt'e göre; saniyeden bağımsız).
      ..sort((a, b) => (a.startedAt ?? DateTime.now())
          .compareTo(b.startedAt ?? DateTime.now()));

    final memberById = {for (final m in members) m.id: m};

    final green = subjectColor('chart-2');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Şu an çalışanlar', style: theme.textTheme.titleMedium),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${active.length} aktif',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: green, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (active.isEmpty)
              Text('Şu an çalışan kimse yok.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant))
            else
              for (final p in active)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: _ActiveRow(
                    name: memberById[p.userId]?.displayName ?? 'İsimsiz',
                    avatarUrl: memberById[p.userId]?.avatarUrl,
                    startedAt: p.startedAt,
                    green: green,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _ActiveRow extends StatelessWidget {
  const _ActiveRow({
    required this.name,
    required this.avatarUrl,
    required this.startedAt,
    required this.green,
  });

  final String name;
  final String? avatarUrl;
  final DateTime? startedAt;
  final Color green;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Stack(
          children: [
            UserAvatar(displayName: name, avatarUrl: avatarUrl, radius: 16),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: green,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.colorScheme.surface, width: 2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(name,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500)),
        ),
        // Yalnızca bu metin saniyede bir kendini yeniler.
        SecondTicker(
          builder: (_, now) {
            final elapsed =
                startedAt == null ? 0 : now.difference(startedAt!).inSeconds;
            return Text(formatHms(elapsed),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: green,
                  fontFeatures: const [],
                ));
          },
        ),
      ],
    );
  }
}
