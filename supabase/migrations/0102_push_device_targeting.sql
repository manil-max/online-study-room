-- 0102_push_device_targeting.sql
-- WP-432: Timer sync ve self-test bildirimlerinde cihaz-hedef sözleşmesi.
--
-- Timer sync, komutu başlatan cihaz hariç aynı hesabın etkin cihazlarına gider;
-- self-test ise yalnız çağrıyı başlatan etkin cihazın server-side device_id'sine
-- yönelir. Hedef sahipliği RPC'de auth.uid() ile doğrulanır; FCM token istemciye
-- veya payload'a taşınmaz. Delivery satırının (outbox_id, device_id) benzersizliği
-- aynı outbox için yinelenen teslimat yazımını engeller.
--
-- Geri alma (Rollback): Yeni self-test çağrılarını uygulama katmanında kapat;
-- gerektiğinde ileri migration ile request_push_self_test(uuid) execute iznini
-- kaldır. Audit/outbox/delivery satırlarını silme ve uygulanmış migration'ı değiştirme.

alter table public.notification_outbox
  add column if not exists target_device_id uuid
    references public.push_devices(id) on delete set null;

create index if not exists notification_outbox_target_device_idx
  on public.notification_outbox(target_device_id, created_at desc)
  where target_device_id is not null;

create or replace function public._create_push_deliveries()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare v_count integer;
begin
  insert into public.notification_deliveries (outbox_id, device_id)
  select new.id, d.id
  from public.push_devices d
  where d.user_id = new.recipient_id
    and d.disabled_at is null
    and (new.origin_device_id is null or d.id <> new.origin_device_id)
    and (new.target_device_id is null or d.id = new.target_device_id)
    and public._push_type_enabled(d, new.notification_type)
    and (
      new.notification_type <> 'update'
      or d.app_channel = coalesce(new.payload ->> 'target_channel', d.app_channel)
    )
  on conflict (outbox_id, device_id) do nothing;

  get diagnostics v_count = row_count;
  if v_count = 0 then
    update public.notification_outbox
    set status = 'no_devices', completed_at = now()
    where id = new.id;
  end if;
  return new;
end;
$$;

drop function public.request_push_self_test();

create function public.request_push_self_test(p_device_id uuid)
returns table (outbox_id uuid, requested_at timestamptz)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_row public.notification_outbox;
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;
  if p_device_id is null or not exists (
    select 1
    from public.push_devices
    where id = p_device_id
      and user_id = v_user_id
      and disabled_at is null
  ) then
    raise exception 'push_test_target_device_required';
  end if;
  if exists (
    select 1
    from public.notification_outbox
    where recipient_id = v_user_id
      and notification_type = 'self_test'
      and target_device_id = p_device_id
      and created_at > now() - interval '20 seconds'
  ) then
    raise exception 'push_test_cooldown';
  end if;

  insert into public.notification_outbox (
    event_key, recipient_id, notification_type, payload, target_device_id
  ) values (
    'self_test:' || v_user_id::text || ':' || p_device_id::text || ':' || gen_random_uuid()::text,
    v_user_id,
    'self_test',
    jsonb_build_object(
      'schema_version', '1',
      'event_id', gen_random_uuid()::text,
      'route', 'notification_center'
    ),
    p_device_id
  ) returning * into v_row;

  return query select v_row.id, v_row.created_at;
end;
$$;

revoke all on function public.request_push_self_test(uuid) from public, anon;
grant execute on function public.request_push_self_test(uuid) to authenticated;

notify pgrst, 'reload schema';
