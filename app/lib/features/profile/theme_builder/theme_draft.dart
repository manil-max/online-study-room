import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/custom_theme.dart';
import 'theme_contrast.dart';
import 'theme_feel_catalog.dart';

/// Sihirbazın yazı adımı için kullanıcı seçimleri.
///
/// `AppTypography` dört hazır `TextStyle` tutar; sihirbaz bunları **türetir**.
/// Böylece kayıtlı temadan geri okunabilir (round-trip) ve WP-288 modeli
/// değişmeden kalır.
@immutable
class DraftTypography {
  const DraftTypography({
    this.titleFamily = kFontFamilySans,
    this.bodyFamily = kFontFamilySans,
    this.clockFamily = kFontFamilyMono,
    this.weightStep = 0,
    this.scale = 1.0,
    this.letterSpacing = 0.0,
  });

  /// Genel yazı tipi seçenekleri — platformun kendi aileleri.
  ///
  /// ADR-4'ün paketlenmiş font asset'leri bu WP'de **eklenmedi** (bkz. teslim
  /// notu); sözleşme `fontFamily` string'i olduğu için sonradan paketlenmiş bir
  /// aile eklemek yalnız bu listeye + `pubspec.yaml`'a satır eklemektir.
  /// Genel aileler Android/Windows'ta sistem fontuna çözülür; eksik glif
  /// olmadığı için AR/RTL'de kutu karakter riski yoktur.
  static const kFamilies = [kFontFamilySans, kFontFamilySerif, kFontFamilyMono];

  final String titleFamily;
  final String bodyFamily;
  final String clockFamily;

  /// -1 = daha ince, 0 = normal, 1 = daha kalın, 2 = en kalın.
  final int weightStep;

  /// Yazı ölçeği (0.85 – 1.30).
  final double scale;

  /// Ek harf aralığı (-0.5 – 1.5).
  final double letterSpacing;

  DraftTypography copyWith({
    String? titleFamily,
    String? bodyFamily,
    String? clockFamily,
    int? weightStep,
    double? scale,
    double? letterSpacing,
  }) => DraftTypography(
    titleFamily: titleFamily ?? this.titleFamily,
    bodyFamily: bodyFamily ?? this.bodyFamily,
    clockFamily: clockFamily ?? this.clockFamily,
    weightStep: weightStep ?? this.weightStep,
    scale: scale ?? this.scale,
    letterSpacing: letterSpacing ?? this.letterSpacing,
  );

  /// Kayıtlı token'lardan sihirbaz durumunu geri kur.
  factory DraftTypography.fromTokens(AppTypography tokens) {
    final titleWeight = tokens.title.fontWeight ?? FontWeight.w700;
    return DraftTypography(
      titleFamily: tokens.title.fontFamily ?? kFontFamilySans,
      bodyFamily: tokens.body.fontFamily ?? kFontFamilySans,
      clockFamily: tokens.displayClock.fontFamily ?? kFontFamilyMono,
      weightStep: _weightStepFor(titleWeight),
      scale: ((tokens.title.fontSize ?? _kBaseTitleSize) / _kBaseTitleSize)
          .clamp(kMinTypographyScale, kMaxTypographyScale),
      letterSpacing: (tokens.body.letterSpacing ?? 0).clamp(-0.5, 1.5),
    );
  }

  /// Seçimleri gerçek `AppTypography` sözleşmesine çevir.
  ///
  /// `app_theme.dart` yalnız `fontFamily != null` olan token'ı ek `TextTheme`
  /// slotlarına taşıdığı için aile **her zaman** açıkça yazılır; aksi hâlde
  /// ağırlık/aralık seçimi yüzeylerin çoğunda etkisiz kalırdı.
  AppTypography toTokens(Color textPrimary) {
    final titleWeight = _weights[(weightStep + 1).clamp(0, _weights.length - 1)];
    final bodyWeight = _bodyWeights[(weightStep + 1).clamp(
      0,
      _bodyWeights.length - 1,
    )];
    return AppTypography(
      displayClock: TextStyle(
        fontFamily: clockFamily,
        fontSize: 48 * scale,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: letterSpacing + (clockFamily == kFontFamilyMono ? 1.2 : 0),
      ),
      title: TextStyle(
        fontFamily: titleFamily,
        fontSize: _kBaseTitleSize * scale,
        fontWeight: titleWeight,
        color: textPrimary,
        letterSpacing: letterSpacing,
      ),
      body: TextStyle(
        fontFamily: bodyFamily,
        fontSize: 15 * scale,
        fontWeight: bodyWeight,
        color: textPrimary,
        height: 1.35,
        letterSpacing: letterSpacing,
      ),
      label: TextStyle(
        fontFamily: bodyFamily,
        fontSize: 12 * scale,
        fontWeight: bodyWeight,
        color: textPrimary,
        letterSpacing: letterSpacing,
      ),
      useSerifTitles: titleFamily == kFontFamilySerif,
      useMonospaceClock: clockFamily == kFontFamilyMono,
    );
  }

