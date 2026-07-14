import 'package:flutter/material.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import 'achievement_ledger_engine.dart' show kCrownXpThresholds;

export 'achievement_ledger_engine.dart' show crownRankForXp, kCrownXpThresholds;

/// Başarım kademesi (1–5) ve taç rütbesi (5 basamak) ortak görsel dili.
///
/// Kademe ve taç **aynı 5 renkte** hizalanır; gizli başarımlar bu paletin
/// dışında mor/eflatun bir "sır" rengi kullanır.

/// Kademe 1→5 renkleri (bronz → gümüş → altın → platin → elmas).
Color tierColorFor(int tier) {
  switch (tier.clamp(1, 5)) {
    case 1:
      return const Color(0xFFB87333); // bronz
    case 2:
      return const Color(0xFF9CA3AF); // gümüş
    case 3:
      return const Color(0xFFEAB308); // altın
    case 4:
      return const Color(0xFF67E8F9); // platin / buz
    case 5:
    default:
      return const Color(0xFF38BDF8); // elmas
  }
}

String tierLabel(int tier, AppLocalizations l10n) {
  switch (tier.clamp(1, 5)) {
    case 1:
      return l10n.coreBronz;
    case 2:
      return l10n.coreGumus;
    case 3:
      return l10n.coreAltin;
    case 4:
      return l10n.corePlatin;
    case 5:
    default:
      return l10n.coreElmas;
  }
}

/// Gizli başarımlar — 5 kademe paletinden ayrı (eflatun/mor sır).
const Color kSecretAchievementColor = Color(0xFFA855F7);
const Color kSecretLockedColor = Color(0xFF1F1230);

/// Taç rütbe id'leri (5 basamak).
const List<String> kCrownRanks = <String>[
  'bronze_beginner',
  'silver_learner',
  'gold_achiever',
  'platinum_scholar',
  'diamond_owl',
];

/// Eski sunucu rütbelerini 5 basamağa indirger.
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
      return 'platinum_scholar';
    case 'ruby_master':
    case 'diamond_owl':
      return 'diamond_owl';
    default:
      return 'bronze_beginner';
  }
}

int crownTierIndex(String rank) {
  final n = normalizeCrownRank(rank);
  final i = kCrownRanks.indexOf(n);
  return i < 0 ? 0 : i; // 0..4
}

int crownTierNumber(String rank) => crownTierIndex(rank) + 1; // 1..5

String crownLabel(String rank, AppLocalizations l10n) {
  switch (normalizeCrownRank(rank)) {
    case 'diamond_owl':
      return l10n.coreElmasTac;
    case 'platinum_scholar':
      return l10n.corePlatinTac;
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
