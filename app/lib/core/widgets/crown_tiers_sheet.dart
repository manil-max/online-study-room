import 'package:flutter/material.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../stats/progression_visuals.dart';

/// Taç rütbelerinin XP eşiklerini gösteren sayfa (WP-234).
///
/// Kullanıcı tacına basınca "bronzdayım, Immortal kaç XP istiyor?" sorusunu
/// yanıtlar. Başarım detayındaki "Tüm kademeler" listesiyle aynı görsel dili
/// kullanır; eşikler [kCrownXpThresholds]'ten okunur (tek kaynak).
Future<void> showCrownTiers(BuildContext context, {required int currentXp}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final l10n = AppLocalizations.of(ctx);
      final currentTier = crownTierNumber(crownRankForXp(currentXp));

      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.82,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    l10n.profileTumKademeler,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    '$currentXp XP',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: tierColorFor(currentTier),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                for (var i = 0; i < kCrownRanks.length; i++)
                  _CrownTierRow(
                    tier: i + 1,
                    label: crownLabel(kCrownRanks[i], l10n),
                    thresholdXp: kCrownXpThresholds[i],
                    reached: currentXp >= kCrownXpThresholds[i],
                    isCurrent: currentTier == i + 1,
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _CrownTierRow extends StatelessWidget {
  const _CrownTierRow({
    required this.tier,
    required this.label,
    required this.thresholdXp,
    required this.reached,
    required this.isCurrent,
  });

  final int tier;
  final String label;
  final int thresholdXp;
  final bool reached;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final color = tierColorFor(tier);

    return Semantics(
      selected: isCurrent,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isCurrent ? 0.18 : 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: isCurrent ? 1 : 0.3),
            width: isCurrent ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              reached ? Icons.workspace_premium : Icons.lock_outline,
              color: reached
                  ? color
                  : color.withValues(alpha: 0.45),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: reached ? color : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$thresholdXp XP',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              reached ? l10n.profileTamamland : l10n.profileKilitli,
              style: theme.textTheme.labelSmall?.copyWith(
                color: reached ? color : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
