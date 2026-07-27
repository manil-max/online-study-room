/// WP-377: mevsime göre kayan sivil gökyüzü çıpaları.
///
/// 🔴 **Neden gerekti:** `kDefaultSkyAnchors` yıl boyu sabitti
/// (05:30 · 06:30 · 18:30 · 19:30). Gerçek güneşe göre sapma İstanbul'da
/// **±2,5 saate** kadar çıkıyordu: 21 Haziran'da sahne 19:30'da geceye geçerken
/// dışarıda güneş 20:40'ta batıyor, 21 Aralık'ta ise güneş 17:39'da battığı
/// hâlde sahne 18:30'a kadar gündüz kalıyordu. Bu model aynı günlerde **±13
/// dakika** içinde kalır.
///
/// 🔴 **Neden konum yok:** enlem/boylam yaklaşımı (eski WP-300) sahip kararıyla
/// **iptal edilmişti** — konum izni istemek istenmiyor. Bu yüzden enlem ve
/// güneş öğleni birer **sabittir**; grup başına gerçek koordinat gerekirse o
/// ayrı bir ürün kararıdır (izin yüzeyi açar).
library;

import 'dart:math' as math;

import 'sky_phase.dart';

/// Türkiye ortalaması. Modelin tek serbest parametresi budur.
const double kCampLatitude = 39.0;

/// Yerel saat olarak güneş öğleni (Türkiye ortalaması, 13:05).
///
/// Boylam bilinmediği için öğle "hesaplanmaz", ölçülmüş bir sabittir. Boylamı
/// saat diliminden türetmek İstanbul'da ~1 saat hata verir (UTC+3'ün merkezi
/// 45°D, İstanbul 29°D) — bu yüzden bilinçle yapılmadı.
const int kCampSolarNoonMinute = 13 * 60 + 5;

/// Gündoğumu/günbatımı için görünür disk + kırılma düzeltmeli zenit.
const double _sunriseZenith = 90.833;

/// Sivil alacakaranlık zeniti (güneş ufkun 6° altında).
const double _civilTwilightZenith = 96.0;

/// İki çıpa arasında korunan en küçük aralık (dakika).
///
/// Kutup bölgelerinde gün doğmayabilir ya da batmayabilir; [SkyAnchors.isValid]
/// kesin artan sıra istediği için sonuç her hâlükârda sıralı tutulur.
const double _minAnchorGap = 10;

/// [local] gününün sivil çıpalarını hesaplar.
///
/// Saf fonksiyon: saat okumaz, saat dilimi dönüştürmez. Çağıran hangi anı
/// gökyüzüne veriyorsa aynı anı buraya da verir.
SkyAnchors solarSkyAnchors(
  DateTime local, {
  double latitude = kCampLatitude,
  int solarNoonMinute = kCampSolarNoonMinute,
}) {
  final dayOfYear = local.difference(DateTime(local.year)).inDays + 1;
  // Cooper yaklaşımı: yıl içindeki güneş deklinasyonu.
  final declination =
      _degToRad(23.45) * math.sin(2 * math.pi * (284 + dayOfYear) / 365);
  final lat = _degToRad(latitude);

  double halfArcMinutes(double zenithDegrees) {
    final cosHourAngle =
        (math.cos(_degToRad(zenithDegrees)) -
            math.sin(declination) * math.sin(lat)) /
        (math.cos(declination) * math.cos(lat));
    // |cos| > 1 → o gün güneş hiç doğmuyor ya da hiç batmıyor.
    final clamped = cosHourAngle.clamp(-1.0, 1.0).toDouble();
    return math.acos(clamped) * 180 / math.pi / 15 * 60;
  }

  final noon = solarNoonMinute.toDouble();
  final sunHalf = halfArcMinutes(_sunriseZenith);
  final twilightHalf = halfArcMinutes(_civilTwilightZenith);

  return _ordered(
    dawn: noon - twilightHalf,
    sunrise: noon - sunHalf,
    sunset: noon + sunHalf,
    dusk: noon + twilightHalf,
  );
}

/// Ham dakikaları `dawn < sunrise < sunset < dusk` ve gün içinde kalacak
/// biçimde sıralar. [SkyAnchors.isValid] bunu şart koşar; kutup vakalarında
/// ham değerler bu sözleşmeyi bozabilir.
SkyAnchors _ordered({
  required double dawn,
  required double sunrise,
  required double sunset,
  required double dusk,
}) {
  const last = SkyAnchors.minutesPerDay - 1.0;
  var d = dawn.clamp(1.0, last - 3 * _minAnchorGap);
  var sr = math.max(sunrise, d + _minAnchorGap);
  var ss = math.max(sunset, sr + _minAnchorGap);
  var dk = math.max(dusk, ss + _minAnchorGap);

  if (dk > last) {
    dk = last;
    ss = math.min(ss, dk - _minAnchorGap);
    sr = math.min(sr, ss - _minAnchorGap);
    d = math.min(d, sr - _minAnchorGap);
  }

  return SkyAnchors(
    dawnMinute: d.round(),
    sunriseMinute: sr.round(),
    sunsetMinute: ss.round(),
    duskMinute: dk.round(),
  );
}

double _degToRad(double degrees) => degrees * math.pi / 180;
