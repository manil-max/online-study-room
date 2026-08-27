import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/desktop/desktop_window.dart';
import '../../../core/stats/session_window.dart';
import '../../../core/navigation/nav_index.dart';
import '../../../core/stats/stats_period.dart';
import '../../../core/stats/study_stats.dart';
import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../core/widgets/safe_screen_padding.dart';
import '../../../data/models/study_session.dart';
import '../../../data/models/subject.dart';
import '../../../data/models/user_study_summary.dart';
import '../../../data/providers/analytics_query_providers.dart';
import '../../../data/providers/stats_period_provider.dart';
import '../../../data/providers/study_providers.dart';
import '../../../data/providers/subject_providers.dart';
import '../analytics/analytics_period.dart';
import '../charts/area_line_chart.dart';
import '../charts/radar_stat_chart.dart';
import 'daily_bar_chart.dart';
import 'hour_activity_chart.dart';
import 'personal_period_cards.dart';
import 'session_scatter_chart.dart';
import 'stats_desktop_layout.dart';
import 'study_heatmap.dart';
import 'subject_donut.dart';
import 'week_hour_heatmap.dart';
import '../stats_l10n.dart';

/// Kişisel istatistik: sabit ListView bölümleri (WP-179; sürükle-grid yok).
/// [sessions] sıcak pencere; [summary] yıl/ömür; uzun aralık RPC.
class PersonalStatsView extends ConsumerStatefulWidget {
  const PersonalStatsView({super.key, required this.sessions, this.summary});

  final List<StudySession> sessions;
  final UserStudySummary? summary;

  @override
  ConsumerState<PersonalStatsView> createState() => _PersonalStatsViewState();
}

