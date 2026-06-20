import 'package:flutter/material.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/models/profile.dart';
import '../../../data/models/study_session.dart';

/// Seçilebilir dönem (sınıf leaderboard'u için).
enum _Period { today, week, month }

/// Sınıf (ortak) istatistikleri: dönem seçici + kıyaslamalı sıralama (leaderboard)
/// + sınıf toplamı/ortalaması. Tam şeffaf (project.md §3.4): herkes herkesi görür.
class ClassStatsView extends StatefulWidget {
  const ClassStatsView({
    super.key,
    required this.sessions,
    required this.members,
    required this.currentUserId,
  });

  final List<StudySession> sessions;
  final List<Profile> members;
  final String currentUserId;

  @override
  State<ClassStatsView> createState() => _ClassStatsViewState();
}

class _ClassStatsViewState extends State<ClassStatsView> {
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
        Row(
          children: [
            Expanded(
              child: _SummaryCard(label: 'Sınıf toplamı', seconds: classTotal),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryCard(label: 'Kişi başı ort.', seconds: classAvg),
            ),
          ],
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
              seconds: rows[i].seconds,
              maxSeconds: maxSeconds,
              isMe: rows[i].member.id == widget.currentUserId,
            ),
      ],
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
    required this.seconds,
    required this.maxSeconds,
    required this.isMe,
  });

  final int rank;
  final String name;
  final int seconds;
  final int maxSeconds;
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
                    Text(formatHuman(seconds),
                        style: theme.textTheme.bodyMedium),
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
