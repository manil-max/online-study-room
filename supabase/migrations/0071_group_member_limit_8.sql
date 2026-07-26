-- 0071_group_member_limit_8.sql
-- Sahip kararı (2026-07-26): grup üye sınırı **8**. "Fazlası çok geliyor."
-- Önceki hâli: varsayılan 50, kısıt 2..100 (0032_public_group_discovery.sql).
--
-- Sıra önemli: önce güvenlik kontrolü → sonra mevcut satırlar → sonra kısıt.
-- Kısıt en sona kalmalı, yoksa 50'li mevcut satırlar yüzünden migration düşer.
--
-- GERİ ALMA:
--   alter table public.groups drop constraint groups_member_limit_check;
--   alter table public.groups add constraint groups_member_limit_check
--     check (member_limit between 2 and 100);
--   alter table public.groups alter column member_limit set default 50;
--   (create_group_with_access'i 0032'deki hâliyle yeniden oluştur)
--   Not: 50'ye çekilmiş satırlar geri gelmez; sınırın kendisi veri değil politika.

-- 1) Güvenlik kontrolü. `guard_group_member_limit` zaten sınırı aktif üye
--    sayısının altına indirmeyi engelliyor ama mesajı belirsiz ve migration'ın
--    ortasında patlıyor. Burada önden, adıyla sanıyla söyleyip duruyoruz.
do $$
declare
  offenders text;
begin
  select string_agg(format('%s (%s aktif üye)', g.name, c.n), ', ')
    into offenders
  from public.groups g
  join lateral (
    select count(*)::integer as n
    from public.group_members m
    where m.group_id = g.id and m.left_at is null
  ) c on true
  where c.n > 8;

  if offenders is not null then
    raise exception
      'Üye sınırı 8''e indirilemez — 8''den fazla aktif üyesi olan grup(lar): %. Önce bu gruplar küçültülmeli.',
      offenders;
  end if;
end
$$;

-- 2) Yeni gruplar için varsayılan. Eski `create_group(text)` sütun
--    varsayılanına dayandığı için o yol da bu satırla düzelir.
alter table public.groups alter column member_limit set default 8;

-- 3) Mevcut gruplar. 1. adım hepsinin ≤ 8 aktif üyesi olduğunu garanti etti,
--    dolayısıyla guard trigger'ı bu update'i reddetmez.
update public.groups set member_limit = 8 where member_limit <> 8;

-- 4) Kısıt daraltılır.
alter table public.groups drop constraint if exists groups_member_limit_check;
alter table public.groups
  add constraint groups_member_limit_check
  check (member_limit between 2 and 8);

-- 5) RPC sözleşmesi: varsayılan ve doğrulama aralığı 8'e çekilir.
--    Gövde 0032'deki ile aynı; yalnız sınır sayıları değişti.
create or replace function public.create_group_with_access(
  p_name text,
  p_visibility text default 'private',
  p_member_limit integer default 8
)
returns public.groups
language plpgsql
security definer
set search_path = public
as $$
declare
  g public.groups;
  uid uuid := auth.uid();
  normalized_name text := btrim(coalesce(p_name, ''));
  normalized_visibility text := lower(btrim(coalesce(p_visibility, 'private')));
  attempt integer;
begin
  if uid is null then
    raise exception 'Oturum bulunamadı';
  end if;
  if normalized_name = '' or char_length(normalized_name) > 64 then
    raise exception 'Grup adı 1 ile 64 karakter arasında olmalı.';
  end if;
  if normalized_visibility not in ('private', 'public') then
    raise exception 'Geçersiz grup görünürlüğü.';
  end if;
  if p_member_limit not between 2 and 8 then
    raise exception 'Üye sınırı 2 ile 8 arasında olmalı.';
  end if;

  for attempt in 1..8 loop
    begin
      insert into public.groups (
        name, invite_code, created_by, visibility, member_limit
      ) values (
        normalized_name,
        public.gen_invite_code(),
        uid,
        normalized_visibility,
        p_member_limit
      ) returning * into g;

      insert into public.group_members (group_id, user_id, role)
        values (g.id, uid, 'admin');
      return g;
    exception when unique_violation then
      -- Davet kodu çakışırsa yeni kodla tekrar dene.
      continue;
    end;
  end loop;

  raise exception 'Grup oluşturulamadı, tekrar deneyin.';
end;
$$;

grant execute on function public.create_group_with_access(text, text, integer)
  to authenticated;

comment on constraint groups_member_limit_check on public.groups is
  'Sahip kararı 2026-07-26: grup en fazla 8 kişi.';