class _PersonalStatsViewState extends ConsumerState<PersonalStatsView> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(navReselectProvider, (previous, next) {
      if (next.tabIndex != AppTab.stats.index ||
          next.tick <= (previous?.tick ?? 0) ||
          !_scrollController.hasClients ||
          _scrollController.offset <= 0) {
        return;
      }
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
    final sessions = widget.sessions;
    final summary = widget.summary;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final sel = ref.watch(statsPeriodProvider);
    final period = sel.period;
    final (from, to) = sel.range(now: now);
    final analyticsPeriod = analyticsPeriodFromSelection(sel);
    // 🔴 WP-745: hangi kartın çizileceği artık DÖNEMDEN türer
    // (bkz. [PersonalCardSet]). Önceden altı dönem düğmesi de aşağıya aynı 25
    // kartı seriyordu; yalnız sayılar değişiyordu.
    final cardSet = PersonalCardSet.of(sel, now: now);
    // "Seçili tarih aralığı" (S10) yalnız Yıl/Tümü'de var; kart yokken RPC de
    // açılmaz. Çizilmeyen kartın verisini çekmek ölü bir okumadır.
    final longTotalsAsync = cardSet.showRangeTotals
        ? ref.watch(analyticsUserDayTotalsProvider(analyticsPeriod))
        : null;
    final goalMinutes = ref.watch(dailyGoalMinutesProvider);
    final goalSeconds = goalMinutes * 60;

    // Ömür: özetten (period == all Toplam kartı için).
    final lifetime = summary?.lifetimeSeconds;

    // Gün→saniye haritası: rekor/heatmap tüm sıcak pencere; trend alt seçici.
    final dailyTotalsMap = dailyTotals(sessions);

    // 🔴 WP-561: "Tümü" (`from == DateTime(2000)`) ve "Yıl" dönemlerinde payda
    // takvim gününden geliyordu (≈9718 gün) ama pay yalnız 90 günlük **sıcak
    // pencereden** (`kUserSessionsHotWindowDays`) hesaplanıyor. 300 saat çalışmış
    // kullanıcıda "Toplam: 300 sa" ile "Günlük Ortalama: 37 sn" yan yana
    // çıkıyordu. Payda artık verinin gerçekten bulunduğu ufka kırpılır.
    final avgWindow = averageWindow(
      periodFrom: from,
      hotWindowStart: sessionHotWindowStart(now: now),
      dayTotals: dailyTotalsMap,
    );

    // 🔴 WP-573: dönem sıcak pencerenin gerisine uzanıyorsa detay kartları
    // (ders kırılımı, saat dağılımı, oturum dağılımı, haftalık ritim, hafta
    // içi/sonu, Toplam) artık **sunucudan** beslenir. Önceden hepsi
    // `widget.sessions`ten çiziliyordu; o liste 90 günlük sıcak penceredir
    // (`supabase_study_repository.dart` `_fetchHotWindowSessions`), yani 400
    // günlük geçmişi olan kullanıcı "Tümü"de yalnız son 90 günün toplamını
    // görüyordu. Sunucu yolu (`analyticsUserSessionsInRangeProvider`) tam bu
    // iş için yazılmıştı ama `lib/` içinde **tek bir çağıranı yoktu**: bitmiş
    // backend, bağlanmamış UI — yani özellik yoktu.
    final beyondHot = avgWindow.hotLimited;
    // Dönem zaten sıcak pencerenin içindeyse sunucuya hiç gidilmez.
    final longSessionsAsync = beyondHot
        ? ref.watch(analyticsUserSessionsInRangeProvider(analyticsPeriod))
        : null;
    final serverRange = longSessionsAsync?.value;
    final periodSessions =
        serverRange?.sessions ?? inRange(sessions, from, to).toList();
    // 🔴 Sunucu yolu gelmediyse (yükleniyor / hata) **sessizce** 90 güne
    // düşülmez: başlık kapsamı söyler ([scopeSuffix]), hata dalı ayrıca
    // tekrar-dene sunar ([scopeFailed]). Etiket artık "dönem ufku aşıyor mu"
    // değil "kartlar gerçekten 90 günle mi sınırlı" sorusunu yanıtlar.
    //
    // 🔴 WP-585: sunucu BOŞ dönüp provider sıcak pencereye geri düştüğünde de
    // etiket yazılır ([AnalyticsRangeSessions.hotLimited]). Eskiden bu dalda
    // `serverSessions != null` olduğu için view "veri geldi" sanıyor, kartlar
    // 90 günü gösterirken başlık dönemin tamamını iddia ediyordu.
    final hotLimited =
        beyondHot && (serverRange == null || serverRange.hotLimited);
    final scopeFailed = longSessionsAsync?.hasError ?? false;

    // Döneme göre hafta içi/sonu (ortalama aşağıda, veri ufkuna kırpılarak).
    final split = weekdayWeekendSplit(periodSessions);

    // Sıcak pencere boş olsa da sunucu dönem verisi getirmiş olabilir; o durumda
    // "henüz kaydın yok" demek yeni bir sessiz yalandır.
    if (sessions.isEmpty && periodSessions.isEmpty) {
      // 🔴 WP-541: `Center` + `Column` = kaydırıcı yok. Sekme çubuğu + dönem
      // şeridi yüksekliği yedikten sonra büyük yazı ölçüsünde bu blok
      // viewport'a sığmıyor ve taşıyordu (320x640, textScale 2.0 → "A RenderFlex
      // overflowed by 58 pixels on the bottom"). Grup ekranındaki boş durumla
      // (bkz. `classroom_screen.dart` `_NoGroupView`) aynı desen, aynı çözüm:
      // sığdığında ortalanır, sığmadığında kayar.
      const padding = EdgeInsets.all(24);
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.hasBoundedHeight
                  ? (constraints.maxHeight - padding.vertical).clamp(
                      0.0,
                      double.infinity,
                    )
                  : 0.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.timelapse,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context).statsHenuzCalismaKaydinYok,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context).statsBuDonemdeCalismaKaydin,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final periodTotalSec = totalSeconds(periodSessions);
    final avgPeriod = dailyAverageSeconds(periodSessions, avgWindow.from, to);
    final periodLabel = statsPeriodLabel(l10n, period);
    final scopeSuffix = hotLimited
        ? ' · ${l10n.statsStreakGun(kUserSessionsHotWindowDays.toString())}'
        : '';

    // 🔴 WP-745 (1): "Günlük dağılım" (S1) penceresinin SONU daima `bugün`dü —
    // [lastNDays] pencereyi `today ?? DateTime.now()`da bitirir ve `offset`i
    // hiç okumazdı. "Geçen hafta"da başlık geçen haftayı yazarken grafik bu
    // haftayı çiziyordu. Uç artık dönemin `to`suna bağlı.
    final chartEnd = dayOf(to);

    // 🔴 WP-765 (1): oturum dağılımının penceresi artık dönemin KENDİSİ.
    //
    // WP-745 grafiğin bugünden geriye ikinci kez kırpmasını `days`i "dönemin
    // başından BUGÜNE" uzatarak telafi etmişti; grafik boş çıkmıyordu ama
    // pencerenin SONU hâlâ bugündü ([SessionScatterChart] `endDay` almıyordu).
    // Ölçülen hâl (bugün 27 Ağustos, "Ay" offset -1 = Temmuz): eksen 31 değil
    // 58 gün, alt eksende "10 Ağu" gibi **dönem dışı** tarih yazıyor, noktalar
    // sol yarıya sıkışıyordu. İki uç da tek kaynaktan gelir: `sel.range()`.
    final scatterDays = statsDaySpan(from, chartEnd);

    // 🔴 WP-745 (3): radar "tutarlılık" ekseninin paydası SABİT 14 gündü, yani
    // "Hafta"da en iyi ihtimalle 7/14 = 0.5 çıkıyordu — kısa dönem hep dipte.
    // Payda artık verinin gerçekten bulunduğu ufuktur ([averageWindow]), yani
    // "Günlük ortalama" döşemesiyle AYNI payda.
    final consistencyDays = statsDaySpan(avgWindow.from, to);

    // 🔴 WP-745 (4): "Çalışma takvimi" SABİT 13 hafta çiziyordu; "Yıl"/"Tümü"de
    // de son 13 haftayı gösteriyordu. Harita bugünde biter, o yüzden pencere
    // dönemin başından bugüne uzatılır; "Tümü"de veri ufkunun tamamını alır.
    // Uzun dönemde sunucudan gelen günler de haritaya katılır — aksi hâlde
    // 53 haftalık bir ızgara 90 günlük veriyle boyanırdı.
    final calendarTotals = beyondHot
        ? <DateTime, int>{...dailyTotalsMap, ...dailyTotals(periodSessions)}
        : dailyTotalsMap;
    final calendarWeeks = _calendarWeeks(
      cardSet: cardSet,
      periodFrom: from,
      now: now,
      totals: calendarTotals,
    );

    final sessionCount = periodSessions.length;
    final longestSessionSeconds = periodSessions.fold<int>(
      0,
      (m, s) => s.durationSeconds > m ? s.durationSeconds : m,
    );

    // ---- Özet döşemeleri ---------------------------------------------------
    // 🔴 WP-673 / SPEC §3 A2: bu kartlar ÖNCEDEN elle 2×2 diziliyordu (iki
    // `Row(Expanded, Expanded)`), yani sütun sayısı sabit 2'ydi ve genişliğe
    // hiç bakmıyordu. 1920 px pencerede her kart ~800 px oluyor, içinde tek bir
    // "2s" yazıyordu — sahibin 3 numaralı şikâyeti birebir buydu.
    // Masaüstünde artık [StatsTileGrid] akıtır ve döşeme 320 px'te tavanlanır;
    // mobil dal aşağıda BİREBİR eski 2×2 hâlinde durur (SPEC §7).
    //
    // 🔴 WP-745: kümesi dönemden gelir. "Gün"de "Günlük ortalama"nın paydası
    // 1 gündür ([dailyAverageSeconds]) → "Toplam" ile birebir aynı sayı; "Hafta
    // içi"/"Hafta sonu"nda tek gün ya biridir ya öteki → biri hep sıfır. Onların
    // yerini güne gerçekten ait üç ölçü alır.
    final statTiles = <Widget>[
      _StatCard(
        label: l10n.statsToplam,
        seconds: period == StatsPeriod.all && lifetime != null
            ? lifetime
            : periodTotalSec,
        icon: Icons.timelapse,
      ),
      if (cardSet.showSessionCount)
        _StatCard(
          label: l10n.statsOturumSayisi,
          value: sessionCount.toString(),
          icon: Icons.format_list_numbered,
        ),
      if (cardSet.showLongestSession)
        _StatCard(
          label: l10n.statsEnUzunOturum,
          seconds: longestSessionSeconds,
          icon: Icons.hourglass_bottom,
        ),
      if (cardSet.showGoalStatus)
        _StatCard(
          label: l10n.statsHedefDurumu,
          // Hedef yoksa yüzde uydurulmaz; ölçüsüz kart "—" der.
          value: goalSeconds <= 0
              ? '—'
              : '%${(periodTotalSec * 100 / goalSeconds).round()}',
          icon: Icons.flag_outlined,
        ),
      if (cardSet.showDailyAverage)
        _StatCard(
          label: l10n.statsGunlukOrtalama,
          seconds: avgPeriod.round(),
          icon: Icons.trending_up,
        ),
      if (cardSet.showWeekdaySplit) ...[
        _StatCard(
          label: l10n.statsHaftaIci,
          seconds: split.weekday,
          icon: Icons.work_outline,
        ),
        _StatCard(
          label: l10n.statsHaftaSonu,
          seconds: split.weekend,
          icon: Icons.weekend_outlined,
        ),
      ],
    ];

    // ---- Bağımsız bölümler -------------------------------------------------
    // Sıra ve içerik WP-673 öncesiyle aynıdır; yalnız her başlık+kart çifti bir
    // [StatsSection]'a sarıldı ki masaüstünde iki sütuna akıtılabilsin. Hiçbir
    // metrik, grafik ya da katlanır blok kaldırılmadı (SPEC §7).
    final sections = <Widget>[
      // ---- Ana içerik ------------------------------------------------------
      if (cardSet.showSessionSchedule)
        StatsSection(
          title: l10n.statsOturumCizelgesi,
          child: SessionScheduleCard(sessions: periodSessions),
        ),
      StatsSection(
        title: '${l10n.statsCalismaSaatleri} · $periodLabel$scopeSuffix',
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: HourActivityChart(hourly: hourlyTotals(periodSessions)),
          ),
        ),
      ),
      StatsSection(
        title: '${l10n.statsDersBazindaDagilimSon} · $periodLabel$scopeSuffix',
        child: _SubjectBreakdownCard(sessions: periodSessions),
      ),
      if (cardSet.showSessionScatter)
        StatsSection(
          title: '${l10n.statsOturumDagilimi} · $periodLabel$scopeSuffix',
          // P10 scatter — varsayılan katlı (WP ürün kararı)
          child: _CollapsibleSection(
            title: l10n.statsOturumDagilimi,
            initiallyExpanded: false,
            child: periodSessions.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.statsBuDonemdeCalismaKaydin,
                      style: theme.textTheme.bodySmall,
                    ),
                  )
                : SessionScatterChart(
                    sessions: periodSessions,
                    days: scatterDays,
                    endDay: chartEnd,
                  ),
          ),
        ),

      // ---- Zaman serileri --------------------------------------------------
      if (cardSet.showDailyDistribution)
        StatsSection(
          title: l10n.statsGunlukDagilim,
          // Yerel 7/14/30 kalır; master period değişince otomatik senkron.
          child: _TrendCard(
            sessions: sessions,
            totals: dailyTotalsMap,
            end: chartEnd,
          ),
        ),
      if (cardSet.showMonthlyDistribution)
        StatsSection(
          title: '${l10n.statsAylikDagilim} · $periodLabel$scopeSuffix',
          child: MonthlyDistributionCard(
            sessions: periodSessions,
            endMonth: chartEnd,
          ),
        ),
      // P2 area trend (dönem serisi)
      if (cardSet.showTrend)
        StatsSection(
          title: '${l10n.homeEgilimGrafigi} · ${statsPeriodLabel(l10n, period)}',
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                height: 140,
                child: Builder(
                  builder: (context) {
                    // 🔴 WP-561: pencere artık DÖNEME bağlı. Eskiden
                    // `lastNDays(periodSessions, …, totals: dailyTotalsMap)`
                    // çağrılıyordu: `totals` verildiği için `periodSessions`
                    // argümanı **hiç okunmuyordu** (ölü parametre, üstelik iki
                    // argüman birbiriyle çelişiyordu) ve pencere daima
                    // `DateTime.now()`da bitiyordu — "Geçen ay"a gidildiğinde
                    // başlık geçen ayı, grafik bu ayın son günlerini
                    // gösteriyordu.
                    final chartStart = chartEnd.subtract(
                      Duration(days: period.chartDays() - 1),
                    );
                    final series = dailyRange(
                      sessions,
                      chartStart,
                      chartEnd,
                      totals: dailyTotalsMap,
                    );
                    if (series.isEmpty || series.every((d) => d.seconds == 0)) {
                      return Center(
                        child: Text(
                          l10n.statsBuDonemdeCalismaKaydin,
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return AreaLineChart(
                      values: [for (final d in series) d.seconds / 3600.0],
                      labels: [
                        for (final d in series) '${d.day.day}/${d.day.month}',
                      ],
                      yUnit: l10n.statsSaatKisa,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      // P11 detaylı geçmiş (RPC / uzun aralık)
      if (longTotalsAsync != null)
        StatsSection(
          title: l10n.statsSeciliTarihAraligi,
          child: longTotalsAsync.when(
            loading: () => const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (_, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.authBeklenmeyenBirHataOlustu,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
            data: (map) {
              if (map.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.statsBuDonemdeCalismaKaydin,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                );
              }
              final days = map.keys.toList()..sort();
              final vals = [for (final d in days) (map[d] ?? 0) / 3600.0];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${formatHuman(map.values.fold<int>(0, (a, b) => a + b))} · ${days.length}d',
                        style: theme.textTheme.labelMedium,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 120,
                        child: AreaLineChart(
                          values: vals,
                          labels: [for (final d in days) '${d.day}/${d.month}'],
                          yUnit: l10n.statsSaatKisa,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      if (cardSet.showWeekComparison)
        StatsSection(
          title: l10n.statsSeciliHaftaVsOnceki,
          child: _WeekComparisonCard(
            sessions: sessions,
            selection: sel,
            now: now,
          ),
        ),

      // ---- Desenler --------------------------------------------------------
      if (cardSet.showCalendar)
        StatsSection(
          title: '${l10n.homeCalismaTakvimi} · $periodLabel$scopeSuffix',
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: StudyHeatmap(
                sessions: sessions,
                weeks: calendarWeeks,
                precomputedTotals: calendarTotals,
              ),
            ),
          ),
        ),
      if (cardSet.showWeekRhythm)
        StatsSection(
          title: '${l10n.statsHaftalikRitim} · $periodLabel$scopeSuffix',
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: WeekHourHeatmap(grid: weekdayHourTotals(periodSessions)),
            ),
          ),
        ),
      // P12 radar — basit türetilmiş skorlar
      if (cardSet.showRadar)
        StatsSection(
          title: l10n.analyticsCardInsight,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 200,
                child: _PersonalRadar(
                  sessions: periodSessions,
                  paceSeconds: avgPeriod.round(),
                  goalSeconds: goalSeconds,
                  split: split,
                  consistencyDays: consistencyDays,
                ),
              ),
            ),
          ),
        ),
      if (cardSet.showRecords)
        StatsSection(
          title: l10n.statsRekorlar,
          child: PersonalRecordsCard(
            sessions: periodSessions,
            totals: calendarTotals,
          ),
        ),
    ];

    // Üst dönem + seçili dönem özeti
    final periodHeading = Text(
      statsPeriodLabel(l10n, period),
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    // 🔴 WP-573: uzun dönem verisi düştüyse kullanıcı çıkışsız kalmaz.
    // WP-560 dersi: çıkışı olmayan hata dalı açılmaz.
    final scopeFailedCard = Card(
      child: ErrorRetryView(
        dense: true,
        message: l10n.homeVerilerYuklenemedi,
        onRetry: () =>
            ref.invalidate(analyticsUserSessionsInRangeProvider(analyticsPeriod)),
      ),
    );

    if (isDesktopWindow) {
      // SPEC §4: masaüstü sayfa kenar boşluğu 24 (≥1440 bandı).
      return ListView(
        controller: _scrollController,
        padding: getSafeVerticalPadding(context, horizontal: 24),
        children: [
          periodHeading,
          if (scopeFailed) scopeFailedCard,
          const SizedBox(height: 8),
          StatsTileGrid(tiles: statTiles),
          const SizedBox(height: kStatsGridGutter),
          StatsSectionColumns(sections: sections),
        ],
      );
    }

    return ListView(
      controller: _scrollController,
      padding: getSafeVerticalPadding(context),
      children: [
        periodHeading,
        if (scopeFailed) scopeFailedCard,
        const SizedBox(height: 8),
        // 🔴 WP-745: satırlar ikişerli **türetilir**. Eskiden `statTiles[0..3]`
        // sabit indekslerdi; küme dönemden gelince o indeksler bir dönemde
        // sessizce aralık dışına düşerdi. Görünen düzen aynı 2×2'dir.
        for (var i = 0; i < statTiles.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: statTiles[i]),
              const SizedBox(width: 8),
              if (i + 1 < statTiles.length)
                Expanded(child: statTiles[i + 1])
              else
                const Spacer(),
            ],
          ),
        ],
        for (final section in sections) ...[
          const SizedBox(height: 16),
          section,
        ],
      ],
    );
  }
}

