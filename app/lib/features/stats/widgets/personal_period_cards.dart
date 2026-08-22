import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/istanbul_calendar.dart';
import '../../../core/stats/stats_period.dart';
import '../../../core/stats/study_stats.dart';
import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/models/study_session.dart';
import '../../../data/models/subject.dart';
import '../../../data/providers/study_providers.dart';
import '../../../data/providers/subject_providers.dart';

/// WP-745 — Kişisel sekmesinin **dönem başına** kart kümesi ve o kümeye özgü
/// yeni kartlar.
///
/// 🔴 ÖLÇÜLEN KUSUR (WP-745 öncesi `personal_stats_view.dart:194-421`): altı
/// dönem düğmesi de aşağıya **aynı 25 kartı** seriyordu, yalnız sayılar
/// değişiyordu. Kartların bir kısmı seçili dönemde matematiksel olarak
/// anlamsızdı:
///
/// - "Gün"de **Günlük ortalama**'nın paydası 1 gündür ([dailyAverageSeconds]
///   `to.difference(from).inDays + 1`), yani "Toplam" ile **birebir aynı**
///   sayıyı verir — iki kart, tek bilgi.
/// - "Gün"de **Hafta içi / Hafta sonu** ([weekdayWeekendSplit]) tek bir güne
///   bakar; o gün ya hafta içidir ya hafta sonu, dolayısıyla iki döşemeden
///   **biri her zaman sıfırdır**.
/// - "Hafta"da **Eğilim grafiği** (S5) ile **Günlük dağılım** (S1) aynı 7 günü
///   çizer ([StatsPeriodX.chartDays] `week → 7`): aynı veri, iki grafik.
///
/// Küme artık dönemden türetilir. Karar noktası TEK yerdedir ki "hangi dönemde
/// ne var" sorusunun cevabı ekranın 200 satırına dağılmasın.
enum PersonalCardSet {
  day,
  week,
  month,
  year,
  all;

  /// Seçimden küme: `custom` **uyarlanabilirdir** — kendi kartı yoktur, seçilen
  /// aralığın gün sayısına göre yukarıdaki kümelerden birine eşlenir.
  /// 1 gün → [day], 2–31 gün → [month], 32+ gün → [year].
  static PersonalCardSet of(StatsPeriodSelection selection, {DateTime? now}) {
    switch (selection.period) {
      case StatsPeriod.day:
        return PersonalCardSet.day;
      case StatsPeriod.week:
        return PersonalCardSet.week;
      case StatsPeriod.month:
        return PersonalCardSet.month;
      case StatsPeriod.year:
        return PersonalCardSet.year;
      case StatsPeriod.all:
        return PersonalCardSet.all;
      case StatsPeriod.custom:
        final (from, to) = selection.range(now: now);
        final days = statsDaySpan(from, to);
        if (days <= 1) return PersonalCardSet.day;
        if (days <= 31) return PersonalCardSet.month;
        return PersonalCardSet.year;
    }
  }

  bool get _isDay => this == PersonalCardSet.day;

  // ---- Özet döşemeleri ---------------------------------------------------
  // "Toplam", "Çalışma saatleri" (S4) ve "Ders bazında dağılım" (S8) HER
  // dönemde vardır; onlar için bayrak yazılmadı — hiçbir zaman yanlış olmayan
  // bir anahtar ölü anahtardır.

  /// Günde payda 1 gündür: "Toplam" ile aynı sayı.
  bool get showDailyAverage => !_isDay;

  /// Günde tek gün ya hafta içidir ya hafta sonu; biri hep sıfır.
  bool get showWeekdaySplit => !_isDay;

  bool get showSessionCount => _isDay;
  bool get showLongestSession => _isDay;
  bool get showGoalStatus => _isDay;

  // ---- Ana içerik ---------------------------------------------------------
  bool get showSessionSchedule => _isDay;
  bool get showSessionScatter =>
      this == PersonalCardSet.day ||
      this == PersonalCardSet.week ||
      this == PersonalCardSet.month;

  // ---- Zaman serileri -----------------------------------------------------
  bool get showDailyDistribution =>
      this == PersonalCardSet.week || this == PersonalCardSet.month;
  bool get showMonthlyDistribution =>
      this == PersonalCardSet.year || this == PersonalCardSet.all;

  /// Haftada S1 ile aynı 7 günü çizerdi — tekrar.
  bool get showTrend =>
      this == PersonalCardSet.month ||
      this == PersonalCardSet.year ||
      this == PersonalCardSet.all;
  bool get showRangeTotals =>
      this == PersonalCardSet.year || this == PersonalCardSet.all;
  bool get showWeekComparison => this == PersonalCardSet.week;

  // ---- Desenler -----------------------------------------------------------
  bool get showCalendar =>
      this == PersonalCardSet.month ||
      this == PersonalCardSet.year ||
      this == PersonalCardSet.all;
  bool get showWeekRhythm => showCalendar;
  bool get showRadar => !_isDay;
  bool get showRecords => this == PersonalCardSet.all;
}

