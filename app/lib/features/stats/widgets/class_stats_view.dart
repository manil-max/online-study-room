import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/desktop/desktop_layout.dart';
import '../../../core/desktop/desktop_window.dart';
import '../../../core/stats/stats_period.dart';
import '../../../core/navigation/nav_index.dart';
import '../../../core/stats/study_stats.dart';
import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/safe_screen_padding.dart';
import '../../../core/widgets/crowned_avatar.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../data/models/daily_stat.dart';
import '../../../data/models/profile.dart';
import '../../../data/providers/analytics_query_providers.dart';
import '../../../data/providers/moderation_providers.dart';
import '../../../data/providers/stats_period_provider.dart';
import '../../classroom/widgets/class_switcher.dart';
import '../../classroom/widgets/group_avatar.dart';
import '../../profile/widgets/profile_tap.dart';
import '../analytics/analytics_period.dart';
import '../charts/gauge_chart.dart';
import 'daily_line_chart.dart';
import 'leaderboard_rank_chart.dart';
import 'member_chart_colors.dart';
import 'stat_heat_table.dart';
import 'stats_desktop_layout.dart';
import 'subject_donut.dart';
import '../stats_l10n.dart';

/// Sınıf (ortak) istatistikleri: ortak dönem + sıralama + özet.
/// Dönem üst [StatsPeriodBar] / [statsPeriodProvider] ile gelir; yerel seçici yok.
class ClassStatsView extends ConsumerStatefulWidget {
  const ClassStatsView({
    super.key,
    required this.stats,
    required this.members,
    required this.currentUserId,
    required this.groupName,
    required this.groupGoalMinutes,
    this.groupAvatarPath,
    this.groupAvatarUpdatedAt,
  });

  /// Sınıfın per-user-per-gün toplamları (F1: ham oturum yerine sunucu agregası).
  final List<DailyStat> stats;
  final List<Profile> members;
  final String currentUserId;
  final String groupName;
  final int groupGoalMinutes;
  final String? groupAvatarPath;
  final DateTime? groupAvatarUpdatedAt;

  @override
  ConsumerState<ClassStatsView> createState() => _ClassStatsViewState();
}

class _ClassStatsViewState extends ConsumerState<ClassStatsView> {
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
    final stats = widget.stats;
    final members = widget.members;
    final currentUserId = widget.currentUserId;
    final groupName = widget.groupName;
    final groupGoalMinutes = widget.groupGoalMinutes;
    final groupAvatarPath = widget.groupAvatarPath;
    final groupAvatarUpdatedAt = widget.groupAvatarUpdatedAt;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final sel = ref.watch(statsPeriodProvider);
    final period = sel.period;
    final (from, to) = sel.range(now: now);
    final analyticsPeriod = analyticsPeriodFromSelection(sel);
    final contribAsync = ref.watch(
      analyticsGroupContributionProvider(analyticsPeriod),
    );
    final alphaWins =
        ref.watch(groupAlphaScoresProvider).value ?? const <String, int>{};
    // WP-627: grafik renkleri artık zeminin fonksiyonu. Kart yüzeyi geçilir;
    // sabit açıklık açık temada üyelerin yarısını görünmez yapıyordu.
    final memberColors = memberChartColors(
      members.map((member) => member.id),
      surface: theme.colorScheme.surface,
    );
    // WP-495B: sunucu roster satırında kimliği zaten boşaltıyor (0095/0115);
    // istemci kümesi ikinci kat. Bkz. docs/qa/V58-ASYNC-EMPTY-AUDIT.md §6.
    final blocked = ref.watch(blockedUserIdsProvider).value ?? const <String>{};

    // Seçili dönem leaderboard'u: userId → saniye (per-user-per-gün toplamdan).
    final totals = userTotalsInRange(stats, from, to);
    final rows = [
      for (final m in members) (member: m, seconds: totals[m.id] ?? 0),
    ]..sort((a, b) => b.seconds.compareTo(a.seconds));

