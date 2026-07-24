import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/profile/theme_builder/theme_contrast.dart';

void main() {
  group('contrastRatio', () {
    test('siyah-beyaz azami oranı verir', () {
      expect(
        contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21.0, 0.01),
      );
    });

    test('aynı renk 1:1 verir ve sıra fark etmez', () {
      const color = Color(0xFF3186E9);
      expect(contrastRatio(color, color), closeTo(1.0, 0.001));
      expect(
        contrastRatio(color, const Color(0xFFFFFFFF)),
        closeTo(contrastRatio(const Color(0xFFFFFFFF), color), 0.001),
      );
    });
  });

  group('meetsContrastAa', () {
    test('normal metin 4.5:1 eşiğini kullanır', () {
      // #767676 beyaz üstünde ~4.54:1 — geçer.
      expect(
        meetsContrastAa(const Color(0xFF767676), const Color(0xFFFFFFFF)),
        isTrue,
      );
      // #999999 beyaz üstünde ~2.85:1 — kalır.
      expect(
        meetsContrastAa(const Color(0xFF999999), const Color(0xFFFFFFFF)),
        isFalse,
      );
    });

    test('büyük metin 3:1 eşiğinde daha toleranslıdır', () {
      const grey = Color(0xFF949494);
      const white = Color(0xFFFFFFFF);
      expect(meetsContrastAa(grey, white), isFalse);
      expect(meetsContrastAa(grey, white, large: true), isTrue);
    });
  });

  group('fixForegroundForAa', () {
    test('geçen rengi değiştirmez', () {
      const fg = Color(0xFF000000);
      const bg = Color(0xFFFFFFFF);
      expect(fixForegroundForAa(fg, bg), fg);
    });

    test('koyu zeminde rengi aydınlatarak AA yapar', () {
      const bg = Color(0xFF0C0F16);
      const fg = Color(0xFF1B2436);
      expect(meetsContrastAa(fg, bg), isFalse);
      final fixed = fixForegroundForAa(fg, bg);
      expect(meetsContrastAa(fixed, bg), isTrue);
      expect(relativeLuminance(fixed), greaterThan(relativeLuminance(fg)));
    });

    test('açık zeminde rengi karartarak AA yapar', () {
      const bg = Color(0xFFF7F8FB);
      const fg = Color(0xFFE0E4EC);
      final fixed = fixForegroundForAa(fg, bg);
      expect(meetsContrastAa(fixed, bg), isTrue);
      expect(relativeLuminance(fixed), lessThan(relativeLuminance(fg)));
    });

    test('hiçbir ton yetmezse siyah/beyaza düşer ve AA sağlanır', () {
      const bg = Color(0xFF808080);
      final fixed = fixForegroundForAa(const Color(0xFF7F7F7F), bg);
      expect(meetsContrastAa(fixed, bg), isTrue);
    });
  });

  test('readableOn zemine göre okunur uç rengi seçer', () {
    expect(readableOn(const Color(0xFF000000)), const Color(0xFFFFFFFF));
    expect(readableOn(const Color(0xFFFFFFFF)), const Color(0xFF000000));
  });
}
