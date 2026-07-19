import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/achievement_ledger.dart';
import '../../data/models/study_session.dart';
import 'istanbul_calendar.dart';

final tz.Location _ledgerIstanbul = () {
  tz_data.initializeTimeZones();
  return tz.getLocation('Europe/Istanbul');
}();

/// Başarım 3.0 sözlüğü (SQL seed ile birebir — in_memory / birim test).
/// Kaynak: docs/BASARIM-MIMARISI.md
List<AchievementDictEntry> kAchievementDictV3([AppLocalizations? l10n]) {
  AchievementDictEntry e(
    String id,
    String category,
    String name,
    String description,
    List<(int tier, int threshold, String unit, int xp)> tiers, {
    bool secret = false,
    String icon = 'emoji_events',
  }) {
    return AchievementDictEntry(
      id: id,
      category: category,
      name: name,
      description: description,
      maxTier: tiers.length,
      iconKey: icon,
      isSecret: secret,
      tiers: [
        for (final t in tiers)
          AchievementTierDef(tier: t.$1, threshold: t.$2, unit: t.$3, xp: t.$4),
      ],
    );
  }

  return [
    e(
      'marathon_total',
      'study',
      (l10n?.coreMaratoncu ?? 'coremaratoncu'),
      (l10n?.coreToplamCalismaSaati ?? 'coretoplamcalismasaati'),
      [
        (1, 50, 'hours', 100),
        (2, 200, 'hours', 500),
        (3, 500, 'hours', 1500),
        (4, 1000, 'hours', 5000),
        (5, 2500, 'hours', 15000),
        (6, 5000, 'hours', 45000),
      ],
      icon: 'timer',
    ),
    e(
      'steel_will',
      'study',
      (l10n?.coreCelikIrade ?? 'corecelikirade'),
      (l10n?.coreTekOturumDakika ?? 'coretekoturumdakika'),
      [
        (1, 60, 'minutes', 50),
        (2, 90, 'minutes', 100),
        (3, 120, 'minutes', 250),
        (4, 180, 'minutes', 1000),
        (5, 300, 'minutes', 5000),
        (6, 480, 'minutes', 15000),
      ],
      icon: 'self_improvement',
    ),
    e(
      'day_hero',
      'study',
      (l10n?.coreGununKahramani ?? 'coregununkahramani'),
      (l10n?.coreTekGundeSaat ?? 'coretekgundesaat'),
      [
        (1, 2, 'day_hours', 50),
        (2, 4, 'day_hours', 150),
        (3, 6, 'day_hours', 500),
        (4, 8, 'day_hours', 1500),
        (5, 10, 'day_hours', 5000),
        (6, 12, 'day_hours', 15000),
      ],
      icon: 'directions_run',
    ),
    e(
      'fire_streak',
      'streak',
      (l10n?.coreAtesHarli ?? 'coreatesharli'),
      (l10n?.coreGunlukHedefSerisi ?? 'coregunlukhedefserisi'),
      [
        (1, 7, 'streak_days', 100),
        (2, 30, 'streak_days', 2000),
        (3, 150, 'streak_days', 5000),
        (4, 365, 'streak_days', 20000),
        (5, 730, 'streak_days', 50000),
        (6, 1000, 'streak_days', 100000),
      ],
      icon: 'local_fire_department',
    ),
    e(
      'weekend_goal_days',
      'streak',
      (l10n?.coreHaftaSonuSavascisi ?? 'corehaftasonusavascisi'),
      (l10n?.coreHsHedefGun ?? 'corehshedefgun'),
      [
        (1, 4, 'weekend_goal_days', 150),
        (2, 8, 'weekend_goal_days', 450),
        (3, 20, 'weekend_goal_days', 1000),
        (4, 50, 'weekend_goal_days', 3000),
        (5, 100, 'weekend_goal_days', 10000),
        (6, 250, 'weekend_goal_days', 25000),
      ],
      icon: 'weekend',
    ),
    e(
      'perfect_month',
      'streak',
      (l10n?.coreKusursuzAy ?? 'corekusursuzay'),
      (l10n?.coreKusursuzAySayisi ?? 'corekusursuzaysayisi'),
      [
        (1, 1, 'perfect_months', 2000),
        (2, 3, 'perfect_months', 4000),
        (3, 6, 'perfect_months', 8000),
        (4, 12, 'perfect_months', 16000),
        (5, 24, 'perfect_months', 32000),
        (6, 36, 'perfect_months', 64000),
      ],
      icon: 'star',
    ),
    e(
      'alpha_wolf',
      'group',
      (l10n?.coreAlfaKurt ?? 'corealfakurt'),
      (l10n?.coreGrupGunBirincisi ?? 'coregrupgunbirincisi'),
      [
        (1, 7, 'group_day_first', 1000),
        (2, 30, 'group_day_first', 2500),
        (3, 90, 'group_day_first', 7500),
        (4, 180, 'group_day_first', 15000),
        (5, 360, 'group_day_first', 30000),
        (6, 720, 'group_day_first', 60000),
      ],
    ),
    e(
      'alpha_wolf_weekly',
      'group',
      (l10n?.coreLiderKurt ?? 'coreliderkurt'),
      (l10n?.coreHaftalikGrupBirincisi ?? 'corehaftalikgrupbirincisi'),
      [
        (1, 1, 'weekly_alpha_wins', 2500),
        (2, 4, 'weekly_alpha_wins', 6000),
        (3, 12, 'weekly_alpha_wins', 15000),
        (4, 26, 'weekly_alpha_wins', 30000),
        (5, 52, 'weekly_alpha_wins', 60000),
        (6, 104, 'weekly_alpha_wins', 120000),
      ],
      icon: 'pets',
    ),
    e(
      'team_player',
      'group',
      (l10n?.coreTakimOyuncusu ?? 'coretakimoyuncusu'),
      (l10n?.coreGrupHedefKatkisi ?? 'coregruphedefkatkisi'),
      [
        (1, 10, 'group_goal_contrib', 50),
        (2, 30, 'group_goal_contrib', 200),
        (3, 100, 'group_goal_contrib', 800),
        (4, 300, 'group_goal_contrib', 2500),
        (5, 600, 'group_goal_contrib', 8000),
        (6, 1000, 'group_goal_contrib', 20000),
      ],
      icon: 'groups',
    ),
    e(
      'campfire_hours',
      'group',
      (l10n?.coreKampAtesiEtrafinda ?? 'corekampatesietrafinda'),
      (l10n?.coreEnAz3KisiAktifkenCalis ?? 'coreenaz3kisiaktifkencalis'),
      [
        (1, 10, 'campfire_hours', 100),
        (2, 50, 'campfire_hours', 400),
        (3, 150, 'campfire_hours', 1500),
        (4, 300, 'campfire_hours', 5000),
        (5, 600, 'campfire_hours', 12000),
        (6, 1000, 'campfire_hours', 25000),
      ],
      icon: 'whatshot',
    ),
    e(
      'inspiration',
      'social',
      (l10n?.coreIlhamKaynagi ?? 'coreilhamkaynagi'),
      (l10n?.coreDurtmeDonusumu ?? 'coredurtmedonusumu'),
      [
        (1, 5, 'nudge_starts', 100),
        (2, 20, 'nudge_starts', 400),
        (3, 50, 'nudge_starts', 1200),
        (4, 150, 'nudge_starts', 4000),
        (5, 500, 'nudge_starts', 15000),
        (6, 1000, 'nudge_starts', 30000),
      ],
      icon: 'campaign',
    ),
    e(
      'locomotive',
      'social',
      (l10n?.coreLokomotif ?? 'corelokomotif'),
      (l10n?.coreIlkOturanIlham ?? 'coreilkoturanilham'),
      [
        (1, 5, 'locomotive_events', 150),
        (2, 15, 'locomotive_events', 500),
        (3, 30, 'locomotive_events', 1500),
        (4, 100, 'locomotive_events', 4500),
        (5, 300, 'locomotive_events', 15000),
        (6, 600, 'locomotive_events', 30000),
      ],
    ),
    e(
      'secret_night_owl',
      'secret',
      (l10n?.coreGeceKusu ?? 'coregecekusu'),
      (l10n?.profileGizliBasarim ?? 'secret'),
      [(1, 1, 'secret_night_owl', 2000)],
      secret: true,
      icon: 'dark_mode',
    ),
    e(
      'secret_dawn',
      'secret',
      (l10n?.coreGunDogumu ?? 'coregundogumu'),
      (l10n?.profileGizliBasarim ?? 'secret'),
      [(1, 1, 'secret_dawn', 2500)],
      secret: true,
      icon: 'wb_sunny',
    ),
    e(
      'secret_404',
      'secret',
      '404',
      (l10n?.profileGizliBasarim ?? 'secret'),
      [(1, 1, 'secret_404', 5000)],
      secret: true,
      icon: 'error_outline',
    ),
    e(
      'secret_pi',
      'secret',
      (l10n?.corePiSirri ?? 'corepisirri'),
      (l10n?.profileGizliBasarim ?? 'secret'),
      [(1, 1, 'secret_pi', 3147)],
      secret: true,
      icon: 'functions',
    ),
    e(
      'secret_break_enemy',
      'secret',
      (l10n?.coreMolaDusmani ?? 'coremoladusmani'),
      (l10n?.profileGizliBasarim ?? 'secret'),
      [(1, 1, 'secret_break_enemy', 2500)],
      secret: true,
      icon: 'block',
    ),
    e(
      'secret_last_second',
      'secret',
      (l10n?.coreSonSaniyeKurtaricisi ?? 'coresonsaniyekurtaricisi'),
      (l10n?.coreGizli ?? 'coregizli'),
      [(1, 1, 'secret_last_second', 1500)],
      secret: true,
      icon: 'hourglass_bottom',
    ),
    e(
      'secret_no_limits',
      'secret',
      (l10n?.coreSinirTanimaz ?? 'coresinirtanimaz'),
      (l10n?.profileGizliBasarim ?? 'secret'),
      [(1, 1, 'secret_no_limits', 5000)],
      secret: true,
      icon: 'trending_up',
    ),
    e(
      'secret_matrix',
      'secret',
      (l10n?.coreMatrixHatasi ?? 'corematrixhatasi'),
      (l10n?.profileGizliBasarim ?? 'secret'),
      [(1, 1, 'secret_matrix', 1111)],
      secret: true,
      icon: 'memory',
    ),
    e(
      'secret_nye',
      'secret',
      (l10n?.coreYilbasiNobeti ?? 'coreyilbasinobeti'),
      (l10n?.profileGizliBasarim ?? 'secret'),
      [(1, 1, 'secret_nye', 3000)],
      secret: true,
      icon: 'celebration',
    ),
  ];
}