    final classTotal = totals.values.fold<int>(0, (s, v) => s + v);
    final memberCount = members.isEmpty ? 1 : members.length;
    final classAvg = classTotal ~/ memberCount;
    final maxSeconds = rows.isEmpty ? 0 : rows.first.seconds;
    // Üst dönem → bar/çizgi penceresi (7 veya 30; yerelde ayrı seçici yok).
    final chartDays = period.chartDays(options: const [7, 14, 30]);
    final trendDays =
        period == StatsPeriod.month ||
            period == StatsPeriod.year ||
            period == StatsPeriod.all ||
            period == StatsPeriod.custom
        ? 30
        : chartDays;
    // WP-253: Sıralama satırından üye serisi rozeti kaldırıldı. Ateş ikonu
    // uygulamanın her yerinde "hedef tutturma serisi" demek (sayaç kartı,
    // grup hedefi başlığı); burada ise `studyStreak` = "üst üste en az 1 sn
    // çalışılan gün" idi — aynı ikon iki farklı metriği anlatıyordu. Grup
    // tarafında hedef serisi hesaplanamaz (herkesin günlük hedefi bilinmez,
    // gerekçe `study_stats.dart:245-246`), o yüzden rozet düzeltilmedi,
    // kaldırıldı.
    // Renk-kodlu karşılaştırma tablosu: üye × [Bugün, Hafta, Ay].
    final todayTotals = userTotalsInRange(stats, dayOf(now), now);
    final weekTotals = userTotalsInRange(stats, startOfWeek(now), now);
    final monthTotals = userTotalsInRange(stats, startOfMonth(now), now);
    final heatRows = [
      for (final m in members)
        HeatRow(
          label: !m.isActive
              ? AppLocalizations.of(context).statsEskiGrupUyesi
              : (m.displayName.isEmpty
                    ? AppLocalizations.of(context).statsIsimsiz
                    : m.displayName),
          avatarUrl: m.avatarUrl,
          userId: m.id,
          highlight: m.id == currentUserId,
          values: [
            todayTotals[m.id] ?? 0,
            weekTotals[m.id] ?? 0,
            monthTotals[m.id] ?? 0,
          ],
        ),
    ]..sort((a, b) => b.values[2].compareTo(a.values[2]));

    // Grup günlük hedefi: bugünkü grup toplamı + gruba göre seri.
    final goalSeconds = groupGoalMinutes * 60;
    final groupDay = groupDayTotals(stats);
    final todayGroupTotal = groupDay[dayOf(now)] ?? 0;
    // WP-204: gauge yanı özeti — bugünün en çok katkı veren üyesi.
    final nameById = {for (final m in members) m.id: m.displayName};
    MapEntry<String, int>? topTodayEntry;
    for (final e in todayTotals.entries) {
      if (e.value <= 0) continue;
      if (topTodayEntry == null || e.value > topTodayEntry.value) {
        topTodayEntry = e;
      }
    }
    final topTodaySeconds = topTodayEntry?.value ?? 0;
    final String? topTodayName = topTodayEntry == null
        ? null
        : ((nameById[topTodayEntry.key] ?? '').isEmpty
              ? AppLocalizations.of(context).statsIsimsiz
              : nameById[topTodayEntry.key]);

    // Tüm-zamanlar metrikleri (§WP-10) — dönem seçiminden bağımsız.
    final allTimeTotal = totalOfDayTotals(groupDay);
    final activeDays = activeDayCount(groupDay);
    final peak = peakDay(groupDay);
    // 🔴 WP-637: grup rekor serisi de HEDEF serisidir. Grup tarafında "hedef"
    // grubun günlük hedefidir (gauge ile aynı `goalSeconds`): grup toplamı o
    // gün grup hedefini tutturduysa gün seriye girer.
    final recordStreak = longestStudyStreak(
      const [],
      totals: groupDay,
      goalSeconds: goalSeconds,
    );
    // En istikrarlı üye: en uzun günlük HEDEF serisi. WP-253 "herkesin günlük
    // hedefi bilinmez" diyordu; artık biliniyor — `group_member_directory`
    // (0115) satırı `daily_goal_minutes` taşıyor, yani her üye KENDİ hedefiyle
    // ölçülür. Grup hedefini tek üyeye uygulamak üçüncü bir yanlış metrik
    // olurdu (bir kişi tek başına grup hedefini nadiren tutturur).
    String? consistentName;
    var consistentStreak = 0;
    for (final m in members) {
      final st = longestStudyStreak(
        const [],
        totals: userDayTotals(stats, m.id),
        goalSeconds: m.dailyGoalMinutes * 60,
      );
      if (st > consistentStreak) {
        consistentStreak = st;
        consistentName = !m.isActive
            ? AppLocalizations.of(context).statsEskiGrupUyesi
            : (m.displayName.isEmpty
                  ? AppLocalizations.of(context).statsIsimsiz
                  : m.displayName);
      }
    }

