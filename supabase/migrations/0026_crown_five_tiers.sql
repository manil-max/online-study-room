-- 0026: 5 kademeli taç sistemi (bronz → gümüş → altın → platin → elmas)
-- Eski 7 basamak (wood_novice … ruby_master) yeni 5 id'ye indirgenir.
-- Geri alma: 0024'teki _recalc_crown_rank tanımını geri yükle.

create or replace function public._recalc_crown_rank(p_xp integer)
returns text
language sql
immutable
as $$
  select case
    when p_xp >= 50000 then 'diamond_owl'
    when p_xp >= 15000 then 'platinum_scholar'
    when p_xp >= 5000 then 'gold_achiever'
    when p_xp >= 1000 then 'silver_learner'
    else 'bronze_beginner'
  end;
$$;

-- Mevcut profilleri yeni eşiklerle yeniden hesapla (yalnız allow bayrağı ile).
do $$
begin
  perform set_config('app.allow_xp_write', 'on', true);
  update public.gamification_profiles g
  set crown_rank = public._recalc_crown_rank(coalesce(g.xp, 0))
  where g.crown_rank is distinct from public._recalc_crown_rank(coalesce(g.xp, 0));
exception
  when undefined_table then
    null; -- gamification_profiles yoksa sessiz geç
  when others then
    -- allow bayrağı / trigger yoksa en azından fonksiyon güncel kalsın
    null;
end $$;
