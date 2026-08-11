import 'package:flutter/material.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import 'achievement_ledger_engine.dart'
    show crownRankForXp, kCrownXpThresholds;

export 'achievement_ledger_engine.dart' show crownRankForXp, kCrownXpThresholds;

/// Başarım kademesi (1–6) ve taç rütbesi (6 basamak) ortak görsel dili.
///
/// Kademe ve taç **aynı 6 renkte** hizalanır; gizli başarımlar bu paletin
/// dışında mor/eflatun bir "sır" rengi kullanır. Platin kalktı; 4=Elmas,
/// 5=Zümrüt (Valorant Ascendant yeşili), 6=Immortal (Valorant Immortal kırmızısı).

/// Kademe 1→6 renkleri (bronz → gümüş → altın → elmas → zümrüt → immortal).
Color tierColorFor(int tier) {
  switch (tier.clamp(1, 6)) {
    case 1:
      return const Color(0xFFB87333); // bronz
    case 2:
      return const Color(0xFF9CA3AF); // gümüş
    case 3:
      return const Color(0xFFEAB308); // altın
    case 4:
      return const Color(0xFF38BDF8); // elmas
    case 5:
      return const Color(0xFF17E4A0); // zümrüt (Valorant Ascendant yeşili)
    case 6:
    default:
      return const Color(0xFFB02E42); // immortal (Valorant Immortal kırmızısı)
  }
}

String tierLabel(int tier, AppLocalizations l10n) {
  switch (tier.clamp(1, 6)) {
    case 1:
      return l10n.coreBronz;
    case 2:
      return l10n.coreGumus;
    case 3:
      return l10n.coreAltin;
    case 4:
      return l10n.coreElmas;
    case 5:
      return l10n.coreZumrut;
    case 6:
    default:
      return l10n.coreImmortal;
  }
}

/// Metriği **birikmeyen** (kişisel rekor) başarımlar.
///
/// WP-234: `steel_will` tek oturumun en uzun süresini, `day_hero` en yoğun
/// günün saatini ölçer. Bunlar toplanmaz — 60/90 gibi bir ilerleme çubuğu
/// "30 dakika daha çalış" ima eder, oysa tek seferde 90 dakika gerekir.
/// Bu yüzden UI bunlarda çubuk yerine "en iyi" değerini gösterir.
bool isPersonalBestAchievement(String id) {
  switch (id) {
    case 'steel_will':
    case 'day_hero':
      return true;
    default:
      return false;
  }
}

/// Gizli başarımlar — 5 kademe paletinden ayrı (eflatun/mor sır).
const Color kSecretAchievementColor = Color(0xFFA855F7);
const Color kSecretLockedColor = Color(0xFF1F1230);

/// Taç rütbe id'leri (6 basamak). 4=Elmas (diamond_owl), 5=Zümrüt, 6=Immortal.
const List<String> kCrownRanks = <String>[
  'bronze_beginner',
  'silver_learner',
  'gold_achiever',
  'diamond_owl',
  'emerald_sage',
  'immortal_legend',
];

/// Eski sunucu rütbelerini 6 basamağa map'ler. Platin ve eski elmas artık aynı
/// Elmas (diamond_owl, 4.) kademeye düşer; XP korunur, taç yeniden hesaplanır.
String normalizeCrownRank(String rank) {
  switch (rank) {
    case 'wood_novice':
    case 'bronze':
    case 'bronze_beginner':
      return 'bronze_beginner';
    case 'silver_learner':
      return 'silver_learner';
    case 'gold_achiever':
      return 'gold_achiever';
    case 'platinum_scholar':
    case 'ruby_master':
    case 'diamond_owl':
      return 'diamond_owl';
    case 'emerald_sage':
      return 'emerald_sage';
    case 'immortal_legend':
      return 'immortal_legend';
    default:
      return 'bronze_beginner';
  }
}

int crownTierIndex(String rank) {
  final n = normalizeCrownRank(rank);
  final i = kCrownRanks.indexOf(n);
  return i < 0 ? 0 : i; // 0..5
}

int crownTierNumber(String rank) => crownTierIndex(rank) + 1; // 1..6

String crownLabel(String rank, AppLocalizations l10n) {
  switch (normalizeCrownRank(rank)) {
    case 'immortal_legend':
      return l10n.coreImmortalTac;
    case 'emerald_sage':
      return l10n.coreZumrutTac;
    case 'diamond_owl':
      return l10n.coreElmasTac;
    case 'gold_achiever':
      return l10n.coreAltinTac;
    case 'silver_learner':
      return l10n.coreGumusTac;
    case 'bronze_beginner':
    default:
      return l10n.coreBronzTac;
  }
}

Color crownColorFor(String rank, [ColorScheme? _]) {
  return tierColorFor(crownTierNumber(rank));
}

/// XP → bir sonraki taç eşiği (0..1 progress).
///
/// Kullanıcıya gösterilen değer ve çubuğun payı **mutlak** XP'dir: örneğin
/// 25.000 XP / sonraki eşik 75.000 ise hem etiket hem de doluluk `25/75` olur.
/// Kademe-içi `5.000/55.000` görünümü kullanıcıyı önceki eşikten habersiz
/// bıraktığı için burada bilinçli olarak üretilmez.
({int floor, int next, int currentXp, int nextThreshold, double progress})
xpBarMetrics(int xp) {
  final thresholds = kCrownXpThresholds;
  var floor = thresholds.first;
  var next = thresholds.last;
  for (var i = 0; i < thresholds.length - 1; i++) {
    if (xp >= thresholds[i] && xp < thresholds[i + 1]) {
      floor = thresholds[i];
      next = thresholds[i + 1];
      break;
    }
    if (xp >= thresholds.last) {
      floor = thresholds.last;
      next = thresholds.last;
    }
  }
  if (next <= floor) {
    return (
      floor: floor,
      next: next,
      currentXp: next,
      nextThreshold: next,
      progress: 1.0,
    );
  }
  final currentXp = xp.clamp(0, next);
  final progress = (currentXp / next).clamp(0.0, 1.0);
  return (
    floor: floor,
    next: next,
    currentXp: currentXp,
    nextThreshold: next,
    progress: progress,
  );
}