  static const _kBaseTitleSize = 20.0;
  static const _weights = [
    FontWeight.w400,
    FontWeight.w700,
    FontWeight.w800,
    FontWeight.w900,
  ];
  static const _bodyWeights = [
    FontWeight.w300,
    FontWeight.w400,
    FontWeight.w500,
    FontWeight.w600,
  ];

  static int _weightStepFor(FontWeight weight) {
    final index = _weights.indexWhere((w) => w.value >= weight.value);
    if (index < 0) return _weights.length - 2;
    return index - 1;
  }
}

const String kFontFamilySans = 'sans-serif';
const String kFontFamilySerif = 'serif';
const String kFontFamilyMono = 'monospace';

const double kMinTypographyScale = 0.85;
const double kMaxTypographyScale = 1.3;

/// Tema adı üst sınırı (kart edge-case'i: "çok uzun tema adı ≤ 24 karakter").
const int kThemeNameMaxLength = 24;

/// Sihirbazın düzenlediği geçici tema — kaydedilene kadar hiçbir yere yazılmaz.
@immutable
class ThemeDraft {
  const ThemeDraft({
    required this.slotId,
    required this.name,
    required this.lightColors,
    required this.darkColors,
    required this.typography,
    required this.shapes,
    required this.atmosphere,
    required this.feel,
    this.editing = Brightness.dark,
    this.counterpartEdited = false,
  });

  final String slotId;
  final String name;
  final AppColors lightColors;
  final AppColors darkColors;
  final DraftTypography typography;
  final AppShapes shapes;
  final AppAtmosphere atmosphere;
  final AppFeel feel;

  /// Renk adımının düzenlediği varyant; karşı varyant bundan türetilir.
  final Brightness editing;

  /// Karşı varyant kullanıcı tarafından elle değiştirildi mi? (true ise
  /// otomatik türetme onu artık ezmez.)
  final bool counterpartEdited;

  Brightness get counterpart =>
      editing == Brightness.light ? Brightness.dark : Brightness.light;

  AppColors colorsFor(Brightness brightness) =>
      brightness == Brightness.light ? lightColors : darkColors;

  AppTypography typographyFor(Brightness brightness) =>
      typography.toTokens(colorsFor(brightness).textPrimary);

  ThemeDraft copyWith({
    String? slotId,
    String? name,
    AppColors? lightColors,
    AppColors? darkColors,
    DraftTypography? typography,
    AppShapes? shapes,
    AppAtmosphere? atmosphere,
    AppFeel? feel,
    Brightness? editing,
    bool? counterpartEdited,
  }) => ThemeDraft(
    slotId: slotId ?? this.slotId,
    name: name ?? this.name,
    lightColors: lightColors ?? this.lightColors,
    darkColors: darkColors ?? this.darkColors,
    typography: typography ?? this.typography,
    shapes: shapes ?? this.shapes,
    atmosphere: atmosphere ?? this.atmosphere,
    feel: feel ?? this.feel,
    editing: editing ?? this.editing,
    counterpartEdited: counterpartEdited ?? this.counterpartEdited,
  );

  /// Düzenlenen varyantın renklerini değiştir ve karşı varyantı **elle
  /// düzenlenmediyse** yeniden türet (ADR-1: iki tam renk seti).
  ThemeDraft withEditedColors(AppColors colors) {
    final light = editing == Brightness.light ? colors : lightColors;
    final dark = editing == Brightness.dark ? colors : darkColors;
    if (counterpartEdited) {
      return copyWith(lightColors: light, darkColors: dark);
    }
    final derived = deriveCounterpartColors(colors, counterpart);
    return copyWith(
      lightColors: editing == Brightness.light ? light : derived,
      darkColors: editing == Brightness.dark ? dark : derived,
    );
  }

  /// Karşı varyant elle düzenlendi — bundan sonra türetme onu ezmez.
  ThemeDraft withCounterpartColors(AppColors colors) {
    final light = counterpart == Brightness.light ? colors : lightColors;
    final dark = counterpart == Brightness.dark ? colors : darkColors;
    return copyWith(
      lightColors: light,
      darkColors: dark,
      counterpartEdited: true,
    );
  }

  /// Karşı varyantı yeniden türet (kullanıcı "yeniden türet" derse).
  ThemeDraft withRederivedCounterpart() {
    final derived = deriveCounterpartColors(colorsFor(editing), counterpart);
    return copyWith(
      lightColors: counterpart == Brightness.light ? derived : lightColors,
      darkColors: counterpart == Brightness.dark ? derived : darkColors,
      counterpartEdited: false,
    );
  }

