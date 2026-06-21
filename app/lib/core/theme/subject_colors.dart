import 'package:flutter/material.dart';

import '../../data/models/subject.dart';

/// Ders renk token'larını (`chart-1`..`chart-5`) gerçek renklere çevirir.
/// Değerler tasarım referansındaki paletin (oklch) yaklaşık sRGB karşılıklarıdır
/// (bkz. project.md §3.7). Nihai ton tasarım aşamasında ince ayar edilebilir.
const Map<String, Color> _subjectColors = <String, Color>{
  'chart-1': Color(0xFF4C8DF6), // mavi
  'chart-2': Color(0xFF34C98A), // yeşil
  'chart-3': Color(0xFFD9A441), // sarı / amber
  'chart-4': Color(0xFFB370E0), // mor
  'chart-5': Color(0xFFE0685A), // kırmızı
};

/// Token'a karşılık gelen renk (bilinmeyen token → paletin ilk rengi).
Color subjectColor(String token) =>
    _subjectColors[token] ?? _subjectColors[kSubjectColorTokens.first]!;
