-- 0116_nudge_focus_guard.sql
-- WP-476: Dürtme spam'ini kes ve "İlham Kaynağı" başarımını adının söylediği
-- şeye bağla. Üç kullanıcı şikâyeti tek kök nedene çıkıyor: dürtme **bedava**.
--
--   1. Cooldown 10 → 20 dakika. Kullanıcı notu: "görev için 10 dk'da bir
--      dürtüyorlar". Pencere zaten cooldown'un tam boyuydu, yani sistem bu
--      davranışı üretiyordu.
--   2. Çalışan kişi dürtülemez (`recipient_is_studying`). Zaten odaklanmış
--      birini dürtmek yalnız dikkat dağıtır; dürtmenin amacı başlatmaktır.
--   3. `inspiration` metriği artık **dönüşüm** sayar: dürtmeden sonraki 20
--      dakika içinde alıcı gerçekten çalışmaya başladıysa sayılır.
--
-- 🔴 (3) neden davranış düzeltmesi, kozmetik değil: başarımın adı "İlham
-- Kaynağı", açıklama anahtarının adı bile `coreDurtmeDonusumu` ("dürtme
-- dönüşümü") — ama sunucu ham gönderim sayıyordu. Yani 6. kademe (30.000 XP)
-- kimseyi çalıştırmadan, yalnız 1000 dürtme göndererek kazanılabiliyordu.
-- Ad dönüşüm vaat edip metrik spam ölçünce hem kullanıcı ("hangisi artırıyor
-- belli değil") hem ekonomi kaybediyor.
--
-- ⚠️ Kazanılmış kademeler GERİ ALINMAZ. `xp_ledger` append-only'dir ve
-- `achievement_metric_progress` projeksiyonu `inspiration` için `cumulative`
-- (greatest) yazar; değer düşmez. Yeni kural yalnız BUNDAN SONRAKİ ilerlemeye
-- uygulanır.
--
-- Geri alma (Rollback):
--   * `send_nudge`'ı `0107`'deki hâline döndür (20 dk → 10 dk, studying dalını
--     kaldır),
--   * `_achievement_metrics`'i `0058`'deki wrapper'a döndür (yalnız
--     perfect_months override'ı),
--   * `drop function if exists public._count_converted_nudges(uuid);`
--   * `achievement_metric_definitions.source_version` = 'metric_v2'.

-- ---------------------------------------------------------------------
-- 1) send_nudge — 20 dk cooldown + odak koruması
--    (0107 gövdesi; yalnız pencere ve tek yeni dal değişti.)
-- ---------------------------------------------------------------------
create or replace function public.send_nudge(
  p_group_id uuid,
  p_recipient_id uuid,
  p_message text default null
)
returns public.nudges
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sender uuid := auth.uid();
  v_message text := nullif(trim(coalesce(p_message, '')), '');
  v_row public.nudges;
  v_block_exempt boolean;
  v_muted boolean;
begin
  if v_sender is null then
    raise exception 'not_authenticated';
  end if;
  if v_sender = p_recipient_id then
    raise exception 'cannot_nudge_self';
  end if;
  if char_length(coalesce(v_message, '')) > 120 then
    raise exception 'message_too_long';
  end if;
  if not exists (
    select 1 from public.group_members
    where group_id = p_group_id and user_id = v_sender and left_at is null
  ) or not exists (
    select 1 from public.group_members
    where group_id = p_group_id and user_id = p_recipient_id and left_at is null
  ) then
    raise exception 'not_group_member';
  end if;

  -- F2: grup sahibi veya platform yöneticisi, yönetim yükümlülükleri için muaf.
  select public.is_group_admin(p_group_id)
    or public.is_super_admin()
    or exists (select 1 from public.groups where id = p_group_id and created_by = p_recipient_id)
    or exists (select 1 from public.app_admins where user_id = p_recipient_id)
  into v_block_exempt;

  if not v_block_exempt and exists (
    select 1 from public.user_blocks
    where (blocker_id = v_sender and blocked_id = p_recipient_id)
       or (blocker_id = p_recipient_id and blocked_id = v_sender)
  ) then
    raise exception 'nudge_blocked';
  end if;

  -- WP-476: çalışan kişi dürtülmez.
  --
  -- 🔴 Sıra bilinçli: engel kontrolünden SONRA. Aksi hâlde engellenmiş bir
  -- kullanıcı, dönen hatanın `nudge_blocked` mi `recipient_is_studying` mi
  -- olduğuna bakarak karşı tarafın o an çalışıp çalışmadığını okurdu.
  -- Bu noktadan sonra gönderen zaten aktif grup üyesidir ve alıcının
  -- durumunu `group_live_presence` üzerinden görebilir; yeni bilgi sızmaz.
  --
  -- Kaynak kanonik state'tir, projeksiyon değil: lease süresi dolmuş bir
  -- satır "çalışıyor" sayılmaz, yoksa uygulamayı çökerten kullanıcı
  -- süresiz dürtülemez olurdu.
  if exists (
    select 1 from public.user_live_presence_state
    where user_id = p_recipient_id
      and status = 'studying'
      and lease_expires_at > now()
  ) then
    raise exception 'recipient_is_studying';
  end if;

  -- WP-444: cooldown penceresi gerçek ve bastırılmış denemeleri birlikte sayar.
  -- Yalnız `nudges` sayılsaydı susturulmuş alıcıya art arda dürtme kabul edilir,
  -- gönderen tercihi bu farktan okurdu.
  -- WP-476: pencere 10 → 20 dakika (iki dal birlikte, parite şart).
  if exists (
    select 1 from public.nudges
    where group_id = p_group_id and sender_id = v_sender and recipient_id = p_recipient_id
      and created_at > now() - interval '20 minutes'
  ) or exists (
    select 1 from public.nudge_suppressed_attempts
    where group_id = p_group_id and sender_id = v_sender and recipient_id = p_recipient_id
      and created_at > now() - interval '20 minutes'
  ) then
    raise exception 'nudge_cooldown';
  end if;

  select exists (
    select 1 from public.nudge_mutes
    where user_id = p_recipient_id and muted_sender_id = v_sender
  ) into v_muted;

  if v_muted then
    -- Satır yok → realtime yok → `nudges_enqueue_push` tetiklenmez → outbox yok.
    insert into public.nudge_suppressed_attempts (group_id, sender_id, recipient_id)
    values (p_group_id, v_sender, p_recipient_id);

    v_row.id := gen_random_uuid();
    v_row.group_id := p_group_id;
    v_row.sender_id := v_sender;
    v_row.recipient_id := p_recipient_id;
    v_row.message := v_message;
    v_row.created_at := now();
    v_row.read_at := null;
    return v_row;
  end if;

  insert into public.nudges (group_id, sender_id, recipient_id, message)
  values (p_group_id, v_sender, p_recipient_id, v_message)
  returning * into v_row;
  return v_row;