/// 6 kademeli taç XP eşikleri (bronz → immortal). SQL `_recalc_crown_rank` ile aynı.
/// 0 / 20.000 / 75.000 / 200.000 / 500.000 / 1.000.000 (yeni ekonomiye ölçekli).
const List<int> kCrownXpThresholds = <int>[
  0,
  20000,
  75000,
  200000,
  500000,
  1000000,
];

/// Tamamlanan her 1 saat çalışma = 50 XP (başarım ödüllerine ek, idempotent).
/// Sunucu: `0033_study_hour_xp_50.sql` / `process_achievement_event`.
const int kStudyHourXp = 50;

/// Sistem ledger kimliği (rozet kataloğunda gösterilmez).
const String kStudyHourAchievementId = 'study_hour_xp';

/// Must match migration 0050. Later verified metric WPs replace only their own
/// source version while keeping this projection contract stable.
const Map<String, String> kAchievementMetricSourceVersions = {
  'marathon_total': 'metric_v2',
  'steel_will': 'metric_v2',
  'day_hero': 'metric_v2',
  'fire_streak': 'metric_v2',
  'weekend_goal_days': 'metric_v2',
  'perfect_month': 'perfect_month_28_v1',
  'alpha_wolf': 'group_verified_v1',
  'alpha_wolf_weekly': 'weekly_alpha_verified_v1',
  'team_player': 'metric_v2',
  'campfire_hours': 'group_verified_v1',
  'inspiration': 'metric_v2',
  'locomotive': 'group_verified_v1',
  'secret_night_owl': 'metric_v2',
  'secret_dawn': 'metric_v2',
  'secret_404': 'metric_v2',
  'secret_pi': 'metric_v2',
  'secret_break_enemy': 'break_verified_v1',
  'secret_last_second': 'metric_v2',
  'secret_no_limits': 'metric_v2',
  'secret_matrix': 'metric_v2',
  'secret_nye': 'metric_v2',
};