/// Isı haritasının **seçili dönemi kapsayan** hafta sayısı.
///
/// [StudyHeatmap] her zaman bu haftada biter, o yüzden pencere dönemin
/// başlangıcından bugüne uzatılır. "Tümü"nde dönem `DateTime(2000)`den başlar
/// (≈1300 hafta); orada sınır **veri ufkudur**: ilk kayıtlı gün, yoksa sıcak
/// pencerenin başı. Üst sınır 5 yıl — kullanıcı ne kadar eski olursa olsun
/// ızgara sonsuz büyümez (kart yatay kaydırılabilir).
int _calendarWeeks({
  required PersonalCardSet cardSet,
  required DateTime periodFrom,
  required DateTime now,
  required Map<DateTime, int> totals,
}) {
  DateTime start = dayOf(periodFrom);
  if (cardSet == PersonalCardSet.all) {
    DateTime? earliest;
    for (final entry in totals.entries) {
      if (entry.value <= 0) continue;
      if (earliest == null || entry.key.isBefore(earliest)) earliest = entry.key;
    }
    start = earliest ?? sessionHotWindowStart(now: now);
  }
  final weeks =
      (statsDayNumber(startOfWeek(now)) - statsDayNumber(startOfWeek(start))) ~/
          7 +
      1;
  return weeks.clamp(4, 260);
}

