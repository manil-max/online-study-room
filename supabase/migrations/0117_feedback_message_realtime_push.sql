-- 0117_feedback_message_realtime_push.sql
-- WP-485: yönetici konuşmasında canlı yayın ve push bildirimi.
--
-- Belirti (V57-N09 sistem yarısı + V57-N10): yönetici mesaj gönderiyor, mesaj
-- karşıya gidiyor ama kendi ekranında görünmüyor; ne karşı tarafa ne de
-- yöneticiye bildirim düşüyor. "Geç geliyor" denen şey gecikme değil YOKLUKTU:
-- canlı yayın olmadığı için mesaj ancak ekran yeniden veri çektiğinde görünüyor.
--
-- İki kök neden, ikisi de sunucuda:
--   1. `public.feedback_ticket_messages` `supabase_realtime` publication'ına
--      hiç eklenmemiş. `watchTicketMessages` Supabase `.stream()` kullanıyor,
--      yani WAL olaylarına bağlı; tablo yayında olmayınca akış yalnız ilk
--      okumayı verip donuyor. Karşılaştırma: `feedback_tickets` 0018'de,
--      `nudges` 0016'da publication'a eklenmiş.
--   2. `0066` push zincirinde yalnız iki üretici var (`nudges_enqueue_push`,
--      `announcements_enqueue_push`). Mesaj için tetikleyici yok, dolayısıyla
--      iki yönde de bildirim doğmuyor.
--
-- Alıcı her zaman KARŞI TARAFTIR: kullanıcı yazdıysa yönetici(ler), yönetici
-- yazdıysa bilet sahibi. Gönderene kendi mesajının push'u gitmez.
--
-- 🔴 0116 dersi: bildirim gövdesi data-only kalır. `dispatch-push` bu tipi
-- genel daldan (payload.title / payload.body) üretir ve `android.notification`
-- bloğu eklenmez; eklenirse data-only mesaj bozulur ve yanına içeriksiz ikinci
-- bir bildirim düşer.
--
-- Geri alma (Rollback):
--   drop trigger if exists feedback_messages_enqueue_push on public.feedback_ticket_messages;
--   drop function if exists public._enqueue_feedback_message_push();
--   alter publication supabase_realtime drop table public.feedback_ticket_messages;
--   alter table public.notification_outbox drop constraint notification_outbox_notification_type_check;
--   alter table public.notification_outbox add constraint notification_outbox_notification_type_check
--     check (notification_type in ('nudge','announcement','update','self_test','timer_sync'));
--   (`_push_type_enabled` gövdesini 0083'teki hâline döndür.)

-- ---------------------------------------------------------------------------
-- 1. Realtime yayını
-- ---------------------------------------------------------------------------
-- Koşullu kalıp 0016/0018 ile aynı: tekrar apply `duplicate_object` ile patlamaz.
do $$
begin
  alter publication supabase_realtime add table public.feedback_ticket_messages;
exception
  when duplicate_object then null;
end $$;

-- ---------------------------------------------------------------------------
-- 2. Push tipi
-- ---------------------------------------------------------------------------
-- 0083 ile aynı yaklaşım: adı ne olursa olsun mevcut CHECK'i düşür, yenisini
-- adlandırılmış olarak ekle.
do $migration$
declare
  v_constraint record;
begin
  for v_constraint in
    select conname from pg_constraint
    where conrelid = 'public.notification_outbox'::regclass and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%notification_type%'
  loop
    execute format(
      'alter table public.notification_outbox drop constraint %I',
      v_constraint.conname
    );
  end loop;
end
$migration$;

alter table public.notification_outbox
  add constraint notification_outbox_notification_type_check
  check (
    notification_type in (
      'nudge', 'announcement', 'update', 'self_test', 'timer_sync',
      'feedback_message'
    )
  );

-- Cihaz tercihleri: `feedback_message` için ayrı bir bayrak YOK ve bilinçli
-- olarak eklenmedi. Bu bir yayın değil, kullanıcının kendi açtığı biletin
-- yanıtıdır; duyuru bayrağına bağlanırsa duyuruları kapatan kullanıcı destek
-- yanıtını da kaçırır. Sessiz saatler yine uygulanır (`dispatch-push` yalnız
-- `self_test`/`timer_sync` tiplerini sessiz saatlerden muaf tutar).
create or replace function public._push_type_enabled(
  p_device public.push_devices,
  p_notification_type text
)
returns boolean
language plpgsql
stable
set search_path = public
as $$
begin
  case p_notification_type
    when 'nudge' then return p_device.nudge_enabled;
    when 'announcement' then return p_device.announcement_enabled;
    when 'update' then return p_device.update_enabled;
    when 'self_test', 'timer_sync', 'feedback_message' then return true;
    else raise exception 'invalid_push_notification_type';
  end case;
end;
$$;

revoke all on function public._push_type_enabled(public.push_devices, text)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Mesaj → outbox tetikleyicisi
-- ---------------------------------------------------------------------------
create or replace function public._enqueue_feedback_message_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ticket_owner uuid;
  v_sender_name text;
  v_body text;
begin
  select user_id into v_ticket_owner
  from public.feedback_tickets
  where id = new.ticket_id;

  if v_ticket_owner is null then
    return new;
  end if;

  select display_name into v_sender_name
  from public.profiles
  where id = new.sender_id;

  -- Gövde kısaltılır: push yükü mesajın tamamını taşımak zorunda değil ve
  -- 1200 karakterlik mesaj FCM yükünü şişirir.
  v_body := left(trim(new.message), 180);

  insert into public.notification_outbox (
    event_key, recipient_id, notification_type, payload
  )
  select
    'feedback_message:' || new.id::text || ':' || recipient.user_id::text,
    recipient.user_id,
    'feedback_message',
    jsonb_build_object(
      'schema_version', '1',
      'event_id', new.id::text,
      'route', 'feedback_ticket',
      'ticket_id', new.ticket_id::text,
      'message_id', new.id::text,
      'sender_id', new.sender_id::text,
      'sender_role', new.sender_role,
      'sender_display_name', coalesce(v_sender_name, ''),
      'title', coalesce(nullif(trim(v_sender_name), ''), 'Odak Kampı'),
      'body', v_body
    )
  from (
    -- Kullanıcı yazdıysa alıcı yöneticilerdir; yönetici yazdıysa bilet sahibi.
    select a.user_id
      from public.app_admins a
     where new.sender_role = 'user'
    union
    select v_ticket_owner
     where new.sender_role = 'admin'
  ) recipient
  -- Gönderene kendi mesajının push'u gitmez (yönetici hem admin hem bilet
  -- sahibi olabilir; bu filtre o durumu da kapatır).
  where recipient.user_id is distinct from new.sender_id
  on conflict (event_key) do nothing;

  return new;
end;
$$;

drop trigger if exists feedback_messages_enqueue_push
  on public.feedback_ticket_messages;
create trigger feedback_messages_enqueue_push
after insert on public.feedback_ticket_messages
for each row execute function public._enqueue_feedback_message_push();

revoke all on function public._enqueue_feedback_message_push()
  from public, anon, authenticated;