const Set<String> kCurrentAchievementMetrics = {'fire_streak'};

/// XP → 6 basamaklı taç rütbesi.
/// Eski rütbeler (wood_novice, platinum_scholar, ruby_master) görselde [normalize]
/// edilir; yeni yazımlar yalnız bu 6 id'yi üretir.
String crownRankForXp(int xp) {
  if (xp >= kCrownXpThresholds[5]) return 'immortal_legend';
  if (xp >= kCrownXpThresholds[4]) return 'emerald_sage';
  if (xp >= kCrownXpThresholds[3]) return 'diamond_owl';
  if (xp >= kCrownXpThresholds[2]) return 'gold_achiever';
  if (xp >= kCrownXpThresholds[1]) return 'silver_learner';
  return 'bronze_beginner';
}

String ledgerEventKey(String userId, String achievementId, int tier) =>
    '$userId|$achievementId|tier_$tier';

/// Saat XP event_key: `uid|study_hour_xp|h_12` (12. tamamlanan saat).
String studyHourEventKey(String userId, int hourIndex) =>
    '$userId|$kStudyHourAchievementId|h_$hourIndex';

tz.TZDateTime _asIstanbul(DateTime instant) =>
    tz.TZDateTime.from(instant, _ledgerIstanbul);

/// Saf metrik + ödül motoru (server RPC ile aynı kurallar; istemci XP yazmaz).
class AchievementLedgerEngine {
  AchievementLedgerEngine({
    List<AchievementDictEntry>? dictionary,
    Map<String, int> initialLedgerXp = const {},
  }) : dictionary = dictionary ?? kAchievementDictV3() {
    _ledgerXp.addAll(initialLedgerXp);
    _eventKeys.addAll(initialLedgerXp.keys);
  }

