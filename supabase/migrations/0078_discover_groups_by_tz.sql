-- 0078_discover_groups_by_tz.sql
-- WP-328: Açık grup keşfini arayan kullanıcının güncel IANA UTC farkına göre
-- sıralar; bölge ve boş kontenjan filtrelerini güvenli özet RPC'sinde uygular.
--
-- Geri alma (Rollback): Bu fonksiyonu 0077_public_group_time_zone_summary.sql
-- içindeki üç parametreli gövdeyle yeniden kur. Veri veya RLS politikası silinmez.

drop function if exists public.discover_public_groups(text, integer, integer);

create function public.discover_public_groups(
  p_query text,
  p_time_zone text,
  p_user_time_zone text,
  p_only_with_capacity boolean,
  p_offset integer,
  p_limit integer
)
returns table (
  id uuid,
  name text,
  daily_goal_minutes integer,
  member_count integer,
  member_limit integer,
  created_at timestamptz,
  avatar_path text,
  avatar_updated_at timestamptz,
  time_zone text
)
language sql
security definer
set search_path = public
stable
as $$
  with params as (
    select
      case
        when public.is_valid_group_time_zone(p_user_time_zone)
          then trim(p_user_time_zone)
        else 'Europe/Istanbul'
      end as user_time_zone,
      nullif(trim(coalesce(p_time_zone, '')), '') as requested_time_zone,
      coalesce(p_only_with_capacity, false) as only_with_capacity
  )
  select
    g.id,
    g.name,
    g.daily_goal_minutes,
    count(m.user_id)::integer as member_count,
    g.member_limit,
    g.created_at,
    g.avatar_path,
    g.avatar_updated_at,
    g.time_zone
  from public.groups g
  cross join params
  left join public.group_members m
    on m.group_id = g.id and m.left_at is null
  where g.visibility = 'public'
    and (params.requested_time_zone is null or g.time_zone = params.requested_time_zone)
    and (
      btrim(coalesce(p_query, '')) = ''
      or position(lower(left(btrim(p_query), 64)) in lower(g.name)) > 0
    )
  group by
    g.id,
    g.name,
    g.daily_goal_minutes,
    g.member_limit,
    g.created_at,
    g.avatar_path,
    g.avatar_updated_at,
    g.time_zone,
    params.user_time_zone,
    params.only_with_capacity
  having not params.only_with_capacity or count(m.user_id) < g.member_limit
  order by
    abs(extract(epoch from (
      (now() at time zone g.time_zone) -
      (now() at time zone params.user_time_zone)
    ))) asc,
    g.created_at desc,
    g.id
  limit least(greatest(coalesce(p_limit, 20), 1), 50)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

revoke all on function public.discover_public_groups(text, text, text, boolean, integer, integer)
  from public, anon;
grant execute on function public.discover_public_groups(text, text, text, boolean, integer, integer)
  to authenticated;

-- 0077 imzasını kullanan yayımlanmış istemciler, yeni filtre/sıralama
-- sözleşmesine geçene kadar çalışmaya devam eder. PostgREST adla çözümlediği
-- için bu wrapper ile altı parametreli yeni RPC arasında belirsizlik oluşmaz.
create function public.discover_public_groups(
  p_query text default '',
  p_offset integer default 0,
  p_limit integer default 20
)
returns table (
  id uuid,
  name text,
  daily_goal_minutes integer,
  member_count integer,
  member_limit integer,
  created_at timestamptz,
  avatar_path text,
  avatar_updated_at timestamptz,
  time_zone text
)
language sql
security definer
set search_path = public
stable
as $$
  select *
  from public.discover_public_groups(
    p_query,
    null,
    'Europe/Istanbul',
    false,
    p_offset,
    p_limit
  );
$$;

revoke all on function public.discover_public_groups(text, integer, integer)
  from public, anon;
grant execute on function public.discover_public_groups(text, integer, integer)
  to authenticated;

notify pgrst, 'reload schema';