class _CollapsibleSection extends StatefulWidget {
  const _CollapsibleSection({
    required this.title,
    required this.child,
    this.initiallyExpanded = true,
  });

  final String title;
  final Widget child;
  final bool initiallyExpanded;

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  late bool _open = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            title: Text(widget.title),
            trailing: Icon(_open ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _open = !_open),
            minVerticalPadding: 12,
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: widget.child,
            ),
        ],
      ),
    );
  }
}

/// Basit 5 eksen radar (tempo, tutarlılık, çeşitlilik, süre, odak saati).
class _PersonalRadar extends StatelessWidget {
  const _PersonalRadar({
    required this.sessions,
    required this.paceSeconds,
    required this.goalSeconds,
    required this.split,
    required this.consistencyDays,
  });

  final List<StudySession> sessions;

  /// 🔴 WP-765 (2): "Günlük hedef" ekseninin PAYI.
  ///
  /// Önceden `secondsOnDay(sessions, DateTime.now())` idi — dönem ne olursa
  /// olsun **bugünün** saniyesi. "Geçen ay" seçiliyken radarın bu köşesi geçen
  /// ayı değil bugünü anlatıyordu: bugün hiç çalışılmadıysa köşe tabana
  /// yapışıyordu (`RadarEntry` alt kırpması 0.05), oysa o ay hedefin üstünde
  /// kapanmış olabilirdi. Pay artık dönemin **günlük ortalamasıdır**: ekrandaki
  /// "Günlük ortalama" döşemesiyle aynı sayı, aynı payda ([averageWindow]).
  final int paceSeconds;

