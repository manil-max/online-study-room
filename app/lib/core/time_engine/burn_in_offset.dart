import 'dart:math' as math;

/// AMOLED burn-in koruması: her dakikada yavaşça kayan ofset.
///
/// Apple/Samsung masa saati tarzı — metin her [period] içinde en az
/// [minPixels] kadar yer değiştirir (kabul: 1 saat içinde ≥10 px).
class BurnInOffset {
  BurnInOffset({
    this.period = const Duration(minutes: 1),
    this.amplitude = 12,
    math.Random? random,
  }) : _random = random ?? math.Random();

  final Duration period;
  final double amplitude;
  final math.Random _random;

  double _dx = 0;
  double _dy = 0;
  int _lastPeriodIndex = -1;

  double get dx => _dx;
  double get dy => _dy;

  /// [now] ile ofseti güncelle; periyot değiştiyse yeni rastgele kayma.
  void tick(DateTime now) {
    final index = now.millisecondsSinceEpoch ~/ period.inMilliseconds;
    if (index == _lastPeriodIndex) return;
    _lastPeriodIndex = index;
    // En az ~1 px kayma garantisi (sıfır vektör engeli).
    double nx;
    double ny;
    do {
      nx = (_random.nextDouble() * 2 - 1) * amplitude;
      ny = (_random.nextDouble() * 2 - 1) * amplitude;
    } while (nx.abs() < 1 && ny.abs() < 1);
    _dx = nx;
    _dy = ny;
  }

  /// Test yardımcısı: N periyot boyunca max yer değiştirme.
  static double maxDisplacementOver({
    required int periods,
    required double amplitude,
    int seed = 1,
  }) {
    final b = BurnInOffset(
      amplitude: amplitude,
      random: math.Random(seed),
    );
    var maxD = 0.0;
    final start = DateTime(2026, 1, 1);
    for (var i = 0; i < periods; i++) {
      b.tick(start.add(Duration(minutes: i)));
      final d = math.sqrt(b.dx * b.dx + b.dy * b.dy);
      if (d > maxD) maxD = d;
    }
    return maxD;
  }
}
