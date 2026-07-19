-- 0047_achievement_rewards_expand.sql
-- Başarım ödül gelen kutusu expansion'ı (WP-209)
--
-- Pending ödüller xp_ledger'dan ayrı tutulur. XP yalnız claim RPC'sinin
-- append-only ledger insert'iyle bankalanır; mevcut auto-award ve saatlik 50 XP
-- davranışı bu migration'da değiştirilmez. İstemci yalnız kendi pending
-- ödüllerini okuyabilir, doğrudan DML yapamaz. _create_pending_achievement_reward
-- gelecekteki trusted evaluator içindir; authenticated'a asla açılmaz.
--
-- Geri alma (Rollback): Aktivasyon öncesi ve tablo boşsa function/policy/index
-- bağımlılıklarını kaldırıp tablolar drop edilebilir. Reward satırı oluştuysa
-- tablo veya pending satırları silinmez; yeni pending üretimi durdurulur ve
-- mevcut satırlar claim edilebilir kalır.

create table if not exists public.achievement_rewards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  achievement_id text not null references public.achievements_dict(id),
  tier integer not null check (tier between 1 and 6),
  xp_amount integer not null check (xp_amount >= 0),
  reason text,
  -- Eski auto-award ile aynı kimlik: iki yol aynı kademe için iki XP yazamaz.
  event_key text not null,
  status text not null default 'pending'
    check (status in ('pending', 'claimed')),
  created_at timestamptz not null default now(),
  claimed_at timestamptz,
  claimed_ledger_event_key text,
  unique (user_id, achievement_id, tier),
  unique (event_key),
  check (
    (status = 'pending' and claimed_at is null and claimed_ledger_event_key is null)
    or
    (status = 'claimed' and claimed_at is not null and claimed_ledger_event_key is not null)
  )
);

create index if not exists achievement_rewards_pending_page_idx
  on public.achievement_rewards (user_id, created_at desc, id desc)
  where status = 'pending';

alter table public.achievement_rewards enable row level security;

drop policy if exists achievement_rewards_select_self on public.achievement_rewards;
create policy achievement_rewards_select_self on public.achievement_rewards
  for select to authenticated
  using (user_id = auth.uid());

revoke all on table public.achievement_rewards from public;
grant select on table public.achievement_rewards to authenticated;
revoke insert, update, delete on table public.achievement_rewards from authenticated, anon;

do $$
begin
  alter publication supabase_realtime add table public.achievement_rewards;
exception
  when duplicate_object then null;
end $$;

-- Capability yalnız rollout/UX cohort kaydıdır; XP uygunluğu değildir.
create table if not exists public.user_achievement_capabilities (
  user_id uuid not null references auth.users(id) on delete cascade,
  capability text not null check (capability in ('reward_inbox_v1')),
  enabled_at timestamptz not null default now(),
  primary key (user_id, capability)
);

alter table public.user_achievement_capabilities enable row level security;

drop policy if exists user_achievement_capabilities_select_self
  on public.user_achievement_capabilities;
create policy user_achievement_capabilities_select_self
  on public.user_achievement_capabilities
  for select to authenticated
  using (user_id = auth.uid());

revoke all on table public.user_achievement_capabilities from public;
grant select on table public.user_achievement_capabilities to authenticated;
revoke insert, update, delete on table public.user_achievement_capabilities
  from authenticated, anon;