  final List<AchievementDictEntry> dictionary;

  /// Append-only defter: event_key → xp
  final Map<String, int> _ledgerXp = {};
  final Set<String> _eventKeys = {};

  int get totalXp => _ledgerXp.values.fold(0, (a, b) => a + b);

  String get crownRank => crownRankForXp(totalXp);

  Set<String> get eventKeys => Set.unmodifiable(_eventKeys);

  /// Oturum listesinden metrik üretir (Europe/Istanbul).
  Map<String, dynamic> computeMetrics({
    required List<StudySession> sessions,
    required int dailyGoalMinutes,
    DateTime? now,
  }) {
    final goalSecs = dailyGoalMinutes * 60;
    final dayTotals = <DateTime, int>{};
    var totalSeconds = 0;
    var maxSessionMinutes = 0;
    var secretNight = false;
    var secretDawn = false;
    var secret404 = false;
    var secretPi = false;
    var secretMatrix = false;
    var secretNye = false;
    var secretLastSecond = false;
    var secretNoLimits = false;
    final secretBreakEnemy = hasVerifiedBreakEnemyWindow(sessions);

    for (final s in sessions) {
      final dur = s.durationSeconds;
      if (dur <= 0) continue;
      totalSeconds += dur;
      final mins = dur ~/ 60;
      if (mins > maxSessionMinutes) maxSessionMinutes = mins;

      final startLocal = _asIstanbul(s.start);
      final endLocal = _asIstanbul(s.end);
      final day = istanbulDay(s.start);
      dayTotals[day] = (dayTotals[day] ?? 0) + dur;

      if (mins == 404) secret404 = true;
      if (mins == 194) secretPi = true;
      if (mins == 111 || mins == 222 || mins == 333 || mins == 555) {
        secretMatrix = true;
      }
      if (dur >= 7200 && startLocal.hour >= 0 && startLocal.hour < 4) {
        secretNight = true;
      }
      if (dur >= 3600 && startLocal.hour >= 5 && startLocal.hour < 7) {
        secretDawn = true;
      }
      final startMin = startLocal.hour * 60 + startLocal.minute;
      final endMin = endLocal.hour * 60 + endLocal.minute;
      final crossesNye =
          (startLocal.month == 12 &&
              startLocal.day == 31 &&
              startMin >= 23 * 60 + 50 &&
              endLocal.day != startLocal.day) ||
          (endLocal.month == 1 &&
              endLocal.day == 1 &&
              endMin <= 10 &&
              startLocal.day != endLocal.day);
      if (crossesNye) secretNye = true;

      if (endLocal.hour == 23 &&
          endLocal.minute >= 55 &&
          endLocal.minute <= 59) {
        final endDay = istanbulDay(s.end);
        if ((dayTotals[endDay] ?? 0) >= goalSecs) {
          secretLastSecond = true;
        }
      }
    }

    var maxDayHours = 0;
    var weekendGoalDays = 0;
    for (final entry in dayTotals.entries) {
      final secs = entry.value;
      final hours = secs ~/ 3600;
      if (hours > maxDayHours) maxDayHours = hours;
      if (secs >= goalSecs * 3) secretNoLimits = true;
      final wd = entry.key.weekday;
      if (secs >= goalSecs &&
          (wd == DateTime.saturday || wd == DateTime.sunday)) {
        weekendGoalDays++;
      }
    }

    final clock = now != null ? _asIstanbul(now) : istanbulNow();
    var cursor = DateTime(clock.year, clock.month, clock.day);
    if ((dayTotals[cursor] ?? 0) < goalSecs) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while ((dayTotals[cursor] ?? 0) >= goalSecs) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    final byMonth = <String, int>{};
    for (final e in dayTotals.entries) {
      if (e.value < goalSecs) continue;
      final key = '${e.key.year}-${e.key.month.toString().padLeft(2, '0')}';
      byMonth[key] = (byMonth[key] ?? 0) + 1;
    }
    // WP-D: Kusursuz Ay = takvim ayında ≥28 hedef günü (en fazla 2 kaçırma).
    final perfectMonths = byMonth.values.where((d) => d >= 28).length;

    return {
      'total_hours': totalSeconds ~/ 3600,
      'max_session_minutes': maxSessionMinutes,
      'max_day_hours': maxDayHours,
      'streak_days': streak,
      'weekend_goal_days': weekendGoalDays,
      'perfect_months': perfectMonths,
      'goal_minutes': dailyGoalMinutes,
      // Offline: sosyal metrikler oturumdan türetilmez (sunucu 0025).
      'nudge_starts': 0,
      'group_goal_contrib': sessions.isEmpty ? 0 : dayTotals.length,
      'secrets': {
        'night_owl': secretNight,
        'dawn': secretDawn,
        'm404': secret404,
        'pi': secretPi,
        'matrix': secretMatrix,
        'nye': secretNye,
        'last_second': secretLastSecond,
        'no_limits': secretNoLimits,
        'break_enemy': secretBreakEnemy,
      },
    };
  }

