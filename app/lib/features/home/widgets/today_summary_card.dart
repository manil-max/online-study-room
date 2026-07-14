import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/models/subject.dart';
import '../../../data/providers/study_providers.dart';
import '../../../data/providers/subject_providers.dart';
import '../dashboard_card.dart';

/// Bugünün özeti: toplam süre + ders bazında oransal dağılım (§3.9 kart).
/// Küçük boyutta yalnızca toplamı, orta/büyükte ders dağılımını gösterir.
class TodaySummaryCard extends ConsumerWidget {
  const TodaySummaryCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sessions = ref.watch(userSessionsProvider).value ?? const [];
    final subjects = ref.watch(userSubjectsProvider).value ?? const <Subject>[];
    final now = DateTime.now();
    final today = sessions.where((s) => isSameDay(s.day, now)).toList();
    final total = totalSeconds(today);
    final breakdown = subjectBreakdown(today);

    Subject? subjectFor(String? id) {
      for (final s in subjects) {
        if (s.id == id) return s;
      }
      return null;
    }

    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Dar VEYA çok kısa hücrede kaydırma-güvenli özet düzenine düş; böylece
          // tam genişlikte h=1 gibi çok kısa hücrede taşma (RenderFlex) olmaz.
          // 140 eşiği CardScaffold'un doldurma eşiğiyle (minBody 96 + başlık 44)
          // hizalıdır.
          final isCompact =
              constraints.maxWidth < 180 ||
              (constraints.maxHeight.isFinite && constraints.maxHeight < 140);

          if (isCompact) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).homeBugun,
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatHuman(total),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      breakdown.isEmpty
                          ? AppLocalizations.of(context).homeKayitYok
                          : '${breakdown.length} ders',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final maxSeconds = breakdown.isEmpty
              ? 1
              : breakdown.first.value.clamp(1, 1 << 30);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      AppLocalizations.of(context).homeBugunOzeti,
                      style: theme.textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Text(
                      formatHuman(total),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: breakdown.isEmpty
                      ? Text(
                          AppLocalizations.of(
                            context,
                          ).homeBugunHenuzCalismaKaydin,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      : ListView.builder(
                          itemCount: breakdown.length,
                          itemBuilder: (context, index) {
                            final entry = breakdown[index];
                            final subject = subjectFor(entry.key);
                            final name =
                                subject?.name ??
                                AppLocalizations.of(context).homeGenel;
                            final color = subject != null
                                ? subjectColor(subject.color)
                                : theme.colorScheme.onSurfaceVariant;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 5,
                                        backgroundColor: color,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: theme.textTheme.bodyMedium,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        formatHuman(entry.value),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: entry.value / maxSeconds,
                                      minHeight: 8,
                                      backgroundColor: theme
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
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
