-- 0061_group_alpha_leaderboard.sql
-- beta-v42 · WP-K — Grup sıralamasında verified alpha göstergesi.
--
-- Yalnız çağıranın aktif üyesi olduğu grup için, finalized verified grup-günü
-- kayıtlarından üye başına alpha toplamını döndürür. Ham oturum, başka grubun
-- metriği veya self-only achievement_metric_progress açılmaz.
--
-- Geri alma (Rollback): drop function if exists public.group_alpha_scores(uuid);

create or replace function public.group_alpha_scores(p_group_id uuid)
returns table (user_id uuid, alpha_wins bigint)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if auth.uid() is null or not public.is_group_member(p_group_id) then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  return query
  select
    gm.user_id,
    coalesce(sum(day.alpha_wins) filter (where day.finalized_at is not null), 0)::bigint
      as alpha_wins
  from public.group_members gm
  left join public.group_achievement_daily day
    on day.group_id = gm.group_id
   and day.user_id = gm.user_id
  where gm.group_id = p_group_id
    and gm.left_at is null
  group by gm.user_id
  order by alpha_wins desc, gm.user_id;
end;
$$;

revoke all on function public.group_alpha_scores(uuid) from public, anon;
grant execute on function public.group_alpha_scores(uuid) to authenticated;

comment on function public.group_alpha_scores(uuid) is
  'WP-K: active group members only; finalized verified alpha totals; no raw sessions.';