  final int goalSeconds;
  final ({int weekday, int weekend}) split;

  /// 🔴 WP-745: "tutarlılık" ekseninin **paydası**. Sabit `14` idi: "Hafta"da
  /// en iyi ihtimalle 7/14 = 0.5, yani kısa dönemler yapısal olarak hep dipte
  /// görünüyordu. Payda artık verinin bulunduğu ufuktur ([averageWindow]) —
  /// "Günlük ortalama" döşemesinin paydasıyla aynı sayı.
  final int consistencyDays;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (sessions.isEmpty) {
      return Center(
        child: Text(
          l10n.statsBuDonemdeCalismaKaydin,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      );
    }
    final total = totalSeconds(sessions).toDouble();
    final tempo = goalSeconds <= 0
        ? 0.5
        : (paceSeconds / goalSeconds).clamp(0.0, 1.0);
    final days = dailyTotals(sessions).values.where((s) => s > 0).length;
    final consistency = consistencyDays <= 0
        ? 0.0
        : (days / consistencyDays).clamp(0.0, 1.0);
    final subjects = <String>{
      for (final s in sessions)
        if (s.subjectId != null) s.subjectId!,
    };
    final variety = (subjects.length / 5.0).clamp(0.0, 1.0);
    final durationScore = (total / (10 * 3600)).clamp(0.0, 1.0);
    final balance = total <= 0
        ? 0.5
        : (1.0 - ((split.weekday - split.weekend).abs() / total)).clamp(
            0.0,
            1.0,
          );

    return RadarStatChart(
      values: [tempo, consistency, variety, durationScore, balance],
      labels: [
        l10n.homeGunlukHedef,
        l10n.statsRekorlar,
        l10n.statsDersBazindaDagilimSon,
        l10n.statsToplam,
        l10n.statsHaftaIci,
      ],
    );
  }
}