/// Taç kademesi satırının üç durumu (WP-712).
enum CrownTierState { locked, unlocked, current }

/// Açılmamış tacın opaklığı. Sahip: "açmadığı taçlar silik olsun."
///
/// 0.38 Material'in `disabled` opaklığıdır: metin hâlâ okunur (WCAG AA'yı
/// koruyan tek adım), ama açılmış satırın yanında bakışta geri plana düşer.
const double kCrownTierLockedOpacity = 0.38;

/// XP → o kademenin durumu. Tek kaynak: eşikler [kCrownXpThresholds].
CrownTierState crownTierStateFor({required int tier, required int currentXp}) {
  final index = (tier - 1).clamp(0, kCrownXpThresholds.length - 1);
  if (crownTierNumber(crownRankForXp(currentXp)) == tier) {
    return CrownTierState.current;
  }
  return currentXp >= kCrownXpThresholds[index]
      ? CrownTierState.unlocked
      : CrownTierState.locked;
}

/// Kademe satırının ÖLÇÜLEBİLİR görsel sözleşmesi (WP-712 madde 7).
///
/// Sahip "ayrımı net olsun" dedi; bu bir izlenim değil üç sayıdır:
///   kilitli  → opaklık 0.38, kenarlık 1 px, dolgu 0.04
///   açılmış  → opaklık 1.00, kenarlık 1 px, dolgu 0.10
///   mevcut   → opaklık 1.00, kenarlık **3 px**, dolgu 0.22
/// Yani "açılmış mı" sorusunu opaklık, "şu an hangisindeyim" sorusunu
/// kenarlık kalınlığı + dolgu ayrı ayrı yanıtlar (tek işarete bağlı değil).
({double opacity, double borderWidth, double fillAlpha}) crownTierRowVisual(
  CrownTierState state,
) {
  switch (state) {
    case CrownTierState.current:
      return (opacity: 1.0, borderWidth: 3.0, fillAlpha: 0.22);
    case CrownTierState.unlocked:
      return (opacity: 1.0, borderWidth: 1.0, fillAlpha: 0.10);
    case CrownTierState.locked:
      return (
        opacity: kCrownTierLockedOpacity,
        borderWidth: 1.0,
        fillAlpha: 0.04,
      );
  }
}

/// Taç + XP satırı — profil yüzeylerinin **tek** taç/XP kaynağı (WP-712).
///
/// Sahip emri: XP barı ve altındaki renkli kademe şeridi kaldırıldı. Barın
/// taşıdığı bilgi kaybolmadı, bu satıra taşındı: rozet artık mutlak
/// `XP / sonraki eşik` yazar (`commonXpIlerlemesi`). Yüzde ayrıca yazılmaz —
/// iki sayıdan türetilir ve onu görselleştiren çubuk artık yok.
///
/// Kademelerin tamamı [onTap] ile açılan sayfada durur (sahip maddesi 6).
///
/// 🔴 Bu widget bilerek `core/stats` altında ve sayfayı kendisi AÇMAZ: iki
/// profil kolu (genel kart + sosyal profil) aynı görünümü kopyalamadan
/// kullansın diye. Bu depoda aynı bilgi için iki kol tutulduğunda biri
/// eksik kaldı (WP-550, WP-594).
class CrownXpHeader extends StatelessWidget {
  const CrownXpHeader({
    super.key,
    required this.rank,
    required this.xp,
    this.onTap,
  });

  final String rank;
  final int xp;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final color = crownColorFor(rank, theme.colorScheme);
    final bar = xpBarMetrics(xp);
    final atMax = xp >= kCrownXpThresholds.last;

    return InkWell(
      key: const ValueKey('crown-xp-header'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        // DoD erişilebilirlik: 48 dp dokunma alanı yazı ölçeğiyle büyür.
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        // 🔴 360 dp kapısı: `500000 / 1000000 XP` + "Zümrüt Taç" dar ekranda
        // satıra sığmıyor (ölçüldü: 360 dp'de 92 px taşma). Çözüm ellipsis
        // DEĞİL — kısalan bir XP sayısı yanlış bilgi olur. `scaleDown` yalnız
        // gerekince küçültür, hiçbir şey kırpılmaz ve satır ortalı kalır.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.workspace_premium, color: color, size: 20),
              const SizedBox(width: 6),
              Text(
                crownLabel(rank, l10n),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
              ),
              const SizedBox(width: 8),
              Container(
                key: const ValueKey('crown-xp-value'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  atMax
                      ? l10n.commonXpMiktari(xp)
                      : l10n.commonXpIlerlemesi(
                          bar.currentXp,
                          bar.nextThreshold,
                        ),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.info_outline,
                size: 16,
                color: color.withValues(alpha: 0.75),
                semanticLabel: l10n.profileTumKademeler,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rozet rengi: gizli kilit → koyu mor; gizli açık → eflatun; normal → kademe.
Color badgeVisualColor({
  required int tier,
  required bool unlocked,
  required bool isSecret,
  required bool secretLocked,
  ColorScheme? scheme,
}) {
  if (secretLocked) return kSecretLockedColor;
  if (isSecret && unlocked) return kSecretAchievementColor;
  if (!unlocked) {
    return scheme?.outline ?? const Color(0xFF6B7280);
  }
  return tierColorFor(tier);
}
