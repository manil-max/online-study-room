begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(2);

-- WP-368 (V51-2): 0082 bayrağı `false` tohumladı ve hiçbir ortamda açılmadı.
-- Sonuç: `apply_global_timer_command` her komutu `global_timer_v2_disabled`
-- ile reddediyordu; istemci hatayı yuttuğu için bu "senkron çalışmıyor" olarak
-- görünüyordu. 0087 bayrağı açar; bu test kapanmayı regresyon olarak yakalar.

select is(
  (select count(*)::integer from public.global_timer_v2_runtime_config where singleton),
  1,
  'runtime config stays a single-row singleton'
);

select ok(
  (select v2_enabled from public.global_timer_v2_runtime_config where singleton),
  'global timer v2 is enabled server-side after 0087'
);

select * from finish();
rollback;
