import 'dart:math' as math;

import 'package:flutter/material.dart';

/// WP-377: kamp ateşi kompozisyonunun sahip tarafından seçilen iki sayısı.
///
/// Bu iki sabit **tek** yerde durur ki önizleme, üretim ve golden testleri aynı
/// değeri görsün. Sahip önizlemeden bir varyant seçtiğinde değişen yalnız
/// burasıdır.
///
/// [kCampfireSceneHeight] kartın toplam yüksekliğidir. Sahnedeki her painter
/// yükseklik oranlı olduğu için yükseklik tek başına kısaltılırsa kompozisyon
/// da küçülür; gökyüzünü **üstten kırpmak** için yükseklik düşerken
/// [kCampfireGroundYFactor] aynı oranda yükselir ve ateş piksel olarak yerinde
/// kalır.
/// 🔴 Sahip seçimi (2026-07-28, `campfire_wp377_preview.png` üzerinden):
/// gökyüzü üstten **85 px** kırpıldı (360 → 275) ve zemin bandı korundu.
const double kCampfireSceneHeight = 275;

/// `1 − 360 × (1 − 0.66) / 275` — kırpma öncesindeki **zemin bandı** (122.4 px)
/// aynen korunur, yani kısalan tek şey gökyüzüdür.
const double kCampfireGroundYFactor = 0.5549;

/// WP-382 sahibin onayladığı kalabalık sahne kompozisyonu: ateşin **piksel**
/// cinsinden aşağı kaydırması ve oturma yayının dikey açılması.
const double kCampfireFireYOffset = 45;
const double kCampfireSeatVerticalSpread = 1.25;

/// İsim etiketinin (ön sıradaki üye) yazı boyutu. Arka sıra ve canlı süre
/// bundan türetilir; tek sayı değişince üçü birlikte kayar.
const double kCampfireLabelFontSize = 12;

/// Halka merkezinin ateşin **altında** kaldığı sabit piksel payı.
const double kCampfireRingCenterOffset = 18;

/// Oturma elipsinin dikey yarıçapının sahne yüksekliğine oranı.
const double kCampfireRingRyFactor = 0.15;

/// Ufuk çizgisinin halka merkezinden yukarıda kaldığı, dikey yarıçapa oranlı pay.
const double kCampfireHorizonRyFactor = 0.82;

/// 🔴 WP-429 sahip kararı: ateş + oturma halkası ufuktan **bağımsız** olarak
/// aşağı iner.
///
/// v56'ya kadar ufuk ateşin türeviydi (`horizon = fireY + 18 − ...`), yani
/// yeşili büyütmenin tek yolu tüm kompozisyonu yukarı kaydırmaktı. Sahibin
/// istediği bu değil: "yeşili **üste** uzat, hayvanları yukarı kaldırma".
/// Bu pay ateşi ve halkayı ufka göre aşağı iter; ufuk (dolayısıyla yeşil alan
/// yüksekliği) sabit kalır.
double campfireFireY({
  required double sceneHeight,
  required double groundYFactor,
  required double fireYOffset,
  required double fireYPixelOffset,
  double ringDropPixels = 0,
}) =>
    sceneHeight * (groundYFactor + fireYOffset) +
    fireYPixelOffset +
    ringDropPixels;

/// Ufuk çizgisinin sahne üstünden uzaklığı (px) — yeşil zeminin başladığı yer.
///
/// Sahnedeki üç yer (zemin painter'ı, ateş, oturma halkası) aynı türetmeyi
/// kullanır; sayı üç ayrı yerde tekrarlanırsa biri kayınca ufuk ile ateş
/// ayrışır. [fireYOffset] profilin **oranı**, [fireYPixelOffset] WP-382'nin
/// piksel kaydırmasıdır.
double campfireHorizonY({
  required double sceneHeight,
  required double groundYFactor,
  required double fireYOffset,
  required double fireYPixelOffset,
}) {
  final fireY = sceneHeight * (groundYFactor + fireYOffset) + fireYPixelOffset;
  return fireY +
      kCampfireRingCenterOffset -
      sceneHeight * kCampfireRingRyFactor * kCampfireHorizonRyFactor;
}

