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
                    // WP-504: birim katalogdan. TR ve EN'de aynı yazılıyor ama
                    // literal olarak kalmıyor — ileride başka bir dil eklenirse
                    // çeviri noktası hazır.
                    AppLocalizations.of(context).commonXpMiktari(currentXp),
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
                    state: crownTierStateFor(
                      tier: i + 1,
                      currentXp: currentXp,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// 🔴 WP-712 madde 7 — sahip: "açmadığı taçlar silik olsun; şu an hangi taçta
/// olduğu tam belirli olmuyor, ayrımı net olsun."
///
/// Eski hâlde ayrım **yalnız alfa** ile veriliyordu (0.18/0.07 dolgu,
/// 1/0.3 kenarlık): kilitli satır da açılmış satır da tam opaklıkta, aynı
/// canlılıkta duruyordu. Yeni sözleşme üç işareti birbirinden bağımsız
/// kullanır ve `crownTierRowVisual` ile ÖLÇÜLEBİLİR:
///   * "açtım mı" → satır opaklığı (0.38 ↔ 1.0)
///   * "şu an neredeyim" → kenarlık kalınlığı (1 px ↔ 3 px) + dolgu
///   * ayrıca yazıyla: "Şu an" / "Tamamlandı" / "Kilitli"
class _CrownTierRow extends StatelessWidget {
  const _CrownTierRow({
    required this.tier,
    required this.label,
    required this.thresholdXp,
    required this.state,
  });

  final int tier;
  final String label;
  final int thresholdXp;
  final CrownTierState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final color = tierColorFor(tier);
    final visual = crownTierRowVisual(state);
    final isCurrent = state == CrownTierState.current;
    final reached = state != CrownTierState.locked;

    return Semantics(
      selected: isCurrent,
      child: Opacity(
        key: ValueKey('crown-tier-row-$tier'),
        opacity: visual.opacity,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: visual.fillAlpha),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: isCurrent ? 1 : 0.3),
              width: visual.borderWidth,
            ),
          ),
          child: Row(
            children: [
              // WP-292 notu: buraya gerçek tacın ikon hâlini koymak denendi ve
              // geri alındı. Taç siluetinin tabanı avatarla eş merkezli bir
              // yay; altında kafa olmadan bu yay "kanat" gibi okunuyor. Düzgün
              // bir liste ikonu için **düz tabanlı** ikinci bir geometri
              // gerekiyor (vadi yarıçapı da uç yüksekliğiyle oranlanmalı) —
              // sahip onayıyla ayrı iş. Madalya o yüzden yerinde bırakıldı.
              Icon(
                reached ? Icons.workspace_premium : Icons.lock_outline,
                color: reached ? color : color.withValues(alpha: 0.45),
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
                      AppLocalizations.of(context).commonXpMiktari(thresholdXp),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                isCurrent
                    ? l10n.profileCrownSuAnki
                    : (reached ? l10n.profileTamamland : l10n.profileKilitli),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: reached ? color : theme.colorScheme.onSurfaceVariant,
                  fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
