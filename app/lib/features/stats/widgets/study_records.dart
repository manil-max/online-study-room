import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/models/study_session.dart';
import '../../../data/models/subject.dart';
import '../../../data/providers/subject_providers.dart';

List<String> _months(BuildContext context) => [
  AppLocalizations.of(context).statsOca,
  AppLocalizations.of(context).statsSub,
  AppLocalizations.of(context).statsMar,
  AppLocalizations.of(context).statsNis,
  AppLocalizations.of(context).statsMay,
  AppLocalizations.of(context).statsHaz,
  AppLocalizations.of(context).statsTem,
  AppLocalizations.of(context).statsAgu,
  AppLocalizations.of(context).statsEyl,
  AppLocalizations.of(context).statsEki,
  AppLocalizations.of(context).statsKas,
  AppLocalizations.of(context).statsAra,
];

/// Kişisel rekorlar: toplam, rekor seri, en verimli gün, aktif gün, en çok ders.
/// Renkli stat döşemeleri (§3.11). Card'sız içerik — çağıran sarmalar.
class StudyRecords extends ConsumerWidget {
  const StudyRecords({
    super.key,
    required this.sessions,
    this.columns = 2,
    this.totals,
  });

  final List<StudySession> sessions;
  final int columns;

  /// Çağıran zaten `dailyTotals(sessions)` hesapladıysa buradan geçirir; böylece
  /// bu widget (ve `longestStudyStreak`) haritayı yeniden kurmaz.
  final Map<DateTime, int>? totals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final months = _months(context);
    final subjects = ref.watch(userSubjectsProvider).value ?? const <Subject>[];

    final total = totalSeconds(sessions);
    final daily = totals ?? dailyTotals(sessions);
    final longest = longestStudyStreak(sessions, totals: daily);
    final activeDays = daily.length;

    // En verimli gün.
    DateTime? bestDay;
    var bestSeconds = 0;
    daily.forEach((day, sec) {
      if (sec > bestSeconds) {
        bestSeconds = sec;
        bestDay = day;
      }
    });

    // En çok çalışılan ders.
    final breakdown = subjectBreakdown(sessions);
    String topSubject = '—';
    if (breakdown.isNotEmpty) {
      final id = breakdown.first.key;
      if (id == null) {
        topSubject = AppLocalizations.of(context).statsGenel;
      } else {
        topSubject = subjects
            .where((s) => s.id == id)
            .map((s) => s.name)
            .firstWhere(
              (_) => true,
              orElse: () => AppLocalizations.of(context).statsGenel,
            );
      }
    }

    final tiles = <Widget>[
      _RecordTile(
        icon: Icons.timelapse,
        color: subjectColor('chart-1'),
        label: AppLocalizations.of(context).statsToplam,
        value: formatHuman(total),
      ),
      _RecordTile(
        icon: Icons.local_fire_department,
        color: subjectColor('chart-5'),
        label: AppLocalizations.of(context).statsRekorSeri,
        value: AppLocalizations.of(context).statsStreakGun(longest.toString()),
      ),
      _RecordTile(
        icon: Icons.emoji_events_outlined,
        color: subjectColor('chart-3'),
        label: AppLocalizations.of(context).statsEnVerimliGun,
        value: bestDay == null
            ? '—'
            : '${formatHuman(bestSeconds)}\n${bestDay!.day} ${months[bestDay!.month - 1]}',
      ),
      _RecordTile(
        icon: Icons.calendar_month_outlined,
        color: subjectColor('chart-2'),
        label: AppLocalizations.of(context).statsAktifGun,
        value: AppLocalizations.of(
          context,
        ).statsStreakGun(activeDays.toString()),
      ),
      _RecordTile(
        icon: Icons.menu_book_outlined,
        color: subjectColor('chart-4'),
        label: AppLocalizations.of(context).statsEnCokDers,
        value: topSubject,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final cols = columns.clamp(1, 4);
        final w = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final t in tiles) SizedBox(width: w, child: t)],
        );
      },
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
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
