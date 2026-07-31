// WP-453 Faz 2: seri motorunun iki ucunu birbirine bağlayan sözleşme testi.
//
// Faz 1 saf Dart durum makinesini ve `goal_streak_parity_v1.json` fixture'ını
// indirdi; Faz 2 aynı algoritmayı `0112_goal_streak_projection.sql` içine
// koydu. Bu dosya iki ucun AYRIŞMASINI imkânsız kılar:
//
//   1. Fixture'daki her vaka adının pgTAP dosyasında geçtiğini doğrular —
//      fixture'a vaka eklenip SQL tarafına eklenmezse bu test kırmızı düşer.
//   2. Dart RPC parametre adlarının migration imzasıyla birebir aynı olduğunu
//      doğrular (WP-472'de kurulan desen; orada Dart `p_interval_days`
//      gönderiyordu, SQL'de öyle bir parametre yoktu ve hiçbir test görmüyordu).
//   3. Fixture vakalarını saf Dart projection'a sürerek beklenen sonucu
//      üretir — SQL tarafındaki eşi `037`.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/goal_streak_projection.dart';
import 'package:online_study_room/data/models/goal_streak.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_goal_streak_repository.dart';

/// `create ... function name(` gövdesinden parametre adlarını çıkarır.
Set<String> _sqlParams(String sql, String functionName) {
  final start = sql.indexOf('function public.$functionName(');
  expect(start, isNot(-1), reason: '$functionName migration\'da bulunamadı');
  final open = sql.indexOf('(', start);
  var depth = 0;
  var end = open;
  for (var i = open; i < sql.length; i++) {
    if (sql[i] == '(') depth++;
    if (sql[i] == ')') {
      depth--;
      if (depth == 0) {
        end = i;
        break;
      }
    }
  }
  final body = sql.substring(open + 1, end);
  return {
    for (final raw in body.split(','))
      if (RegExp(r'^\s*(p_\w+)').firstMatch(raw) case final m?) m.group(1)!,
  };
}

void main() {
  final migration = File(
    '../supabase/migrations/0112_goal_streak_projection.sql',
  ).readAsStringSync();
  final pgtap = File(
    '../supabase/tests/037_goal_streak_projection.test.sql',
  ).readAsStringSync();
  final fixture =
      jsonDecode(
            File('test/fixtures/goal_streak_parity_v1.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  final cases = (fixture['cases'] as List).cast<Map<String, dynamic>>();

  test('fixture sürümü iki uçta da aynı', () {
    expect(fixture['version'], goalStreakProjectionSourceVersion);
    expect(
      migration,
      contains("'goal_completion_v1'"),
      reason: 'SQL projection kaynak sürümünü Dart ile aynı etiketle döner',
    );
  });

  test('her fixture vakasının pgTAP karşılığı var', () {
    expect(cases, isNotEmpty, reason: 'boş fixture bu testi anlamsız kılar');
    for (final testCase in cases) {
      final name = testCase['name'] as String;
      expect(
        pgtap,
        contains(name),
        reason:
            '$name fixture\'da var ama 037 pgTAP dosyasında yok; sözleşmenin '
            'sunucu ucu bu vakayı hiç sınamıyor',
      );
    }
  });

  test('Dart RPC parametreleri migration imzasıyla birebir', () {
    final projection = SupabaseGoalStreakRepository.projectionParams(
      scope: const GoalStreakScope.personal('user-a'),
      asOfDay: DateTime.utc(2026, 7, 5),
    );
    expect(
      projection.keys.toSet(),
      _sqlParams(migration, 'goal_streak_projection'),
    );

    final completion = SupabaseGoalStreakRepository.completionParams(
      scope: const GoalStreakScope.personal('user-a'),
      day: DateTime.utc(2026, 7, 5),
    );
    expect(
      completion.keys.toSet(),
      _sqlParams(migration, 'record_goal_completion'),
    );
    // Gün alanları tarih-only tel biçiminde gitmeli; timestamp gönderilirse
    // `date` parametresi sunucuda saat dilimine göre kayabilir.
    expect(projection['p_as_of_day'], '2026-07-05');
    expect(completion['p_day'], '2026-07-05');
  });

  test('olay yazma yolu istemciye kapalı', () {
    // Seri "uygulamayı açmakla" ilerlememeli; bunun yapısal garantisi
    // arayüzde mutasyon metodu OLMAMASI ve tabloda yazma yetkisi olmaması.
    expect(migration, contains('revoke insert, update, delete'));
    expect(migration, contains('goal_progress_events'));
    expect(
      File('lib/data/repositories/goal_streak_repository.dart')
          .readAsStringSync(),
      isNot(contains('Future<void> record')),
      reason: 'repository arayüzü seri yazma yolu açmamalı',
    );
  });

  group('fixture vakaları saf Dart projection', () {
    for (final testCase in cases) {
      test(testCase['name'] as String, () {
        final scopeType = GoalStreakScopeType.fromWire(
          testCase['scopeType'] as String,
        );
        final scope = GoalStreakScope(
          type: scopeType,
          id: testCase['scopeId'] as String,
          timeZone: testCase['timeZone'] as String,
        );
        final events = [
          for (final raw in (testCase['events'] as List).cast<Map<String, dynamic>>())
            GoalProgressEvent(
              eventKey: raw['key'] as String,
              scope: GoalStreakScope(
                type: GoalStreakScopeType.fromWire(
                  raw['scopeType'] as String? ?? testCase['scopeType'] as String,
                ),
                id: raw['scopeId'] as String? ?? testCase['scopeId'] as String,
                timeZone:
                    raw['timeZone'] as String? ?? testCase['timeZone'] as String,
              ),
              kind: GoalProgressEventKind.fromWire(raw['kind'] as String),
              goalDay: DateTime.parse(raw['day'] as String),
              occurredAt: DateTime.parse('${raw['day']}T12:00:00Z'),
            ),
        ];

        final projection = projectGoalStreak(
          scope: scope,
          events: events,
          asOfDay: DateTime.parse(testCase['asOfDay'] as String),
        );
        final expected = testCase['expected'] as Map<String, dynamic>;
        expect(projection.currentStreak, expected['streak']);
        expect(projection.completionCount, expected['count']);
        expect(projection.state.wireValue, expected['state']);
      });
    }
  });
}
