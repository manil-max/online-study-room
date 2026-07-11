-- 0020_super_admin_operations.sql
-- Süper-adminlerin yaptığı işlemleri kaydeden denetim (audit) tablosu.

create table if not exists public.admin_audit_logs (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid not null references auth.users (id) on delete restrict,
  target_user_id uuid,
  target_user_email text,
  action text not null,
  reason text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_admin_audit_logs_created_at
  on public.admin_audit_logs (created_at desc);

create index if not exists idx_admin_audit_logs_admin
  on public.admin_audit_logs (admin_id);

alter table public.admin_audit_logs enable row level security;

-- Yalnızca süper-adminler bu kayıtları görebilir.
-- Tekrar çalıştırıldığında aynı politikayı güvenle yenile.
drop policy if exists admin_audit_logs_select on public.admin_audit_logs;
create policy admin_audit_logs_select on public.admin_audit_logs
  for select to authenticated
  using (public.is_super_admin());

-- İstemciden doğrudan kayıt atmayı (INSERT) engelliyoruz.
-- Kayıt ekleme işlemini sadece servis tarafı (Edge Function) service_role yetkisiyle yapacak.
