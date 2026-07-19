import 'package:flutter/material.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import 'achievement_ledger_engine.dart' show kCrownXpThresholds;

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
({int floor, int next, double progress}) xpBarMetrics(int xp) {
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
    return (floor: floor, next: next, progress: 1.0);
  }
  final progress = ((xp - floor) / (next - floor)).clamp(0.0, 1.0);
  return (floor: floor, next: next, progress: progress);
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