  /// His seçimi şekil ve atmosfer karakterini birlikte ayarlar.
  ThemeDraft withFeel(AppFeel next) => copyWith(
    feel: next,
    shapes: shapesForFeel(next.feelId, shapes),
    atmosphere: atmosphereForFeel(next.feelId, atmosphere),
  );

  ThemeData themeFor(Brightness brightness) => AppTheme.fromCustomTokens(
    colors: colorsFor(brightness),
    typography: typographyFor(brightness),
    shapes: shapes,
    atmosphere: atmosphere,
    feel: feel,
    brightness: brightness,
  );

  CustomTheme toCustomTheme() => CustomTheme(
    id: slotId,
    name: name,
    isDefined: true,
    updatedAt: DateTime.now(),
    lightColors: lightColors,
    darkColors: darkColors,
    // Tipografi renkleri açık varyanta göre yazılır; `_buildFromTokens` metin
    // rengini zaten aktif `AppColors.textPrimary` ile tazeler.
    typography: typographyFor(Brightness.light),
    shapes: shapes,
    atmosphere: atmosphere,
    feel: feel,
  );

  factory ThemeDraft.fromCustomTheme(CustomTheme theme) => ThemeDraft(
    slotId: theme.id,
    name: theme.name,
    lightColors: theme.lightColors,
    darkColors: theme.darkColors,
    typography: DraftTypography.fromTokens(theme.typography),
    shapes: theme.shapes,
    atmosphere: theme.atmosphere,
    feel: theme.feel,
    editing: Brightness.dark,
    // Kayıtlı temada iki varyant da gerçek; türetme onları ezmemeli.
    counterpartEdited: true,
  );

  /// Yeni tema: seçilen hazır aile "zemin" olarak alınır.
  factory ThemeDraft.fromPreset({
    required String slotId,
    required String name,
    required ThemePreset preset,
  }) {
    final base = AppTheme.fromFamily(preset, preset.brightness);
    final baseColors = base.extension<AppColors>()!;
    final other = AppTheme.fromFamily(
      preset,
      preset.brightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark,
    );
    final otherColors = other.extension<AppColors>()!;
    final isDark = preset.brightness == Brightness.dark;
    return ThemeDraft(
      slotId: slotId,
      name: name,
      lightColors: isDark ? otherColors : baseColors,
      darkColors: isDark ? baseColors : otherColors,
      typography: DraftTypography(
        titleFamily: preset.serifTitles ? kFontFamilySerif : kFontFamilySans,
        bodyFamily: preset.serifTitles ? kFontFamilySerif : kFontFamilySans,
        clockFamily: preset.monospaceClock ? kFontFamilyMono : kFontFamilySans,
      ),
      shapes: preset.shapes,
      atmosphere: preset.atmosphere,
      feel: AppFeel.modern.copyWith(motion: preset.motion),
      editing: preset.brightness,
    );
  }
}

/// Bir renk setinden karşı parlaklık varyantını türet.
///
/// Vurgu DNA'sı (primary/accent) korunur; yüzeyler ters çevrilir, metin ve
/// kenarlık yeni zemine göre **AA'yı geçecek biçimde** yeniden hesaplanır.
/// WP-288 R16: tek renk seti yetmez, bu yüzden türetme ayrı ve saf tutulur.
AppColors deriveCounterpartColors(AppColors source, Brightness target) {
  final toDark = target == Brightness.dark;
  final scaffold = toDark ? const Color(0xFF0C0F16) : const Color(0xFFF7F8FB);
  final surface1 = toDark ? const Color(0xFF151A23) : const Color(0xFFFFFFFF);
  final surface2 = toDark ? const Color(0xFF1E2430) : const Color(0xFFEDEFF5);
  final border = toDark ? const Color(0xFF2A3240) : const Color(0xFFD8DCE6);

  // Vurgu renkleri korunur ama yeni zeminde okunabilir olmalı.
  final primary = fixForegroundForAa(source.primary, surface1, large: true);
  final accent = fixForegroundForAa(source.accent, surface1, large: true);
  final textPrimary = fixForegroundForAa(
    toDark ? const Color(0xFFE9ECF3) : const Color(0xFF141821),
    scaffold,
  );
  final textSecondary = fixForegroundForAa(
    toDark ? const Color(0xFF9AA4B6) : const Color(0xFF5A6376),
    scaffold,
  );

  return AppColors(
    scaffold: scaffold,
    surface1: surface1,
    surface2: surface2,
    primary: primary,
    onPrimary: readableOn(primary),
    accent: accent,
    onAccent: readableOn(accent),
    textPrimary: textPrimary,
    textSecondary: textSecondary,
    border: border,
    success: source.success,
    error: source.error,
    onError: source.onError,
  );
}
