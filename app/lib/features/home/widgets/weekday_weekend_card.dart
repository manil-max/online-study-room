import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/providers/study_providers.dart';
import '../dashboard_card.dart';
import 'card_scaffold.dart';

/// Hafta içi (Pzt–Cum) ile hafta sonu (Cmt–Paz) çalışma kıyası (§3.11 kart).
class WeekdayWeekendCard extends ConsumerWidget {
  const WeekdayWeekendCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sessions = ref.watch(userSessionsProvider).value ?? const [];
    final split = weekdayWeekendSplit(sessions);
    final max = (split.weekday > split.weekend ? split.weekday : split.weekend)
        .clamp(1, 1 << 30);
    final weekdayColor = subjectColor('chart-1');
    final weekendColor = subjectColor('chart-4');

    return CardScaffold(
      header: Text(
        AppLocalizations.of(context).homeHaftaIciHaftaSonu,
        style: theme.textTheme.titleMedium,
      ),
      minBodyHeight: 88,
      fallbackBodyHeight: 110,
      bodyBuilder: (context, bodyHeight) => SizedBox(
        height: bodyHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _Bar(
                label: AppLocalizations.of(context).homeHaftaIci,
                seconds: split.weekday,
                fraction: split.weekday / max,
                color: weekdayColor,
              ),
            ),
            Expanded(
              child: _Bar(
                label: AppLocalizations.of(context).homeHaftaSonu,
                seconds: split.weekend,
                fraction: split.weekend / max,
                color: weekendColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.seconds,
    required this.fraction,
    required this.color,
  });

  final String label;
  final int seconds;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Dar hücrede de taşmasın: etiket + bar mevcut yüksekliğe sığar.
    return LayoutBuilder(
      builder: (context, constraints) {
        final tight = constraints.maxHeight < 40;
        final barH = tight ? 6.0 : 10.0;
        final gap = tight ? 2.0 : 4.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    formatHuman(seconds),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: gap),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: barH,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        );
      },
    );
  }
}