    // ======================= WP-680 — MASAUSTU (SPEC §3 A2) ==================
    //
    // 🔴 OLCUM (bu WP'nin testi, `devicePixelRatio = 1`, SPEC §2.3 1440 px
    // bandinin ICINDE): duzeltme oncesi grup sekmesi 1920 px ve 2560 px
    // pencerede AYNI seyi ciziyordu — **tek sutun, en genis kart 1408 px**.
    // Yani 1440'lik bant zaten uygulaniyordu ama bant ICINDE hicbir sutun
    // karari yoktu: iki sayi yan yana, geri kalan her sey alt alta 1408 px'lik
    // seritler halinde. Ayni kusurun kisisel sekmedeki hali WP-673'te olculdu
    // (1888 px); bu sekme o turda BILEREK disarida birakilmisti (dosya CRLF,
    // digerleri LF).
    //
    // Cozum kisisel sekmeyle AYNI araclardir ([StatsTileGrid] /
    // [StatsSectionColumns], `stats_desktop_layout.dart`): sutun sayisi
    // pencere sinifindan, kart genisligi icerik tavanindan gelir. Hicbir
    // metrik, grafik ya da satir kaldirilmadi — yalniz yerleri degisti
    // (SPEC §7). Mobil dal asagida BIREBIR eski hâlinde durur.
    final header =
    // Grup başlığı + grup değiştirici (yalnızca geçiş, basılan yerde açılır).
    Row(
      children: [
        GroupAvatar(
          name: groupName,
          avatarPath: groupAvatarPath,
          avatarUpdatedAt: groupAvatarUpdatedAt,
          radius: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            groupName,
            style: theme.textTheme.titleMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Builder(
          builder: (iconContext) => TextButton.icon(
            onPressed: () =>
                showClassSwitcher(iconContext, ref, switchOnly: true),
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: Text(AppLocalizations.of(context).statsDegistir),
          ),
        ),
      ],
    );

    final periodHeading =
    Text(
      statsPeriodLabel(AppLocalizations.of(context), period),
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );

    final leaderboard = <Widget>[
    if (rows.isEmpty)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            AppLocalizations.of(context).statsBuDonemdeHenuzCalisma,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      )
    else
      for (var i = 0; i < rows.length; i++)
        _LeaderboardRow(
          rank: i + 1,
          name: blocked.contains(rows[i].member.id)
              ? AppLocalizations.of(context).safetyBlockedUserFallbackName
              : rows[i].member.displayName,
          avatarUrl: blocked.contains(rows[i].member.id)
              ? null
              : rows[i].member.avatarUrl,
          seconds: rows[i].seconds,
          maxSeconds: maxSeconds,
          alphaWins: alphaWins[rows[i].member.id] ?? 0,
          isMe: rows[i].member.id == currentUserId,
          profile:
              rows[i].member.isActive &&
                  !blocked.contains(rows[i].member.id)
              ? rows[i].member
              : null,
        ),
    ];

