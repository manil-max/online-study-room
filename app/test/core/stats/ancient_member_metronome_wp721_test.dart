import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/achievement_ledger_engine.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/features/profile/widgets/achievement_showcase.dart';
import 'package:online_study_room/l10n/app_localizations_en.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';

/// WP-721 — "Kadim Uye" ve "Metronom".
///
/// 🔴 Metronom'un tasarim amaci: gunluk serinin (`fire_streak`) SAGLIKLI
/// alternatifi. Bir hafta icinde iki gun kacirmak zinciri KIRMAMALI. Bu dosya
/// ayni fikstur uzerinde iki motoru birden okur; fark bir iddiaya baglidir.
/// Zincir kurali gunluk seri mantiginin kopyasina donerse o iddia kirilir.

/// Istanbul saatiyle 10:00'da baslayan bir oturum (UTC+3 → 07:00Z).
StudySession _session(DateTime day, {int minutes = 60}) {
  final start = DateTime.utc(day.year, day.month, day.day, 7);
  return StudySession(
    id: 's-${day.toIso8601String()}',
    userId: 'u1',
    start: start,
    end: start.add(Duration(minutes: minutes)),
    durationSeconds: minutes * 60,
    source: StudySource.live,
  );
}

/// [weeks] hafta boyunca, her hafta pazartesiden itibaren [daysPerWeek] gun
/// hedefe ulasilan oturumlar. Kalan gunler bilerek BOS birakilir.
List<StudySession> _weekdaySessions({
  required DateTime firstMonday,
  required int weeks,
  int daysPerWeek = 5,
  Set<int> skipWeeks = const {},
}) {
  final sessions = <StudySession>[];
  for (var week = 0; week < weeks; week++) {
    final days = skipWeeks.contains(week) ? daysPerWeek - 1 : daysPerWeek;
    for (var day = 0; day < days; day++) {
      sessions.add(
        _session(
          DateTime(
            firstMonday.year,
            firstMonday.month,
            firstMonday.day + week * 7 + day,
          ),
        ),
      );
    }
  }
  return sessions;
}