/// Ufuk ile sahnenin alt kenarı arasında kalan **yeşil alan** yüksekliği (px).
///
/// Sahibin cihazda ölçtüğü büyüklük tam olarak budur ("yeşil kısmın yüksekliği
/// çok az"), bu yüzden önizleme kolu da doğrudan bu sayıyı sürer.
double campfireGreenAreaHeight({
  required double sceneHeight,
  required double groundYFactor,
  required double fireYOffset,
  required double fireYPixelOffset,
}) =>
    sceneHeight -
    campfireHorizonY(
      sceneHeight: sceneHeight,
      groundYFactor: groundYFactor,
      fireYOffset: fireYOffset,
      fireYPixelOffset: fireYPixelOffset,
    );

/// [campfireGreenAreaHeight]'ın tersi: istenen yeşil alanı üreten zemin çıpası.
///
/// Önizlemede sahip **px** seçer; sahne ise oran ile çalışır. Çeviriyi tek
/// fonksiyonda tutmak, iki tarafın ayrışmasını imkânsız kılar.
double campfireGroundYFactorForGreenArea({
  required double sceneHeight,
  required double greenAreaHeight,
  required double fireYOffset,
  required double fireYPixelOffset,
}) {
  final anchorPixels =
      sceneHeight -
      greenAreaHeight -
      fireYPixelOffset -
      kCampfireRingCenterOffset +
      sceneHeight * kCampfireRingRyFactor * kCampfireHorizonRyFactor;
  return anchorPixels / sceneHeight - fireYOffset;
}

/// 🔴 WP-416 sahip başlangıç değeri: telefonda yeşil alan **2×**.
///
/// v55'te bu bant 68,5 px'ti (275 px sahne · telefon `fireYOffset` 0.09 ·
/// WP-382'nin +45 px ateş kaydırması) ve sahip cihazda "yeşil kısmın yüksekliği
/// çok az" dedi. İki katı = 137 px. Sahne yüksekliği **değişmez**; kısalan tek
/// şey gökyüzüdür, böylece kart telefonda aynı yeri kaplar ve hayvanlara alt
/// sırada gerçek yer açılır.
/// 🔴 v56 sahip düzeltmesi (`wp416_green_ladder_8.png` üzerinden, 2026-07-28):
/// 137 px yerine **150 px**, ama kompozisyon yukarı kaymayacak — bkz.
/// [kCampfirePhoneRingDropPixels].
const double kCampfirePhoneGreenAreaHeight = 150;

/// Telefonda ateş + halkanın ufka göre aşağı inme payı (px).
///
/// 137 → 150 yeşil, kompozisyonu 13 px yukarı iterdi; sahip ise onu **aşağıda**
/// istiyor. 13 px geri alınır, üstüne sahibin "biraz aşağı indir" dediği pay
/// eklenir. Sayı önizleme merdiveninden seçilir ve düzen testi kilitler.
const double kCampfirePhoneRingDropPixels = 40;

/// [kCampfirePhoneGreenAreaHeight]'ı üreten telefon zemin çıpası.
///
/// `campfireGroundYFactorForGreenArea(275, 150, 0.09, 45)` = 0.25845.
/// Sabit elle yazılır çünkü profil `const`'tur; testi türetmeyi geri hesaplayıp
/// bandın gerçekten 150 px olduğunu doğrular.
const double kCampfirePhoneGroundYFactor = 0.25845;

/// Telefonda halkanın yatay yarıçap çarpanı (masaüstünde 1.0).
///
/// 🔴 Sahip seçimi (2026-07-28): 1.20 → **1.50**. 8 kişide isimler üst üste
/// biniyordu; halka genişleyince oturma yayı da açıldı.
const double kCampfirePhoneRingWidthMultiplier = 1.5;

