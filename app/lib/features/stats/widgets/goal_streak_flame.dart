import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../data/models/goal_streak.dart';
import '../../../data/providers/goal_streak_providers.dart';

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
      // WP-481 sahip kararı: seri **yaşıyor** ve risk yok, o yüzden alev
      // canlı renkte. Ayrım içi boş çizim: bugünün hedefi henüz tamamlanmadı.
      // (Eskiden gri idi ve "sıfırlanmış" durumla karışıyordu.)
      return GoalStreakFlameVisual(
        icon: Icons.local_fire_department_outlined,
        foreground: const Color(0xFFEA580C),
        background: const Color(0xFFEA580C).withValues(alpha: 0.10),
      );
    case GoalStreakState.atRisk:
      // WP-481 sahip kararı: duraklatma işareti **pause**. Kırmızı DEĞİL —
      // seri hâlâ ayakta ve kırmızı rozet kırmızı temada kaybolabiliyor
      // (v49 sahip notu).
      return GoalStreakFlameVisual(
        icon: Icons.pause_circle_outline,
        foreground: const Color(0xFFB45309),
        background: const Color(0xFFF59E0B).withValues(alpha: 0.18),
      );
    case GoalStreakState.expired:
    case GoalStreakState.empty:
      // WP-481 sahip kararı: sıfırlanmış seride **gri soluk alev + "0"**.
      // Rozet gizlenmez; gece ikonu "seri yok" demiyordu.
      return GoalStreakFlameVisual(
        icon: Icons.local_fire_department,
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

/// WP-481: ekranlara konan **kanonik** seri rozeti.
///
/// 🔴 Kök neden buydu: [GoalStreakFlame] ve `goalStreakProjectionProvider`
/// WP-453/454'te yazıldı ama `app/lib` içinde tek bir çağrı yeri yoktu. Ekranlar
/// bunun yerine grace'siz eski motoru (`currentStreak()`) okuyordu; sahibin
/// istediği duraklatma o motorda **yok**. Bu sarmalayıcı iki motorun aynı
/// ekranda yaşamasını engeller.
///
/// Rozet **her zaman** görünür (sahip kararı): kapsam hazır değilken, akış
/// yüklenirken veya hata verdiğinde de boş projeksiyonla gri alev + "0" çizer.
/// Eskiden `if (streak > 0)` kapısı vardı ve seri sıfırken rozet kayboluyordu.
class GoalStreakBadge extends ConsumerWidget {
  const GoalStreakBadge({
    super.key,
    required this.scope,
    this.size = GoalStreakFlameSize.regular,
  });

  /// Kapsam henüz bilinmiyorsa (oturum/grup yüklenmedi) `null` geçilir.
  final GoalStreakScope? scope;
  final GoalStreakFlameSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = this.scope;
    final projection = scope == null
        ? null
        : ref.watch(goalStreakProjectionProvider(scope)).value;
    return GoalStreakFlame(
      projection:
          projection ??
          emptyGoalStreakProjection(
            scope ?? const GoalStreakScope.personal('unknown'),
          ),
      size: size,
    );
  }
}

/// Veri yokken gösterilecek projeksiyon: seri 0, durum `empty`.
///
/// `sourceVersion` bilinçli olarak `local-empty`: bu satırın sunucudan
/// gelmediği, günlükte ve testte ayırt edilebilsin.
GoalStreakProjection emptyGoalStreakProjection(GoalStreakScope scope) =>
    GoalStreakProjection(
      scope: scope,
      asOfDay: DateTime.utc(1970),
      currentStreak: 0,
      completionCount: 0,
      state: GoalStreakState.empty,
      sourceVersion: 'local-empty',
    );