  int progressForAchievement(String id, Map<String, dynamic> metrics) {
    final secrets = Map<String, dynamic>.from(metrics['secrets'] as Map? ?? {});
    switch (id) {
      case 'marathon_total':
        return metrics['total_hours'] as int? ?? 0;
      case 'steel_will':
        return metrics['max_session_minutes'] as int? ?? 0;
      case 'day_hero':
        return metrics['max_day_hours'] as int? ?? 0;
      case 'fire_streak':
        return metrics['streak_days'] as int? ?? 0;
      case 'weekend_goal_days':
        return metrics['weekend_goal_days'] as int? ?? 0;
      case 'perfect_month':
        return metrics['perfect_months'] as int? ?? 0;
      case 'secret_break_enemy':
        return secrets['break_enemy'] == true ? 1 : 0;
      // WP-F: alpha_wolf / campfire_hours / locomotive **grup-verified** metriklerdir;
      // yerel motor (solo oturumlardan) hesaplayamaz. Gerçek ilerleme sunucu
      // `achievement_metric_progress` (group_verified_v1) projeksiyonundan gelir.
      // Eski kod yanlışlıkla break_enemy bayrağını okuyup demo modda sahte ödül
      // veriyordu; artık 0 döner (sunucu authoritative).
      case 'alpha_wolf':
      case 'alpha_wolf_weekly':
      case 'campfire_hours':
      case 'locomotive':
        return 0;
      case 'team_player':
        return metrics['group_goal_contrib'] as int? ?? 0;
      case 'inspiration':
        return metrics['nudge_starts'] as int? ?? 0;
      case 'secret_night_owl':
        return (secrets['night_owl'] == true) ? 1 : 0;
      case 'secret_dawn':
        return (secrets['dawn'] == true) ? 1 : 0;
      case 'secret_404':
        return (secrets['m404'] == true) ? 1 : 0;
      case 'secret_pi':
        return (secrets['pi'] == true) ? 1 : 0;
      case 'secret_matrix':
        return (secrets['matrix'] == true) ? 1 : 0;
      case 'secret_nye':
        return (secrets['nye'] == true) ? 1 : 0;
      case 'secret_last_second':
        return (secrets['last_second'] == true) ? 1 : 0;
      case 'secret_no_limits':
        return (secrets['no_limits'] == true) ? 1 : 0;
      default:
        return 0;
    }
  }