/// Marşmelov çubuğunun ucunun ateşe olan **mutlak** boşluğunu halka
/// genişliğinden bağımsız tutar.
///
/// `stickReachFactor` hayvan→ateş mesafesinin bir **oranıdır**; halka
/// genişleyince mesafe büyür ve sabit oran çubuğu ateşten uzaklaştırır — sahibin
/// "ona göre marşmelov çubuğu uzasın" dediği durum tam olarak budur. Oranı
/// halka ölçeğine bölmek boşluğu sabitler: `ringScale == 1` (masaüstü) hiçbir
/// şeyi değiştirmez.
double campfireStickReach(double baseReachFactor, double ringScale) {
  if (ringScale <= 0) return baseReachFactor;
  return (1 - (1 - baseReachFactor) / ringScale).clamp(0.05, 0.98).toDouble();
}

/// Sahnenin masaüstü ve telefon kompozisyonlarını ayıran test edilebilir profil.
///
/// Sadece Android/iOS ve telefon kısa kenarı birlikte sağlanırsa telefon düzeni
/// seçilir. Böylece daraltılmış bir Windows penceresi masaüstü kompozisyonunu
/// korur.
class CampfireViewportProfile {
  const CampfireViewportProfile._({
    required this.isPhone,
    required this.ringWidthMultiplier,
    required this.critterScaleMultiplier,
    required this.fireYOffset,
    required this.fireVisualScale,
    required this.showTrees,
    required this.groundYFactor,
    required this.ringDropPixels,
  });

  const CampfireViewportProfile.desktop()
    : this._(
        isPhone: false,
        ringWidthMultiplier: 1,
        critterScaleMultiplier: 1,
        fireYOffset: 0,
        fireVisualScale: 1,
        showTrees: true,
        groundYFactor: kCampfireGroundYFactor,
        // Masaüstü kompozisyonu sahibin v55'te onayladığı hâlinde kalır.
        ringDropPixels: 0,
      );

  const CampfireViewportProfile.phone()
    : this._(
        isPhone: true,
        ringWidthMultiplier: kCampfirePhoneRingWidthMultiplier,
        critterScaleMultiplier: 0.76,
        fireYOffset: 0.09,
        fireVisualScale: 0.78,
        showTrees: false,
        // WP-416: telefonda yeşil alan 2×. Masaüstü kompozisyonu sahibin v55'te
        // onayladığı hâliyle kalır — bu yüzden çıpa profil başına ayrılır.
        groundYFactor: kCampfirePhoneGroundYFactor,
        ringDropPixels: kCampfirePhoneRingDropPixels,
      );

  factory CampfireViewportProfile.fromConstraints({
    required BoxConstraints constraints,
    required TargetPlatform platform,
  }) {
    final shortestSide = math.min(constraints.maxWidth, constraints.maxHeight);
    final phonePlatform =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;
    return phonePlatform && shortestSide < 600
        ? const CampfireViewportProfile.phone()
        : const CampfireViewportProfile.desktop();
  }

  final bool isPhone;
  final double ringWidthMultiplier;
  final double critterScaleMultiplier;
  final double fireYOffset;
  final double fireVisualScale;
  final bool showTrees;

  /// Zeminin (ve ateşin) sahne yüksekliğine oranı. Yeşil alan yüksekliği bunun
  /// türevidir; bkz. [campfireGreenAreaHeight].
  final double groundYFactor;

  /// Ateş + oturma halkasının ufka göre aşağı inme payı (px); ufku **etkilemez**.
  final double ringDropPixels;
}

/// Sahnenin sahip tarafından ayarlanabilen tüm kolları.
///
/// Üretim çağrıları hiçbirini vermez — varsayılanlar sahibin onayladığı
/// kanonik sayılardır. Parametrik önizleme (`lib/campfire_preview.dart`) ve
/// golden varyantları tek tek ezer. Kollar tek nesnede toplanır ki önizleme
/// ekranı ile sahne arasında **aynı** sözleşme dursun.
@immutable
class CampfireTuning {
  const CampfireTuning({
    this.sceneHeight = kCampfireSceneHeight,
    this.greenAreaHeight,
    this.groundYFactor,
    this.ringWidthScale,
    this.fireYPixelOffset = kCampfireFireYOffset,
    this.seatVerticalSpread = kCampfireSeatVerticalSpread,
    this.labelFontSize = kCampfireLabelFontSize,
    this.critterScale = 1,
    this.ringDropPixels,
  });

