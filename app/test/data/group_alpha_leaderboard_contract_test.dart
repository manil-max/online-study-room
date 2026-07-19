import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '../supabase/migrations/0061_group_alpha_leaderboard.sql',
  ).readAsStringSync();

  test('group alpha RPC is member-only and finalized-verified only', () {
    expect(migration, contains('not public.is_group_member(p_group_id)'));
    expect(migration, contains('day.finalized_at is not null'));
    expect(migration, contains('gm.left_at is null'));
    expect(migration, contains('security definer'));
  });

  test('group alpha RPC does not expose raw sessions or mint XP', () {
    expect(migration, isNot(contains('study_sessions')));
    expect(migration, isNot(contains('xp_ledger')));
    expect(
      migration,
      contains('grant execute on function public.group_alpha_scores(uuid)'),
    );
  });
}
