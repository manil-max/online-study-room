-- 0129_retract_goal_completion_on_session_change.sql
--
-- Calisma kaydi silinince GUNLUK SERI geri gitmiyordu.
--
-- Sahibin cihazdaki bildirimi (2026-08-10): "denemek icin 6 saat sure ekleyip
-- sildim, gunluk seri geri alinmadi." XP/basarim/tac `0126`+`0128` ile geri
-- doner; seri donmez.
--
-- ===========================================================================
-- KOK NEDEN -- koddan, karttan degil
-- ===========================================================================
-- Seri `goal_streak_projection` (`0112:204`) ile YALNIZ
-- `goal_progress_events` satirlarindan turer; `study_sessions`'a hic bakmaz.
-- O satirlari yazan tek yol `_study_session_project_goal_completion`
-- tetikleyicisidir ve `0120:249` onu soyle baglar:
--
--     after insert or update on public.study_sessions
--
-- `delete` o listede YOK. Govdesi de yalniz `_record_goal_completion` cagirir
-- (`0120:219`, `0120:239`), yani yol MONOTON EKLEMELIdir: olay yazar, hicbir
-- kosulda silmez. Sonuc: hedefi tutturan tek oturum silindiginde
-- `goal_progress_events` satiri yerinde kalir, projeksiyon onu okumaya devam
-- eder, alev yanmaya devam eder.
--
-- `0126:232` DELETE'i dinler ama yalnizca `reconcile_user_gamification`
-- cagirir; o fonksiyon `xp_ledger` / `achievement_rewards` /
-- `user_achievements` / `achievement_metric_progress` / `gamification_profiles`
-- tablolarina dokunur -- `goal_progress_events` adi `0126`da ve `0128`de HIC
-- gecmez. Yani "kayit silinince geri alma" bu tabloyu bastan beri kapsam
-- disinda birakmisti (`0120:34-37` bunu bilerek yaptigini yaziyor).
--
-- Ayni bosluk GUNCELLEME yolunda da acik: `0120` tetikleyicisi UPDATE'te
-- caliisir ama yine yalnizca EKLER. Bir oturumun suresi kisaltildiginda ya da
-- baska bir gune tasindiginda eski gunun tamamlamasi yerinde kalir.
--
-- ===========================================================================
-- COZUM
-- ===========================================================================
-- Yazma yolunun simetrigi: `_retract_goal_completion` GERCEK oturumlardan
-- yeniden hesaplar ve gun artik hedefi tutmuyorsa olayi DUSURUR. Karar
-- "su kadar cikar" degil, `0126`daki ile ayni felsefe: gercekte ne oldugu.
--
-- Hesap DELETE oldugu icin `0124`un FK tuzagi (yaz-geri -> 23503) burada
-- olusmaz, ama maliyet gerekcesiyle silinmekte olan hesap yine de atlanir:
-- `delete from auth.users` cascade'i yuzlerce oturumu dusururken her gun ve
-- her grup icin toplam yeniden hesaplamak purge maliyetini uye sayisiyla
-- carpardi (`0120:35` ayni gerekce).
--
-- Tetikleyiciler IFADE seviyesindedir (`old table` gecis tablosu): 300 oturumu
-- tek komutla silen kullanici icin 300 kez tam hesap kosmaz. Gecis tablosu tek
-- olaya baglanabildigi icin DELETE ve UPDATE ayri iki tetikleyicidir.
--
-- Geri alma (Rollback):
--   drop trigger if exists study_sessions_retract_goal_completion_del
--     on public.study_sessions;
--   drop trigger if exists study_sessions_retract_goal_completion_upd
--     on public.study_sessions;
--   drop function if exists public._retract_goal_completions_after_delete();
--   drop function if exists public._retract_goal_completions_after_update();
--   drop function if exists public.repair_orphan_goal_completions();
--   drop function if exists public._repair_orphan_goal_completions();
--   drop function if exists public._retract_goal_days_for_session(uuid, timestamptz);
--   drop function if exists public._retract_goal_completion(text, uuid, date);

-- ---------------------------------------------------------------------
-- 1) Tek kapsam + tek gun icin geri alma karari
-- ---------------------------------------------------------------------
-- Hedef matematigi `_record_goal_completion` (`0120:56`) ile BIREBIR aynidir:
-- ayni gun siniri, ayni saat dilimi, ayni "grup toplami aktif uyelerden" kurali.
-- Iki farkli tanim yazmak, iki gun sonra birbirinden sapan iki hedef demekti.
create or replace function public._retract_goal_completion(
  p_scope_type text,
  p_scope_id uuid,
  p_day date
)
returns boolean
language plpgsql
security definer
set search_path = public
as $wp641$
declare
  v_time_zone text;
  v_goal_minutes integer;
  v_seconds bigint;
