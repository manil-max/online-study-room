import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../core/stats/stats_period.dart';
import '../../../core/stats/study_stats.dart';
import 'personal_period_cards.dart';

/// WP-925 — grafikler SEÇİLİ DÖNEMİ çizer.
///
/// 🔴 ÖLÇÜLEN KUSUR (UX denetimi `s07`, `s08`, `s09`, `s10`; saat 23 Eylül
/// 2026 Çarşamba):
/// - "Bu hafta" başlığı **21–27 Eyl** (İstanbul takvim haftası, Pzt–Paz)
///   yazarken "Günlük dağılım" **17–23 Eyl**'ü çiziyordu: pencere bugünde biten
///   7 günlük kayan penceredir (`lastNDays`), dönem değil. Toplam kartı 21–23'ü
///   toplarken grafiğin 4 çubuğu önceki haftaya aitti.
/// - "Bu ay"da "Günlük dağılım" ve "Eğilim grafiği" 25/8–23/9 çiziyordu —
///   ağustosun son haftası "Ay" başlığı altında.
/// - "Yıl" ve "Tümü"de "Eğilim grafiği" yine SON 30 GÜNÜ çiziyordu
///   (`period.chartDays()` = 30); başlık yılı/tüm geçmişi iddia ediyordu.
///
/// Dönemin tanımı ekranın geri kalanıyla aynıdır: [StatsPeriodSelection.range]
/// (İstanbul takvim haftası/ayı/yılı, `istanbul_calendar.dart`). Burada yalnız
/// o aralığın **takvim sonu** ve eğilim kovaları üretilir.

/// Seçili dönemin TAKVİMDEKİ son günü (İstanbul gün anahtarı).
///
/// İçinde bulunulan dönemde [StatsPeriodSelection.range] üst ucu "şimdi"dir
/// (toplamlar bugüne kadar sayılır); çubuk grafik ise başlığın yazdığı
/// aralığın TAMAMINI çizer — gelecek günler boş çubuktur. Başlık "21–27 Eyl"
/// diyorsa eksen de 21–27'dir.
DateTime periodCalendarEnd(StatsPeriodSelection selection, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final (from, to) = selection.range(now: n);
  final start = dayOf(from);
  return switch (selection.period) {
    StatsPeriod.day => start,
    StatsPeriod.week => DateTime(start.year, start.month, start.day + 6),
    // Ayın 0. günü = önceki ayın son günü: bir sonraki ayın 0'ı bu ayın sonu.
    StatsPeriod.month => DateTime(start.year, start.month + 1, 0),
    StatsPeriod.year => DateTime(start.year, 12, 31),
    StatsPeriod.custom => dayOf(to),
    StatsPeriod.all => dayOf(n),
  };
}

/// [first]..[last] (iki uç dâhil) her takvim günü için bir kova; verisi
/// olmayan gün 0.
///
/// Gün adımı takvim aritmetiğiyle atılır (`DateTime(y, m, d + i)`), süre
/// ekleyerek değil: yaz saati uygulayan bir cihazda `add(Duration(days: 1))`
/// gün anahtarını 23:00'a kaydırır ve harita araması boş döner.
List<DayTotal> calendarDayTotals(
  DateTime first,
  DateTime last,
  Map<DateTime, int> totals,
) {
  final a = dayOf(first);
  final count = statsDayNumber(last) - statsDayNumber(a) + 1;
  if (count <= 0) return const [];
  return [
    for (var i = 0; i < count; i++)
      () {
        final day = DateTime(a.year, a.month, a.day + i);
        return DayTotal(day, totals[day] ?? 0);
      }(),
  ];
}

/// Eğilim grafiğinin kova boyu.
enum TrendBucket { day, week, month }

/// Bir eğilim noktası: kovanın ilk günü + kovanın toplam saniyesi.
class TrendPoint {
  const TrendPoint(this.start, this.seconds);

  final DateTime start;
  final int seconds;
}

