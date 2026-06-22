import 'package:flutter/material.dart';

/// Seçilebilir renk paleti (§ tema ayarları). Her palet birincil + vurgu rengini
/// belirler; koyu lacivert zemin tüm paletlerde ortaktır.
class AppPalette {
  const AppPalette({
    required this.id,
    required this.name,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.onAccent,
  });

  final String id;
  final String name;
  final Color primary;
  final Color onPrimary;
  final Color accent;
  final Color onAccent;
}

/// Hazır paletler (ilk: kardeşin tasarım referansı — lacivert/mavi).
const List<AppPalette> kAppPalettes = [
  AppPalette(
    id: 'navy',
    name: 'Lacivert',
    primary: Color(0xFF3186E9),
    onPrimary: Color(0xFFF4F9FF),
    accent: Color(0xFF12C281),
    onAccent: Color(0xFF06140E),
  ),
  AppPalette(
    id: 'purple',
    name: 'Mor Gece',
    primary: Color(0xFF8B5CF6),
    onPrimary: Color(0xFFF6F2FF),
    accent: Color(0xFFEC4899),
    onAccent: Color(0xFF1B0712),
  ),
  AppPalette(
    id: 'emerald',
    name: 'Zümrüt',
    primary: Color(0xFF12C281),
    onPrimary: Color(0xFF04130D),
    accent: Color(0xFF3186E9),
    onAccent: Color(0xFFF4F9FF),
  ),
  AppPalette(
    id: 'sunset',
    name: 'Gün Batımı',
    primary: Color(0xFFF97362),
    onPrimary: Color(0xFF230803),
    accent: Color(0xFFF5A524),
    onAccent: Color(0xFF201400),
  ),
  AppPalette(
    id: 'ocean',
    name: 'Okyanus',
    primary: Color(0xFF22B8CF),
    onPrimary: Color(0xFF04161A),
    accent: Color(0xFF6366F1),
    onAccent: Color(0xFFF1F2FF),
  ),
];

/// id'ye karşılık gelen palet (bilinmeyen → ilk palet).
AppPalette paletteById(String id) => kAppPalettes.firstWhere(
      (p) => p.id == id,
      orElse: () => kAppPalettes.first,
    );

/// Uygulama teması. Koyu lacivert zemin (kardeşin `globals.css` oklch → sRGB);
/// birincil/vurgu rengi seçilen [AppPalette]'ten gelir. Açık tema da sağlanır.
class AppTheme {
  AppTheme._();

  // --- Ortak koyu yüzeyler (tüm paletlerde aynı) ---
  static const Color _bg = Color(0xFF0B1016); // zemin (en koyu lacivert)
  static const Color _card = Color(0xFF151B23); // kart yüzeyi
  static const Color _surfaceHigh = Color(0xFF202730); // ikincil yüzey
  static const Color _amber = Color(0xFFE69825); // tertiary (amber)
  static const Color _fg = Color(0xFFEFF2F5); // metin (near-white)
  static const Color _muted = Color(0xFF9299A2); // soluk metin
  static const Color _error = Color(0xFFEA3C3F);

  static ColorScheme _darkScheme(AppPalette p) =>
      const ColorScheme.dark().copyWith(
        brightness: Brightness.dark,
        primary: p.primary,
        onPrimary: p.onPrimary,
        primaryContainer:
            Color.alphaBlend(p.primary.withValues(alpha: 0.30), _card),
        onPrimaryContainer: p.onPrimary,
        secondary: p.accent,
        onSecondary: p.onAccent,
        secondaryContainer:
            Color.alphaBlend(p.accent.withValues(alpha: 0.30), _card),
        onSecondaryContainer: p.onAccent,
        tertiary: _amber,
        onTertiary: const Color(0xFF241700),
        surface: _card,
        onSurface: _fg,
        onSurfaceVariant: _muted,
        surfaceContainerLowest: _bg,
        surfaceContainerLow: const Color(0xFF11161D),
        surfaceContainer: const Color(0xFF161D26),
        surfaceContainerHigh: const Color(0xFF1B222B),
        surfaceContainerHighest: _surfaceHigh,
        error: _error,
        onError: Colors.white,
        outline: const Color(0xFF2C343F),
        outlineVariant: const Color(0xFF20262E),
      );

  static ColorScheme _lightScheme(AppPalette p) => ColorScheme.fromSeed(
        seedColor: p.primary,
        primary: p.primary,
        secondary: p.accent,
        tertiary: _amber,
      );

  static ThemeData dark(AppPalette palette) =>
      _build(_darkScheme(palette), scaffold: _bg);

  static ThemeData light(AppPalette palette) {
    final scheme = _lightScheme(palette);
    return _build(scheme, scaffold: scheme.surface);
  }

  static ThemeData _build(ColorScheme scheme, {required Color scaffold}) {
    final isDark = scheme.brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF11161D) : scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStatePropertyAll(
              BorderSide(color: scheme.outlineVariant)),
          backgroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? scheme.primary.withValues(alpha: 0.18)
                  : Colors.transparent),
          foregroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? scheme.primary
                  : scheme.onSurfaceVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }
}