/// Günlük çubuk grafiği + gün aralığı seçici (7 / 14 / 30 gün).
///
/// Yerel seçici kalır; üst [statsPeriodProvider] değişince en yakın
/// seçeneğe otomatik senkronlanır (kullanıcı sonra yine yerel değiştirebilir).
class _TrendCard extends ConsumerStatefulWidget {
  const _TrendCard({required this.sessions, required this.end, this.totals});

  final List<StudySession> sessions;

  /// 🔴 WP-745: pencerenin BİTİŞ günü. [lastNDays] `today` verilmediğinde
  /// pencereyi `DateTime.now()`da bitirir ve `StatsPeriodSelection.offset`i hiç
  /// okumaz: "Geçen hafta"da başlık geçen haftayı yazarken grafik BU haftayı
  /// çiziyordu. Uç artık dönemin `to`sudur.
  final DateTime end;

  final Map<DateTime, int>? totals;

  @override
  ConsumerState<_TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends ConsumerState<_TrendCard> {
  static const _options = [7, 14, 30];
  late int _days;

  @override
  void initState() {
    super.initState();
    // İlk açılış: mevcut master dönemle hizala.
    _days = ref.read(statsPeriodProvider).period.chartDays(options: _options);
  }

  @override
  Widget build(BuildContext context) {
    // Master dönem değişince yerel 7/14/30'u güncelle; kullanıcı override edebilir.
    ref.listen(statsPeriodProvider, (prev, next) {
      if (prev?.period == next.period) return;
      final mapped = next.period.chartDays(options: _options);
      if (_days != mapped) setState(() => _days = mapped);
    });

    final series = lastNDays(
      widget.sessions,
      _days,
      today: widget.end,
      totals: widget.totals,
    );
    final goalSeconds = ref.watch(dailyGoalMinutesProvider) * 60;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          children: [
            SegmentedButton<int>(
              segments: [
                ButtonSegment(
                  value: 7,
                  label: Text(AppLocalizations.of(context).statsValue7Gun),
                ),
                ButtonSegment(
                  value: 14,
                  label: Text(AppLocalizations.of(context).statsValue14Gun),
                ),
                ButtonSegment(
                  value: 30,
                  label: Text(AppLocalizations.of(context).statsValue30Gun),
                ),
              ],
              selected: {_days},
              onSelectionChanged: (s) => setState(() => _days = s.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: DailyBarChart(days: series, goalSeconds: goalSeconds),
            ),
          ],
        ),
      ),
    );
  }
}

