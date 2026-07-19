import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    '../supabase/migrations/0053_group_achievement_metrics.sql',
  ).readAsStringSync();

  test('exact verified group context never uses session group_id', () {
    expect(sql, contains('r.group_id_snapshot=p_group_id'));
    expect(sql, contains("r.status='finalized'"));
    expect(sql, contains('s.live_run_id is null'));
  });

  test(
    'campfire >=3 sweep and locomotive 15 minute active race are explicit',
    () {
      expect(sql, contains('p.active>=3'));
      expect(sql, contains("leader.a+interval '15 minutes'"));
      expect(sql, contains('follower.a between leader.a'));
    },
  );

  test('Alpha only closed day, tie-conservative and catch-up idempotent', () {
    expect(sql, contains('group_day_not_closed'));
    expect(sql, contains('count(*) over(partition by seconds)=1'));
    expect(sql, contains('catch_up_verified_group_days'));
    expect(sql, contains("'5 21 * * *'"));
    expect(sql, contains('on conflict do nothing'));
    expect(sql, contains('as snapshot_group_id'));
    expect(sql, contains('as metric_day'));
    expect(sql, isNot(contains('::date day')));
    expect(sql, isNot(contains('r.day')));
    expect(sql, contains('candidate.metric_day'));
    expect(sql, contains('live_runs_project_group_metrics'));
    expect(sql, contains("new.status='finalized'"));
    expect(sql, contains("jobname='verified-group-day-finalizer'"));
  });

  test('legacy ambiguity is reported but cannot produce candidates', () {
    expect(sql, contains('excluded_ambiguous_group'));
    final auditStart = sql.indexOf(
      'create or replace view public.group_metric_legacy_proxy_audit',
    );
    final audit = sql.substring(auditStart);
    expect(audit, isNot(contains('achievement_reward_candidates')));
  });
}
