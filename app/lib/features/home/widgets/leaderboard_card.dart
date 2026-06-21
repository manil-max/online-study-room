import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/theme/subject_colors.dart';
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
            'Bir gruba katılınca sıralama burada görünür.',
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
    // Her üyenin çalışma serisi (üst üste çalıştığı gün), tüm grup oturumlarından.
    final streaks = <String, int>{
      for (final e in board)
        e.key: studyStreak(sessions.where((s) => s.userId == e.key)),
    };

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
                Text('Grup sıralaması', style: theme.textTheme.titleMedium),
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
                  streak: streaks[board[i].key] ?? 0,
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
    required this.streak,
    required this.isMe,
  });

  final int rank;
  final Profile? member;
  final int seconds;
  final int streak;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = member?.displayName.isNotEmpty == true
        ? member!.displayName
        : 'İsimsiz';
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _showDetail(context, name),
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
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
          if (streak > 0) ...[
            Icon(Icons.local_fire_department,
                size: 14, color: subjectColor('chart-5')),
            const SizedBox(width: 2),
            Text('$streak',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: subjectColor('chart-5'))),
            const SizedBox(width: 8),
          ],
          Text(
            formatHuman(seconds),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      ),
    );
  }

  void _showDetail(BuildContext context, String name) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    UserAvatar(
                        displayName: name,
                        avatarUrl: member?.avatarUrl,
                        radius: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(isMe ? '$name (sen)' : name,
                          style: theme.textTheme.titleMedium),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _InfoRow(label: 'Sıralama', value: '$rank.'),
                _InfoRow(
                    label: 'Bugünkü çalışma', value: formatHuman(seconds)),
                if (streak > 0)
                  _InfoRow(label: 'Çalışma serisi', value: '$streak gün'),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Text(value, style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}
