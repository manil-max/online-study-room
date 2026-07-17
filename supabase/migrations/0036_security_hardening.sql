-- 0036: Güvenlik sertleştirme (WP-109 — S3 IDOR + S4 profiles enumeration)
--
-- S3: get_user_monthly_stats — authenticated yalnız kendi (veya super_admin);
--     service_role / JWT'siz (auth.uid null) edge çağrıları serbest.
-- S4: profiles_select using(true) kaldırılır; kendi satır + can_see_user_sessions
--     + super_admin. Grup üyesi listesi / chat / nudge inFilter hâlâ çalışır.
--
-- Geri alma (Rollback):
--   -- get_user_monthly_stats gövdesini 0030 haline döndür (guard'sız)
--   drop policy if exists profiles_select on public.profiles;
--   create policy profiles_select on public.profiles
--     for select to authenticated using (true);

-- ---------------------------------------------------------------------
-- S3: Aylık istatistik IDOR kapat
-- ---------------------------------------------------------------------
create or replace function public.get_user_monthly_stats(p_user_id uuid, p_month text)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_start_date date;
  v_end_date date;
  v_total_seconds int;
  v_active_days int;
  v_peak_date date;
  v_peak_seconds int;
begin
  -- JWT varsa: yalnız self veya super_admin. uid null → service_role/edge.
  if auth.uid() is not null
     and auth.uid() is distinct from p_user_id
     and not public.is_super_admin() then
    raise exception 'forbidden'
      using errcode = '42501';
  end if;

  v_start_date := (p_month || '-01')::date;
  v_end_date := (v_start_date + interval '1 month' - interval '1 day')::date;

  select
    coalesce(sum(duration_seconds), 0),
    count(distinct (start_time at time zone 'Europe/Istanbul')::date)
  into v_total_seconds, v_active_days
  from public.study_sessions
  where user_id = p_user_id
    and (start_time at time zone 'Europe/Istanbul')::date >= v_start_date
    and (start_time at time zone 'Europe/Istanbul')::date <= v_end_date;

  select (start_time at time zone 'Europe/Istanbul')::date as day_date,
         sum(duration_seconds) as sum_sec
  into v_peak_date, v_peak_seconds
  from public.study_sessions
  where user_id = p_user_id
    and (start_time at time zone 'Europe/Istanbul')::date >= v_start_date
    and (start_time at time zone 'Europe/Istanbul')::date <= v_end_date
  group by day_date
  order by sum_sec desc
  limit 1;

  return jsonb_build_object(
    'total_seconds', v_total_seconds,
    'active_days', v_active_days,
    'daily_average_seconds',
      case when v_active_days > 0 then v_total_seconds / v_active_days else 0 end,
    'peak_date', v_peak_date,
    'peak_seconds', coalesce(v_peak_seconds, 0)
  );
end;
$$;

grant execute on function public.get_user_monthly_stats(uuid, text) to authenticated;
grant execute on function public.get_user_monthly_stats(uuid, text) to service_role;

-- ---------------------------------------------------------------------
-- S4: Profil enumeration kapat
-- ---------------------------------------------------------------------
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select to authenticated
  using (
    id = auth.uid()
    or public.can_see_user_sessions(id)
    or public.is_super_admin()
  );
