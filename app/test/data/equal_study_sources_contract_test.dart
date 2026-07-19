import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('0063 tüm süre kaynaklarını eşit kazanım yoluna alır', () {
    final migration = File(
      '../supabase/migrations/0063_equal_study_sources.sql',
    ).readAsStringSync();

    expect(migration, startsWith('-- 0063_equal_study_sources.sql'));
    expect(migration, contains('set live_run_id = null'));
    expect(
      migration,
      contains('create or replace function public.project_group_day'),
    );
    expect(
      migration,
      contains('create or replace function public.project_group_week'),
    );
    expect(migration, contains('from public.study_sessions s'));
    expect(migration, contains("'group_all_sessions_v1'"));
    expect(migration, contains("'weekly_alpha_all_sessions_v1'"));
    expect(migration, contains("'break_all_sessions_v1'"));
    expect(migration, contains('group-achievement-day-finalizer'));
    expect(migration, contains('group-achievement-week-finalizer'));
    expect(migration, contains('delete from public.group_achievement_daily'));
    expect(migration, isNot(contains('delete from public.study_sessions')));
    expect(migration, isNot(contains('delete from public.xp_ledger')));
  });

  test('yeni sayaç başlangıcı verified live-run RPC akışına girmez', () {
    final provider = File(
      'lib/data/providers/study_providers.dart',
    ).readAsStringSync();
    final notice = File(
      'lib/features/classroom/widgets/timer_mode_controls.dart',
    ).readAsStringSync();

    expect(provider, contains('bool get _verifiedServerAvailable => false;'));
    expect(notice, contains('return const SizedBox.shrink();'));
  });
}