  /// Kartın toplam yüksekliği.
  final double sceneHeight;

  /// Ufkun altındaki yeşil bandın hedef yüksekliği (px). `null` ise profilin
  /// kendi çıpası kullanılır.
  final double? greenAreaHeight;

  /// Zemin çıpası doğrudan verilirse [greenAreaHeight]'tan **önce** gelir
  /// (WP-377 golden varyantları bu yolu kullanır).
  final double? groundYFactor;

  /// Halkanın yatay genişlik çarpanı; `null` ise profil çarpanı.
  final double? ringWidthScale;

  /// Ateşin piksel cinsinden aşağı kaydırması (WP-382).
  final double fireYPixelOffset;

  /// Oturma yayının dikey açıklığı — sahibin dilinde "satır aralığı".
  final double seatVerticalSpread;

  /// Ön sıradaki isim etiketinin yazı boyutu.
  final double labelFontSize;

  /// Hayvan gövdesinin ek ölçek çarpanı (profil çarpanının üstüne biner).
  final double critterScale;

  /// Ateş + halkanın ufka göre aşağı inme payı (px); `null` ise profil payı.
  ///
  /// Sahibin dilinde "yeşili üste uzat, hayvanları aşağıda bırak": yeşil alan
  /// kolu ufku **yukarı**, bu kol kompozisyonu **aşağı** taşır ve ikisi
  /// birbirini etkilemez.
  final double? ringDropPixels;

  /// Sahnenin gerçekten kullanacağı halka düşürme payı.
  double resolvedRingDropPixels(CampfireViewportProfile profile) =>
      ringDropPixels ?? profile.ringDropPixels;

  /// Sahnenin gerçekten kullanacağı zemin çıpası.
  double resolvedGroundYFactor(CampfireViewportProfile profile) {
    final explicit = groundYFactor;
    if (explicit != null) return explicit;
    final green = greenAreaHeight;
    if (green != null) {
      return campfireGroundYFactorForGreenArea(
        sceneHeight: sceneHeight,
        greenAreaHeight: green,
        fireYOffset: profile.fireYOffset,
        fireYPixelOffset: fireYPixelOffset,
      );
    }
    return profile.groundYFactor;
  }

  /// Seçili kolların ürettiği yeşil alan yüksekliği (px) — önizlemenin
  /// sahibe gösterdiği ve testin sabitlediği sayı.
  double resolvedGreenAreaHeight(CampfireViewportProfile profile) =>
      campfireGreenAreaHeight(
        sceneHeight: sceneHeight,
        groundYFactor: resolvedGroundYFactor(profile),
        fireYOffset: profile.fireYOffset,
        fireYPixelOffset: fireYPixelOffset,
      );

  CampfireTuning copyWith({
    double? sceneHeight,
    double? greenAreaHeight,
    double? ringWidthScale,
    double? fireYPixelOffset,
    double? seatVerticalSpread,
    double? labelFontSize,
    double? critterScale,
    double? ringDropPixels,
  }) {
    return CampfireTuning(
      sceneHeight: sceneHeight ?? this.sceneHeight,
      greenAreaHeight: greenAreaHeight ?? this.greenAreaHeight,
      groundYFactor: groundYFactor,
      ringWidthScale: ringWidthScale ?? this.ringWidthScale,
      fireYPixelOffset: fireYPixelOffset ?? this.fireYPixelOffset,
      seatVerticalSpread: seatVerticalSpread ?? this.seatVerticalSpread,
      labelFontSize: labelFontSize ?? this.labelFontSize,
      critterScale: critterScale ?? this.critterScale,
      ringDropPixels: ringDropPixels ?? this.ringDropPixels,
    );
  }
}

/// Dikey eksene göre aynalanan bir sol-sağ çiftin normalize konumu.
class CampfirePairPlacement {
  const CampfirePairPlacement({
    required this.horizontalFactor,
    required this.verticalFactor,
  });

