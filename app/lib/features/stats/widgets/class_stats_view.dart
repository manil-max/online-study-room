import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/models/profile.dart';
import '../../../data/models/study_session.dart';
import '../../classroom/widgets/class_switcher.dart';
import 'daily_bar_chart.dart';
import 'stat_heat_table.dart';

/// Seçilebilir dönem (sınıf leaderboard'u için).
enum _Period { today, week, month }

/// Sınıf (ortak) istatistikleri: dönem seçici + kıyaslamalı sıralama (leaderboard)
/// + sınıf toplamı/ortalaması. Tam şeffaf (project.md §3.4): herkes herkesi görür.
class ClassStatsView extends ConsumerStatefulWidget {
  const ClassStatsView({
    super.key,
    required this.sessions,
    required this.members,
    required this.currentUserId,
    required this.groupName,
    required this.groupGoalMinutes,
  });

  final List<StudySession> sessions;
  final List<Profile> members;
  final String currentUserId;
  final String groupName;
  final int groupGoalMinutes;

  @override
  ConsumerState<ClassStatsView> createState() => _ClassStatsViewState();
}

class _ClassStatsViewState extends ConsumerState<ClassStatsView> {
  _Period _period = _Period.week;

  (DateTime, DateTime) _range(DateTime now) => switch (_period) {
        _Period.today => (dayOf(now), now),
        _Period.week => (startOfWeek(now), now),
        _Period.month => (startOfMonth(now), now),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final (from, to) = _range(now);
    final ranged = inRange(widget.sessions, from, to).toList();

    // userId → saniye (verisi olmayan üyeler 0 ile tamamlanır).
    final totals = {for (final e in leaderboard(ranged)) e.key: e.value};
    final rows = [
      for (final m in widget.members)
        (member: m, seconds: totals[m.id] ?? 0),
    ]..sort((a, b) => b.seconds.compareTo(a.seconds));

    final classTotal = totals.values.fold<int>(0, (s, v) => s + v);
    final memberCount = widget.members.isEmpty ? 1 : widget.members.length;
    final classAvg = classTotal ~/ memberCount;
    final maxSeconds = rows.isEmpty ? 0 : rows.first.seconds;
    // Üye başına çalışma serisi (tüm oturumlardan, dönemden bağımsız).
    final streaks = <String, int>{
      for (final m in widget.members)
        m.id: studyStreak(widget.sessions.where((s) => s.userId == m.id)),
    };
    // Renk-kodlu karşılaştırma tablosu: üye × [Bugün, Hafta, Ay] (her sütun
    // kendi içinde yeşil→kırmızı). Ay toplamına göre sıralı.
    final heatRows = [
      for (final m in widget.members)
        HeatRow(
          label: m.displayName.isEmpty ? 'İsimsiz' : m.displayName,
          avatarUrl: m.avatarUrl,
          highlight: m.id == widget.currentUserId,
          values: [
            totalSeconds(inRange(
                widget.sessions.where((s) => s.userId == m.id), dayOf(now), now)),
            totalSeconds(inRange(widget.sessions.where((s) => s.userId == m.id),
                startOfWeek(now), now)),
            totalSeconds(inRange(widget.sessions.where((s) => s.userId == m.id),
                startOfMonth(now), now)),
          ],
        ),
    ]..sort((a, b) => b.values[2].compareTo(a.values[2]));

    // Grup günlük hedefi: bugünkü grup toplamı + gruba göre seri.
    final goalSeconds = widget.groupGoalMinutes * 60;
    final todayGroupTotal = secondsOnDay(widget.sessions, now);
    final groupStreak = currentStreak(widget.sessions, goalSeconds);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Grup başlığı + grup değiştirici (yalnızca geçiş, basılan yerde açılır).
        Row(
          children: [
            Expanded(
              child: Text(
                widget.groupName,
                style: theme.textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Builder(
              builder: (iconContext) => TextButton.icon(
                onPressed: () =>
                    showClassSwitcher(iconContext, ref, switchOnly: true),
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Değiştir'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: SegmentedButton<_Period>(
            segments: const [
              ButtonSegment(value: _Period.today, label: Text('Bugün')),
              ButtonSegment(value: _Period.week, label: Text('Bu hafta')),
              ButtonSegment(value: _Period.month, label: Text('Bu ay')),
            ],
            selected: {_period},
            onSelectionChanged: (s) => setState(() => _period = s.first),
            showSelectedIcon: false,
          ),
        ),
        const SizedBox(height: 16),
        _GroupGoalCard(
          todaySeconds: todayGroupTotal,
          goalSeconds: goalSeconds,
          streak: groupStreak,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(label: 'Grup toplamı', seconds: classTotal),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryCard(label: 'Kişi başı ort.', seconds: classAvg),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text('Grup günlük trendi (son 7 gün)',
                      style: theme.textTheme.titleSmall),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 150,
                  child: DailyBarChart(days: lastNDays(widget.sessions, 7)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Karşılaştırma tablosu', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: heatRows.isEmpty
                ? Text('Üye yok.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant))
                : StatHeatTable(
                    columns: const ['Bugün', 'Hafta', 'Ay'],
                    rows: heatRows,
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Sıralama', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Bu dönemde henüz çalışma kaydı yok.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          )
        else
          for (var i = 0; i < rows.length; i++)
            _LeaderboardRow(
              rank: i + 1,
              name: rows[i].member.displayName,
              avatarUrl: rows[i].member.avatarUrl,
              seconds: rows[i].seconds,
              maxSeconds: maxSeconds,
              streak: streaks[rows[i].member.id] ?? 0,
              isMe: rows[i].member.id == widget.currentUserId,
            ),
      ],
    );
  }
}

/// Grup günlük hedefi kartı: bugünkü grup toplamının hedefe oranı + grup serisi.
class _GroupGoalCard extends StatelessWidget {
  const _GroupGoalCard({
    required this.todaySeconds,
    required this.goalSeconds,
    required this.streak,
  });

  final int todaySeconds;
  final int goalSeconds;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct =
        goalSeconds <= 0 ? 0.0 : (todaySeconds / goalSeconds).clamp(0.0, 1.0);
    final reached = goalSeconds > 0 && todaySeconds >= goalSeconds;
    final fire = subjectColor('chart-5');
    final barColor =
        reached ? subjectColor('chart-2') : theme.colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag_outlined, size: 20, color: barColor),
                const SizedBox(width: 6),
                Text('Bugünkü grup hedefi',
                    style: theme.textTheme.titleMedium),
                const Spacer(),
                if (streak > 0) ...[
                  Icon(Icons.local_fire_department, size: 18, color: fire),
                  const SizedBox(width: 2),
                  Text('$streak gün',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: fire, fontWeight: FontWeight.w700)),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${formatHuman(todaySeconds)} / ${formatHuman(goalSeconds)}',
                    style: theme.textTheme.bodyMedium),
                Text('%${(pct * 100).round()}',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: barColor, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 10,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            if (reached) ...[
              const SizedBox(height: 8),
              Text('Grup bugünkü hedefini tuttu! 🎉',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: subjectColor('chart-2'))),
            ],
          ],
        ),
      ),
    );
  }
}

/// Sınıf özet kartı (toplam / ortalama).
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.seconds});

  final String label;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text(formatHuman(seconds), style: theme.textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}

/// Tek bir leaderboard satırı: sıra, isim, oransal çubuk ve süre.
class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.name,
    required this.avatarUrl,
    required this.seconds,
    required this.maxSeconds,
    required this.streak,
    required this.isMe,
  });

  final int rank;
  final String name;
  final String? avatarUrl;
  final int seconds;
  final int maxSeconds;
  final int streak;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = maxSeconds <= 0 ? 0.0 : seconds / maxSeconds;
    final medal = switch (rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => '$rank.',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(medal, style: theme.textTheme.titleMedium),
          ),
          const SizedBox(width: 8),
          UserAvatar(displayName: name, avatarUrl: avatarUrl, radius: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        isMe ? '$name (sen)' : name,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (streak > 0) ...[
                          Icon(Icons.local_fire_department,
                              size: 14, color: subjectColor('chart-5')),
                          const SizedBox(width: 2),
                          Text('$streak',
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: subjectColor('chart-5'))),
                          const SizedBox(width: 8),
                        ],
                        Text(formatHuman(seconds),
                            style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    color: isMe
                        ? theme.colorScheme.primary
                        : theme.colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
