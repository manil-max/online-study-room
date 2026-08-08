import 'package:flutter/material.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import 'theme_presets.dart';
import 'theme_tokens.dart';

export 'theme_presets.dart';
export 'theme_tokens.dart';

/// Seçilebilir renk paleti (eski WP-26 yolu — ThemePreset ile köprülenir).
/// Yeni kod: `ThemePreset` / `context.appColors`.
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

  String localizedName(AppLocalizations l10n) => switch (id) {
    'navy' => l10n.coreLacivert,
    'purple' => l10n.coreMorGece,
    'emerald' => l10n.coreZumrut,
    'sunset' => l10n.coreGunBatimi,
    'ocean' => l10n.coreOkyanus,
    'slate_mint' => l10n.coreSlateMint,
    'custom_1' => '${l10n.profileOzelPalet} 1',
    'custom_2' => '${l10n.profileOzelPalet} 2',
    'custom_3' => '${l10n.profileOzelPalet} 3',
    _ => name,
  };

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'primary': primary.toARGB32(),
      'onPrimary': onPrimary.toARGB32(),
      'accent': accent.toARGB32(),
      'onAccent': onAccent.toARGB32(),
    };
  }

  factory AppPalette.fromMap(Map<String, dynamic> map) {
    return AppPalette(
      id: map['id'] as String,
      name: map['name'] as String,
      primary: Color(map['primary'] as int),
      onPrimary: Color(map['onPrimary'] as int),
      accent: Color(map['accent'] as int),
      onAccent: Color(map['onAccent'] as int),
    );
  }
}

/// Hazır paletler (ilk: kardeşin tasarım referansı — lacivert/mavi).
const List<AppPalette> kAppPalettes = [
  AppPalette(
    id: 'navy',
    name: 'Navy',
    primary: Color(0xFF3186E9),
    onPrimary: Color(0xFFF4F9FF),
    accent: Color(0xFF12C281),
    onAccent: Color(0xFF06140E),
  ),
  AppPalette(
    id: 'purple',
    name: 'Purple Night',
    primary: Color(0xFF8B5CF6),
    onPrimary: Color(0xFFF6F2FF),
    accent: Color(0xFFEC4899),
    onAccent: Color(0xFF1B0712),
  ),
  AppPalette(
    id: 'emerald',
    name: 'Emerald',
    primary: Color(0xFF12C281),
    onPrimary: Color(0xFF04130D),
    accent: Color(0xFF3186E9),
    onAccent: Color(0xFFF4F9FF),
  ),
  AppPalette(
    id: 'sunset',
    name: 'Sunset',
    primary: Color(0xFFF97362),
    onPrimary: Color(0xFF230803),
    accent: Color(0xFFF5A524),
    onAccent: Color(0xFF201400),
  ),
  AppPalette(
    id: 'ocean',
    name: 'Ocean',
    primary: Color(0xFF22B8CF),
    onPrimary: Color(0xFF04161A),
    accent: Color(0xFF6366F1),
    onAccent: Color(0xFFF1F2FF),
  ),
  AppPalette(
    id: 'slate_mint',
    name: 'Slate Mint',
    primary: Color(0xFF94A3B8),
    onPrimary: Color(0xFF0F172A),
    accent: Color(0xFF34D399),
    onAccent: Color(0xFF022C22),
  ),
  AppPalette(
    id: 'rose_noir',
    name: 'Rose Noir',
    primary: Color(0xFFF43F5E),
    onPrimary: Color(0xFF20030A),
    accent: Color(0xFF9CA3AF),
    onAccent: Color(0xFF111827),
  ),
  AppPalette(
    id: 'cyber_blue',
    name: 'Cyber Blue',
    primary: Color(0xFF00E5FF),
    onPrimary: Color(0xFF001F24),
    accent: Color(0xFFFF007F),
    onAccent: Color(0xFF240011),
  ),
  AppPalette(
    id: 'forest',
    name: 'Forest',
    primary: Color(0xFF22C55E),
    onPrimary: Color(0xFF021707),
    accent: Color(0xFFEAB308),
    onAccent: Color(0xFF1C1401),
  ),
  AppPalette(
    id: 'cream_coffee',
    name: 'Cream Coffee',
    primary: Color(0xFFD4A373),
    onPrimary: Color(0xFF2A1C11),
    accent: Color(0xFFFAEDCD),
    onAccent: Color(0xFF3A311D),
  ),
  AppPalette(
    id: 'mono_amber',
    name: 'Mono Amber',
    primary: Color(0xFFF59E0B),
    onPrimary: Color(0xFF241400),
    accent: Color(0xFFFCD34D),
    onAccent: Color(0xFF241C04),
  ),
];

