-- 0128_reconcile_fix_unlock_row_and_projection.sql
--
-- WP-635. `0126`in uzlastirmasi HAK EDILMIS kademeleri ekrandan sildi.
--
-- 🔴 KUSUR. `user_achievements` her basarim icin **tek satir** tutar
-- (`0022:26` unique (user_id, achievement_id)) ve o satirdaki `tier` sutunu
-- kullanicinin ERISTIGI EN YUKSEK kademedir. `0126` ise "dusen kademe" listesi
-- ile satiri `tier = <dusen kademe>` diye eslestirip **satirin tamamini
-- siliyordu**. Sahibin `steel_will` satirinda 6 yaziyordu; 5 ve 6 hak
-- edilmedigi icin listeye girdiler, satir 6 ile eslesti ve SILINDI. Defterde
-- 1-4 duruyordu ama ekranin okudugu satir yok oldu -- kullanici alti kademeyi
-- birden kaybetmis gordu.
--
-- Olculdu, tahmin degil: sahibin hesabinda `xp_ledger` `steel_will` t1..t4,
-- `day_hero` t1..t5, `marathon_total` t1 tasiyordu; ekran ise sifir kademe
-- gosteriyordu.
--
-- Dogrusu satiri SILMEK degil, kalan en yuksek kademeye DUSURMEK.
--
-- 🔴 IKINCI KUSUR: donmus "en iyi" degeri. `achievement_metric_progress`
-- `projection_kind = 'cumulative'` ile yazilir (`0050:296`), yani deger asla
-- dusmez. Silinen 8 saatlik oturumdan sonra bile ekran "Best 480" diyordu.
-- Bu kural genel olarak dogrudur ("kazanilan kazanilmistir") ama OTURUMDAN
-- TUREYEN uc olcu icin yanlistir: oradaki "en iyi" GERCEK oturumlarin en
-- iyisi olmali, silinmis bir oturumunki degil. Uzlastirma artik o uc olcuyu
-- canli degere ceker; digerlerine dokunmaz.
--
-- Geri alma: `0126`daki fonksiyon govdesini geri yaz. Onarim dongusu geri
-- alinmaz -- zaten yanlislikla silinmis satirlari yerine koyuyor.

-- ---------------------------------------------------------------------
-- 1) Uzlastirmanin duzeltilmis hali
-- ---------------------------------------------------------------------
create or replace function public.reconcile_user_gamification(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $wp635$
declare
  v_metrics jsonb;
  v_hours integer;
  v_removed_hours integer := 0;
  v_removed_tiers integer := 0;
  v_xp integer;
begin
  if not public._account_still_exists(p_user_id) then
    return jsonb_build_object('skipped', 'account_missing');
  end if;

  v_metrics := public._achievement_metrics(p_user_id);
  v_hours := coalesce((v_metrics->>'total_hours')::integer, 0);

  -- 1a) Hak edilmeyen SAAT XP'si (`0126` ile ayni).
  with removed as (
    delete from public.xp_ledger
     where user_id = p_user_id
       and achievement_id = 'study_hour_xp'
       and event_key ~ '\|h_[0-9]+$'
       and (regexp_replace(event_key, '^.*\|h_', ''))::integer > v_hours
    returning 1
  )
  select count(*) into v_removed_hours from removed;

  -- 1b) Hak edilmeyen KADEME defter/odul satirlari (`0126` ile ayni).
  with candidates as (
    select
      d.id as achievement_id,
      (t->>'tier')::integer as tier,
      (t->>'threshold')::integer as threshold,
      public._session_derived_progress(v_metrics, d.id) as progress
    from public.achievements_dict d
    cross join lateral jsonb_array_elements(d.tiers) t
    where public._session_derived_progress(v_metrics, d.id) is not null
  ),
  lost as (
    select achievement_id, tier,
           p_user_id::text || '|' || achievement_id || '|tier_' || tier::text
             as event_key
    from candidates
    where progress < threshold
  ),
  del_ledger as (
    delete from public.xp_ledger l
     using lost
     where l.user_id = p_user_id and l.event_key = lost.event_key
    returning 1
  ),
  del_rewards as (
    delete from public.achievement_rewards r
     using lost
     where r.user_id = p_user_id and r.event_key = lost.event_key
    returning 1
  )
  select (select count(*) from del_ledger) into v_removed_tiers;

  -- 1c) 🔴 KILIT DUZELTME. Kilit satiri SILINMEZ, kalan en yuksek kademeye
  -- DUSURULUR. Defterde hala kademe varsa kullanici o kademeyi hak etmis
  -- demektir ve ekranda gormeye devam etmelidir.
  update public.user_achievements ua
     set tier = sub.max_tier,
         progress = sub.max_tier,
         updated_at = now()
    from (
      select l.achievement_id, max(l.tier) as max_tier
        from public.xp_ledger l
       where l.user_id = p_user_id
         and public._session_derived_progress(v_metrics, l.achievement_id)
             is not null
       group by l.achievement_id
    ) sub
   where ua.user_id = p_user_id
     and ua.achievement_id = sub.achievement_id
     and ua.tier is distinct from sub.max_tier;

  -- Hicbir kademesi kalmayan basarimin satiri gider. Kapsam DISI basarimlarin
  -- satirina dokunulmaz -- onlarin defter satiri hic olmayabilir.
  delete from public.user_achievements ua
   where ua.user_id = p_user_id
     and public._session_derived_progress(v_metrics, ua.achievement_id)
         is not null
     and not exists (
       select 1 from public.xp_ledger l
        where l.user_id = p_user_id and l.achievement_id = ua.achievement_id
     );

  -- 1d) 🔴 "En iyi" degeri de gercege cekilir. Kumulatif kural genel olarak
  -- dogru ama oturumdan turemis olculerde "en iyi", GERCEK oturumlarin en
  -- iyisi olmali. Kapsam disi olculere dokunulmaz.
  update public.achievement_metric_progress p
     set metric_value = public._session_derived_progress(v_metrics, p.achievement_id),
         updated_at = now()
   where p.user_id = p_user_id
     and public._session_derived_progress(v_metrics, p.achievement_id) is not null
     and p.metric_value is distinct from
         public._session_derived_progress(v_metrics, p.achievement_id);

  -- 1e) Bakiyeyi defterden yeniden topla.
  select coalesce(sum(xp_amount), 0) into v_xp
    from public.xp_ledger where user_id = p_user_id;

  perform set_config('app.allow_xp_write', 'on', true);
  update public.gamification_profiles
     set xp = v_xp,
         crown_rank = public._recalc_crown_rank(v_xp),
         updated_at = now()
   where user_id = p_user_id;

  return jsonb_build_object(
    'user_id', p_user_id,
    'total_hours', v_hours,
    'removed_hour_rows', v_removed_hours,
    'removed_tier_rows', v_removed_tiers,
    'xp', v_xp,
    'crown_rank', public._recalc_crown_rank(v_xp)
  );