-- Trusted evaluator helper: dictionary'deki XP'yi doğrular ve snapshot alır.
-- WP-219'a kadar çağrılmaz; bu migration auto-award akışını değiştirmez.
create or replace function public._create_pending_achievement_reward(
  p_user_id uuid,
  p_achievement_id text,
  p_tier integer,
  p_xp_amount integer,
  p_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_expected_xp integer;
  v_event_key text;
  v_reward_id uuid;
begin
  if p_user_id is null then
    raise exception 'reward_user_required';
  end if;

  select (tier_def ->> 'xp')::integer
    into v_expected_xp
  from public.achievements_dict d
  cross join lateral jsonb_array_elements(d.tiers) tier_def
  where d.id = p_achievement_id
    and (tier_def ->> 'tier')::integer = p_tier;

  if v_expected_xp is null or v_expected_xp <> p_xp_amount then
    raise exception 'reward_xp_snapshot_mismatch';
  end if;

  v_event_key := p_user_id::text || '|' || p_achievement_id
    || '|tier_' || p_tier::text;

  -- Aynı kademe eski auto-award ile zaten bankalandıysa pending yaratılmaz.
  if exists (
    select 1 from public.xp_ledger where event_key = v_event_key
  ) then
    return null;
  end if;

  insert into public.achievement_rewards (
    user_id, achievement_id, tier, xp_amount, reason, event_key
  ) values (
    p_user_id, p_achievement_id, p_tier, p_xp_amount, p_reason, v_event_key
  )
  on conflict (user_id, achievement_id, tier) do nothing
  returning id into v_reward_id;

  return v_reward_id;
end;
$$;

-- Tek reward için satır kilidi + canonical ledger event-key ile atomik claim.
create or replace function public._claim_achievement_reward(
  p_user_id uuid,
  p_reward_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reward public.achievement_rewards%rowtype;
  v_ledger_id uuid;
begin
  select * into v_reward
  from public.achievement_rewards
  where id = p_reward_id and user_id = p_user_id
  for update;

  if not found then
    return jsonb_build_object(
      'status', 'not_found',
      'reward_id', p_reward_id,
      'xp_granted', 0
    );
  end if;

  if v_reward.status = 'claimed' then
    return jsonb_build_object(
      'status', 'already_claimed',
      'reward_id', v_reward.id,
      'xp_granted', 0
    );
  end if;

  -- Eski/yeni yol yarışırsa mevcut canonical event XP'nin zaten bankalandığını
  -- kanıtlar; satır claim edilir fakat ikinci XP insert'i yapılmaz.
  if exists (
    select 1 from public.xp_ledger where event_key = v_reward.event_key
  ) then
    update public.achievement_rewards
    set status = 'claimed',
        claimed_at = now(),
        claimed_ledger_event_key = v_reward.event_key
    where id = v_reward.id;

    return jsonb_build_object(
      'status', 'already_banked',
      'reward_id', v_reward.id,
      'xp_granted', 0
    );
  end if;

  insert into public.xp_ledger (
    user_id, achievement_id, tier, xp_amount, reason, event_key
  ) values (
    v_reward.user_id,
    v_reward.achievement_id,
    v_reward.tier,
    v_reward.xp_amount,
    coalesce(v_reward.reason, 'Başarım ödülü toplandı'),
    v_reward.event_key
  )
  on conflict (event_key) do nothing
  returning id into v_ledger_id;

  update public.achievement_rewards
  set status = 'claimed',
      claimed_at = now(),
      claimed_ledger_event_key = v_reward.event_key
  where id = v_reward.id;

  return jsonb_build_object(
    'status', case when v_ledger_id is null then 'already_banked' else 'claimed' end,
    'reward_id', v_reward.id,
    'xp_granted', case when v_ledger_id is null then 0 else v_reward.xp_amount end
  );
end;
$$;

create or replace function public.claim_achievement_reward(p_reward_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  return public._claim_achievement_reward(v_uid, p_reward_id);
end;
$$;

-- Tek RPC çağrısında üst sınır 50'dir; 100+ inbox cursor ile sayfalanır.
create or replace function public.claim_all_achievement_rewards(
  p_limit integer default 25
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row record;
  v_result jsonb;
  v_claimed_ids jsonb := '[]'::jsonb;
  v_claimed_count integer := 0;
  v_xp_granted integer := 0;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if p_limit is null or p_limit < 1 or p_limit > 50 then
    raise exception 'claim_limit_out_of_range';
  end if;

  for v_row in
    select id
    from public.achievement_rewards
    where user_id = v_uid and status = 'pending'
    order by created_at asc, id asc
    limit p_limit
    for update skip locked
  loop
    v_result := public._claim_achievement_reward(v_uid, v_row.id);
    if v_result ->> 'status' = 'claimed' then
      v_claimed_count := v_claimed_count + 1;
      v_xp_granted := v_xp_granted + coalesce((v_result ->> 'xp_granted')::integer, 0);
      v_claimed_ids := v_claimed_ids || jsonb_build_array(v_row.id);
    end if;
  end loop;

  return jsonb_build_object(
    'claimed_count', v_claimed_count,
    'xp_granted', v_xp_granted,
    'claimed_reward_ids', v_claimed_ids
  );
end;
$$;

-- Keyset pagination: cursor son görülen (created_at, id) çiftidir.
create or replace function public.list_pending_achievement_rewards(
  p_limit integer default 50,
  p_cursor_created_at timestamptz default null,
  p_cursor_id uuid default null
)
returns table (
  id uuid,
  achievement_id text,
  tier integer,
  xp_amount integer,
  reason text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if p_limit is null or p_limit < 1 or p_limit > 100 then
    raise exception 'page_limit_out_of_range';
  end if;
  if (p_cursor_created_at is null) <> (p_cursor_id is null) then
    raise exception 'invalid_reward_cursor';
  end if;

  return query
  select r.id, r.achievement_id, r.tier, r.xp_amount, r.reason, r.created_at
  from public.achievement_rewards r
  where r.user_id = v_uid
    and r.status = 'pending'
    and (
      p_cursor_created_at is null
      or (r.created_at, r.id) < (p_cursor_created_at, p_cursor_id)
    )
  order by r.created_at desc, r.id desc
  limit p_limit;
end;
$$;

create or replace function public.pending_achievement_reward_summary()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  return (
    select jsonb_build_object(
      'pending_count', count(*),
      'pending_xp', coalesce(sum(xp_amount), 0)
    )
    from public.achievement_rewards
    where user_id = v_uid and status = 'pending'
  );
end;
$$;

-- Reconciliation self-service'dir; pending XP ledger/toplam XP'ye dahil değildir.
create or replace function public.my_achievement_xp_reconciliation()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_profile_xp integer;
  v_ledger_xp integer;
  v_pending_count integer;
  v_pending_xp integer;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  select coalesce(xp, 0) into v_profile_xp
  from public.gamification_profiles where user_id = v_uid;
  select coalesce(sum(xp_amount), 0) into v_ledger_xp
  from public.xp_ledger where user_id = v_uid;
  select count(*), coalesce(sum(xp_amount), 0)
    into v_pending_count, v_pending_xp
  from public.achievement_rewards
  where user_id = v_uid and status = 'pending';

  return jsonb_build_object(
    'profile_xp', coalesce(v_profile_xp, 0),
    'ledger_xp', coalesce(v_ledger_xp, 0),
    'difference', coalesce(v_profile_xp, 0) - coalesce(v_ledger_xp, 0),
    'pending_count', v_pending_count,
    'pending_xp', v_pending_xp
  );
end;
$$;

create or replace function public.record_achievement_capability(p_capability text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if p_capability <> 'reward_inbox_v1' then
    raise exception 'unknown_achievement_capability';
  end if;

  insert into public.user_achievement_capabilities (user_id, capability)
  values (v_uid, p_capability)
  on conflict (user_id, capability) do nothing;
end;
$$;

revoke all on function public._create_pending_achievement_reward(uuid, text, integer, integer, text) from public;
revoke all on function public._claim_achievement_reward(uuid, uuid) from public;
revoke all on function public.claim_achievement_reward(uuid) from public;
revoke all on function public.claim_all_achievement_rewards(integer) from public;
revoke all on function public.list_pending_achievement_rewards(integer, timestamptz, uuid) from public;
revoke all on function public.pending_achievement_reward_summary() from public;
revoke all on function public.my_achievement_xp_reconciliation() from public;
revoke all on function public.record_achievement_capability(text) from public;

grant execute on function public.claim_achievement_reward(uuid) to authenticated;
grant execute on function public.claim_all_achievement_rewards(integer) to authenticated;
grant execute on function public.list_pending_achievement_rewards(integer, timestamptz, uuid) to authenticated;
grant execute on function public.pending_achievement_reward_summary() to authenticated;
grant execute on function public.my_achievement_xp_reconciliation() to authenticated;
grant execute on function public.record_achievement_capability(text) to authenticated;
