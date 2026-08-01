-- 0115_profile_titles.sql
-- WP-475: Ünvan sistemi — kullanıcı kazandığı bir başarımı profilinde ünvan
-- olarak seçip gösterir (kullanıcı isteği: "başarılarımızın ünvanlarından
-- birini seçebilelim, Brawl Stars'taki gibi").
--
-- Ünvan yalnız bir gösterge değildir: profilde herkese görünür bir iddiadır.
-- Bu yüzden "kazanılmış mı" kontrolü **sunucudadır** ve tek bir yerdedir.
--
-- 🔴 Doğrulama kaynağı `xp_ledger`, `user_achievements` DEĞİL. `user_achievements`
-- RLS'i istemciye kendi satırını yazma izni verir (0022:
-- "Users can insert their own achievements"); oraya bakan bir kontrol,
-- kullanıcının kendisine kazanmadığı bir ünvanı vermesine izin verirdi.
-- `xp_ledger`'a yalnız SECURITY DEFINER ödül/claim zinciri yazar ve istemcinin
-- insert/update izni yoktur (0024/0047/0057) — sunucu-otoriter tek kaynak.
--
-- 🔴 Kontrol RPC'de değil TRIGGER'da: `profiles_update` politikası (0001)
-- sahibine tüm sütunları güncelleme izni verir. Kontrol yalnız bir RPC'de
-- olsaydı istemci `.from('profiles').update(...)` ile onu atlardı. Trigger
-- her yazma yolunu kapatır.
--
-- Geri alma (Rollback):
--   drop trigger if exists profiles_title_earned_guard on public.profiles;
--   drop function if exists public.enforce_profile_title_earned();
--   alter table public.profiles drop column if exists title_achievement_id;
--   -- group_member_directory'yi 0095'teki (title_achievement_id'siz) hâline döndür.

alter table public.profiles
  add column if not exists title_achievement_id text;

-- Sözlükten kalkan bir başarım ünvanı da düşürür (ölü ünvan kalmaz).
alter table public.profiles
  drop constraint if exists profiles_title_achievement_id_fkey;
alter table public.profiles
  add constraint profiles_title_achievement_id_fkey
  foreign key (title_achievement_id)
  references public.achievements_dict (id) on delete set null;

create or replace function public.enforce_profile_title_earned()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Ünvanı kaldırmak her zaman serbest.
  if new.title_achievement_id is null then
    return new;
  end if;

  -- Değeri değişmeyen güncellemeler yeniden doğrulanmaz: aksi hâlde ilgisiz
  -- bir profil güncellemesi (ad, hedef, avatar) ünvan yüzünden düşerdi.
  if tg_op = 'UPDATE'
     and new.title_achievement_id is not distinct from old.title_achievement_id then
    return new;
  end if;

  if not exists (
    select 1
    from public.xp_ledger
    where user_id = new.id
      and achievement_id = new.title_achievement_id
  ) then
    raise exception 'title_not_earned';
  end if;

  return new;
end;
$$;

revoke all on function public.enforce_profile_title_earned()
  from public, anon, authenticated;

drop trigger if exists profiles_title_earned_guard on public.profiles;
create trigger profiles_title_earned_guard
  before insert or update of title_achievement_id on public.profiles
  for each row execute function public.enforce_profile_title_earned();

-- ---------------------------------------------------------------------
-- Üye dizini ünvanı da taşır (0095 gövdesi + tek sütun).
-- `create or replace` dönüş tipi değişince çalışmaz; önce düşürülür.
-- ---------------------------------------------------------------------
drop function if exists public.group_member_directory(uuid);

create function public.group_member_directory(p_group_id uuid)
returns table (
  id uuid,
  display_name text,
  avatar_url text,
  created_at timestamptz,
  daily_goal_minutes int,
  is_active boolean,
  animal text,
  monthly_report_opt_in boolean,
  is_blocked boolean,
  title_achievement_id text
)
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
    p.id,
    -- 🔴 Engellenen üye listeden SİLİNMEZ: satır kalır, kimlik boşalır.
    -- Kamp ateşi bu sayede kişiyi sahnede tutar, anonim gösterir ve
    -- katılımcı sayısını bozmaz.
    case when v.blocked then '' else p.display_name end as display_name,
    case when v.blocked then null else p.avatar_url end as avatar_url,
    p.created_at,
    p.daily_goal_minutes,
    (gm.left_at is null) as is_active,
    case when v.blocked then null else p.animal end as animal,
    p.monthly_report_opt_in,
    v.blocked as is_blocked,
    -- Ünvan da kimliğin parçasıdır: engellenen üyede ad/avatar gibi boşalır.
    case when v.blocked then null else p.title_achievement_id end
      as title_achievement_id
  from public.group_members gm
  join public.profiles p on p.id = gm.user_id
  cross join lateral (
    select public.is_blocked_pair(auth.uid(), gm.user_id) as blocked
  ) v
  where gm.group_id = p_group_id;
end;
$$;

revoke all on function public.group_member_directory(uuid) from public, anon;
grant execute on function public.group_member_directory(uuid) to authenticated;

comment on function public.group_member_directory(uuid) is
  'WP-413/WP-475: group roster for campfire/member list; blocked members stay in the row set but are anonymised (name/avatar/animal/title cleared, is_blocked=true) so the participant count is preserved.';

notify pgrst, 'reload schema';
