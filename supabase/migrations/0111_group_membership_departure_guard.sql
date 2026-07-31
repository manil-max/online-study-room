-- 0111_group_membership_departure_guard.sql
-- WP-447: gruptan ayrilmanin TEK kapisi olur.
--
-- Bulgu (v57 yaris/guvenlik matrisi): `0108` cikis komutunu sunucu-otoriter ve
-- idempotent yapti, ama eski kapiyi kapatmadi. `group_members` uzerindeki
-- `members_update_self` politikasi (`0008`) hala su iki yazmaya izin veriyor:
--
--   1. Kullanicinin KENDI satirina dogrudan `left_at` yazmasi. Bu, `leave_group`
--      icindeki advisory lock'u, `group_leave_commands` idempotency anahtarini,
--      presence temizligini ve sahiplik kontrolunu tamamen atlar. Uygulama artik
--      RPC kullaniyor; fakat REST ucu authenticated her istemciye acik.
--   2. Grup SAHIBININ (`groups.created_by`) uyeliginin kapatilmasi. `leave_group`
--      bunu `owner_must_transfer_or_delete` ile reddediyor, `ban_group_member`
--      `cannot_ban_group_owner` ile reddediyor; ama dogrudan UPDATE eden hicbir
--      sey reddetmiyordu. Sonuc: sahipsiz grup - kimse davet kodunu
--      yenileyemez, uye cikaramaz, grubu silemez.
--
-- Iki degismez de artik yazma yolundan BAGIMSIZ olarak trigger'da duruyor.
-- RLS `with check` bunu yapamaz: eski satiri gormeden `left_at` gecisini
-- (null -> not null) ayirt edemez, `using` de yeni satiri goremez.

create or replace function public.group_members_departure_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $guard$
declare
  v_owner uuid;
begin
  -- Yalniz "aktif uyelikten cikis" gecisi denetlenir. Rol degisimi, yeniden
  -- katilim (`left_at` -> null) ve alakasiz kolon guncellemeleri serbesttir.
  if new.left_at is null or old.left_at is not null then
    return new;
  end if;

  select created_by into v_owner from public.groups where id = new.group_id;

  -- 1) Sahiplik degismezi: her yoldan gecerli.
  if v_owner is not null and new.user_id = v_owner then
    raise exception 'owner_must_transfer_or_delete'
      using errcode = 'check_violation';
  end if;

  -- 2) Kendi cikisin tek yolu `leave_group` RPC'si.
  --    `auth.uid()` yalnizca istemci (authenticated) baglaminda doludur;
  --    service_role, migration ve diger security-definer fonksiyonlar bu
  --    kapidan etkilenmez. Yonetici BASKASINI cikardiginda (`removeMember`,
  --    `ban_group_member`) `auth.uid() <> new.user_id` oldugu icin gecer.
  if auth.uid() is not null
     and auth.uid() = new.user_id
     and coalesce(current_setting('app.leave_group_command', true), '') = ''
  then
    raise exception 'use_leave_group_rpc'
      using errcode = 'check_violation';
  end if;

  return new;
end;
$guard$;

drop trigger if exists group_members_departure_guard on public.group_members;
create trigger group_members_departure_guard
  before update of left_at on public.group_members
  for each row
  execute function public.group_members_departure_guard();

-- `leave_group` artik kendi yazmasini isaretler. Bayrak transaction-local
-- (`is_local = true`): ayni oturumdaki sonraki bir dogrudan UPDATE'e sizmaz.
create or replace function public.leave_group(
  p_group_id uuid,
  p_command_id uuid
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_outcome text;
  v_owner uuid;
  v_is_active boolean;
  v_is_admin boolean;
  v_other_members integer;
  v_other_admins integer;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if p_group_id is null or p_command_id is null then
    raise exception 'invalid_leave_command';
  end if;

  -- Ayni kullanici+grup icin tum cikis komutlarini siraya sokar: 20 hizli tap
  -- da, zaman asimi sonrasi retry de bu kapidan tek tek gecer.
  perform pg_advisory_xact_lock(
    hashtext(v_uid::text || ':' || p_group_id::text)
  );

  -- 1) Tekrar (replay): is yeniden yapilmaz, ilk sonuc aynen doner.
  select outcome into v_outcome
  from public.group_leave_commands
  where command_id = p_command_id;

  if found then
    if not exists (
      select 1 from public.group_leave_commands
      where command_id = p_command_id and user_id = v_uid and group_id = p_group_id
    ) then
      -- Anahtar baskasinin ya da baska grubun komutu: sessizce kabul edilmez.
      raise exception 'leave_command_mismatch';
    end if;
    return v_outcome;
  end if;

  select created_by into v_owner from public.groups where id = p_group_id;
  if v_owner is null then
    raise exception 'group_not_found';
  end if;

  select (left_at is null), (role = 'admin')
  into v_is_active, v_is_admin
  from public.group_members
  where group_id = p_group_id and user_id = v_uid;

  -- 2) Zaten uye degil (ya da hic olmadi): idempotent "already_left".
  --    Hata DEGILDIR; aksi halde cevrimdisi retry sahte hata gosterirdi.
  if v_is_active is null or v_is_active = false then
    insert into public.group_leave_commands (command_id, user_id, group_id, outcome)
    values (p_command_id, v_uid, p_group_id, 'already_left');
    return 'already_left';
  end if;

  select count(*) into v_other_members
  from public.group_members
  where group_id = p_group_id and user_id <> v_uid and left_at is null;

  -- 3) Sahiplik degismezi: sahip cikarsa grup sahipsiz kalir.
  if v_uid = v_owner then
    raise exception 'owner_must_transfer_or_delete';
  end if;

  -- 4) Son yonetici korumasi. Sahip cikamadigi icin normalde ulasilamaz;
  --    sahibi silinmis eski gruplar icin guvenlik agi olarak durur.
  if v_is_admin and v_other_members > 0 then
    select count(*) into v_other_admins
    from public.group_members
    where group_id = p_group_id and user_id <> v_uid
      and left_at is null and role = 'admin';
    if v_other_admins = 0 then
      raise exception 'last_admin_must_transfer';
    end if;
  end if;

  -- 5) Cikis: soft-delete + presence temizligi ayni islemde.
  --    WP-447: bayrak `0111` trigger'ina "bu yazma RPC'den geliyor" der.
  perform set_config('app.leave_group_command', p_command_id::text, true);

  update public.group_members
  set left_at = now()
  where group_id = p_group_id and user_id = v_uid and left_at is null;

  delete from public.group_live_presence
  where group_id = p_group_id and user_id = v_uid;

  insert into public.group_leave_commands (command_id, user_id, group_id, outcome)
  values (p_command_id, v_uid, p_group_id, 'left');

  return 'left';
end;
$$;

grant execute on function public.leave_group(uuid, uuid) to authenticated;

-- Trigger fonksiyonu istemciden dogrudan cagrilamaz.
revoke all on function public.group_members_departure_guard() from public;