/// id'ye karşılık gelen palet (bilinmeyen → ilk palet).
AppPalette paletteById(String id) => kAppPalettes.firstWhere(
  (p) => p.id == id,
  orElse: () => kAppPalettes.first,
);

/// WP-54: 5 katmanlı ThemeExtension + 12 preset motoru.
/// Geriye uyum: [light]/[dark] hâlâ AppPalette kabul eder (eski ayar ekranı).
class AppTheme {
  AppTheme._();

  /// Seçili aileyi hem açık hem koyu moda uyarlar (beta: tema “gelmedi” düzeltmesi).
  ///
  /// Ailenin kendi brightness'i ile eşleşiyorsa full token; karşı moda
  /// [ColorScheme.fromSeed] ile primary/accent DNA taşınır.
  static ThemeData fromFamily(
    ThemePreset family,
    Brightness brightness, {
    Color? dynamicSeed,
  }) {
    if (family.isDynamic) {
      final seed = dynamicSeed ?? family.colors.primary;
      final scheme = ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
      );
      final colors = AppColors.fromScheme(scheme).copyWith(
        scaffold: scheme.surfaceContainerLowest,
        surface1: scheme.surface,
        surface2: scheme.surfaceContainerHigh,
      );
      return _buildFromTokens(
        colors: colors,
        shapes: family.shapes,
        atmosphere: family.atmosphere.copyWith(glowColor: scheme.primary),
        motion: family.motion,
        rawTypography: family.typography(),
        brightness: brightness,
      );
    }
    if (family.brightness == brightness) {
      return fromPreset(family, dynamicSeed: dynamicSeed);
    }
    // Karşı parlaklık: aile primary ile seed, yüzeyler moda göre.
    final scheme = ColorScheme.fromSeed(
      seedColor: family.colors.primary,
      brightness: brightness,
    );
    final colors = AppColors.fromScheme(scheme).copyWith(
      primary: family.colors.primary,
      onPrimary: family.colors.onPrimary,
      accent: family.colors.accent,
      onAccent: family.colors.onAccent,
      scaffold: scheme.surfaceContainerLowest,
      surface1: scheme.surface,
      surface2: scheme.surfaceContainerHigh,
    );
    return _buildFromTokens(
      colors: colors,
      shapes: family.shapes,
      atmosphere: family.atmosphere.copyWith(
        glowColor: family.colors.primary,
        gradientStart: colors.scaffold,
        gradientEnd: colors.surface1,
      ),
      motion: family.motion,
      rawTypography: AppTypography.standard(
        textPrimary: colors.textPrimary,
        serif: family.serifTitles,
        monoClock: family.monospaceClock,
      ),
      brightness: brightness,
    );
  }

  /// Tercih edilen giriş: sanat ailesi (ThemePreset).
  static ThemeData fromPreset(ThemePreset preset, {Color? dynamicSeed}) {
    var colors = preset.colors;
    if (preset.isDynamic && dynamicSeed != null) {
      final scheme = ColorScheme.fromSeed(
        seedColor: dynamicSeed,
        brightness: preset.brightness,
      );
      colors = AppColors.fromScheme(scheme).copyWith(
        scaffold: scheme.surfaceContainerLowest,
        surface1: scheme.surface,
        surface2: scheme.surfaceContainerHigh,
      );
    }
    return _buildFromTokens(
      colors: colors,
      shapes: preset.shapes,
      atmosphere: preset.atmosphere,
      motion: preset.motion,
      rawTypography: preset.typography(),
      brightness: preset.brightness,
    );
  }

  /// Eski yol: palet → en yakın preset (veya palet renkleriyle override).
  static ThemeData dark(AppPalette palette) {
    final base = themePresetById(migratePaletteIdToPreset(palette.id));
    final colors = base.colors.copyWith(
      primary: palette.primary,
      onPrimary: palette.onPrimary,
      accent: palette.accent,
      onAccent: palette.onAccent,
    );
    return _buildFromTokens(
      colors: colors,
      shapes: base.shapes,
      atmosphere: base.atmosphere.copyWith(
        glowColor: palette.primary,
        gradientStart: colors.scaffold,
        gradientEnd: colors.surface1,
      ),
      motion: base.motion,
      rawTypography: AppTypography.standard(textPrimary: colors.textPrimary),
      brightness: Brightness.dark,
    );
  }

  static ThemeData light(AppPalette palette) {
    final nordic = themePresetById('nordic_snow');
    final colors = nordic.colors.copyWith(
      primary: palette.primary,
      onPrimary: palette.onPrimary,
      accent: palette.accent,
      onAccent: palette.onAccent,
    );
    return _buildFromTokens(
      colors: colors,
      shapes: nordic.shapes,
      atmosphere: nordic.atmosphere.copyWith(glowColor: palette.primary),
      motion: nordic.motion,
      rawTypography: AppTypography.standard(textPrimary: colors.textPrimary),
      brightness: Brightness.light,
    );
  }

  /// WP-288: Yerel özel tema, hazır preset'e dönmeden tam token setinden kurulur.
  static ThemeData fromCustomTokens({
    required AppColors colors,
    required AppTypography typography,
    required AppShapes shapes,
    required AppAtmosphere atmosphere,
    required AppFeel feel,
    required Brightness brightness,
  }) => _buildFromTokens(
    colors: colors,
    shapes: shapes,
    atmosphere: atmosphere,
    motion: feel.motion,
    feel: feel,
    rawTypography: typography,
    brightness: brightness,
  );

  static ThemeData _buildFromTokens({
    required AppColors colors,
    required AppShapes shapes,
    required AppAtmosphere atmosphere,
    required AppMotion motion,
    AppFeel? feel,
    required AppTypography rawTypography,
    required Brightness brightness,
  }) {
    // 🔴 WP-308: tipografi **her zaman** aktif varyantın metin rengiyle
    // tazelenir. `CustomTheme` tipografiyi tek kopya saklar (açık varyantın
    // metin rengi pişmiş hâlde) ve `main.dart` aynı kopyayı hem açık hem koyu
    // `ThemeData`'ya verir. Tazelenmezse koyu modda başlık/gövde/etiket açık
    // varyantın **koyu** metin rengiyle çizilir: kullanıcı metni açık seçmiş
    // olsa bile yazılar zemine gömülür ("bazı yazılar okunmuyor").
    final typography = rawTypography.recolored(colors.textPrimary);
    final scheme = ColorScheme(
      brightness: brightness,
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      secondary: colors.accent,
      onSecondary: colors.onAccent,
      tertiary: colors.accent,
      onTertiary: colors.onAccent,
      error: colors.error,
      onError: colors.onError,
      surface: colors.surface1,
      onSurface: colors.textPrimary,
      onSurfaceVariant: colors.textSecondary,
      surfaceContainerLowest: colors.scaffold,
      surfaceContainerLow: Color.alphaBlend(
        colors.surface1.withValues(alpha: 0.5),
        colors.scaffold,
      ),
      surfaceContainer: colors.surface1,
      surfaceContainerHigh: colors.surface2,
      surfaceContainerHighest: colors.surface2,
      outline: colors.border,
      outlineVariant: colors.border.withValues(alpha: 0.7),
    );

    final radius = shapes.cardRadius;
    final rSm = BorderRadius.circular(shapes.sharp ? 0 : shapes.radiusSm);

    final resolvedFeel = feel ?? AppFeel.modern.copyWith(motion: motion);
    final defaultTextTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
    ).textTheme;
    TextStyle themed(TextStyle base, TextStyle token) {
      // Hazır/eski temalar yalnız dört slotu özelleştiriyordu. Aile verilmemiş
      // ek slotları Material varsayılanında bırakarak migration görünümünü koru;
      // özel font seçildiğinde ise token tüm ilgili yüzeylere uygulanır.
      if (token.fontFamily == null) return base;
      return base.copyWith(
        fontFamily: token.fontFamily,
        // 🔴 WP-297: fallback zinciri de taşınmalı. Aksi hâlde gömülü (Latin)
        // bir aile seçildiğinde `displayLarge` dışındaki TÜM slotlar zincirsiz
        // kalır ve Arapça/eksik glifler (ör. JetBrains Mono'da `₺`) kutu
        // karakter olarak çizilir — token'da zincir doğru kurulmuş olsa bile.
        fontFamilyFallback:
            token.fontFamilyFallback ?? base.fontFamilyFallback,
        fontWeight: token.fontWeight,
        letterSpacing: token.letterSpacing ?? base.letterSpacing,
        color: token.color ?? colors.textPrimary,
      );
    }

    final textTheme = TextTheme(
      displayLarge: typography.displayClock,
      displayMedium: themed(defaultTextTheme.displayMedium!, typography.title),
      displaySmall: themed(defaultTextTheme.displaySmall!, typography.title),
      headlineLarge: themed(defaultTextTheme.headlineLarge!, typography.title),
      headlineMedium: themed(
        defaultTextTheme.headlineMedium!,
        typography.title,
      ),
      headlineSmall: themed(defaultTextTheme.headlineSmall!, typography.title),
      titleLarge: typography.title,
      titleMedium: themed(defaultTextTheme.titleMedium!, typography.title),
      titleSmall: themed(defaultTextTheme.titleSmall!, typography.title),
      bodyLarge: themed(defaultTextTheme.bodyLarge!, typography.body),
      bodyMedium: typography.body,
      bodySmall: themed(defaultTextTheme.bodySmall!, typography.body),
      labelLarge: themed(defaultTextTheme.labelLarge!, typography.label),
      labelMedium: typography.label,
      labelSmall: themed(defaultTextTheme.labelSmall!, typography.label),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.scaffold,
      extensions: <ThemeExtension<dynamic>>[
        colors,
        typography,
        shapes,
        atmosphere,
        resolvedFeel.motion,
        resolvedFeel,
      ],
      cardTheme: CardThemeData(
        color: colors.surface1,
        elevation: shapes.cardElevation,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: colors.border, width: shapes.borderWidth),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.scaffold,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: typography.title,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface1,
        indicatorColor: colors.primary.withValues(alpha: 0.18),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return typography.label.copyWith(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? colors.primary : colors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? colors.primary : colors.textSecondary,
          );
        }),
      ),
      dividerTheme: DividerThemeData(color: colors.border, thickness: 1),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStatePropertyAll(BorderSide(color: colors.border)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? colors.primary.withValues(alpha: 0.18)
                : scheme.surface.withValues(alpha: 0),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? colors.primary
                : colors.textSecondary,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: rSm),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        // WP-534: hata metni TEK SATIRA sigdirilip kesiliyordu. Sahip sahada
        // "The new password cannot be th..." gordu -- cumlenin yarisi yok ve
        // kullanici ne yapmasi gerektigini anlamiyor. Olculdu: ayar yokken
        // uzun hata 16.0 px (tek satir), ayarla sariliyor.
        // Duzeltme her alana tek tek degil TEMADA bir kez yapilir; aksi halde
        // eklenen her yeni alan ayni hatayi yeniden uretir.
        errorMaxLines: 3,
        helperMaxLines: 3,
        filled: true,
        fillColor: colors.surface2.withValues(alpha: 0.6),
        border: OutlineInputBorder(
          borderRadius: rSm,
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: rSm,
          borderSide: BorderSide(color: colors.border),
        ),
      ),
      textTheme: textTheme,
    );
  }
}
