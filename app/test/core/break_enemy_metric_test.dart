import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/achievement_ledger_engine.dart';
import 'package:online_study_room/data/models/study_session.dart';

StudySession interval(
  String id,
  int startMinute,
  int endMinute, {
  bool verified = true,
}) {
  final base = DateTime.utc(2026, 7, 19);
  return StudySession(
    id: id,
    userId: 'u1',
    start: base.add(Duration(minutes: startMinute)),
    end: base.add(Duration(minutes: endMinute)),
    durationSeconds: (endMinute - startMinute) * 60,
    source: StudySource.live,
    liveRunId: verified ? 'run-$id' : null,
  );
}

void main() {
  test('tam 270 dakika / 5 saat sınırı kabul edilir', () {
    expect(hasVerifiedBreakEnemyWindow([interval('a', 0, 270)]), isTrue);
  });

  test('269 dakika ve unverified legacy reddedilir', () {
    expect(hasVerifiedBreakEnemyWindow([interval('a', 0, 269)]), isFalse);
    expect(
      hasVerifiedBreakEnemyWindow([
        interval('legacy', 0, 300, verified: false),
      ]),
      isFalse,
    );
  });

  test('çakışan segmentler union edilir ve kayan pencere kırpılır', () {
    expect(
      hasVerifiedBreakEnemyWindow([
        interval('a', 0, 180),
        interval('b', 120, 270),
        interval('c', 285, 300),
      ]),
      isTrue,
    );
    expect(
      hasVerifiedBreakEnemyWindow([
        interval('a', 0, 150),
        interval('b', 400, 550),
      ]),
      isFalse,
    );
  });

  test('SQL job bounded, pasif ve candidate idempotenttir', () {
    final sql = File(
      '../supabase/migrations/0052_break_enemy_metric.sql',
    ).readAsStringSync();
    expect(sql, contains("interval '5 hours'"));
    expect(sql, contains('v_covered >= 16200'));
    expect(sql, contains('on conflict do nothing'));
    expect(sql, contains('p_batch_limit not between 1 and 500'));
    expect(sql, contains('No job row is inserted'));
    expect(sql, isNot(contains('cron.schedule')));
  });
}