/// Bir gün anahtarının takvim gün numarası (1970-01-01 = 0).
///
/// 🔴 `a.difference(b).inDays` **kullanılmaz**: [dayOf] cihazın yerel gece
/// yarısını üretir, yaz saati uygulayan bir bölgede iki gece yarısının arası 23
/// ya da 25 saattir ve tam bölme 23 saati `0` güne yuvarlar (aynı tuzak
/// `stats_period_provider.dart` `_dayNumber` yorumunda ölçüldü). UTC'de her gün
/// tam 24 saattir.
int statsDayNumber(DateTime instant) {
  final day = dayOf(instant);
  return (DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch /
          Duration.millisecondsPerDay)
      .floor();
}

/// `[from, to]` arasındaki takvim günü sayısı (iki uç dâhil, en az 1).
int statsDaySpan(DateTime from, DateTime to) {
  final span = statsDayNumber(to) - statsDayNumber(from) + 1;
  return span < 1 ? 1 : span;
}

List<String> _monthNames(BuildContext context) => [
  AppLocalizations.of(context).statsOca,
  AppLocalizations.of(context).statsSub,
  AppLocalizations.of(context).statsMar,
  AppLocalizations.of(context).statsNis,
  AppLocalizations.of(context).statsMay,
  AppLocalizations.of(context).statsHaz,
  AppLocalizations.of(context).statsTem,
  AppLocalizations.of(context).statsAgu,
  AppLocalizations.of(context).statsEyl,
  AppLocalizations.of(context).statsEki,
  AppLocalizations.of(context).statsKas,
  AppLocalizations.of(context).statsAra,
];

/// Bir ay kovası (ayın ilk günü + o ayın toplam saniyesi).
class MonthTotal {
  const MonthTotal(this.month, this.seconds);

  final DateTime month;
  final int seconds;
}

/// [endMonth]'un ayında biten [count] aylık seri (eski → yeni), verisi olmayan
/// aylar 0. Gün kovası yerine AY kovası; [DayTotal]/[dailyRange] ikilisinin ay
/// karşılığıdır.
List<MonthTotal> monthlyTotals(
  Iterable<StudySession> sessions, {
  required DateTime endMonth,
  int count = 12,
}) {
  final totals = <int, int>{};
  for (final session in sessions) {
    final day = session.day;
    totals[day.year * 12 + (day.month - 1)] =
        (totals[day.year * 12 + (day.month - 1)] ?? 0) +
        session.durationSeconds;
  }
  final endKey = endMonth.year * 12 + (endMonth.month - 1);
  return [
    for (var i = count - 1; i >= 0; i--)
      MonthTotal(
        DateTime(endMonth.year, endMonth.month - i, 1),
        totals[endKey - i] ?? 0,
      ),
  ];
}

/// Aylık dağılım çubuk grafiği (y: saat). [DailyBarChart] ile aynı hizadadır —
/// aynı `BarChart`, aynı renk, aynı "boş kovada etiket yok" kuralı — yalnız
/// kova gün değil AYdır, o yüzden alt eksende gün numarası değil ay adı yazar.
class MonthlyBarChart extends StatelessWidget {
  const MonthlyBarChart({super.key, required this.months});

