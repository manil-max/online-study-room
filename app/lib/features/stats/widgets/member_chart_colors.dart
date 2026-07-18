import 'package:flutter/material.dart';

/// Üye kimliğinden türetilen, grafikler arasında sabit kalan renkler.
/// Aynı kişi katkı donut'ında ve liderlik geçmişinde hep aynı rengi alır.
const _memberChartPalette = <Color>[
  Color(0xFF3186E9),
  Color(0xFF12C281),
  Color(0xFFE69825),
  Color(0xFFC35DD9),
  Color(0xFFF3625D),
  Color(0xFF4DD0E1),
  Color(0xFFFF8A65),
  Color(0xFF9CCC65),
  Color(0xFF7986CB),
  Color(0xFFF06292),
];

/// Liste sırası veya sıralama değişse bile üyenin rengi değişmez.
Color memberChartColor(String memberId) {
  var hash = 0x811c9dc5;
  for (final unit in memberId.codeUnits) {
    hash = (hash ^ unit) * 0x01000193;
    hash &= 0x7fffffff;
  }
  return _memberChartPalette[hash % _memberChartPalette.length];
}
