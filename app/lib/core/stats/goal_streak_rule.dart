/// WP-739 — **tek** günlük seri kuralı.
///
/// 🔴 Sahip kararı (2026-08-19): *"blazing fire başarımı full devamlı günlere
/// bakıyor ama ben onu bizim pause hakkı olan günlük seriye eşitlemek
/// istiyorum… 7 gün üst üste ulaş değil de 7 gün alevine sahip ol."*
///
/// Bu dosyadan önce depoda üç ayrı "seri" tanımı vardı ve üçü aynı geçmişte
/// üç farklı sayı veriyordu:
///
///   1. `goal_streak_projection` (0112 + `projectGoalStreak`) — alev rozetinin
///      kaynağı; **tek kaçırmayı affeder**, iki ardışık kaçırma sıfırlar;
///   2. `_current_fire_streak_days` (0135) ve yerel `computeMetrics` —
///      Alevli Seri başarımının kaynağı; ilk eksik günde durur;
///   3. `currentStreak` / `longestStudyStreak` (`study_stats.dart`) — profil
///      "Güncel seri" ve "Rekor seri" döşemeleri; onlar da ilk eksik günde
///      durur.
///
/// Ayrışma `038_progression_matrix.test.sql §6` ve
/// `progression_matrix_wp455_test.dart` içinde **açık bulgu** olarak
/// sabitlenmişti; kapatılması XP eşiklerini değiştirdiği için sahip kararına
/// bırakılmıştı. Karar geldi: kural tektir ve burada durur.
///
/// **KURAL** (SQL `goal_streak_projection` ile birebir):
///   * Bir gün seriye ancak **günlük hedefi tutturursa** girer.
///   * İki tamamlanan gün arası fark **≤ 2** ise seri sürer (yani arada tek
///     boş gün affedilir); fark **> 2** ise yeni seri başlar.
///   * Seri uzunluğu = o koşudaki **tamamlanan gün sayısı**. Affedilen boş gün
///     sayıya EKLENMEZ: `tamamla-boş-tamamla-boş-tamamla = 3`.
///   * Güncel seri, son tamamlanan gün ile bugün arası fark ≤ 2 ise yaşar;
///     değilse 0'dır (bugün henüz sürdüğü için dün de "geç kalınmış" sayılmaz).
///
/// ⚠️ Buradaki affetme **otomatik**tir ve `streak_freezes` bakiyesiyle
/// KARIŞTIRILMAZ (o ayrı bir kavram, `currentStreakWithFreezes`).
library;

/// İki tamamlanan gün arasındaki en büyük tolere edilen fark.
/// `2` = "arada tek boş gün olabilir".
const int kGoalStreakMaxGapDays = 2;

/// Gün anahtarını takvim sıra numarasına indirger.
///
/// 🔴 WP-636 dersi: `difference(...).inDays` iki anahtar arasındaki SÜREdir;
/// DST uygulayan bir cihazda 23/25 saat çıkar ve ardışıklık iki yönlü yanlış
/// ölçülür. Karşılaştırma bu takvim indeksi üzerinden yapılır.
int goalStreakDayIndex(DateTime day) =>
    DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

/// Tamamlanan günleri koşulara böler ve her koşunun **gün sayısını** döner.
/// Sonuç, günlerin kendi sırasındadır (eskiden yeniye).
List<int> goalStreakRunLengths(Iterable<DateTime> completedDays) {
  final indexes = <int>{for (final day in completedDays) goalStreakDayIndex(day)}
      .toList(growable: false)
    ..sort();
  if (indexes.isEmpty) return const <int>[];

  final runs = <int>[];
  var current = 1;
  for (var i = 1; i < indexes.length; i++) {
    if (indexes[i] - indexes[i - 1] <= kGoalStreakMaxGapDays) {
      current++;
    } else {
      runs.add(current);
      current = 1;
    }
  }
  runs.add(current);
  return List.unmodifiable(runs);
}

/// Güncel seri: son koşunun uzunluğu — son tamamlanan gün bugüne ≤ 2 gün
/// uzaklıktaysa. Aksi halde 0.
int currentGoalStreakDays({
  required Iterable<DateTime> completedDays,
  required DateTime asOfDay,
}) {
  final asOf = goalStreakDayIndex(asOfDay);
  final indexes = <int>{
    for (final day in completedDays)
      if (goalStreakDayIndex(day) <= asOf) goalStreakDayIndex(day),
  }.toList(growable: false)..sort();
  if (indexes.isEmpty) return 0;

  if (asOf - indexes.last > kGoalStreakMaxGapDays) return 0;
  final runs = goalStreakRunLengths(
    indexes.map(_dayFromIndex).toList(growable: false),
  );
  return runs.last;
}

/// Rekor seri: tüm geçmişteki en uzun koşu.
int longestGoalStreakDays(Iterable<DateTime> completedDays) {
  final runs = goalStreakRunLengths(completedDays);
  if (runs.isEmpty) return 0;
  return runs.reduce((a, b) => a > b ? a : b);
}

/// `gün → saniye` haritasından hedefi tutturan günleri süzer.
/// [goalSeconds] ≤ 0 ise hedef tanımsızdır ve hiçbir gün seriye girmez.
List<DateTime> goalMetDays({
  required Map<DateTime, int> totals,
  required int goalSeconds,
}) {
  if (goalSeconds <= 0) return const <DateTime>[];
  // Aynı takvim gününü gösteren iki anahtar (UTC damgası + yerel anahtar) bir
  // BOŞLUK değildir; süreleri o günün toplamında BİRLEŞİR.
  final byDay = <int, int>{};
  for (final entry in totals.entries) {
    final index = goalStreakDayIndex(entry.key);
    byDay[index] = (byDay[index] ?? 0) + entry.value;
  }
  return <DateTime>[
    for (final entry in byDay.entries)
      if (entry.value > 0 && entry.value >= goalSeconds)
        _dayFromIndex(entry.key),
  ];
}

DateTime _dayFromIndex(int index) => DateTime.utc(
  1970,
  1,
  1,
).add(Duration(days: index));
