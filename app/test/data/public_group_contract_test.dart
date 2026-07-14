import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '../supabase/migrations/0032_public_group_discovery.sql',
  ).readAsStringSync();

  test('public discovery RPC yalnız güvenli özet alanlarını döndürür', () {
    final start = migration.indexOf(
      'create or replace function public.discover_public_groups',
    );
    final end = migration.indexOf(
      'grant execute on function public.discover_public_groups',
      start,
    );
    final definition = migration.substring(start, end);

    expect(definition, contains('security definer'));
    expect(definition, contains('member_count integer'));
    expect(definition, isNot(contains('invite_code')));
    expect(definition, isNot(contains('created_by')));
    expect(definition, isNot(contains('group_members.*')));
  });

  test('public ve private katılım aynı kapasite kilidini kullanır', () {
    expect(migration, contains("default 'private'"));
    expect(migration, contains('member_limit between 2 and 100'));
    expect(migration, contains('create or replace function public.join_group'));
    expect(
      migration,
      contains('create or replace function public.join_public_group'),
    );
    expect(migration, contains('for update'));
    expect(migration, contains("if active_count >= g.member_limit then"));
  });

  test('migration mevcut groups_select RLS kuralını genişletmez', () {
    expect(migration, isNot(contains('create policy groups_select')));
    expect(migration, isNot(contains("using (visibility = 'public')")));
  });
}
