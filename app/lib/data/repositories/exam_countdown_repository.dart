import '../models/exam_countdown.dart';

/// WP-694 - sinav geri sayiminin sunucu ucu.
///
/// Yerel kopya (`SharedPreferences`) **ekranin** kaynagi olmaya devam eder;
/// bu depo **dogrulugun** kaynagidir. Internet yoksa cagrilarin hepsi hata
/// atar ve cagiran yerel kopyayi cizmeye devam eder.
abstract class ExamCountdownRepository {
  /// Hesabin sunucudaki tum geri sayimlari (`sort_order` sirasiyla).
  Future<List<ExamCountdown>> load({required String userKey});

  /// Tek kaydi yazar. Sunucu, damgasi eskiyse yazmayi **yok sayar** (LWW).
  Future<void> upsert({
    required String userKey,
    required ExamCountdown entry,
  });

  Future<void> delete({required String userKey, required String id});
}
