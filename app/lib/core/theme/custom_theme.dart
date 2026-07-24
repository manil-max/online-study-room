import 'package:flutter/material.dart';

import 'theme_tokens.dart';

/// Cihazda saklanan, üç sabit yuvadan birindeki tema sözleşmesi.
@immutable
class CustomTheme {
  const CustomTheme({
    required this.id,
    required this.name,
    required this.isDefined,
    required this.updatedAt,
    required this.lightColors,
    required this.darkColors,
    required this.typography,
    required this.shapes,
    required this.atmosphere,
    required this.feel,
    this.schemaVersion = currentSchemaVersion,
    this.rawJson,
  });

  static const currentSchemaVersion = 2;
  final String id;
  final String name;
  final bool isDefined;
  final DateTime? updatedAt;
  final AppColors lightColors;
  final AppColors darkColors;
  final AppTypography typography;
  final AppShapes shapes;
  final AppAtmosphere atmosphere;
  final AppFeel feel;
  final int schemaVersion;
  final Map<String, dynamic>? rawJson;

  bool get isReadOnly => schemaVersion > currentSchemaVersion;
  AppColors colorsFor(Brightness brightness) =>
      brightness == Brightness.light ? lightColors : darkColors;

  CustomTheme copyWith({String? name, bool? isDefined, DateTime? updatedAt}) =>
      CustomTheme(
        id: id,
        name: name ?? this.name,
        isDefined: isDefined ?? this.isDefined,
        updatedAt: updatedAt ?? this.updatedAt,
        lightColors: lightColors,
        darkColors: darkColors,
        typography: typography,
        shapes: shapes,
        atmosphere: atmosphere,
        feel: feel,
        schemaVersion: schemaVersion,
        rawJson: rawJson,
      );

  Map<String, dynamic> toMap() =>
      rawJson ??
      <String, dynamic>{
        'schemaVersion': currentSchemaVersion,
        'id': id,
        'name': name,
        'isDefined': isDefined,
        'updatedAt': updatedAt?.toIso8601String(),
        'lightColors': _colors(lightColors),
        'darkColors': _colors(darkColors),
        'typography': _typography(typography),
        'shapes': _shapes(shapes),
        'atmosphere': _atmosphere(atmosphere),
        'feel': _feel(feel),
      };

  static CustomTheme? tryParse(Map<String, dynamic> source) {
    try {
      final version = source['schemaVersion'] as int? ?? 1;
      final id = source['id'] as String?;
      final name = source['name'] as String?;
      if (id == null || name == null) return null;
      final parsed = CustomTheme(
        id: id,
        name: name,
        isDefined: source['isDefined'] as bool? ?? true,
        updatedAt: DateTime.tryParse(source['updatedAt'] as String? ?? ''),
        lightColors: _readColors(source['lightColors']),
        darkColors: _readColors(source['darkColors']),
        typography: _readTypography(source['typography']),
        shapes: _readShapes(source['shapes']),
        atmosphere: _readAtmosphere(source['atmosphere']),
        feel: _readFeel(source['feel']),
        schemaVersion: version,
        rawJson: version > currentSchemaVersion ? Map.of(source) : null,
      );
      return parsed;
    } catch (_) {
      return null;
    }
  }
}

int _argb(Color color) => color.toARGB32();
Map<String, dynamic> _colors(AppColors v) => {
  'surface1': _argb(v.surface1),
  'surface2': _argb(v.surface2),
  'scaffold': _argb(v.scaffold),
  'primary': _argb(v.primary),
  'onPrimary': _argb(v.onPrimary),
  'accent': _argb(v.accent),
  'onAccent': _argb(v.onAccent),
  'textPrimary': _argb(v.textPrimary),
  'textSecondary': _argb(v.textSecondary),
  'border': _argb(v.border),
  'success': _argb(v.success),
  'error': _argb(v.error),
  'onError': _argb(v.onError),
};
Map<String, dynamic> _map(Object? value) =>
    Map<String, dynamic>.from(value as Map);
Color _color(Map<String, dynamic> m, String key) => Color(m[key] as int);
AppColors _readColors(Object? v) {
  final m = _map(v);
  return AppColors(
    surface1: _color(m, 'surface1'),
    surface2: _color(m, 'surface2'),
    scaffold: _color(m, 'scaffold'),
    primary: _color(m, 'primary'),
    onPrimary: _color(m, 'onPrimary'),
    accent: _color(m, 'accent'),
    onAccent: _color(m, 'onAccent'),
    textPrimary: _color(m, 'textPrimary'),
    textSecondary: _color(m, 'textSecondary'),
    border: _color(m, 'border'),
    success: _color(m, 'success'),
    error: _color(m, 'error'),
    onError: _color(m, 'onError'),
  );
}

