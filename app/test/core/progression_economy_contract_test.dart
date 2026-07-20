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
      final achievements = fixture['achievements'] as Map<String, dynamic>;

      for (final entry in achievements.entries) {
        final sql = entry.key == 'alpha_wolf_weekly' ? weeklySql : economySql;
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