begin
  if p_scope_type is null or p_scope_id is null or p_day is null then
    return false;
  end if;

  -- Olay zaten yoksa hicbir toplam hesaplanmaz. Silme yolunun sicak yolu budur:
  -- hedefi hic tutmamis gunlerin oturumlari tek indeks okumasiyla gecer.
  if not exists (
    select 1 from public.goal_progress_events e
    where e.scope_type = p_scope_type
      and e.scope_id = p_scope_id
      and e.event_kind = 'goal_completed'
      and e.goal_day = p_day
  ) then
    return false;
  end if;

  if p_scope_type = 'personal' then
    v_time_zone := 'Europe/Istanbul';
    select daily_goal_minutes into v_goal_minutes
    from public.profiles where id = p_scope_id;
    v_seconds := public._goal_day_seconds(p_scope_id, p_day, v_time_zone);

  elsif p_scope_type = 'group' then
    select time_zone, daily_goal_minutes into v_time_zone, v_goal_minutes
    from public.groups where id = p_scope_id;
    if v_time_zone is null then
      return false;
    end if;
    select coalesce(sum(public._goal_day_seconds(gm.user_id, p_day, v_time_zone)), 0)
    into v_seconds
    from public.group_members gm
    where gm.group_id = p_scope_id
      and gm.left_at is null;

  else
    return false;
  end if;

  -- 🔴 Hedef yapilandirilmamis: gecmis bir tamamlamayi DUSURMEK icin dayanak
  -- yok. Hedefini 0 yapan kullanicinin gecmis serisini yakmayiz.
  if v_goal_minutes is null or v_goal_minutes <= 0 then
    return false;
  end if;

  -- Gun hala hedefi tutuyor: olay hak edilmis, durur.
  if v_seconds >= (v_goal_minutes::bigint * 60) then
    return false;
  end if;

  delete from public.goal_progress_events e
   where e.scope_type = p_scope_type
     and e.scope_id = p_scope_id
     and e.event_kind = 'goal_completed'
     and e.goal_day = p_day;

  return true;
end;
$wp641$;

comment on function public._retract_goal_completion(text, uuid, date) is
  'WP-641: bir kapsamin bir gunu artik hedefi tutmuyorsa tamamlama olayini '
  'dusurur. `_record_goal_completion` (0120) ile simetriktir.';

revoke all on function public._retract_goal_completion(text, uuid, date)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 2) Etkilenen (kapsam, gun) ciftlerini daraltan ortak yardimci
-- ---------------------------------------------------------------------
-- Bir oturumun baslangic damgasi kisisel kapsamda Europe/Istanbul, her grupta
-- GRUBUN kendi saat diliminde bir gune duser (`0120:211`, `0120:231`).
create or replace function public._retract_goal_days_for_session(
  p_user_id uuid,
  p_start_time timestamptz
)
returns void
language plpgsql
security definer
set search_path = public
as $wp641$
declare
  v_group record;
begin
  if p_user_id is null or p_start_time is null then
    return;
  end if;
  -- Silinmekte olan hesap: purge maliyetini uye sayisiyla carpmamak icin
  -- atlanir (baslik). Kalan satirlar hicbir ekrana ulasmaz -- hesap yok.
  if not public._account_still_exists(p_user_id) then
    return;
  end if;

  perform public._retract_goal_completion(
    'personal',
    p_user_id,
    (p_start_time at time zone 'Europe/Istanbul')::date
  );

  for v_group in
    select g.id, g.time_zone
    from public.group_members gm
    join public.groups g on g.id = gm.group_id
    where gm.user_id = p_user_id
      and gm.left_at is null
  loop
    perform public._retract_goal_completion(
      'group',
      v_group.id,
      (p_start_time at time zone v_group.time_zone)::date
    );
  end loop;
end;
$wp641$;

revoke all on function public._retract_goal_days_for_session(uuid, timestamptz)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 3) Tetikleyiciler: silme ve guncelleme
-- ---------------------------------------------------------------------
create or replace function public._retract_goal_completions_after_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $wp641$
declare
  r record;
begin
  for r in
    select distinct d.user_id, d.start_time
    from deleted_sessions d
    where d.user_id is not null and d.start_time is not null
  loop
    perform public._retract_goal_days_for_session(r.user_id, r.start_time);
  end loop;
  return null;
end;
$wp641$;

create or replace function public._retract_goal_completions_after_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $wp641$
declare
  r record;