Map<String, dynamic> _style(TextStyle s) => {
  'family': s.fontFamily,
  'size': s.fontSize,
  'weight': s.fontWeight?.value,
  'color': s.color == null ? null : _argb(s.color!),
  'height': s.height,
  'spacing': s.letterSpacing,
};
TextStyle _readStyle(Object? v) {
  final m = _map(v);
  final weight = m['weight'] as int?;
  return TextStyle(
    fontFamily: m['family'] as String?,
    fontSize: (m['size'] as num?)?.toDouble(),
    fontWeight: weight == null
        ? null
        : FontWeight.values.firstWhere(
            (w) => w.value == weight,
            orElse: () => FontWeight.normal,
          ),
    color: m['color'] == null ? null : Color(m['color'] as int),
    height: (m['height'] as num?)?.toDouble(),
    letterSpacing: (m['spacing'] as num?)?.toDouble(),
  );
}

Map<String, dynamic> _typography(AppTypography v) => {
  'displayClock': _style(v.displayClock),
  'title': _style(v.title),
  'body': _style(v.body),
  'label': _style(v.label),
  'serif': v.useSerifTitles,
  'mono': v.useMonospaceClock,
};
AppTypography _readTypography(Object? v) {
  final m = _map(v);
  return AppTypography(
    displayClock: _readStyle(m['displayClock']),
    title: _readStyle(m['title']),
    body: _readStyle(m['body']),
    label: _readStyle(m['label']),
    useSerifTitles: m['serif'] as bool? ?? false,
    useMonospaceClock: m['mono'] as bool? ?? true,
  );
}

Map<String, dynamic> _shapes(AppShapes v) => {
  'sm': v.radiusSm,
  'md': v.radiusMd,
  'lg': v.radiusLg,
  'elevation': v.cardElevation,
  'border': v.borderWidth,
  'sharp': v.sharp,
};
AppShapes _readShapes(Object? v) {
  final m = _map(v);
  return AppShapes(
    radiusSm: (m['sm'] as num).toDouble(),
    radiusMd: (m['md'] as num).toDouble(),
    radiusLg: (m['lg'] as num).toDouble(),
    cardElevation: (m['elevation'] as num).toDouble(),
    borderWidth: (m['border'] as num).toDouble(),
    sharp: m['sharp'] as bool? ?? false,
  );
}

Map<String, dynamic> _atmosphere(AppAtmosphere v) => {
  'start': _argb(v.gradientStart),
  'end': _argb(v.gradientEnd),
  'glow': _argb(v.glowColor),
  'strength': v.glowStrength,
  'blur': v.blurSigma,
  'glass': v.glassOpacity,
};
AppAtmosphere _readAtmosphere(Object? v) {
  final m = _map(v);
  return AppAtmosphere(
    gradientStart: Color(m['start'] as int),
    gradientEnd: Color(m['end'] as int),
    glowColor: Color(m['glow'] as int),
    glowStrength: (m['strength'] as num).toDouble(),
    blurSigma: (m['blur'] as num).toDouble(),
    glassOpacity: (m['glass'] as num?)?.toDouble() ?? 0,
  );
}

Map<String, dynamic> _feel(AppFeel v) => {
  'id': v.feelId,
  'grain': v.grainStrength,
  'kind': v.grainKind,
  'edge': v.edgeIrregularity,
  'fast': v.motion.fast.inMilliseconds,
  'normal': v.motion.normal.inMilliseconds,
  'slow': v.motion.slow.inMilliseconds,
  'reduce': v.motion.respectReduceMotion,
};
AppFeel _readFeel(Object? v) {
  final m = _map(v);
  return AppFeel(
    feelId: m['id'] as String,
    grainStrength: (m['grain'] as num).toDouble(),
    grainKind: m['kind'] as String,
    edgeIrregularity: (m['edge'] as num).toDouble(),
    motion: AppMotion(
      fast: Duration(milliseconds: m['fast'] as int),
      normal: Duration(milliseconds: m['normal'] as int),
      slow: Duration(milliseconds: m['slow'] as int),
      respectReduceMotion: m['reduce'] as bool? ?? true,
    ),
  );
}
