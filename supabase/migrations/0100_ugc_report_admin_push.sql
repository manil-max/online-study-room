-- 0100_ugc_report_admin_push.sql
-- WP-428: Yeni açık içerik vakası için yöneticilere tekilleştirilmiş push.
-- Geri alma (Rollback): drop trigger if exists ugc_reports_enqueue_admin_push on public.ugc_reports;

create or replace function public._enqueue_ugc_report_admin_push()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  -- Aynı hedef için açık vaka varken sonraki şikâyetler yeni push üretmez.
  -- 🔴 Sayım yerine "en eski açık şikâyet ben miyim" sorulur: AFTER ROW tetikleyicisi
  -- deyim sonunda çalıştığı için çok satırlı tek INSERT'te bütün satırlar görünür
  -- olur; `count(*) = 1` koşulu o durumda hiçbir satırda tutmaz ve push HİÇ
  -- üretilmezdi. Bu biçim satır sayısından ve deyim gruplamasından bağımsızdır.
  if new.id <> (
       select r.id from public.ugc_reports r
       where r.target_type = new.target_type and r.target_id = new.target_id
         and r.status = 'open'
       order by r.created_at, r.id
       limit 1
     ) then return new; end if;
  insert into public.notification_outbox (event_key, recipient_id, notification_type, payload)
  select 'ugc-report:' || new.id::text || ':' || admin.user_id::text,
    admin.user_id, 'announcement', jsonb_build_object(
      'schema_version', '1', 'event_id', new.id::text, 'route', 'admin_moderation',
      'ugc_report_id', new.id::text, 'title', 'Yeni içerik şikâyeti',
      'body', left(new.target_type || ' · ' || new.reason, 120)
    )
  from public.app_admins admin on conflict (event_key) do nothing;
  return new;
end;
$$;
drop trigger if exists ugc_reports_enqueue_admin_push on public.ugc_reports;
create trigger ugc_reports_enqueue_admin_push after insert on public.ugc_reports
for each row execute function public._enqueue_ugc_report_admin_push();
