import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// 1) Renk katmanı — semantik yüzey/metin/vurgu token'ları (TEMA-MIMARISI §1).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.surface1,
    required this.surface2,
    required this.scaffold,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.onAccent,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.success,
    required this.error,
    required this.onError,
  });

  final Color surface1;
  final Color surface2;
  final Color scaffold;
  final Color primary;
  final Color onPrimary;
  final Color accent;
  final Color onAccent;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color success;
  final Color error;
  final Color onError;

  factory AppColors.fromScheme(ColorScheme s) => AppColors(
        surface1: s.surface,
        surface2: s.surfaceContainerHigh,
        scaffold: s.surfaceContainerLowest,
        primary: s.primary,
        onPrimary: s.onPrimary,
        accent: s.secondary,
        onAccent: s.onSecondary,
        textPrimary: s.onSurface,
        textSecondary: s.onSurfaceVariant,
        border: s.outlineVariant,
        success: const Color(0xFF22C55E),
        error: s.error,
        onError: s.onError,
      );

  @override
  AppColors copyWith({
    Color? surface1,
    Color? surface2,
    Color? scaffold,
    Color? primary,
    Color? onPrimary,
    Color? accent,
    Color? onAccent,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? success,
    Color? error,
    Color? onError,
  }) {
    return AppColors(
      surface1: surface1 ?? this.surface1,
      surface2: surface2 ?? this.surface2,
      scaffold: scaffold ?? this.scaffold,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      success: success ?? this.success,
      error: error ?? this.error,
      onError: onError ?? this.onError,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      surface1: Color.lerp(surface1, other.surface1, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      scaffold: Color.lerp(scaffold, other.scaffold, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      success: Color.lerp(success, other.success, t)!,
      error: Color.lerp(error, other.error, t)!,
      onError: Color.lerp(onError, other.onError, t)!,
    );
  }
}

/// 2) Tipografi katmanı.
@immutable
class AppTypography extends ThemeExtension<AppTypography> {
  const AppTypography({
    required this.displayClock,
    required this.title,
    required this.body,
    required this.label,
    this.useSerifTitles = false,
    this.useMonospaceClock = true,
  });

  final TextStyle displayClock;
  final TextStyle title;
  final TextStyle body;
  final TextStyle label;
  final bool useSerifTitles;
  final bool useMonospaceClock;

  factory AppTypography.standard({
    required Color textPrimary,
    bool serif = false,
    bool monoClock = true,
  }) {
    final titleFamily = serif ? 'serif' : null;
    final clockFamily = monoClock ? 'monospace' : titleFamily;
    return AppTypography(
      displayClock: TextStyle(
        fontFamily: clockFamily,
        fontSize: 48,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: monoClock ? 1.2 : 0,
      ),
      title: TextStyle(
        fontFamily: titleFamily,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      body: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: textPrimary,
        height: 1.35,
      ),
      label: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      useSerifTitles: serif,
      useMonospaceClock: monoClock,
    );
  }

  @override
  AppTypography copyWith({
    TextStyle? displayClock,
    TextStyle? title,
    TextStyle? body,
    TextStyle? label,
    bool? useSerifTitles,
    bool? useMonospaceClock,
  }) {
    return AppTypography(
      displayClock: displayClock ?? this.displayClock,
      title: title ?? this.title,
      body: body ?? this.body,
      label: label ?? this.label,
      useSerifTitles: useSerifTitles ?? this.useSerifTitles,
      useMonospaceClock: useMonospaceClock ?? this.useMonospaceClock,
    );
  }

  @override
  AppTypography lerp(ThemeExtension<AppTypography>? other, double t) {
    if (other is! AppTypography) return this;
    return AppTypography(
      displayClock: TextStyle.lerp(displayClock, other.displayClock, t)!,
      title: TextStyle.lerp(title, other.title, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      label: TextStyle.lerp(label, other.label, t)!,
      useSerifTitles: t < 0.5 ? useSerifTitles : other.useSerifTitles,
      useMonospaceClock: t < 0.5 ? useMonospaceClock : other.useMonospaceClock,
    );
  }
}

/// 3) Şekil ve derinlik.
@immutable
class AppShapes extends ThemeExtension<AppShapes> {
  const AppShapes({
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.cardElevation,
    required this.borderWidth,
    this.sharp = false,
  });

  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double cardElevation;
  final double borderWidth;
  final bool sharp;

  static const AppShapes soft = AppShapes(
    radiusSm: 8,
    radiusMd: 16,
    radiusLg: 24,
    cardElevation: 0,
    borderWidth: 1,
  );

  static const AppShapes bubble = AppShapes(
    radiusSm: 16,
    radiusMd: 28,
    radiusLg: 40,
    cardElevation: 2,
    borderWidth: 0,
  );

  static const AppShapes sharpBox = AppShapes(
    radiusSm: 0,
    radiusMd: 0,
    radiusLg: 0,
    cardElevation: 0,
    borderWidth: 1,
    sharp: true,
  );

  BorderRadius get cardRadius =>
      BorderRadius.circular(sharp ? 0 : radiusMd);

  @override
  AppShapes copyWith({
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? cardElevation,
    double? borderWidth,
    bool? sharp,
  }) {
    return AppShapes(
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      cardElevation: cardElevation ?? this.cardElevation,
      borderWidth: borderWidth ?? this.borderWidth,
      sharp: sharp ?? this.sharp,
    );
  }

  @override
  AppShapes lerp(ThemeExtension<AppShapes>? other, double t) {
    if (other is! AppShapes) return this;
    return AppShapes(
      radiusSm: lerpDouble(radiusSm, other.radiusSm, t)!,
      radiusMd: lerpDouble(radiusMd, other.radiusMd, t)!,
      radiusLg: lerpDouble(radiusLg, other.radiusLg, t)!,
      cardElevation: lerpDouble(cardElevation, other.cardElevation, t)!,
      borderWidth: lerpDouble(borderWidth, other.borderWidth, t)!,
      sharp: t < 0.5 ? sharp : other.sharp,
    );
  }
}

/// 4) Atmosfer (gradient, glow, blur).
@immutable
class AppAtmosphere extends ThemeExtension<AppAtmosphere> {
  const AppAtmosphere({
    required this.gradientStart,
    required this.gradientEnd,
    required this.glowColor,
    required this.glowStrength,
    required this.blurSigma,
    this.glassOpacity = 0.0,
  });

  final Color gradientStart;
  final Color gradientEnd;
  final Color glowColor;
  final double glowStrength;
  final double blurSigma;
  final double glassOpacity;

  LinearGradient get scaffoldGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [gradientStart, gradientEnd],
      );

  @override
  AppAtmosphere copyWith({
    Color? gradientStart,
    Color? gradientEnd,
    Color? glowColor,
    double? glowStrength,
    double? blurSigma,
    double? glassOpacity,
  }) {
    return AppAtmosphere(
      gradientStart: gradientStart ?? this.gradientStart,
      gradientEnd: gradientEnd ?? this.gradientEnd,
      glowColor: glowColor ?? this.glowColor,
      glowStrength: glowStrength ?? this.glowStrength,
      blurSigma: blurSigma ?? this.blurSigma,
      glassOpacity: glassOpacity ?? this.glassOpacity,
    );
  }

  @override
  AppAtmosphere lerp(ThemeExtension<AppAtmosphere>? other, double t) {
    if (other is! AppAtmosphere) return this;
    return AppAtmosphere(
      gradientStart: Color.lerp(gradientStart, other.gradientStart, t)!,
      gradientEnd: Color.lerp(gradientEnd, other.gradientEnd, t)!,
      glowColor: Color.lerp(glowColor, other.glowColor, t)!,
      glowStrength: lerpDouble(glowStrength, other.glowStrength, t)!,
      blurSigma: lerpDouble(blurSigma, other.blurSigma, t)!,
      glassOpacity: lerpDouble(glassOpacity, other.glassOpacity, t)!,
    );
  }
}

/// 5) Animasyon / hareket (Reduce Motion uyumlu).
@immutable
class AppMotion extends ThemeExtension<AppMotion> {
  const AppMotion({
    required this.fast,
    required this.normal,
    required this.slow,
    this.respectReduceMotion = true,
  });

  final Duration fast;
  final Duration normal;
  final Duration slow;
  final bool respectReduceMotion;

  static const AppMotion fallback = AppMotion(
    fast: Duration(milliseconds: 150),
    normal: Duration(milliseconds: 280),
    slow: Duration(milliseconds: 450),
  );

  static const AppMotion snappy = AppMotion(
    fast: Duration(milliseconds: 100),
    normal: Duration(milliseconds: 200),
    slow: Duration(milliseconds: 320),
  );

  Duration resolve(Duration base, {required bool reduceMotion}) {
    if (respectReduceMotion && reduceMotion) return Duration.zero;
    return base;
  }

  @override
  AppMotion copyWith({
    Duration? fast,
    Duration? normal,
    Duration? slow,
    bool? respectReduceMotion,
  }) {
    return AppMotion(
      fast: fast ?? this.fast,
      normal: normal ?? this.normal,
      slow: slow ?? this.slow,
      respectReduceMotion: respectReduceMotion ?? this.respectReduceMotion,
    );
  }

  @override
  AppMotion lerp(ThemeExtension<AppMotion>? other, double t) {
    if (other is! AppMotion) return this;
    return AppMotion(
      fast: t < 0.5 ? fast : other.fast,
      normal: t < 0.5 ? normal : other.normal,
      slow: t < 0.5 ? slow : other.slow,
      respectReduceMotion:
          t < 0.5 ? respectReduceMotion : other.respectReduceMotion,
    );
  }
}

/// Kolay erişim: `context.appColors` …
extension AppThemeTokensX on BuildContext {
  AppColors get appColors {
    final ext = Theme.of(this).extension<AppColors>();
    if (ext != null) return ext;
    return AppColors.fromScheme(Theme.of(this).colorScheme);
  }

  AppTypography get appTypography {
    final ext = Theme.of(this).extension<AppTypography>();
    if (ext != null) return ext;
    return AppTypography.standard(
      textPrimary: Theme.of(this).colorScheme.onSurface,
    );
  }

  AppShapes get appShapes =>
      Theme.of(this).extension<AppShapes>() ?? AppShapes.soft;

  AppAtmosphere get appAtmosphere {
    final ext = Theme.of(this).extension<AppAtmosphere>();
    if (ext != null) return ext;
    final s = Theme.of(this).colorScheme;
    return AppAtmosphere(
      gradientStart: s.surface,
      gradientEnd: s.surface,
      glowColor: s.primary,
      glowStrength: 0,
      blurSigma: 0,
    );
  }

  AppMotion get appMotion =>
      Theme.of(this).extension<AppMotion>() ?? AppMotion.fallback;
}
