import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/anchored_menu.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/models/profile.dart';
import '../../classroom/widgets/class_switcher.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/group_providers.dart';
import '../../../data/providers/study_providers.dart';
import '../dashboard_card.dart';
import 'group_card_shell.dart';

/// Aktif grubun bugünkü sıralaması (§3.9 kart). "sen" vurgulu. Boyuta göre üye
/// sayısı: küçük 3, orta 5, büyük 10.
class LeaderboardCard extends ConsumerWidget {
  const LeaderboardCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final group = ref.watch(userGroupProvider).value;

    if (group == null) {
      return GroupCardShell(
        title: 'Grup sıralaması',
        onCreateGroup: () => createGroupFlow(context, ref),
        onJoinGroup: () => joinGroupFlow(context, ref),
      );
    }

    final stats = ref.watch(groupDailyStatsProvider).value ?? const [];
    final members = ref.watch(groupMembersProvider).value ?? const <Profile>[];
    final meId = ref.watch(authStateProvider).value?.id;

    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 220;
          final availableHeight = constraints.maxHeight;
          final isHeightBounded = availableHeight.isFinite;

          // Sabit başlık yüksekliği tahmini (dikey padding dahil): başlık satırı +
          // (yalnız geniş kartta) grup hedefi bloğu + listeden önceki boşluk.
          const rowHeight = 36.0;
          final headerHeight = 32 + 24 + 12 + (isCompact ? 0.0 : 43.0);

          // Kart, başlık + en az bir satırı sığdıramayacak kadar kısaysa TÜM içerik
          // kaydırılır (Expanded yerine düz Column) → hiçbir boyutta taşma olmaz.
          final fill =
              !isHeightBounded || availableHeight >= headerHeight + rowHeight;

          final int count;
          if (fill && isHeightBounded) {
            count = ((availableHeight - headerHeight) / rowHeight)
                .floor()
                .clamp(1, 15);
          } else if (isHeightBounded) {
            count = 3;
          } else {
            count = 5;
          }

          // Bugünün sıralaması (userId → saniye), büyükten küçüğe.
          final todayByUser = todaySecondsByUser(stats);

          // Grup günlük hedefi: grubun bugünkü TOPLAM çalışması / hedef + grup serisi.
          final goalSeconds = group.dailyGoalMinutes * 60;
          final groupTodayTotal = todayByUser.values.fold<int>(
            0,
            (a, v) => a + v,
          );
          final groupGoalPct = goalSeconds > 0
              ? (groupTodayTotal / goalSeconds).clamp(0.0, 1.0)
              : 0.0;
          final groupStreak = currentStreak(
            const [],
            goalSeconds,
            totals: groupDayTotals(stats),
          );

          Profile? memberFor(String id) {
            for (final m in members) {
              if (m.id == id) return m;
            }
            return null;
          }

          final board =
              (todayByUser.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value)))
                  .take(count)
                  .toList();

          final streaks = <String, int>{
            for (final e in board)
              e.key: studyStreak(const [], totals: userDayTotals(stats, e.key)),
          };

          final headerChildren = <Widget>[
            Row(
              children: [
                Flexible(
                  child: Text(
                    'Sıralama',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const Spacer(),
                if (!isCompact)
                  Flexible(
                    child: Text(
                      group.name,
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            if (!isCompact) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.flag_outlined,
                    size: 15,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Grup hedefi',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (groupStreak > 0) ...[
                    Icon(
                      Icons.local_fire_department,
                      size: 14,
                      color: subjectColor('chart-5'),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '$groupStreak',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: subjectColor('chart-5'),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    '%${(groupGoalPct * 100).round()}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: groupGoalPct,
                  minHeight: 7,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  color: groupGoalPct >= 1.0
                      ? subjectColor('chart-2')
                      : theme.colorScheme.primary,
                ),
              ),
            ],
            const SizedBox(height: 12),
          ];

          Widget rowFor(int i) => _Row(
            rank: i + 1,
            member: memberFor(board[i].key),
            seconds: board[i].value,
            streak: streaks[board[i].key] ?? 0,
            isMe: board[i].key == meId,
            isCompact: isCompact,
          );

          final emptyText = Text(
            'Bugün henüz kimse çalışmamış.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );

          // Kısa kart: Expanded yerine düz Column + dış kaydırma (taşma önlenir).
          if (!fill) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...headerChildren,
                    if (board.isEmpty)
                      emptyText
                    else
                      for (var i = 0; i < board.length; i++) rowFor(i),
                  ],
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...headerChildren,
                if (board.isEmpty)
                  emptyText
                else
                  Expanded(
                    child: ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: board.length,
                      itemBuilder: (context, i) => rowFor(i),
                    ),
                  ),
              ],
            ),
          );
        },
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
    this.isCompact = false,
  });

  final int rank;
  final Profile? member;
  final int seconds;
  final int streak;
  final bool isMe;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = (member != null && !member!.isActive)
        ? 'Eski Grup Üyesi'
        : (member?.displayName.isNotEmpty == true
              ? member!.displayName
              : 'İsimsiz');
    // Üzerine gelince basit özet (tooltip); tıklayınca tıklanan yerde detay.
    final brief = StringBuffer('$rank. · Bugün ${formatHuman(seconds)}');
    if (streak > 0) brief.write(' · 🔥$streak gün');
    return Tooltip(
      message: brief.toString(),
      waitDuration: const Duration(milliseconds: 350),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTapDown: (d) => _showDetailAt(context, name, d.globalPosition),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  '$rank',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              UserAvatar(
                displayName: name,
                avatarUrl: member?.avatarUrl,
                radius: 14,
              ),
              const SizedBox(width: 8),
              if (!isCompact) ...[
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
                  Icon(
                    Icons.local_fire_department,
                    size: 14,
                    color: subjectColor('chart-5'),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '$streak',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: subjectColor('chart-5'),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  formatHuman(seconds),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ] else
                // Dar hücrede ad gizli; süre kalan alana yaslanır ve gerekiyorsa
                // küçülerek taşmayı önler.
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formatHuman(seconds),
                        maxLines: 1,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tıklanan noktada açılan detay paneli (alttan açılan pencere yerine §3.12).
  void _showDetailAt(BuildContext context, String name, Offset position) {
    final theme = Theme.of(context);
    showMenuAtPosition<void>(
      context: context,
      globalPosition: position,
      items: [
        PopupMenuItem<void>(
          enabled: false,
          child: SizedBox(
            width: 220,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    UserAvatar(
                      displayName: name,
                      avatarUrl: member?.avatarUrl,
                      radius: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isMe ? '$name (sen)' : name,
                        style: theme.textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoRow(label: 'Sıralama', value: '$rank.'),
                _InfoRow(label: 'Bugünkü çalışma', value: formatHuman(seconds)),
                if (streak > 0)
                  _InfoRow(label: 'Çalışma serisi', value: '$streak gün'),
              ],
            ),
          ),
        ),
      ],
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
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(value, style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}
