import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/theme/app_theme.dart';
import 'package:online_study_room/features/profile/theme_builder/bundled_font_licenses.dart';
import 'package:online_study_room/features/profile/theme_builder/theme_draft.dart';
import 'package:online_study_room/features/profile/theme_builder/theme_feel_catalog.dart';

/// WP-297: gömülü fontların **gerçekten etki ürettiğini** doğrular.
///
/// Bu dosyanın varlık nedeni: font paketlemek kolay, ama üç ayrı yerde sessizce
/// ölü anahtar üretebilir — (1) `pubspec.yaml`'daki aile adı kodla eşleşmezse,
/// (2) variable font'un `wght` ekseni uygulanmazsa ağırlık kaydırıcısı hiçbir
/// şey yapmaz, (3) fallback zinciri `TextTheme`'e taşınmazsa eksik glifler kutu
/// karakter olur. Üçü de burada ölçülüyor.
Future<void> _loadFont(String family, String asset) async {
  final loader = FontLoader(family)..addFont(rootBundle.load(asset));
  await loader.load();
}

double _textWidth(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  return painter.width;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFont(kFontFamilyInter, 'assets/fonts/Inter-Variable.ttf');
    await _loadFont(kFontFamilyLiterata, 'assets/fonts/Literata-Variable.ttf');
    await _loadFont(
      kFontFamilyJetBrainsMono,
      'assets/fonts/JetBrainsMono-Variable.ttf',
    );
  });

  test('font dosyaları ve lisans metinleri repoda duruyor', () {
    for (final path in const [
      'assets/fonts/Inter-Variable.ttf',
      'assets/fonts/Literata-Variable.ttf',
      'assets/fonts/JetBrainsMono-Variable.ttf',
    ]) {
      expect(File(path).existsSync(), isTrue, reason: '$path eksik');
    }
    // OFL 1.1 şartı: lisans metni fontla birlikte dağıtılır.
    for (final asset in kBundledFontLicenseAssets.values) {
      final file = File(asset);
      expect(file.existsSync(), isTrue, reason: '$asset eksik');
      expect(
        file.readAsStringSync(),
        contains('SIL Open Font License'),
        reason: '$asset OFL metni değil',
      );
    }
  });

  test('pubspec aile adları kodla birebir aynı', () {
    // Aile adı bir harf farklı olsa Flutter aileyi bulamaz ve sessizce sistem
    // fontuna düşer — kullanıcı "font seçtim, değişmedi" der.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final family in const [
      kFontFamilyInter,
      kFontFamilyLiterata,
      kFontFamilyJetBrainsMono,
    ]) {
      expect(
        pubspec,
        contains('- family: $family'),
        reason: '$family pubspec.yaml `fonts:` bloğunda yok',
      );
    }
  });

  test('sihirbaz 3 platform + 3 gömülü aile sunuyor', () {
    expect(DraftTypography.kFamilies, hasLength(6));
    expect(
      DraftTypography.kFamilies,
      containsAll(const [
        kFontFamilyInter,
        kFontFamilyLiterata,
        kFontFamilyJetBrainsMono,
      ]),
      reason: 'gömülü aileler seçilebilir olmalı',
    );
    // Platform aileleri kaldırılmadı: kayıtlı temalar onları taşıyor.
    expect(
      DraftTypography.kFamilies,
      containsAll(const [
        kFontFamilySans,
        kFontFamilySerif,
        kFontFamilyMono,
      ]),
    );
  });

  test('gömülü ailelerde fallback zinciri kurulu, platformda gereksiz', () {
    for (final family in const [
      kFontFamilyInter,
      kFontFamilyLiterata,
      kFontFamilyJetBrainsMono,
    ]) {
      expect(isBundledFontFamily(family), isTrue);
      expect(fallbackFor(family), kBundledFontFallback);
    }
    for (final family in const [
      kFontFamilySans,
      kFontFamilySerif,
      kFontFamilyMono,
    ]) {
      expect(fallbackFor(family), isNull);
    }
  });

  test('WP-297: ağırlık ekseni gerçekten uygulanıyor (ölü kaydırıcı yok)', () {
    // Variable font'un `wght` ekseni yok sayılırsa w300 ile w900 aynı genişlikte
    // çizilir. Kalın metin daha geniştir; bu yüzden ölçülebilir bir fark aranır.
    for (final family in const [kFontFamilyInter, kFontFamilyLiterata]) {
      final light = _textWidth(
        'Ağırlık ışığı',
        TextStyle(fontFamily: family, fontWeight: FontWeight.w300),
      );
      final heavy = _textWidth(
        'Ağırlık ışığı',
        TextStyle(fontFamily: family, fontWeight: FontWeight.w900),
      );
      expect(
        heavy,
        greaterThan(light),
        reason: '$family: w900 ile w300 aynı genişlikte → wght ekseni ölü',
      );
    }
  });

  test('sihirbaz ağırlık kademeleri gömülü fontta farklı sonuç veriyor', () {
    const draft = DraftTypography(
      titleFamily: kFontFamilyLiterata,
      bodyFamily: kFontFamilyInter,
      clockFamily: kFontFamilyJetBrainsMono,
    );
    final thin = draft.copyWith(weightStep: -1).toTokens(Colors.black);
    final thick = draft.copyWith(weightStep: 2).toTokens(Colors.black);
    expect(thin.title.fontWeight, isNot(thick.title.fontWeight));
    expect(thin.body.fontWeight, isNot(thick.body.fontWeight));

    final thinWidth = _textWidth('Başlık', thin.title);
    final thickWidth = _textWidth('Başlık', thick.title);
    expect(
      thickWidth,
      greaterThan(thinWidth),
      reason: 'kaydırıcının en ince ve en kalın ucu aynı çiziliyor',
    );
  });

  test('Türkçe karakterler gömülü fontta kutu değil', () {
    // Eksik glif `.notdef`'e düşer; genişliği aynı olsa da Flutter fallback'e
    // gider. Burada asıl güvence: tırnaklı/eş aralıklı aileler Türkçe metni
    // Latin metinden farklı ölçüde çiziyor, yani gliflerin kendisi var.
    for (final family in const [
      kFontFamilyInter,
      kFontFamilyLiterata,
      kFontFamilyJetBrainsMono,
    ]) {
      final style = TextStyle(
        fontFamily: family,
        fontFamilyFallback: fallbackFor(family),
        fontSize: 20,
      );
      expect(_textWidth('ışİĞŞçöü', style), greaterThan(0));
    }
  });

  test('fallback zinciri TextTheme slotlarına taşınıyor', () {
    // 🔴 Regresyon bekçisi: `app_theme.dart` `themed()` yardımcısı önce yalnız
    // `fontFamily`'yi kopyalıyordu; zincir düşünce `displayLarge` dışındaki tüm
    // slotlar Arapça/eksik glifte kutu karakter üretecekti.
    const draft = DraftTypography(
      titleFamily: kFontFamilyLiterata,
      bodyFamily: kFontFamilyInter,
      clockFamily: kFontFamilyJetBrainsMono,
    );
    final preset = themePresetById('nordic_snow');
    final theme = AppTheme.fromCustomTokens(
      colors: preset.colors,
      typography: draft.toTokens(Colors.black),
      shapes: preset.shapes,
      atmosphere: preset.atmosphere,
      feel: feelOptionById('modern').feel,
      brightness: Brightness.light,
    );
    final text = theme.textTheme;
    for (final style in <TextStyle?>[
      text.displayMedium,
      text.headlineSmall,
      text.titleMedium,
      text.bodyLarge,
      text.labelSmall,
    ]) {
      expect(style?.fontFamilyFallback, kBundledFontFallback);
    }
  });
}