end;
$$;

grant execute on function public.send_nudge(uuid, uuid, text) to authenticated;

-- ---------------------------------------------------------------------
-- 2) İlham Kaynağı = dönüşüm sayısı
-- ---------------------------------------------------------------------
-- Bir dürtme, alıcı **dürtmeden sonraki 20 dakika içinde** çalışmaya başladıysa
-- ve bu çalışma sunucu-doğrulamalı canlı oturum olarak tamamlandıysa dönüşmüş
-- sayılır. Elle eklenen/legacy `live_run_id is null` satırlar sayılmaz; aksi hâlde
-- alıcı geçmişe dönük 1 dakikalık kayıt ekleyerek gönderenle XP farm'ı yapabilirdi.
-- Pencere cooldown ile aynı tutuldu: aynı kişiye ikinci dürtmeyi gönderebildiğin
-- an, birincinin dönüşme şansı bitmiştir.
create or replace function public._count_converted_nudges(p_user_id uuid)
returns integer
language sql
security definer
set search_path = public
stable
as $$
  select count(*)::integer
  from public.nudges n
  where n.sender_id = p_user_id
    and exists (
      select 1
      from public.study_sessions s
      where s.user_id = n.recipient_id
        and s.source = 'live'
        and s.live_run_id is not null
        and s.duration_seconds > 0
        and s.start_time >= n.created_at
        and s.start_time < n.created_at + interval '20 minutes'
    );
$$;

revoke all on function public._count_converted_nudges(uuid)
  from public, anon, authenticated;

-- 0058 wrapper'ı + tek override daha. Legacy gövde (0025) dokunulmadan kalır.
create or replace function public._achievement_metrics(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  v_metrics jsonb;
  v_perfect_months integer;
  v_converted_nudges integer;
begin
  v_metrics := public._achievement_metrics_legacy_v1(p_user_id);

  v_perfect_months := public._count_perfect_months_28(p_user_id);
  v_metrics := jsonb_set(
    v_metrics,
    '{perfect_months}',
    to_jsonb(coalesce(v_perfect_months, 0)),
    true
  );

  v_converted_nudges := public._count_converted_nudges(p_user_id);
  v_metrics := jsonb_set(
    v_metrics,
    '{nudge_starts}',
    to_jsonb(coalesce(v_converted_nudges, 0)),
    true
  );

  perform public._project_achievement_metrics(p_user_id, v_metrics);
  return v_metrics;
end;
$$;

revoke all on function public._achievement_metrics(uuid)
  from public, anon, authenticated;

-- Metrik sözleşme sürümü doğrulanmış canlı oturum şartını da ilan eder.
update public.achievement_metric_definitions
set source_version = 'nudge_conversion_verified_v1', updated_at = now()
where achievement_id = 'inspiration';

-- Kullanıcıya görünen açıklama artık kuralı SÖYLÜYOR. Eski metin ("gönderdiğin
-- dürtme sayısı") ile başarımın adı birbirini yalanlıyordu.
update public.achievements_dict
set description = 'Dürttüğün kişi 20 dakika içinde çalışmaya başlarsa sayılır'
where id = 'inspiration';

notify pgrst, 'reload schema';