    final gaugeRow =
    // WP-204: gauge sola yaslı; sağdaki boşluğu bugüne dair kısa özet doldurur
    // (katılım / hedefe kalan / bugünün lideri). Önceden ortalanmış tek kart
    // iki yanda boş alan bırakıyordu.
    IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 150,
            child: _GroupGaugeCard(
              progress: goalSeconds <= 0
                  ? 0
                  : todayGroupTotal / goalSeconds,
              todaySeconds: todayGroupTotal,
              goalSeconds: goalSeconds,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _GroupTodaySummaryCard(
              participants: todayTotals.values.where((v) => v > 0).length,
              totalMembers: members.length,
              remainingSeconds: (goalSeconds - todayGroupTotal).clamp(
                0,
                1 << 30,
              ),
              goalReached:
                  goalSeconds > 0 && todayGroupTotal >= goalSeconds,
              topName: topTodayName,
              topSeconds: topTodaySeconds,
            ),
          ),
        ],
      ),
    );

    // SPEC §2.3 "Tek sayilik istatistik dosemesi": tavan 320 px. Mobilde
    // asagida yine `Row(Expanded, Expanded)` ile ikiye bolunur.
    final summaryTiles = <Widget>[
      _SummaryCard(
        label: AppLocalizations.of(context).statsGrupToplami,
        seconds: classTotal,
      ),
      _SummaryCard(
        label: AppLocalizations.of(context).statsKisiBasiOrt,
        seconds: classAvg,
      ),
    ];

    final donutCard =
    contribAsync.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      // 🔴 WP-589: bu dal BOŞ dalla (aşağıda) AYNI cümleyi kullanıyordu.
      // Sunucuya ulaşılamayınca kullanıcıya "bu dönemde henüz çalışma
      // yok" deniyordu — grubu hakkında YANLIŞ bilgi. Yasak zaten
      // yazılıydı (`home/widgets/group_card_shell.dart`), uygulanmamıştı.
      // Yenileme hedefli: `refreshAppData` bu family'yi okumaz, oraya
      // bağlanan düğme ölü olurdu.
      error: (_, _) => Card(
        child: ErrorRetryView(
          message: AppLocalizations.of(
            context,
          ).statsUyeKatkisiYuklenemedi,
          onRetry: () => ref.invalidate(
            analyticsGroupContributionProvider(analyticsPeriod),
          ),
        ),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                AppLocalizations.of(context).statsBuDonemdeHenuzCalisma,
                style: theme.textTheme.bodySmall,
              ),
            ),
          );
        }
        final nameOf = {for (final m in members) m.id: m.displayName};
        final slices = [
          for (var i = 0; i < rows.length; i++)
            SubjectDonutSlice(
              label: (nameOf[rows[i].userId] ?? '').isEmpty
                  ? AppLocalizations.of(context).statsIsimsiz
                  : nameOf[rows[i].userId]!,
              color: memberColors[rows[i].userId] ?? Colors.grey,
              seconds: rows[i].seconds,
            ),
        ];
        final contribTotal = slices.fold<int>(0, (s, e) => s + e.seconds);
        // WP-203: isim+renk legend — basılı tutmaya gerek yok.
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
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
                              CircleAvatar(
                                radius: 5,
                                backgroundColor: s.color,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  s.label,
                                  style: theme.textTheme.bodyMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                contribTotal == 0
                                    ? '—'
                                    : '%${(s.seconds * 100 / contribTotal).round()}',
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
          ),
        );
      },
    );

    final historyCard =
    Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LeaderboardRankChart(
          members: members,
          memberColors: memberColors,
          stats: stats,
          days: trendDays,
          currentUserId: currentUserId,
          emptyLabel: AppLocalizations.of(
            context,
          ).statsBuDonemdeHenuzCalisma,
          namelessLabel: AppLocalizations.of(context).statsIsimsiz,
        ),
      ),
    );

    final trendCard =
    // Grup eğilimi — master dönemle hizalı çizgi penceresi.
    Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '${AppLocalizations.of(context).statsGrupEgilimiSon30} · '
                '${AppLocalizations.of(context).statsStreakGun(trendDays.toString())} · '
                '${statsPeriodLabel(AppLocalizations.of(context), period)}',
                style: theme.textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: DailyLineChart(
                days: lastNDays(const [], trendDays, totals: groupDay),
              ),
            ),
          ],
        ),
      ),
    );

    final allTimeCard =
    _AllTimeCard(
      total: allTimeTotal,
      activeDays: activeDays,
      peak: peak,
      recordStreak: recordStreak,
      consistentName: consistentName,
      consistentStreak: consistentStreak,
    );

    final comparisonCard =
    Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: heatRows.isEmpty
            ? Text(
                AppLocalizations.of(context).statsUyeYok,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            : StatHeatTable(
                columns: [
                  AppLocalizations.of(context).statsBugun,
                  AppLocalizations.of(context).statsHafta,
                  AppLocalizations.of(context).statsAy,
                ],
                rows: heatRows,
              ),
      ),
    );

    final rankingTitle = AppLocalizations.of(context).statsSiralama;
    final donutTitle = AppLocalizations.of(context).analyticsCardMemberDonut;
    final historyTitle = AppLocalizations.of(
      context,
    ).analyticsCardLeaderboardHistory;
    final comparisonTitle = AppLocalizations.of(
      context,
    ).statsKarsilastirmaTablosu;

    if (isDesktopWindow) {
      // SPEC §4: masaustu sayfa kenar boslugu 24 (≥1440 bandi) — kisisel
      // sekmeyle ayni.
      return ListView(
        controller: _scrollController,
        padding: getSafeVerticalPadding(context, horizontal: 24),
        children: [
          // SPEC KURAL 2.2: grup adi (etiket) ile "Degistir" dugmesi (deger)
          // arasindaki mesafe sert tavan 600 px. Tavansiz hâlde dugme bandin
          // en sagina, adin ~1300 px otesine itiliyordu.
          _LabelValueBand(
            bandKey: const ValueKey(kGroupStatsHeaderKey),
            child: header,
          ),
          const SizedBox(height: 8),
          periodHeading,
          const SizedBox(height: 12),
          StatsTileGrid(tiles: summaryTiles),
          const SizedBox(height: kStatsGridGutter),
          StatsSectionColumns(
            sections: [
              StatsSection(
                title: rankingTitle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: leaderboard,
                ),
              ),
              StatsSection(child: gaugeRow),
              StatsSection(title: donutTitle, child: donutCard),
              StatsSection(title: historyTitle, child: historyCard),
              StatsSection(child: trendCard),
              StatsSection(child: allTimeCard),
              StatsSection(title: comparisonTitle, child: comparisonCard),
            ],
          ),
        ],
      );
    }

    return ListView(
      controller: _scrollController,
      padding: getSafeVerticalPadding(context),
      children: [
        header,
        const SizedBox(height: 8),
        periodHeading,
        const SizedBox(height: 12),
        // WP-191: sıralama EN ÜSTE — gauge/donut'tan önce.
        Text(rankingTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        ...leaderboard,
        const SizedBox(height: 16),
        gaugeRow,
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: summaryTiles[0]),
            const SizedBox(width: 8),
            Expanded(child: summaryTiles[1]),
          ],
        ),
        const SizedBox(height: 16),
        Text(donutTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        donutCard,
        const SizedBox(height: 16),
        Text(historyTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        historyCard,
        const SizedBox(height: 16),
        trendCard,
        const SizedBox(height: 16),
        allTimeCard,
        const SizedBox(height: 16),
        Text(comparisonTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        comparisonCard,
      ],
    );
  }
}

