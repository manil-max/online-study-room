/// WP-627: `ColorScheme`'in "container" rolleri **paletten türetilir**.
///
/// Sorun: `app_theme.dart` `ColorScheme`'i elle kuruyor ve
/// `primaryContainer` / `secondaryContainer` / `tertiaryContainer` /
/// `errorContainer` (ve `on*` eşleri) hiç geçilmiyordu. Flutter'ın fallback'i
/// bunları **tam doygunluktaki ana renge** düşürür
/// (`primaryContainer == primary`, `secondaryContainer == secondary`,
/// `errorContainer == error`). "Container" rolü tanım gereği bir **zemin**dir;
/// oraya tam doygun bir renk konunca üstündeki yazı/ikon okunmaz olur ve
/// zeminin üstüne çizilen vurgu (seçim çubuğu gibi) zemine gömülür.
///
/// Ölçüldü (düzeltme öncesi, 15 hazır tema): seçim çubuğu (`primary`) seçili
/// döşeme zemininde (`secondaryContainer`) **13 temada** 3.0 altında, ikisinde
/// **1.01** — yani tamamen görünmez. `onErrorContainer/errorContainer` 15
/// temanın **15'inde** 4.03.
///
/// Çözüm, `warning_tokens.dart` (WP-358) ve `focus_ring_tokens.dart` (WP-594)
/// ile aynı ilkedir — renk sabit yazılmaz, **zeminin fonksiyonu** olarak
/// türetilir. Buradaki iki kural:
///
///  1. **Zemin**: rol renginin *tonu* alınır, doygunluğu düşürülür ve açıklığı
///     yüzeyden sabit bir adım uzağa taşınır. Sonuç "düşük doygunluklu, yüzeyden
///     ayrışan bir zemin"dir — tam doygun marka rengi değil.
///  2. **Üstü**: `on*Container`, o zemine karşı [kMinTextContrast] tutturulana
///     kadar rol renginin açıklığı itilerek bulunur. Ton korunur, yani tema
///     kimliği (Kamp Ateşi turuncu, Nordik Kar mavi) bozulmaz.
///
/// 🔴 Her tema için elle renk yazma. 15 tema × 4 rol × 2 = 120 sabit demektir;
/// 16'ncı tema eklendiğinde sessizce eksik kalır. Kural tek yerde durmalı,
/// kapı da (`theme_contrast_gate_wp627_test.dart`) tüm temaları tarasın.
library;

import 'package:flutter/material.dart';

import 'warning_tokens.dart'
    show contrastRatio, kMinSurfaceContrast, kMinTextContrast;

/// Türetilmiş bir "container" rolü: zemin + üstünde okunur ön plan.
@immutable
class ContainerRole {
  const ContainerRole({required this.container, required this.onContainer});

  /// Düşük doygunluklu zemin — yüzeyden ayrışır, ana renk kadar bağırmaz.
  final Color container;

  /// [container] üstündeki metin/ikon — zemine karşı ≥ [kMinTextContrast].
  final Color onContainer;
}

/// Zeminin rol renginden devraldığı doygunluk oranı. 1.0 olsaydı zemin ana
/// rengin ta kendisi olurdu (bulgunun kendisi); 0 olsaydı tema kimliği
/// tamamen kaybolur, bütün temalarda aynı gri zemin çıkardı.
const double _containerSaturation = 0.45;

/// Zeminin doygunluk tabanı/tavanı. Taban, akromatik paletlerde (Paper & Ink)
/// zeminin yüzeyden yalnız açıklıkla ayrılmasını sağlar; tavan neon
/// paletlerde zeminin bağırmasını engeller.
const double _minSaturation = 0.06;
const double _maxSaturation = 0.45;

/// Zeminin yüzeyden uzaklaştığı açıklık adımı. Koyu temada yukarı, açık temada
/// aşağı: her iki yönde de "yüzeyden ayrı bir kat" hissi verir.
const double _darkLift = 0.10;
const double _lightDrop = 0.08;

/// Container zemininin uygulama yüzeylerinden ayrışması için en düşük oran.
///
/// WCAG eşiği değildir — "seçili" durumun görülebilmesi için gereken en küçük
/// farktır ve WCAG'ın metin/bileşen eşiklerinin **altındadır**; seçim tek
/// başına renge de dayanmaz (sol panelde ayrıca bir vurgu çubuğu vardır).
///
/// 🔴 Sabit açıklık adımı yetmez. Beyaza yakın paletlerde 0.08'lik bir açıklık
/// farkı orana çevrildiğinde 1.11'e düşüyor — `pastel_day`'de seçili döşeme
/// zeminden ayırt edilemiyordu. Ayrışma **oran** olarak garanti edilir.
const double kMinContainerSeparation = 1.25;

/// Üçüncül rolün ikinciden ayrıldığı ton farkı (derece).
///
/// Eski kurulumda `tertiary` doğrudan `accent` idi; `SeriesPalette` 8 "farklı"
/// seri rengi vaat ederken gerçekte **4** üretiyordu. Ton kaydırma paleti
/// değiştirmez, yalnız Material'ın zaten ayrı olmasını beklediği rolü ayırır.
const double kTertiaryHueShift = 48;

