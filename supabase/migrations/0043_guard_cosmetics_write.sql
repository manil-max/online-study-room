--0043_guard_cosmetics_write.sql
-- cosmetics istemci yazımını engelle (WP-166)
--
-- Bulgu: 0042 cosmetics kolonu eklendi; _guard_gamification_xp_write yalnız
-- xp/crown_rank koruyor. authenticated UPDATE policy user_id=auth.uid() ile
-- cosmetics'i serbest yazabilirdi.
--
-- İşleyiş: mevcut trigger fonksiyonuna cosmetics koruması eklenir (CREATE OR REPLACE).
-- app.allow_xp_write='on' (DEFINER ledger) dışında cosmetics eski değerde kalır.
--
-- Geri alma: 0024'teki _guard_gamification_xp_write gövdesini yeniden uygula
-- (cosmetics satırları olmadan) — veya bu dosyanın tersi.

create or replace function public._guard_gamification_xp_write()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  -- app.allow_xp_write = 'on' yalnız SECURITY DEFINER fonksiyonlar tarafından set edilir
  if current_setting('app.allow_xp_write', true) is distinct from 'on' then
    if tg_op = 'UPDATE' then
      new.xp := old.xp;
      new.crown_rank := old.crown_rank;
      -- WP-166: kozmetik de server/DEFINER dışında değişmesin
      if to_jsonb(new) ? 'cosmetics' and to_jsonb(old) ? 'cosmetics' then
        new.cosmetics := old.cosmetics;
      end if;
    elsif tg_op = 'INSERT' then
      new.xp := coalesce(new.xp, 0);
      if new.xp <> 0 then
        new.xp := 0;
      end if;
      new.crown_rank := coalesce(new.crown_rank, 'wood_novice');
      if new.crown_rank is distinct from 'wood_novice' and new.xp = 0 then
        new.crown_rank := 'wood_novice';
      end if;
      if to_jsonb(new) ? 'cosmetics' then
        new.cosmetics := coalesce(new.cosmetics, '{}'::jsonb);
        -- İstemci INSERT ile dolu cosmetics basamasın
        if new.cosmetics is distinct from '{}'::jsonb then
          new.cosmetics := '{}'::jsonb;
        end if;
      end if;
    end if;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

comment on function public._guard_gamification_xp_write() is
  'WP-166: blocks client writes to xp, crown_rank, and cosmetics unless app.allow_xp_write=on';