end;
$wp635$;

-- ---------------------------------------------------------------------
-- 2) ONARIM: `0126`nin sildigi kilit satirlarini geri koy
-- ---------------------------------------------------------------------
-- Defter satirlari duruyor, yani hangi kademelerin hak edildigi BILINIYOR.
-- Kilit satiri eksik olan her basarim icin defterdeki en yuksek kademeden
-- yeniden kurulur. Bu bir tahmin degil, turetme.
do $wp635$
declare
  v_restored integer;
begin
  insert into public.user_achievements (
    user_id, achievement_id, tier, progress, unlocked_at, updated_at
  )
  select l.user_id, l.achievement_id, max(l.tier), max(l.tier), now(), now()
    from public.xp_ledger l
   where l.achievement_id in ('steel_will', 'day_hero', 'marathon_total')
     and public._account_still_exists(l.user_id)
     and not exists (
       select 1 from public.user_achievements ua
        where ua.user_id = l.user_id and ua.achievement_id = l.achievement_id
     )
   group by l.user_id, l.achievement_id
  on conflict (user_id, achievement_id) do nothing;

  get diagnostics v_restored = row_count;
  raise notice 'WP-635 onarim: % kilit satiri geri kondu', v_restored;
end $wp635$;

-- ---------------------------------------------------------------------
-- 3) Donmus "en iyi" degerlerini gercege cek
-- ---------------------------------------------------------------------
do $wp635$
declare
  v_user uuid;
  v_count integer := 0;
  v_bad integer;
begin
  for v_user in
    select g.user_id from public.gamification_profiles g
     where public._account_still_exists(g.user_id)
     order by g.user_id
  loop
    perform public.reconcile_user_gamification(v_user);
    v_count := v_count + 1;
  end loop;
  raise notice 'WP-635: % kullanici yeniden uzlastirildi', v_count;

  -- 🔴 GOC KENDINI DOGRULAR: defterde kademesi olan hicbir basarim ekranda
  -- kayip olmamali. Kalirsa sessizce gecmeyiz.
  select count(*) into v_bad
    from (
      select l.user_id, l.achievement_id
        from public.xp_ledger l
       where l.achievement_id in ('steel_will', 'day_hero', 'marathon_total')
         and public._account_still_exists(l.user_id)
       group by l.user_id, l.achievement_id
    ) k
   where not exists (
     select 1 from public.user_achievements ua
      where ua.user_id = k.user_id and ua.achievement_id = k.achievement_id
   );

  if v_bad > 0 then
    raise exception
      'WP-635 dogrulamasi BASARISIZ: defterde kademesi olan % basarim ekranda '
      'hala kayip', v_bad;
  end if;
end $wp635$;
