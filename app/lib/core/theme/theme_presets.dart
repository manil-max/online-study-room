import 'package:flutter/material.dart';

import 'theme_tokens.dart';

/// Hazır sanat yönü (TEMA-MIMARISI §2) — atmosfer aileleri (tam UI havası).
@immutable
class ThemePreset {
  const ThemePreset({
    required this.id,
    required this.name,
    required this.description,
    required this.brightness,
    required this.colors,
    required this.shapes,
    required this.atmosphere,
    required this.motion,
    this.serifTitles = false,
    this.monospaceClock = true,
    this.isDynamic = false,
  });

  final String id;
  final String name;
  final String description;
  final Brightness brightness;
  final AppColors colors;
  final AppShapes shapes;
  final AppAtmosphere atmosphere;
  final AppMotion motion;
  final bool serifTitles;
  final bool monospaceClock;

  /// Material You — seed dışarıdan uygulanır.
  final bool isDynamic;

  AppTypography typography() => AppTypography.standard(
        textPrimary: colors.textPrimary,
        serif: serifTitles,
        monoClock: monospaceClock,
      );
}

AppColors _c({
  required Color scaffold,
  required Color surface1,
  required Color surface2,
  required Color primary,
  required Color onPrimary,
  required Color accent,
  required Color onAccent,
  required Color textPrimary,
  required Color textSecondary,
  required Color border,
  Color success = const Color(0xFF22C55E),
  Color error = const Color(0xFFEA3C3F),
  Color onError = const Color(0xFFFFFFFF),
}) =>
    AppColors(
      scaffold: scaffold,
      surface1: surface1,
      surface2: surface2,
      primary: primary,
      onPrimary: onPrimary,
      accent: accent,
      onAccent: onAccent,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      border: border,
      success: success,
      error: error,
      onError: onError,
    );

