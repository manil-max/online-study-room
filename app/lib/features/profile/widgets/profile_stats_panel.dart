import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../core/desktop/desktop_layout.dart';
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
/// | günlük seri | `goal_streak_projection` RPC (`0112`) | ortak gruba açık gün toplamı + o üyenin hedefi |
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
///  2. **Güncel seri ≠ rekor seri.** Başkası için iki değer de aynı, zaten
///     RLS'ten geçmiş gün toplamları ve üyenin görünür hedefiyle hesaplanır;
///     güncel seri bugün/dünden geriye, rekor ise tüm tarihteki en uzun aralığa
///     bakar. Yeni bir veri erişim yolu açılmaz.
///
/// Ortak grup yoksa `group_daily_totals` boş döner ve panel **hiç çizilmez**:
/// `can_see_user_sessions` kapısının istemcideki doğal yansıması budur.
class ProfileStatsPanel extends ConsumerWidget {
  const ProfileStatsPanel({
    super.key,
    required this.userId,
    required this.isSelf,
    this.clock,
  });

  final String userId;
  final bool isSelf;
  final DateTime Function()? clock;

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
    final visibleCurrentStreak = goalSeconds <= 0
        ? 0
        : currentStreak(
            const [],
            goalSeconds,
            totals: totals,
            today: clock?.call(),
          );
    final recordStreak = goalSeconds <= 0
        ? 0
        : longestStudyStreak(
            const [],
            totals: totals,
            goalSeconds: goalSeconds,
          );
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
                Text(
                  l10n.profileStatsBaslik,
                  style: theme.textTheme.titleMedium,
                ),
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
              _StatRow(
                valueKey: const Key('profile-stat-goal-streak'),
                label: l10n.profileStatsGunlukSeri,
                definition: l10n.profileStatsGunlukSeriTanimi,
                value: l10n.statsStreakGun(visibleCurrentStreak.toString()),
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
    // 🔴 WP-674 / SPEC KURAL 2.2 — aşağıdaki `Expanded` TAVANSIZDI. Sahibin
    // 2000 px'lik penceresinde "Günlük seri" solda kalıyor, değeri (`0`) ~1900 px
    // ötede sağa itiliyordu. Bu bir estetik tercih değil okunabilirlik hatası:
    // göz satır başına dönemeyince satırı kaybeder (WCAG 2.1 SC 1.4.8, SPEC §2.2).
    //
    // Kural: satırın kabı 496 px'ten (Bringhurst 66ch hedefi) genissse satır kabı
    // DOLDURMAZ — 496'da bırakılır ve sola hizalanır. Mobilde (390 px) kap zaten
    // 496'dan dar olduğu için çizilen ağaç birebir aynı kalır (SPEC §7).
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: DesktopBreakpoints.labelValueTargetWidth,
        ),
        child: Row(
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
        ),
      ),
    );
  }
}