  final double horizontalFactor;
  final double verticalFactor;

  CampfirePairPlacement copyWith({
    double? horizontalFactor,
    double? verticalFactor,
  }) {
    return CampfirePairPlacement(
      horizontalFactor: horizontalFactor ?? this.horizontalFactor,
      verticalFactor: verticalFactor ?? this.verticalFactor,
    );
  }
}

/// Tek sayılı profilde bağımsız ayarlanabilen bir hayvan konumu.
class CampfireSinglePlacement {
  const CampfireSinglePlacement({
    required this.horizontalFactor,
    required this.verticalFactor,
  });

  final double horizontalFactor;
  final double verticalFactor;

  CampfireSinglePlacement copyWith({
    double? horizontalFactor,
    double? verticalFactor,
  }) {
    return CampfireSinglePlacement(
      horizontalFactor: horizontalFactor ?? this.horizontalFactor,
      verticalFactor: verticalFactor ?? this.verticalFactor,
    );
  }
}

/// Belirli bir çift kişi sayısına ait bağımsız yerleşim profili.
class CampfireCountLayout {
  const CampfireCountLayout({
    required this.memberCount,
    required this.ringWidthFactor,
    required this.pairs,
    this.singles = const [],
    required this.groundYFactor,
    required this.fireScale,
    required this.stickReachFactor,
    required this.roastCycleMinutes,
  });

  factory CampfireCountLayout.oddDraft(int memberCount) {
    if (memberCount < 1 || memberCount > 7 || memberCount.isEven) {
      throw ArgumentError.value(
        memberCount,
        'memberCount',
        '1, 3, 5 veya 7 olmalı.',
      );
    }
    final singles =
        [
          for (var index = 0; index < memberCount; index++)
            CampfireSinglePlacement(
              horizontalFactor: math.cos(index * math.pi * 2 / memberCount),
              verticalFactor: math.sin(index * math.pi * 2 / memberCount),
            ),
        ]..sort((a, b) {
          final vertical = a.verticalFactor.compareTo(b.verticalFactor);
          return vertical != 0
              ? vertical
              : a.horizontalFactor.compareTo(b.horizontalFactor);
        });
    final neighbor = CampfireCountLayout.saved(
      memberCount == 1 ? 2 : memberCount + 1,
    );
    return CampfireCountLayout(
      memberCount: memberCount,
      ringWidthFactor: neighbor.ringWidthFactor,
      pairs: const [],
      singles: singles,
      groundYFactor: neighbor.groundYFactor,
      fireScale: neighbor.fireScale,
      stickReachFactor: neighbor.stickReachFactor,
      roastCycleMinutes: neighbor.roastCycleMinutes,
    );
  }