/// Seçili haftayı bir öncekiyle kıyaslar (dönemler arası — project.md §3.4).
///
/// 🔴 WP-745: kart ART IK gezinilen haftayı anlatır. WP-743'ten sonra hafta
/// gezinilebilir hale geldi ama bu kart her zaman [weekOverWeekSeconds]'i "şimdi"
/// ile çağırıyordu: "Geçen hafta"ya gidildiğinde başlık geçen haftayı,
/// kart BU haftayı yazıyordu. Etiketler de artık sabit "Bu hafta"/"Geçen hafta"
/// değil, gezinme çubuğuyla aynı dili konuşan [statsPeriodNavTitle]'dir.
class _WeekComparisonCard extends StatelessWidget {
  const _WeekComparisonCard({
    required this.sessions,
    required this.selection,
    required this.now,
  });

  final List<StudySession> sessions;
  final StatsPeriodSelection selection;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final (from, to) = selection.range(now: now);

    final int thisWeek;
    final int lastWeek;
    if (selection.offset == 0) {
      // İçinde bulunulan hafta YAŞIYOR: kısmî hafta kısmî haftayla kıyaslanır
      // (WP-561 — aksi hâlde Salı günü kullanıcı matematiksel olarak her zaman
      // "kötüye gidiyorum" görüyordu).
      final wow = weekOverWeekSeconds(sessions, now: now);
      thisWeek = wow.thisWeek;
      lastWeek = wow.lastWeek;
    } else {
      // Kapalı hafta: iki taraf da TAM 7 gündür, kırpmaya gerek yok.
      thisWeek = totalSeconds(inRange(sessions, from, to));
      lastWeek = totalSeconds(
        inRange(
          sessions,
          DateTime(from.year, from.month, from.day - 7),
          DateTime(from.year, from.month, from.day - 1),
        ),
      );
    }