/// [_LabelValueBand] test tutamaklari (WP-680).
///
/// [kLabelValueBandKey] HER banda takilir; [kGroupStatsHeaderKey] yalniz grup
/// basligina. Ayni `ValueKey`in cok kez kullanilmasi guvenlidir cunku anahtar
/// `Align`in ICINDEKI kutuya takilir: iki band birbirinin KARDESI degildir,
/// dolayisiyla "Duplicate keys" hatasi olusmaz.
const String kLabelValueBandKey = 'label-value-band';
const String kGroupStatsHeaderKey = 'group-stats-header';

/// SPEC KURAL 2.2 — etiket–deger satiri sert tavani **600 px** (80 karakter,
/// WCAG 2.1 SC 1.4.8). `Expanded` / `Spacer` ile sinirsiz yayilma yasaktir:
/// etiketin solu ile degerin sagi arasindaki mesafe buyudukce goz satir basina
/// donerken satiri kaybeder (SPEC §2.2, saccade gerekcesi).
///
/// Mobilde ETKISIZ: 390 px pencerede kullanilabilir genislik 358 px, yani
/// tavan hicbir kutuyu kucultmez (WP-680 testinde olculdu).
class _LabelValueBand extends StatelessWidget {
  const _LabelValueBand({required this.child, this.bandKey});