  final List<MonthTotal> months;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final names = _monthNames(context);
    final maxSeconds = months.fold<int>(
      0,
      (m, e) => e.seconds > m ? e.seconds : m,
    );
    // Kova ay olduğu için birim dakika değil SAAT: 12 aylık toplam dakikayla
    // çizilseydi eksen dört haneli olurdu.
    final maxY = maxSeconds <= 0 ? 1.0 : (maxSeconds / 3600) * 1.32;

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceBetween,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.transparent,
            tooltipPadding: EdgeInsets.zero,
            tooltipMargin: 2,
            getTooltipItem: (group, _, _, _) {
              final seconds = months[group.x].seconds;
              if (seconds <= 0) return null;
              return BarTooltipItem(
                formatHuman(seconds),
                theme.textTheme.labelSmall!.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 9,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= months.length) return const SizedBox.shrink();
                final month = months[i].month;
                return Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    names[month.month - 1],
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 9,
                      height: 1.1,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < months.length; i++)
            BarChartGroupData(
              x: i,
              showingTooltipIndicators: months[i].seconds > 0
                  ? const [0]
                  : const [],
              barRods: [
                BarChartRodData(
                  toY: months[i].seconds / 3600,
                  color: theme.colorScheme.primary,
                  width: 10,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(3),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// "Aylık dağılım" kartı (yıl / tümü): 12 ay kovası.
class MonthlyDistributionCard extends StatelessWidget {
  const MonthlyDistributionCard({
    super.key,
    required this.sessions,
    required this.endMonth,
  });

  final List<StudySession> sessions;

  /// Serinin bittiği ay (dönemin `to` ucunun ayı).
  final DateTime endMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final months = monthlyTotals(sessions, endMonth: endMonth);
    final empty = months.every((m) => m.seconds == 0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: empty
            ? Text(
                AppLocalizations.of(context).statsBuDonemdeCalismaKaydin,
                style: theme.textTheme.bodySmall,
              )
            : SizedBox(height: 180, child: MonthlyBarChart(months: months)),
      ),
    );
  }
}

/// "Oturum çizelgesi" kartı (gün): seçili günün oturumları **saat sırasıyla** —
/// başlangıç–bitiş saati, ders, süre.
///
/// Yeni bir grafik türü icat edilmedi; kart mevcut liste/satır deseniyle
/// (bkz. `_SubjectBreakdownCard` efsanesi) aynı biçimdedir. Saatler İstanbul
/// duvar saatidir ([istanbulHm]) — cihaz TZ'sinden bağımsız.
class SessionScheduleCard extends ConsumerWidget {
  const SessionScheduleCard({super.key, required this.sessions});

  final List<StudySession> sessions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final subjects = ref.watch(userSubjectsProvider).value ?? const <Subject>[];
    final subjectById = {for (final s in subjects) s.id: s};

    if (sessions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            l10n.statsBuDonemdeCalismaKaydin,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final ordered = [...sessions]..sort((a, b) => a.start.compareTo(b.start));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final session in ordered)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 5,
                      backgroundColor: _colorOf(
                        theme,
                        subjectById[session.subjectId],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // İki `Expanded` + sabit süre: 390 px telefonda satır
                    // taşmaz (bu dosyada `_StatCard`/`_WeekComparisonCard`
                    // taşmaları WP-673'te ölçülmüştü).
                    Expanded(
                      child: Text(
                        '${istanbulHm(session.start)} – '
                        '${istanbulHm(session.end)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        subjectById[session.subjectId]?.name ?? l10n.statsGenel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatHuman(session.durationSeconds),
                      style: theme.textTheme.labelLarge,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _colorOf(ThemeData theme, Subject? subject) => subject == null
      ? theme.colorScheme.onSurfaceVariant
      : subjectColor(subject.color);
}

/// "Rekorlar" kartı (yalnız "Tümü"): tüm zaman metrikleri — ilk çalışma günü,
/// en yoğun gün, rekor seri.
///
/// 🔴 `study_records.dart` [StudyRecords] OKUNDU ve **yeniden kullanılmadı**:
/// beş döşemesinin ilki "Toplam"dır ve bu ekranda "Toplam" zaten en üstteki
/// özet döşemesidir (aynı sayı iki kez), "Aktif gün"/"En çok ders" bu WP'nin
/// kart listesinde yoktur, "İlk çalışma günü" ise onda hiç yoktur. Yani
/// kullanılabilecek kısmı üç metrikten ikisidir; kalanı bu ekranda tekrar
/// üretirdi.
class PersonalRecordsCard extends ConsumerWidget {
  const PersonalRecordsCard({
    super.key,
    required this.sessions,
    required this.totals,
  });

  final List<StudySession> sessions;
  final Map<DateTime, int> totals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final months = _monthNames(context);
    final goalSeconds = ref.watch(dailyGoalMinutesProvider) * 60;

    DateTime? firstDay;
    for (final entry in totals.entries) {
      if (entry.value <= 0) continue;
      if (firstDay == null || entry.key.isBefore(firstDay)) firstDay = entry.key;
    }
    final peak = peakDay(totals);
    // Hedef AÇIKÇA geçilir: `longestStudyStreak` hedefsiz çağrıyı derlemez
    // (WP-639), çünkü sessiz varsayılan sahibin reddettiği kurala düşerdi.
    final longest = longestStudyStreak(
      sessions,
      totals: totals,
      goalSeconds: goalSeconds,
    );

    String dayLabel(DateTime day) => '${day.day} ${months[day.month - 1]}';

    final tiles = <Widget>[
      _RecordTile(
        icon: Icons.flag_outlined,
        color: subjectColor('chart-3'),
        label: l10n.statsIlkCalismaGunu,
        value: firstDay == null ? '—' : dayLabel(firstDay),
      ),
      _RecordTile(
        icon: Icons.emoji_events_outlined,
        color: subjectColor('chart-1'),
        label: l10n.statsEnYogunGun,
        value: peak == null
            ? '—'
            : '${formatHuman(peak.seconds)}\n${dayLabel(peak.day)}',
      ),
      _RecordTile(
        icon: Icons.local_fire_department,
        color: subjectColor('chart-5'),
        label: l10n.statsRekorSeri,
        value: l10n.statsStreakGun(longest.toString()),
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const gap = 8.0;
            // Dar kapta tek sütun; 360 px'ten sonra üçe bölünür.
            final columns = constraints.maxWidth >= 360 ? 3 : 1;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final tile in tiles) SizedBox(width: width, child: tile),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