/// "Eğilim grafiği" serisi — dönemin kendisi, dönemin uzunluğuna uygun kovayla.
///
/// - Ay (ve ≤31 günlük Özel): **günlük**, dönemin ilk gününden bugüne.
/// - Yıl (ve >31 günlük Özel): **haftalık** (Pzt başlangıçlı İstanbul
///   haftası). Aylık kovayı "Aylık dağılım" zaten çiziyor; aynı veriyi ikinci
///   kez çizmek yerine eğilim bir kademe ince çözünürlüktedir.
/// - Tümü: ilk kayıtlı aydan bugüne **aylık**; geçmiş 3 aydan kısaysa
///   haftalık (tek noktalı çizgi eğilim anlatmaz).
///
/// Seri bugünde biter: gelecek günler çizgide sıfıra düşüş gibi okunurdu.
/// Dönem sınırının dışındaki günler kovaya girmez (yılın ilk haftası
/// 29 Aralık'ta başlasa da yalnız 1 Ocak'tan itibaren sayılır).
({TrendBucket bucket, List<TrendPoint> points}) periodTrend({
  required PersonalCardSet cardSet,
  required DateTime periodFrom,
  required DateTime periodEnd,
  required DateTime today,
  required Map<DateTime, int> totals,
}) {
  var from = dayOf(periodFrom);
  final end = dayOf(periodEnd);
  final t = dayOf(today);
  final last = end.isAfter(t) ? t : end;

  TrendBucket bucket;
  switch (cardSet) {
    case PersonalCardSet.day:
    case PersonalCardSet.week:
    case PersonalCardSet.month:
      bucket = TrendBucket.day;
    case PersonalCardSet.year:
      bucket = TrendBucket.week;
    case PersonalCardSet.all:
      DateTime? earliest;
      for (final e in totals.entries) {
        if (e.value <= 0) continue;
        if (e.key.isBefore(from) || e.key.isAfter(last)) continue;
        if (earliest == null || e.key.isBefore(earliest)) earliest = e.key;
      }
      from = earliest ?? last;
      final months =
          (last.year * 12 + last.month) - (from.year * 12 + from.month) + 1;
      bucket = months >= 3 ? TrendBucket.month : TrendBucket.week;
  }
  if (last.isBefore(from)) return (bucket: bucket, points: const []);

  final DateTime firstStart;
  final int count;
  switch (bucket) {
    case TrendBucket.day:
      firstStart = from;
      count = statsDayNumber(last) - statsDayNumber(from) + 1;
    case TrendBucket.week:
      // `startOfWeek` süre çıkarır (DST'de 23:00'a kayar); gün anahtarı
      // takvim aritmetiğiyle kurulur.
      firstStart = DateTime(
        from.year,
        from.month,
        from.day - (from.weekday - 1),
      );
      count = (statsDayNumber(last) - statsDayNumber(firstStart)) ~/ 7 + 1;
    case TrendBucket.month:
      firstStart = DateTime(from.year, from.month, 1);
      count = (last.year * 12 + last.month) - (from.year * 12 + from.month) + 1;
  }

  final sums = List<int>.filled(count, 0);
  final firstDayNumber = statsDayNumber(firstStart);
  for (final e in totals.entries) {
    if (e.value <= 0) continue;
    final day = dayOf(e.key);
    if (day.isBefore(from) || day.isAfter(last)) continue;
    final index = switch (bucket) {
      TrendBucket.day => statsDayNumber(day) - firstDayNumber,
      TrendBucket.week => (statsDayNumber(day) - firstDayNumber) ~/ 7,
      TrendBucket.month =>
        (day.year * 12 + day.month) - (firstStart.year * 12 + firstStart.month),
    };
    if (index < 0 || index >= count) continue;
    sums[index] += e.value;
  }

  return (
    bucket: bucket,
    points: [
      for (var i = 0; i < count; i++)
        TrendPoint(switch (bucket) {
          TrendBucket.day => DateTime(
            firstStart.year,
            firstStart.month,
            firstStart.day + i,
          ),
          TrendBucket.week => DateTime(
            firstStart.year,
            firstStart.month,
            firstStart.day + 7 * i,
          ),
          TrendBucket.month => DateTime(
            firstStart.year,
            firstStart.month + i,
            1,
          ),
        }, sums[i]),
    ],
  );
}

/// Eğilim X ekseni etiketi: gün/hafta kovasında "gün/ay", ay kovasında
/// "Ay YYYY" (ör. "Eyl 2026") — "9/26" hem 9 Eylül'e hem Eylül 2026'ya
/// okunabilirdi.
String trendPointLabel(
  AppLocalizations l10n,
  TrendBucket bucket,
  DateTime start,
) {
  if (bucket != TrendBucket.month) return '${start.day}/${start.month}';
  final names = [
    l10n.statsOca,
    l10n.statsSub,
    l10n.statsMar,
    l10n.statsNis,
    l10n.statsMay,
    l10n.statsHaz,
    l10n.statsTem,
    l10n.statsAgu,
    l10n.statsEyl,
    l10n.statsEki,
    l10n.statsKas,
    l10n.statsAra,
  ];
  return '${names[start.month - 1]} ${start.year}';
}
