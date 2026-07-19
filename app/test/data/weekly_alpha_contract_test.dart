import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('weekly alpha is finalized-only, tie-safe, and server authoritative', () {
    final migration = File(
      '../supabase/migrations/0062_weekly_alpha_wolf.sql',
    ).readAsStringSync();

    expect(migration, startsWith('-- 0062_weekly_alpha_wolf.sql'));
    expect(migration, contains("'alpha_wolf_weekly'"));
    expect(migration, contains('iso_week_start_must_be_monday'));
    expect(migration, contains('count(*) from leaders) = 1'));
    expect(migration, contains('where finalized_at is not null'));
    expect(migration, contains('achievement_reward_candidates'));
    expect(migration, contains('_create_pending_achievement_reward'));
    expect(migration, contains("'weekly_alpha_verified_v1'"));
    expect(migration, contains('revoke all on table public.group_achievement_weekly'));
    expect(migration, contains('revoke all on function public.project_verified_group_week'));
    expect(migration, isNot(contains('study_sessions')));
  });
}