/// Hazır atmosfer temaları — renk + şekil + glow + hareket (docs/TEMA-MIMARISI.md).
final List<ThemePreset> kThemePresets = [
  // 1. Ateş — Kamp Ateşi
  ThemePreset(
    id: 'campfire_night',
    name: 'Kamp Ateşi',
    description: 'Ateş teması — turuncu glow, gece kampı havası',
    brightness: Brightness.dark,
    colors: _c(
      scaffold: const Color(0xFF07090E),
      surface1: const Color(0xFF12161E),
      surface2: const Color(0xFF1C222C),
      primary: const Color(0xFFF97316),
      onPrimary: const Color(0xFF1C0A00),
      accent: const Color(0xFFE69825),
      onAccent: const Color(0xFF1C1400),
      textPrimary: const Color(0xFFF5EDE4),
      textSecondary: const Color(0xFFA89888),
      border: const Color(0xFF2A241C),
    ),
    shapes: AppShapes.soft,
    atmosphere: const AppAtmosphere(
      gradientStart: Color(0xFF0A0C12),
      gradientEnd: Color(0xFF1A1008),
      glowColor: Color(0xFFF97316),
      glowStrength: 0.45,
      blurSigma: 0,
    ),
    motion: AppMotion.fallback,
  ),
  // 2. Keskin modern — Deep AMOLED
  ThemePreset(
    id: 'deep_amoled',
    name: 'Keskin Modern',
    description: 'Saf siyah, keskin köşeler — modern minimal odak',
    brightness: Brightness.dark,
    colors: _c(
      scaffold: Color(0xFF000000),
      surface1: Color(0xFF0A0A0A),
      surface2: Color(0xFF141414),
      primary: Color(0xFF00FF88),
      onPrimary: Color(0xFF001A0E),
      accent: Color(0xFF00E5FF),
      onAccent: Color(0xFF001418),
      textPrimary: Color(0xFFE8E8E8),
      textSecondary: Color(0xFF888888),
      border: Color(0xFF222222),
    ),
    shapes: AppShapes.sharpBox,
    atmosphere: const AppAtmosphere(
      gradientStart: Color(0xFF000000),
      gradientEnd: Color(0xFF000000),
      glowColor: Color(0xFF00FF88),
      glowStrength: 0,
      blurSigma: 0,
    ),
    motion: AppMotion.snappy,
  ),
  // 3. Nordic (açık buzul ailesi)
  ThemePreset(
    id: 'nordic_snow',
    name: 'Nordik Kar',
    description: 'Ferah İskandinav — açık ton, sakin odak',
    brightness: Brightness.light,
    colors: _c(
      scaffold: Color(0xFFF7F9FC),
      surface1: Color(0xFFFFFFFF),
      surface2: Color(0xFFEEF2F7),
      primary: Color(0xFF3B82F6),
      onPrimary: Color(0xFFFFFFFF),
      accent: Color(0xFF2DD4BF),
      onAccent: Color(0xFF042F2E),
      textPrimary: Color(0xFF0F172A),
      textSecondary: Color(0xFF64748B),
      border: Color(0xFFE2E8F0),
    ),
    shapes: const AppShapes(
      radiusSm: 12,
      radiusMd: 20,
      radiusLg: 28,
      cardElevation: 1,
      borderWidth: 0,
    ),
    atmosphere: const AppAtmosphere(
      gradientStart: Color(0xFFF7F9FC),
      gradientEnd: Color(0xFFE8F0FA),
      glowColor: Color(0xFF3B82F6),
      glowStrength: 0.1,
      blurSigma: 0,
    ),
    motion: AppMotion.fallback,
  ),
  // 4. Ocean Glass
  ThemePreset(
    id: 'ocean_glass',
    name: 'Okyanus Cam',
    description: 'Cam ve su — soft glassmorphism',
    brightness: Brightness.dark,
    colors: _c(
      scaffold: Color(0xFF0A192F),
      surface1: Color(0xFF112240),
      surface2: Color(0xFF1D3461),
      primary: Color(0xFF64FFDA),
      onPrimary: Color(0xFF003328),
      accent: Color(0xFF22D3EE),
      onAccent: Color(0xFF042F2E),
      textPrimary: Color(0xFFE6F1FF),
      textSecondary: Color(0xFF8892B0),
      border: Color(0xFF233554),
    ),
    shapes: AppShapes.soft,
    atmosphere: const AppAtmosphere(
      gradientStart: Color(0xFF0A192F),
      gradientEnd: Color(0xFF020C1B),
      glowColor: Color(0xFF64FFDA),
      glowStrength: 0.25,
      blurSigma: 18,
      glassOpacity: 0.35,
    ),
    motion: AppMotion.fallback,
  ),
  // 5. Coffee Library
  ThemePreset(
    id: 'coffee_library',
    name: 'Kahve Kütüphane',
    description: 'Sıcak sepya — yumuşak akademik hava',
    brightness: Brightness.dark,
    colors: _c(
      scaffold: Color(0xFF1A120B),
      surface1: Color(0xFF2A1F16),
      surface2: Color(0xFF3A2B1E),
      primary: Color(0xFFD4A373),
      onPrimary: Color(0xFF2A1C11),
      accent: Color(0xFF9B2226),
      onAccent: Color(0xFFFFF5F5),
      textPrimary: Color(0xFFF5E6D3),
      textSecondary: Color(0xFFB8A48E),
      border: Color(0xFF4A3A2A),
    ),
    shapes: AppShapes.soft,
    atmosphere: const AppAtmosphere(
      gradientStart: Color(0xFF1A120B),
      gradientEnd: Color(0xFF2C1E12),
      glowColor: Color(0xFFD4A373),
      glowStrength: 0.2,
      blurSigma: 0,
    ),
    motion: AppMotion.fallback,
    serifTitles: true,
    monospaceClock: false,
  ),
  // 6. Retro Terminal
  ThemePreset(
    id: 'retro_terminal',
    name: 'Retro Terminal',
    description: 'Fosfor yeşili — keskin hacker terminali',
    brightness: Brightness.dark,
    colors: _c(
      scaffold: Color(0xFF0C0C0C),
      surface1: Color(0xFF0C0C0C),
      surface2: Color(0xFF101510),
      primary: Color(0xFF00FF41),
      onPrimary: Color(0xFF001A08),
      accent: Color(0xFF39FF14),
      onAccent: Color(0xFF001A08),
      textPrimary: Color(0xFF00FF41),
      textSecondary: Color(0xFF00AA2A),
      border: Color(0xFF00FF41),
    ),
    shapes: AppShapes.sharpBox,
    atmosphere: const AppAtmosphere(
      gradientStart: Color(0xFF0C0C0C),
      gradientEnd: Color(0xFF0C0C0C),
      glowColor: Color(0xFF00FF41),
      glowStrength: 0.15,
      blurSigma: 0,
    ),
    motion: AppMotion.snappy,
    monospaceClock: true,
  ),
  // 7. Gelecek neon
  ThemePreset(
    id: 'neon_focus',
    name: 'Gelecek Neon',
    description: 'Synthwave / cyberpunk — parlak gelecek havası',
    brightness: Brightness.dark,
    colors: _c(
      scaffold: Color(0xFF0D0221),
      surface1: Color(0xFF1A0A3E),
      surface2: Color(0xFF2A1058),
      primary: Color(0xFFFF007F),
      onPrimary: Color(0xFF240011),
      accent: Color(0xFF00F0FF),
      onAccent: Color(0xFF001F24),
      textPrimary: Color(0xFFF5E9FF),
      textSecondary: Color(0xFFB8A0D0),
      border: Color(0xFF3D1F6B),
    ),
    shapes: AppShapes.soft,
    atmosphere: const AppAtmosphere(
      gradientStart: Color(0xFF0D0221),
      gradientEnd: Color(0xFF1A0533),
      glowColor: Color(0xFFFF007F),
      glowStrength: 0.55,
      blurSigma: 8,
    ),
    motion: AppMotion.fallback,
  ),
  // 8. Forest Study
  ThemePreset(
    id: 'forest_study',
    name: 'Orman Kabini',
    description: 'Yeşil sakinlik — doğa odak odası',
    brightness: Brightness.dark,
    colors: _c(
      scaffold: Color(0xFF122315),
      surface1: Color(0xFF1A3020),
      surface2: Color(0xFF243D28),
      primary: Color(0xFF8B5A2B),
      onPrimary: Color(0xFFFFF8F0),
      accent: Color(0xFFE8C547),
      onAccent: Color(0xFF1C1401),
      textPrimary: Color(0xFFE8F0E4),
      textSecondary: Color(0xFF9BB09A),
      border: Color(0xFF2E4A34),
    ),
    shapes: const AppShapes(
      radiusSm: 14,
      radiusMd: 22,
      radiusLg: 32,
      cardElevation: 0,
      borderWidth: 1,
    ),
    atmosphere: const AppAtmosphere(
      gradientStart: Color(0xFF122315),
      gradientEnd: Color(0xFF0C1A10),
      glowColor: Color(0xFFE8C547),
      glowStrength: 0.15,
      blurSigma: 0,
    ),
    motion: AppMotion.fallback,
  ),
  // 9. Paper & Ink
  ThemePreset(
    id: 'paper_ink',
    name: 'Kâğıt ve Mürekkep',
    description: 'E-okuyucu / kağıt minimalizmi',
    brightness: Brightness.light,
    colors: _c(
      scaffold: Color(0xFFF4F4F0),
      surface1: Color(0xFFFAFAF6),
      surface2: Color(0xFFECECE6),
      primary: Color(0xFF1C1C1C),
      onPrimary: Color(0xFFF4F4F0),
      accent: Color(0xFFB91C1C),
      onAccent: Color(0xFFFFF5F5),
      textPrimary: Color(0xFF1C1C1C),
      textSecondary: Color(0xFF5C5C5C),
      border: Color(0xFFD4D4CC),
    ),
    shapes: const AppShapes(
      radiusSm: 4,
      radiusMd: 6,
      radiusLg: 8,
      cardElevation: 0,
      borderWidth: 1,
    ),
    atmosphere: const AppAtmosphere(
      gradientStart: Color(0xFFF4F4F0),
      gradientEnd: Color(0xFFF4F4F0),
      glowColor: Color(0xFF1C1C1C),
      glowStrength: 0,
      blurSigma: 0,
    ),
    motion: AppMotion.snappy,
    serifTitles: true,
    monospaceClock: false,
  ),
  // 10. Yumuşak pastel
  ThemePreset(
    id: 'pastel_day',
    name: 'Yumuşak Pastel',
    description: 'Yumuşak tonlar — bahar pastel, yuvarlak UI',
    brightness: Brightness.light,
    colors: _c(
      scaffold: Color(0xFFE6E6FA),
      surface1: Color(0xFFFAFAFF),
      surface2: Color(0xFFDDD6FE),
      primary: Color(0xFFA78BFA),
      onPrimary: Color(0xFF1E1035),
      accent: Color(0xFF6EE7B7),
      onAccent: Color(0xFF064E3B),
      textPrimary: Color(0xFF2E1065),
      textSecondary: Color(0xFF6B7280),
      border: Color(0xFFC4B5FD),
    ),
    shapes: AppShapes.bubble,
    atmosphere: const AppAtmosphere(
      gradientStart: Color(0xFFE6E6FA),
      gradientEnd: Color(0xFFFCE7F3),
      glowColor: Color(0xFFA78BFA),
      glowStrength: 0.2,
      blurSigma: 0,
    ),
    motion: AppMotion.fallback,
    monospaceClock: false,
  ),
  // 11. Royal Academy
  ThemePreset(
    id: 'royal_academy',
    name: 'Kraliyet Akademi',
    description: 'Gece mavisi + altın varak',
    brightness: Brightness.dark,
    colors: _c(
      scaffold: Color(0xFF001427),
      surface1: Color(0xFF0A1F33),
      surface2: Color(0xFF122A40),
      primary: Color(0xFFD4AF37),
      onPrimary: Color(0xFF1A1400),
      accent: Color(0xFFF0D78C),
      onAccent: Color(0xFF1A1400),
      textPrimary: Color(0xFFF5F0E1),
      textSecondary: Color(0xFFA8B2C0),
      border: Color(0xFF3D4F5F),
    ),
    shapes: AppShapes.soft,
    atmosphere: const AppAtmosphere(
      gradientStart: Color(0xFF001427),
      gradientEnd: Color(0xFF0A1A2E),
      glowColor: Color(0xFFD4AF37),
      glowStrength: 0.3,
      blurSigma: 0,
    ),
    motion: AppMotion.fallback,
    serifTitles: true,
  ),
  // 12. Dynamic Material You (seed fallback; runtime seed ile ezilebilir)
  ThemePreset(
    id: 'material_you',
    name: 'Material You',
    description: 'Sistem / dinamik tohum rengi (Android 12+ hissi)',
    brightness: Brightness.dark,
    colors: _c(
      scaffold: Color(0xFF1A1B1E),
      surface1: Color(0xFF24262A),
      surface2: Color(0xFF2E3136),
      primary: Color(0xFFA8C7FA),
      onPrimary: Color(0xFF062E6F),
      accent: Color(0xFFC2C1FF),
      onAccent: Color(0xFF2A2A60),
      textPrimary: Color(0xFFE3E2E6),
      textSecondary: Color(0xFFC4C6D0),
      border: Color(0xFF44474E),
    ),
    shapes: AppShapes.soft,
    atmosphere: const AppAtmosphere(
      gradientStart: Color(0xFF1A1B1E),
      gradientEnd: Color(0xFF1A1B1E),
      glowColor: Color(0xFFA8C7FA),
      glowStrength: 0.1,
      blurSigma: 0,
    ),
    motion: AppMotion.fallback,
    isDynamic: true,
  ),
  // 13. Buzul — koyu buz / glacier
  ThemePreset(
    id: 'glacier_ice',
    name: 'Buzul',
    description: 'Buzul teması — buz mavisi, soğuk keskin odak',
    brightness: Brightness.dark,
    colors: _c(
      scaffold: Color(0xFF0A1419),
      surface1: Color(0xFF0F1E28),
      surface2: Color(0xFF163040),
      primary: Color(0xFF7DD3FC),
      onPrimary: Color(0xFF082F49),
      accent: Color(0xFFA5F3FC),
      onAccent: Color(0xFF083344),
      textPrimary: Color(0xFFE0F2FE),
      textSecondary: Color(0xFF7BA3B8),
      border: Color(0xFF1E3A4A),
    ),
    shapes: AppShapes.sharpBox,
    atmosphere: const AppAtmosphere(
      gradientStart: Color(0xFF0A1419),
      gradientEnd: Color(0xFF0C2433),
      glowColor: Color(0xFF7DD3FC),
      glowStrength: 0.35,
      blurSigma: 6,
    ),
    motion: AppMotion.snappy,
  ),
  // 14. Yumuşak krem — warm soft
  ThemePreset(
    id: 'soft_cream',
    name: 'Yumuşak Krem',
    description: 'Yumuşak ton — krem, lavanta, yuvarlak kartlar',
    brightness: Brightness.light,
    colors: _c(
      scaffold: Color(0xFFFAF6F1),
      surface1: Color(0xFFFFFCF8),
      surface2: Color(0xFFF0E8DF),
      primary: Color(0xFFC4A484),
      onPrimary: Color(0xFF2A1F14),
      accent: Color(0xFFB8A9C9),
      onAccent: Color(0xFF1F1630),
      textPrimary: Color(0xFF3D3229),
      textSecondary: Color(0xFF8A7B6E),
      border: Color(0xFFE8DDD2),
    ),
    shapes: AppShapes.bubble,
    atmosphere: const AppAtmosphere(
      gradientStart: Color(0xFFFAF6F1),
      gradientEnd: Color(0xFFF3EAF5),
      glowColor: Color(0xFFC4A484),
      glowStrength: 0.12,
      blurSigma: 0,
    ),
    motion: AppMotion.fallback,
    monospaceClock: false,
  ),
  // 15. Gelecek kenarı — ultra modern chrome
  ThemePreset(
    id: 'future_edge',
    name: 'Gelecek Kenarı',
    description: 'Keskin modern gelecek — krom, cyan, flat UI',
    brightness: Brightness.dark,
    colors: _c(
      scaffold: Color(0xFF09090B),
      surface1: Color(0xFF121216),
      surface2: Color(0xFF1C1C22),
      primary: Color(0xFF22D3EE),
      onPrimary: Color(0xFF083344),
      accent: Color(0xFFE4E4E7),
      onAccent: Color(0xFF18181B),
      textPrimary: Color(0xFFFAFAFA),
      textSecondary: Color(0xFFA1A1AA),
      border: Color(0xFF27272A),
    ),
    shapes: AppShapes.sharpBox,
    atmosphere: const AppAtmosphere(
      gradientStart: Color(0xFF09090B),
      gradientEnd: Color(0xFF0E1520),
      glowColor: Color(0xFF22D3EE),
      glowStrength: 0.4,
      blurSigma: 4,
    ),
    motion: AppMotion.snappy,
  ),
];

ThemePreset themePresetById(String id) => kThemePresets.firstWhere(
      (p) => p.id == id,
      orElse: () => kThemePresets.first,
    );

/// Eski AppPalette id → en yakın ThemePreset (yalnız ilk kurulum / family yokken).
/// **Not (WP-71):** Bu map artık `setPalette` ile aileyi ezmez; lacivert ≠ kamp ateşi.
String migratePaletteIdToPreset(String paletteId) {
  const map = {
    'navy': 'ocean_glass',
    'purple': 'neon_focus',
    'emerald': 'forest_study',
    'sunset': 'campfire_night',
    'ocean': 'ocean_glass',
    'slate_mint': 'nordic_snow',
    'rose_noir': 'neon_focus',
    'cyber_blue': 'glacier_ice',
    'forest': 'forest_study',
    'cream_coffee': 'coffee_library',
    'mono_amber': 'campfire_night',
  };
  if (paletteId.startsWith('custom_')) return 'deep_amoled';
  return map[paletteId] ?? 'ocean_glass';
}
