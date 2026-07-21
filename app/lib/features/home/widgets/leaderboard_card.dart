import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/crowned_avatar.dart';
import '../../../data/models/profile.dart';
import '../../classroom/widgets/class_switcher.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/analytics_query_providers.dart';
import '../../../data/providers/group_providers.dart';
import '../../../data/providers/study_providers.dart';
import '../../profile/widgets/profile_tap.dart';
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
        title: AppLocalizations.of(context).homeGrupSiralamasi,
        onCreateGroup: () => createGroupFlow(context, ref),
        onJoinGroup: () => joinGroupFlow(context, ref),
      );
    }

    final stats = ref.watch(groupDailyStatsProvider).value ?? const [];
    final members = ref.watch(groupMembersProvider).value ?? const <Profile>[];
    final meId = ref.watch(authStateProvider).value?.id;
    final alphaWins =
        ref.watch(groupAlphaScoresProvider).value ?? const <String, int>{};

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
          // kaydırılır (Expanded yerine düz Column). Sınırsız yükseklikte (ListView)
          // Expanded kullanılmamalı, bu yüzden fill = false olmalı.
          final fill =
              isHeightBounded && availableHeight >= headerHeight + rowHeight;

          final int count;
          if (fill) {
            count = ((availableHeight - headerHeight) / rowHeight)
                .floor()
                .clamp(1, 15);
          } else if (isHeightBounded) {
            count = 3;
          } else {
            count = 10; // Sınırsız yükseklikte en fazla 10 kişi gösterelim.
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

          // WP-253: üye başına seri rozeti kaldırıldı — bkz. class_stats_view.
          // Bu karttaki ateş ikonu artık YALNIZ grup hedef serisini
          // (`groupStreak`) anlatıyor; iki anlam çakışması bitti.

          final headerChildren = <Widget>[
            Row(
              children: [
                Flexible(
                  child: Text(
                    AppLocalizations.of(context).homeSiralama,
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
                    AppLocalizations.of(context).homeGrupHedefi,
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
            alphaWins: alphaWins[board[i].key] ?? 0,
            isMe: board[i].key == meId,
            isCompact: isCompact,
          );

          final emptyText = Text(
            AppLocalizations.of(context).homeBugunHenuzKimseCalismamis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );

          // Kısa kart / ListView (Gruplar): nested scroll yok (WP-172).
          // Home sonlu kısa hücrede kart içi kaydırma korunur.
          if (!fill) {
            final column = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ...headerChildren,
                if (board.isEmpty)
                  emptyText
                else
                  for (var i = 0; i < board.length; i++) rowFor(i),
              ],
            );
            return Padding(
              padding: const EdgeInsets.all(16),
              child: isHeightBounded
                  ? SingleChildScrollView(child: column)
                  : column,
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
    required this.alphaWins,
    required this.isMe,
    this.isCompact = false,
  });

  final int rank;
  final Profile? member;
  final int seconds;
  final int alphaWins;
  final bool isMe;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = (member != null && !member!.isActive)
        ? AppLocalizations.of(context).homeEskiGrupUyesi
        : (member?.displayName.isNotEmpty == true
              ? member!.displayName
              : AppLocalizations.of(context).homeIsimsiz);
    // Üzerine gelince özet; tıklayınca sosyal profil (isim/PP her yerde).
    final brief = StringBuffer(
      '$rank. · ${AppLocalizations.of(context).homeBugun} '
      '${formatHuman(seconds)}',
    );
    if (alphaWins > 0) {
      brief.write(' · 🐺$alphaWins');
    }
    final canOpenProfile = member != null && member!.isActive;
    return Tooltip(
      message: brief.toString(),
      waitDuration: const Duration(milliseconds: 350),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: canOpenProfile
            ? () => openMemberProfile(context, member!)
            : null,
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
              if (member != null)
                LiveCrownedAvatar(
                  userId: member!.id,
                  displayName: name,
                  avatarUrl: member!.avatarUrl,
                  radius: 14,
                )
              else
                CrownedAvatar(displayName: name, radius: 14),
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
                if (alphaWins > 0) ...[
                  const Text('🐺', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 2),
                  Text(
                    '$alphaWins',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (alphaWins > 0) ...[
                            const Text('🐺', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 2),
                            Text(
                              '$alphaWins',
                              style: theme.textTheme.labelSmall,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            formatHuman(seconds),
                            maxLines: 1,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
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
}