    final diff = thisWeek - lastWeek;
    // `diff == 0` iken eskiden `improved = true` olup yeşil "+0 dk" yazıyordu.
    final improved = diff > 0;
    final flat = diff == 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _MiniMetric(
                    label: statsPeriodNavTitle(l10n, selection, now: now),
                    value: formatHuman(thisWeek),
                  ),
                ),
                Expanded(
                  child: _MiniMetric(
                    label: statsPeriodNavTitle(
                      l10n,
                      selection.shifted(-1),
                      now: now,
                    ),
                    value: formatHuman(lastWeek),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 🔴 WP-673 BULGUSU: bu satır 390x844 telefonda **23 px
            // taşıyordu** ("A RenderFlex overflowed by 23 pixels on the
            // right"): ikon + fark + "Bu hafta vs geçen" üç üye `Card`ın
            // 318 px'lik içine sığmıyordu. Üçüncü üye WP-745'te KALKTI:
            // aynı cümle artık bölüm başlığında ("Seçili hafta vs önceki")
            // bir kez yazılıyor, kartın içinde ikinci kez tekrarlanmıyor.
            Row(
              children: [
                Icon(
                  flat
                      ? Icons.trending_flat
                      : improved
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  size: 18,
                  color: flat
                      ? theme.colorScheme.onSurfaceVariant
                      : improved
                      ? subjectColor('chart-2')
                      : theme.colorScheme.error,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    flat
                        ? formatHuman(0)
                        : '${improved ? '+' : '-'}${formatHuman(diff.abs())}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: flat
                          ? theme.colorScheme.onSurfaceVariant
                          : improved
                          ? subjectColor('chart-2')
                          : theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Küçük etiket + değer (kıyas kartı için).
class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.titleMedium),
      ],
    );
  }
}

/// Tek bir istatistik kartı (etiket + süre).
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    this.seconds,
    this.value,
    this.icon,
  }) : assert(seconds != null || value != null, 'stat tile needs a measure');

  final String label;
  final int? seconds;

  /// WP-745: süre OLMAYAN ölçüler için hazır metin ("Oturum sayısı" bir adet,
  /// "Hedef durumu" bir yüzdedir). Verilirse [seconds] okunmaz.
  final String? value;

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                ],
                // 🔴 WP-673 BULGUSU (duzeltme degil, KUSUR): bu `Text`
                // sarmalayicisizdi ve 390x844 telefonda `_StatCard` satiri
                // **73 px tasiyordu** ("A RenderFlex overflowed by 73 pixels on
                // the right", `Row` bu satir). "Gunluk ortalama" etiketi
                // 175 px'lik yarim sutuna sigmiyor. Kusur WP-673 oncesinden
                // beri vardi; hicbir test 390 px'te bu karti cizmedigi icin
                // sessizdi. `Expanded` + ellipsis hem telefonu hem 320 px'lik
                // masaustu dosemesini emniyete alir; metin KAYBOLMAZ, kirpilir.
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value ?? formatHuman(seconds!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }
}

/// Ders bazında dağılım: verilen oturumları derse göre toplar, etkileşimli donut
/// + açıklama (legend) ile gösterir. Veri formatı (yüzde / süre) seçilebilir.
/// Derssiz süreler "Genel" altında toplanır (project.md §3.7).
class _SubjectBreakdownCard extends ConsumerStatefulWidget {
  const _SubjectBreakdownCard({required this.sessions});

  final List<StudySession> sessions;

  @override
  ConsumerState<_SubjectBreakdownCard> createState() =>
      _SubjectBreakdownCardState();
}

class _SubjectBreakdownCardState extends ConsumerState<_SubjectBreakdownCard> {
  bool _showPercent = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subjects = ref.watch(userSubjectsProvider).value ?? const <Subject>[];
    final breakdown = subjectBreakdown(widget.sessions);

    if (breakdown.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            AppLocalizations.of(context).statsBuDonemdeCalismaKaydin,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // id→Subject map'i: döngü içinde O(1) arama (önceki O(slices×subjects)).
    final subjectById = {for (final s in subjects) s.id: s};
    Subject? subjectFor(String? id) => id == null ? null : subjectById[id];

    final total = breakdown.fold<int>(0, (s, e) => s + e.value);
    final slices = [
      for (final entry in breakdown)
        () {
          final subject = subjectFor(entry.key);
          return SubjectDonutSlice(
            label: subject?.name ?? AppLocalizations.of(context).statsGenel,
            color: subject != null
                ? subjectColor(subject.color)
                : theme.colorScheme.onSurfaceVariant,
            seconds: entry.value,
          );
        }(),
    ];

    String valueFor(int seconds) => _showPercent
        ? '%${total == 0 ? 0 : (seconds * 100 / total).round()}'
        : formatHuman(seconds);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Veri formatı seçici: yüzde / süre.
            Align(
              alignment: Alignment.centerRight,
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: true, label: Text('%')),
                  ButtonSegment(
                    value: false,
                    label: Text(AppLocalizations.of(context).statsSure),
                  ),
                ],
                selected: {_showPercent},
                onSelectionChanged: (s) =>
                    setState(() => _showPercent = s.first),
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SubjectDonut(slices: slices, size: 132),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final s in slices)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              CircleAvatar(radius: 5, backgroundColor: s.color),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  s.label,
                                  style: theme.textTheme.bodyMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                valueFor(s.seconds),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
