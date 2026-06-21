import 'package:flutter/material.dart';

/// Uygulama teması. Renkler kardeşin tasarım referansından (project-continuation
/// `globals.css`, oklch paleti) sRGB'ye çevrildi: koyu lacivert zemin, canlı mavi
/// primary + yeşil accent. Referans koyu (dark-only) olduğu için varsayılan koyu
/// tema; uyumlu bir açık tema da sağlanır.
class AppTheme {
  AppTheme._();

  // --- Palet (kardeşin globals.css oklch → sRGB) ---
  static const Color _bg = Color(0xFF0B1016); // zemin (en koyu lacivert)
  static const Color _card = Color(0xFF151B23); // kart yüzeyi
  static const Color _surfaceHigh = Color(0xFF202730); // ikincil yüzey
  static const Color _primary = Color(0xFF3186E9); // mavi
  static const Color _onPrimary = Color(0xFFF4F9FF);
  static const Color _accent = Color(0xFF12C281); // yeşil/teal
  static const Color _amber = Color(0xFFE69825); // sarı/amber
  static const Color _fg = Color(0xFFEFF2F5); // metin (near-white)
  static const Color _muted = Color(0xFF9299A2); // soluk metin
  static const Color _error = Color(0xFFEA3C3F);

  static final ColorScheme _darkScheme = const ColorScheme.dark().copyWith(
    brightness: Brightness.dark,
    primary: _primary,
    onPrimary: _onPrimary,
    primaryContainer: const Color(0xFF173759),
    onPrimaryContainer: const Color(0xFFD6E6FF),
    secondary: _accent,
    onSecondary: const Color(0xFF06140E),
    secondaryContainer: const Color(0xFF0F3A2B),
    onSecondaryContainer: const Color(0xFFCFF5E6),
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

  static final ColorScheme _lightScheme = ColorScheme.fromSeed(
    seedColor: _primary,
    primary: _primary,
    secondary: _accent,
    tertiary: _amber,
  );

  static ThemeData get dark => _build(_darkScheme, scaffold: _bg);

  static ThemeData get light =>
      _build(_lightScheme, scaffold: _lightScheme.surface);

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