  /// event_key idempotent: aynı anahtar ikinci kez XP vermez.
  AchievementEventResult processEvent({
    required String userId,
    required String eventType,
    required List<StudySession> sessions,
    required int dailyGoalMinutes,
    DateTime? now,
  }) {
    final metrics = computeMetrics(
      sessions: sessions,
      dailyGoalMinutes: dailyGoalMinutes,
      now: now,
    );
    final awarded = <AchievementAward>[];

    for (final def in dictionary) {
      // Sistem satırları (saat XP) sözlük döngüsünde işlenmez.
      if (def.id == kStudyHourAchievementId || def.category == 'system') {
        continue;
      }
      final progress = progressForAchievement(def.id, metrics);
      for (final tier in def.tiers) {
        if (progress < tier.threshold) continue;
        final key = ledgerEventKey(userId, def.id, tier.tier);
        if (_eventKeys.contains(key)) continue;
        _eventKeys.add(key);
        _ledgerXp[key] = tier.xp;
        awarded.add(
          AchievementAward(
            achievementId: def.id,
            tier: tier.tier,
            xp: tier.xp,
            name: def.name,
            isSecret: def.isSecret,
          ),
        );
      }
    }

    // Her tamamlanan 1 saat çalışma → 10 XP (idempotent h_1..h_N).
    final hours = metrics['total_hours'] as int? ?? 0;
    for (var h = 1; h <= hours; h++) {
      final key = studyHourEventKey(userId, h);
      if (_eventKeys.contains(key)) continue;
      _eventKeys.add(key);
      _ledgerXp[key] = kStudyHourXp;
    }

    return AchievementEventResult(
      eventType: eventType,
      awarded: awarded,
      totalXp: totalXp,
      crownRank: crownRank,
      metrics: metrics,
    );
  }
}

/// Verified çalışma aralıklarının birleşiminde herhangi bir 5 saatlik kayan
/// pencere içinde en az 270 dakika odak var mı? O(n log n) sort+union ve O(n)
/// iki-pointer; çakışan session'ları iki kez saymaz.
bool hasVerifiedBreakEnemyWindow(
  List<StudySession> sessions, {
  Duration window = const Duration(hours: 5),
  Duration threshold = const Duration(minutes: 270),
}) {
  final intervals =
      sessions
          .where(
            (session) =>
                session.isVerified && session.end.isAfter(session.start),
          )
          .map((session) => (session.start.toUtc(), session.end.toUtc()))
          .toList()
        ..sort((a, b) => a.$1.compareTo(b.$1));
  if (intervals.isEmpty) return false;

  final merged = <(DateTime, DateTime)>[];
  for (final interval in intervals) {
    if (merged.isEmpty || interval.$1.isAfter(merged.last.$2)) {
      merged.add(interval);
    } else if (interval.$2.isAfter(merged.last.$2)) {
      merged[merged.length - 1] = (merged.last.$1, interval.$2);
    }
  }

  var left = 0;
  var coveredMicros = 0;
  for (var right = 0; right < merged.length; right++) {
    coveredMicros += merged[right].$2
        .difference(merged[right].$1)
        .inMicroseconds;
    final windowStart = merged[right].$2.subtract(window);
    while (left <= right && !merged[left].$2.isAfter(windowStart)) {
      coveredMicros -= merged[left].$2
          .difference(merged[left].$1)
          .inMicroseconds;
      left++;
    }
    var clipped = coveredMicros;
    if (left <= right && merged[left].$1.isBefore(windowStart)) {
      clipped -= windowStart.difference(merged[left].$1).inMicroseconds;
    }
    if (clipped >= threshold.inMicroseconds) return true;
  }
  return false;
}
