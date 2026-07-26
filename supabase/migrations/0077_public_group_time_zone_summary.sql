-- 0077_public_group_time_zone_summary.sql
-- WP-327: Açık grup kartı yalnız güvenli özet alanları döndürür. IANA bölgesi
-- konum değildir ve katılmadan önce gün sınırını anlatmak için gerekir; davet
-- kodu, üye listesi ve oluşturucu kimliği yine hiçbir zaman bu RPC'ye girmez.
--
-- Geri alma: bu fonksiyonu 0076 öncesi imzayla yeniden kurmak yeterlidir;
-- groups.time_zone ve grup verileri silinmez.

drop function if exists public.discover_public_groups(text, integer, integer);

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
  left join public.group_members m
    on m.group_id = g.id and m.left_at is null
  where g.visibility = 'public'
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
    g.time_zone
  order by g.created_at desc, g.id
  limit least(greatest(coalesce(p_limit, 20), 1), 50)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

revoke all on function public.discover_public_groups(text, integer, integer)
  from public, anon;
grant execute on function public.discover_public_groups(text, integer, integer)
  to authenticated;

notify pgrst, 'reload schema';
