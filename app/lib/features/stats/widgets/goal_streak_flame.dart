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
/// 🔴 **WP-496 sahip kararı (2026-08-06): rozette hiç yazı yok.** Ne durum
/// cümlesi ("Henüz seri yok"), ne kapsam etiketi ("Kişisel"). Sahibin gerekçesi:
/// *"grup kısmında grup streak yazıyor, oradan anlaşılır zaten"*. Görünen içerik
/// **ikon + sayı**dan ibarettir.
///
/// Ayrım yine yalnız RENGE dayanmaz — renk körü bir kullanıcı için dört durum da
/// aynı gri tona düşebilir. Metin gidince ayrımı taşıyan kanallar şunlar:
///
///   * **ikon**: canlı alev / içi boş alev / pause — üç ayrı glif;
///   * **sayı**: `expired` ve `empty` her zaman **0** taşır
///     (`projectGoalStreak`: `currentStreak: distance <= 2 ? streak : 0`),
///     `completedToday` ise en az 1'dir. Yani "dolu alev + 0" ile
///     "dolu alev + n" hiçbir zaman karışmaz;
///   * **`Semantics` etiketi**: kapsam · sayı · durum cümlesi **aynen** durur,
///     ekran okuyucu hiçbir bilgi kaybetmez.
///
/// ⚠️ Kart "dört durum için dört ayrı ikon" yazıyordu; sıfırlanmış durumun
/// ikonu ise WP-481'de sahip tarafından **gri soluk alev** olarak karara
/// bağlandı ("gece ikonu 'seri yok' demiyordu"). İkisi aynı anda olamaz; sahip
/// kararı üstün (`AGENTS.md §0.1`), ayrımı yukarıdaki (ikon, sayı) çifti taşır
/// ve testte bu çiftin dört durumda dört ayrı değer aldığı ölçülür.
///
/// Kişisel/grup ayrımı ise çerçeve **biçimiyle** sürüyor (yuvarlak / köşeli),
/// yani kapsam etiketi kalksa da renksiz bir kanal kalıyor.
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
          // Sahip şikâyeti "rozet gereğinden büyük" idi; metin gidince dolgu da
          // küçülüyor, yoksa boş bir kutu kalırdı.
          padding: EdgeInsets.symmetric(
            horizontal: _isCompact ? 6 : 8,
            vertical: _isCompact ? 2 : 4,
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
              const SizedBox(width: 4),
              Text(
                '${projection.currentStreak}',
                style:
                    (_isCompact
                            ? theme.textTheme.labelMedium
                            : theme.textTheme.titleMedium)
                        ?.copyWith(
                          color: visual.foreground,
                          fontWeight: FontWeight.w700,
                        ),
              ),
            ],
          ),
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

/// Durum → görsel. Üç ayrı glif; renk tek ayırt edici değildir (kart kabulü).
/// Dördüncü durumun (`expired`/`empty`) ayrımını sayı taşır — bkz.
/// [GoalStreakFlame] başlığı.
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
      // 🔴 WP-604 — SAHİP KARARI DEĞİŞTİ (2026-08-09, doğrudan emir).
      //
      // Buradaki eski kod `completedToday` ile **birebir aynı** canlı turuncuyu
      // (0xFFEA580C) kullanıyordu; tek fark dolu/içi boş glifti ve rozet
      // boyutunda o fark görünmüyor. Sahip tam bunu bildirdi: "dün hedefimi
      // tamamladım, bugün tamamlamadım ama alev hâlâ canlı renkli."
      //
      // İstenen (chess.com modeli, sahibin kendi tarifi): bugünün hedefi
      // tamamlanmadıysa alev **soluk**; bugünkü tamamlanınca **canlı renge
      // döner ve sayı artar**.
      //
      // Bu WP-481'de yazılı "seri yaşıyor, o yüzden canlı renkte" kararını
      // **geçersiz kılar**. O kayıt `progress.md`de de düzeltildi — yalnız kodu
      // değiştirmek yetmez, bir sonraki tur yazılı karara bakıp geri alır.
      // Bu hatanın üç dört kez tekrarlanmasının sebebi buydu.
      //
      // Soluk = aynı turuncunun düşük doygunluklu hâli, gri DEĞİL: gri
      // "sıfırlanmış" durumun rengi ve ikisi karışmamalı. Ayrım hâlâ üç
      // kanalda: renk yoğunluğu + içi boş glif + sayı.
      return GoalStreakFlameVisual(
        icon: Icons.local_fire_department_outlined,
        foreground: Color.lerp(
          const Color(0xFFEA580C),
          scheme.surface,
          0.55,
        )!,
        background: const Color(0xFFEA580C).withValues(alpha: 0.06),
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

/// Durumun okunabilir cümlesi.
///
/// WP-496'dan sonra bu cümle **ekranda çizilmez**; yalnız `Semantics` etiketini
/// besler. Yani l10n anahtarları (`streakFlame*`) hâlâ kullanımdadır — silinecek
/// ölü anahtar üretmez (WP-500 tuzağı).
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
