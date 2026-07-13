/// Tur (lap) analizi — en hızlı / en yavaş / farklar.
///
/// [lapTotalsMs]: her tur kaydında kronometrenin o anki **toplam** elapsed ms'i.
class LapAnalysis {
  const LapAnalysis({
    required this.splitsMs,
    required this.fastestIndex,
    required this.slowestIndex,
  });

  /// Her turun kendi süresi (ms): split[i] = total[i] - total[i-1].
  final List<int> splitsMs;

  /// En hızlı turun indeksi (küçük split); tek turda 0; boşsa -1.
  final int fastestIndex;

  /// En yavaş turun indeksi; tek turda -1 (highlight yok); boşsa -1.
  final int slowestIndex;

  bool get isEmpty => splitsMs.isEmpty;

  /// Önceki tura göre fark (ms); ilk turda null.
  int? deltaVsPrevious(int index) {
    if (index <= 0 || index >= splitsMs.length) return null;
    return splitsMs[index] - splitsMs[index - 1];
  }

  static LapAnalysis fromTotals(List<int> lapTotalsMs) {
    if (lapTotalsMs.isEmpty) {
      return const LapAnalysis(
        splitsMs: [],
        fastestIndex: -1,
        slowestIndex: -1,
      );
    }

    final splits = <int>[];
    for (var i = 0; i < lapTotalsMs.length; i++) {
      final prev = i == 0 ? 0 : lapTotalsMs[i - 1];
      splits.add((lapTotalsMs[i] - prev).clamp(0, 1 << 62));
    }

    if (splits.length == 1) {
      return LapAnalysis(
        splitsMs: splits,
        fastestIndex: 0,
        slowestIndex: -1, // tek turda yavaş vurgusu yok
      );
    }

    var fast = 0;
    var slow = 0;
    for (var i = 1; i < splits.length; i++) {
      if (splits[i] < splits[fast]) fast = i;
      if (splits[i] > splits[slow]) slow = i;
    }
    // Hepsi eşitse slow/fast aynı olabilir — yine de işaretle.
    return LapAnalysis(
      splitsMs: splits,
      fastestIndex: fast,
      slowestIndex: slow == fast ? -1 : slow,
    );
  }
}

/// Kronometre / timer süre metni: `mm:ss.cc` veya `h:mm:ss`.
String formatStopwatch(Duration d, {bool centiseconds = true}) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  final cs = (d.inMilliseconds.remainder(1000) ~/ 10);
  if (h > 0) {
    final base =
        '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return centiseconds ? '$base.${cs.toString().padLeft(2, '0')}' : base;
  }
  final base = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  return centiseconds ? '$base.${cs.toString().padLeft(2, '0')}' : base;
}

String formatCountdown(Duration d) {
  final total = d.inSeconds.clamp(0, 1 << 30);
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}
