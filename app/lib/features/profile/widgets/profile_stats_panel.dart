import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/models/goal_streak.dart';
import '../../../data/providers/group_providers.dart';
import '../../../data/providers/study_providers.dart';
import '../../stats/widgets/goal_streak_flame.dart';

/// WP-660 — profil zenginleştirme (sahip maddesi 6).
///
/// Sahip: *"profilde günlük aktif, günlük serisi ve rekorları falan olsa güzel
/// olur."* Bu panel o üç şeyi çizer ama **uydurmaz**: her sayı hâlihazırda
/// istemcide olan, RLS kapısından geçmiş bir kaynaktan gelir.
///
/// Kaynak matrisi (envanterden):
///
/// | alan | kendi profili | başkasının profili |
/// |---|---|---|
/// | günlük seri | `goal_streak_projection` RPC (`0112`) | **YOK** — `goal_progress_events` RLS'i `scope_id = auth.uid()` |
/// | aktif gün | `userSessionsProvider` → [dailyTotals] | `group_daily_totals` (`0011`, security invoker → `can_see_user_sessions`) |
/// | rekor seri | aynı gün haritası + kendi hedefi | aynı harita + O ÜYENİN hedefi (`group_member_directory`, `0115`) |
/// | en verimli gün / toplam | gün haritası | gün haritası |
///
/// 🔴 İki tuzak burada bilinçli olarak kapatıldı:
///
///  1. **Seri ≠ aktif gün.** WP-636/637'den beri bunlar farklı ölçüler: seri
///     günlük *hedefi tutturulan* ardışık takvim günü, aktif gün ise *çalışılan*
///     gün. Aynı panelde ikisi de göründüğü için her ikisinin de altında kendi
///     tanımı yazılıdır; sahip bu ayrımı bir kez karıştırdı.
///  2. **Başkasının serisi uydurulmaz.** Günlük seri projeksiyonu sunucuda
///     self-only. Buraya günlük totallerden ikinci bir "seri" hesabı koymak
///     ekranda başka, sunucuda başka bir sayı üretirdi (WP-373 sınıfı hata).
///     Onun yerine neden görünmediği yazılır.
///
/// Ortak grup yoksa `group_daily_totals` boş döner ve panel **hiç çizilmez**:
/// `can_see_user_sessions` kapısının istemcideki doğal yansıması budur.
class ProfileStatsPanel extends ConsumerWidget {
  const ProfileStatsPanel({
    super.key,
    required this.userId,
    required this.isSelf,
  });

  final String userId;
  final bool isSelf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final Map<DateTime, int> totals;
    final int goalSeconds;
    if (isSelf) {
      totals = ref.watch(dailyTotalsProvider);
      goalSeconds = ref.watch(dailyGoalMinutesProvider) * 60;
    } else {
      final stats = ref.watch(groupDailyStatsProvider).value ?? const [];
      totals = userDayTotals(stats, userId);
      final members = ref.watch(groupMembersProvider).value ?? const [];
      var minutes = 0;
      for (final member in members) {
        if (member.id == userId) {
          minutes = member.dailyGoalMinutes;
          break;
        }
      }
      goalSeconds = minutes * 60;
    }

    // Başkasının profilinde hiç ortak kayıt yoksa panel yok. Boş bir kart
    // "bu kişinin verisi sıfır" demek olurdu; oysa doğrusu "göremiyoruz".
    if (!isSelf && totals.isEmpty) {
      return const SizedBox.shrink(key: Key('profile-stats-panel-empty'));
    }

    final activeDays = activeDayCount(totals);
    final recordStreak = goalSeconds <= 0
        ? 0
        : longestStudyStreak(const [], totals: totals, goalSeconds: goalSeconds);
    final total = totalOfDayTotals(totals);
    final peak = peakDay(totals);

    return Card(
      key: const Key('profile-stats-panel'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.insights_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(l10n.profileStatsBaslik, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            if (isSelf) ...[
              _StatRow(
                valueKey: const Key('profile-stat-goal-streak'),
                label: l10n.profileStatsGunlukSeri,
                definition: l10n.profileStatsGunlukSeriTanimi,
                trailing: GoalStreakBadge(
                  scope: GoalStreakScope.personal(userId),
                  size: GoalStreakFlameSize.compact,
                ),
              ),
            ] else ...[
              Text(
                l10n.profileStatsSeriYalnizKendinde,
                key: const Key('profile-stat-streak-unavailable'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            _StatRow(
              valueKey: const Key('profile-stat-active-days'),
              label: l10n.statsAktifGun,
              definition: l10n.profileStatsAktifGunTanimi,
              value: '$activeDays',
            ),
            const SizedBox(height: 12),
            _StatRow(
              valueKey: const Key('profile-stat-record-streak'),
              label: l10n.statsRekorSeri,
              definition: l10n.profileStatsGunlukSeriTanimi,
              value: recordStreak > 0
                  ? l10n.statsStreakGun(recordStreak.toString())
                  : '—',
            ),
            const SizedBox(height: 12),
            _StatRow(
              valueKey: const Key('profile-stat-peak-day'),
              label: l10n.statsEnVerimliGun,
              value: peak == null
                  ? '—'
                  : '${DateFormat.yMd(l10n.localeName).format(peak.day)} · '
                        '${formatHuman(peak.seconds)}',
            ),
            const SizedBox(height: 12),
            _StatRow(
              valueKey: const Key('profile-stat-total'),
              label: l10n.statsToplam,
              value: formatHuman(total),
            ),
            if (!isSelf) ...[
              const SizedBox(height: 12),
              Text(
                l10n.profileStatsGrupKapsamNotu,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.valueKey,
    required this.label,
    this.definition,
    this.value,
    this.trailing,
  });

  final Key valueKey;
  final String label;

  /// Ölçünün kuralı. Seri ve aktif gün aynı ekranda olduğu için boş bırakılmaz.
  final String? definition;
  final String? value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final definition = this.definition;
    final value = this.value;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodyMedium),
              if (definition != null) ...[
                const SizedBox(height: 2),
                Text(
                  definition,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (trailing != null)
          KeyedSubtree(key: valueKey, child: trailing!)
        else
          Text(
            value ?? '—',
            key: valueKey,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}