void main() {
  final monday = DateTime(2026, 1, 5); // ISO pazartesi

  group('WP-721 · sozluk', () {
    test('iki basarim da 4 kademeli ve esikleri sahibin sectigi degerler', () {
      final dict = kAchievementDictV3();
      final ancient = dict.firstWhere((e) => e.id == 'ancient_member');
      final metronome = dict.firstWhere((e) => e.id == 'metronome');

      expect(ancient.maxTier, 4);
      expect(ancient.tiers.map((t) => t.threshold), [30, 100, 365, 730]);
      expect(ancient.tiers.map((t) => t.unit).toSet(), {'membership_days'});
      expect(ancient.category, 'group');
      expect(ancient.isSecret, isFalse);

      expect(metronome.maxTier, 4);
      expect(metronome.tiers.map((t) => t.threshold), [4, 12, 26, 52]);
      expect(metronome.tiers.map((t) => t.unit).toSet(), {'metronome_weeks'});
      expect(metronome.category, 'streak');
      expect(metronome.isSecret, isFalse);

      expect(
        kAchievementMetricSourceVersions['ancient_member'],
        'membership_tenure_v1',
      );
      expect(
        kAchievementMetricSourceVersions['metronome'],
        'weekly_cadence_v1',
      );
    });

    test('kosul metni iki dilde kurali soyler', () {
      final metronome = kAchievementDictV3().firstWhere(
        (e) => e.id == 'metronome',
      );
      final ancient = kAchievementDictV3().firstWhere(
        (e) => e.id == 'ancient_member',
      );

      final tr = achievementTierConditionTr(
        AppLocalizationsTr(),
        metronome,
        metronome.tiers.first,
      );
      final en = achievementTierConditionTr(
        AppLocalizationsEn(),
        metronome,
        metronome.tiers.first,
      );
      // Kural metinde yaziyor: "haftada en az 5 gun" / "at least 5 days".
      expect(tr, contains('5'));
      expect(tr, contains('4'));
      expect(en.toLowerCase(), contains('at least 5 days'));
      expect(en.toLowerCase(), contains('consecutive week'));
      expect(tr, endsWith('.'));
      expect(en, endsWith('.'));

      for (final l10n in [AppLocalizationsTr(), AppLocalizationsEn()]) {
        for (final tier in ancient.tiers) {
          final condition = achievementTierConditionTr(l10n, ancient, tier);
          expect(condition, contains('${tier.threshold}'));
          expect(condition, endsWith('.'));
          expect(condition.split(' ').length, greaterThan(3));
        }
      }
    });
  });

  group('WP-721 · Metronom zincir kurali', () {
    test(
      '🔴 hafta sonu iki gun kacirmak zinciri KIRMAZ (gunluk seri kirilir)',
      () {
        // 6 hafta boyunca pazartesi-cuma calisan, her hafta cumartesi+pazar
        // kacan kullanici.
        final sessions = _weekdaySessions(firstMonday: monday, weeks: 6);
        final metrics = AchievementLedgerEngine().computeMetrics(
          sessions: sessions,
          dailyGoalMinutes: 60,
          // 6. haftanin cumasi, 23:00 Istanbul.
          now: DateTime.utc(2026, 2, 13, 20),
        );

        // Ayni fikstur, iki motor. Fark bu WP'nin varlik sebebi:
        expect(
          metrics['streak_days'],
          5,
          reason: 'gunluk seri her hafta sonu kirilir, 5 gunde kalir',
        );
        expect(
          metrics['metronome_weeks'],
          6,
          reason:
              'Metronom ayni iki gunluk bosluga ragmen 6 hafta boyunca '
              'kesintisiz sayar — kural "haftada en az 5 gun"',
        );
      },
    );

    test('haftada 4 gune dusmek zinciri kirar; olculen sey ARDISIK haftadir', () {
      // 7 hafta: 4. hafta (indeks 3) yalniz 4 gun. Uygun hafta sayisi 6,
      // en uzun ARDISIK zincir 3.
      final sessions = _weekdaySessions(
        firstMonday: monday,
        weeks: 7,
        skipWeeks: {3},
      );
      final metrics = AchievementLedgerEngine().computeMetrics(
        sessions: sessions,
        dailyGoalMinutes: 60,
        now: DateTime.utc(2026, 2, 20, 20),
      );
      expect(metrics['metronome_weeks'], 3);
    });

    test('hedefin altinda kalan gun sayilmaz', () {
      // 5 gun calisiliyor ama gunluk hedef 120 dk; hicbir gun hedefe ulasmiyor.
      final sessions = _weekdaySessions(firstMonday: monday, weeks: 6);
      final metrics = AchievementLedgerEngine().computeMetrics(
        sessions: sessions,
        dailyGoalMinutes: 120,
        now: DateTime.utc(2026, 2, 13, 20),
      );
      expect(metrics['metronome_weeks'], 0);
    });

    test('saf fonksiyon: 5 gun yeter, 4 gun yetmez', () {
      List<DateTime> week(int offset, int days) => [
        for (var d = 0; d < days; d++)
          DateTime(monday.year, monday.month, monday.day + offset * 7 + d),
      ];

      expect(metronomeWeekChain([...week(0, 5), ...week(1, 5)]), 2);
      expect(metronomeWeekChain([...week(0, 5), ...week(1, 4)]), 1);
      // Bir hafta tamamen atlanirsa zincir kopar (5+5 / bosluk / 5).
      expect(
        metronomeWeekChain([...week(0, 5), ...week(1, 5), ...week(3, 5)]),
        2,
      );
      expect(metronomeWeekChain(const []), 0);
    });
  });

  group('WP-721 · geriye donuk hesaplama (dolu fikstur)', () {
    test('iki yildir calisan kullanici sifirdan baslamaz', () {
      // 104 hafta (2 yil) boyunca pazartesi-cuma. 2024-01-01 bir pazartesidir.
      final sessions = _weekdaySessions(
        firstMonday: DateTime(2024, 1, 1),
        weeks: 104,
      );
      final engine = AchievementLedgerEngine();
      final result = engine.processEvent(
        userId: 'legacy-user',
        eventType: 'manual_refresh',
        sessions: sessions,
        dailyGoalMinutes: 60,
        now: DateTime.utc(2025, 12, 26, 20),
      );

      expect(result.metrics['metronome_weeks'], 104);

      final metronomeTiers =
          result.awarded
              .where((award) => award.achievementId == 'metronome')
              .map((award) => award.tier)
              .toList()
            ..sort();
      expect(
        metronomeTiers,
        [1, 2, 3, 4],
        reason: 'gecmisi olan kullanici dort kademeyi de geriye donuk alir',
      );
      expect(
        result.awarded
            .where((award) => award.achievementId == 'metronome')
            .fold<int>(0, (sum, award) => sum + award.xp),
        1000 + 3000 + 8000 + 20000,
      );

      // Idempotent: ikinci tur ayni kademeleri tekrar odullendirmez.
      final second = engine.processEvent(
        userId: 'legacy-user',
        eventType: 'manual_refresh',
        sessions: sessions,
        dailyGoalMinutes: 60,
        now: DateTime.utc(2025, 12, 26, 20),
      );
      expect(
        second.awarded.where((a) => a.achievementId == 'metronome'),
        isEmpty,
      );
    });

    test('Kadim Uye yerel motorda 0 doner (uyelik verisi sunucuda)', () {
      // `alpha_wolf` ile ayni gerekce: istemci uyelik gecmisini gormez, sahte
      // ilerleme uretmemelidir.
      final engine = AchievementLedgerEngine();
      final metrics = engine.computeMetrics(
        sessions: _weekdaySessions(firstMonday: monday, weeks: 6),
        dailyGoalMinutes: 60,
        now: DateTime.utc(2026, 2, 13, 20),
      );
      expect(engine.progressForAchievement('ancient_member', metrics), 0);
      final result = engine.processEvent(
        userId: 'u1',
        eventType: 'manual_refresh',
        sessions: _weekdaySessions(firstMonday: monday, weeks: 6),
        dailyGoalMinutes: 60,
        now: DateTime.utc(2026, 2, 13, 20),
      );
      expect(
        result.awarded.where((a) => a.achievementId == 'ancient_member'),
        isEmpty,
      );
    });
  });

  group('WP-721 · mevcut katalog bozulmadi', () {
    test('21 eski basarim (12 acik + 9 gizli) esikleriyle duruyor', () {
      final dict = kAchievementDictV3();
      const legacyVisibleFirstTier = <String, int>{
        'marathon_total': 50,
        'steel_will': 60,
        'day_hero': 2,
        'fire_streak': 7,
        'weekend_goal_days': 4,
        'perfect_month': 1,
        'alpha_wolf': 7,
        'alpha_wolf_weekly': 1,
        'team_player': 10,
        'campfire_hours': 10,
        'inspiration': 5,
        'locomotive': 5,
      };
      for (final entry in legacyVisibleFirstTier.entries) {
        final achievement = dict.firstWhere((e) => e.id == entry.key);
        expect(
          achievement.tiers.first.threshold,
          entry.value,
          reason: '${entry.key} esigi degismis',
        );
        expect(achievement.maxTier, 6, reason: '${entry.key} kademe sayisi');
      }
      expect(dict.where((e) => e.isSecret).length, 9);
      expect(dict.length, legacyVisibleFirstTier.length + 9 + 2);
    });

    test('yeni metrik anahtarlari eski metrikleri ezmiyor', () {
      final metrics = AchievementLedgerEngine().computeMetrics(
        sessions: _weekdaySessions(firstMonday: monday, weeks: 6),
        dailyGoalMinutes: 60,
        now: DateTime.utc(2026, 2, 13, 20),
      );
      expect(metrics['total_hours'], 30);
      expect(metrics['max_session_minutes'], 60);
      expect(metrics['max_day_hours'], 1);
      expect(metrics['weekend_goal_days'], 0);
      expect(metrics['perfect_months'], 0);
    });
  });

  group('WP-721 · sunucu sozlesmesi (0134)', () {
    final migration = File(
      '../supabase/migrations/0134_ancient_member_and_metronome.sql',
    ).readAsStringSync();

    test('ilk satir dosya adi ve geri alma notu var', () {
      expect(
        migration,
        startsWith('-- 0134_ancient_member_and_metronome.sql'),
      );
      expect(migration, contains('Geri alma (Rollback):'));
    });

    test('kademe tuple\'lari istemci sozlugu ile birebir', () {
      for (final id in ['ancient_member', 'metronome']) {
        final achievement = kAchievementDictV3().firstWhere((e) => e.id == id);
        for (final tier in achievement.tiers) {
          expect(
            migration,
            contains(
              '"tier":${tier.tier},"threshold":${tier.threshold},'
              '"unit":"${tier.unit}","xp":${tier.xp}',
            ),
            reason: '$id kademe ${tier.tier} sunucu tuple',
          );
        }
      }
    });

    test('Metronom kurali sunucuda da "haftada en az 5 gun"', () {
      expect(migration, contains('goal_days >= 5'));
      expect(migration, contains("event_kind = 'goal_completed'"));
      expect(migration, contains("date_trunc('week', e.goal_day)"));
    });

    test('Kadim Uye tek gruptaki en uzun uyeligi olcer ve sifirlanmaz', () {
      expect(migration, contains('coalesce(gm.left_at, now()) - gm.joined_at'));
      expect(migration, contains('_ancient_member_days'));
      // Yeniden katilma karari koda gomulu: monoton yazim.
      expect(
        migration,
        contains('public.achievement_metric_progress.metric_value'),
      );
      expect(migration, contains('greatest('));
    });

    test('geri doldurma kaynak tablolari tarar ve kendini dogrular', () {
      expect(migration, contains('backfill_wp721_metrics'));
      expect(migration, contains('public.group_members gm'));
      expect(migration, contains('public.goal_progress_events e'));
      // Kendini dogrulayan goc (0127 deseni): sessizce gecmez.
      expect(migration, contains('raise exception'));
      expect(migration, contains('BASARISIZ'));
      // 🔴 0124 dersi: bos veritabaninda yesil yanan kalinti sorgusu yok.
      expect(migration, isNot(contains('metric_value is null')));
    });

    test('odul ve yetki zinciri mevcut desene uyar', () {
      expect(migration, contains('_create_pending_achievement_reward'));
      expect(
        migration,
        contains('revoke all on function public.project_wp721_metrics(uuid)'),
      );
      expect(
        migration,
        contains('revoke all on function public.backfill_wp721_metrics()'),
      );
      // Buyuk RPC'nin govdesi bu WP'de degistirilmedi.
      expect(
        migration,
        isNot(contains('create or replace function public.process_achievement_event')),
      );
    });

    test('pgTAP dolu fikstur uzerinde gercek sayi olcer', () {
      final pgtap = File(
        '../supabase/tests/061_ancient_member_metronome_wp721.test.sql',
      ).readAsStringSync();
      expect(pgtap, contains('interval \'900 days\''));
      expect(pgtap, contains('600'));
      expect(pgtap, contains('_metronome_week_chain'));
      expect(pgtap, contains('goal_streak_projection'));
      expect(pgtap, contains('backfill_wp721_metrics'));
    });
  });
}
