import 'package:flutter/material.dart';

/// WP-157: erişilebilir seri renkleri — colorScheme + sabit offset.
/// Yalnız renge dayanma: her seri indeksi için [patternLabel] kullan.
class SeriesPalette {
  const SeriesPalette(this.scheme);

  final ColorScheme scheme;

  static const _patterns = ['●', '■', '▲', '◆', '○', '□', '△', '◇'];

  Color colorAt(int index) {
    final base = <Color>[
      scheme.primary,
      scheme.tertiary,
      scheme.secondary,
      scheme.error,
      scheme.primaryContainer,
      scheme.tertiaryContainer,
      scheme.secondaryContainer,
      scheme.outline,
    ];
    return base[index % base.length];
  }

  String patternLabel(int index) => _patterns[index % _patterns.length];

  /// Etiket + renk: "● Matematik"
  String labeled(int index, String name) =>
      '${patternLabel(index)} $name';
}
