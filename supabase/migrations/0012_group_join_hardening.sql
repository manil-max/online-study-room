-- =====================================================================
-- 0012_group_join_hardening.sql — Grup katılımı güvenlik sıkılaştırması
-- Bkz. OPTIMIZATIONS.md N5 + Güvenlik denetimi (davet-kodu RLS atlatma,
-- davet kodu ifşası, atomik olmayan grup oluşturma).
--
-- SORUN (öncesi):
--   1. members_insert yalnız user_id=auth.uid() kontrol ediyordu → kullanıcı
--      davet kodunu bilmeden DOĞRUDAN herhangi bir gruba üye eklenebiliyordu.
--   2. groups_select using(true) → tüm grupların invite_code'u herkese okunur.
--   3. createGroup istemcide 2 ayrı insert → atomik değil (yetim grup riski).
--
-- ÇÖZÜM:
--   • create_group / join_group SECURITY DEFINER RPC'leri (atomik + kodu
--     sunucuda doğrular). İstemci artık groups/group_members'a DOĞRUDAN
--     insert atmaz.
--   • members_insert: doğrudan istemci insert'i tamamen kapatılır
--     (üyelik yalnız RPC'lerden gelir; DEFINER RLS'i atlar).
--   • groups_select: yalnız üye olunan grup görünür (kod ifşası biter).
--     Koda göre arama join_group RPC'si içinde (RLS'siz) yapılır.
--   • study_sessions: süre/zaman tutarlılık CHECK kısıtları (leaderboard
--     şişirmeyi zorlaştırır). NOT VALID → eski satırlar kontrol edilmez.
--
-- Çalıştırma: Supabase paneli → SQL Editor → New query → yapıştır → Run.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) Davet kodu üretici (sunucu tarafı, karışık karakterler hariç)
-- ---------------------------------------------------------------------
create or replace function public.gen_invite_code()
returns text
language plpgsql
volatile
set search_path = public
as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; -- I/L/O/0/1 yok
  code text := '';
  i int;
begin
  for i in 1..6 loop
    code := code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
  end loop;
  return code;
end;
$$;

-- ---------------------------------------------------------------------
-- 2) create_group — grubu + admin üyeliğini TEK transaction'da kurar
-- ---------------------------------------------------------------------
create or replace function public.create_group(p_name text)
returns public.groups
language plpgsql
security definer
set search_path = public
as $$
declare
  g public.groups;
  uid uuid := auth.uid();
  attempt int;
begin
  if uid is null then
    raise exception 'Oturum bulunamadı';
  end if;
  if coalesce(btrim(p_name), '') = '' then
    raise exception 'Grup adı boş olamaz.';
  end if;

  for attempt in 1..8 loop
    begin
      insert into public.groups (name, invite_code, created_by)
        values (btrim(p_name), public.gen_invite_code(), uid)
        returning * into g;

      insert into public.group_members (group_id, user_id, role)
        values (g.id, uid, 'admin');

      return g;
    exception when unique_violation then
      -- davet kodu çakıştı → tekrar dene
      continue;
    end;
  end loop;

  raise exception 'Grup oluşturulamadı, tekrar deneyin.';
end;
$$;

grant execute on function public.create_group(text) to authenticated;

-- ---------------------------------------------------------------------
-- 3) join_group — kodu sunucuda doğrular, üyeliği kurar/yeniden açar
--    Kod geçersizse NULL döner (istemci "grup bulunamadı" gösterir).
-- ---------------------------------------------------------------------
create or replace function public.join_group(p_code text)
returns public.groups
language plpgsql
security definer
set search_path = public
as $$
declare
  g public.groups;
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Oturum bulunamadı';
  end if;

  select * into g
  from public.groups
  where invite_code = upper(btrim(p_code))
  limit 1;

  if g.id is null then
    return null;  -- kod geçersiz
  end if;

  insert into public.group_members (group_id, user_id, role, joined_at, left_at)
    values (g.id, uid, 'member', now(), null)
  on conflict (group_id, user_id) do update
    set left_at = null,
        joined_at = now();
  -- not: rol çakışmada DEĞİŞTİRİLMEZ → eski admin tekrar katılırsa admin kalır

  return g;
end;
$$;

grant execute on function public.join_group(text) to authenticated;

-- ---------------------------------------------------------------------
-- 4) RLS sıkılaştırma
-- ---------------------------------------------------------------------

-- groups: artık yalnız ÜYE olunan grup görünür (davet kodu ifşası biter).
-- Koda göre arama join_group RPC'si içinde (DEFINER, RLS'siz) yapılıyor.
drop policy if exists groups_select on public.groups;
create policy groups_select on public.groups
  for select to authenticated
  using (public.is_group_member(id));

-- group_members: DOĞRUDAN istemci insert'i kapalı. Üyelik yalnız
-- create_group / join_group RPC'lerinden (SECURITY DEFINER) gelir.
drop policy if exists members_insert on public.group_members;
create policy members_insert on public.group_members
  for insert to authenticated
  with check (false);

-- ---------------------------------------------------------------------
-- 5) study_sessions bütünlük kısıtları (leaderboard şişirmeyi zorlaştırır)
--    NOT VALID: yalnız yeni/değişen satırlar denetlenir; eski veri korunur.
-- ---------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'study_sessions_time_order'
  ) then
    alter table public.study_sessions
      add constraint study_sessions_time_order
      check (end_time >= start_time) not valid;
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'study_sessions_duration_bound'
  ) then
    alter table public.study_sessions
      add constraint study_sessions_duration_bound
      check (duration_seconds <= extract(epoch from (end_time - start_time)) + 120)
      not valid;
  end if;
end
$$;
