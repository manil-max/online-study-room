-- 0046_fix_feedback_trigger.sql
-- Feedback AFTER INSERT trigger onarımı (WP-195a)
--
-- Kök neden (cihaz Detay): 42704 column "role" does not exist.
-- 0029_admin_panel_fixes.sql notify_admins_on_feedback() şunu yapıyordu:
--   select … from public.app_admins where role = 'super_admin'
-- Ama app_admins (0018) yalnız user_id + created_at; role kolonu yok.
-- AFTER INSERT trigger her feedback insert'te patlayıp transaction'ı rollback
-- ediyordu (önbellek/RLS değil).
--
-- Bu migration: role filtresi kaldırılır (app_admins satırı = süper-admin);
-- security definer + search_path sertleştirme; pgrst schema reload.
--
-- Geri alma (Rollback): eski 0029 gövdesini (role filtresiyle) geri koymak
-- hatayı yeniden üretir — yapma. Trigger drop: drop trigger if exists
-- on_new_feedback on public.feedback_tickets;

create or replace function public.notify_admins_on_feedback()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- app_admins'in her satırı süper-admin (role kolonu yok / 0018).
  insert into public.admin_notifications (admin_id, title, message)
  select
    user_id,
    'Yeni Geri Bildirim: ' || NEW.subject,
    left(NEW.message, 100)
  from public.app_admins;

  return NEW;
end;
$$;

-- Trigger zaten 0029'da kurulu; yoksa idempotent yeniden oluştur.
drop trigger if exists on_new_feedback on public.feedback_tickets;
create trigger on_new_feedback
  after insert on public.feedback_tickets
  for each row
  execute function public.notify_admins_on_feedback();

notify pgrst, 'reload schema';
