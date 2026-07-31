import 'package:flutter/material.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../data/models/goal_streak.dart';

/// WP-454: seri alevinin üç durumu ve kişisel/grup ayrımı.
///
/// Durum **yalnız sunucu projeksiyonundan** gelir ([GoalStreakProjection.state]);
/// bu widget hiçbir yerel çıkarım yapmaz. Yerel bir "bugün tamamladım mı"
/// tahmini olsaydı, cihaz saati ile sunucu günü ayrıştığı anda kullanıcı
/// ekranda başka, sunucuda başka bir seri görürdü.
///
/// 🔴 Ayrım yalnız RENGE dayanmaz. Renk körü bir kullanıcı için üç durumun
/// üçü de aynı gri tona düşebilir; bu yüzden her durumun ayrı **ikonu**,
/// ayrı **metni** ve ekran okuyucu için ayrı `semanticsLabel`ı var. Kişisel ve
/// grup ise ayrıca çerçeve biçimi + rozet etiketiyle ayrılır.
enum GoalStreakFlameSize { compact, regular }

class GoalStreakFlame extends StatelessWidget {
  const GoalStreakFlame({
    super.key,
    required this.projection,
    this.size = GoalStreakFlameSize.regular,
  });

  final GoalStreakProjection projection;
  final GoalStreakFlameSize size;

  bool get _isCompact => size == GoalStreakFlameSize.compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final visual = goalStreakFlameVisual(projection.state, theme.colorScheme);
    final label = goalStreakFlameLabel(projection.state, l10n);
    final scopeLabel = projection.scope.type == GoalStreakScopeType.personal
        ? l10n.streakScopePersonal
        : l10n.streakScopeGroup;

    final isGroup = projection.scope.type == GoalStreakScopeType.group;
    return Semantics(
      container: true,
      // Ekran okuyucu tek cümlede kapsamı, seriyi ve durumu duyar.
      label: '$scopeLabel · ${projection.currentStreak} · $label',
      child: ExcludeSemantics(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: _isCompact ? 8 : 12,
            vertical: _isCompact ? 4 : 8,
          ),
          decoration: BoxDecoration(
            color: visual.background,
            // Kişisel yuvarlak, grup köşeli: renk dışında ikinci bir ayrım.
            borderRadius: BorderRadius.circular(isGroup ? 8 : 999),
            border: Border.all(
              color: visual.foreground.withValues(alpha: 0.55),
              width: isGroup ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                visual.icon,
                size: _isCompact ? 16 : 20,
                color: visual.foreground,
              ),
              const SizedBox(width: 6),
              Text(
                '${projection.currentStreak}',
                style: (_isCompact
                        ? theme.textTheme.labelMedium
                        : theme.textTheme.titleMedium)
                    ?.copyWith(
                      color: visual.foreground,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              // Küçük kartta da işaret okunur kalmalı: dar alanda sayı ve
              // durum ikonu korunur, yalnız uzun metin düşer.
              if (!_isCompact) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: visual.foreground,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              _ScopeBadge(
                text: scopeLabel,
                color: visual.foreground,
                compact: _isCompact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScopeBadge extends StatelessWidget {
  const _ScopeBadge({
    required this.text,
    required this.color,
    required this.compact,
  });

  final String text;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        child: Text(
          text,
          style: (compact ? theme.textTheme.labelSmall : theme.textTheme.labelMedium)
              ?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Bir seri durumunun ikon + renk karşılığı.
@immutable
class GoalStreakFlameVisual {
  const GoalStreakFlameVisual({
    required this.icon,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final Color foreground;
  final Color background;
}

/// Durum → görsel. Üç durumun **üç ayrı ikonu** var; renk tek ayırt edici
/// değildir (kart kabulü).
GoalStreakFlameVisual goalStreakFlameVisual(
  GoalStreakState state,
  ColorScheme scheme,
) {
  switch (state) {
    case GoalStreakState.completedToday:
      // Canlı alev.
      return GoalStreakFlameVisual(
        icon: Icons.local_fire_department,
        foreground: const Color(0xFFEA580C),
        background: const Color(0xFFEA580C).withValues(alpha: 0.14),
      );
    case GoalStreakState.pendingToday:
      // Sönük/gri alev: bugün için hâlâ süre var.
      return GoalStreakFlameVisual(
        icon: Icons.local_fire_department_outlined,
        foreground: scheme.onSurfaceVariant,
        background: scheme.surfaceContainerHighest,
      );
    case GoalStreakState.atRisk:
      // Grace işareti: alev + uyarı. Kırmızı DEĞİL — seri hâlâ ayakta ve
      // kırmızı rozet kırmızı temada kaybolabiliyor (v49 sahip notu).
      return GoalStreakFlameVisual(
        icon: Icons.warning_amber_rounded,
        foreground: const Color(0xFFB45309),
        background: const Color(0xFFF59E0B).withValues(alpha: 0.18),
      );
    case GoalStreakState.expired:
    case GoalStreakState.empty:
      return GoalStreakFlameVisual(
        icon: Icons.mode_night_outlined,
        foreground: scheme.onSurfaceVariant,
        background: scheme.surfaceContainerHigh,
      );
  }
}

String goalStreakFlameLabel(GoalStreakState state, AppLocalizations l10n) {
  switch (state) {
    case GoalStreakState.completedToday:
      return l10n.streakFlameCompleted;
    case GoalStreakState.pendingToday:
      return l10n.streakFlamePending;
    case GoalStreakState.atRisk:
      return l10n.streakFlameAtRisk;
    case GoalStreakState.expired:
    case GoalStreakState.empty:
      return l10n.streakFlameNone;
  }
}
