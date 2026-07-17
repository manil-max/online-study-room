/// Duvar saati soyutlaması — testlerde sabitlenebilir.
///
/// Tüm sayaç/alarm/kronometre mantığı **epoch ms** (UTC anı) ile çalışır.
/// `Timer.periodic` yalnız UI yenileme için kullanılır; geçen süre her zaman
/// `nowMs - startedAtMs` farkından türetilir (Doze/skip-frame dayanıklı).
abstract class EpochClock {
  /// Unix epoch milisaniye (yerel duvar saati anı).
  int nowMs();

  /// Kolaylık: [nowMs] → DateTime.
  DateTime nowDateTime() => DateTime.fromMillisecondsSinceEpoch(nowMs());
}

/// Cihaz duvar saati.
class SystemEpochClock implements EpochClock {
  const SystemEpochClock();

  @override
  int nowMs() => DateTime.now().millisecondsSinceEpoch;

  @override
  DateTime nowDateTime() => DateTime.now();
}

/// Test / deterministik senaryolar için sabitlenebilir saat.
class FakeEpochClock implements EpochClock {
  FakeEpochClock([int? initialMs])
      : _ms = initialMs ?? DateTime(2026, 7, 13, 12).millisecondsSinceEpoch;

  int _ms;

  @override
  int nowMs() => _ms;

  @override
  DateTime nowDateTime() => DateTime.fromMillisecondsSinceEpoch(_ms);

  void setMs(int ms) => _ms = ms;

  void advance(Duration d) => _ms += d.inMilliseconds;

  void setDateTime(DateTime dt) => _ms = dt.millisecondsSinceEpoch;
}
