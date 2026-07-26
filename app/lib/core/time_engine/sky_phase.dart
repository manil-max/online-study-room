import 'dart:math' as math;

/// Kamp gökyüzünün sivil fazı.
enum SkyPhase { night, dawn, day, dusk }

/// Bir yerel gün içindeki dört sivil gökyüzü çıpası.
///
/// Değerler gece yarısından itibaren dakikadır. WP-299 sabit çıpaları kullanır;
/// WP-300 aynı nesneyi grubun konumundan hesaplanan güneş saatleriyle
/// değiştirebilir.
class SkyAnchors {
  const SkyAnchors({
    required this.dawnMinute,
    required this.sunriseMinute,
    required this.sunsetMinute,
    required this.duskMinute,
  });

  final int dawnMinute;
  final int sunriseMinute;
  final int sunsetMinute;
  final int duskMinute;

  bool get isValid =>
      dawnMinute >= 0 &&
      dawnMinute < sunriseMinute &&
      sunriseMinute < sunsetMinute &&
      sunsetMinute < duskMinute &&
      duskMinute < minutesPerDay;

  static const int minutesPerDay = 24 * 60;
}

/// WP-299'un geçici sivil çıpaları.
///
/// Tek sabit burada tutulur; sahne ve uyku pozu ayrı saat tanımlamaz.
const kDefaultSkyAnchors = SkyAnchors(
  dawnMinute: 5 * 60 + 30,
  sunriseMinute: 6 * 60 + 30,
  sunsetMinute: 18 * 60 + 30,
  duskMinute: 19 * 60 + 30,
);

/// Saf gökyüzü hesabının çıktısı.
class SkyPhaseResult {
  const SkyPhaseResult({
    required this.phase,
    required this.value,
    required this.phaseProgress,
    required this.sunProgress,
    required this.warmth,
  });

  /// Sivil faz.
  final SkyPhase phase;

  /// Gün ışığı yoğunluğu: tam gece 0, tam gündüz 1.
  final double value;

  /// İçinde bulunulan fazın 0..1 ilerlemesi.
  final double phaseProgress;

  /// Güneşin gündoğumu → günbatımı yayındaki 0..1 konumu.
  final double sunProgress;

  /// Şafak/akşam renk sıcaklığı: nötr 0, geçiş ortası 1.
  final double warmth;

  bool get isNight => phase == SkyPhase.night;
  double get nightOpacity => 1 - value;
}

/// Verilen yerel sivil saat için kamp gökyüzünü hesaplar.
///
/// Fonksiyon saat okumaz ve saat dilimi dönüştürmez. Çağıran taraf aynı
/// [DateTime] anını hem gökyüzüne hem gece uyuma pozuna vermelidir.
SkyPhaseResult skyPhase(DateTime local, SkyAnchors anchors) {
  if (!anchors.isValid) {
    throw ArgumentError.value(
      anchors,
      'anchors',
      'dawn < sunrise < sunset < dusk ve tümü aynı sivil gün içinde olmalı',
    );
  }

  final minute =
      local.hour * 60 +
      local.minute +
      (local.second + local.millisecond / 1000) / 60;

  if (minute < anchors.dawnMinute || minute >= anchors.duskMinute) {
    final progress = minute < anchors.dawnMinute
        ? minute / anchors.dawnMinute
        : (minute - anchors.duskMinute) /
              (SkyAnchors.minutesPerDay - anchors.duskMinute);
    return SkyPhaseResult(
      phase: SkyPhase.night,
      value: 0,
      phaseProgress: progress.clamp(0, 1).toDouble(),
      sunProgress: minute < anchors.dawnMinute ? 0 : 1,
      warmth: 0,
    );
  }

  if (minute < anchors.sunriseMinute) {
    final progress = _segmentProgress(
      minute,
      anchors.dawnMinute,
      anchors.sunriseMinute,
    );
    return SkyPhaseResult(
      phase: SkyPhase.dawn,
      value: _smoothStep(progress),
      phaseProgress: progress,
      sunProgress: 0,
      warmth: math.sin(math.pi * progress),
    );
  }

  if (minute < anchors.sunsetMinute) {
    final progress = _segmentProgress(
      minute,
      anchors.sunriseMinute,
      anchors.sunsetMinute,
    );
    return SkyPhaseResult(
      phase: SkyPhase.day,
      value: 1,
      phaseProgress: progress,
      sunProgress: progress,
      warmth: 0,
    );
  }

  final progress = _segmentProgress(
    minute,
    anchors.sunsetMinute,
    anchors.duskMinute,
  );
  return SkyPhaseResult(
    phase: SkyPhase.dusk,
    value: 1 - _smoothStep(progress),
    phaseProgress: progress,
    sunProgress: 1,
    warmth: math.sin(math.pi * progress),
  );
}

double _segmentProgress(double value, int start, int end) =>
    ((value - start) / (end - start)).clamp(0, 1).toDouble();

double _smoothStep(double value) => value * value * (3 - 2 * value);
