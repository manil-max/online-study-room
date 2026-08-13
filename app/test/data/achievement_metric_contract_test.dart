import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '../supabase/migrations/0050_achievement_metric_contract.sql',
  ).readAsStringSync();

  test('metric progress is self-only and direct writes are revoked', () {
    expect(migration, contains('using (user_id = auth.uid())'));
    expect(
      migration,
      contains(
        'revoke insert, update, delete on public.achievement_metric_progress',
      ),
    );
    expect(migration, contains('achievement_metric_progress_self_select'));
  });

  test('30-day evaluator and grandfather-safe contract are explicit', () {
    expect(migration, contains('where goal_days >= 30'));
    expect(migration, contains("'perfect_month_30_v1'"));
    expect(migration, isNot(contains('delete from public.xp_ledger')));
    expect(migration, isNot(contains('delete from public.user_achievements')));
  });

  test('backfill, dirty bucket and bounded hour window are present', () {
    expect(migration, contains('achievement_backfill_jobs'));
    expect(migration, contains('achievement_metric_dirty'));
    expect(migration, contains('achievement_hour_watermarks'));
    expect(
      migration,
      contains('least(greatest(coalesce(p_limit, 100), 1), 100)'),
    );
    expect(migration, contains("'automatic_repair_applied', false"));
  });

  test('WP-732 fire streak is current and ledger rewards stay intact', () {
    final v70 = File(
      '../supabase/migrations/0135_v70_achievement_tiers_and_live_fire.sql',
    ).readAsStringSync();

    expect(v70, contains("source_version = 'goal_completion_current_v2'"));
    expect(v70, contains("projection_kind = 'current'"));
    expect(v70, contains("event_kind = 'goal_completed'"));
    expect(v70, contains("e.time_zone = 'Europe/Istanbul'"));
    expect(v70, contains('backfill_v70_achievement_progress'));
    expect(v70, isNot(contains('delete from public.xp_ledger')));
    expect(v70, isNot(contains('delete from public.user_achievements')));
  });
}
