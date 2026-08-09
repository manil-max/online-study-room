-- 0126_reconcile_gamification_on_session_delete.sql
--
-- WP-634. Calisma kaydi silinince XP / basarim / tac GERI GITMIYORDU.
--
-- Olay: proje sahibinin kardesinin sayaci gece boyu acik kaldi, sabah durdurdu,
-- ~11 saatlik sahte bir oturum yazildi. Kaydi sildi -- XP, basarim kademeleri
-- ve tac YERINDE KALDI. Teshis: `docs/analiz/WP-595-sayac-xp-teshis.md`.
--
-- Kok neden mimari: XP oturum listesinin bir FONKSIYONU degil, oturum
-- olaylarinin bir KALINTISIdir. `xp_ledger` append-only bir defterdir ve hicbir
-- silme yolu ona dokunmaz (`0024`). Bu tasarim DOGRUdur -- istemci XP'yi
-- duzeltebilseydi herkes kendine XP yazardi -- ama eksik yani vardi: kayit
-- silinince defteri kimse haberdar etmiyordu.
--
-- 🔴 COZUM "su kadar XP cikar" DEGIL. Cikarma islemi neyin ne kadar
-- eklendigini bilmeyi gerektirir ve o bilgi hicbir yerde tutulmuyor. Bunun
-- yerine GERCEK KAYITLARDAN YENIDEN HESAPLIYORUZ: kullanicinin su anki
-- oturumlarina bakip hangi saatlerin ve hangi kademelerin hala hak edildigini
-- buluyoruz, hak edilmeyenleri dusuruyoruz, bakiyeyi defterden yeniden
-- topluyoruz. Boylece sonuc "ne kadar cikardigimiza" degil "gercekte ne
-- oldugu"na bagli olur.
--
-- ===========================================================================
-- KAPSAM SINIRI -- bu bolum dikkatle okunmali
-- ===========================================================================
-- Uzlastirma YALNIZ oturumdan TUREYEN ve DUSEBILEN olculere dokunur:
--
--   * saat XP'si       (`study_hour_xp`, toplam saatten turer)
--   * `marathon_total` (toplam saat)
--   * `steel_will`     (en uzun oturum dakikasi)
--   * `day_hero`       (bir gundeki en cok saat)
--
-- 🔴 Digerlerine DOKUNULMAZ ve bu bilinclidir:
--   * `alpha_wolf`, `campfire_hours`, `locomotive`, `secret_break_enemy` --
--     `process_achievement_event` bunlarin ilerlemesini 0 olarak gecer, yani
--     baska bir yoldan verilirler. Buradan "0 < esik" diye bakip silseydik
--     GERCEKTEN kazanilmis rozetleri yok ederdik.
--   * `fire_streak`, `weekend_goal_days`, `perfect_month` -- projeksiyon
--     `0058`den beri KUMULATIF GREATEST'tir, yani deger tasarim geregi
--     dusmez. Geriye donuk seri kirmak ayri bir urun karari olurdu.
--   * gizli basarimlar -- bir kez tetiklenen olaya baglidir.
--
-- ===========================================================================
-- HESAP SILME TUZAGI
-- ===========================================================================
-- 🔴 `study_sessions` uzerine AFTER DELETE tetikleyicisi koymak, bu depoda
-- hesap silmeyi TAMAMEN bloke etmis olan hata sinifidir (`0124`, WP-549):
-- `delete from auth.users` cascade ile oturumlari silerken tetikleyici artik
-- var olmayan kullanici icin yazmaya calisir ve 23503 ile duser. Bu yuzden
-- tetikleyici `_account_still_exists` (`0124:400`) yuklemiyle susturulur --
-- ayni desen, ayni gerekce.
--
-- Ayrica tetikleyici SATIR degil IFADE seviyesindedir (`old table` gecis
-- tablosu ile): 300 oturumu tek komutla silen kullanici icin 300 kez tam
-- metrik yeniden hesabi kosmaz.
--
-- Geri alma (Rollback): tetikleyiciyi dusur
--   drop trigger if exists study_sessions_reconcile_gamification
--     on public.study_sessions;
-- Fonksiyonlar zararsizdir; cagrilmadiklarinda hicbir sey yapmazlar.
-- Dusurulmus ledger satirlari GERI GELMEZ -- zaten hak edilmemislerdi.

