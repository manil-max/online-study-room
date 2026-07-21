import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/achievement_ledger_engine.dart';

void main() {
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/progression_economy_v2.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  test('tek ekonomi fixture istemci kataloğu ve taç eşikleriyle birebir', () {
    expect(fixture['schemaVersion'], 2);
    expect(fixture['crownThresholds'], kCrownXpThresholds);
    expect((fixture['coreTieredAchievementIds'] as List), hasLength(11));

    final actual = <String, dynamic>{
      for (final entry in kAchievementDictV3())
        entry.id: [
          for (final tier in entry.tiers)
            [tier.tier, tier.threshold, tier.unit, tier.xp],
        ],
    };
    expect(actual, fixture['achievements']);
    for (final removed in fixture['removedAchievementIds'] as List) {
      expect(actual, isNot(contains(removed)));
    }
  });

  test(
    'fixture tupleları uygulanan server ekonomi migrationlarında bulunur',
    () {
      final economySql = File(
        '../supabase/migrations/0056_six_tier_economy.sql',
      ).readAsStringSync();
      final weeklySql = File(
        '../supabase/migrations/0062_weekly_alpha_wolf.sql',
      ).readAsStringSync();
      // WP-255: bu 5 başarımın fiyatı 0065 ile yeniden yazıldı; tuple'ları
      // ARTIK 0056'da değil 0065'te aranmalı. Kimliği burada tutmak, ileride
      // yeniden fiyatlandırılan bir başarımın eski migration'daki eski
      // değeriyle eşleşip testi sessizce geçmesini engeller.
      final repricedSql = File(
        '../supabase/migrations/0065_reprice_core_economy.sql',
      ).readAsStringSync();
      const repricedIds = {
        'marathon_total',
        'steel_will',
        'day_hero',
        'fire_streak',
        'locomotive',
      };
      final achievements = fixture['achievements'] as Map<String, dynamic>;

      for (final entry in achievements.entries) {
        final sql = switch (entry.key) {
          'alpha_wolf_weekly' => weeklySql,
          final id when repricedIds.contains(id) => repricedSql,
          _ => economySql,
        };
        expect(sql, contains(entry.key), reason: '${entry.key} server id');
        for (final tuple in entry.value as List) {
          final values = tuple as List;
          expect(
            sql,
            contains(
              '"tier":${values[0]},"threshold":${values[1]},'
              '"unit":"${values[2]}","xp":${values[3]}',
            ),
            reason: '${entry.key} tier ${values[0]} server tuple',
          );
        }
      }
    },
  );
}
