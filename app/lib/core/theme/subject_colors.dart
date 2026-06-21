import 'package:flutter/material.dart';

import '../../data/models/subject.dart';

/// Ders renk token'larını (`chart-1`..`chart-5`) gerçek renklere çevirir.
/// Değerler tasarım referansındaki paletin (oklch) yaklaşık sRGB karşılıklarıdır
/// (bkz. project.md §3.7). Nihai ton tasarım aşamasında ince ayar edilebilir.
// Kardeşin tasarım referansındaki oklch paletinin sRGB karşılıkları (globals.css).
const Map<String, Color> _subjectColors = <String, Color>{
  'chart-1': Color(0xFF3186E9), // mavi
  'chart-2': Color(0xFF12C281), // yeşil / teal
  'chart-3': Color(0xFFE69825), // sarı / amber
  'chart-4': Color(0xFFC35DD9), // mor
  'chart-5': Color(0xFFF3625D), // mercan / kırmızı
};

/// Token'a karşılık gelen renk (bilinmeyen token → paletin ilk rengi).
Color subjectColor(String token) =>
    _subjectColors[token] ?? _subjectColors[kSubjectColorTokens.first]!;