/// [role] renginden, [surfaces] listesindeki **tüm** uygulama yüzeylerinden
/// ayrışan bir container rolü türetir.
///
/// [surfaces] tek bir yüzey değil hepsidir: bir container zemini scaffold'un
/// (sol panel seçili döşemesi), kartın (hayvan seçici) ya da yükseltilmiş
/// yüzeyin üstünde durabilir. Hepsinden ayrışmazsa "seçili" durumu bir yerde
/// görünmez olur.
///
/// Saf ve deterministiktir: aynı giriş her zaman aynı çıkışı verir.
ContainerRole resolveContainerRole({
  required Color role,
  required List<Color> surfaces,
  required Brightness brightness,
}) {
  assert(surfaces.isNotEmpty);
  final roleHsl = HSLColor.fromColor(role);
  final towardsLight = brightness == Brightness.dark;

  // Hareket yönündeki en uçtaki yüzeyden başla: koyu temada en açık yüzeyin
  // üstüne, açık temada en koyu yüzeyin altına.
  final lightnesses = surfaces.map((c) => HSLColor.fromColor(c).lightness);
  final anchor = towardsLight
      ? lightnesses.reduce((a, b) => a > b ? a : b)
      : lightnesses.reduce((a, b) => a < b ? a : b);

  final saturation = (roleHsl.saturation * _containerSaturation).clamp(
    _minSaturation,
    _maxSaturation,
  );

  Color build(double lightness) => HSLColor.fromAHSL(
    1,
    roleHsl.hue,
    saturation,
    lightness.clamp(0.0, 1.0),
  ).toColor();

  double separation(Color candidate) => surfaces
      .map((s) => contrastRatio(candidate, s))
      .reduce((a, b) => a < b ? a : b);

  var lightness = towardsLight ? anchor + _darkLift : anchor - _lightDrop;
  var container = build(lightness);

  // Sabit açıklık adımı beyaza/siyaha yakın paletlerde orana çevrildiğinde
  // erir; ayrışmayı **ölçerek** garanti altına al.
  for (var step = 0; step < 100 && separation(container) < kMinContainerSeparation; step++) {
    lightness = towardsLight ? lightness + 0.01 : lightness - 0.01;
    if (lightness <= 0.0 || lightness >= 1.0) {
      container = build(lightness);
      break;
    }
    container = build(lightness);
  }

  return ContainerRole(
    container: container,
    onContainer: ensureContrast(background: container, preferred: role),
  );
}

/// [preferred] rengin **tonunu koruyarak** [background] üstünde en az
/// [minRatio] kontrast sağlayan en yakın rengi döndürür.
///
/// Yön zeminin kendisinden gelir (siyah/beyazdan hangisi zemine karşı daha
/// yüksekse o tarafa itilir), paletten değil. Ton korunarak yetişilemeyen tek
/// durum orta parlaklıktaki zeminlerdir; orada akromatik uca düşülür —
/// `focus_ring_tokens.dart` ile aynı ilke.
///
/// 🔴 Eşiği düşürerek "geçirmek" yasak: bir çift tutmuyorsa **renk** düzeltilir.
Color ensureContrast({
  required Color background,
  required Color preferred,
  double minRatio = kMinTextContrast,
}) {
  final cacheKey = Object.hash(background.toARGB32(), preferred.toARGB32(), minRatio);
  final cached = _cache[cacheKey];
  if (cached != null) return cached;
  final resolved = _resolveContrast(background, preferred, minRatio);
  if (_cache.length >= _cacheLimit) _cache.clear();
  _cache[cacheKey] = resolved;
  return resolved;
}

/// Widget tarafı kısayolu: zeminin üstüne çizilen **vurgu** (seçim çubuğu,
/// onay ikonu gibi metin olmayan bileşen) için [kMinSurfaceContrast] eşiği.
///
/// 🔴 Zemin olarak paneli değil, vurgunun **fiilen üstünde durduğu** döşemeyi
/// geç: seçili döşeme `secondaryContainer`dır, panel zemini değil.
Color accentOn(Color background, {required Color preferred}) => ensureContrast(
  background: background,
  preferred: preferred,
  minRatio: kMinSurfaceContrast,
);

const int _cacheLimit = 512;
final Map<int, Color> _cache = <int, Color>{};

Color _resolveContrast(Color background, Color preferred, double minRatio) {
  var bestRatio = contrastRatio(preferred, background);
  if (bestRatio >= minRatio) return preferred;

  // Hangi uca gitmek daha çok yer açıyor? Karar zeminin luminance'ından çıkar.
  final towardsLight =
      contrastRatio(const Color(0xFFFFFFFF), background) >=
      contrastRatio(const Color(0xFF000000), background);

  final hsl = HSLColor.fromColor(preferred);
  var best = preferred;
  for (var step = 1; step <= 100; step++) {
    final lightness =
        (towardsLight
                ? hsl.lightness + step * 0.01
                : hsl.lightness - step * 0.01)
            .clamp(0.0, 1.0);
    final candidate = hsl.withLightness(lightness).toColor();
    final ratio = contrastRatio(candidate, background);
    if (ratio > bestRatio) {
      best = candidate;
      bestRatio = ratio;
    }
    if (ratio >= minRatio) return candidate;
    if (lightness == 0.0 || lightness == 1.0) break;
  }

  final fallback = towardsLight
      ? const Color(0xFFFFFFFF)
      : const Color(0xFF000000);
  return contrastRatio(fallback, background) > bestRatio ? fallback : best;
}
