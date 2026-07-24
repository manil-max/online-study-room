import 'package:flutter/material.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../core/theme/theme_tokens.dart';

/// WP-289 `docs/TEMA-HIS-KATALOGU.md` §1 his ailelerinin kod karşılığı.
///
/// Şema `AppFeel`'de (WP-288); burada yalnız **hazır değerler** ve maliyet
/// etiketi var. Sihirbaz bu listeyi sunar, seçim `AppFeel`'e birebir yazılır.
enum FeelCost {
  /// Ek çizim yok — Modern/Flat.
  none,

  /// Statik doku/gölge; düşük donanımda güvenli.
  low,

  /// Özel çizim katmanı; ölçülü kullan.
  medium,

  /// Glow/blur — düşük donanımda kare düşürebilir.
  high,
}

@immutable
class FeelOption {
  const FeelOption({required this.feel, required this.cost});

  final AppFeel feel;
  final FeelCost cost;

  String get id => feel.feelId;

  String localizedName(AppLocalizations l10n) => switch (id) {
    'modern' => l10n.profileHisModern,
    'zen' => l10n.profileHisZen,
    'neon' => l10n.profileHisNeon,
    'vintage' => l10n.profileHisVintage,
    'carton' => l10n.profileHisKarton,
    'paper' => l10n.profileHisKagit,
    'glass' => l10n.profileHisCam,
    'flat' => l10n.profileHisDuz,
    _ => id,
  };

  String localizedCost(AppLocalizations l10n) => switch (cost) {
    FeelCost.none => l10n.profileHisMaliyetYok,
    FeelCost.low => l10n.profileHisMaliyetDusuk,
    FeelCost.medium => l10n.profileHisMaliyetOrta,
    FeelCost.high => l10n.profileHisMaliyetYuksek,
  };
}

/// Katalog sırası = sihirbazdaki sıra (varsayılan önce, ağır olanlar sonda).
const List<FeelOption> kFeelOptions = [
  FeelOption(feel: AppFeel.modern, cost: FeelCost.none),
  FeelOption(
    feel: AppFeel(
      feelId: 'zen',
      grainStrength: 0,
      grainKind: 'none',
      edgeIrregularity: 0,
      motion: AppMotion(
        fast: Duration(milliseconds: 220),
        normal: Duration(milliseconds: 420),
        slow: Duration(milliseconds: 700),
      ),
    ),
    cost: FeelCost.low,
  ),
  FeelOption(
    feel: AppFeel(
      feelId: 'paper',
      grainStrength: 0.35,
      grainKind: 'paper',
      edgeIrregularity: 0,
      motion: AppMotion.fallback,
    ),
    cost: FeelCost.low,
  ),
  FeelOption(
    feel: AppFeel(
      feelId: 'vintage',
      grainStrength: 0.5,
      grainKind: 'film',
      edgeIrregularity: 0,
      motion: AppMotion.fallback,
    ),
    cost: FeelCost.low,
  ),
  FeelOption(
    feel: AppFeel(
      feelId: 'carton',
      grainStrength: 0.6,
      grainKind: 'carton',
      edgeIrregularity: 0.35,
      motion: AppMotion.fallback,
    ),
    cost: FeelCost.medium,
  ),
  FeelOption(
    feel: AppFeel(
      feelId: 'flat',
      grainStrength: 0,
      grainKind: 'none',
      edgeIrregularity: 0,
      motion: AppMotion.snappy,
    ),
    cost: FeelCost.none,
  ),
  FeelOption(
    feel: AppFeel(
      feelId: 'neon',
      grainStrength: 0,
      grainKind: 'none',
      edgeIrregularity: 0,
      motion: AppMotion.snappy,
    ),
    cost: FeelCost.high,
  ),
  FeelOption(
    feel: AppFeel(
      feelId: 'glass',
      grainStrength: 0,
      grainKind: 'none',
      edgeIrregularity: 0,
      motion: AppMotion.fallback,
    ),
    cost: FeelCost.high,
  ),
];

FeelOption feelOptionById(String id) => kFeelOptions.firstWhere(
  (option) => option.id == id,
  orElse: () => kFeelOptions.first,
);

/// Seçilen his, ilgili diğer katmanları da birlikte ayarlar (katalog §3:
/// "his bir bileşim kimliğidir"). Renkler kullanıcının; yalnız şekil ve
/// atmosfer karakteri hisle hizalanır.
AppShapes shapesForFeel(String feelId, AppShapes current) => switch (feelId) {
  'zen' => current.copyWith(
    radiusSm: 16,
    radiusMd: 28,
    radiusLg: 40,
    cardElevation: 2,
    sharp: false,
  ),
  'neon' => current.copyWith(
    radiusSm: 2,
    radiusMd: 4,
    radiusLg: 6,
    cardElevation: 0,
    borderWidth: 1,
    sharp: false,
  ),
  'flat' => current.copyWith(cardElevation: 0, borderWidth: 1, sharp: false),
  'carton' => current.copyWith(
    radiusSm: 4,
    radiusMd: 8,
    radiusLg: 12,
    cardElevation: 1,
    borderWidth: 1,
    sharp: false,
  ),
  'paper' => current.copyWith(
    radiusSm: 2,
    radiusMd: 6,
    radiusLg: 10,
    cardElevation: 0,
    borderWidth: 1,
    sharp: false,
  ),
  'glass' => current.copyWith(
    radiusSm: 14,
    radiusMd: 22,
    radiusLg: 32,
    cardElevation: 0,
    borderWidth: 1,
    sharp: false,
  ),
  _ => current.copyWith(
    radiusSm: 8,
    radiusMd: 16,
    radiusLg: 24,
    cardElevation: 0,
    borderWidth: 1,
    sharp: false,
  ),
};

/// Hissin atmosfer karakteri — renkler korunur, yalnız şiddet alanları hizalanır.
AppAtmosphere atmosphereForFeel(String feelId, AppAtmosphere current) =>
    switch (feelId) {
      'neon' => current.copyWith(glowStrength: 0.6, blurSigma: 0, glassOpacity: 0),
      'glass' => current.copyWith(
        glowStrength: 0.2,
        blurSigma: 12,
        glassOpacity: 0.35,
      ),
      'zen' => current.copyWith(glowStrength: 0.15, blurSigma: 0, glassOpacity: 0),
      'flat' ||
      'paper' ||
      'carton' => current.copyWith(glowStrength: 0, blurSigma: 0, glassOpacity: 0),
      'vintage' => current.copyWith(glowStrength: 0.1, blurSigma: 0, glassOpacity: 0),
      _ => current.copyWith(glowStrength: 0, blurSigma: 0, glassOpacity: 0),
    };