  factory CampfireCountLayout.saved(int memberCount) {
    return switch (memberCount) {
      1 => const CampfireCountLayout(
        memberCount: 1,
        ringWidthFactor: 0.24,
        pairs: [],
        singles: [
          CampfireSinglePlacement(horizontalFactor: 1.00, verticalFactor: 0.00),
        ],
        groundYFactor: kCampfireGroundYFactor,
        fireScale: 0.80,
        stickReachFactor: 0.78,
        roastCycleMinutes: 12,
      ),
      2 => const CampfireCountLayout(
        memberCount: 2,
        ringWidthFactor: 0.34,
        pairs: [
          CampfirePairPlacement(horizontalFactor: 0.67, verticalFactor: 0.02),
        ],
        groundYFactor: kCampfireGroundYFactor,
        fireScale: 0.98,
        stickReachFactor: 0.71,
        roastCycleMinutes: 12,
      ),
      3 => const CampfireCountLayout(
        memberCount: 3,
        ringWidthFactor: 0.31,
        pairs: [],
        singles: [
          CampfireSinglePlacement(
            horizontalFactor: -0.57,
            verticalFactor: -0.40,
          ),
          CampfireSinglePlacement(horizontalFactor: 0.70, verticalFactor: 0.00),
          CampfireSinglePlacement(
            horizontalFactor: -0.54,
            verticalFactor: 0.86,
          ),
        ],
        groundYFactor: kCampfireGroundYFactor,
        fireScale: 0.80,
        stickReachFactor: 0.73,
        roastCycleMinutes: 12,
      ),
      4 => const CampfireCountLayout(
        memberCount: 4,
        ringWidthFactor: 0.31,
        pairs: [
          CampfirePairPlacement(horizontalFactor: 0.58, verticalFactor: -0.40),
          CampfirePairPlacement(horizontalFactor: 0.64, verticalFactor: 0.66),
        ],
        groundYFactor: kCampfireGroundYFactor,
        fireScale: 0.80,
        stickReachFactor: 0.73,
        roastCycleMinutes: 12,
      ),
      5 => const CampfireCountLayout(
        memberCount: 5,
        ringWidthFactor: 0.26,
        pairs: [],
        singles: [
          CampfireSinglePlacement(
            horizontalFactor: 0.61,
            verticalFactor: -0.57,
          ),
          CampfireSinglePlacement(
            horizontalFactor: -0.63,
            verticalFactor: -0.44,
          ),
          CampfireSinglePlacement(horizontalFactor: 0.91, verticalFactor: 0.17),
          CampfireSinglePlacement(
            horizontalFactor: -0.70,
            verticalFactor: 0.70,
          ),
          CampfireSinglePlacement(horizontalFactor: 0.47, verticalFactor: 0.95),
        ],
        groundYFactor: kCampfireGroundYFactor,
        fireScale: 0.80,
        stickReachFactor: 0.76,
        roastCycleMinutes: 12,
      ),
      6 => const CampfireCountLayout(
        memberCount: 6,
        ringWidthFactor: 0.35,
        pairs: [
          CampfirePairPlacement(horizontalFactor: 0.40, verticalFactor: -0.68),
          CampfirePairPlacement(horizontalFactor: 0.63, verticalFactor: 0.09),
          CampfirePairPlacement(horizontalFactor: 0.44, verticalFactor: 0.87),
        ],
        groundYFactor: kCampfireGroundYFactor,
        fireScale: 0.80,
        stickReachFactor: 0.76,
        roastCycleMinutes: 12,
      ),
      7 => const CampfireCountLayout(
        memberCount: 7,
        ringWidthFactor: 0.23,
        pairs: [],
        singles: [
          CampfireSinglePlacement(
            horizontalFactor: -0.52,
            verticalFactor: -0.67,
          ),
          CampfireSinglePlacement(
            horizontalFactor: 0.57,
            verticalFactor: -0.68,
          ),
          CampfireSinglePlacement(
            horizontalFactor: -0.92,
            verticalFactor: -0.21,
          ),
          CampfireSinglePlacement(
            horizontalFactor: 0.90,
            verticalFactor: -0.08,
          ),
          CampfireSinglePlacement(
            horizontalFactor: -0.88,
            verticalFactor: 0.60,
          ),
          CampfireSinglePlacement(horizontalFactor: 0.62, verticalFactor: 0.78),
          CampfireSinglePlacement(
            horizontalFactor: -0.44,
            verticalFactor: 0.98,
          ),
        ],
        groundYFactor: kCampfireGroundYFactor,
        fireScale: 0.80,
        stickReachFactor: 0.76,
        roastCycleMinutes: 12,
      ),
      8 => const CampfireCountLayout(
        memberCount: 8,
        ringWidthFactor: 0.34,
        pairs: [
          CampfirePairPlacement(horizontalFactor: 0.34, verticalFactor: -0.85),
          CampfirePairPlacement(horizontalFactor: 0.62, verticalFactor: -0.33),
          CampfirePairPlacement(horizontalFactor: 0.61, verticalFactor: 0.45),
          CampfirePairPlacement(horizontalFactor: 0.31, verticalFactor: 0.92),
        ],
        groundYFactor: kCampfireGroundYFactor,
        fireScale: 0.80,
        stickReachFactor: 0.76,
        roastCycleMinutes: 12,
      ),
      _ => throw ArgumentError.value(
        memberCount,
        'memberCount',
        '1 ile 8 arasında olmalı.',
      ),
    };
  }

