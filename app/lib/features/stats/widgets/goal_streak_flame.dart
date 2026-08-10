import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../core/theme/container_roles.dart';
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

/// 🔴 WP-657 — RENKLER ARTIK SABİT DEĞİL, **ZEMİNİN FONKSİYONU**.
///
/// Sahip (2026-08-10): *"hâlâ günlük ve grup serisindeki işaret soluk ama tam
/// belli olmuyor; gri renk daha güzel olur."*
///
/// Ölçüm (`goal_streak_flame_theme_wp657_test.dart`, 15 hazır tema × 4 durum,
/// rozet gerçek `Card` yüzeyinin üstünde pump edilerek):
///
/// | durum          | ikon/dolgu kontrastı (eski) | WCAG eşiği |
/// |----------------|-----------------------------|------------|
/// | `pendingToday` | **1.63 – 1.86** (15/15 tema) | 3.0        |
/// | `atRisk`       | 2.02 – 2.96 (11/15 tema)    | 3.0        |
/// | `completedToday` sayı | 3.47 – 4.45 (11/15)  | 4.5        |
///
/// Yani "soluk" bir tercih değil, **okunamama** idi ve sahibin hiç fark
/// edemediği duraklatma (pause) işareti de aynı sebeple görünmüyordu.
///
/// Kök neden bu depoda üç kez daha görüldü (WP-358 uyarı rozeti, WP-594 odak
/// halkası, WP-627 container rolleri): renk sabit yazıldı, sonra
/// `Color.lerp(renk, scheme.surface, 0.55)` ile "soluklaştırıldı". Zemine doğru
/// lerp etmek **tanım gereği** kontrastı düşürür; ne kadar soluklaştırılırsa o
/// kadar okunmaz olur.
///
/// Çözüm yeni bir mekanizma değil, var olanın kullanılmasıdır:
/// [resolveContainerRole] tohum rengin **tonunu** korur, dolguyu uygulamanın
/// tüm yüzeylerinden ≥ `kMinContainerSeparation` ayırır ve üstündeki
/// ikon/sayıyı dolguya karşı ≥ `kMinTextContrast` tutturur. Dört durumun tek
/// farkı **tohum + glif**tir.
///
/// Ayrım hâlâ yalnız renge dayanmaz (renk körü kullanıcı): dört ayrı glif
/// çifti + `expired`/`empty`'nin her zaman **0** taşıyan sayısı + `Semantics`
/// cümlesi.
///
/// ⚠️ Bu, WP-604'ün "soluk = aynı turuncunun düşük doygunluklu hâli, gri
/// DEĞİL" kaydını **geçersiz kılar**; sahip 2026-08-10'da doğrudan gri istedi
/// (`AGENTS.md §0.1`). Kod yorumunu değiştirmek yetmez — bir sonraki tur yazılı
/// karara bakıp geri alır; bu satır o yüzden burada duruyor.
GoalStreakFlameVisual goalStreakFlameVisual(
  GoalStreakState state,
  ColorScheme scheme,
) {
  final (icon, seed) = _goalStreakSeed(state);
  final role = _resolveChip(seed, scheme);
  return GoalStreakFlameVisual(
    icon: icon,
    foreground: role.onContainer,
    background: role.container,
  );
}

/// Canlı alevin tohumu — sahibin 3. durumu ("renkli ateş vesaire").
const Color kGoalStreakLiveSeed = Color(0xFFEA580C);

/// Duraklatma tohumu. `warning_tokens.dart` ile **aynı** kehribar ailesi:
/// kırmızı seçilmedi, çünkü seri hâlâ ayakta ve kırmızı rozet kırmızı temada
/// kayboluyor (v49 sahip notu).
const Color kGoalStreakPauseSeed = Color(0xFFF59E0B);

/// Nötr (gri) tohum — sahibin V64 emri.
///
/// Doygunluğu 0 değil ~0.09: tamamen akromatik bir gri koyu temalarda ölü
/// görünüyor. Yine de her tema için **aynı** tohumdur, yani paletten bağımsız.
const Color kGoalStreakNeutralSeed = Color(0xFF9CA3AF);

(IconData, Color) _goalStreakSeed(GoalStreakState state) => switch (state) {
  // 3. durum: bugünün hedefi tutturuldu → canlı, renkli ateş.
  GoalStreakState.completedToday => (
    Icons.local_fire_department,
    kGoalStreakLiveSeed,
  ),
  // Dün tutturuldu, bugün henüz değil → nötr gri, içi boş alev.
  GoalStreakState.pendingToday => (
    Icons.local_fire_department_outlined,
    kGoalStreakNeutralSeed,
  ),
  // 2. durum: dün kaçırıldı, önceki gün tutturuldu → seri DURAKLAMADA.
  GoalStreakState.atRisk => (Icons.pause_circle_outline, kGoalStreakPauseSeed),
  // 1. durum: sıfırlanmış → gri alev + "0". Rozet gizlenmez.
  GoalStreakState.expired || GoalStreakState.empty => (
    Icons.local_fire_department,
    kGoalStreakNeutralSeed,
  ),
};

/// Tohum + yüzeyler → rozet dolgusu ve üstü.
///
/// Küçük bir bellek tutulur: [resolveContainerRole] eşiği tutturana kadar
/// döngüye girer ve rozet her karede (dört yüzeyde birden) yeniden çizilir.
/// Anahtar temanın kendisidir, o yüzden tema değişince yeni değer üretilir.
ContainerRole _resolveChip(Color seed, ColorScheme scheme) {
  final key = Object.hash(
    seed.toARGB32(),
    scheme.surface.toARGB32(),
    scheme.surfaceContainerLowest.toARGB32(),
    scheme.surfaceContainerHigh.toARGB32(),
    scheme.brightness,
  );
  final cached = _chipCache[key];
  if (cached != null) return cached;

  final role = resolveContainerRole(
    role: seed,
    // Rozet dört ayrı kartta çiziliyor (`goal_card`, `group_goal_card`,
    // `leaderboard_card`, `study_timer_card`); hangisinin üstünde durursa
    // dursun ayrışsın diye üç yüzeyin hepsi geçiliyor.
    surfaces: [
      scheme.surface,
      scheme.surfaceContainerLowest,
      scheme.surfaceContainerHigh,
    ],
    brightness: scheme.brightness,
  );
  if (_chipCache.length >= 64) _chipCache.clear();
  _chipCache[key] = role;
  return role;
}

final Map<int, ContainerRole> _chipCache = <int, ContainerRole>{};

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
