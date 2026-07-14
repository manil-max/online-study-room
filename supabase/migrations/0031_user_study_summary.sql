-- 0031_user_study_summary.sql
-- Kişisel çalışma özetleri: ömür boyu / bu yıl / son 90 gün saniye toplamları.
-- Detay satırları istemcide sıcak pencerede tutulur; özet DB'de tek agregasyon.

create or replace function public.user_study_summary(p_user_id uuid)
returns json
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  v_caller uuid := auth.uid();
  v_lifetime bigint;
  v_year bigint;
  v_hot bigint;
  v_year_start timestamptz;
  v_hot_start timestamptz;
begin
  -- Yalnız kendi özetini oku (RLS + açık kontrol).
  if v_caller is null or v_caller <> p_user_id then
    raise exception 'not authorized';
  end if;

  v_year_start := date_trunc(
    'year',
    (now() at time zone 'Europe/Istanbul')
  ) at time zone 'Europe/Istanbul';

  v_hot_start := (
    (now() at time zone 'Europe/Istanbul')::date - 89
  )::timestamp at time zone 'Europe/Istanbul';

  select
    coalesce(sum(duration_seconds), 0),
    coalesce(
      sum(duration_seconds) filter (where start_time >= v_year_start),
      0
    ),
    coalesce(
      sum(duration_seconds) filter (where start_time >= v_hot_start),
      0
    )
  into v_lifetime, v_year, v_hot
  from public.study_sessions
  where user_id = p_user_id;

  return json_build_object(
    'lifetime_seconds', v_lifetime,
    'year_seconds', v_year,
    'hot_window_seconds', v_hot
  );
end;
$$;

grant execute on function public.user_study_summary(uuid) to authenticated;

comment on function public.user_study_summary(uuid) is
  'Kişisel çalışma özeti: lifetime / year / last-90d seconds (auth.uid = p_user_id).';
