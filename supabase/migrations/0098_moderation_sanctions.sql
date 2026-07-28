-- 0098_moderation_sanctions.sql
-- WP-426: Geri alınabilir ad sıfırlama ve denetim kaydının değişmezliği.
--
-- Geri alma (Rollback): drop table if exists public.moderation_name_resets;
-- Edge Function yaptırımlarını geri alırken auth.users ban_until değeri `none`
-- ile temizlenir; isim geri alımı önce bu tablodaki özgün ada döner.

create table if not exists public.moderation_name_resets (
  target_type text not null check (target_type in ('user', 'group')),
  target_id uuid not null,
  previous_name text not null,
  reset_by uuid not null references auth.users(id) on delete restrict,
  reset_at timestamptz not null default now(),
  primary key (target_type, target_id)
);

alter table public.moderation_name_resets enable row level security;
revoke all on public.moderation_name_resets from public, anon, authenticated;

-- Denetim satırları yalnız Edge Function/service_role tarafından eklenir;
-- hiçbir yönetici geçmiş işlemi değiştiremez ya da silemez.
revoke update, delete on public.admin_audit_logs from public, anon, authenticated;