-- ---------------------------------------------------------------------
-- 1) Oturumdan turemis ilerleme -- TEK kaynak
-- ---------------------------------------------------------------------
-- `process_achievement_event` (`0057:79`) ayni esleme icin buyuk bir CASE
-- tasiyor. Burada yalniz OTURUMDAN TUREYEN uc tanesi tekrarlanir ve
-- esitlikleri pgTAP ile olculur (`supabase/tests/052`): uzlastirma, odul
-- verenin verecegi bir kademeyi ASLA silmemelidir.
create or replace function public._session_derived_progress(
  p_metrics jsonb,
  p_achievement_id text
)
returns integer
language sql
immutable
set search_path = pg_catalog, public
as $wp634$
  select case p_achievement_id
    when 'marathon_total' then (p_metrics->>'total_hours')::integer
    when 'steel_will' then (p_metrics->>'max_session_minutes')::integer
    when 'day_hero' then (p_metrics->>'max_day_hours')::integer
    else null
  end;
$wp634$;

comment on function public._session_derived_progress(jsonb, text) is
  'WP-634: oturumdan TUREYEN ve dusebilen olculer. NULL = bu basarim '
  'uzlastirma kapsaminda degil (dokunulmaz).';

-- ---------------------------------------------------------------------
-- 2) Uzlastirma
-- ---------------------------------------------------------------------
create or replace function public.reconcile_user_gamification(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $wp634$
declare
  v_metrics jsonb;
  v_hours integer;
  v_removed_hours integer := 0;
  v_removed_tiers integer := 0;
  v_xp integer;
begin
  -- Silinmekte olan hesap icin hicbir sey yazilmaz (bkz. baslik).
  if not public._account_still_exists(p_user_id) then
    return jsonb_build_object('skipped', 'account_missing');
  end if;

  v_metrics := public._achievement_metrics(p_user_id);
  v_hours := coalesce((v_metrics->>'total_hours')::integer, 0);

  -- 2a) Hak edilmeyen SAAT XP'si.
  --
  -- Anahtar `uid|study_hour_xp|h_N` ve `uid|study_hour_xp_v50_topup|h_N`
  -- (`0033:5,11`). N, kumulatif saat indeksidir; kullanicinin gercek toplam
  -- saati N'den kucukse o saat artik hak edilmiyor demektir.
  --
  -- 🔴 Satirin SILINMESI ayrica sunu duzeltir: anahtar serbest kalir, yani
  -- kullanici o saati GERCEKTEN calisirsa XP'yi bu kez alabilir. Satir
  -- birakilsaydi sahte gece, gercek saatleri kalici olarak yakardi.
  with removed as (
    delete from public.xp_ledger
     where user_id = p_user_id
       and achievement_id = 'study_hour_xp'
       and event_key ~ '\|h_[0-9]+$'
       and (regexp_replace(event_key, '^.*\|h_', ''))::integer > v_hours
    returning 1
  )
  select count(*) into v_removed_hours from removed;

  -- 2b) Hak edilmeyen basarim KADEMELERI (yalniz oturumdan turenler).
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
  ),
  del_unlocks as (
    delete from public.user_achievements ua
     using lost
     where ua.user_id = p_user_id
       and ua.achievement_id = lost.achievement_id
       and ua.tier = lost.tier
    returning 1
  )
  select (select count(*) from del_ledger) into v_removed_tiers;

  -- 2c) Bakiyeyi DEFTERDEN yeniden topla.
  --
  -- "Su kadar dus" demiyoruz: bakiye defterin toplamidir, o yuzden yeniden
  -- toplamak her zaman dogru cevabi verir. Tac da bakiyeden turer.
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
$wp634$;

comment on function public.reconcile_user_gamification(uuid) is
  'WP-634: kullanicinin XP/basarim/tac degerlerini GERCEK oturumlarindan '
  'yeniden hesaplar. Silinen calisma kaydinin kazanimi boylece geri doner.';

revoke all on function public.reconcile_user_gamification(uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 3) Oturum silinince kendiliginden kossun
-- ---------------------------------------------------------------------
create or replace function public._reconcile_gamification_after_session_delete()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $wp634$
declare
  v_user uuid;
begin
  for v_user in
    select distinct user_id from deleted_sessions where user_id is not null
  loop
    -- Fonksiyon kendi icinde de hesap kapisini kontrol eder; buradaki dongu
    -- yalniz ETKILENEN kullanicilari daraltir.
    perform public.reconcile_user_gamification(v_user);
  end loop;
  return null;
end;
$wp634$;

drop trigger if exists study_sessions_reconcile_gamification
  on public.study_sessions;
create trigger study_sessions_reconcile_gamification
  after delete on public.study_sessions
  referencing old table as deleted_sessions
  for each statement
  execute function public._reconcile_gamification_after_session_delete();