begin
  -- Hem ESKI hem YENI gun degerlendirilir: bir oturumu baska gune tasimak eski
  -- gunu hedefin altina dusurebilir, sure kisaltmak da ayni sonucu verir.
  for r in
    select distinct user_id, start_time from (
      select o.user_id, o.start_time from old_sessions o
      union all
      select n.user_id, n.start_time from new_sessions n
    ) s
    where s.user_id is not null and s.start_time is not null
  loop
    perform public._retract_goal_days_for_session(r.user_id, r.start_time);
  end loop;
  return null;
end;
$wp641$;

drop trigger if exists study_sessions_retract_goal_completion_del
  on public.study_sessions;
create trigger study_sessions_retract_goal_completion_del
  after delete on public.study_sessions
  referencing old table as deleted_sessions
  for each statement
  execute function public._retract_goal_completions_after_delete();

drop trigger if exists study_sessions_retract_goal_completion_upd
  on public.study_sessions;
create trigger study_sessions_retract_goal_completion_upd
  after update on public.study_sessions
  referencing old table as old_sessions new table as new_sessions
  for each statement
  execute function public._retract_goal_completions_after_update();

-- ---------------------------------------------------------------------
-- 4) GECMIS: dayanaksiz kalmis olaylarin onarimi
-- ---------------------------------------------------------------------
-- Tetikleyici bugunden sonrasini kapatir. Sahibin sildigi 6 saatlik kaydin
-- birakttigi satir gibi ZATEN dayanaksiz kalmis olaylar icin ayri bir gecis
-- gerekir.
--
-- 🔴 Olcut bilerek DAR: yalniz o gunde HIC kayitli calisma kalmamis olaylar
-- dusurulur. Genis olcut ("bugunku hedefe gore yeniden degerlendir") gecmisi
-- BUGUNKU hedef degeriyle yargilardi; hedefini sonradan yukselten kullanicinin
-- gercekten hak ettigi gecmis serisi silinirdi. Sifir saniye ise hicbir hedef
-- degeri altinda tamamlama sayilmaz -- yorum gerektirmez.
-- Ic yol: yetki kapisi YOK. Goc kendi DO blogunda bunu cagirir; disaridaki
-- `repair_orphan_goal_completions` kapiyi tutar. Ayrik olmasinin sebebi somut:
-- gocu uygulayan rol ortamdan ortama degisir (`postgres` / `supabase_admin`) ve
-- kapiyi gocun icinden gecmeye calismak apply'i dusurebilirdi.
create or replace function public._repair_orphan_goal_completions()
returns integer
language plpgsql
security definer
set search_path = public
as $wp641$
declare
  v_removed integer := 0;
begin
  with orphan as (
    delete from public.goal_progress_events e
     where e.event_kind = 'goal_completed'
       and case e.scope_type
         when 'personal' then
           public._goal_day_seconds(e.scope_id, e.goal_day, e.time_zone) = 0
         when 'group' then
           coalesce((
             select sum(public._goal_day_seconds(gm.user_id, e.goal_day, e.time_zone))
             from public.group_members gm
             where gm.group_id = e.scope_id and gm.left_at is null
           ), 0) = 0
         else false
       end
    returning 1
  )
  select count(*)::integer into v_removed from orphan;

  return v_removed;
end;
$wp641$;

revoke all on function public._repair_orphan_goal_completions()
  from public, anon, authenticated;

-- Genel kapi: `0120`deki `backfill_goal_completions` ile ayni sozlesme.
create or replace function public.repair_orphan_goal_completions()
returns integer
language plpgsql
security definer
set search_path = public
as $wp641$
begin
  if auth.role() is distinct from 'service_role'
     and current_user not in ('postgres', 'service_role') then
    raise exception 'service_role_required';
  end if;
  return public._repair_orphan_goal_completions();
end;
$wp641$;

comment on function public.repair_orphan_goal_completions() is
  'WP-641: arkasinda TEK saniye calisma kalmamis tamamlama olaylarini dusurur. '
  'Dar olcut bilinclidir: gecmisi bugunku hedef degeriyle yargilamaz.';

revoke all on function public.repair_orphan_goal_completions()
  from public, anon, authenticated;
grant execute on function public.repair_orphan_goal_completions() to service_role;

-- 🔴 Onarim burada CAGRILIR. `0120:23` backfill'i bilerek cagirmiyordu cunku
-- o EKLEME yapiyor ve hatali eklemenin bedeli seri sisirmekti. Bu fonksiyon
-- yalnizca dayanaksiz satiri dusurur ve olcutu yorum icermez; ertelenmesi
-- sahibin serisini yanlis degerde birakirdi.
do $wp641$
declare
  v_removed integer;
begin
  v_removed := public._repair_orphan_goal_completions();
  raise notice 'WP-641 onarim: % dayanaksiz tamamlama olayi dusuruldu', v_removed;
end $wp641$;

notify pgrst, 'reload schema';