  factory CampfireCountLayout.regular(int memberCount) {
    if (memberCount < 2 || memberCount > 8 || memberCount.isOdd) {
      throw ArgumentError.value(
        memberCount,
        'memberCount',
        '2, 4, 6 veya 8 olmalı.',
      );
    }
    final pairCount = memberCount ~/ 2;
    return CampfireCountLayout(
      memberCount: memberCount,
      ringWidthFactor: 0.34,
      pairs: [
        for (var row = 0; row < pairCount; row++)
          CampfirePairPlacement(
            horizontalFactor: math.cos(
              -math.pi / 2 +
                  math.pi / memberCount +
                  row * math.pi * 2 / memberCount,
            ),
            verticalFactor: math.sin(
              -math.pi / 2 +
                  math.pi / memberCount +
                  row * math.pi * 2 / memberCount,
            ),
          ),
      ],
      groundYFactor: 0.56,
      fireScale: 1,
      stickReachFactor: 0.58,
      roastCycleMinutes: 10,
    );
  }

  final int memberCount;
  final double ringWidthFactor;
  final List<CampfirePairPlacement> pairs;
  final List<CampfireSinglePlacement> singles;
  final double groundYFactor;
  final double fireScale;
  final double stickReachFactor;
  final double roastCycleMinutes;

  CampfireCountLayout copyWith({
    double? ringWidthFactor,
    List<CampfirePairPlacement>? pairs,
    List<CampfireSinglePlacement>? singles,
    double? groundYFactor,
    double? fireScale,
    double? stickReachFactor,
    double? roastCycleMinutes,
  }) {
    return CampfireCountLayout(
      memberCount: memberCount,
      ringWidthFactor: ringWidthFactor ?? this.ringWidthFactor,
      pairs: pairs ?? this.pairs,
      singles: singles ?? this.singles,
      groundYFactor: groundYFactor ?? this.groundYFactor,
      fireScale: fireScale ?? this.fireScale,
      stickReachFactor: stickReachFactor ?? this.stickReachFactor,
      roastCycleMinutes: roastCycleMinutes ?? this.roastCycleMinutes,
    );
  }
}

class CampfireSeat {
  const CampfireSeat({required this.x, required this.y, required this.index});

  final double x;
  final double y;
  final int index;

  double get depth => (y + 1) / 2;
}

List<CampfireSeat> campfireSeats(CampfireCountLayout layout) {
  if (layout.memberCount != layout.pairs.length * 2 + layout.singles.length) {
    throw ArgumentError.value(
      '${layout.pairs.length}/${layout.singles.length}',
      'pairs/singles',
      'Çift ve tek konum sayısı üye sayısıyla uyuşmalı.',
    );
  }

  final seats = <CampfireSeat>[];
  for (final pair in layout.pairs) {
    if (pair.horizontalFactor <= 0 ||
        pair.horizontalFactor > 1.2 ||
        pair.verticalFactor < -1 ||
        pair.verticalFactor > 1) {
      throw ArgumentError.value(pair, 'pairs', 'Çift konumu geçersiz.');
    }
    seats.add(
      CampfireSeat(
        x: pair.horizontalFactor,
        y: pair.verticalFactor,
        index: seats.length,
      ),
    );
    seats.add(
      CampfireSeat(
        x: -pair.horizontalFactor,
        y: pair.verticalFactor,
        index: seats.length,
      ),
    );
  }
  for (final single in layout.singles) {
    if (single.horizontalFactor < -1.2 ||
        single.horizontalFactor > 1.2 ||
        single.verticalFactor < -1 ||
        single.verticalFactor > 1) {
      throw ArgumentError.value(single, 'singles', 'Tek konumu geçersiz.');
    }
    seats.add(
      CampfireSeat(
        x: single.horizontalFactor,
        y: single.verticalFactor,
        index: seats.length,
      ),
    );
  }
  return seats;
}
