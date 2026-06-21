import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/models/profile.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/group_providers.dart';
import '../../../data/providers/study_providers.dart';

/// Aktif sınıfın bugünkü sıralaması (§3.9 kart). İlk 5 üye; "sen" vurgulu.
class LeaderboardCard extends ConsumerWidget {
  const LeaderboardCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final group = ref.watch(userGroupProvider).value;

    if (group == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Bir sınıfa katılınca sıralama burada görünür.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final sessions = ref.watch(groupSessionsProvider).value ?? const [];
    final members = ref.watch(groupMembersProvider).value ?? const <Profile>[];
    final meId = ref.watch(authStateProvider).value?.id;
    final now = DateTime.now();

    final today = sessions.where((s) => isSameDay(s.day, now));
    final board = leaderboard(today).take(5).toList();

    Profile? memberFor(String id) {
      for (final m in members) {
        if (m.id == id) return m;
      }
      return null;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Sınıf sıralaması', style: theme.textTheme.titleMedium),
                const Spacer(),
                Flexible(
                  child: Text(
                    group.name,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Bugün',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            if (board.isEmpty)
              Text(
                'Bugün henüz kimse çalışmamış.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              )
            else
              for (var i = 0; i < board.length; i++)
                _Row(
                  rank: i + 1,
                  member: memberFor(board[i].key),
                  seconds: board[i].value,
                  isMe: board[i].key == meId,
                ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.rank,
    required this.member,
    required this.seconds,
    required this.isMe,
  });

  final int rank;
  final Profile? member;
  final int seconds;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = member?.displayName.isNotEmpty == true
        ? member!.displayName
        : 'İsimsiz';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '$rank',
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          UserAvatar(
            displayName: name,
            avatarUrl: member?.avatarUrl,
            radius: 14,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isMe ? '$name (sen)' : name,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isMe ? FontWeight.w600 : null,
                color: isMe ? theme.colorScheme.primary : null,
              ),
            ),
          ),
          Text(
            formatHuman(seconds),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