  final Widget child;

  /// 🔴 Anahtar `Align`a DEGIL, tavani uygulayan kutuya takilir: `Align` kabini
  /// doldurur (1408 px), olculmesi gereken ise ic kutudur. Widget anahtari
  /// olarak verilseydi test 1408 px olcup yesil kalirdi.
  ///
  /// Ayrica bu band kardes olarak COK kez cizilir (siralama satirlari); sabit
  /// bir anahtar verilseydi `Column` "Duplicate keys" ile coker. Bu yuzden
  /// anahtar opsiyoneldir ve yalniz TEK ornekte (baslik) kullanilir.
  final Key? bandKey;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.topStart,
    child: ConstrainedBox(
      key: bandKey ?? const ValueKey(kLabelValueBandKey),
      constraints: const BoxConstraints(
        maxWidth: DesktopBreakpoints.maxLabelValueWidth,
      ),
      child: child,
    ),
  );
}

/// WP-191: gauge kartı — boyutu gaugenin gerçek yüksekliğine sar + alt özet.
class _GroupGaugeCard extends StatelessWidget {
  const _GroupGaugeCard({
    required this.progress,
    required this.todaySeconds,
    required this.goalSeconds,
  });

  final double progress;
  final int todaySeconds;
  final int goalSeconds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final remaining = (goalSeconds - todaySeconds).clamp(0, 1 << 30);
    final pct = (progress * 100).clamp(0, 999).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GaugeChart(
              progress: progress,
              label: l10n.homeGrupHedefi,
              size: 100,
            ),
            const SizedBox(height: 6),
            Text(
              '$pct%',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              goalSeconds <= 0
                  ? formatHuman(todaySeconds)
                  : '${formatHuman(todaySeconds)} / ${formatHuman(goalSeconds)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (goalSeconds > 0 && remaining > 0) ...[
              const SizedBox(height: 2),
              Text(
                '−${formatHuman(remaining)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// WP-204: gauge'un yanındaki boşluğu dolduran bugün-odaklı özet kartı.
class _GroupTodaySummaryCard extends StatelessWidget {
  const _GroupTodaySummaryCard({
    required this.participants,
    required this.totalMembers,
    required this.remainingSeconds,
    required this.goalReached,
    required this.topName,
    required this.topSeconds,
  });

  final int participants;
  final int totalMembers;
  final int remainingSeconds;
  final bool goalReached;
  final String? topName;
  final int topSeconds;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MiniStatRow(
              icon: Icons.groups_outlined,
              label: l10n.statsBugunKatilim,
              value: '$participants/$totalMembers',
            ),
            const SizedBox(height: 12),
            _MiniStatRow(
              icon: goalReached
                  ? Icons.check_circle_outline
                  : Icons.flag_outlined,
              label: l10n.statsHedefeKalan,
              value: goalReached
                  ? l10n.statsHedefTamam
                  : formatHuman(remainingSeconds),
            ),
            const SizedBox(height: 12),
            _MiniStatRow(
              icon: Icons.emoji_events_outlined,
              label: l10n.statsBugunLider,
              value: topName == null
                  ? '—'
                  : '$topName · ${formatHuman(topSeconds)}',
            ),
          ],
        ),
      ),
    );
  }
}

/// İkon + küçük etiket + belirgin değer (dar sütuna sığan alt-alta düzen).
class _MiniStatRow extends StatelessWidget {
  const _MiniStatRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
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
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tüm-zamanlar sınıf metrikleri kartı (§WP-10): grup geneli toplam, aktif gün
/// sayısı, en yoğun gün, grup rekor serisi ve en istikrarlı üye.
class _AllTimeCard extends StatelessWidget {
  const _AllTimeCard({
    required this.total,
    required this.activeDays,
    required this.peak,
    required this.recordStreak,
    required this.consistentName,
    required this.consistentStreak,
  });

  final int total;
  final int activeDays;
  final DayTotal? peak;
  final int recordStreak;
  final String? consistentName;
  final int consistentStreak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fire = subjectColor('chart-5');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_graph,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  AppLocalizations.of(context).statsTumZamanlar,
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: AppLocalizations.of(context).statsGrupToplami,
                    value: formatHuman(total),
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: AppLocalizations.of(context).statsAktifGun,
                    value: '$activeDays',
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: AppLocalizations.of(context).statsRekorSeri,
                    value: recordStreak > 0
                        ? AppLocalizations.of(
                            context,
                          ).statsStreakGun(recordStreak.toString())
                        : '—',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 12),
            _AllTimeRow(
              icon: Icons.event_available_outlined,
              label: AppLocalizations.of(context).statsEnYogunGun,
              value: peak == null
                  ? '—'
                  : '${DateFormat.yMd(AppLocalizations.of(context).localeName).format(peak!.day)} · '
                        '${formatHuman(peak!.seconds)}',
            ),
            const SizedBox(height: 8),
            _AllTimeRow(
              icon: Icons.local_fire_department,
              iconColor: fire,
              label: AppLocalizations.of(context).statsEnIstikrarliUye,
              value: consistentName == null || consistentStreak <= 0
                  ? '—'
                  : '$consistentName · '
                        '${AppLocalizations.of(context).statsStreakGun(consistentStreak.toString())}',
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _AllTimeRow extends StatelessWidget {
  const _AllTimeRow({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // SPEC KURAL 2.2: `Spacer()` degeri kabin en sagina atar. 1408 px'lik bir
    // kartta "En yogun gun" etiketi ile tarihi arasinda ~1300 px kaliyordu.
    return _LabelValueBand(
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: iconColor ?? theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sınıf özet kartı (toplam / ortalama).
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.seconds});

  final String label;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(formatHuman(seconds), style: theme.textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}

/// Tek bir leaderboard satırı: sıra, isim, oransal çubuk ve süre.
class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.name,
    required this.avatarUrl,
    required this.seconds,
    required this.maxSeconds,
    required this.alphaWins,
    required this.isMe,
    this.profile,
  });

  final int rank;
  final String name;
  final String? avatarUrl;
  final int seconds;
  final int maxSeconds;
  final int alphaWins;
  final bool isMe;
  final Profile? profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = maxSeconds <= 0 ? 0.0 : seconds / maxSeconds;
    final medal = switch (rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => '$rank.',
    };

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(medal, style: theme.textTheme.titleMedium),
          ),
          const SizedBox(width: 8),
          if (profile != null)
            LiveCrownedAvatar(
              userId: profile!.id,
              displayName: name,
              avatarUrl: avatarUrl,
              radius: 16,
            )
          else
            CrownedAvatar(displayName: name, avatarUrl: avatarUrl, radius: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        isMe
                            ? AppLocalizations.of(context).commonSenEtiketi(name)
                            : name,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (alphaWins > 0) ...[
                          const Text('🐺', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 2),
                          Text(
                            '$alphaWins',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          formatHuman(seconds),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    color: isMe
                        ? theme.colorScheme.primary
                        : theme.colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    // SPEC KURAL 2.2: isim (etiket) solda, sure (deger) sagda —
    // `spaceBetween` ikisini kabin iki ucuna iter. 1408 px'lik tek sutunda
    // aradaki mesafe 1300 px'i asiyordu. Band ayrica tiklama hedefini de
    // 600 px'te kapatir; oncesinde satirin gorunmez tiklama alani bandin
    // tamamiydi.
    if (profile == null) return _LabelValueBand(child: row);
    return _LabelValueBand(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => openMemberProfile(context, profile!),
        child: row,
      ),
    );
  }
}
